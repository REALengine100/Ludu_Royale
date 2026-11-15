import 'package:flutter/material.dart';
import '../services/app_settings.dart';

void showSettingsDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFF241B4B),
      title: const Text('Settings', style: TextStyle(color: Colors.white)),
      content: ListenableBuilder(
        listenable: AppSettings.i,
        builder: (_, __) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              title: const Text('Sound effects', style: TextStyle(color: Colors.white)),
              value: AppSettings.i.sound,
              onChanged: AppSettings.i.setSound,
            ),
            SwitchListTile(
              title: const Text('Vibration', style: TextStyle(color: Colors.white)),
              value: AppSettings.i.vibration,
              onChanged: AppSettings.i.setVibration,
            ),
            SwitchListTile(
              title: const Text('Auto-move (single option)', style: TextStyle(color: Colors.white)),
              subtitle: const Text('Moves automatically when only one move is possible',
                  style: TextStyle(color: Colors.white60, fontSize: 12)),
              value: AppSettings.i.autoMove,
              onChanged: AppSettings.i.setAutoMove,
            ),
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
    ),
  );
}

void showRulesDialog(BuildContext context) {
  const rules = [
    'Roll a 6 to bring a token out of base. Rolling a 6 always gives another roll.',
    'Three 6s in a row cancel your turn.',
    'Move tokens clockwise around the 52-tile track, then up your coloured home column.',
    'Landing on a single opponent token (not on a safe square) sends it back to base and gives you a bonus roll.',
    'Safe squares: the 4 coloured start squares and the 4 star squares. Tokens there cannot be captured.',
    'Two or more tokens of the same colour on a square form a block and cannot be captured.',
    'You need the exact number to reach the centre. Reaching home gives a bonus roll.',
    'If no move is possible your turn is skipped automatically.',
    'Rank is decided by finishing order: the first to bring all 4 tokens home wins.',
  ];
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFF241B4B),
      title: const Text('How to play', style: TextStyle(color: Colors.white)),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final r in rules)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text('•  $r', style: const TextStyle(color: Colors.white70, height: 1.35)),
              ),
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Got it'))],
    ),
  );
}
