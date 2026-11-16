import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../engine/ai.dart';
import '../engine/ludo_engine.dart';
import '../models.dart';
import '../services/app_settings.dart';
import '../services/sfx.dart';
import '../widgets/board_painter.dart';
import '../widgets/dialogs.dart';
import '../widgets/dice_view.dart';
import 'menu_screen.dart' show FancyButton;
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

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
  static const _emojis = ['😀', '😂', '😎', '😡', '😭', '👍', '🔥', '🤯'];

  late LudoEngine engine;
  late List<List<int>> disp; // displayed progress (animated step by step)
  late final AnimationController pulseCtl;
  late final AnimationController diceCtl;
  final Random rng = Random();

  bool busy = false; // dice rolling / token animating
  bool over = false;
  List<int> movable = [];
  int face = 1; // face shown on the CURRENT player's dice while rolling
  final Map<int, int> faces = {}; // last rolled face of every player
  String status = '';
  String? banner;
  final Map<int, String> bubbles = {};
  Timer? faceTimer, bannerTimer;
  DateTime _lastImmersive = DateTime.fromMillisecondsSinceEpoch(0);

  GameConfig get cfg => widget.config;

  /// Normal mode: a player who got all tokens home is out. Team Up: everybody keeps playing.
  bool _finished(int color) => !cfg.teamUp && engine.ranking.contains(color);
  PlayerCfg playerOf(int color) => cfg.players.firstWhere((p) => p.color == color);
  bool isBot(int color) => playerOf(color).bot;

  // ---------------------------------------------------------------- full screen

  /// Hides status bar + navigation bar. Called again whenever Android brings the bars
  /// back (app resumed, dialog / bottom sheet closed, system bars swiped in).
  void _goImmersive() {
    _lastImmersive = DateTime.now();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _goImmersive();
  }

  @override
  void didChangeMetrics() {
    // System bars appeared/disappeared -> make sure we stay full screen (throttled, no loop).
    if (!mounted) return;
    if (DateTime.now().difference(_lastImmersive) > const Duration(milliseconds: 800)) {
      _goImmersive();
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _goImmersive();
    engine = LudoEngine(cfg.players.map((p) => p.color).toList(), teamUp: cfg.teamUp);
    disp = engine.pos.map((e) => List<int>.from(e)).toList();
    pulseCtl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
    diceCtl = AnimationController(vsync: this, duration: const Duration(milliseconds: 750));
    WidgetsBinding.instance.addPostFrameCallback((_) => _afterState());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    faceTimer?.cancel();
    bannerTimer?.cancel();
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
    setState(() {});
    if (isBot(engine.current)) _scheduleBot();
  }

  Future<void> _scheduleBot() async {
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted || over || busy) return;
    if (engine.phase == Phase.roll && isBot(engine.current)) _doRoll();
  }

  Future<void> _doRoll() async {
    if (busy || over || engine.phase != Phase.roll) return;
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
    final mc = engine.movingColor;
    status = isBot(who)
        ? '${playerOf(who).name} is thinking...'
        : mc != who
            ? "Move your partner's ${kColorNames[mc]} token"
            : 'Tap a token to move';
    setState(() {});

    if (isBot(who)) {
      await Future.delayed(const Duration(milliseconds: 750));
      if (!mounted || over || engine.phase != Phase.move) return;
      _doMove(chooseMove(engine));
    } else if (AppSettings.i.autoMove && movable.length == 1) {
      await Future.delayed(const Duration(milliseconds: 450));
      if (mounted && !over && !busy && engine.phase == Phase.move && movable.length == 1) _doMove(movable.first);
    }
  }

  Future<void> _doMove(int t) async {
    if (busy || over || engine.phase != Phase.move || !movable.contains(t)) return;
    busy = true;
    final who = engine.current; // player whose turn it is
    final c = engine.movingColor; // colour of the token being moved (partner's colour in Team Up)
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
      _flash('💥 ${playerOf(who).name} captured a token!');
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
      _flash(cfg.teamUp
          ? "🎉 ${playerOf(c).name}'s tokens are all home!"
          : '🎉 ${playerOf(c).name} finished ${ordinal(engine.ranking.length)}!');
      Sfx.i.play('win');
      await Future.delayed(const Duration(milliseconds: 900));
    }
    if (!mounted) return;
    busy = false;
    _afterState();
  }

  void _onTokenTap(int color, int t) {
    if (color != engine.movingColor || isBot(engine.current) || busy) return;
    _doMove(t);
  }

  /// Match finished -> straight to the podium. (No ad here: ads are only shown at app launch
  /// and when the player starts the NEXT game from the podium.)
  Future<void> _finish() async {
    if (over) return;
    over = true;
    setState(() => status = 'Game over!');
    await Future.delayed(const Duration(milliseconds: 1000));
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
    ).then((_) => _goImmersive());
  }

  Future<bool> _confirmQuit() async {
    final r = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF241B4B),
        title: const Text('Quit match?'),
        content: const Text('Your current game will be lost.'),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          FancyButton(
            color: const Color(0xFF2EBD59),
            radius: 14,
            glow: false,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            onTap: () => Navigator.pop(context, false),
            child: const Text('Keep playing', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
          ),
          FancyButton(
            color: const Color(0xFFE53935),
            radius: 14,
            glow: false,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
            onTap: () => Navigator.pop(context, true),
            child: const Text('Quit', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
          ),
        ],
      ),
    );
    _goImmersive();
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
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          child: Column(
            children: [
              _topBar(),
              if (cfg.teamUp) _teamBar(),
              _cardsRow([0, 1]),
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar() {
    Widget round(IconData icon, String tip, VoidCallback onTap) => Padding(
          padding: const EdgeInsets.only(left: 6),
          child: FancyButton(
            color: const Color(0xFF3B2F7A),
            radius: 18,
            glow: false,
            padding: const EdgeInsets.all(7),
            onTap: onTap,
            child: Icon(icon, size: 19, color: Colors.white),
          ),
        );
    return ListenableBuilder(
      listenable: AppSettings.i,
      builder: (_, __) => Padding(
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 4),
        child: Row(
          children: [
            round(Icons.arrow_back_ios_new_rounded, 'Back', () async {
              if (await _confirmQuit() && mounted) Navigator.of(context).pop();
            }),
            Expanded(
              child: Text(cfg.teamUp ? 'TEAM UP' : 'LUDO ROYALE', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 16)),
            ),
            round(AppSettings.i.sound ? Icons.volume_up_rounded : Icons.volume_off_rounded, 'Sound', () => AppSettings.i.setSound(!AppSettings.i.sound)),
            round(AppSettings.i.vibration ? Icons.vibration_rounded : Icons.mobile_off_rounded, 'Vibration', () => AppSettings.i.setVibration(!AppSettings.i.vibration)),
            round(Icons.settings_rounded, 'Settings', () => showSettingsDialog(context)),
          ],
        ),
      ),
    );
  }

  /// Team Up: live score of both teams (tokens home out of 8).
  Widget _teamBar() {
    Widget chip(int team) {
      final cols = cfg.players.map((p) => p.color).where((c) => LudoEngine.teamOf(c) == team).toList();
      final home = cols.fold<int>(0, (a, c) => a + disp[c].where((p) => p == kHomeProgress).length);
      final active = LudoEngine.teamOf(engine.current) == team && !over;
      return Expanded(
        child: Container(
          margin: EdgeInsets.fromLTRB(team == 0 ? 8 : 4, 2, team == 0 ? 4 : 8, 2),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: kTeamColors[team].withOpacity(active ? .35 : .15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: active ? Colors.white : kTeamColors[team].withOpacity(.6), width: active ? 1.6 : 1),
          ),
          child: Row(
            children: [
              Text(team == 0 ? 'A' : 'B', style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(width: 6),
              Expanded(child: Text(kTeamNames[team], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11))),
              Text('$home/8', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
            ],
          ),
        ),
      );
    }

    return Row(children: [chip(0), chip(1)]);
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
    final isCur = engine.current == color && !over && !_finished(color);
    final canRoll = isCur && !isBot(color) && engine.phase == Phase.roll && !busy;
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
    final active = engine.current == color && !over && !_finished(color);
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
                  Text(
                    cfg.teamUp
                        ? '${LudoEngine.teamOf(color) == 0 ? 'A' : 'B'} · 🏠 $home/4${home == 4 ? ' ✅' : ''}'
                        : (rank >= 0 ? '#${rank + 1}  🏠 $home/4' : '🏠 $home/4'),
                    style: TextStyle(fontSize: 11, color: rank >= 0 && !cfg.teamUp ? Colors.amber : Colors.white70),
                  ),
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
      final double sz = isBase ? 1.05 : n == 1 ? .8 : n == 2 ? .62 : n <= 4 ? .52 : .42;
      final double sp = n <= 2 ? .36 : .33;
      final cols = n <= 2 ? n : sqrt(n).ceil();
      final rows = (n / cols).ceil();
      for (int i = 0; i < n; i++) {
        final k = list[i];
        final dx = n == 1 ? 0.0 : ((i % cols) - (cols - 1) / 2) * sp;
        final dy = n == 1 ? 0.0 : ((i ~/ cols) - (rows - 1) / 2) * sp;
        final highlighted = curHuman && !busy && k.c == engine.movingColor && movable.contains(k.t);
        final dimmed = curHuman && !busy && movable.isNotEmpty && k.c == engine.movingColor && !movable.contains(k.t);
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
                child: TokenView(color: kPlayerColors[k.c], highlighted: highlighted, dimmed: dimmed, glow: pulseCtl.value),
              ),
            ),
          ),
        );
        (highlighted ? hi : normal).add(w);
      }
    });
    return [...normal, ...hi];
  }

  /// Bottom bar: status text + chat button.
  Widget _controls() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
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
    return FancyButton(
      color: const Color(0xFF5B3FD6),
      radius: 20,
      glow: false,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      onTap: enabled ? onTap : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
        ],
      ),
    );
  }
}
