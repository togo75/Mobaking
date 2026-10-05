import 'package:flutter/material.dart';

class DeviceFrame extends StatelessWidget {
  const DeviceFrame({
    super.key,
    required this.child,
    this.width = 390,
    this.height = 844,
    this.borderRadius = 30,
  });

  final Widget child;
  final double width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    //  PLUS UTILISATION de MediaQuery.of(context)
    return Center(
      child: Container(
        width: width,
        height: height,
        // PAS de margin négative
        margin: EdgeInsets.zero, // ou padding: EdgeInsets.zero
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 30,
              offset: const Offset(0, 15),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: child,
        ),
      ),
    );
  }
}