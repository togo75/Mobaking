import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/device_frame.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();


  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('[BOOTSTRAP] Firebase initialized');
  } catch (e, st) {
    debugPrint('[BOOTSTRAP] Firebase init FAILED: $e');
    debugPrintStack(stackTrace: st);
  }


  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFFFAF7F2),
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const KumakanApp());
}

class KumakanApp extends StatelessWidget {
  const KumakanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return DeviceFrame(
      child: MaterialApp(
        title: 'Kumakan',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: const SplashScreen(),
        routes: {
          '/splash': (context) => const SplashScreen(),
        },
      ),
    );
  }
}