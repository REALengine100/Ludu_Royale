import 'package:flutter/material.dart';

/// Color index: 0 Red (top-left), 1 Green (top-right), 2 Yellow (bottom-right), 3 Blue (bottom-left)
const List<Color> kPlayerColors = [
  Color(0xFFE53935),
  Color(0xFF43A047),
  Color(0xFFFFC107),
  Color(0xFF1E88E5),
];
const List<String> kColorNames = ['Red', 'Green', 'Yellow', 'Blue'];

/// Team Up teams: partners sit opposite each other (colour % 2 decides the team).
const List<String> kTeamNames = ['Red & Yellow', 'Green & Blue'];
const List<Color> kTeamColors = [Color(0xFFFF7043), Color(0xFF26A69A)];

Color darken(Color c, [double amount = .25]) {
  final h = HSLColor.fromColor(c);
  return h.withLightness((h.lightness - amount).clamp(0.0, 1.0)).toColor();
}

Color lighten(Color c, [double amount = .25]) {
  final h = HSLColor.fromColor(c);
  return h.withLightness((h.lightness + amount).clamp(0.0, 1.0)).toColor();
}

String ordinal(int n) => n == 1 ? '1st' : n == 2 ? '2nd' : n == 3 ? '3rd' : '${n}th';

class PlayerCfg {
  final int color;
  final String name;
  final bool bot;
  const PlayerCfg(this.color, this.name, this.bot);
}

class GameConfig {
  final List<PlayerCfg> players;
  final bool vsComputer;

  /// Team Up mode (needs exactly 4 players: Red+Yellow vs Green+Blue).
  final bool teamUp;
  const GameConfig(this.players, this.vsComputer, {this.teamUp = false});
}
