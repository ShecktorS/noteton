import 'dart:async';

import 'package:flutter/services.dart';

/// Manages metronome state: BPM, running/stopped, tap-tempo.
/// Notifies listeners on each beat and on state changes.
class MetronomeController {
  int bpm;
  bool _running = false;
  Timer? _timer;

  /// Called on every beat (for UI pulse).
  VoidCallback? onBeat;

  /// Called when running/bpm state changes.
  VoidCallback? onStateChanged;

  MetronomeController({this.bpm = 80});

  bool get isRunning => _running;

  void start() {
    if (_running) return;
    _running = true;
    _scheduleTick();
    onStateChanged?.call();
  }

  void stop() {
    _running = false;
    _timer?.cancel();
    _timer = null;
    onStateChanged?.call();
  }

  void toggle() => _running ? stop() : start();

  void setBpm(int newBpm) {
    bpm = newBpm.clamp(20, 300);
    if (_running) {
      _timer?.cancel();
      _scheduleTick();
    }
    onStateChanged?.call();
  }

  void adjustBpm(int delta) => setBpm(bpm + delta);

  // ── Tap tempo ──────────────────────────────────────────────────────────────

  final List<int> _tapTimes = [];

  void tapTempo() {
    final now = DateTime.now().millisecondsSinceEpoch;
    _tapTimes.add(now);

    // Keep only the last 8 taps within a 4-second window
    _tapTimes.removeWhere((t) => now - t > 4000);
    if (_tapTimes.length > 8) _tapTimes.removeAt(0);

    if (_tapTimes.length >= 2) {
      final intervals = <int>[];
      for (int i = 1; i < _tapTimes.length; i++) {
        intervals.add(_tapTimes[i] - _tapTimes[i - 1]);
      }
      final avgMs = intervals.reduce((a, b) => a + b) / intervals.length;
      setBpm((60000 / avgMs).round());
    }
  }

  // ── Internal ───────────────────────────────────────────────────────────────

  void _scheduleTick() {
    final interval = Duration(milliseconds: (60000 / bpm).round());
    _tick(); // fire immediately on start
    _timer = Timer.periodic(interval, (_) => _tick());
  }

  void _tick() {
    HapticFeedback.lightImpact();
    onBeat?.call();
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}
