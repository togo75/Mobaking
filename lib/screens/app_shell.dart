import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/bottom_navbar.dart';
import '../services/service_locator.dart';
import 'home_tab.dart';
import 'services_tab.dart';
import 'history_tab.dart';
import 'profile_tab.dart';
import 'voice_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late final appState = ServiceLocator.instance.appState;

  @override
  void initState() {
    super.initState();
    appState.addListener(_rebuild);
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    appState.removeListener(_rebuild);
    super.dispose();
  }

  void _openVoice() {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 280),
        pageBuilder: (_, __, ___) => const VoiceScreen(serviceName: ''),
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
    final tabs = [
      HomeTab(onMicTap: _openVoice),
      const ServicesTab(),
      const HistoryTab(),
      const ProfileTab(),
    ];

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Stack(
        children: [
          IndexedStack(index: appState.currentTab, children: tabs),
          BottomNavbar(
            currentIndex: appState.currentTab,
            onTabSelected: appState.navigateTo,
            onMicTap: _openVoice,
          ),
        ],
      ),
    );
  }
}