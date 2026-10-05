import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

enum AppButtonVariant { primary, ghost, gold, text }

class AppButton extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  final AppButtonVariant variant;
  final IconData? icon;

  const AppButton({
    super.key,
    required this.label,
    this.onTap,
    this.variant = AppButtonVariant.primary,
    this.icon, SizedBox? child,
  });

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  double _scale = 1;

  void _setPressed(bool pressed) => setState(() => _scale = pressed ? 0.97 : 1);

  @override
  Widget build(BuildContext context) {
    final isText = widget.variant == AppButtonVariant.text;

    late final Color bg;
    late final Color fg;
    Border? border;
    List<BoxShadow>? shadow;

    switch (widget.variant) {
      case AppButtonVariant.primary:
        bg = AppColors.navy900;
        fg = AppColors.gold100;
        shadow = AppShadows.md;
        break;
      case AppButtonVariant.ghost:
        bg = Colors.transparent;
        fg = AppColors.navy900;
        border = Border.all(color: AppColors.line, width: 1.5);
        break;
      case AppButtonVariant.gold:
        bg = AppColors.gold500;
        fg = AppColors.navy950;
        shadow = AppShadows.gold;
        break;
      case AppButtonVariant.text:
        bg = Colors.transparent;
        fg = AppColors.navy700;
        break;
    }

    final child = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.icon != null) ...[
          Icon(widget.icon, size: 18, color: fg),
          const SizedBox(width: 8),
        ],
        Text(
          widget.label,
          style: AppText.sans(
            size: isText ? 14 : 15.5,
            weight: FontWeight.w700,
            color: fg,
          ),
        ),
      ],
    );

    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 120),
        child: isText
            ? Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: child)
            : Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 22),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(999),
                  border: border,
                  boxShadow: shadow,
                ),
                child: child,
              ),
      ),
    );
  }
}