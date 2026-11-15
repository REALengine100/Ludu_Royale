import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'splash_screen.dart';
import 'ad_manager.dart';
import 'app_settings.dart';
import 'sfx.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  
  // সেফটি ট্রাই-ক্যাচ ব্লক যাতে কোনো ইনিশিয়ালাইজেশন ফেইল করলেও অ্যাপ ক্র্যাশ না করে
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
