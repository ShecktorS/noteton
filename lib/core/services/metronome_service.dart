import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Stili di click disponibili per il metronomo.
enum MetronomeSound {
  classic('Click classico', 'classic'),
  woodblock('Woodblock', 'woodblock'),
  legno('Legno', 'legno');

  final String label;
  final String assetPrefix;
  const MetronomeSound(this.label, this.assetPrefix);
}

/// Time signatures supportate. Il numeratore determina i beat per battuta;
/// il denominatore non incide sull'audio (8 = un sottomultiplo, ma trattato
/// uguale a 4 per semplicità: l'utente regola il BPM se vuole sottosuddividere).
class TimeSignature {
  final int beats; // numeratore
  final int unit; // denominatore (4 o 8)
  const TimeSignature(this.beats, this.unit);

  String get label => '$beats/$unit';

  static const List<TimeSignature> presets = [
    TimeSignature(2, 4),
    TimeSignature(3, 4),
    TimeSignature(4, 4),
    TimeSignature(6, 8),
    TimeSignature(12, 8),
  ];

  @override
  bool operator ==(Object other) =>
      other is TimeSignature && beats == other.beats && unit == other.unit;

  @override
  int get hashCode => Object.hash(beats, unit);
}

/// Servizio metronomo singleton: gestisce timing, audio e stato.
///
/// Espone [ChangeNotifier] così la UI può ascoltare con `ListenableBuilder`
/// o widget simili. Sopravvive a navigation/rebuild perché istanziato come
/// Provider (singleton) in providers.dart.
class MetronomeService extends ChangeNotifier {
  // Audio: due player alternati per evitare cutoff sul prossimo tick.
  // (audioplayers riproduce a partire da capo, ma su Android certi MediaPlayer
  // hanno latenza alta — alterniamo per ridurre il rischio di overlap.)
  final AudioPlayer _playerA = AudioPlayer(playerId: 'metronome-a');
  final AudioPlayer _playerB = AudioPlayer(playerId: 'metronome-b');
  bool _useA = true;
  bool _audioInitialized = false;

  // Stato pubblico
  int _bpm = 80;
  bool _running = false;
  TimeSignature _timeSignature = const TimeSignature(4, 4);
  MetronomeSound _sound = MetronomeSound.classic;
  double _volume = 0.7; // 0..1

  Timer? _timer;
  int _beatIndex = 0; // 0-based, riparte da 0 a ogni battuta

  int get bpm => _bpm;
  bool get isRunning => _running;
  TimeSignature get timeSignature => _timeSignature;
  MetronomeSound get sound => _sound;
  double get volume => _volume;
  int get beatIndex => _beatIndex;

  /// Indica se il beat corrente è il downbeat (1° della battuta).
  bool get isDownbeat => _beatIndex == 0;

  Future<void> _ensureAudio() async {
    if (_audioInitialized) return;
    try {
      // Mode di rendering più reattivo
      await _playerA.setReleaseMode(ReleaseMode.stop);
      await _playerB.setReleaseMode(ReleaseMode.stop);
      await _playerA.setPlayerMode(PlayerMode.lowLatency);
      await _playerB.setPlayerMode(PlayerMode.lowLatency);
      _audioInitialized = true;
    } catch (_) {
      // Su web/desktop lowLatency non è sempre supportato — degrada in silenzio.
      _audioInitialized = true;
    }
  }

  Future<void> start() async {
    if (_running) return;
    await _ensureAudio();
    _running = true;
    _beatIndex = 0;
    _scheduleTick(immediate: true);
    notifyListeners();
  }

  void stop() {
    if (!_running) return;
    _running = false;
    _timer?.cancel();
    _timer = null;
    _beatIndex = 0;
    notifyListeners();
  }

  void toggle() => _running ? stop() : start();

  void setBpm(int newBpm) {
    final clamped = newBpm.clamp(40, 240);
    if (clamped == _bpm) return;
    _bpm = clamped;
    if (_running) {
      _timer?.cancel();
      _scheduleTick();
    }
    notifyListeners();
  }

  void adjustBpm(int delta) => setBpm(_bpm + delta);

  void setTimeSignature(TimeSignature ts) {
    if (ts == _timeSignature) return;
    _timeSignature = ts;
    _beatIndex = 0;
    notifyListeners();
  }

  void setSound(MetronomeSound s) {
    if (s == _sound) return;
    _sound = s;
    notifyListeners();
  }

  void setVolume(double v) {
    final clamped = v.clamp(0.0, 1.0);
    if ((clamped - _volume).abs() < 0.001) return;
    _volume = clamped;
    _playerA.setVolume(_volume);
    _playerB.setVolume(_volume);
    notifyListeners();
  }

  // ── Internal ───────────────────────────────────────────────────────────────

  void _scheduleTick({bool immediate = false}) {
    final intervalMs = (60000 / _bpm).round();
    if (immediate) _tick();
    _timer = Timer.periodic(Duration(milliseconds: intervalMs), (_) => _tick());
  }

  Future<void> _tick() async {
    final isAccent = _beatIndex == 0;
    final assetName =
        '${_sound.assetPrefix}_${isAccent ? 'accent' : 'normal'}.wav';
    final source = AssetSource('sounds/$assetName');

    // Alterna fra due player così il prossimo click parte sempre da capo
    // anche se il precedente sta ancora terminando (50ms, raro ma succede).
    final player = _useA ? _playerA : _playerB;
    _useA = !_useA;
    try {
      await player.stop();
      await player.setVolume(_volume);
      await player.play(source);
    } catch (_) {
      // In caso di errore audio non interrompiamo il timer:
      // l'utente vede comunque la pulsazione visiva.
    }

    // Avanza il beat counter per la prossima battuta
    _beatIndex = (_beatIndex + 1) % _timeSignature.beats;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _playerA.dispose();
    _playerB.dispose();
    super.dispose();
  }
}
