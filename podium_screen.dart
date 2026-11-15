import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import '../models.dart';
import '../services/sfx.dart';
import 'game_screen.dart';
import 'menu_screen.dart';

class PodiumScreen extends StatefulWidget {
  final GameConfig config;
  final List<int> ranking; // colours, 1st first
  const PodiumScreen({super.key, required this.config, required this.ranking});
  @override
  State<PodiumScreen> createState() => _PodiumScreenState();
}

class _PodiumScreenState extends State<PodiumScreen> with SingleTickerProviderStateMixin {
  final ConfettiController _conf = ConfettiController(duration: const Duration(seconds: 6));
  late final AnimationController _rise =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..forward();

  @override
  void initState() {
    super.initState();
    _conf.play();
    Sfx.i.play('win');
  }

  @override
  void dispose() {
    _conf.dispose();
    _rise.dispose();
    super.dispose();
  }

  String _name(int color) => widget.config.players.firstWhere((p) => p.color == color).name;
  bool _bot(int color) => widget.config.players.firstWhere((p) => p.color == color).bot;

  Widget _slot(int rank, double height) {
    if (rank >= widget.ranking.length) return const Expanded(child: SizedBox());
    final color = widget.ranking[rank];
    return Expanded(
      child: AnimatedBuilder(
        animation: _rise,
        builder: (_, __) {
          final t = Curves.easeOutBack.transform(_rise.value.clamp(0.0, 1.0));
          return Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (rank == 0) const Text('👑', style: TextStyle(fontSize: 30)),
              CircleAvatar(
                radius: rank == 0 ? 30 : 24,
                backgroundColor: kPlayerColors[color],
                child: Icon(_bot(color) ? Icons.smart_toy_rounded : Icons.person_rounded, color: Colors.white, size: rank == 0 ? 32 : 26),
              ),
              const SizedBox(height: 6),
              Text(_name(color), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
              const SizedBox(height: 6),
              Container(
                height: height * t,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                alignment: Alignment.topCenter,
                padding: const EdgeInsets.only(top: 8),
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [kPlayerColors[color], darken(kPlayerColors[color], .2)]),
                ),
                child: Text(ordinal(rank + 1), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF2B1B6B), Color(0xFF110C2B)]),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  const SizedBox(height: 24),
                  const Text('🏆 VICTORY 🏆', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: 3, color: Colors.white)),
                  const SizedBox(height: 4),
                  if (widget.ranking.isNotEmpty)
                    Text('${_name(widget.ranking.first)} wins!', style: const TextStyle(fontSize: 18, color: Colors.white70)),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [_slot(1, 110), _slot(0, 150), _slot(2, 80)]),
                  ),
                  if (widget.ranking.length > 3)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text('4th: ${_name(widget.ranking[3])}', style: const TextStyle(color: Colors.white60, fontSize: 16)),
                    ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                    child: Row(children: [
                      Expanded(
                        child: SizedBox(
                          height: 52,
                          child: FilledButton.icon(
                            onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => GameScreen(config: widget.config))),
                            icon: const Icon(Icons.replay_rounded),
                            label: const Text('Play Again', style: TextStyle(fontWeight: FontWeight.w800)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 52,
                          child: OutlinedButton.icon(
                            onPressed: () => Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const MenuScreen()), (_) => false),
                            icon: const Icon(Icons.home_rounded),
                            label: const Text('Home', style: TextStyle(fontWeight: FontWeight.w800)),
                          ),
                        ),
                      ),
                    ]),
                  ),
                ],
              ),
              Align(
                alignment: Alignment.topCenter,
                child: ConfettiWidget(
                  confettiController: _conf,
                  blastDirectionality: BlastDirectionality.explosive,
                  emissionFrequency: .05,
                  numberOfParticles: 24,
                  gravity: .25,
                  colors: kPlayerColors,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
