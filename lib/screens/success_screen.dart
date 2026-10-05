import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/app_button.dart';
import 'app_shell.dart';

class SuccessScreen extends StatefulWidget {
  final String recipient;
  final String amount;
  final String reference;

  const SuccessScreen({
    super.key,
    required this.recipient,
    required this.amount,
    required this.reference,
  });

  @override
  State<SuccessScreen> createState() => _SuccessScreenState();
}

class _SuccessScreenState extends State<SuccessScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _popCtrl;
  late final Animation<double> _pop;

  @override
  void initState() {
    super.initState();
    _popCtrl = AnimationController(
      vsync: this, 
      duration: const Duration(milliseconds: 420)
    );
    _pop = CurvedAnimation(parent: _popCtrl, curve: Curves.elasticOut);
    _popCtrl.forward();
  }

  @override
  void dispose() {
    _popCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
   
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: _pop,
                child: Container(
                  width: 108,
                  height: 108,
                  margin: const EdgeInsets.only(bottom: 26),
                  decoration: BoxDecoration(
                    gradient: AppColors.checkGradient,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.greenTx.withValues(alpha: 0.32), 
                        blurRadius: 34, 
                        offset: const Offset(0, 14)
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.check_rounded, size: 52, color: Colors.white),
                ),
              ),
              Text(
                'Ciyɛn kɛra ka ɲɛ — Envoi réussi', 
                style: AppText.serif(size: 23), 
                textAlign: TextAlign.center
              ),
              const SizedBox(height: 6),
              Text(
                'à ${widget.recipient}', 
                style: AppText.sub(), 
                textAlign: TextAlign.center
              ),
              Text(
                '${widget.amount} FCFA', 
                style: AppText.serif(size: 31, color: AppColors.navy900).copyWith(height: 1.6)
              ),
              const SizedBox(height: 8),
              Text(
                'N° de référence : ${widget.reference}', 
                style: AppText.sans(size: 12, color: AppColors.inkSoft)
              ),
              Column(
                children: [
                  const SizedBox(height: 30),
                  AppButton(
                    label: 'So kɔnɔ — Retour à l\'accueil',
                    variant: AppButtonVariant.primary,
                    onTap: () {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const AppShell()),
                        (route) => false,
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  AppButton(
                    label: 'Sɛbɛn ci — Partager le reçu',
                    variant: AppButtonVariant.ghost,
                    onTap: () {},
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}