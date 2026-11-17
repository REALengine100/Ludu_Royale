import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Achievement {
  final String id, title, desc, stat, icon;
  final int goal, reward;
  const Achievement(this.id, this.title, this.desc, this.stat, this.goal, this.reward, this.icon);
}

const List<Achievement> kAchievements = [
  Achievement('first_win', 'First Victory', 'Win your first game', 'wins', 1, 30, '🏆'),
  Achievement('wins_10', 'Champion', 'Win 10 games', 'wins', 10, 100, '👑'),
  Achievement('wins_50', 'Legend', 'Win 50 games', 'wins', 50, 400, '🌟'),
  Achievement('games_25', 'Regular', 'Play 25 games', 'games', 25, 80, '🎲'),
  Achievement('games_100', 'Veteran', 'Play 100 games', 'games', 100, 250, '🎖️'),
  Achievement('cap_10', 'Hunter', 'Capture 10 tokens', 'captures', 10, 40, '💥'),
  Achievement('cap_50', 'Destroyer', 'Capture 50 tokens', 'captures', 50, 150, '⚔️'),
  Achievement('cap_200', 'Unstoppable', 'Capture 200 tokens', 'captures', 200, 500, '🔥'),
  Achievement('home_20', 'Homecoming', 'Bring 20 tokens home', 'home', 20, 50, '🏠'),
  Achievement('home_100', 'Home Master', 'Bring 100 tokens home', 'home', 100, 200, '🏰'),
  Achievement('six_25', 'Lucky Six', 'Roll 25 sixes', 'sixes', 25, 40, '🍀'),
  Achievement('six_100', 'Six Machine', 'Roll 100 sixes', 'sixes', 100, 150, '🎯'),
];

/// Coins, stats, achievements, daily reward and shop ownership. Saved on the device.
class Progress extends ChangeNotifier {
  static final Progress i = Progress._();
  Progress._();

  SharedPreferences? _p;
  int coins = 0;
  final Map<String, int> stats = {};
  final Set<String> done = {};
  final Set<String> owned = {'board:classic', 'dice:classic', 'pawn:classic'};
  String board = 'classic', dice = 'classic', pawn = 'classic';
  String lastDaily = '';
  int streak = 0;

  // last finished game (shown on the podium)
  int sessionCoins = 0;
  int lastGameCoins = 0;
  List<Achievement> lastGameAch = [];

  Future<void> load() async {
    try {
      _p = await SharedPreferences.getInstance();
      coins = _p!.getInt('coins') ?? 0;
      final s = _p!.getString('stats');
      if (s != null) {
        final m = jsonDecode(s) as Map<String, dynamic>;
        m.forEach((k, v) => stats[k] = (v as num).toInt());
      }
      done.addAll(_p!.getStringList('ach') ?? []);
      owned.addAll(_p!.getStringList('owned') ?? []);
      board = _p!.getString('sel_board') ?? 'classic';
      dice = _p!.getString('sel_dice') ?? 'classic';
      pawn = _p!.getString('sel_pawn') ?? 'classic';
      lastDaily = _p!.getString('daily') ?? '';
      streak = _p!.getInt('streak') ?? 0;
    } catch (_) {}
  }

  void _save() {
    final p = _p;
    if (p == null) return;
    p.setInt('coins', coins);
    p.setString('stats', jsonEncode(stats));
    p.setStringList('ach', done.toList());
    p.setStringList('owned', owned.toList());
    p.setString('sel_board', board);
    p.setString('sel_dice', dice);
    p.setString('sel_pawn', pawn);
    p.setString('daily', lastDaily);
    p.setInt('streak', streak);
  }

  int stat(String k) => stats[k] ?? 0;

  /// Adds to a stat and returns achievements that just unlocked (their coin reward is already added).
  List<Achievement> addStat(String k, [int n = 1]) {
    stats[k] = stat(k) + n;
    final out = <Achievement>[];
    for (final a in kAchievements) {
      if (!done.contains(a.id) && a.stat == k && stat(k) >= a.goal) {
        done.add(a.id);
        coins += a.reward;
        sessionCoins += a.reward;
        out.add(a);
      }
    }
    _save();
    notifyListeners();
    return out;
  }

  void startGame() => sessionCoins = 0;

  List<Achievement> onCapture(int n) {
    coins += 2 * n;
    sessionCoins += 2 * n;
    return addStat('captures', n);
  }

  List<Achievement> onHome() {
    coins += 5;
    sessionCoins += 5;
    return addStat('home');
  }

  List<Achievement> onSix() => addStat('sixes');

  /// Called once when a match ends.
  void endGame({required bool won}) {
    final base = 10 + (won ? 50 : 0);
    coins += base;
    sessionCoins += base;
    final ach = <Achievement>[...addStat('games'), if (won) ...addStat('wins')];
    lastGameAch = ach;
    lastGameCoins = sessionCoins;
    _save();
    notifyListeners();
  }

  // ---------------------------------------------------------------- daily reward
  static String _key(DateTime d) => '${d.year}-${d.month}-${d.day}';
  bool get dailyAvailable => lastDaily != _key(DateTime.now());
  int get nextStreak {
    final y = DateTime.now().subtract(const Duration(days: 1));
    return lastDaily == _key(y) ? streak + 1 : 1;
  }

  static int dailyReward(int day) => 20 + 10 * ((day - 1) % 7);

  int claimDaily() {
    if (!dailyAvailable) return 0;
    streak = nextStreak;
    lastDaily = _key(DateTime.now());
    final r = dailyReward(streak);
    coins += r;
    _save();
    notifyListeners();
    return r;
  }

  // ---------------------------------------------------------------- shop
  bool has(String id) => owned.contains(id);

  bool isEquipped(String kind, String id) =>
      (kind == 'board' && board == id) || (kind == 'dice' && dice == id) || (kind == 'pawn' && pawn == id);

  void equip(String kind, String id) {
    if (kind == 'board') board = id;
    if (kind == 'dice') dice = id;
    if (kind == 'pawn') pawn = id;
    _save();
    notifyListeners();
  }

  /// Buys (if needed) and equips. Returns false if there are not enough coins.
  bool buyAndEquip(String kind, String id, int price) {
    final key = '$kind:$id';
    if (!owned.contains(key)) {
      if (coins < price) return false;
      coins -= price;
      owned.add(key);
    }
    equip(kind, id);
    return true;
  }
}
