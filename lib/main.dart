import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/menu_screen.dart';
import 'dart:async';
import 'app_settings.dart';
import 'progress.dart';

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await AppSettings.i.load();
    await Progress.i.load();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    runApp(const LudoApp());
  }, (error, stack) {
    debugPrint('Safe Catch Error: $error');
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
      home: const MenuScreen(),
    );
  }
}
