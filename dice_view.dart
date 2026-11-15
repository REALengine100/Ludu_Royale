import 'package:flutter/material.dart';

class DiceView extends StatelessWidget {
  final int value;
  final Color accent;
  final double size;
  final bool glow;
  const DiceView({super.key, required this.value, required this.accent, this.size = 80, this.glow = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Color(0xFFE0E0E0)],
        ),
        borderRadius: BorderRadius.circular(size * .22),
        border: Border.all(color: accent, width: 3.5),
        boxShadow: [
          BoxShadow(color: accent.withOpacity(glow ? .85 : .3), blurRadius: glow ? 20 : 8, spreadRadius: glow ? 2 : 0),
          const BoxShadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 4)),
        ],
      ),
      child: CustomPaint(painter: _DotsPainter(value)),
    );
  }
}

class _DotsPainter extends CustomPainter {
  final int v;
  _DotsPainter(this.v);
  static const _faces = {
    1: [4],
    2: [0, 8],
    3: [0, 4, 8],
    4: [0, 2, 6, 8],
    5: [0, 2, 4, 6, 8],
    6: [0, 2, 3, 5, 6, 8],
  };

  @override
  void paint(Canvas canvas, Size s) {
    const f = [.27, .5, .73];
    for (final i in _faces[v.clamp(1, 6)]!) {
      canvas.drawCircle(Offset(s.width * f[i % 3], s.height * f[i ~/ 3]), s.width * .085, Paint()..color = const Color(0xFF212121));
    }
  }

  @override
  bool shouldRepaint(covariant _DotsPainter old) => old.v != v;
}
