import 'dart:async';
import 'dart:convert';
import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:isolate';

import 'package:audioplayers/audioplayers.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import '../core/asset_manager.dart';
import 'model_download_service.dart';

class TTSService extends ChangeNotifier {
  static const int _maxCacheBytes = 100 * 1024 * 1024;
  static const int _maxCacheEntries = 250;
  static const String _cacheVersion = 'bam-vits-v1-sid0-speed1';
  static const List<String> _fixedPrompts = [
    'Nimɔrɔ fɔ kelen kelen',
    'Wari hakɛ fɔ',
    "K'i ɲɛda Home kan",
    "K'i ɲɛda Operations kan",
    "K'i ɲɛda FAQ kan",
    "K'i ɲɛda Profile kan",
    'I ka wari jate tɛ a bɔ.',
    'I ka ɲininkali jaabi bɛ sɔrɔ ninnu cɛma',
  ];

  final ModelDownloadService _models;
  final AudioPlayer _audioPlayer = AudioPlayer();
  final ReceivePort _responses = ReceivePort();
  final Map<int, Completer<String>> _pendingGeneration = {};
  final Map<String, Future<String>> _inFlightCacheWrites = {};

  StreamSubscription<dynamic>? _responseSubscription;
  Isolate? _worker;
  SendPort? _commands;
  Completer<void>? _initialization;
  Completer<void>? _cancellation;
  Directory? _cacheDirectory;
  int _nextGenerationId = 0;
  int _speechVersion = 0;
  bool _isEngineLoading = false;
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _interactiveRequestActive = false;
  bool _isPrewarming = false;
  String? _initializationError;

  bool get isEngineLoading => _isEngineLoading;
  bool get isInitialized => _isInitialized;
  bool get isPlaying => _isPlaying;
  String? get initializationError => _initializationError;

  TTSService({required ModelDownloadService models}) : _models = models {
    _audioPlayer.onPlayerStateChanged.listen((state) {
      _isPlaying = state == PlayerState.playing;
      notifyListeners();
    });
  }

