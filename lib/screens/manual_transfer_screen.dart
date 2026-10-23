import 'package:flutter/material.dart';
import '../models/voice_intent.dart';
import '../services/action_handler.dart';
import '../services/service_locator.dart';

class ManualTransferScreen extends StatefulWidget {
  const ManualTransferScreen({
    super.key,
    this.initialAmount,
    this.initialTarget,
    this.initialAction = 'transfer_to_momo',
  });

  /// Montant déjà extrait par le SLU (optionnel).
  final String? initialAmount;

  /// Numéro ou nom déjà extrait par le SLU (optionnel).
  final String? initialTarget;

  /// 'transfer_to_momo' ou 'transfer_to_account'.
  final String initialAction;

  @override
  State<ManualTransferScreen> createState() => _ManualTransferScreenState();
}

class _ManualTransferScreenState extends State<ManualTransferScreen> {
  late final TextEditingController _targetCtrl;
  late final TextEditingController _amountCtrl;
  late String _action;

  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _targetCtrl = TextEditingController(text: widget.initialTarget ?? '');
    _amountCtrl = TextEditingController(text: widget.initialAmount ?? '');
    _action = widget.initialAction;
  }

  Future<void> _executeTransfer() async {
    final target = _targetCtrl.text.trim();
    final amount = int.tryParse(_amountCtrl.text.replaceAll(' ', '')) ?? 0;

    if (target.isEmpty || amount <= 0) {
      setState(() => _error = 'I ka tɔgɔ/nimɔrɔ ni wari hakɛ dafa.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final locator = ServiceLocator.instance;

      // Détecter si c'est un numéro ou un nom
      final cleanTarget = target.replaceAll(' ', '');
      final isPhone = RegExp(r'^\+?\d{6,}$').hasMatch(cleanTarget);

      final entities = <VoiceEntity>[
        VoiceEntity(type: 'amount', filler: amount.toString()),
      ];
      if (isPhone) {
        entities.add(VoiceEntity(type: 'recipient_phone', filler: cleanTarget));
      } else {
        entities.add(VoiceEntity(type: 'recipient', filler: target));
      }

      final intent = VoiceIntent(
        scenario: 'Operation',
        action: _action,
        entities: entities,
      );

      //  Ne passer rawTarget que si c'est un numéro
      //    (sinon parseDigitSequence échoue sur un nom)
      final draft = await locator.actions.prepareTransfer(
        action: _action,
        rawAmount: amount.toString(),
        rawTarget: isPhone ? cleanTarget : '',
      );

      // Retourner le draft au VoiceScreen
      if (!mounted) return;
      Navigator.of(context).pop(draft);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e is ActionException ? e.userMessage : e.toString();
      });
    }
  }

  @override
  void dispose() {
    _targetCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Saisie manuelle',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1E293B)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Wari ci',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Aw ye kunnafoniw dafa walisa ka wari ci.',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 24),

              //  Sélecteur MoMo / Compte
              Row(
                children: [
                  Expanded(
                    child: _actionChip(
                      label: 'Mobile Money',
                      value: 'transfer_to_momo',
                      icon: Icons.phone_android_rounded,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _actionChip(
                      label: 'Compte',
                      value: 'transfer_to_account',
                      icon: Icons.account_balance_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              _buildTextField(
                controller: _targetCtrl,
                label: 'Mɔgɔ tɔgɔ / Nimɔrɔ (Bénéficiaire)',
                icon: Icons.person_outline_rounded,
                keyboardType: TextInputType.text,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _amountCtrl,
                label: 'Wari hakɛ (FCFA)',
                icon: Icons.account_balance_wallet_rounded,
                keyboardType: TextInputType.number,
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: Color(0xFFEF4444),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            color: Color(0xFFEF4444),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _executeTransfer,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4A6CF7),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    disabledBackgroundColor:
                        const Color(0xFF4A6CF7).withValues(alpha: 0.6),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text(
                          'Wari ci',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionChip({
    required String label,
    required String value,
    required IconData icon,
  }) {
    final selected = _action == value;
    return GestureDetector(
      onTap: () => setState(() => _action = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF4A6CF7).withValues(alpha: 0.12)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? const Color(0xFF4A6CF7) : const Color(0xFFE2E8F0),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color:
                  selected ? const Color(0xFF4A6CF7) : const Color(0xFF94A3B8),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected
                    ? const Color(0xFF4A6CF7)
                    : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF475569),
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 54,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFE2E8F0),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              const SizedBox(width: 16),
              Icon(icon, size: 20, color: const Color(0xFF94A3B8)),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: keyboardType,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF1E293B),
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: 'Sɛbɛn yan...',
                    hintStyle: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontWeight: FontWeight.w400,
                    ),
                    contentPadding: EdgeInsets.symmetric(vertical: 0),
                  ),
                ),
              ),
              const SizedBox(width: 16),
            ],
          ),
        ),
      ],
    );
  }
}
