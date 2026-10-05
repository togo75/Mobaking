import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';

import '../core/native_bindings.dart';
import '../core/vocab.dart';
import '../models/voice_intent.dart';
import 'model_download_service.dart';

class SluAsrService extends ChangeNotifier {
  SluAsrService({required ModelDownloadService models}) : _models = models;

  final ModelDownloadService _models;
  final ReceivePort _responses = ReceivePort();
  final Map<int, Completer<String>> _pending = {};

  Isolate? _worker;
  SendPort? _commands;
  StreamSubscription<dynamic>? _responseSubscription;
  Completer<void>? _initialization;
  int _nextRequestId = 0;
  bool _isInitialized = false;
  bool _isLoading = false;
  String? _initializationError;

  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  String? get initializationError => _initializationError;

  Future<void> init() async {
    if (_isInitialized) return;
    if (_initialization != null) return _initialization!.future;

    final completer = Completer<void>();
    _initialization = completer;
    _isLoading = true;
    _initializationError = null;
    notifyListeners();
    final stopwatch = Stopwatch()..start();

    try {
      await _models.init();
      final paths = [
        _models.pathFor(AppModels.numberAsr),
        _models.pathFor(AppModels.sluEncoder),
        _models.pathFor(AppModels.sluDecoder),
        _models.pathFor(AppModels.sluEmbedding),
        _models.pathFor(AppModels.sluClassifier),
      ];

      _responseSubscription ??= _responses.listen(_handleWorkerMessage);
      _worker = await Isolate.spawn<Map<String, dynamic>>(_sluWorkerMain, {
        'replyTo': _responses.sendPort,
        'paths': paths,
        'asrVocab': AppVocabularies.modelVocabs[0]!,
        'sluVocab': AppVocabularies.modelVocabs[2]!,
      }, debugName: 'bamking-asr-slu');

      await completer.future.timeout(const Duration(seconds: 90));
      stopwatch.stop();
      debugPrint('[SLU:init] ready in ${stopwatch.elapsedMilliseconds} ms');
    } catch (error, stackTrace) {
      _isLoading = false;
      _isInitialized = false;
      _initializationError = error.toString();
      if (!completer.isCompleted) completer.completeError(error, stackTrace);
      debugPrint(
        '[SLU:init] failed after ${stopwatch.elapsedMilliseconds} ms: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
      notifyListeners();
      rethrow;
    } finally {
      _initialization = null;
    }
  }

  void _handleWorkerMessage(dynamic message) {
    if (message is! Map) return;
    switch (message['type']) {
      case 'ready':
        _commands = message['commands'] as SendPort;
        _isInitialized = true;
        _isLoading = false;
        _initializationError = null;
        if (_initialization != null && !_initialization!.isCompleted) {
          _initialization!.complete();
        }
        notifyListeners();
      case 'initError':
        final error = StateError(
          message['error']?.toString() ?? 'Unknown worker error',
        );
        if (_initialization != null && !_initialization!.isCompleted) {
          _initialization!.completeError(error);
        }
      case 'result':
        final id = message['id'] as int?;
        final completer = id == null ? null : _pending.remove(id);
        completer?.complete(message['value']?.toString() ?? '');
      case 'error':
        final id = message['id'] as int?;
        final completer = id == null ? null : _pending.remove(id);
        completer?.completeError(
          StateError(message['error']?.toString() ?? 'Inference failed'),
        );
    }
  }

  Future<String> transcribeSpeech(String wavPath) async {
    final stopwatch = Stopwatch()..start();
    final output = await _request('asr', wavPath);
    stopwatch.stop();
    debugPrint(
      '[ASR] input=$wavPath output=$output elapsedMs=${stopwatch.elapsedMilliseconds}',
    );
    return output.trim();
  }

  Future<VoiceIntent> parseIntent(String wavPath) async {
    final stopwatch = Stopwatch()..start();
    final rawOutput = await _request('slu', wavPath);
    debugPrint('[SLU] raw=$rawOutput');
    try {
      final intent = VoiceIntent.fromRawJson(rawOutput);
      stopwatch.stop();
      debugPrint(
        '[SLU] validated=$intent elapsedMs=${stopwatch.elapsedMilliseconds}',
      );
      return intent;
    } catch (error, stackTrace) {
      stopwatch.stop();
      debugPrint(
        '[SLU] validation failed elapsedMs=${stopwatch.elapsedMilliseconds}: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<String> _request(String operation, String wavPath) async {
    if (!_isInitialized || _commands == null) {
      throw StateError('Voice model worker is not ready.');
    }
    final id = _nextRequestId++;
    final completer = Completer<String>();
    _pending[id] = completer;
    _commands!.send({'id': id, 'operation': operation, 'wavPath': wavPath});
    return completer.future;
  }

  @override
  void dispose() {
    _commands?.send({'operation': 'dispose'});
    _responseSubscription?.cancel();
    _responses.close();
    final worker = _worker;
    if (worker != null) {
      unawaited(
        Future<void>.delayed(const Duration(seconds: 2), () {
          worker.kill(priority: Isolate.immediate);
        }),
      );
    }
    for (final completer in _pending.values) {
      if (!completer.isCompleted) {
        completer.completeError(StateError('Voice model worker disposed.'));
      }
    }
    _pending.clear();
    super.dispose();
  }
}

void _sluWorkerMain(Map<String, dynamic> initialization) {
  final replyTo = initialization['replyTo'] as SendPort;
  final paths = (initialization['paths'] as List).cast<String>();
  final asrVocab = (initialization['asrVocab'] as List).cast<String>();
  final sluVocab = (initialization['sluVocab'] as List).cast<String>();
  final commands = ReceivePort();
  int? asrHandle;
  int? sluHandle;

  try {
    asrHandle = initSession(
      mainModelPath: paths[0],
      modelType: 0,
      vocabulary: asrVocab,
    );
    sluHandle = initSession(
      mainModelPath: paths[1],
      modelType: 2,
      vocabulary: sluVocab,
      extraModelPaths: [paths[3], paths[2], paths[4]],
    );
    replyTo.send({'type': 'ready', 'commands': commands.sendPort});
  } catch (error) {
    if (asrHandle != null) disposeSession(asrHandle);
    if (sluHandle != null) disposeSession(sluHandle);
    commands.close();
    replyTo.send({'type': 'initError', 'error': error.toString()});
    return;
  }

  commands.listen((dynamic message) {
    if (message is! Map) return;
    if (message['operation'] == 'dispose') {
      disposeSession(asrHandle!);
      disposeSession(sluHandle!);
      commands.close();
      Isolate.exit();
    }

    final id = message['id'] as int;
    final operation = message['operation'] as String;
    final wavPath = message['wavPath'] as String;
    final pathPointer = wavPath.toNativeUtf8();
    Pointer<Utf8>? resultPointer;
    try {
      resultPointer = transcribe(
        operation == 'asr' ? asrHandle! : sluHandle!,
        pathPointer,
      );
      if (resultPointer == nullptr) {
        throw StateError('$operation returned a null result.');
      }
      replyTo.send({
        'type': 'result',
        'id': id,
        'value': resultPointer.toDartString(),
      });
    } catch (error) {
      replyTo.send({'type': 'error', 'id': id, 'error': error.toString()});
    } finally {
      malloc.free(pathPointer);
      if (resultPointer != null && resultPointer != nullptr) {
        freeCString(resultPointer);
      }
    }
  });
}
