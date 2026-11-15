import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../engine/ai.dart';
import '../engine/ludo_engine.dart';
import '../models.dart';
import '../services/ad_manager.dart';
import '../services/app_settings.dart';
import '../services/sfx.dart';
import '../widgets/board_painter.dart';
import '../widgets/dialogs.dart';
import '../widgets/dice_view.dart';
import 'podium_screen.dart';

class _Tk {
  final int c, t, p;
  final Offset cell;
  final String key;
  _Tk(this.c, this.t, this.p, this.cell, this.key);
}

class GameScreen extends StatefulWidget {
  final GameConfig config;
  const GameScreen({super.key, required this.config});
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  static const _turnSeconds = 15;
  static const _emojis = ['😀', '😂', '😎', '😡', '😭', '👍', '🔥', '🤯'];

  late LudoEngine engine;
  late List<List<int>> disp; // displayed progress (animated step by step)
  late final AnimationController timerCtl;
  late final AnimationController pulseCtl;
  late final AnimationController diceCtl;
  final Random rng = Random();

  bool busy = false; // dice rolling / token animating
  bool paused = false; // an ad is on screen
  bool over = false;
  List<int> movable = [];
  int face = 1; // face shown on the CURRENT player's dice while rolling
  final Map<int, int> faces = {}; // last rolled face of every player
  String status = '';
  String? banner;
  final Map<int, String> bubbles = {};
  Timer? faceTimer, bannerTimer;

  GameConfig get cfg => widget.config;
  PlayerCfg playerOf(int color) => cfg.players.firstWhere((p) => p.color == color);
  bool isBot(int color) => playerOf(color).bot;

