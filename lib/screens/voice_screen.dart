import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/voice_intent.dart';
import '../services/action_handler.dart';
import '../services/service_locator.dart';

enum _VoiceState { idle, recording, transcribing, interpreting, result, error }

class VoiceScreen extends StatefulWidget {
  final String serviceName;
  const VoiceScreen({super.key, required this.serviceName});

  @override
  State<VoiceScreen> createState() => _VoiceScreenState();
}

class _VoiceScreenState extends State<VoiceScreen>
    with SingleTickerProviderStateMixin {
  // ✅ FIX — Séparation stricte NUMÉRO / NOM
  static const _phoneKeys = [
    'recipient_phone',
    'phone',
    'target',
    'account',
    'number',
  ];

  static const _nameKeys = [
    'recipient',
    'recipient_name',
    'beneficiary',
    'name',
    'destinataire',
  ];

  _VoiceState _state = _VoiceState.idle;

  String _shownTranscript = '';
  VoiceIntent? _intent;
  TransferDraft? _draft;
  String _errorMessage = '';
  bool _isSimulated = false;
  bool _busy = false;

  late final AnimationController _rippleCtrl;

  @override
  void initState() {
    super.initState();
    _rippleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _rippleCtrl.dispose();
    super.dispose();
  }

  // ---------- Helpers ----------

  // ✅ FIX — Tolérant à la casse et aux variantes d'action
  bool _isTransfer(VoiceIntent intent) {
    final action = intent.action.toLowerCase();
    final scenario = intent.scenario.toLowerCase();
    return scenario.contains('operation') && action.contains('transfer');
  }

  String _messageOf(Object e) {
    if (e is ActionException) {
      debugPrint('[VOICE] ${e.technicalMessage}');
      return e.userMessage;
    }
    if (e is VoiceIntentFormatException) {
      debugPrint('[VOICE] SLU format error: ${e.message}');
      debugPrint('[VOICE] SLU raw output: ${e.rawOutput}');
      return 'Je n\'ai pas compris la commande. Veuillez reformuler.';
    }
    debugPrint('[VOICE] error: $e');
    return 'Une erreur est survenue. Veuillez réessayer.';
  }

  // ---------- Pipeline vocal réel ----------

  Future<void> _startRecording() async {
    final locator = ServiceLocator.instance;

    if (!locator.slu.isInitialized) {
      setState(() {
        _state = _VoiceState.error;
        _errorMessage =
            'Les modèles vocaux ne sont pas encore prêts. '
            'Vérifiez votre connexion et réessayez dans quelques instants.';
      });
      return;
    }

    setState(() {
      _state = _VoiceState.recording;
      _shownTranscript = '';
      _intent = null;
      _draft = null;
      _errorMessage = '';
      _isSimulated = false;
    });

    try {
      await locator.recorder.startRecording('voice_cmd');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _VoiceState.error;
        _errorMessage = 'Impossible de démarrer l\'enregistrement: $e';
      });
    }
  }

  Future<void> _stopAndProcess() async {
    final locator = ServiceLocator.instance;
    String? path;

    try {
      path = await locator.recorder.stopRecording();

      setState(() => _state = _VoiceState.transcribing);
      final transcript = await locator.slu.transcribeSpeech(path);
      if (!mounted) return;
      setState(() => _shownTranscript = transcript);

      setState(() => _state = _VoiceState.interpreting);
      final intent = await locator.slu.parseIntent(path);
      if (!mounted) return;

      // ✅ FIX — Debug exhaustif
      debugPrint('[VOICE] scenario="${intent.scenario}" '
          'action="${intent.action}"');
      debugPrint('[VOICE] entityMap=${intent.entityMap}');
      debugPrint('[VOICE] isTransfer=${_isTransfer(intent)}');
      debugPrint('[VOICE] phone=${intent.entityFirst(_phoneKeys)}');
      debugPrint('[VOICE] name=${intent.entityFirst(_nameKeys)}');

      // Pour un transfert : préparer et valider le brouillon tout de suite.
      TransferDraft? draft;
      if (_isTransfer(intent)) {
        final rawAmount = intent.entityMap['amount'] ?? '';
        final rawTarget = intent.entityFirst(_phoneKeys) ?? '';
        debugPrint(
          '[VOICE] transfer rawAmount="$rawAmount" rawTarget="$rawTarget"',
        );
        try {
          draft = await locator.actions.prepareTransfer(
            action: intent.action,
            rawAmount: rawAmount,
            rawTarget: rawTarget,
          );
        } catch (e) {
          if (!mounted) return;
          setState(() {
            _intent = intent;
            _state = _VoiceState.error;
            _errorMessage = _messageOf(e);
          });
          return;
        }
        if (!mounted) return;
      }

      setState(() {
        _intent = intent;
        _draft = draft;
        _state = _VoiceState.result;
      });
    } catch (e) {
      if (!mounted) return;

      if (locator.slu.initializationError != null) {
        _simulateResponse();
        return;
      }

      debugPrint('[VOICE] pipeline error: $e');
      setState(() {
        _state = _VoiceState.error;
        _errorMessage = _messageOf(e);
      });
    } finally {
      if (path != null) {
        unawaited(locator.recorder.deleteTemporaryFile(path));
      }
    }
  }

  void _simulateResponse() {
    if (!mounted) return;
    setState(() {
      _isSimulated = true;
      _draft = null;
      _shownTranscript = '15 000 FCFA Ci Boubacar Koné ma';
      _intent = const VoiceIntent(
        scenario: 'Operation',
        action: 'transfer_to_momo',
        entities: [
          VoiceEntity(type: 'amount', filler: '15000'),
          VoiceEntity(type: 'recipient', filler: 'Boubacar Koné'),
          VoiceEntity(type: 'recipient_phone', filler: '+223 76 00 00 00'),
        ],
      );
      _state = _VoiceState.result;
    });
  }

  Future<void> _executeIntent() async {
    final intent = _intent;
    if (intent == null || _busy) return;

    final locator = ServiceLocator.instance;
    _busy = true;
    setState(() => _state = _VoiceState.interpreting);

    try {
      if (_isTransfer(intent)) {
        // Sécurité : recréer le brouillon s'il manque.
        final draft = _draft ??
            await locator.actions.prepareTransfer(
              action: intent.action,
              rawAmount: intent.entityMap['amount'] ?? '',
              rawTarget: intent.entityFirst(_phoneKeys) ?? '',
            );
        await locator.actions.execute(intent, transfer: draft);
      } else {
        await locator.actions.execute(intent);
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _VoiceState.error;
        _errorMessage = _messageOf(e);
      });
    } finally {
      _busy = false;
    }
  }

  void _restart() {
    setState(() {
      _state = _VoiceState.idle;
      _shownTranscript = '';
      _intent = null;
      _draft = null;
      _errorMessage = '';
      _isSimulated = false;
    });
  }

  void _openManualEntry() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Saisie manuelle — bientôt disponible'),
        backgroundColor: const Color(0xFF1E293B),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  String _formatAmount(int amount) {
    return amount.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]} ',
    );
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    final isIdle = _state == _VoiceState.idle;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Positioned(
                top: 8,
                right: 12,
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.close_rounded,
                      color: Color(0xFF94A3B8),
                      size: 20,
                    ),
                  ),
                ),
              ),
              Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildOrb(isIdle),
                          const SizedBox(height: 18),
                          Text(
                            switch (_state) {
                              _VoiceState.idle => 'Je vous écoute',
                              _VoiceState.recording => 'Enregistrement…',
                              _VoiceState.transcribing =>
                                'Transcription en cours…',
                              _VoiceState.interpreting =>
                                'Analyse de votre demande…',
                              _VoiceState.result => 'Demande détectée',
                              _VoiceState.error => 'Une erreur est survenue',
                            },
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              letterSpacing: -0.3,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            switch (_state) {
                              _VoiceState.idle =>
                                'Appuyez longuement sur le micro pour parler',
                              _VoiceState.recording =>
                                'Relâchez pour terminer l\'enregistrement',
                              _VoiceState.transcribing =>
                                'Conversion de votre voix en texte',
                              _VoiceState.interpreting =>
                                'Le système interprète votre demande',
                              _VoiceState.result => _isSimulated
                                  ? 'Mode simulation (modèles indisponibles)'
                                  : 'Vérifiez les détails avant de confirmer',
                              _VoiceState.error => _errorMessage,
                            },
                            style: TextStyle(
                              fontSize: 13,
                              color: _state == _VoiceState.error
                                  ? const Color(0xFFEF4444)
                                  : const Color(0xFF94A3B8),
                              fontWeight: FontWeight.w400,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),

                          if (_state != _VoiceState.idle) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: _state == _VoiceState.error
                                      ? const Color(0xFFEF4444)
                                          .withValues(alpha: 0.3)
                                      : Colors.white.withValues(alpha: 0.08),
                                  width: 1,
                                ),
                              ),
                              child: RichText(
                                text: TextSpan(
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                    height: 1.5,
                                  ),
                                  children: [
                                    TextSpan(text: _shownTranscript),
                                    if (_state == _VoiceState.transcribing)
                                      const WidgetSpan(
                                        child: _BlinkingCaret(),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            if (_state == _VoiceState.interpreting)
                              _statusChip(
                                color: const Color(0xFF4A6CF7),
                                label: 'Traitement en cours…',
                                leading: const SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFF4A6CF7),
                                  ),
                                ),
                              )
                            else if (_state == _VoiceState.error)
                              _statusChip(
                                color: const Color(0xFFEF4444),
                                label: 'Erreur de traitement',
                                leading: const Icon(
                                  Icons.error_outline_rounded,
                                  size: 12,
                                  color: Color(0xFFEF4444),
                                ),
                              ),
                          ],

                          if (_state == _VoiceState.result &&
                              _intent != null) ...[
                            const SizedBox(height: 16),
                            _buildResultCard(_intent!),
                          ],

                          if (isIdle) ...[
                            const SizedBox(height: 12),
                            _buildPrivacyNote(),
                          ],
                        ],
                      ),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Column(
                      children: [
                        if (_state == _VoiceState.result &&
                            _intent != null) ...[
                          _primaryButton(
                            _isTransfer(_intent!)
                                ? 'Confirmer la transaction'
                                : 'Exécuter',
                            _isSimulated ? null : _executeIntent,
                          ),
                          const SizedBox(height: 8),
                          _secondaryButton('Reformuler', _restart),
                        ] else if (_state == _VoiceState.error) ...[
                          _primaryButton('Réessayer', _restart),
                          const SizedBox(height: 8),
                          _secondaryButton(
                              'Saisir manuellement', _openManualEntry),
                          const SizedBox(height: 2),
                          _secondaryButton(
                              'Annuler', () => Navigator.of(context).pop()),
                        ] else
                          _secondaryButton(
                              'Annuler', () => Navigator.of(context).pop()),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusChip({
    required Color color,
    required String label,
    required Widget leading,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          leading,
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _primaryButton(String label, VoidCallback? onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4A6CF7),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          disabledBackgroundColor:
              const Color(0xFF4A6CF7).withValues(alpha: 0.4),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }

  Widget _secondaryButton(String label, VoidCallback onPressed) {
    return TextButton(
      onPressed: onPressed,
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: Color(0xFF94A3B8),
        ),
      ),
    );
  }

  Widget _buildResultCard(VoiceIntent intent) {
    final isTransfer = _isTransfer(intent);
    final draft = _draft;

    late final String title;
    late final String subtitle;
    String? extra;

    if (isTransfer) {
      title = draft != null
          ? '${_formatAmount(draft.amount)} FCFA'
          : (intent.amountCfa > 0
              ? '${_formatAmount(intent.amountCfa)} FCFA'
              : (intent.entityMap['amount'] ?? '—'));
      final kind = intent.action == 'transfer_to_momo'
          ? 'Mobile Money'
          : 'Compte';
      final dest = draft?.target ?? intent.entityFirst(_phoneKeys) ?? '—';
      subtitle = 'Vers ($kind): $dest';
      // ✅ FIX — Nom via _nameKeys (plus fiable)
      final name = intent.entityFirst(_nameKeys);
      if (name != null && name.isNotEmpty && name != dest) {
        extra = 'Bénéficiaire: $name';
      }
    } else {
      title = switch (intent.scenario) {
        'Navigate' => 'Navigation',
        'FAQ' => 'Question fréquente',
        _ => intent.action == 'get_balance' ? 'Solde du compte' : 'Opération',
      };
      subtitle = intent.entityMap.entries
          .where((e) => e.value.isNotEmpty)
          .map((e) => e.value)
          .join(' · ');
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            const Color(0xFF4A6CF7).withValues(alpha: 0.15),
            const Color(0xFF6B4CF7).withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF4A6CF7).withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFF4A6CF7).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  isTransfer ? Icons.send_rounded : Icons.bolt_rounded,
                  size: 16,
                  color: const Color(0xFF4A6CF7),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (extra != null) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                extra,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ),
          ],
          if (isTransfer && intent.recipientPhone != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(
                  Icons.phone_rounded,
                  size: 13,
                  color: Color(0xFF94A3B8),
                ),
                const SizedBox(width: 6),
                Text(
                  intent.recipientPhone!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ],
          if (_isSimulated) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Mode simulation',
                style: TextStyle(
                  fontSize: 10,
                  color: Color(0xFFF59E0B),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPrivacyNote() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shield_rounded, size: 13, color: Color(0xFF94A3B8)),
          SizedBox(width: 6),
          Text(
            'Traitement vocal sécurisé et confidentiel',
            style: TextStyle(
              fontSize: 10.5,
              color: Color(0xFF94A3B8),
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrb(bool isIdle) {
    final isRecording = _state == _VoiceState.recording;

    return GestureDetector(
      onLongPressStart: isIdle ? (_) => _startRecording() : null,
      onLongPressEnd: isRecording ? (_) => _stopAndProcess() : null,
      onTap: isIdle ? _startRecording : null,
      child: SizedBox(
        width: 160,
        height: 160,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (isIdle || isRecording)
              AnimatedBuilder(
                animation: _rippleCtrl,
                builder: (context, child) {
                  return Stack(alignment: Alignment.center, children: [
                    _orbRipple((_rippleCtrl.value) % 1.0),
                    _orbRipple((_rippleCtrl.value + .33) % 1.0),
                    _orbRipple((_rippleCtrl.value + .66) % 1.0),
                  ]);
                },
              ),
            Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: _state == _VoiceState.error
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                      )
                    : isRecording
                        ? const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF10B981), Color(0xFF059669)],
                          )
                        : const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF4A6CF7), Color(0xFF6B4CF7)],
                          ),
                boxShadow: [
                  BoxShadow(
                    color: (_state == _VoiceState.error
                            ? const Color(0xFFEF4444)
                            : isRecording
                                ? const Color(0xFF10B981)
                                : const Color(0xFF4A6CF7))
                        .withValues(alpha: 0.3),
                    blurRadius: 30,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Icon(
                _state == _VoiceState.result
                    ? Icons.check_rounded
                    : _state == _VoiceState.error
                        ? Icons.close_rounded
                        : isRecording
                            ? Icons.mic_rounded
                            : Icons.mic_none_rounded,
                size: 42,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _orbRipple(double t) {
    final size = 130 + (t * 50);
    final opacity = (1 - t).clamp(0, 1).toDouble() * 0.3;
    final color = _state == _VoiceState.error
        ? const Color(0xFFEF4444)
        : _state == _VoiceState.recording
            ? const Color(0xFF10B981)
            : const Color(0xFF4A6CF7);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: color.withValues(alpha: opacity),
          width: 1.5,
        ),
      ),
    );
  }
}

class _BlinkingCaret extends StatefulWidget {
  const _BlinkingCaret();
  @override
  State<_BlinkingCaret> createState() => _BlinkingCaretState();
}

class _BlinkingCaretState extends State<_BlinkingCaret>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final visible = _ctrl.value < 0.5;
        return Opacity(
          opacity: visible ? 1 : 0,
          child: Container(
            width: 2,
            height: 20,
            color: const Color(0xFF4A6CF7),
            margin: const EdgeInsets.only(left: 2),
          ),
        );
      },
    );
  }
}

extension VoiceIntentExt on VoiceIntent {
  int get amountCfa =>
      int.tryParse((entityMap['amount'] ?? '0').replaceAll(RegExp(r'\s'), '')) ??
      0;

  String get recipientName => entityMap['recipient'] ?? '—';

  String? get recipientPhone {
    final p = entityMap['recipient_phone'];
    return (p == null || p.isEmpty) ? null : p;
  }

  String? targetNumber(List<String> keys) => entityFirst(keys);

  String get type => action;
}