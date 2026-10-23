import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:serious_python/serious_python.dart';

class NumberConversionException implements Exception {
  const NumberConversionException(this.message, {this.responseBody});

  final String message;
  final String? responseBody;

  @override
  String toString() => 'NumberConversionException: $message';
}

class NumberService extends ChangeNotifier {
  NumberService({http.Client? client}) : _client = client ?? http.Client();

  static final Uri _healthUrl = Uri.parse('http://127.0.0.1:55001/health');
  static final Uri _spellUrl = Uri.parse(
    'http://127.0.0.1:55001/getSpelledNum',
  );
  static final Uri _digitsUrl = Uri.parse('http://127.0.0.1:55001/getDigits');

  final http.Client _client;
  Future<void>? _initialization;
  bool _isReady = false;
  bool _isLoading = false;
  String? _initializationError;

  bool get isReady => _isReady;
  bool get isLoading => _isLoading;
  String? get initializationError => _initializationError;

  Future<void> init() {
    return _initialization ??= _initialize().whenComplete(
      () => _initialization = null,
    );
  }

  Future<void> _initialize() async {
    if (_isReady) return;
    _isLoading = true;
    _initializationError = null;
    notifyListeners();
    final stopwatch = Stopwatch()..start();
    try {
      if (await _probeHealth()) return;
      unawaited(
        SeriousPython.run('app/app.zip')
            .then((result) {
              debugPrint('[PY:runtime] interpreter exited result=$result');
              _isReady = false;
              _initializationError = 'Embedded Python interpreter exited.';
              notifyListeners();
            })
            .catchError((Object error, StackTrace stackTrace) {
              debugPrint('[PY:runtime] interpreter failed: $error');
              debugPrintStack(stackTrace: stackTrace);
            }),
      );
      const delays = [100, 200, 400, 800, 1200, 1600, 2000, 2000];
      Object? lastError;
      for (final delay in delays) {
        try {
          final response = await _client
              .get(_healthUrl)
              .timeout(const Duration(seconds: 1));
          debugPrint(
            '[PY:health] status=${response.statusCode} body=${response.body}',
          );
          if (response.statusCode == 200) {
            _isReady = true;
            _isLoading = false;
            stopwatch.stop();
            debugPrint(
              '[PY:init] ready in ${stopwatch.elapsedMilliseconds} ms',
            );
            notifyListeners();
            return;
          }
          lastError = StateError(
            'Health endpoint returned ${response.statusCode}',
          );
        } catch (error) {
          lastError = error;
        }
        await Future<void>.delayed(Duration(milliseconds: delay));
      }
      throw StateError('Python backend did not become ready: $lastError');
    } catch (error, stackTrace) {
      _isReady = false;
      _isLoading = false;
      _initializationError = error.toString();
      debugPrint(
        '[PY:init] failed after ${stopwatch.elapsedMilliseconds} ms: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
      notifyListeners();
      rethrow;
    }
  }

  Future<bool> _probeHealth() async {
    try {
      final response = await _client
          .get(_healthUrl)
          .timeout(const Duration(milliseconds: 500));
      if (response.statusCode != 200) return false;
      _isReady = true;
      _isLoading = false;
      _initializationError = null;
      debugPrint('[PY:health] existing backend is ready body=${response.body}');
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<String> spellNumber(String number, {bool isAmount = true}) async {
    final value = number.trim();
    if (value.isEmpty) {
      throw const NumberConversionException('Number to spell is empty.');
    }
    final data = await _postJson(_spellUrl, {
      'number': value,
      'is_amount': isAmount,
    });
    final spelled = data['spelled_number'];
    if (spelled is! String || spelled.trim().isEmpty) {
      throw NumberConversionException(
        'getSpelledNum returned an invalid spelled_number.',
        responseBody: jsonEncode(data),
      );
    }
    debugPrint('[PY:getSpelledNum] parsed=${spelled.trim()}');
    return spelled.trim();
  }

  Future<int> parseAmount(String phrase) async {
    final digits = await _parseDigits(phrase, isAmount: true);
    final amount = int.tryParse(digits);
    if (amount == null || amount <= 0) {
      throw NumberConversionException(
        'getDigits returned an invalid positive amount: $digits',
      );
    }
    debugPrint('[PY:getDigits] parsedAmount=$amount');
    return amount;
  }

  Future<String> parseDigitSequence(String phrase) async {
    final digits = await _parseDigits(phrase, isAmount: false);
    if (digits.isEmpty || !RegExp(r'^\d+$').hasMatch(digits)) {
      throw NumberConversionException(
        'getDigits returned an invalid digit sequence: $digits',
      );
    }
    debugPrint('[PY:getDigits] parsedSequence=$digits');
    return digits;
  }

  Future<String> _parseDigits(String phrase, {required bool isAmount}) async {
    final value = phrase.trim();
    if (value.isEmpty) {
      throw const NumberConversionException('Phrase to parse is empty.');
    }
    final data = await _postJson(_digitsUrl, {
      'phrase': value,
      'is_amount': isAmount,
    });
    final rawDigits = data['digits'];
    if (rawDigits is! String || rawDigits.trim().isEmpty) {
      throw NumberConversionException(
        'getDigits returned an invalid digits field.',
        responseBody: jsonEncode(data),
      );
    }
    return rawDigits.trim();
  }

  Future<Map<String, dynamic>> _postJson(
    Uri endpoint,
    Map<String, dynamic> payload,
  ) async {
    if (!_isReady) {
      throw const NumberConversionException('Python backend is not ready.');
    }
    final stopwatch = Stopwatch()..start();
    debugPrint('[PY:${endpoint.pathSegments.last}] request=$payload');
    try {
      final response = await _client
          .post(
            endpoint,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 5));
      stopwatch.stop();
      debugPrint(
        '[PY:${endpoint.pathSegments.last}] status=${response.statusCode} '
        'body=${response.body} elapsedMs=${stopwatch.elapsedMilliseconds}',
      );
      if (response.statusCode != 200) {
        throw NumberConversionException(
          '${endpoint.path} returned HTTP ${response.statusCode}.',
          responseBody: response.body,
        );
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw NumberConversionException(
          '${endpoint.path} returned a non-object JSON response.',
          responseBody: response.body,
        );
      }
      return decoded;
    } on NumberConversionException {
      rethrow;
    } catch (error, stackTrace) {
      stopwatch.stop();
      debugPrint('[PY:${endpoint.pathSegments.last}] failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      throw NumberConversionException(
        '${endpoint.path} request failed: $error',
      );
    }
  }

  @override
  void dispose() {
    _client.close();
    // Keep the embedded interpreter alive across Flutter hot restarts. The next
    // NumberService instance reuses it through /health; Android owns final
    // process teardown when the application exits.
    super.dispose();
  }
}
