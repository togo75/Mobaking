import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';


class PinInputField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool obscure;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onCompleted;
  final String label;

  const PinInputField({
    super.key,
    required this.controller,
    required this.label,
    this.focusNode,
    this.obscure = true,
    this.errorText,
    this.onChanged,
    this.onCompleted,
  });

  @override
  State<PinInputField> createState() => _PinInputFieldState();
}

class _PinInputFieldState extends State<PinInputField> {
  late final FocusNode _focusNode;
  late final bool _ownsFocusNode;

  @override
  void initState() {
    super.initState();
    _ownsFocusNode = widget.focusNode == null;
    _focusNode = widget.focusNode ?? FocusNode();
    widget.controller.addListener(_handleChange);
  }

  void _handleChange() {
    setState(() {});
    widget.onChanged?.call(widget.controller.text);
    if (widget.controller.text.length == 4) {
      widget.onCompleted?.call();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleChange);
    if (_ownsFocusNode) _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.controller.text;
    final hasError = widget.errorText != null && widget.errorText!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.inkSoft,
          ),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () => _focusNode.requestFocus(),
          behavior: HitTestBehavior.opaque,
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(4, (i) {
                  final filled = i < value.length;
                  final active = _focusNode.hasFocus && i == value.length;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 64,
                    height: 58,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: filled
                          ? AppColors.navy900.withValues(alpha: 0.045)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: hasError
                            ? AppColors.red
                            : active
                                ? AppColors.gold500
                                : AppColors.navy900.withValues(alpha: 0.08),
                        width: active || hasError ? 2 : 1,
                      ),
                    ),
                    child: filled
                        ? (widget.obscure
                            ? Container(
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(
                                  color: AppColors.navy900,
                                  shape: BoxShape.circle,
                                ),
                              )
                            : Text(
                                value[i],
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.navy900,
                                ),
                              ))
                        : null,
                  );
                }),
              ),
              // Champ réel invisible qui capte le clavier système
              Opacity(
                opacity: 0,
                child: SizedBox(
                  height: 58,
                  child: TextField(
                    controller: widget.controller,
                    focusNode: _focusNode,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      counterText: '',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 8),
          Text(
            widget.errorText!,
            style: const TextStyle(
              color: AppColors.red,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}