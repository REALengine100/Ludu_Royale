import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings extends ChangeNotifier {
  static final AppSettings i = AppSettings._();
  AppSettings._();

  bool sound = true;
  bool vibration = true;
  bool autoMove = true; // auto-move when only one valid move exists
  List<String> names = ['Player 1', 'Player 2', 'Player 3', 'Player 4'];
  SharedPreferences? _p;

  Future<void> load() async {
    try {
      _p = await SharedPreferences.getInstance();
      sound = _p!.getBool('sound') ?? true;
      vibration = _p!.getBool('vibration') ?? true;
      autoMove = _p!.getBool('autoMove') ?? true;
      final n = _p!.getStringList('names');
      if (n != null && n.length == 4) names = n;
    } catch (_) {}
  }

  void setSound(bool v) {
    sound = v;
    _p?.setBool('sound', v);
    notifyListeners();
  }

  void setVibration(bool v) {
    vibration = v;
    _p?.setBool('vibration', v);
    notifyListeners();
  }

  void setAutoMove(bool v) {
    autoMove = v;
    _p?.setBool('autoMove', v);
    notifyListeners();
  }

  void setNames(List<String> n) {
    names = n;
    _p?.setStringList('names', n);
  }
}

class Haptics {
  static void light() {
    if (AppSettings.i.vibration) HapticFeedback.lightImpact();
  }

  static void medium() {
    if (AppSettings.i.vibration) HapticFeedback.mediumImpact();
  }

  static void heavy() {
    if (AppSettings.i.vibration) HapticFeedback.heavyImpact();
  }
}
