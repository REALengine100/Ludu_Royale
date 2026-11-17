import 'package:flutter/material.dart';
import 'board_painter.dart';
import 'dice_view.dart';
import 'models.dart';
import 'progress.dart';
import 'rewards_ui.dart';
import 'sfx.dart';
import 'themes.dart';

class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFF14102B),
        appBar: AppBar(
          backgroundColor: const Color(0xFF241B4B),
          title: const Text('Shop', style: TextStyle(fontWeight: FontWeight.w900)),
          actions: const [CoinChip(), SizedBox(width: 12)],
          bottom: const TabBar(
            indicatorColor: Color(0xFFFFC107),
            tabs: [Tab(text: 'Boards'), Tab(text: 'Dice'), Tab(text: 'Tokens')],
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListenableBuilder(
                  listenable: Progress.i,
                  builder: (_, __) => TabBarView(
                    children: [
                      _grid([
                        for (final t in kBoardThemes) _card('board', t.id, t.name, t.price, _boardPreview(t)),
                      ]),
                      _grid([
                        for (final t in kDiceThemes) _card('dice', t.id, t.name, t.price, _dicePreview(t)),
                      ]),
                      _grid([
                        for (final s in kPawnStyles) _card('pawn', s.id, s.name, s.price, _pawnPreview(s.id)),
                      ]),
                    ],
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 6, 16, 10),
                child: Text(
                  'Earn coins: win +50 · finish a game +10 · capture +2 · token home +5 · daily reward · achievements',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _grid(List<Widget> items) => GridView.count(
        crossAxisCount: 2,
        padding: const EdgeInsets.all(12),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: .82,
        children: items,
      );

  Widget _boardPreview(BoardTheme t) => SizedBox(
        width: 104,
        height: 104,
        child: CustomPaint(painter: BoardPainter(t)),
      );

  Widget _dicePreview(DiceTheme t) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          DiceView(value: 5, accent: kPlayerColors[0], size: 54, theme: t),
          const SizedBox(width: 10),
          DiceView(value: 1, accent: kPlayerColors[3], size: 54, theme: t),
        ],
      );

  Widget _pawnPreview(String style) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final c in [0, 1, 2, 3])
            SizedBox(width: 34, height: 44, child: TokenView(color: kPlayerColors[c], style: style)),
        ],
      );

  Widget _card(String kind, String id, String name, int price, Widget preview) {
    return Builder(builder: (context) {
      final p = Progress.i;
      final owned = p.has('$kind:$id');
      final on = p.isEquipped(kind, id);
      final afford = p.coins >= price;
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF241B4B),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: on ? const Color(0xFF2EBD59) : Colors.white12, width: on ? 2.5 : 1),
        ),
        child: Column(
          children: [
            Expanded(child: Center(child: FittedBox(child: preview))),
            const SizedBox(height: 6),
            Text(name, style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: on
                      ? const Color(0xFF2EBD59)
                      : owned
                          ? const Color(0xFF5B3FD6)
                          : afford
                              ? const Color(0xFFFFA000)
                              : Colors.grey.shade700,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onPressed: on
                    ? null
                    : () {
                        final ok = p.buyAndEquip(kind, id, price);
                        if (ok) {
                          if (!owned) Sfx.i.play('coin');
                        } else {
                          ScaffoldMessenger.of(context)
                            ..clearSnackBars()
                            ..showSnackBar(const SnackBar(content: Text('Not enough coins - play more games!')));
                        }
                      },
                child: Text(
                  on
                      ? 'Equipped'
                      : owned
                          ? 'Equip'
                          : '🪙 $price',
                  style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}
