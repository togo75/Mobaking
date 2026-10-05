import 'dart:convert';
import 'package:flutter/foundation.dart';

class VoiceIntentFormatException implements Exception {
  const VoiceIntentFormatException(this.message, {this.rawOutput});

  final String message;
  final String? rawOutput;

  @override
  String toString() => 'VoiceIntentFormatException: $message';
}

class VoiceEntity {
  const VoiceEntity({required this.type, required this.filler});

  final String type;
  final String filler;

  @override
  String toString() => '$type=$filler';
}

class VoiceIntent {
  const VoiceIntent({
    required this.scenario,
    required this.action,
    required this.entities,
  });

  static const Map<String, Set<String>> supportedActions = {
    'Navigate': {'Maps_to', 'logout'},
    'Operation': {'get_balance', 'transfer_to_account', 'transfer_to_momo'},
    'FAQ': {'search_faq'},
  };

  // ✅ FIX 1 — Alias d'actions pour tolérer les variantes du SLU
  static const Map<String, String> _actionAliases = {
    'transfer_momo': 'transfer_to_momo',
    'transfer_mobile_money': 'transfer_to_momo',
    'transfer_to_mobile_money': 'transfer_to_momo',
    'transfer_account': 'transfer_to_account',
    'transfer_bank': 'transfer_to_account',
    'transfer_to_bank': 'transfer_to_account',
    'balance': 'get_balance',
    'check_balance': 'get_balance',
    'see_balance': 'get_balance',
    'navigate': 'Maps_to',
    'map': 'Maps_to',
    'maps_to': 'Maps_to',
    'searchfaq': 'search_faq',
    'faq': 'search_faq',
  };

  final String scenario;
  final String action;
  final List<VoiceEntity> entities;

  bool get isTransfer => action.startsWith('transfer_');
  bool get isLogout => scenario == 'Navigate' && action == 'logout';

  Map<String, String> get entityMap => {
        for (final entity in entities) entity.type: entity.filler,
      };

  /// Première entité non vide parmi [keys].
  String? entityFirst(List<String> keys) {
    for (final k in keys) {
      final v = entityMap[k];
      if (v != null && v.trim().isNotEmpty) return v;
    }
    return null;
  }

  factory VoiceIntent.fromRawJson(String rawOutput) {
    final dynamic decoded;
    try {
      decoded = _decodeStructuredOutput(rawOutput);
    } on FormatException catch (error) {
      throw VoiceIntentFormatException(
        'Model output is neither JSON nor a supported SLU map literal: $error',
        rawOutput: rawOutput,
      );
    }

    if (decoded is! Map<String, dynamic>) {
      throw VoiceIntentFormatException(
        'Model output must be a JSON object.',
        rawOutput: rawOutput,
      );
    }

    final rawScenario = decoded['scenario'];
    final rawAction = decoded['action'];
    final rawEntities = decoded['entities'];

    if (rawScenario is! String || rawScenario.trim().isEmpty) {
      throw VoiceIntentFormatException(
        'Missing or invalid scenario.',
        rawOutput: rawOutput,
      );
    }
    if (rawAction is! String || rawAction.trim().isEmpty) {
      throw VoiceIntentFormatException(
        'Missing or invalid action.',
        rawOutput: rawOutput,
      );
    }
    if (rawEntities is! List) {
      throw VoiceIntentFormatException(
        'Missing or invalid entities list.',
        rawOutput: rawOutput,
      );
    }

    // ✅ FIX 2 — Normalisation casse (insensible) pour le scenario
    final scenario = _canonicalScenario(rawScenario);

    // ✅ FIX 3 — Normalisation + alias pour l'action
    final action = _canonicalAction(rawAction);

    final supported = supportedActions[scenario];
    if (supported == null) {
      throw VoiceIntentFormatException(
        'Unknown scenario "$scenario". '
        'Known: ${supportedActions.keys.join(", ")}.',
        rawOutput: rawOutput,
      );
    }

    // ✅ FIX 4 — Recherche insensible à la casse dans le set d'actions
    final matched = supported.firstWhere(
      (a) => a.toLowerCase() == action.toLowerCase(),
      orElse: () => '',
    );
    if (matched.isEmpty) {
      throw VoiceIntentFormatException(
        'Action "$action" not allowed for scenario "$scenario". '
        'Allowed: ${supported.join(", ")}.',
        rawOutput: rawOutput,
      );
    }

    // ✅ FIX 5 — Ne plus jeter sur entité dupliquée, garder la première
    final entities = <VoiceEntity>[];
    final seenTypes = <String>{};
    for (final rawEntity in rawEntities) {
      if (rawEntity is! Map) {
        throw VoiceIntentFormatException(
          'Every entity must be an object.',
          rawOutput: rawOutput,
        );
      }
      final type = rawEntity['type'];
      final filler = rawEntity['filler'];
      if (type is! String ||
          type.trim().isEmpty ||
          filler is! String ||
          filler.trim().isEmpty) {
        debugPrint(
          '[SLU] entity ignored (empty type/filler): '
          'type=$type filler=$filler',
        );
        continue;
      }
      final cleanType = type.trim();
      if (!seenTypes.add(cleanType)) {
        debugPrint('[SLU] duplicate entity type="$cleanType" ignored');
        continue;
      }
      entities.add(VoiceEntity(type: cleanType, filler: filler.trim()));
    }

    return VoiceIntent(
      scenario: scenario,
      action: matched,
      entities: List.unmodifiable(entities),
    );
  }

