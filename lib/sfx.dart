import 'dart:math';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'app_settings.dart';

const int _sr = 22050;

/// Tiny procedural synth: builds 16-bit mono WAV files in memory, so no audio assets are needed.
class _Wave {
  final List<double> s = [];
  double _ph = 0;
  final Random _r = Random();

  void tone(double f, double d, {double vol = .5, double? f2, bool square = false, double decay = 4}) {
    final n = (d * _sr).toInt();
    for (int i = 0; i < n; i++) {
      final fr = f + ((f2 ?? f) - f) * (i / n);
      _ph += 2 * pi * fr / _sr;
      double v = sin(_ph);
      if (square) v = v > 0 ? .6 : -.6;
      final env = exp(-decay * i / n) * min(1.0, i / 90);
      s.add(v * env * vol);
    }
  }

  void noise(double d, {double vol = .4}) {
    final n = (d * _sr).toInt();
    for (int i = 0; i < n; i++) {
      s.add((_r.nextDouble() * 2 - 1) * exp(-5 * i / n) * vol);
    }
  }

  void silence(double d) {
    final n = (d * _sr).toInt();
    for (int i = 0; i < n; i++) {
      s.add(0);
    }
  }

  Uint8List wav() {
    final n = s.length;
    final b = ByteData(44 + n * 2);
    void str(int o, String t) {
      for (int i = 0; i < t.length; i++) {
        b.setUint8(o + i, t.codeUnitAt(i));
      }
    }

    str(0, 'RIFF');
    b.setUint32(4, 36 + n * 2, Endian.little);
    str(8, 'WAVE');
    str(12, 'fmt ');
    b.setUint32(16, 16, Endian.little);
    b.setUint16(20, 1, Endian.little);
    b.setUint16(22, 1, Endian.little);
    b.setUint32(24, _sr, Endian.little);
    b.setUint32(28, _sr * 2, Endian.little);
    b.setUint16(32, 2, Endian.little);
    b.setUint16(34, 16, Endian.little);
    str(36, 'data');
    b.setUint32(40, n * 2, Endian.little);
    for (int i = 0; i < n; i++) {
      b.setInt16(44 + i * 2, (s[i].clamp(-1.0, 1.0) * 32767).toInt(), Endian.little);
    }
    return b.buffer.asUint8List();
  }
}

class Sfx {
  static final Sfx i = Sfx._();
  Sfx._();

  final Map<String, Uint8List> _bank = {};
  final List<AudioPlayer> _pool = [];
  int _n = 0;
  bool _ready = false;

  void init() {
    try {
      AudioPlayer.global.setAudioContext(AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers).build());
    } catch (_) {}

    // Dice rattle: a burst of clicks + low thud
    final dice = _Wave();
    for (int k = 0; k < 7; k++) {
      dice.noise(.028, vol: .55);
      dice.tone(180 + k * 25, .03, vol: .25);
      dice.silence(.04);
    }
    dice.tone(120, .1, vol: .5, f2: 70);
    _bank['dice'] = dice.wav();

    final step = _Wave()..tone(540, .07, vol: .45, f2: 620, decay: 5);
    _bank['step'] = step.wav();

    final cap = _Wave()
      ..tone(760, .32, vol: .5, f2: 140, square: true, decay: 2.5)
      ..tone(110, .15, vol: .5, decay: 5);
    _bank['capture'] = cap.wav();

    final safe = _Wave()
      ..tone(880, .13, vol: .45, decay: 3)
      ..tone(1320, .22, vol: .45, decay: 3);
    _bank['safe'] = safe.wav();

    final win = _Wave();
    for (final f in [523.25, 659.25, 783.99, 1046.5]) {
      win.tone(f, .16, vol: .5, decay: 2);
    }
    win.tone(783.99, .12, vol: .45, decay: 2);
    win.tone(1046.5, .6, vol: .55, decay: 2.2);
    _bank['win'] = win.wav();

    final pop = _Wave()..tone(660, .09, vol: .4, f2: 990, decay: 4);
    _bank['pop'] = pop.wav();

    _pool.addAll(List.generate(5, (_) => AudioPlayer()));
    _ready = true;
  }

  Future<void> play(String key) async {
    if (!AppSettings.i.sound || !_ready) return;
    final bytes = _bank[key];
    if (bytes == null) return;
    final p = _pool[_n++ % _pool.length];
    try {
      await p.stop();
      await p.play(BytesSource(bytes));
    } catch (_) {}
  }
}
