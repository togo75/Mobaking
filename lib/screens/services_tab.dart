import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'voice_screen.dart';

class ServicesTab extends StatelessWidget {
  const ServicesTab({super.key});

  static const _services = [
    (Icons.send_rounded, ' Wari ci — Transfert', AppColors.navy900),
    (Icons.qr_code_scanner_rounded, 'Sarali — Payer par QR', AppColors.gold600),
    (Icons.bolt_rounded, 'Kuran sara — Facture EDM', AppColors.greenTx),
    (Icons.water_drop_rounded, 'Ji sara — Facture eau', AppColors.navy500),
    (Icons.phone_iphone_rounded, 'Kredi ta — Achat crédit', AppColors.gold500),
    (Icons.savings_rounded, 'Mara — Épargne', AppColors.gold600),
  ];

  void _openVoiceScreen(BuildContext context, String serviceName) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 280),
        pageBuilder: (_, __, ___) => VoiceScreen(serviceName: serviceName),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween(
              begin: const Offset(0, .06),
              end: Offset.zero,
            ).animate(anim),
            child: child,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 120),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Sèribiw', style: AppText.eyebrow()),
                  const SizedBox(height: 6),
                  Text('Services', style: AppText.serif(size: 24)),
                  const SizedBox(height: 4),
                  Text(
                    'Tout ce que vous pouvez faire, à la voix ou au doigt',
                    style: AppText.sub(),
                  ),
                ],
              ),
            ),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.35,
              children: [
                for (final s in _services)
                  _ServiceCard(
                    icon: s.$1,
                    label: s.$2,
                    color: s.$3,
                    onTap: () => _openVoiceScreen(context, s.$2),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ServiceCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.paper,
          borderRadius: BorderRadius.circular(20),
          boxShadow: AppShadows.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(13),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 21, color: color),
            ),
            const Spacer(),
            Text(
              label,
              style: AppText.sans(size: 14, weight: FontWeight.w700),
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
}