  @override
  void initState() {
    super.initState();
    // Full screen (hide status bar + navigation bar) while the game is on
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    engine = LudoEngine(cfg.players.map((p) => p.color).toList());
    disp = engine.pos.map((e) => List<int>.from(e)).toList();
    timerCtl = AnimationController(vsync: this, duration: const Duration(seconds: _turnSeconds))
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) _onTimeout();
      });
    pulseCtl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
    diceCtl = AnimationController(vsync: this, duration: const Duration(milliseconds: 750));
    WidgetsBinding.instance.addPostFrameCallback((_) => _afterState());
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    faceTimer?.cancel();
    bannerTimer?.cancel();
    timerCtl.dispose();
    pulseCtl.dispose();
    diceCtl.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- game flow

  void _afterState() {
    if (!mounted) return;
    if (engine.phase == Phase.over) {
      _finish();
      return;
    }
    movable = [];
    final name = playerOf(engine.current).name;
    status = isBot(engine.current) ? "$name's turn" : "$name's turn - tap your dice";
    timerCtl.forward(from: 0);
    setState(() {});
    if (isBot(engine.current)) _scheduleBot();
  }

  Future<void> _scheduleBot() async {
    await Future.delayed(const Duration(milliseconds: 900));
    await _waitUnpaused();
    if (!mounted || over || busy) return;
    if (engine.phase == Phase.roll && isBot(engine.current)) _doRoll();
  }

  Future<void> _waitUnpaused() async {
    while (paused && mounted) {
      await Future.delayed(const Duration(milliseconds: 300));
    }
  }

  void _onTimeout() {
    if (!mounted || over) return;
    if (busy || paused) {
      timerCtl.forward(from: 0);
      return;
    }
    if (engine.phase == Phase.roll) {
      _doRoll();
    } else if (engine.phase == Phase.move) {
      _doMove(chooseMove(engine));
    }
  }

  Future<void> _doRoll() async {
    if (busy || paused || over || engine.phase != Phase.roll) return;
    busy = true;
    movable = [];
    final who = engine.current;
    status = '${playerOf(who).name} is rolling...';
    setState(() {});
    Sfx.i.play('dice');
    Haptics.medium();
    diceCtl.forward(from: 0);
    faceTimer?.cancel();
    faceTimer = Timer.periodic(const Duration(milliseconds: 70), (_) {
      if (mounted) setState(() => face = rng.nextInt(6) + 1);
    });
    await Future.delayed(const Duration(milliseconds: 750));
    faceTimer?.cancel();
    if (!mounted) return;

    final out = engine.roll();
    face = engine.dice;
    faces[who] = face;
    Haptics.light();
    if (out == RollOutcome.forfeit) {
      status = 'Three 6s in a row - turn forfeited!';
      _flash('3 sixes! Turn lost');
      setState(() {});
      await Future.delayed(const Duration(milliseconds: 1300));
      busy = false;
      _afterState();
      return;
    }
    if (out == RollOutcome.noMoves) {
      status = 'No valid move';
      setState(() {});
      await Future.delayed(const Duration(milliseconds: 1000));
      busy = false;
      _afterState();
      return;
    }
    movable = engine.legalMoves();
    busy = false;
    status = isBot(who) ? '${playerOf(who).name} is thinking...' : 'Tap a token to move';
    setState(() {});
    timerCtl.forward(from: 0);

    if (isBot(who)) {
      await Future.delayed(const Duration(milliseconds: 750));
      await _waitUnpaused();
      if (!mounted || over || engine.phase != Phase.move) return;
      _doMove(chooseMove(engine));
    } else if (AppSettings.i.autoMove && movable.length == 1) {
      await Future.delayed(const Duration(milliseconds: 450));
      await _waitUnpaused();
      if (mounted && !over && !busy && engine.phase == Phase.move && movable.length == 1) _doMove(movable.first);
    }
  }

  Future<void> _doMove(int t) async {
    if (busy || over || engine.phase != Phase.move || !movable.contains(t)) return;
    busy = true;
    final c = engine.current;
    final before = engine.ranking.length;
    movable = [];
    final res = engine.move(t);
    setState(() {});

    for (final p in res.path) {
      disp[c][t] = p;
      Sfx.i.play('step');
      Haptics.light();
      if (mounted) setState(() {});
      await Future.delayed(const Duration(milliseconds: 190));
      if (!mounted) return;
    }
    if (res.captured.isNotEmpty) {
      for (final cp in res.captured) {
        disp[cp[0]][cp[1]] = -1;
      }
      Sfx.i.play('capture');
      Haptics.heavy();
      _flash('💥 ${playerOf(c).name} captured a token!');
      setState(() {});
      await Future.delayed(const Duration(milliseconds: 750));
    } else if (res.reachedHome) {
      Sfx.i.play('safe');
      Haptics.medium();
      _flash('🏠 Token home!');
      await Future.delayed(const Duration(milliseconds: 500));
    } else if (res.landedSafe) {
      Sfx.i.play('safe');
    }
    if (engine.ranking.length > before && engine.phase != Phase.over) {
      _flash('🎉 ${playerOf(c).name} finished ${ordinal(engine.ranking.length)}!');
      Sfx.i.play('win');
      await Future.delayed(const Duration(milliseconds: 900));
    }
    if (!mounted) return;
    busy = false;
    _afterState();
  }

  void _onTokenTap(int color, int t) {
    if (color != engine.current || isBot(color) || busy || paused) return;
    _doMove(t);
  }

  Future<void> _finish() async {
    if (over) return;
    over = true;
    timerCtl.stop();
    setState(() => status = 'Game over!');
    await Future.delayed(const Duration(milliseconds: 1000));
    await AdManager.showInterstitial(); // interstitial BEFORE the podium
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => PodiumScreen(config: cfg, ranking: List<int>.from(engine.ranking))),
    );
  }

  // ---------------------------------------------------------------- UI helpers

  void _flash(String text) {
    banner = text;
    bannerTimer?.cancel();
    bannerTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => banner = null);
    });
    if (mounted) setState(() {});
  }

  void _sendEmoji(String e) {
    final humans = cfg.players.where((p) => !p.bot).toList();
    int sender = engine.current;
    if (isBot(sender) && humans.isNotEmpty) sender = humans.first.color;
    Sfx.i.play('pop');
    setState(() => bubbles[sender] = e);
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted && bubbles[sender] == e) setState(() => bubbles.remove(sender));
    });
  }

  void _openEmoji() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF241B4B),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 14,
          runSpacing: 14,
          children: [
            for (final e in _emojis)
              InkWell(
                borderRadius: BorderRadius.circular(30),
                onTap: () {
                  Navigator.pop(context);
                  _sendEmoji(e);
                },
                child: Padding(padding: const EdgeInsets.all(8), child: Text(e, style: const TextStyle(fontSize: 38))),
              ),
          ],
        ),
      ),
    );
  }

  Future<bool> _confirmQuit() async {
    final r = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF241B4B),
        title: const Text('Quit match?'),
        content: const Text('Your current game will be lost.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep playing')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Quit')),
        ],
      ),
    );
    return r ?? false;
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmQuit() && mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF14102B),
        body: SafeArea(
          child: Column(
            children: [
              _topBar(),
              _cardsRow([0, 1]),
              _timerBar(),
              Expanded(
                child: Center(
                  child: LayoutBuilder(builder: (_, box) {
                    final s = min(box.maxWidth - 8, box.maxHeight - 4);
                    return _board(s);
                  }),
                ),
              ),
              _cardsRow([3, 2]),
              _controls(),
              const BannerAdWidget(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar() {
    return ListenableBuilder(
      listenable: AppSettings.i,
      builder: (_, __) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              onPressed: () async {
                if (await _confirmQuit() && mounted) Navigator.of(context).pop();
              },
            ),
            const Expanded(
              child: Text('LUDO ROYALE', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 16)),
            ),
            IconButton(
              tooltip: 'Sound',
              icon: Icon(AppSettings.i.sound ? Icons.volume_up_rounded : Icons.volume_off_rounded),
              onPressed: () => AppSettings.i.setSound(!AppSettings.i.sound),
            ),
            IconButton(
              tooltip: 'Vibration',
              icon: Icon(AppSettings.i.vibration ? Icons.vibration_rounded : Icons.mobile_off_rounded),
              onPressed: () => AppSettings.i.setVibration(!AppSettings.i.vibration),
            ),
            IconButton(tooltip: 'Settings', icon: const Icon(Icons.settings_rounded), onPressed: () => showSettingsDialog(context)),
          ],
        ),
      ),
    );
  }

  Widget _cardsRow(List<int> colors) {
    return Row(
      children: [
        for (final c in colors)
          Expanded(child: cfg.players.any((p) => p.color == c) ? _card(c) : const SizedBox(height: 72)),
      ],
    );
  }

  /// The dice that sits beside each player's home/card.
  Widget _playerDice(int color) {
    final isCur = engine.current == color && !over && !engine.ranking.contains(color);
    final canRoll = isCur && !isBot(color) && engine.phase == Phase.roll && !busy && !paused;
    final value = isCur ? face : (faces[color] ?? 1);
    final accent = kPlayerColors[color];

    Widget dice = DiceView(value: value, accent: accent, size: 46, glow: canRoll && pulseCtl.value > .4);
    if (isCur) {
      dice = AnimatedBuilder(
        animation: diceCtl,
        builder: (_, child) {
          final t = diceCtl.value;
          final m = Matrix4.identity()
            ..setEntry(3, 2, .0015)
            ..rotateX(sin(t * pi * 4) * (1 - t) * 1.3)
            ..rotateY(sin(t * pi * 3) * (1 - t) * 1.5)
            ..rotateZ(sin(t * pi * 5) * (1 - t) * .5);
          return Transform.translate(
            offset: Offset(0, -sin(t * pi) * 8),
            child: Transform(alignment: Alignment.center, transform: m, child: child),
          );
        },
        child: dice,
      );
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: canRoll ? _doRoll : null,
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Opacity(opacity: isCur ? 1 : .55, child: dice),
      ),
    );
  }

  Widget _card(int color) {
    final pc = playerOf(color);
    final active = engine.current == color && !over && !engine.ranking.contains(color);
    final home = disp[color].where((p) => p == kHomeProgress).length;
    final rank = engine.ranking.indexOf(color);
    final col = kPlayerColors[color];
    return AnimatedBuilder(
      animation: pulseCtl,
      builder: (_, __) => Container(
        height: 64,
        margin: const EdgeInsets.fromLTRB(6, 4, 6, 4),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF241B4B),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: active ? Colors.white : col.withOpacity(.6), width: active ? 2.5 : 1.5),
          boxShadow: active ? [BoxShadow(color: col.withOpacity(.5 + .4 * pulseCtl.value), blurRadius: 8 + 14 * pulseCtl.value, spreadRadius: 1 + 2 * pulseCtl.value)] : [],
        ),
        child: Row(
          children: [
            CircleAvatar(radius: 15, backgroundColor: col, child: Icon(pc.bot ? Icons.smart_toy_rounded : Icons.person_rounded, size: 18, color: Colors.white)),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(pc.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                  Text(rank >= 0 ? '#${rank + 1}  🏠 $home/4' : '🏠 $home/4', style: TextStyle(fontSize: 11, color: rank >= 0 ? Colors.amber : Colors.white70)),
                ],
              ),
            ),
            if (bubbles[color] != null)
              Container(
                margin: const EdgeInsets.only(right: 4),
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                child: Text(bubbles[color]!, style: const TextStyle(fontSize: 18)),
              ),
            _playerDice(color),
          ],
        ),
      ),
    );
  }

  Widget _timerBar() {
    return AnimatedBuilder(
      animation: timerCtl,
      builder: (_, __) {
        final left = (1 - timerCtl.value);
        final color = over ? Colors.grey : kPlayerColors[engine.current];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: over ? 0 : left,
              minHeight: 7,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation(left < .25 ? Colors.redAccent : color),
            ),
          ),
        );
      },
    );
  }

  Widget _board(double s) {
    final u = s / 15;
    return SizedBox(
      width: s,
      height: s,
      child: Stack(
        children: [
          const Positioned.fill(child: CustomPaint(painter: BoardPainter())),
          ..._tokens(u),
          if (banner != null)
            Positioned.fill(
              child: IgnorePointer(
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(16)),
                    child: Text(banner!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _tokens(double u) {
    final items = <_Tk>[];
    for (final pc in cfg.players) {
      for (int t = 0; t < 4; t++) {
        final p = disp[pc.color][t];
        final cell = cellCenter(pc.color, p, t);
        final key = p == -1
            ? 'b${pc.color}$t'
            : p == kHomeProgress
                ? 'h${pc.color}'
                : '${cell.dx.toStringAsFixed(2)},${cell.dy.toStringAsFixed(2)}';
        items.add(_Tk(pc.color, t, p, cell, key));
      }
    }
    final groups = <String, List<_Tk>>{};
    for (final k in items) {
      groups.putIfAbsent(k.key, () => []).add(k);
    }
    final normal = <Widget>[];
    final hi = <Widget>[];
    final curHuman = !isBot(engine.current);
    groups.forEach((_, list) {
      final n = list.length;
      final isBase = list.first.p == -1;
      final double sz = isBase ? .95 : n == 1 ? .8 : n == 2 ? .62 : n <= 4 ? .52 : .42;
      final double sp = n <= 2 ? .36 : .33;
      final cols = n <= 2 ? n : sqrt(n).ceil();
      final rows = (n / cols).ceil();
      for (int i = 0; i < n; i++) {
        final k = list[i];
        final dx = n == 1 ? 0.0 : ((i % cols) - (cols - 1) / 2) * sp;
        final dy = n == 1 ? 0.0 : ((i ~/ cols) - (rows - 1) / 2) * sp;
        final highlighted = curHuman && !busy && k.c == engine.current && movable.contains(k.t);
        final w = AnimatedPositioned(
          key: ValueKey('tk${k.c}_${k.t}'),
          duration: const Duration(milliseconds: 170),
          curve: Curves.easeInOut,
          left: (k.cell.dx + dx - sz / 2) * u,
          top: (k.cell.dy + dy - sz / 2) * u,
          width: sz * u,
          height: sz * u,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _onTokenTap(k.c, k.t),
            child: AnimatedBuilder(
              animation: pulseCtl,
              builder: (_, __) => Transform.scale(
                scale: highlighted ? 1 + .12 * pulseCtl.value : 1,
                child: TokenView(color: kPlayerColors[k.c], highlighted: highlighted, glow: pulseCtl.value),
              ),
            ),
          ),
        );
        (highlighted ? hi : normal).add(w);
      }
    });
    return [...normal, ...hi];
  }

  /// Bottom bar: status text + chat button (dice, Re-roll and Undo are gone).
  Widget _controls() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(status, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          ),
          const SizedBox(width: 8),
          _pill(Icons.emoji_emotions_rounded, 'Chat', true, _openEmoji),
        ],
      ),
    );
  }

  Widget _pill(IconData icon, String label, bool enabled, VoidCallback onTap) {
    return Opacity(
      opacity: enabled ? 1 : .4,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(color: const Color(0xFF241B4B), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white24)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16),
              const SizedBox(width: 5),
              Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
            ],
          ),
        ),
      ),
    );
  }
}
