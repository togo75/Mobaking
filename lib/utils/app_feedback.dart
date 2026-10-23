import 'package:flutter/material.dart';

import '../services/tts_service.dart';

abstract final class AppFeedback {
  static const intentFailure =
      'SLU returned an invalid intent. Record the command again and check [SLU] logs.';
  static const actionFailure =
      'Action execution failed. Check [ACTION] and [DB] logs, then retry.';
  static const microphoneUnavailable =
      'ASR/SLU models are unavailable. Tap this banner to retry initialization.';
  static const voiceLoading = 'Initializing ASR and SLU models...';
  static const processing = 'Running SLU intent inference...';
  static const success = 'Action completed.';
  static const asrFailure =
      'ASR could not transcribe the recording. Record that value again and check [ASR] logs.';
  static const recordingFailure =
      'Audio recording failed. Check microphone permission and [RECORD] logs.';
  static const ttsFailure =
      'TTS could not generate or play audio. Check [TTS] logs.';

  static void showError(BuildContext context, String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  static Future<void> speak(
    BuildContext context,
    TTSService tts,
    String text,
  ) async {
    final started = await tts.speak(text);
    if (!started && context.mounted) {
      showError(context, ttsFailure);
    }
  }

  static void showInfo(BuildContext context, String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }
}
