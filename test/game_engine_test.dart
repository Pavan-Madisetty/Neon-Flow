import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:neon_flow/core/game_engine.dart';
import 'package:neon_flow/core/level.dart';

/// 3x3 board, three vertical flows:  col0=red, col1=blue, col2=green.
Level _tiny() => const Level(1, Difficulty.easy, 3, [
      FlowPair(0, [0, 3, 6]),
      FlowPair(1, [1, 4, 7]),
      FlowPair(2, [2, 5, 8]),
    ]);

void _draw(GameEngine e, List<int> cells) {
  e.startDrag(cells.first);
  for (final c in cells.skip(1)) {
    e.dragTo(c);
  }
  e.endDrag();
}

void main() {
  test('connecting a pair counts one move and completes the flow', () {
    final e = GameEngine(_tiny());
    _draw(e, [0, 3, 6]);
    expect(e.isComplete(0), isTrue);
    expect(e.moves, 1);
    expect(e.isSolved, isFalse);
  });

  test('solving every flow solves the level with 3 stars', () {
    final e = GameEngine(_tiny());
    _draw(e, [0, 3, 6]);
    _draw(e, [1, 4, 7]);
    _draw(e, [2, 5, 8]);
    expect(e.isSolved, isTrue);
    expect(e.starRating, 3);
  });

  test('drawing through another colour cuts it', () {
    final e = GameEngine(_tiny());
    _draw(e, [0, 3, 6]);
    e.startDrag(1);
    e.dragTo(4);
    final ev = e.dragTo(3); // cell 3 belongs to red
    expect(ev, MoveEvent.cut);
    e.endDrag();
    expect(e.ownerOf(3), 1);
    expect(e.isComplete(0), isFalse);
  });

  test('cannot draw over another colour\'s dot', () {
    final e = GameEngine(_tiny());
    e.startDrag(0);
    e.dragTo(1); // blue dot
    expect(e.pathOf(0), [0]);
  });

  test('backtracking shortens the path', () {
    final e = GameEngine(_tiny());
    e.startDrag(0);
    e.dragTo(3);
    e.dragTo(4);
    e.dragTo(3);
    expect(e.pathOf(0), [0, 3]);
  });

  test('a completed path cannot be extended', () {
    final e = GameEngine(_tiny());
    e.startDrag(0);
    e.dragTo(3);
    e.dragTo(6);
    expect(e.isComplete(0), isTrue);
    expect(e.dragTo(7), MoveEvent.blocked);
    expect(e.pathOf(0), [0, 3, 6]);
  });

  test('undo restores the previous state and move count', () {
    final e = GameEngine(_tiny());
    _draw(e, [0, 3, 6]);
    _draw(e, [1, 4, 7]);
    expect(e.moves, 2);
    expect(e.undo(), isTrue);
    expect(e.moves, 1);
    expect(e.pathOf(1), isEmpty);
    expect(e.isComplete(0), isTrue);
  });

  test('a tap that changes nothing is not a move', () {
    final e = GameEngine(_tiny());
    e.startDrag(4); // empty cell
    expect(e.endDrag(), isFalse);
    expect(e.moves, 0);
  });

  test('hint completes a colour and caps stars at 2', () {
    final e = GameEngine(_tiny());
    final c = e.applyHint();
    expect(c, isNotNull);
    expect(e.isComplete(c!), isTrue);
    _draw(e, [1, 4, 7]);
    _draw(e, [2, 5, 8]);
    _draw(e, [0, 3, 6]);
    expect(e.isSolved, isTrue);
    expect(e.starRating <= 2, isTrue);
  });

  test('a fast finger jump across cells still steps along the path', () {
    final e = GameEngine(_tiny());
    e.startDrag(0);
    e.dragTo(6); // skips cell 3
    expect(e.pathOf(0), [0, 3, 6]);
    expect(e.isComplete(0), isTrue);
  });

  test('all 150 shipped levels are valid and replayable to a solved state', () {
    final data = jsonDecode(File('assets/levels/levels.json').readAsStringSync())
        as Map<String, dynamic>;
    final levels = (data['levels'] as List)
        .map((e) => Level.fromJson(e as Map<String, dynamic>))
        .toList();
    expect(levels.length, 150);
    final counts = <Difficulty, int>{};
    for (final l in levels) {
      counts[l.difficulty] = (counts[l.difficulty] ?? 0) + 1;
      final e = GameEngine(l);
      for (final p in l.pairs) {
        _draw(e, p.solution);
      }
      expect(e.isSolved, isTrue, reason: 'level ${l.id} must be solvable');
    }
    expect(counts[Difficulty.easy], 50);
    expect(counts[Difficulty.medium], 50);
    expect(counts[Difficulty.hard], 50);
  });
}
