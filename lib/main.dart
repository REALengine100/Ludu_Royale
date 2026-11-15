import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/splash_screen.dart';
import 'services/ad_manager.dart';
import 'services/app_settings.dart';
import 'services/sfx.dart';
import 'dart:async';

void main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    
    try {
      await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    } catch (e) {
      debugPrint('Orientation Error: $e');
    }
    
    try {
      await AppSettings.i.load();
    } catch (e) {
      debugPrint('AppSettings Error: $e');
    }

    try {
      Sfx.i.init();
    } catch (e) {
      debugPrint('Sfx Error: $e');
    }

    try {
      AdManager.init();
    } catch (e) {
      debugPrint('AdManager Error: $e');
    }

    runApp(const LudoApp());
  }, (error, stack) {
    debugPrint('Caught unhandled error: $error');
  });
}

class LudoApp extends StatelessWidget {
  const LudoApp({super.key});
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ludo Royale',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF7C4DFF), brightness: Brightness.dark),
      ),
      home: const SplashScreen(),
    );
  }
}
