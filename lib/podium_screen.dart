import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
// NOTE: these imports match the podium_screen.dart you sent (all files in the same folder).
// If your files are in sub-folders, use:  '../models.dart'  and  '../services/sfx.dart'
import 'models.dart';
import 'sfx.dart';
import 'game_screen.dart';
import 'menu_screen.dart';

class PodiumScreen extends StatefulWidget {
  final GameConfig config;
  final List<int> ranking; // colours, 1st first (Team Up: winning team first)

  const PodiumScreen({super.key, required this.config, required this.ranking});

  @override
  State<PodiumScreen> createState() => _PodiumScreenState();
}

class _PodiumScreenState extends State<PodiumScreen> with SingleTickerProviderStateMixin {
  final ConfettiController _conf = ConfettiController(duration: const Duration(seconds: 6));
  late final AnimationController _rise =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..forward();

  bool get _team => widget.config.teamUp && widget.ranking.length == 4;

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

  // ------------------------------------------------------------ normal podium

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
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [kPlayerColors[color], darken(kPlayerColors[color], .2)],
                  ),
                ),
                child: Text(ordinal(rank + 1), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _normalResult() {
    return Column(
      children: [
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
      ],
    );
  }

  // ------------------------------------------------------------ Team Up result

  Widget _player(int color, {required double radius, bool crown = false}) {
    final col = kPlayerColors[color];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (crown) const Text('👑', style: TextStyle(fontSize: 30)),
          Container(
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2.5), boxShadow: [BoxShadow(color: col.withOpacity(.6), blurRadius: 18)]),
            child: CircleAvatar(
              radius: radius,
              backgroundColor: col,
              child: Icon(_bot(color) ? Icons.smart_toy_rounded : Icons.person_rounded, color: Colors.white, size: radius),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 110,
            child: Text(_name(color), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
          ),
          Text(kColorNames[color], style: TextStyle(color: col, fontWeight: FontWeight.w700, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _teamResult() {
    final team = widget.ranking.first % 2;
    final winners = widget.ranking.where((c) => c % 2 == team).toList();
    final losers = widget.ranking.where((c) => c % 2 != team).toList();
    return AnimatedBuilder(
      animation: _rise,
      builder: (_, __) {
        final t = Curves.easeOutBack.transform(_rise.value.clamp(0.0, 1.0));
        return Column(
          children: [
            const Spacer(),
            Transform.scale(
              scale: t,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: LinearGradient(colors: [lighten(kTeamColors[team], .08), darken(kTeamColors[team], .1)]),
                  border: Border.all(color: Colors.white54, width: 1.5),
                  boxShadow: [BoxShadow(color: kTeamColors[team].withOpacity(.6), blurRadius: 24)],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('TEAM ${team == 0 ? 'A' : 'B'}', style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: 3, color: Colors.white)),
                    Text(kTeamNames[team], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 26),
            Opacity(
              opacity: t.clamp(0.0, 1.0),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [for (final c in winners) _player(c, radius: 32, crown: true)]),
            ),
            const SizedBox(height: 30),
            Opacity(
              opacity: .75 * t.clamp(0.0, 1.0),
              child: Column(
                children: [
                  const Text('RUNNER-UP', style: TextStyle(color: Colors.white54, letterSpacing: 3, fontSize: 12, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [for (final c in losers) _player(c, radius: 20)]),
                ],
              ),
            ),
            const Spacer(),
          ],
        );
      },
    );
  }

  // ------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    final team = _team ? widget.ranking.first % 2 : 0;
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
                  Text(_team ? '🏆 TEAM WINS 🏆' : '🏆 VICTORY 🏆',
                      style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: 3, color: Colors.white)),
                  const SizedBox(height: 4),
                  if (widget.ranking.isNotEmpty)
                    Text(
                      _team ? '${_name(widget.ranking.first)} & ${_name(widget.ranking.firstWhere((c) => c % 2 == team && c != widget.ranking.first))}' : '${_name(widget.ranking.first)} wins!',
                      style: const TextStyle(fontSize: 18, color: Colors.white70),
                    ),
                  Expanded(child: _team ? _teamResult() : _normalResult()),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                    child: Row(
                      children: [
                        Expanded(
                          child: FancyButton(
                            color: const Color(0xFF2EBD59),
                            radius: 20,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            onTap: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => GameScreen(config: widget.config))),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.replay_rounded, color: Colors.white),
                                SizedBox(width: 8),
                                Text('Play Again', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 16)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: FancyButton(
                            color: const Color(0xFF5B3FD6),
                            radius: 20,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            onTap: () => Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const MenuScreen()), (_) => false),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.home_rounded, color: Colors.white),
                                SizedBox(width: 8),
                                Text('Home', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 16)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
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
