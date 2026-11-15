import 'package:flutter/material.dart';
import '../models.dart';
import 'menu_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..forward();

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 2300), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(PageRouteBuilder(
        pageBuilder: (_, __, ___) => const MenuScreen(),
        transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
      ));
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF2B1B6B), Color(0xFF110C2B)]),
        ),
        child: Center(
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, __) {
              final t = Curves.elasticOut.transform(_c.value.clamp(0.0, 1.0));
              return Opacity(
                opacity: _c.value.clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: .5 + .5 * t,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 120,
                        height: 120,
                        child: GridView.count(
                          crossAxisCount: 2,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            for (final c in kPlayerColors)
                              Container(
                                decoration: BoxDecoration(
                                  color: c,
                                  borderRadius: BorderRadius.circular(18),
                                  boxShadow: [BoxShadow(color: c.withOpacity(.6), blurRadius: 14)],
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 26),
                      const Text('LUDO ROYALE',
                          style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: 4, color: Colors.white)),
                      const SizedBox(height: 6),
                      const Text('Roll • Race • Reign', style: TextStyle(color: Colors.white60, letterSpacing: 2)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
