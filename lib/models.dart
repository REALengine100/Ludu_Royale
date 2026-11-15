import 'package:flutter/material.dart';

/// Color index: 0 Red (top-left), 1 Green (top-right), 2 Yellow (bottom-right), 3 Blue (bottom-left)
const List<Color> kPlayerColors = [
  Color(0xFFE53935),
  Color(0xFF43A047),
  Color(0xFFFFC107),
  Color(0xFF1E88E5),
];
const List<String> kColorNames = ['Red', 'Green', 'Yellow', 'Blue'];

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
  const GameConfig(this.players, this.vsComputer);
}
