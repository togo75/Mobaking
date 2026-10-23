import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../services/service_locator.dart';
import 'app_shell.dart';
import 'login_screen.dart';


class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final AnimationController _entranceCtrl;

  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final Animation<Offset> _titleSlide;
  late final Animation<double> _titleFade;
  late final Animation<Offset> _subtitleSlide;
  late final Animation<double> _subtitleFade;
  late final Animation<double> _buttonFade;
  late final Animation<Offset> _buttonSlide;

  bool _checkingSession = true;

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();

    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _logoScale = CurvedAnimation(
      parent: _entranceCtrl,
      curve: const Interval(0.0, 0.55, curve: Curves.easeOutBack),
    ).drive(Tween(begin: 0.6, end: 1.0));

    _logoFade = CurvedAnimation(
      parent: _entranceCtrl,
      curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
    );

    _titleFade = CurvedAnimation(
      parent: _entranceCtrl,
      curve: const Interval(0.25, 0.6, curve: Curves.easeOut),
    );
    _titleSlide = CurvedAnimation(
      parent: _entranceCtrl,
      curve: const Interval(0.25, 0.6, curve: Curves.easeOutCubic),
    ).drive(Tween(begin: const Offset(0, 0.25), end: Offset.zero));

    _subtitleFade = CurvedAnimation(
      parent: _entranceCtrl,
      curve: const Interval(0.4, 0.75, curve: Curves.easeOut),
    );
    _subtitleSlide = CurvedAnimation(
      parent: _entranceCtrl,
      curve: const Interval(0.4, 0.75, curve: Curves.easeOutCubic),
    ).drive(Tween(begin: const Offset(0, 0.25), end: Offset.zero));

    _buttonFade = CurvedAnimation(
      parent: _entranceCtrl,
      curve: const Interval(0.6, 1.0, curve: Curves.easeOut),
    );
    _buttonSlide = CurvedAnimation(
      parent: _entranceCtrl,
      curve: const Interval(0.6, 1.0, curve: Curves.easeOutCubic),
    ).drive(Tween(begin: const Offset(0, 0.4), end: Offset.zero));

    _entranceCtrl.forward();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    // 1. Attendre l'initialisation des services
    try {
      await ServiceLocator.instance.init();
    } catch (e) {
      debugPrint('[SPLASH] ServiceLocator init failed: $e');
    }

    // 2. Vérifier si un utilisateur Firebase est déjà connecté
    final firebaseUser = FirebaseAuth.instance.currentUser;

    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;

    if (firebaseUser != null) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 400),
          pageBuilder: (_, __, ___) => const AppShell(),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
        ),
      );
      return;
    }
    setState(() => _checkingSession = false);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _entranceCtrl.dispose();
    super.dispose();
  }

  Widget _buildLogo() {
    return AnimatedBuilder(
      animation: Listenable.merge([_pulseCtrl, _entranceCtrl]),
      builder: (context, child) {
        final t = _pulseCtrl.value;
        return Opacity(
          opacity: _logoFade.value,
          child: Transform.scale(
            scale: _logoScale.value,
            child: SizedBox(
              width: 176,
              height: 176,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  _pulseRing(t, delay: 0.0, maxSize: 176, color: AppColors.gold500),
                  _pulseRing(
                    (t + 0.5) % 1.0,
                    delay: 0.0,
                    maxSize: 176,
                    color: const Color.fromARGB(255, 39, 134, 64),
                  ),
                  Container(
                    width: 118,
                    height: 118,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color.fromARGB(255, 74, 111, 224),
                          Color.fromARGB(255, 40, 58, 158),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color.fromARGB(255, 30, 42, 120)
                              .withValues(alpha: 0.45),
                          blurRadius: 28,
                          spreadRadius: 2,
                          offset: const Offset(0, 10),
                        ),
                      ],
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.18),
                        width: 1.2,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.mic_rounded,
                      size: 52,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _pulseRing(double t, {required double delay, required double maxSize, required Color color}) {
    final size = 118 + (maxSize - 118) * t;
    final opacity = (1 - t).clamp(0.0, 1.0) * 0.35;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: color.withValues(alpha: opacity),
          width: 1.5,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.fromARGB(255, 21, 32, 87),
              Color.fromARGB(255, 33, 51, 133),
              Color.fromARGB(255, 46, 74, 176),
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Positioned(
                top: -80,
                right: -60,
                child: Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.gold500.withValues(alpha: 0.08),
                  ),
                ),
              ),
              Positioned(
                bottom: -100,
                left: -70,
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.04),
                  ),
                ),
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildLogo(),
                      const SizedBox(height: 30),
                      SlideTransition(
                        position: _titleSlide,
                        child: FadeTransition(
                          opacity: _titleFade,
                          child: Text(
                            'MOBAMKING',
                            style: AppText.serif(
                              size: 40,
                              weight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: -0.6,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      SlideTransition(
                        position: _titleSlide,
                        child: FadeTransition(
                          opacity: _titleFade,
                          child: Container(
                            margin: const EdgeInsets.only(top: 6),
                            height: 3,
                            width: 48,
                            decoration: BoxDecoration(
                              color: AppColors.gold500,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      SlideTransition(
                        position: _subtitleSlide,
                        child: FadeTransition(
                          opacity: _subtitleFade,
                          child: SizedBox(
                            width: 290,
                            child: Text(
                              '\nAw ka wari ci, ani wari sɔrɔ, ani aw ka facture sarali bamanankan na !\n '
                              'Votre application mobile de transfert d\'argent en bambara 🇲🇱',
                              textAlign: TextAlign.center,
                              style: AppText.sans(
                                size: 13,
                                weight: FontWeight.w700,
                                color: Colors.white.withValues(alpha: 0.86),
                                height: 1.6,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (!_checkingSession)
                Positioned(
                  bottom: 48,
                  left: 24,
                  right: 24,
                  child: SlideTransition(
                    position: _buttonSlide,
                    child: FadeTransition(
                      opacity: _buttonFade,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color.fromARGB(255, 34, 168, 101)
                                      .withValues(alpha: 0.4),
                                  blurRadius: 24,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () {
                                  Navigator.of(context).pushReplacement(
                                    PageRouteBuilder(
                                      transitionDuration:
                                          const Duration(milliseconds: 320),
                                      pageBuilder: (_, __, ___) =>
                                          const LoginScreen(),
                                      transitionsBuilder:
                                          (_, anim, __, child) =>
                                              FadeTransition(
                                                  opacity: anim, child: child),
                                    ),
                                  );
                                },
                                child: Container(
                                  width: double.infinity,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 17),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    gradient: const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Color.fromARGB(255, 46, 196, 122),
                                        Color.fromARGB(255, 24, 148, 90),
                                      ],
                                    ),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.15),
                                      width: 1,
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    'Ka Don — Commencer',
                                    style: AppText.sans(
                                      size: 16,
                                      weight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Rapide • Sécurisé • En bamanankan',
                            style: AppText.sans(
                              size: 12.5,
                              color: Colors.white.withValues(alpha: 0.55),
                              weight: FontWeight.w500,
                            ),
                          ),
                        ],
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
}