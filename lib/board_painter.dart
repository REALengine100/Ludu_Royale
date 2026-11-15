import 'dart:math';
import 'package:flutter/material.dart';
import '../engine/ludo_engine.dart';
import '../models.dart';

const List<List<int>> _origins = [
  [0, 0],
  [9, 0],
  [9, 9],
  [0, 9],
];

/// Centre of base slot [i] (0..3) of [color], in grid units.
Offset baseSlot(int color, int i) =>
    Offset(_origins[color][0] + 2.0 + 2.0 * (i % 2), _origins[color][1] + 2.0 + 2.0 * (i ~/ 2));

/// Centre (grid units) where a token with progress [p] is drawn.
Offset cellCenter(int color, int p, int id) {
  if (p < 0) return baseSlot(color, id);
  if (p <= 50) {
    final c = kTrack[absTile(color, p)];
    return Offset(c[0] + .5, c[1] + .5);
  }
  if (p <= 55) {
    final c = kStretch[color][p - 51];
    return Offset(c[0] + .5, c[1] + .5);
  }
  const d = [Offset(-.85, 0), Offset(0, -.85), Offset(.85, 0), Offset(0, .85)];
  return const Offset(7.5, 7.5) + d[color];
}

class BoardPainter extends CustomPainter {
  const BoardPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final u = size.width / 15;
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(u * .4)));
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);

    final line = Paint()
      ..color = const Color(0xFF9E9E9E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    // Quadrants + bases
    for (int k = 0; k < 4; k++) {
      final col = kPlayerColors[k];
      final ox = _origins[k][0] * u, oy = _origins[k][1] * u;
      canvas.drawRect(Rect.fromLTWH(ox, oy, 6 * u, 6 * u), Paint()..color = col);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(ox + u, oy + u, 4 * u, 4 * u), Radius.circular(u * .5)),
        Paint()..color = Colors.white,
      );
      for (int i = 0; i < 4; i++) {
        final c = baseSlot(k, i) * u;
        canvas.drawCircle(c, u * .62, Paint()..color = col.withOpacity(.3));
        canvas.drawCircle(c, u * .62, Paint()
          ..color = darken(col, .1)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
      }
    }

    // Track cells
    for (int i = 0; i < kTrack.length; i++) {
      final r = Rect.fromLTWH(kTrack[i][0] * u, kTrack[i][1] * u, u, u);
      Color fill = Colors.white;
      if (i % 13 == 0) fill = kPlayerColors[i ~/ 13];
      canvas.drawRect(r, Paint()..color = fill);
      canvas.drawRect(r, line);
      if (kStarTiles.contains(i)) {
        canvas.drawPath(_star(r.center, u * .36), Paint()..color = const Color(0xFF757575));
      }
    }
    // Start-square marker (small white dot) so they read as "safe"
    for (int k = 0; k < 4; k++) {
      final c = kTrack[k * 13];
      canvas.drawCircle(Offset((c[0] + .5) * u, (c[1] + .5) * u), u * .13, Paint()..color = Colors.white70);
    }

    // Home stretches
    for (int k = 0; k < 4; k++) {
      for (final c in kStretch[k]) {
        final r = Rect.fromLTWH(c[0] * u, c[1] * u, u, u);
        canvas.drawRect(r, Paint()..color = kPlayerColors[k]);
        canvas.drawRect(r, Paint()
          ..color = Colors.white54
          ..style = PaintingStyle.stroke
          ..strokeWidth = .8);
      }
    }

    // Centre triangles
    final tri = [
      [Offset(6 * u, 6 * u), Offset(6 * u, 9 * u)], // red (left)
      [Offset(6 * u, 6 * u), Offset(9 * u, 6 * u)], // green (top)
      [Offset(9 * u, 6 * u), Offset(9 * u, 9 * u)], // yellow (right)
      [Offset(6 * u, 9 * u), Offset(9 * u, 9 * u)], // blue (bottom)
    ];
    final mid = Offset(7.5 * u, 7.5 * u);
    for (int k = 0; k < 4; k++) {
      final p = Path()
        ..moveTo(tri[k][0].dx, tri[k][0].dy)
        ..lineTo(tri[k][1].dx, tri[k][1].dy)
        ..lineTo(mid.dx, mid.dy)
        ..close();
      canvas.drawPath(p, Paint()..color = kPlayerColors[k]);
      canvas.drawPath(p, Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1);
    }
    canvas.restore();
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(u * .4)),
      Paint()
        ..color = const Color(0xFF263238)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  Path _star(Offset c, double r) {
    final p = Path();
    for (int i = 0; i < 10; i++) {
      final rad = i.isEven ? r : r * .45;
      final a = -pi / 2 + i * pi / 5;
      final pt = Offset(c.dx + rad * cos(a), c.dy + rad * sin(a));
      if (i == 0) {
        p.moveTo(pt.dx, pt.dy);
      } else {
        p.lineTo(pt.dx, pt.dy);
      }
    }
    p.close();
    return p;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class TokenView extends StatelessWidget {
  final Color color;
  final double glow; // 0..1 pulsing highlight (0 = none)
  final bool highlighted;
  const TokenView({super.key, required this.color, this.glow = 0, this.highlighted = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-.3, -.35),
          colors: [lighten(color, .28), color, darken(color, .15)],
          stops: const [0, .55, 1],
        ),
        border: Border.all(color: Colors.white, width: highlighted ? 2.5 : 1.8),
        boxShadow: [
          BoxShadow(color: Colors.black45, blurRadius: 4, offset: const Offset(0, 2)),
          if (highlighted)
            BoxShadow(color: Colors.white.withOpacity(.5 + .5 * glow), blurRadius: 6 + 8 * glow, spreadRadius: 1 + 2 * glow),
        ],
      ),
      child: Center(
        child: FractionallySizedBox(
          widthFactor: .38,
          heightFactor: .38,
          child: DecoratedBox(
            decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(.35)),
          ),
        ),
      ),
    );
  }
}
