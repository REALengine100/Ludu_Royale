import 'package:flutter/material.dart';
import '../models.dart';
import '../services/ad_manager.dart';
import '../services/app_settings.dart';
import '../widgets/dialogs.dart';
import 'game_screen.dart';

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  void _setup(BuildContext context, bool vsComputer) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF241B4B),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SetupSheet(vsComputer: vsComputer),
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
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          for (final c in kPlayerColors)
                            Container(margin: const EdgeInsets.all(4), width: 22, height: 22, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
                        ]),
                        const SizedBox(height: 12),
                        const Text('LUDO ROYALE',
                            style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: 3, color: Colors.white)),
                        const SizedBox(height: 36),
                        _ModeButton(icon: Icons.groups_rounded, title: 'Pass & Play', subtitle: '2-4 players on one device', color: kPlayerColors[1], onTap: () => _setup(context, false)),
                        const SizedBox(height: 16),
                        _ModeButton(icon: Icons.smart_toy_rounded, title: 'vs Computer', subtitle: 'Challenge smart bots', color: kPlayerColors[0], onTap: () => _setup(context, true)),
                        const SizedBox(height: 28),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TextButton.icon(onPressed: () => showRulesDialog(context), icon: const Icon(Icons.menu_book_rounded), label: const Text('Rules')),
                            const SizedBox(width: 16),
                            TextButton.icon(onPressed: () => showSettingsDialog(context), icon: const Icon(Icons.settings_rounded), label: const Text('Settings')),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const BannerAdWidget(),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final Color color;
  final VoidCallback onTap;
  const _ModeButton({required this.icon, required this.title, required this.subtitle, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(colors: [color, darken(color, .15)]),
            boxShadow: [BoxShadow(color: color.withOpacity(.4), blurRadius: 14, offset: const Offset(0, 6))],
          ),
          child: Row(children: [
            Icon(icon, size: 36, color: Colors.white),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
                Text(subtitle, style: const TextStyle(color: Colors.white70)),
              ]),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white),
          ]),
        ),
      ),
    );
  }
}

class SetupSheet extends StatefulWidget {
  final bool vsComputer;
  const SetupSheet({super.key, required this.vsComputer});
  @override
  State<SetupSheet> createState() => _SetupSheetState();
}

class _SetupSheetState extends State<SetupSheet> {
  int count = 2;
  late final List<TextEditingController> ctrls =
      List.generate(4, (i) => TextEditingController(text: AppSettings.i.names[i]));

  static const _layout = {
    2: [0, 2],
    3: [0, 1, 2],
    4: [0, 1, 2, 3],
  };

  @override
  void dispose() {
    for (final c in ctrls) {
      c.dispose();
    }
    super.dispose();
  }

  void _start() {
    final colors = _layout[count]!;
    final names = [for (int i = 0; i < 4; i++) ctrls[i].text.trim().isEmpty ? 'Player ${i + 1}' : ctrls[i].text.trim()];
    AppSettings.i.setNames(names);
    final players = <PlayerCfg>[];
    for (int i = 0; i < colors.length; i++) {
      if (widget.vsComputer) {
        players.add(i == 0 ? PlayerCfg(colors[i], names[0], false) : PlayerCfg(colors[i], 'Computer $i', true));
      } else {
        players.add(PlayerCfg(colors[i], names[i], false));
      }
    }
    final cfg = GameConfig(players, widget.vsComputer);
    Navigator.pop(context);
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => GameScreen(config: cfg)));
  }

  @override
  Widget build(BuildContext context) {
    final colors = _layout[count]!;
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.vsComputer ? 'vs Computer' : 'Pass & Play', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 14),
            const Text('Players'),
            const SizedBox(height: 6),
            Wrap(spacing: 10, children: [
              for (final n in [2, 3, 4])
                ChoiceChip(label: Text('$n'), selected: count == n, onSelected: (_) => setState(() => count = n)),
            ]),
            const SizedBox(height: 14),
            for (int i = 0; i < colors.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TextField(
                  controller: widget.vsComputer && i > 0 ? TextEditingController(text: 'Computer $i') : ctrls[i],
                  enabled: !(widget.vsComputer && i > 0),
                  maxLength: 12,
                  decoration: InputDecoration(
                    counterText: '',
                    filled: true,
                    prefixIcon: Icon(widget.vsComputer && i > 0 ? Icons.smart_toy_rounded : Icons.person_rounded, color: kPlayerColors[colors[i]]),
                    labelText: '${kColorNames[colors[i]]} player',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(onPressed: _start, icon: const Icon(Icons.play_arrow_rounded), label: const Text('START GAME', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1))),
            ),
          ],
        ),
      ),
    );
  }
}
