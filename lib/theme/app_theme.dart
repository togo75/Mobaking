
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppRadius {
  AppRadius._();
  static const lg = 26.0;
  static const md = 18.0;
  static const sm = 12.0;
}

class AppShadows {
  AppShadows._();

  static List<BoxShadow> sm = [
    BoxShadow(
      color: AppColors.navy950.withValues(alpha: .06),
      blurRadius: 2,
      offset: const Offset(0, 1),
    ),
    BoxShadow(
      color: AppColors.navy950.withValues(alpha: .04),
      blurRadius: 1,
      offset: const Offset(0, 1),
    ),
  ];

  static List<BoxShadow> md = [
    BoxShadow(
      color: AppColors.navy950.withValues(alpha: .12),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> lg = [
    BoxShadow(
      color: AppColors.navy950.withValues(alpha: .30),
      blurRadius: 50,
      offset: const Offset(0, 20),
    ),
  ];

  static List<BoxShadow> gold = [
    BoxShadow(
      color: AppColors.gold500.withValues(alpha: .35),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];
}

class AppText {
  AppText._();

  // Titres — équivalent 'Fraunces', serif
  static TextStyle serif({
    double size = 20,
    FontWeight weight = FontWeight.w600,
    Color color = AppColors.ink,
    double? letterSpacing,
  }) =>
      GoogleFonts.fraunces(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing,
        height: 1.15,
      );

  // Corps de texte — équivalent 'Inter', sans-serif
  static TextStyle sans({
    double size = 14,
    FontWeight weight = FontWeight.w500,
    Color color = AppColors.ink,
    double? letterSpacing,
    double? height,
  }) =>
      GoogleFonts.inter(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
      );

  static TextStyle eyebrow({Color color = AppColors.navy500}) => sans(
        size: 11,
        weight: FontWeight.w700,
        color: color,
        letterSpacing: 1.3,
      );

  static TextStyle sub({Color color = AppColors.inkSoft}) => sans(
        size: 13,
        weight: FontWeight.w500,
        color: color,
      );

  static TextStyle bamTag() => sans(
        size: 12,
        weight: FontWeight.w600,
        color: AppColors.gold600,
      );
}

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.cream,
    fontFamily: GoogleFonts.inter().fontFamily,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.navy900,
      primary: AppColors.navy900,
      secondary: const Color.fromARGB(255, 134, 144, 138),
    ),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
  );
}