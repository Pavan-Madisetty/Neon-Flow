import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_config.dart';

/// Persists stars, best moves, hints and user settings.
class ProgressStore extends ChangeNotifier {
  late SharedPreferences _prefs;

  final Map<int, int> _stars = {};
  final Map<int, int> _bestMoves = {};
  int _hints = AppConfig.startingHints;
  bool _sound = true;
  bool _haptics = true;
  int _levelsSinceAd = 0;
  int _lastWon = 0;

  /// Level ids that are always open (the first level of each difficulty).
  /// Set by [Services.init] once the level list is known.
  Set<int> difficultyStarts = {1};

  bool get soundOn => _sound;
  bool get hapticsOn => _haptics;
  int get hints => _hints;
  int get levelsSinceAd => _levelsSinceAd;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    _hints = _prefs.getInt('hints') ?? AppConfig.startingHints;
    _sound = _prefs.getBool('sound') ?? true;
    _haptics = _prefs.getBool('haptics') ?? true;
    _lastWon = _prefs.getInt('last_won') ?? 0;
    for (final key in _prefs.getKeys()) {
      if (key.startsWith('stars_')) {
        _stars[int.parse(key.substring(6))] = _prefs.getInt(key) ?? 0;
      } else if (key.startsWith('best_')) {
        _bestMoves[int.parse(key.substring(5))] = _prefs.getInt(key) ?? 0;
      }
    }
    notifyListeners();
  }

  int starsFor(int levelId) => _stars[levelId] ?? 0;
  int? bestMovesFor(int levelId) => _bestMoves[levelId];
  bool isCompleted(int levelId) => (_stars[levelId] ?? 0) > 0;

  int get completedCount => _stars.values.where((s) => s > 0).length;
  int get totalStars => _stars.values.fold(0, (a, b) => a + b);

  /// Each difficulty can be started at any time, but its levels must be
  /// played in order: a level is open if it is the first of its difficulty
  /// or the level before it has been completed.
  bool isUnlocked(int levelId) =>
      difficultyStarts.contains(levelId) || isCompleted(levelId - 1);

  /// The next level to play within [firstId]..[lastId]: the first level in that
  /// range that is not yet completed (or [lastId] if all are done).
  int currentIn(int firstId, int lastId) {
    for (var i = firstId; i <= lastId; i++) {
      if (!isCompleted(i)) return i;
    }
    return lastId;
  }

  /// Where the "Continue" button should go: the level after the last one won.
  int continueLevel(int total) {
    if (_lastWon <= 0) return 1;
    return (_lastWon + 1).clamp(1, total);
  }

  int starsInRange(int firstId, int lastId) {
    var t = 0;
    for (var i = firstId; i <= lastId; i++) {
      t += starsFor(i);
    }
    return t;
  }

  Future<void> recordWin(int levelId, int stars, int moves) async {
    if (stars > starsFor(levelId)) {
      _stars[levelId] = stars;
      await _prefs.setInt('stars_$levelId', stars);
    }
    final best = _bestMoves[levelId];
    if (best == null || moves < best) {
      _bestMoves[levelId] = moves;
      await _prefs.setInt('best_$levelId', moves);
    }
    _lastWon = levelId;
    await _prefs.setInt('last_won', levelId);
    _levelsSinceAd++;
    notifyListeners();
  }

  void resetAdCounter() => _levelsSinceAd = 0;

  Future<void> addHints(int n) async {
    _hints += n;
    await _prefs.setInt('hints', _hints);
    notifyListeners();
  }

  Future<bool> useHint() async {
    if (_hints <= 0) return false;
    _hints--;
    await _prefs.setInt('hints', _hints);
    notifyListeners();
    return true;
  }

  Future<void> setSound(bool v) async {
    _sound = v;
    await _prefs.setBool('sound', v);
    notifyListeners();
  }

  Future<void> setHaptics(bool v) async {
    _haptics = v;
    await _prefs.setBool('haptics', v);
    notifyListeners();
  }

  Future<void> resetProgress() async {
    for (final key in _prefs.getKeys().toList()) {
      if (key.startsWith('stars_') || key.startsWith('best_')) {
        await _prefs.remove(key);
      }
    }
    _stars.clear();
    _bestMoves.clear();
    _lastWon = 0;
    await _prefs.remove('last_won');
    notifyListeners();
  }
}
