import 'package:flutter/material.dart';
import 'themes.dart';

/// Premium glossy dice. Same API as before (value, accent, size, glow),
/// so game_screen.dart needs no change.
class DiceView extends StatelessWidget {
  final int value;
  final Color accent;
  final double size;
  final bool glow;
  final DiceTheme? theme; // null = the dice equipped in the shop
  const DiceView({super.key, required this.value, required this.accent, this.size = 80, this.glow = false, this.theme});

  @override
  Widget build(BuildContext context) {
    final radius = size * .24;
    final th = theme ?? currentDice();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        // ivory body with a soft 3D light from the top-left
        gradient: RadialGradient(
          center: Alignment(-.45, -.55),
          radius: 1.25,
          colors: th.body,
          stops: [0, .55, 1],
        ),
        border: Border.all(color: accent, width: size * .05),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(glow ? .9 : .35),
            blurRadius: glow ? size * .45 : size * .16,
            spreadRadius: glow ? size * .04 : 0,
          ),
          BoxShadow(color: Colors.black.withOpacity(.55), blurRadius: size * .12, offset: Offset(0, size * .07)),
        ],
      ),
      child: CustomPaint(painter: _DicePainter(value, accent, radius, th.pip)),
    );
  }
}

class _DicePainter extends CustomPainter {
  final int v;
  final Color accent;
  final double radius;
  final List<Color> pip;
  _DicePainter(this.v, this.accent, this.radius, this.pip);

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
    final w = s.width;
    final full = Offset.zero & s;

    // glossy highlight on the upper half
    final gloss = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * .07, w * .06, w * .86, w * .44),
      Radius.circular(radius * .8),
    );
    canvas.drawRRect(
      gloss,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white.withOpacity(.85), Colors.white.withOpacity(0)],
        ).createShader(gloss.outerRect),
    );

    // soft inner shade at the bottom edge (gives the cube feel)
    final shade = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.transparent, Colors.black.withOpacity(.14)],
        stops: const [.6, 1],
      ).createShader(full);
    canvas.drawRRect(RRect.fromRectAndRadius(full.deflate(w * .03), Radius.circular(radius)), shade);

    // thin bevel line
    canvas.drawRRect(
      RRect.fromRectAndRadius(full.deflate(w * .055), Radius.circular(radius * .8)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * .012
        ..color = Colors.white.withOpacity(.7),
    );

    // pips
    const f = [.27, .5, .73];
    final one = v.clamp(1, 6) == 1;
    final pr = w * (one ? .13 : .09);
    for (final i in _faces[v.clamp(1, 6)]!) {
      final c = Offset(w * f[i % 3], w * f[i ~/ 3]);
      // drop shadow
      canvas.drawCircle(c.translate(0, pr * .28), pr, Paint()..color = Colors.black.withOpacity(.28));
      // pip body, a bit glossy
      final colors = one
          ? [Color.lerp(accent, Colors.white, .35)!, accent, Color.lerp(accent, Colors.black, .45)!]
          : pip;
      canvas.drawCircle(
        c,
        pr,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-.35, -.4),
            radius: 1.0,
            colors: colors,
            stops: const [0, .6, 1],
          ).createShader(Rect.fromCircle(center: c, radius: pr)),
      );
      // tiny specular dot
      canvas.drawCircle(c.translate(-pr * .32, -pr * .34), pr * .2, Paint()..color = Colors.white.withOpacity(.75));
    }
  }

  @override
  bool shouldRepaint(covariant _DicePainter old) => old.v != v || old.accent != accent || old.radius != radius || old.pip != pip;
}
