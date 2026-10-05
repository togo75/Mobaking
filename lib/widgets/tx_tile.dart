import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class TxData {
  final String title;
  final String subtitle;
  final String amount;
  final bool isOut; // true = sortant (rouge), false = entrant (vert)
  final IconData icon;

  const TxData({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.isOut,
    required this.icon,
  });
}

class TxTile extends StatelessWidget {
  final TxData tx;
  const TxTile({super.key, required this.tx});

  @override
  Widget build(BuildContext context) {
    final Color accent = tx.isOut ? AppColors.red : AppColors.greenTx;
    final Color iconBg = tx.isOut ? const Color(0xFFF2E0DC) : const Color(0xFFDCECE3);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppShadows.sm,
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Icon(tx.icon, size: 20, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tx.title,
                    style: AppText.sans(size: 14, weight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(tx.subtitle, style: AppText.sub()),
              ],
            ),
          ),
          Text(
            tx.amount,
            style: AppText.sans(size: 14.5, weight: FontWeight.w800, color: accent),
          ),
        ],
      ),
    );
  }
}
