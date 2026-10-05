import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'storage_service.dart';

class ModelArtifact {
  const ModelArtifact({
    required this.id,
    required this.label,
    required this.remotePath,
    required this.relativePath,
    required this.expectedBytes,
    required this.sha256Digest,
  });

  final String id;
  final String label;
  final String remotePath;
  final String relativePath;
  final int expectedBytes;
  final String sha256Digest;
}

abstract final class AppModels {
  static const version = '2026-09-02-v1';
  static const remoteRoot = 'models/$version';

  static const numberAsr = ModelArtifact(
    id: 'number-asr',
    label: 'number ASR',
    remotePath: '$remoteRoot/asr/quartznum.onnx',
    relativePath: 'asr/quartznum.onnx',
    expectedBytes: 75623630,
    sha256Digest:
        '65c39ead3d659e9198436e154135542420b63cb8b9cde93371fa8ae170d19cec',
  );
  static const sluEncoder = ModelArtifact(
    id: 'slu-encoder',
    label: 'SLU encoder',
    remotePath: '$remoteRoot/slu/soloni-ic-slot-fintech-v0-encoder.onnx',
    relativePath: 'slu/soloni-ic-slot-fintech-v0-encoder.onnx',
    expectedBytes: 456149978,
    sha256Digest:
        '5b345aa5c80cec5d40f5630bd3ba6200e19784dfacab200bd8954f7011154579',
  );
  static const sluEmbedding = ModelArtifact(
    id: 'slu-embedding',
    label: 'SLU embedding',
    remotePath: '$remoteRoot/slu/soloni-ic-slot-fintech-v0-embedding.onnx',
    relativePath: 'slu/soloni-ic-slot-fintech-v0-embedding.onnx',
    expectedBytes: 1157852,
    sha256Digest:
        'fff68691b1d18d5364f803dd8707bc89bc8fa8ff4420c5f9ac3cba783da246bb',
  );
  static const sluDecoder = ModelArtifact(
    id: 'slu-decoder',
    label: 'SLU decoder',
    remotePath: '$remoteRoot/slu/soloni-ic-slot-fintech-v0-decoder.onnx',
    relativePath: 'slu/soloni-ic-slot-fintech-v0-decoder.onnx',
    expectedBytes: 37961958,
    sha256Digest:
        '3d5dea9207069d3f728924910339296006688322359df0655cd653e84f69de96',
  );
  static const sluClassifier = ModelArtifact(
    id: 'slu-classifier',
    label: 'SLU classifier',
    remotePath: '$remoteRoot/slu/soloni-ic-slot-fintech-v0-classifier.onnx',
    relativePath: 'slu/soloni-ic-slot-fintech-v0-classifier.onnx',
    expectedBytes: 103155,
    sha256Digest:
        '480ee69b05154e2e189c7f08aed708d5c47cbadf00cf084d28571ed13ca54a21',
  );
  static const vits = ModelArtifact(
    id: 'vits',
    label: 'VITS TTS',
    remotePath: '$remoteRoot/vits/bam-vits.onnx',
    relativePath: 'vits/bam-vits.onnx',
    expectedBytes: 121435416,
    sha256Digest:
        '2ba86b4a20f6bd7ae87cb97270a51ad75ba15b06252c6d18340b6f33a1958893',
  );

  static const all = [
    sluEncoder,
    sluDecoder,
    sluEmbedding,
    sluClassifier,
    numberAsr,
    vits,
  ];

  static const totalBytes = 692431989;
}

class ModelDownloadService extends ChangeNotifier {
  ModelDownloadService({required StorageService storage}) : _storage = storage;

  final StorageService _storage;
  final Map<String, String> _localPaths = {};

  Future<void>? _initialization;
  bool _isReady = false;
  bool _isLoading = false;
  bool _disposed = false;
  String? _error;
  String? _currentLabel;
  String _operation = 'Checking';
  int _completedBytes = 0;
  int _currentBytes = 0;
  int _lastNotifiedBytes = 0;

  bool get isReady => _isReady;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get currentLabel => _currentLabel;
  String get operation => _operation;
  int get totalBytes => AppModels.totalBytes;

  int get downloadedBytes {
    final value = _completedBytes + _currentBytes;
    return value > totalBytes ? totalBytes : value;
  }

  double get progress => totalBytes == 0 ? 0 : downloadedBytes / totalBytes;

  Future<void> init() {
    return _initialization ??= _initialize().whenComplete(
      () => _initialization = null,
    );
  }

