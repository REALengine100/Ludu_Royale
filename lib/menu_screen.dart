import 'dart:math';
import 'package:flutter/material.dart';
import '../models.dart';
import '../services/ad_manager.dart';
import '../services/app_settings.dart';
import '../widgets/dialogs.dart';
import 'game_screen.dart';

enum GameMode { passPlay, vsComputer, teamUp }

/// Master switch for the app-launch / next-game ads. Keep false while ads are off;
/// set to true later (and set up real AdMob IDs) to turn them on.
const bool kAdsEnabled = false;

// =====================================================================================
//  FancyButton - glossy, 3D "press-down" button used everywhere in the app
// =====================================================================================
class FancyButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap; // null = disabled
  final Color color;
  final double radius;
  final EdgeInsetsGeometry padding;
  final bool glow;
  const FancyButton({
    super.key,
    required this.child,
    required this.onTap,
    this.color = const Color(0xFF7C4DFF),
    this.radius = 18,
    this.padding = const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
    this.glow = true,
  });

  @override
  State<FancyButton> createState() => _FancyButtonState();
}

class _FancyButtonState extends State<FancyButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.color;
    final enabled = widget.onTap != null;
    return Opacity(
      opacity: enabled ? 1 : .45,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapUp: enabled ? (_) => setState(() => _down = false) : null,
        onTapCancel: enabled ? () => setState(() => _down = false) : null,
        onTap: enabled
            ? () {
                Haptics.light();
                widget.onTap!();
              }
            : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          transform: Matrix4.translationValues(0, _down ? 4 : 0, 0),
          padding: widget.padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [lighten(c, .1), c, darken(c, .05)],
            ),
            border: Border.all(color: Colors.white.withOpacity(.28), width: 1.2),
            boxShadow: [
              BoxShadow(color: darken(c, .3), offset: Offset(0, _down ? 1 : 5)),
              if (widget.glow) BoxShadow(color: c.withOpacity(.4), blurRadius: 16, offset: const Offset(0, 8)),
            ],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

