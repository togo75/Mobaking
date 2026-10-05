import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Ce fichier est conservé pour compatibilité.
/// La logique de transfert est maintenant gérée par [ActionHandler].
class ConfirmScreen extends StatelessWidget {
  final String recipient;
  final String phone;
  final String amount;
  final String fee;

  const ConfirmScreen({
    super.key,
    required this.recipient,
    required this.phone,
    required this.amount,
    required this.fee,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: Text('Confirmation', style: AppText.serif(size: 20)),
        backgroundColor: Colors.transparent,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.info_outline_rounded,
                size: 64,
                color: AppColors.navy700,
              ),
              const SizedBox(height: 20),
              Text(
                'Écran obsolète',
                style: AppText.serif(size: 22),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'Les transferts sont désormais exécutés directement depuis l\'écran vocal.',
                style: AppText.sub(),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Retour'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}