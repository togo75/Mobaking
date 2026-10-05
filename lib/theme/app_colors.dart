import 'package:flutter/material.dart';


class AppColors {
  AppColors._();

  static const navy950 = Color(0xFF12152C);
  static const navy900 = Color(0xFF1B2142);
  static const navy700 = Color(0xFF2A3266);
  static const navy500 = Color(0xFF3F4A8A);


  static const gold600 = Color(0xFF0F7A3D); // vert profond — fonds foncés, texte sur clair
  static const gold500 = Color(0xFF1AA753); // vert principal — CTA, badges, icônes actives
  static const gold400 = Color(0xFF4FD37B); // vert clair — highlights, dégradés
  static const gold100 = Color(0xFFE1F7E9); // vert pâle — fonds de badge, chips

  static const cream = Color(0xFFF6F4EE);
  static const paper = Color(0xFFFFFFFF);

  static const ink = Color(0xFF191C30);
  static const inkSoft = Color(0xFF666C85);
  static const line = Color(0xFFE6E3D9);

  static const red = Color(0xFFA6433A);

  static const greenTx = Color(0xFF3C7A5C);

// Fond du body (dégradé derrière le "device")
  static const bodyGradient = LinearGradient(
    begin: Alignment(-0.6, -1),
    end: Alignment(0.6, 1),
    colors: [Color(0xFFEFECE2), Color(0xFFE2DED0), Color(0xFFD6D1C1)],
    stops: [0.0, 0.6, 1.0],
  );

  static const navyCardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [navy700, navy950],
  );

  static const goldOrbGradient = RadialGradient(
    center: Alignment(-0.3, -0.4),
    radius: 0.9,
    colors: [gold400, gold500],
  );

  static const splashGradient = RadialGradient(
    center: Alignment(-0.4, -0.6),
    radius: 1.1,
    colors: [Color(0xFF262C56), navy950],
    stops: [0.0, 0.7],
  );

  static const voiceGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [navy950, Color(0xFF0A0C1E)],
  );

  static const checkGradient = RadialGradient(
    center: Alignment(-0.3, -0.4),
    radius: 0.9,
    colors: [Color(0xFF5FA07F), greenTx],
  );

  static get bogolanFilamentColor => null;
}