// =====================================================================================
//  Home screen
// =====================================================================================
class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});
  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> with TickerProviderStateMixin {
  static bool _launchAdDone = false; // the app-launch ad is shown once per app start

  late final AnimationController _enter =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..forward();
  late final AnimationController _float =
      AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showLaunchAd());
  }

  @override
  void dispose() {
    _enter.dispose();
    _float.dispose();
    super.dispose();
  }

  /// Interstitial when the app opens. Ads may still be loading right after launch, so retry a few times.
  Future<void> _showLaunchAd() async {
    if (!kAdsEnabled || _launchAdDone) return;
    _launchAdDone = true;
    for (int i = 0; i < 8; i++) {
      if (!mounted) return;
      if (!(ModalRoute.of(context)?.isCurrent ?? true)) return; // user already started a game
      final sw = Stopwatch()..start();
      await AdManager.showInterstitial();
      if (sw.elapsedMilliseconds > 400) return; // an ad was shown and closed
      await Future.delayed(const Duration(milliseconds: 700)); // not loaded yet -> try again
    }
  }

  void _openSetup(GameMode mode) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SetupSheet(mode: mode),
    );
  }

  Widget _reveal(int i, Widget child) {
    final start = (i * .12).clamp(0.0, .6);
    final a = CurvedAnimation(parent: _enter, curve: Interval(start, start + .4, curve: Curves.easeOutCubic));
    return FadeTransition(
      opacity: a,
      child: SlideTransition(position: Tween<Offset>(begin: const Offset(0, .25), end: Offset.zero).animate(a), child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          _background(),
          SafeArea(
            child: Column(
              children: [
                _header(),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _reveal(0, _logo()),
                          const SizedBox(height: 30),
                          _reveal(
                            1,
                            _modeButton(
                              icon: Icons.diversity_3_rounded,
                              title: 'Team Up',
                              sub: '2 vs 2 - play with your partner',
                              color: const Color(0xFFFF7A18),
                              badge: 'NEW',
                              onTap: () => _openSetup(GameMode.teamUp),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _reveal(
                            2,
                            _modeButton(
                              icon: Icons.smart_toy_rounded,
                              title: 'vs Computer',
                              sub: 'Challenge smart bots',
                              color: const Color(0xFF1E88E5),
                              onTap: () => _openSetup(GameMode.vsComputer),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _reveal(
                            3,
                            _modeButton(
                              icon: Icons.groups_rounded,
                              title: 'Pass & Play',
                              sub: '2-4 players on one device',
                              color: const Color(0xFF2EA84F),
                              onTap: () => _openSetup(GameMode.passPlay),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                _reveal(4, _footer()),
                const SizedBox(height: 14),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ pieces

  Widget _background() {
    return AnimatedBuilder(
      animation: _float,
      builder: (_, __) {
        final t = _float.value * 2 * pi;
        Widget blob(Alignment a, Color c, double phase) => Align(
              alignment: a,
              child: Transform.translate(
                offset: Offset(sin(t + phase) * 14, cos(t + phase) * 14),
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [c.withOpacity(.38), c.withOpacity(0)]),
                  ),
                ),
              ),
            );
        Widget dice(double x, double y, double size, double phase) => Align(
              alignment: Alignment(x, y + sin(t + phase) * .03),
              child: Transform.rotate(
                angle: sin(t + phase) * .6 + phase,
                child: Icon(Icons.casino_rounded, size: size, color: Colors.white.withOpacity(.07)),
              ),
            );
        return Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF1D1058), Color(0xFF0A0620)]),
              ),
            ),
            blob(const Alignment(-1.2, -1.05), kPlayerColors[0], 0),
            blob(const Alignment(1.2, -.7), kPlayerColors[1], 1.5),
            blob(const Alignment(1.2, 1.05), kPlayerColors[2], 3),
            blob(const Alignment(-1.2, .8), kPlayerColors[3], 4.5),
            dice(-.8, -.55, 54, 0),
            dice(.85, -.25, 40, 1.2),
            dice(-.7, .35, 46, 2.4),
            dice(.75, .6, 58, 3.6),
            dice(0, .9, 36, 4.8),
          ],
        );
      },
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: ListenableBuilder(
        listenable: AppSettings.i,
        builder: (_, __) => Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _roundIcon(AppSettings.i.sound ? Icons.volume_up_rounded : Icons.volume_off_rounded, () => AppSettings.i.setSound(!AppSettings.i.sound)),
            const SizedBox(width: 10),
            _roundIcon(Icons.settings_rounded, () => showSettingsDialog(context)),
          ],
        ),
      ),
    );
  }

  Widget _roundIcon(IconData icon, VoidCallback onTap) {
    return FancyButton(
      color: const Color(0xFF3B2F7A),
      radius: 22,
      glow: false,
      padding: const EdgeInsets.all(10),
      onTap: onTap,
      child: Icon(icon, size: 22, color: Colors.white),
    );
  }

  Widget _logo() {
    return Column(
      children: [
        Transform.rotate(
          angle: -.1,
          child: SizedBox(
            width: 104,
            height: 104,
            child: GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (final c in kPlayerColors)
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [lighten(c, .12), darken(c, .08)]),
                      border: Border.all(color: Colors.white.withOpacity(.35), width: 1.5),
                      boxShadow: [BoxShadow(color: c.withOpacity(.55), blurRadius: 16)],
                    ),
                    child: Center(
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(.9), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)]),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        ShaderMask(
          shaderCallback: (r) => const LinearGradient(colors: [Colors.white, Color(0xFFFFE082)]).createShader(r),
          child: const Text('LUDO ROYALE', style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: 3, color: Colors.white)),
        ),
        const SizedBox(height: 4),
        const Text('ROLL  •  RACE  •  REIGN', style: TextStyle(color: Colors.white54, letterSpacing: 4, fontSize: 11, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _modeButton({
    required IconData icon,
    required String title,
    required String sub,
    required Color color,
    required VoidCallback onTap,
    String? badge,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        FancyButton(
          color: color,
          radius: 24,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          onTap: onTap,
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(color: Colors.white.withOpacity(.2), borderRadius: BorderRadius.circular(15)),
                child: Icon(icon, size: 29, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: Colors.white, shadows: [Shadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 2))])),
                    const SizedBox(height: 2),
                    Text(sub, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 18),
            ],
          ),
        ),
        if (badge != null)
          Positioned(
            right: 22,
            top: -9,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(color: const Color(0xFFFFEB3B), borderRadius: BorderRadius.circular(10), boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 4)]),
              child: Text(badge, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1)),
            ),
          ),
      ],
    );
  }

  Widget _footer() {
    Widget pill(IconData icon, String label, VoidCallback onTap) => FancyButton(
          color: const Color(0xFF3B2F7A),
          radius: 18,
          glow: false,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
          onTap: onTap,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 19, color: Colors.white),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ]),
        );
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        pill(Icons.menu_book_rounded, 'Rules', () => showRulesDialog(context)),
        const SizedBox(width: 14),
        pill(Icons.settings_rounded, 'Settings', () => showSettingsDialog(context)),
      ],
    );
  }
}

// =====================================================================================
//  Game setup bottom sheet
// =====================================================================================
class SetupSheet extends StatefulWidget {
  final GameMode mode;
  const SetupSheet({super.key, required this.mode});
  @override
  State<SetupSheet> createState() => _SetupSheetState();
}

class _SetupSheetState extends State<SetupSheet> {
  int count = 2; // Pass & Play / vs Computer
  bool teamBots = false; // Team Up: false = 4 humans, true = you + 3 bots
  late final List<TextEditingController> ctrls =
      List.generate(4, (i) => TextEditingController(text: AppSettings.i.names[i]));

  static const _layout = {
    2: [0, 2],
    3: [0, 1, 2],
    4: [0, 1, 2, 3],
  };

