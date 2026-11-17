import 'package:flutter/material.dart';
import 'progress.dart';
import 'sfx.dart';

/// Gold pill showing the coin balance. Tap handler is optional.
class CoinChip extends StatelessWidget {
  final VoidCallback? onTap;
  const CoinChip({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Progress.i,
      builder: (_, __) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xFF3B2F7A),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFFFC107), width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🪙', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              Text('${Progress.i.coins}', style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }
}

/// 7-day daily reward dialog.
Future<void> showDailyDialog(BuildContext context) async {
  final p = Progress.i;
  if (!p.dailyAvailable) return;
  final day = p.nextStreak;
  final cur = ((day - 1) % 7) + 1;

  Widget tile(int d) {
    final isCur = d == cur;
    final past = d < cur;
    return Container(
      width: 62,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: isCur ? const Color(0xFFFFC107) : const Color(0xFF3B2F7A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isCur ? Colors.white : Colors.white24, width: isCur ? 2 : 1),
      ),
      child: Column(
        children: [
          Text('Day $d', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isCur ? Colors.black : Colors.white70)),
          const SizedBox(height: 4),
          Text(past ? '✅' : '🪙', style: const TextStyle(fontSize: 18)),
          Text('${Progress.dailyReward(d)}', style: TextStyle(fontWeight: FontWeight.w900, color: isCur ? Colors.black : Colors.white)),
        ],
      ),
    );
  }

  await showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF241B4B),
      title: const Text('🎁 Daily Reward', textAlign: TextAlign.center),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Day $day in a row! Come back every day for more.', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 14),
          Wrap(spacing: 6, runSpacing: 6, alignment: WrapAlignment.center, children: [for (int d = 1; d <= 7; d++) tile(d)]),
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2EBD59), padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12)),
          onPressed: () {
            Progress.i.claimDaily();
            Sfx.i.play('coin');
            Navigator.pop(ctx);
          },
          child: Text('Claim +${Progress.dailyReward(day)} 🪙', style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white)),
        ),
      ],
    ),
  );
}

/// Coins + achievements earned in the match that just finished (podium screen).
class RewardSummary extends StatelessWidget {
  const RewardSummary({super.key});

  @override
  Widget build(BuildContext context) {
    final p = Progress.i;
    if (p.lastGameCoins <= 0 && p.lastGameAch.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFF3B2F7A),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFFFC107), width: 1.5),
            ),
            child: Text('+${p.lastGameCoins} 🪙 earned', style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white)),
          ),
          for (final a in p.lastGameAch)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('${a.icon} ${a.title} unlocked', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.w700, fontSize: 13)),
            ),
        ],
      ),
    );
  }
}
