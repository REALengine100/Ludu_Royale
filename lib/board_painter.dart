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
        canvas.drawCircle(c, u * .68, Paint()..color = darken(col, .38));
        canvas.drawCircle(c, u * .68, Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
        canvas.drawCircle(c, u * .52, Paint()..color = Colors.black.withOpacity(.2));
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

/// Premium 3D pawn with dark edge, glow highlight and dim state.
class TokenView extends StatelessWidget {
  final Color color;
  final double glow; // 0..1 pulsing value
  final bool highlighted; // movable now
  final bool dimmed; // not movable while it's this player's turn
  const TokenView({
    super.key,
    required this.color,
    this.glow = 0,
    this.highlighted = false,
    this.dimmed = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: CustomPaint(painter: _PawnPainter(color, highlighted, glow, dimmed)),
    );
  }
}

class _PawnPainter extends CustomPainter {
  final Color color;
  final bool highlighted;
  final double glow;
  final bool dimmed;
  _PawnPainter(this.color, this.highlighted, this.glow, this.dimmed);

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    if (dimmed) {
      canvas.saveLayer(Offset.zero & s, Paint()..color = Colors.white.withOpacity(.5));
    }

    // ground shadow
    canvas.drawOval(
      Rect.fromLTWH(w * .14, h * .80, w * .72, h * .16),
      Paint()
        ..color = Colors.black.withOpacity(.4)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * .04),
    );

    // highlight: golden halo + ring, pawn lifts up and down
    if (highlighted) {
      const gold = Color(0xFFFFD600);
      canvas.drawCircle(
        Offset(w * .5, h * .5),
        w * .62,
        Paint()
          ..color = gold.withOpacity(.20 + .25 * glow)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * .12),
      );
      final ring = Rect.fromLTWH(w * .02, h * .68, w * .96, h * .30);
      canvas.drawOval(
        ring,
        Paint()
          ..color = Colors.black.withOpacity(.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * .11,
      );
      canvas.drawOval(
        ring,
        Paint()
          ..color = gold.withOpacity(.75 + .25 * glow)
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * .075,
      );
      canvas.translate(0, -h * .05 * glow);
    }

    final light = lighten(color, .32);
    final dark = darken(color, .22);

    final edge = Paint()
      ..color = const Color(0xFF1A1A1A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * .11
      ..strokeJoin = StrokeJoin.round;
    final outline = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * .055
      ..strokeJoin = StrokeJoin.round;

    // base disc
    final baseRect = Rect.fromLTWH(w * .15, h * .70, w * .70, h * .22);
    canvas.drawOval(baseRect, edge);
    canvas.drawOval(baseRect, outline);
    canvas.drawOval(
      baseRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [light, color, dark],
        ).createShader(baseRect),
    );

    // body
    final body = Path()
      ..moveTo(w * .22, h * .80)
      ..quadraticBezierTo(w * .44, h * .70, w * .42, h * .46)
      ..lineTo(w * .58, h * .46)
      ..quadraticBezierTo(w * .56, h * .70, w * .78, h * .80)
      ..quadraticBezierTo(w * .50, h * .87, w * .22, h * .80)
      ..close();
    canvas.drawPath(body, edge);
    canvas.drawPath(body, outline);
    canvas.drawPath(
      body,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [light, color, dark],
          stops: const [0, .45, 1],
        ).createShader(Rect.fromLTWH(w * .2, h * .46, w * .6, h * .4)),
    );

    // collar
    final collar = Rect.fromLTWH(w * .33, h * .40, w * .34, h * .11);
    canvas.drawOval(collar, edge);
    canvas.drawOval(collar, outline);
    canvas.drawOval(
      collar,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [lighten(color, .45), color],
        ).createShader(collar),
    );

    // head
    final headC = Offset(w * .5, h * .29);
    final headR = w * .205;
    canvas.drawCircle(headC, headR, edge);
    canvas.drawCircle(headC, headR, outline);
    canvas.drawCircle(
      headC,
      headR,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-.4, -.45),
          radius: 1.0,
          colors: [lighten(color, .55), color, dark],
          stops: const [0, .55, 1],
        ).createShader(Rect.fromCircle(center: headC, radius: headR)),
    );
    canvas.drawCircle(Offset(w * .43, h * .22), w * .055, Paint()..color = Colors.white.withOpacity(.8));

    if (dimmed) canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PawnPainter old) =>
      old.color != color || old.highlighted != highlighted || old.glow != glow || old.dimmed != dimmed;
}
