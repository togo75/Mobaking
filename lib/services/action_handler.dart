import 'dart:async';

import 'package:flutter/foundation.dart';

import '../app_config.dart';
import '../models/voice_intent.dart';
import 'app_state.dart';
import 'auth_service.dart';
import 'database_service.dart';
import 'serious_python.dart';
import 'tts_service.dart';

class ActionException implements Exception {
  const ActionException(this.userMessage, this.technicalMessage);

  final String userMessage;
  final String technicalMessage;

  @override
  String toString() => 'ActionException: $technicalMessage';
}

class ActionResult {
  const ActionResult({required this.userMessage, this.speechStarted});

  final String userMessage;
  final Future<bool>? speechStarted;
}

class TransferDraft {
  const TransferDraft({
    required this.action,
    required this.amount,
    required this.target,
    required this.spokenAmount,
    required this.spokenTarget,
  });

  final String action;
  final int amount;
  final String target;
  final String spokenAmount;
  final String spokenTarget;

  bool get isMobileMoney => action == 'transfer_to_momo';

  String get summary =>
      isMobileMoney
          ? 'I ye $amount ci ni nimɔrɔ la: $target'
          : 'I ye $amount ci ni kɔnti la: $target';

  String get messageToSpeak =>
      isMobileMoney
          ? 'I ye $spokenAmount ci ni nimɔrɔ la: $spokenTarget'
          : 'I ye $spokenAmount ci ni kɔnti la: $spokenTarget';
}

class ActionHandler {
  ActionHandler({
    required AuthService auth,
    required DatabaseService database,
    required NumberService numbers,
    required TTSService tts,
    required AppState appState,
  }) : _auth = auth,
       _database = database,
       _numbers = numbers,
       _tts = tts,
       _appState = appState;

  final AuthService _auth;
  final DatabaseService _database;
  final NumberService _numbers;
  final TTSService _tts;
  final AppState _appState;

  // ✅ FIX — Mêmes clés que VoiceScreen, pour le fallback
  static const _phoneKeys = [
    'recipient_phone',
    'phone',
    'target',
    'account',
    'number',
  ];

  Future<TransferDraft> prepareTransfer({
    required String action,
    required String rawAmount,
    required String rawTarget,
  }) async {
    if (action != 'transfer_to_momo' && action != 'transfer_to_account') {
      throw ActionException(
        'Jago in ma dafalen. I ka segin ka a fɔ.',
        'Unsupported transfer action: $action',
      );
    }
    if (rawAmount.trim().isEmpty || rawTarget.trim().isEmpty) {
      throw const ActionException(
        'Wari hakɛ walima nimɔrɔ ma sɔrɔ. I ka segin ka a fɔ.',
        'Transfer amount or target is empty.',
      );
    }

    final stopwatch = Stopwatch()..start();
    try {
      late int amount;
      late String target;
      late String spokenAmount;
      late String spokenTarget;

      if (AppConfig.dataCollectionEnabled) {
        final cleanAmount = rawAmount.replaceAll('-', '').trim();
        target = rawTarget.replaceAll(RegExp(r'[-\s,]'), '');
        amount = int.tryParse(cleanAmount) ?? 0;
        if (amount <= 0 || !RegExp(r'^\d+$').hasMatch(target)) {
          throw const ActionException(
            'Wari hakɛ walima nimɔrɔ ma dafalen.',
            'Typed transfer fields are invalid.',
          );
        }
        final spoken = await Future.wait([
          _numbers.spellNumber(amount.toString()),
          _numbers.spellNumber(target.split('').join(','), isAmount: false),
        ]);
        spokenAmount = spoken[0];
        spokenTarget = spoken[1];
      } else {
        final parsed = await Future.wait<Object>([
          _numbers.parseAmount(rawAmount),
          _numbers.parseDigitSequence(rawTarget),
        ]);
        amount = parsed[0] as int;
        target = parsed[1] as String;
        spokenAmount = rawAmount.trim();
        spokenTarget = rawTarget.trim();
      }

      stopwatch.stop();
      debugPrint(
        '[ACTION:prepareTransfer] action=$action amount=$amount target=$target '
        'elapsedMs=${stopwatch.elapsedMilliseconds}',
      );
      return TransferDraft(
        action: action,
        amount: amount,
        target: target,
        spokenAmount: spokenAmount,
        spokenTarget: spokenTarget,
      );
    } on ActionException {
      rethrow;
    } catch (error, stackTrace) {
      debugPrint('[ACTION:prepareTransfer] failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      throw ActionException(
        'Wari hakɛ walima nimɔrɔ ma se ka faamu. I ka segin ka a fɔ.',
        error.toString(),
      );
    }
  }

