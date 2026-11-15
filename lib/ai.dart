import 'dart:math';
import 'ludo_engine.dart';

final Random _r = Random();

/// Smart bot: prefers captures, finishing, entering the home stretch, safe squares,
/// escaping danger and pushing tokens that are near home.
int chooseMove(LudoEngine e) {
  final moves = e.legalMoves();
  if (moves.length == 1) return moves.first;
  final c = e.current;
  double bestScore = -1e9;
  int best = moves.first;
  for (final t in moves) {
    final p = e.pos[c][t];
    final to = p == -1 ? 0 : p + e.dice;
    double s = to * 0.35; // progress / push tokens near home
    if (p == -1) s += 45; // unlock a token
    if (to == kHomeProgress) {
      s += 90;
    } else if (to > 50) {
      s += 38; // safe inside the home stretch
    }
    if (to <= 50) {
      final tile = absTile(c, to);
      final caps = e.capturableAt(c, tile);
      s += caps.length * 100;
      for (final cp in caps) {
        s += e.pos[cp[0]][cp[1]] * 0.5; // prefer the most advanced victim
      }
      if (kSafeTiles.contains(tile)) {
        s += 28;
      } else {
        s -= 16 * e.threatsTo(c, tile);
      }
    }
    if (p >= 0 && p <= 50) {
      final tile = absTile(c, p);
      if (!kSafeTiles.contains(tile)) {
        final th = e.threatsTo(c, tile);
        if (th > 0) s += 18 + p * 0.2; // run away from danger
      }
    }
    s += _r.nextDouble() * 2;
    if (s > bestScore) {
      bestScore = s;
      best = t;
    }
  }
  return best;
}
