// lib/app_config.dart

class AppConfig {
  // Global toggle for research data collection
  // If false, bypasses annotation modal and executes intents directly [cite: 166]
  static const bool dataCollectionEnabled = false;

  // Secondary Firebase Project Details
  static const String storageProjectName = 'Storage Project';
  static const String storageBucketUrl =
      'africa-voice-mali.firebasestorage.app';
}
