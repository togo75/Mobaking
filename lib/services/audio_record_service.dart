import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class AudioRecordService {
  final AudioRecorder _audioRecorder = AudioRecorder();
  String? _currentFilePath;

  Future<bool> checkPermission() => _audioRecorder.hasPermission();

  Future<void> startRecording(String fileName) async {
    if (!await checkPermission()) {
      debugPrint('[RECORD] microphone permission denied');
      throw StateError('Microphone permission denied.');
    }
    final directory = await getTemporaryDirectory();
    _currentFilePath = '${directory.path}/$fileName.wav';
    const config = RecordConfig(
      encoder: AudioEncoder.wav,
      sampleRate: 16000,
      numChannels: 1,
    );
    try {
      await _audioRecorder.start(config, path: _currentFilePath!);
      debugPrint('[RECORD] started path=$_currentFilePath');
    } catch (error, stackTrace) {
      debugPrint('[RECORD] start failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<String> stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      if (path == null || path.isEmpty) {
        throw StateError('Recorder did not return an audio path.');
      }
      debugPrint('[RECORD] stopped path=$path');
      return path;
    } catch (error, stackTrace) {
      debugPrint('[RECORD] stop failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> deleteTemporaryFile([String? path]) async {
    final target = path ?? _currentFilePath;
    if (target == null) return;
    final file = File(target);
    if (await file.exists()) {
      await file.delete();
      debugPrint('[RECORD] deleted path=$target');
    }
    if (target == _currentFilePath) _currentFilePath = null;
  }

  void dispose() => _audioRecorder.dispose();
}