  // ✅ Configuration AudioContext pour Waydroid + Android arm64
  Future<void> _configureAudioContext() async {
    try {
      await _audioPlayer.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            isSpeakerphoneOn: true,
            stayAwake: false,
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.assistanceSonification,
            audioFocus: AndroidAudioFocus.none,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: const {AVAudioSessionOptions.duckOthers},
          ),
        ),
      );
      debugPrint('[TTS:audio] AudioContext configuré');
    } catch (e, st) {
      debugPrint('[TTS:audio] Échec config AudioContext: $e');
      debugPrintStack(stackTrace: st);
    }
  }

  Future<void> init() async {
    if (_isInitialized) return;
    if (_initialization != null) return _initialization!.future;

    final completer = Completer<void>();
    _initialization = completer;
    _isEngineLoading = true;
    _initializationError = null;
    notifyListeners();
    final stopwatch = Stopwatch()..start();

    try {
      await _models.init();
      final paths = await Future.wait([
        Future.value(_models.pathFor(AppModels.vits)),
        AssetManager.copyAssetToLocal('assets/vits/tokens.txt'),
      ]);
      final root = await getApplicationCacheDirectory();
      _cacheDirectory = Directory(p.join(root.path, 'tts', _cacheVersion));
      await _cacheDirectory!.create(recursive: true);

      // ✅ Configurer l'AudioContext AVANT de démarrer le worker
      await _configureAudioContext();

      _responseSubscription ??= _responses.listen(_handleWorkerMessage);
      _worker = await Isolate.spawn<Map<String, dynamic>>(_ttsWorkerMain, {
        'replyTo': _responses.sendPort,
        'modelPath': paths[0],
        'tokensPath': paths[1],
      }, debugName: 'bamking-vits');
      await completer.future.timeout(const Duration(seconds: 90));
      stopwatch.stop();
      debugPrint('[TTS:init] ready in ${stopwatch.elapsedMilliseconds} ms');
      unawaited(_prewarm());
    } catch (error, stackTrace) {
      _isEngineLoading = false;
      _isInitialized = false;
      _initializationError = error.toString();
      if (!completer.isCompleted) completer.completeError(error, stackTrace);
      debugPrint(
        '[TTS:init] failed after ${stopwatch.elapsedMilliseconds} ms: $error',
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
        _isEngineLoading = false;
        _initializationError = null;
        if (_initialization != null && !_initialization!.isCompleted) {
          _initialization!.complete();
        }
        notifyListeners();
      case 'initError':
        final error = StateError(
          message['error']?.toString() ?? 'Unknown TTS worker error',
        );
        if (_initialization != null && !_initialization!.isCompleted) {
          _initialization!.completeError(error);
        }
      case 'result':
        final id = message['id'] as int?;
        final completer = id == null ? null : _pendingGeneration.remove(id);
        debugPrint(
          '[TTS:generate] text=${message['text']} elapsedMs=${message['elapsedMs']}',
        );
        completer?.complete(message['path'] as String);
      case 'error':
        final id = message['id'] as int?;
        final completer = id == null ? null : _pendingGeneration.remove(id);
        completer?.completeError(
          StateError(message['error']?.toString() ?? 'TTS failed'),
        );
    }
  }

  Future<bool> speak(String text) async {
    final normalized = _normalize(text);
    if (normalized.isEmpty) return false;
    if (!_isInitialized || _commands == null) {
      debugPrint('[TTS] skipped because engine is unavailable: $normalized');
      return false;
    }

    final version = ++_speechVersion;
    _interactiveRequestActive = true;
    if (_cancellation != null && !_cancellation!.isCompleted) {
      _cancellation!.complete();
    }
    _cancellation = Completer<void>();
    await _audioPlayer.stop();

    final started = Completer<bool>();
    unawaited(
      _playSpeech(normalized, version, _cancellation!, started).whenComplete(
        () {
          if (version == _speechVersion) {
            _interactiveRequestActive = false;
            unawaited(_prewarm());
          }
        },
      ),
    );
    return started.future;
  }

  Future<void> _playSpeech(
    String text,
    int version,
    Completer<void> cancellation,
    Completer<bool> started,
  ) async {
    try {
      for (final chunk in chunkText(text)) {
        final path = await _getOrGenerate(chunk);
        if (version != _speechVersion || cancellation.isCompleted) {
          if (!started.isCompleted) started.complete(false);
          return;
        }

        final playbackComplete = _audioPlayer.onPlayerComplete.first;

        try {
          await _audioPlayer
              .play(DeviceFileSource(path))
              .timeout(const Duration(seconds: 10));
        } catch (e, st) {
          debugPrint('[TTS:play:error] text=$chunk : $e');
          debugPrintStack(stackTrace: st);
          if (!started.isCompleted) started.complete(false);
          return;
        }

        if (!started.isCompleted) started.complete(true);
        await Future.any([playbackComplete, cancellation.future]);
        if (version != _speechVersion || cancellation.isCompleted) return;
      }
    } catch (error, stackTrace) {
      debugPrint('[TTS] playback pipeline failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!started.isCompleted) started.complete(false);
    } finally {
      if (!started.isCompleted) started.complete(false);
    }
  }

  Future<void> stop() async {
    _speechVersion++;
    if (_cancellation != null && !_cancellation!.isCompleted) {
      _cancellation!.complete();
    }
    await _audioPlayer.stop();
    _isPlaying = false;
    notifyListeners();
  }

  Future<String> _getOrGenerate(String text) async {
    final key = sha256.convert(utf8.encode('$_cacheVersion\n$text')).toString();
    final file = File(p.join(_cacheDirectory!.path, 'tts_$key.wav'));
    if (await _isValidWav(file)) {
      await file.setLastModified(DateTime.now());
      debugPrint('[TTS:cache] hit text=$text path=${file.path}');
      return file.path;
    }

    debugPrint('[TTS:cache] miss text=$text');
    return _inFlightCacheWrites.putIfAbsent(file.path, () async {
      try {
        final path = await _generate(text, file.path);
        if (!await _isValidWav(File(path))) {
          throw StateError('Generated WAV is empty or invalid: $path');
        }
        unawaited(_enforceCacheLimit());
        return path;
      } finally {
        _inFlightCacheWrites.remove(file.path);
      }
    });
  }

  Future<String> _generate(String text, String outputPath) {
    final id = _nextGenerationId++;
    final completer = Completer<String>();
    _pendingGeneration[id] = completer;
    _commands!.send({
      'operation': 'generate',
      'id': id,
      'text': text,
      'outputPath': outputPath,
    });
    return completer.future;
  }

  Future<bool> _isValidWav(File file) async {
    try {
      return await file.exists() && await file.length() > 44;
    } catch (_) {
      return false;
    }
  }

  Future<void> _prewarm() async {
    if (_isPrewarming || _interactiveRequestActive || !_isInitialized) return;
    _isPrewarming = true;
    try {
      for (final prompt in _fixedPrompts) {
        if (_interactiveRequestActive || !_isInitialized) return;
        for (final chunk in chunkText(_normalize(prompt))) {
          try {
            await _getOrGenerate(chunk);
          } catch (error) {
            debugPrint('[TTS:prewarm] failed for "$chunk": $error');
          }
        }
      }
    } finally {
      _isPrewarming = false;
    }
  }

  Future<void> _enforceCacheLimit() async {
    final files =
        await _cacheDirectory!
            .list()
            .where(
              (entry) =>
                  entry is File && p.basename(entry.path).startsWith('tts_'),
            )
            .cast<File>()
            .toList();
    final entries = <({File file, FileStat stat})>[];
    var totalBytes = 0;
    for (final file in files) {
      final stat = await file.stat();
      totalBytes += stat.size;
      entries.add((file: file, stat: stat));
    }
    entries.sort((a, b) => a.stat.modified.compareTo(b.stat.modified));
    while (entries.length > _maxCacheEntries || totalBytes > _maxCacheBytes) {
      final oldest = entries.removeAt(0);
      totalBytes -= oldest.stat.size;
      await oldest.file.delete();
      debugPrint('[TTS:cache] evicted ${oldest.file.path}');
    }
  }

  static String _normalize(String text) =>
      text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  @visibleForTesting
  static List<String> chunkText(String text, {int maxCharacters = 120}) {
    final normalized = _normalize(text);
    if (normalized.isEmpty) return const [];
    final chunks = <String>[];
    var current = '';
    for (final word in normalized.split(' ')) {
      final candidate = current.isEmpty ? word : '$current $word';
      if (candidate.length > maxCharacters && current.isNotEmpty) {
        chunks.add(current);
        current = word;
      } else {
        current = candidate;
      }
      if (RegExp(r'[.!?]$').hasMatch(current)) {
        chunks.add(current);
        current = '';
      }
    }
    if (current.isNotEmpty) chunks.add(current);
    return chunks;
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
    _audioPlayer.dispose();
    for (final completer in _pendingGeneration.values) {
      if (!completer.isCompleted) {
        completer.completeError(StateError('TTS worker disposed.'));
      }
    }
    super.dispose();
  }
}

void _ttsWorkerMain(Map<String, dynamic> initialization) {
  final replyTo = initialization['replyTo'] as SendPort;
  final commands = ReceivePort();
  sherpa.OfflineTts? engine;
  try {
    if (Platform.isAndroid) ffi.DynamicLibrary.open('libonnxruntime.so');
    sherpa.initBindings();
    final modelConfig = sherpa.OfflineTtsModelConfig(
      vits: sherpa.OfflineTtsVitsModelConfig(
        model: initialization['modelPath'] as String,
        tokens: initialization['tokensPath'] as String,
        lexicon: '',
        noiseScale: 0.667,
        lengthScale: 1.0,
        noiseScaleW: 0.8,
      ),
      numThreads: 2,
      debug: false,
      provider: 'cpu',
    );
    engine = sherpa.OfflineTts(sherpa.OfflineTtsConfig(model: modelConfig));
    replyTo.send({'type': 'ready', 'commands': commands.sendPort});
  } catch (error) {
    engine?.free();
    commands.close();
    replyTo.send({'type': 'initError', 'error': error.toString()});
    return;
  }

  commands.listen((dynamic message) async {
    if (message is! Map) return;
    if (message['operation'] == 'dispose') {
      engine?.free();
      commands.close();
      Isolate.exit();
    }
    if (message['operation'] != 'generate') return;

    final id = message['id'] as int;
    final text = message['text'] as String;
    final outputPath = message['outputPath'] as String;
    final stopwatch = Stopwatch()..start();
    try {
      final audio = engine!.generate(text: text, sid: 0, speed: 1.0);
      if (audio.samples.isEmpty || audio.sampleRate <= 0) {
        throw StateError('VITS generated no audio samples.');
      }
      await _writeWav(outputPath, audio.samples, audio.sampleRate);
      stopwatch.stop();
      replyTo.send({
        'type': 'result',
        'id': id,
        'text': text,
        'path': outputPath,
        'elapsedMs': stopwatch.elapsedMilliseconds,
      });
    } catch (error) {
      replyTo.send({'type': 'error', 'id': id, 'error': error.toString()});
    }
  });
}

Future<void> _writeWav(
  String outputPath,
  Float32List samples,
  int sampleRate,
) async {
  final numBytes = samples.length * 2;
  final bytes = ByteData(44 + numBytes);
  const riff = [0x52, 0x49, 0x46, 0x46];
  const wave = [0x57, 0x41, 0x56, 0x45];
  const format = [0x66, 0x6d, 0x74, 0x20];
  const data = [0x64, 0x61, 0x74, 0x61];
  for (var i = 0; i < 4; i++) {
    bytes.setUint8(i, riff[i]);
    bytes.setUint8(8 + i, wave[i]);
    bytes.setUint8(12 + i, format[i]);
    bytes.setUint8(36 + i, data[i]);
  }
  bytes.setUint32(4, 36 + numBytes, Endian.little);
  bytes.setUint32(16, 16, Endian.little);
  bytes.setUint16(20, 1, Endian.little);
  bytes.setUint16(22, 1, Endian.little);
  bytes.setUint32(24, sampleRate, Endian.little);
  bytes.setUint32(28, sampleRate * 2, Endian.little);
  bytes.setUint16(32, 2, Endian.little);
  bytes.setUint16(34, 16, Endian.little);
  bytes.setUint32(40, numBytes, Endian.little);
  var offset = 44;
  for (final rawSample in samples) {
    final sample = rawSample.clamp(-1.0, 1.0);
    final pcm = (sample < 0 ? sample * 32768 : sample * 32767).toInt();
    bytes.setInt16(offset, pcm, Endian.little);
    offset += 2;
  }
  await File(outputPath).writeAsBytes(bytes.buffer.asUint8List(), flush: true);
}