  // ---------- Helpers de normalisation ----------

  static String _canonicalScenario(String raw) {
    final trimmed = raw.trim();
    final lower = trimmed.toLowerCase();
    for (final key in supportedActions.keys) {
      if (key.toLowerCase() == lower) return key;
    }
    return trimmed;
  }

  static String _canonicalAction(String raw) {
    final trimmed = raw.trim();
    final lower = trimmed.toLowerCase();

    // 1) Alias explicite
    final alias = _actionAliases[lower];
    if (alias != null) return alias;

    // 2) Correspondance exacte dans les actions connues (insensible casse)
    for (final set in supportedActions.values) {
      for (final candidate in set) {
        if (candidate.toLowerCase() == lower) return candidate;
      }
    }

    return trimmed;
  }

  @override
  String toString() =>
      'VoiceIntent(scenario: $scenario, action: $action, entities: $entityMap)';
}

dynamic _decodeStructuredOutput(String rawOutput) {
  final trimmed = rawOutput.trim();
  try {
    return jsonDecode(trimmed);
  } on FormatException {
    return jsonDecode(_normalizePythonStringQuotes(trimmed));
  }
}

String _normalizePythonStringQuotes(String input) {
  final output = StringBuffer();
  var quote = _Quote.none;
  var escaped = false;

  for (var index = 0; index < input.length; index++) {
    final character = input[index];

    if (quote == _Quote.doubleQuoted) {
      output.write(character);
      if (escaped) {
        escaped = false;
      } else if (character == '\\') {
        escaped = true;
      } else if (character == '"') {
        quote = _Quote.none;
      }
      continue;
    }

    if (quote == _Quote.singleQuoted) {
      if (escaped) {
        if (character == "'") {
          output.write("'");
        } else if (character == '"') {
          output.write(r'\"');
        } else if (character == '\\') {
          output.write(r'\\');
        } else if ('bfnrtu'.contains(character)) {
          output
            ..write('\\')
            ..write(character);
        } else {
          output
            ..write(r'\\')
            ..write(character);
        }
        escaped = false;
      } else if (character == '\\') {
        escaped = true;
      } else if (character == "'") {
        output.write('"');
        quote = _Quote.none;
      } else if (character == '"') {
        output.write(r'\"');
      } else {
        output.write(character);
      }
      continue;
    }

    if (character == "'") {
      output.write('"');
      quote = _Quote.singleQuoted;
    } else {
      output.write(character);
      if (character == '"') quote = _Quote.doubleQuoted;
    }
  }

  if (quote != _Quote.none || escaped) {
    throw const FormatException('Unterminated quoted string.');
  }
  return output.toString();
}

enum _Quote { none, singleQuoted, doubleQuoted }