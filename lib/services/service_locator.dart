import 'package:flutter/foundation.dart';

import 'action_handler.dart';
import 'app_state.dart';
import 'audio_record_service.dart';
import 'auth_service.dart';
import 'database_service.dart';
import 'model_download_service.dart';
import 'serious_python.dart';
import 'slu_asr_service.dart';
import 'storage_service.dart';
import 'tts_service.dart';

class ServiceLocator {
  ServiceLocator._();
  static final ServiceLocator instance = ServiceLocator._();

  late final AuthService auth;
  late final DatabaseService database;
  late final StorageService storage;
  late final ModelDownloadService models;
  late final SluAsrService slu;
  late final TTSService tts;
  late final NumberService numbers;
  late final AudioRecordService recorder;
  late final AppState appState;
  late final ActionHandler actions;

  bool _initialized = false;
  bool _heavyInitStarted = false;

  bool get isInitialized => _initialized;

  /// Initialisation LÉGÈRE : uniquement les services essentiels.
  /// Ne bloque PAS sur le téléchargement des modèles.
  Future<void> init() async {
    if (_initialized) return;

    debugPrint('[BOOTSTRAP] ServiceLocator.init() démarrage');

    // ✅ Instanciation SYNCHRONE (rapide, pas de I/O)
    storage = StorageService();
    auth = AuthService();
    database = DatabaseService();
    models = ModelDownloadService(storage: storage);
    slu = SluAsrService(models: models);
    tts = TTSService(models: models);
    numbers = NumberService();
    recorder = AudioRecordService();
    appState = AppState();
    actions = ActionHandler(
      auth: auth,
      database: database,
      numbers: numbers,
      tts: tts,
      appState: appState,
    );

    _initialized = true;
    debugPrint('[BOOTSTRAP] ServiceLocator init prêt (léger)');

    // ✅ Initialisation LOURDE en arrière-plan (non bloquante)
    _startHeavyInit();
  }

  /// Initialisation LOURDE en arrière-plan.
  /// Ne bloque PAS le splash.
  void _startHeavyInit() {
    if (_heavyInitStarted) return;
    _heavyInitStarted = true;

    // Lance en parallèle sans await
    Future(() async {
      debugPrint('[BOOTSTRAP] Heavy init démarré (arrière-plan)');
      final stopwatch = Stopwatch()..start();

      // 1. Modèles (téléchargement)
      try {
        await models.init();
        debugPrint('[BOOTSTRAP] models.init terminé');
      } catch (e) {
        debugPrint('[BOOTSTRAP] models.init failed: $e');
      }

      // 2. Services vocaux
      try {
        await Future.wait([slu.init(), tts.init(), numbers.init()]);
        debugPrint('[BOOTSTRAP] voice services init terminé');
      } catch (e) {
        debugPrint('[BOOTSTRAP] voice services init failed: $e');
      }

      stopwatch.stop();
      debugPrint(
        '[BOOTSTRAP] all services ready '
        'elapsedMs=${stopwatch.elapsedMilliseconds}',
      );
    });
  }

  void dispose() {
    slu.dispose();
    tts.dispose();
    numbers.dispose();
    recorder.dispose();
    models.dispose();
    appState.dispose();
    storage.dispose();
  }
}