  Future<void> _initialize() async {
    if (_isReady) return;
    _isLoading = true;
    _isReady = false;
    _error = null;
    _completedBytes = 0;
    _currentBytes = 0;
    _lastNotifiedBytes = 0;
    _notify();
    final stopwatch = Stopwatch()..start();

    try {
      final supportDirectory = await getApplicationSupportDirectory();
      final versionDirectory = Directory(
        p.join(supportDirectory.path, 'remote_models', AppModels.version),
      );
      await versionDirectory.create(recursive: true);

      for (final artifact in AppModels.all) {
        _currentLabel = artifact.label;
        _operation = 'Checking';
        _currentBytes = 0;
        _notify();

        final path = await _ensureArtifact(versionDirectory, artifact);
        _localPaths[artifact.id] = path;
        _completedBytes += artifact.expectedBytes;
        _currentBytes = 0;
        _notify();
      }

      await _deleteLegacyBundledModels(supportDirectory);
      await _deleteStaleVersions(versionDirectory.parent);

      _currentLabel = null;
      _operation = 'Ready';
      _isLoading = false;
      _isReady = true;
      stopwatch.stop();
      debugPrint(
        '[MODEL:init] ready bytes=$totalBytes '
        'elapsedMs=${stopwatch.elapsedMilliseconds}',
      );
      _notify();
    } catch (error, stackTrace) {
      _isLoading = false;
      _isReady = false;
      _error = error.toString();
      stopwatch.stop();
      debugPrint(
        '[MODEL:init] failed model=$_currentLabel '
        'elapsedMs=${stopwatch.elapsedMilliseconds}: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
      _notify();
      rethrow;
    }
  }

  String pathFor(ModelArtifact artifact) {
    final path = _localPaths[artifact.id];
    if (!_isReady || path == null) {
      throw StateError('Model is not ready: ${artifact.label}');
    }
    return path;
  }

  Future<String> _ensureArtifact(
    Directory versionDirectory,
    ModelArtifact artifact,
  ) async {
    final localFile = File(
      p.join(versionDirectory.path, artifact.relativePath),
    );
    final checksumFile = File('${localFile.path}.sha256');
    await localFile.parent.create(recursive: true);

    if (await _isValidCachedFile(localFile, checksumFile, artifact)) {
      debugPrint(
        '[MODEL:cache] hit model=${artifact.label} '
        'bytes=${artifact.expectedBytes}',
      );
      return localFile.path;
    }

    if (await localFile.exists()) await localFile.delete();
    if (await checksumFile.exists()) await checksumFile.delete();

    final partialFile = File('${localFile.path}.part');
    if (await partialFile.exists()) await partialFile.delete();

    _operation = 'Downloading';
    var nextLogPercent = 0;
    debugPrint(
      '[MODEL:download] start model=${artifact.label} '
      'remote=${artifact.remotePath} bytes=${artifact.expectedBytes}',
    );
    await _storage.downloadFile(
      remotePath: artifact.remotePath,
      destination: partialFile,
      onProgress: (transferred, _) {
        _currentBytes =
            transferred > artifact.expectedBytes
                ? artifact.expectedBytes
                : transferred;
        final percent =
            artifact.expectedBytes == 0
                ? 0
                : (_currentBytes * 100 ~/ artifact.expectedBytes);
        if (percent >= nextLogPercent) {
          debugPrint(
            '[MODEL:download] model=${artifact.label} progress=$percent% '
            'bytes=$_currentBytes/${artifact.expectedBytes}',
          );
          nextLogPercent = percent + 10;
        }
        if ((downloadedBytes - _lastNotifiedBytes).abs() >= 1024 * 1024 ||
            _currentBytes == artifact.expectedBytes) {
          _lastNotifiedBytes = downloadedBytes;
          _notify();
        }
      },
    );

    final actualBytes = await partialFile.length();
    if (actualBytes != artifact.expectedBytes) {
      await partialFile.delete();
      throw StateError(
        '${artifact.label} size mismatch: '
        'expected ${artifact.expectedBytes}, got $actualBytes.',
      );
    }

    _operation = 'Verifying';
    _notify();
    final digest = await sha256.bind(partialFile.openRead()).first;
    if (digest.toString() != artifact.sha256Digest) {
      await partialFile.delete();
      throw StateError('${artifact.label} checksum mismatch.');
    }

    await partialFile.rename(localFile.path);
    await checksumFile.writeAsString(artifact.sha256Digest, flush: true);
    debugPrint(
      '[MODEL:download] ready model=${artifact.label} bytes=$actualBytes',
    );
    return localFile.path;
  }

  Future<bool> _isValidCachedFile(
    File localFile,
    File checksumFile,
    ModelArtifact artifact,
  ) async {
    if (!await localFile.exists() ||
        await localFile.length() != artifact.expectedBytes) {
      return false;
    }

    if (await checksumFile.exists() &&
        (await checksumFile.readAsString()).trim() == artifact.sha256Digest) {
      return true;
    }

    _operation = 'Verifying';
    _notify();
    final digest = await sha256.bind(localFile.openRead()).first;
    if (digest.toString() != artifact.sha256Digest) return false;
    await checksumFile.writeAsString(artifact.sha256Digest, flush: true);
    return true;
  }

  Future<void> _deleteLegacyBundledModels(Directory supportDirectory) async {
    final legacyDirectory = Directory(
      p.join(supportDirectory.path, 'model_assets'),
    );
    if (!await legacyDirectory.exists()) return;

    await for (final entity in legacyDirectory.list(recursive: true)) {
      if (entity is File && entity.path.endsWith('.onnx')) {
        await entity.delete();
        debugPrint('[MODEL:cleanup] deleted legacy=${entity.path}');
      }
    }
  }

  Future<void> _deleteStaleVersions(Directory versionsDirectory) async {
    if (!await versionsDirectory.exists()) return;
    await for (final entity in versionsDirectory.list()) {
      if (entity is Directory && p.basename(entity.path) != AppModels.version) {
        await entity.delete(recursive: true);
        debugPrint('[MODEL:cleanup] deleted stale=${entity.path}');
      }
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