  Future<ActionResult> execute(
    VoiceIntent intent, {
    TransferDraft? transfer,
  }) async {
    final stopwatch = Stopwatch()..start();
    debugPrint('[ACTION] start intent=$intent');
    try {
      final result = switch (intent.scenario) {
        'Navigate' => await _executeNavigation(intent),
        'Operation' => await _executeOperation(intent, transfer),
        'FAQ' => await _executeFaq(intent),
        _ =>
          throw ActionException(
            'Baara in ma dɔn. I ka segin ka a fɔ.',
            'Unsupported scenario: ${intent.scenario}',
          ),
      };
      stopwatch.stop();
      debugPrint(
        '[ACTION] success action=${intent.action} elapsedMs=${stopwatch.elapsedMilliseconds}',
      );
      return result;
    } on ActionException {
      rethrow;
    } on InsufficientFundsException catch (error) {
      unawaited(_tts.speak('I ka wari jate tɛ a bɔ.'));
      throw ActionException('I ka wari jate tɛ a bɔ.', error.toString());
    } catch (error, stackTrace) {
      debugPrint('[ACTION] failed action=${intent.action}: $error');
      debugPrintStack(stackTrace: stackTrace);
      throw ActionException(
        'Gɛlɛya dɔ sɔrɔla. I ka segin ka a lajɛ.',
        error.toString(),
      );
    }
  }

  Future<ActionResult> _executeNavigation(VoiceIntent intent) async {
    if (intent.action == 'logout') {
      await _tts.stop();
      await _auth.signOut();
      return const ActionResult(userMessage: 'I bɔra ka ɲɛ.');
    }

    final page = intent.entityMap['page'];
    const pages = {'Home': 0, 'Operations': 1, 'FAQ': 2, 'Profile': 3};
    final index = pages[page];
    if (index == null) {
      throw ActionException(
        'Ɲɛ in ma sɔrɔ. I ka segin ka a fɔ.',
        'Maps_to needs a supported page entity; received $page.',
      );
    }
    _appState.navigateTo(index);
    return ActionResult(
      userMessage: 'Ɲɛ yɛlɛmana.',
      speechStarted: _tts.speak("K'i ɲɛda $page kan"),
    );
  }

  Future<ActionResult> _executeOperation(
    VoiceIntent intent,
    TransferDraft? transfer,
  ) async {
    if (intent.action == 'get_balance') {
      _appState.navigateTo(0);
      _appState.revealBalance();
      final balance = await _database.getCurrentBalance();
      final spokenBalance = await _numbers.spellNumber(
        balance.toInt().toString(),
      );
      return ActionResult(
        userMessage: 'I ka wari jate bɔra.',
        speechStarted: _tts.speak('I ka wari jate bɛ bɛn: $spokenBalance'),
      );
    }

    // ✅ FIX — Fallback : reconstruire un draft si absent
    if (transfer == null || transfer.action != intent.action) {
      debugPrint(
        '[ACTION] transfer draft missing, attempting fallback rebuild '
        'for action=${intent.action}',
      );
      final rawAmount = intent.entityMap['amount'] ?? '';
      final rawTarget = intent.entityFirst(_phoneKeys) ?? '';
      if (rawAmount.isEmpty || rawTarget.isEmpty) {
        throw const ActionException(
          'Jago kunnafoni ma dafalen.',
          'A validated transfer draft is required (no fallback possible: '
          'missing amount or target).',
        );
      }
      transfer = await prepareTransfer(
        action: intent.action,
        rawAmount: rawAmount,
        rawTarget: rawTarget,
      );
    }

    final transactionId = await _database.executeTransfer(
      amount: transfer.amount,
      target: transfer.target,
      summary: transfer.summary,
      messageToSpeak: transfer.messageToSpeak,
    );
    _appState.navigateTo(1);
    _appState.setHighlightedTransaction(transactionId);
    return ActionResult(
      userMessage: 'Jago ɲɛnabɔra!',
      speechStarted: _tts.speak(transfer.messageToSpeak),
    );
  }

  Future<ActionResult> _executeFaq(VoiceIntent intent) async {
    final topic = intent.entityMap['topic'];
    final category = intent.entityMap['category'];
    if (topic == null ||
        category == null ||
        topic.isEmpty ||
        category.isEmpty) {
      throw const ActionException(
        'Ɲininkali kunnafoni ma dafalen. I ka segin ka a fɔ.',
        'search_faq requires topic and category entities.',
      );
    }
    _appState.setFaqFilter(topic, category);
    _appState.navigateTo(2);
    return ActionResult(
      userMessage: 'Ɲininkali jaabiw sɔrɔla.',
      speechStarted: _tts.speak('I ka ɲininkali jaabi bɛ sɔrɔ ninnu cɛma'),
    );
  }
}