import 'dart:math';
import 'package:flutter/material.dart';
import 'progress.dart';
import 'rewards_ui.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF14102B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF241B4B),
        title: const Text('Stats & Achievements', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: const [CoinChip(), SizedBox(width: 12)],
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Progress.i,
          builder: (_, __) {
            final p = Progress.i;
            final games = p.stat('games'), wins = p.stat('wins');
            final rate = games == 0 ? 0 : (wins * 100 / games).round();
            Widget tile(String icon, String label, String value) => Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(color: const Color(0xFF241B4B), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white12)),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(icon, style: const TextStyle(fontSize: 22)),
                      const SizedBox(height: 4),
                      Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
                      Text(label, style: const TextStyle(fontSize: 11, color: Colors.white60)),
                    ],
                  ),
                );
            return ListView(
              padding: const EdgeInsets.all(14),
              children: [
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.15,
                  children: [
                    tile('🎲', 'Games', '$games'),
                    tile('🏆', 'Wins', '$wins'),
                    tile('📈', 'Win rate', '$rate%'),
                    tile('💥', 'Captures', '${p.stat('captures')}'),
                    tile('🏠', 'Tokens home', '${p.stat('home')}'),
                    tile('🍀', 'Sixes', '${p.stat('sixes')}'),
                  ],
                ),
                const SizedBox(height: 18),
                const Text('ACHIEVEMENTS', style: TextStyle(color: Colors.white54, letterSpacing: 2, fontWeight: FontWeight.w800, fontSize: 12)),
                const SizedBox(height: 8),
                for (final a in kAchievements) _achievement(a, p),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _achievement(Achievement a, Progress p) {
    final done = p.done.contains(a.id);
    final cur = min(p.stat(a.stat), a.goal);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF241B4B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: done ? const Color(0xFFFFC107) : Colors.white12, width: done ? 1.6 : 1),
      ),
      child: Row(
        children: [
          Opacity(opacity: done ? 1 : .4, child: Text(a.icon, style: const TextStyle(fontSize: 30))),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.title, style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
                Text(a.desc, style: const TextStyle(fontSize: 12, color: Colors.white60)),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: cur / a.goal,
                    minHeight: 7,
                    backgroundColor: Colors.white12,
                    valueColor: AlwaysStoppedAnimation(done ? const Color(0xFF2EBD59) : const Color(0xFF7C4DFF)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            children: [
              Text(done ? '✅' : '$cur/${a.goal}', style: TextStyle(fontWeight: FontWeight.w800, color: done ? Colors.white : Colors.white70, fontSize: done ? 20 : 12)),
              Text('+${a.reward}🪙', style: const TextStyle(fontSize: 11, color: Colors.amber)),
            ],
          ),
        ],
      ),
    );
  }
}