  bool get isTeam => widget.mode == GameMode.teamUp;
  bool get vsBots => widget.mode == GameMode.vsComputer || (isTeam && teamBots);
  List<int> get colors => isTeam ? const [0, 1, 2, 3] : _layout[count]!;

  String _botName(int pos) => isTeam ? (pos == 2 ? 'Partner' : 'Computer ${pos == 1 ? 1 : 2}') : 'Computer $pos';

  @override
  void dispose() {
    for (final c in ctrls) {
      c.dispose();
    }
    super.dispose();
  }

  void _start() {
    final cols = colors;
    final names = [for (int i = 0; i < 4; i++) ctrls[i].text.trim().isEmpty ? 'Player ${i + 1}' : ctrls[i].text.trim()];
    AppSettings.i.setNames(names);
    final players = <PlayerCfg>[
      for (int i = 0; i < cols.length; i++)
        (vsBots && i > 0) ? PlayerCfg(cols[i], _botName(i), true) : PlayerCfg(cols[i], names[i], false),
    ];
    final cfg = GameConfig(players, vsBots, teamUp: isTeam);
    Navigator.pop(context);
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => GameScreen(config: cfg)));
  }

  Widget _row(int pos) {
    final color = colors[pos];
    final col = kPlayerColors[color];
    final bot = vsBots && pos > 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1440),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: col.withOpacity(.7), width: 1.5),
      ),
      child: Row(
        children: [
          CircleAvatar(radius: 17, backgroundColor: col, child: Icon(bot ? Icons.smart_toy_rounded : Icons.person_rounded, size: 19, color: Colors.white)),
          const SizedBox(width: 10),
          Expanded(
            child: bot
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Text(_botName(pos), style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                  )
                : TextField(
                    controller: ctrls[pos],
                    maxLength: 12,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(border: InputBorder.none, counterText: '', hintText: '${kColorNames[color]} player', hintStyle: const TextStyle(color: Colors.white38)),
                  ),
          ),
          Text(kColorNames[color], style: TextStyle(color: col, fontWeight: FontWeight.w800, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _teamHeader(int team) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: kTeamColors[team], borderRadius: BorderRadius.circular(10)),
            child: Text('TEAM ${team == 0 ? 'A' : 'B'}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1, color: Colors.white)),
          ),
          const SizedBox(width: 10),
          Text(kTeamNames[team], style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = isTeam ? 'Team Up' : widget.mode == GameMode.vsComputer ? 'vs Computer' : 'Pass & Play';
    final accent = isTeam ? const Color(0xFFFF7A18) : widget.mode == GameMode.vsComputer ? const Color(0xFF1E88E5) : const Color(0xFF2EA84F);
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF2A1D6B), Color(0xFF150E3A)]),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: Colors.white24, width: 1.2)),
      ),
      padding: EdgeInsets.only(left: 20, right: 20, top: 12, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 44, height: 5, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(3)))),
              const SizedBox(height: 14),
              Text(title, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: accent, letterSpacing: 1)),
              const SizedBox(height: 14),
              if (isTeam) ...[
                _SegBar(labels: const ['With Friends', 'vs Computer'], index: teamBots ? 1 : 0, color: accent, onChanged: (i) => setState(() => teamBots = i == 1)),
                const SizedBox(height: 10),
                const Text(
                  "Partners sit opposite. Bring all 4 of your tokens home, then move your partner's tokens. The first team to get all 8 tokens home wins.",
                  style: TextStyle(color: Colors.white60, fontSize: 12.5, height: 1.35),
                ),
                const SizedBox(height: 8),
                for (final team in [0, 1]) ...[
                  _teamHeader(team),
                  for (int pos = 0; pos < 4; pos++)
                    if (colors[pos] % 2 == team) _row(pos),
                ],
              ] else ...[
                _SegBar(labels: const ['2 Players', '3 Players', '4 Players'], index: count - 2, color: accent, onChanged: (i) => setState(() => count = i + 2)),
                const SizedBox(height: 14),
                for (int pos = 0; pos < colors.length; pos++) _row(pos),
              ],
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FancyButton(
                  color: const Color(0xFF2EBD59),
                  radius: 20,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  onTap: _start,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
                      SizedBox(width: 6),
                      Text('START GAME', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17, letterSpacing: 1.5, shadows: [Shadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 2))])),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SegBar extends StatelessWidget {
  final List<String> labels;
  final int index;
  final Color color;
  final ValueChanged<int> onChanged;
  const _SegBar({required this.labels, required this.index, required this.color, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: const Color(0xFF1B1440), borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          for (int i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  Haptics.light();
                  onChanged(i);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == index ? color : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: i == index ? [BoxShadow(color: color.withOpacity(.5), blurRadius: 10)] : [],
                  ),
                  child: Text(labels[i], style: TextStyle(fontWeight: FontWeight.w800, color: i == index ? Colors.white : Colors.white54)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
