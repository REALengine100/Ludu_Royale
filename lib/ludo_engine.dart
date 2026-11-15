import 'dart:math';

/// Progress model for every token:
///   -1      = in base (yard)
///   0..50   = on the 52-tile outer track (0 = own start square; tile before start is skipped)
///   51..55  = home stretch (5 tiles)
///   56      = reached the centre home triangle
const int kTrackLen = 52;
const int kHomeProgress = 56;

/// Absolute track tiles that are safe: 4 coloured start squares + 4 star squares.
const List<int> kSafeTiles = [0, 8, 13, 21, 26, 34, 39, 47];
const List<int> kStarTiles = [8, 21, 34, 47];

/// 52 outer track cells as [col,row] on the 15x15 grid, clockwise, starting at Red's start square.
const List<List<int>> kTrack = [
  [1, 6], [2, 6], [3, 6], [4, 6], [5, 6],
  [6, 5], [6, 4], [6, 3], [6, 2], [6, 1], [6, 0],
  [7, 0], [8, 0],
  [8, 1], [8, 2], [8, 3], [8, 4], [8, 5],
  [9, 6], [10, 6], [11, 6], [12, 6], [13, 6], [14, 6],
  [14, 7], [14, 8],
  [13, 8], [12, 8], [11, 8], [10, 8], [9, 8],
  [8, 9], [8, 10], [8, 11], [8, 12], [8, 13], [8, 14],
  [7, 14], [6, 14],
  [6, 13], [6, 12], [6, 11], [6, 10], [6, 9],
  [5, 8], [4, 8], [3, 8], [2, 8], [1, 8], [0, 8],
  [0, 7], [0, 6],
];

/// Home stretch cells per colour (Red, Green, Yellow, Blue).
const List<List<List<int>>> kStretch = [
  [[1, 7], [2, 7], [3, 7], [4, 7], [5, 7]],
  [[7, 1], [7, 2], [7, 3], [7, 4], [7, 5]],
  [[13, 7], [12, 7], [11, 7], [10, 7], [9, 7]],
  [[7, 13], [7, 12], [7, 11], [7, 10], [7, 9]],
];

int absTile(int color, int p) => (color * 13 + p) % kTrackLen;

enum Phase { roll, move, over }

enum RollOutcome { moves, noMoves, forfeit }

class MoveResult {
  final int color;
  final int token;
  final int from;
  final int to;
  final List<int> path;
  final List<List<int>> captured; // [color, token]
  final bool reachedHome;
  final bool landedSafe;
  final bool bonus;
  const MoveResult({
    required this.color,
    required this.token,
    required this.from,
    required this.to,
    required this.path,
    required this.captured,
    required this.reachedHome,
    required this.landedSafe,
    required this.bonus,
  });
}

class LudoEngine {
  final List<int> colors; // active colours in turn order
  final List<List<int>> pos; // pos[color][token]
  int turn = 0;
  int dice = 1;
  int sixes = 0;
  Phase phase = Phase.roll;
  final List<int> ranking; // colours in finishing order
  final Random rng;

  LudoEngine(this.colors, {Random? rng})
      : pos = List.generate(4, (_) => List.filled(4, -1)),
        ranking = [],
        rng = rng ?? Random();

  LudoEngine._copy(LudoEngine o)
      : colors = o.colors,
        pos = o.pos.map((e) => List<int>.from(e)).toList(),
        turn = o.turn,
        dice = o.dice,
        sixes = o.sixes,
        phase = o.phase,
        ranking = List<int>.from(o.ranking),
        rng = o.rng;

  LudoEngine clone() => LudoEngine._copy(this);

  int get current => colors[turn];

  /// Rolls the dice. Handles three-sixes forfeit and auto-skip when nothing can move.
  RollOutcome roll([int? forced]) {
    dice = forced ?? rng.nextInt(6) + 1;
    if (dice == 6) {
      sixes++;
    } else {
      sixes = 0;
    }
    if (sixes >= 3) {
      sixes = 0;
      _advance();
      return RollOutcome.forfeit;
    }
    if (legalMoves().isEmpty) {
      sixes = 0;
      _advance();
      return RollOutcome.noMoves;
    }
    phase = Phase.move;
    return RollOutcome.moves;
  }

  /// Used by the rewarded "re-roll" power-up: cancels the current roll.
  void resetRoll() {
    if (dice == 6 && sixes > 0) sixes--;
    phase = Phase.roll;
  }

  List<int> legalMoves() {
    final c = current;
    final res = <int>[];
    for (int t = 0; t < 4; t++) {
      final p = pos[c][t];
      if (p == -1) {
        if (dice == 6) res.add(t);
      } else if (p < kHomeProgress && p + dice <= kHomeProgress) {
        res.add(t);
      }
    }
    return res;
  }

  /// Opponent tokens that would be captured by landing on [tile] (single tokens, non-safe only).
  List<List<int>> capturableAt(int color, int tile) {
    final res = <List<int>>[];
    if (kSafeTiles.contains(tile)) return res;
    for (final oc in colors) {
      if (oc == color) continue;
      final here = <int>[];
      for (int i = 0; i < 4; i++) {
        final p = pos[oc][i];
        if (p >= 0 && p <= 50 && absTile(oc, p) == tile) here.add(i);
      }
      if (here.length == 1) res.add([oc, here[0]]); // 2+ stacked = block, not capturable
    }
    return res;
  }

  /// How many opponent tokens are 1..6 tiles behind [tile] (i.e. could hit it next turn).
  int threatsTo(int color, int tile) {
    int n = 0;
    for (final oc in colors) {
      if (oc == color) continue;
      for (int i = 0; i < 4; i++) {
        final p = pos[oc][i];
        if (p < 0 || p > 50) continue;
        final d = (tile - absTile(oc, p) + kTrackLen) % kTrackLen;
        if (d >= 1 && d <= 6) n++;
      }
    }
    return n;
  }

  MoveResult move(int t) {
    final c = current;
    final from = pos[c][t];
    final path = <int>[];
    int to;
    if (from == -1) {
      to = 0;
      path.add(0);
    } else {
      to = from + dice;
      for (int p = from + 1; p <= to; p++) {
        path.add(p);
      }
    }
    pos[c][t] = to;

    final captured = <List<int>>[];
    bool landedSafe = false;
    if (to <= 50) {
      final tile = absTile(c, to);
      landedSafe = kSafeTiles.contains(tile);
      for (final cp in capturableAt(c, tile)) {
        pos[cp[0]][cp[1]] = -1;
        captured.add(cp);
      }
    }
    final reached = to == kHomeProgress;
    bool bonus = dice == 6 || captured.isNotEmpty || reached;

    if (pos[c].every((p) => p == kHomeProgress)) {
      ranking.add(c);
      bonus = false;
    }
    final remaining = colors.where((x) => !ranking.contains(x)).toList();
    if (remaining.length <= 1) {
      if (remaining.length == 1) ranking.add(remaining.first);
      phase = Phase.over;
    } else if (bonus) {
      phase = Phase.roll; // same player rolls again
    } else {
      _advance();
    }
    return MoveResult(
      color: c,
      token: t,
      from: from,
      to: to,
      path: path,
      captured: captured,
      reachedHome: reached,
      landedSafe: landedSafe,
      bonus: bonus,
    );
  }

  void _advance() {
    sixes = 0;
    do {
      turn = (turn + 1) % colors.length;
    } while (ranking.contains(colors[turn]));
    phase = Phase.roll;
  }
}
