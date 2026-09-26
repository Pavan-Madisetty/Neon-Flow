import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'progress_store.dart';

enum Sfx { tap, click, move, connect, cut, hint, win, undo, error, star }

/// Plays short sound effects and haptics, honouring the user's settings.
class AudioService {
  final ProgressStore settings;
  final Map<Sfx, AudioPlayer> _players = {};
  bool _ready = false;

  AudioService(this.settings);

  Future<void> init() async {
    try {
      for (final s in Sfx.values) {
        final p = AudioPlayer();
        await p.setPlayerMode(PlayerMode.lowLatency);
        await p.setReleaseMode(ReleaseMode.stop);
        await p.setSource(AssetSource('sounds/${s.name}.wav'));
        _players[s] = p;
      }
      _ready = true;
    } catch (e) {
      debugPrint('Audio init failed: $e');
    }
  }

  Future<void> play(Sfx s, {double volume = 1.0}) async {
    if (!settings.soundOn || !_ready) return;
    try {
      final p = _players[s];
      if (p == null) return;
      await p.stop();
      await p.setVolume(volume);
      await p.resume();
    } catch (e) {
      debugPrint('Audio play failed: $e');
    }
  }

  void light() {
    if (settings.hapticsOn) HapticFeedback.selectionClick();
  }

  void medium() {
    if (settings.hapticsOn) HapticFeedback.mediumImpact();
  }

  void heavy() {
    if (settings.hapticsOn) HapticFeedback.heavyImpact();
  }

  void dispose() {
    for (final p in _players.values) {
      p.dispose();
    }
  }
}
