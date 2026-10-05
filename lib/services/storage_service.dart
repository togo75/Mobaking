import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class StorageService {
  StorageService({http.Client? client}) : _client = client ?? http.Client();

  static const String _bucket = 'africa-voice-mali.firebasestorage.app';

  final http.Client _client;

  Future<String> uploadVoiceFile(String localPath, String remotePath) async {
    throw UnimplementedError(
      'Upload is disabled. Voice annotations are not required for the demo.',
    );
  }

  Future<void> downloadFile({
    required String remotePath,
    required File destination,
    required void Function(int transferred, int total) onProgress,
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      await destination.parent.create(recursive: true);

      final encoded = Uri.encodeComponent(remotePath);
      final uri = Uri.parse(
        'https://firebasestorage.googleapis.com/v0/b/$_bucket/o/$encoded?alt=media',
      );

      debugPrint('[STORAGE:download] GET $uri');

      final request = http.Request('GET', uri);
      final response = await _client.send(request);

      if (response.statusCode != 200) {
        throw StateError(
          'Download failed: HTTP ${response.statusCode} for $remotePath',
        );
      }

      final total = response.contentLength ?? 0;
      var transferred = 0;

      final sink = destination.openWrite();
      try {
        await for (final chunk in response.stream) {
          sink.add(chunk);
          transferred += chunk.length;
          onProgress(transferred, total);
        }
      } finally {
        await sink.close();
      }

      onProgress(transferred, total);
      stopwatch.stop();
      debugPrint(
        '[STORAGE:download] completed remotePath=$remotePath '
        'bytes=$transferred '
        'elapsedMs=${stopwatch.elapsedMilliseconds}',
      );
    } catch (error, stackTrace) {
      stopwatch.stop();
      debugPrint(
        '[STORAGE:download] failed remotePath=$remotePath '
        'elapsedMs=${stopwatch.elapsedMilliseconds}: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  void dispose() => _client.close();
}