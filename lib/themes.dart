import 'package:flutter/material.dart';
import 'progress.dart';

class BoardTheme {
  final String id, name;
  final int price;
  final Color cell, line, inner, star, frame;
  final double quadDark; // how much the four corner colours are darkened
  const BoardTheme(this.id, this.name, this.price, this.cell, this.line, this.inner, this.star, this.frame, this.quadDark);
}

const List<BoardTheme> kBoardThemes = [
  BoardTheme('classic', 'Classic', 0, Color(0xFFFFFFFF), Color(0xFF9E9E9E), Color(0xFFFFFFFF), Color(0xFF757575), Color(0xFF263238), 0),
  BoardTheme('wood', 'Wooden', 150, Color(0xFFF3E2C4), Color(0xFFB08D57), Color(0xFFF7EBD3), Color(0xFF8D6E63), Color(0xFF4E342E), 0),
  BoardTheme('ocean', 'Ocean', 200, Color(0xFFE3F2FD), Color(0xFF90CAF9), Color(0xFFFFFFFF), Color(0xFF1565C0), Color(0xFF0D47A1), 0),
  BoardTheme('midnight', 'Midnight', 300, Color(0xFF26224A), Color(0xFF4A4480), Color(0xFF332E66), Color(0xFFFFD54F), Color(0xFF000000), .3),
  BoardTheme('neon', 'Neon', 450, Color(0xFF0D0D1A), Color(0xFF00B8D4), Color(0xFF1A1A33), Color(0xFFFF4081), Color(0xFF00E5FF), .25),
];

class DiceTheme {
  final String id, name;
  final int price;
  final List<Color> body; // 3 colours, light -> dark
  final List<Color> pip; // 3 colours for the dots
  const DiceTheme(this.id, this.name, this.price, this.body, this.pip);
}

const List<DiceTheme> kDiceThemes = [
  DiceTheme('classic', 'Ivory', 0, [Color(0xFFFFFFFF), Color(0xFFF1F2F8), Color(0xFFC7CCDB)], [Color(0xFF6A6F8F), Color(0xFF1B1840), Color(0xFF0D0B22)]),
  DiceTheme('ice', 'Ice', 150, [Color(0xFFE1F5FE), Color(0xFFB3E5FC), Color(0xFF4FC3F7)], [Color(0xFF42A5F5), Color(0xFF0D47A1), Color(0xFF0A2F6B)]),
  DiceTheme('gold', 'Golden', 200, [Color(0xFFFFF8E1), Color(0xFFFFE082), Color(0xFFFFB300)], [Color(0xFF8D6E63), Color(0xFF4E342E), Color(0xFF3E2723)]),
  DiceTheme('candy', 'Candy', 250, [Color(0xFFFCE4EC), Color(0xFFF8BBD0), Color(0xFFF06292)], [Color(0xFFD81B60), Color(0xFF880E4F), Color(0xFF560027)]),
  DiceTheme('dark', 'Obsidian', 300, [Color(0xFF5C6080), Color(0xFF2E3050), Color(0xFF14152A)], [Color(0xFFFFFFFF), Color(0xFFE0E0E0), Color(0xFFBDBDBD)]),
];

class PawnInfo {
  final String id, name;
  final int price;
  const PawnInfo(this.id, this.name, this.price);
}

const List<PawnInfo> kPawnStyles = [
  PawnInfo('classic', 'Classic Pawn', 0),
  PawnInfo('ball', 'Glossy Ball', 200),
  PawnInfo('gem', 'Gem', 350),
];

BoardTheme boardThemeById(String id) => kBoardThemes.firstWhere((t) => t.id == id, orElse: () => kBoardThemes.first);
DiceTheme diceThemeById(String id) => kDiceThemes.firstWhere((t) => t.id == id, orElse: () => kDiceThemes.first);

BoardTheme currentBoard() => boardThemeById(Progress.i.board);
DiceTheme currentDice() => diceThemeById(Progress.i.dice);
String currentPawn() => Progress.i.pawn;
