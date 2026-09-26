import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

enum Difficulty { easy, medium, hard }

extension DifficultyX on Difficulty {
  String get label => switch (this) {
        Difficulty.easy => 'Easy',
        Difficulty.medium => 'Medium',
        Difficulty.hard => 'Hard',
      };
}

/// One colour in a level: two dots plus the stored solution path.
class FlowPair {
  final int color;
  final List<int> solution; // cell indices, first/last are the two dots
  const FlowPair(this.color, this.solution);

  int get a => solution.first;
  int get b => solution.last;
}

class Level {
  final int id; // 1-based, global
  final Difficulty difficulty;
  final int size;
  final List<FlowPair> pairs;

  const Level(this.id, this.difficulty, this.size, this.pairs);

  int get cellCount => size * size;

  factory Level.fromJson(Map<String, dynamic> j) {
    final size = j['size'] as int;
    final pairs = <FlowPair>[];
    for (final p in (j['pairs'] as List)) {
      final sol = <int>[];
      for (final cell in (p['solution'] as List)) {
        sol.add((cell[0] as int) * size + (cell[1] as int));
      }
      pairs.add(FlowPair(p['color'] as int, sol));
    }
    return Level(
      j['id'] as int,
      Difficulty.values.firstWhere((d) => d.name == j['difficulty']),
      size,
      pairs,
    );
  }
}

/// Levels are grouped into stages of [stageSize] levels each.
class LevelRepository {
  static const int stageSize = 10;

  final List<Level> levels;
  LevelRepository(this.levels);

  static Future<LevelRepository> load() async {
    final raw = await rootBundle.loadString('assets/levels/levels.json');
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final list = (data['levels'] as List)
        .map((e) => Level.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    return LevelRepository(list);
  }

  int get total => levels.length;
  int get stageCount => (levels.length / stageSize).ceil();

  Level byId(int id) => levels[id - 1];
  bool hasLevel(int id) => id >= 1 && id <= levels.length;

  /// Stage index is 0-based.
  int stageOf(int levelId) => (levelId - 1) ~/ stageSize;

  List<Level> stage(int stageIndex) {
    final start = stageIndex * stageSize;
    final end = (start + stageSize).clamp(0, levels.length);
    return levels.sublist(start, end);
  }

  Difficulty stageDifficulty(int stageIndex) => stage(stageIndex).first.difficulty;

  List<int> stagesFor(Difficulty d) => [
        for (var s = 0; s < stageCount; s++)
          if (stageDifficulty(s) == d) s
      ];
}
