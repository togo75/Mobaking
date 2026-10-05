import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class AssetManager {
  static const String _modelAssetVersion = '2026-09-02-v1';
  static Future<void> _copyQueue = Future<void>.value();

  /// Copies large model assets one at a time to avoid first-launch memory spikes.
  /// The versioned directory prevents an older extracted model from surviving an
  /// application update that ships new bytes under the same asset filename.
  static Future<String> copyAssetToLocal(String assetPath) {
    final completer = Completer<String>();
    _copyQueue = _copyQueue.then((_) async {
      try {
        completer.complete(await _copyOne(assetPath));
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  static Future<String> _copyOne(String assetPath) async {
    try {
      final supportDirectory = await getApplicationSupportDirectory();
      final modelDirectory = Directory(
        p.join(supportDirectory.path, 'model_assets', _modelAssetVersion),
      );
      await modelDirectory.create(recursive: true);
      final localFile = File(
        p.join(modelDirectory.path, p.basename(assetPath)),
      );
      if (!await localFile.exists() || await localFile.length() == 0) {
        final stopwatch = Stopwatch()..start();
        final byteData = await rootBundle.load(assetPath);
        await localFile.writeAsBytes(
          byteData.buffer.asUint8List(
            byteData.offsetInBytes,
            byteData.lengthInBytes,
          ),
          flush: true,
        );
        stopwatch.stop();
        debugPrint(
          '[ASSET] copied $assetPath bytes=${byteData.lengthInBytes} '
          'elapsedMs=${stopwatch.elapsedMilliseconds}',
        );
      }
      return localFile.path;
    } catch (error) {
      throw StateError("Failed to extract asset '$assetPath': $error");
    }
  }
}
