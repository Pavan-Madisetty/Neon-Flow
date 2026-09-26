import 'level.dart';

/// What happened as a result of a drag step. Used for sound / haptics.
enum MoveEvent { none, extended, backtracked, connected, cut, blocked, started }

/// Pure game logic (no Flutter dependencies apart from [Level]) so it can be
/// unit tested. Cells are addressed by index = row * size + col.
class GameEngine {
  final Level level;
  final int size;

  final Map<int, List<int>> _paths = {};
  final Map<int, FlowPair> _pairByColor = {};
  final List<int> _dotColor; // color of a dot at cell, -1 if none

  int? _active;
  int moves = 0;
  int hintsUsed = 0;
  int? hintedColor;

  final List<_Snap> _undoStack = [];
  Map<int, List<int>>? _dragSnapshot;

  GameEngine(this.level)
      : size = level.size,
        _dotColor = List.filled(level.size * level.size, -1) {
    for (final p in level.pairs) {
      _pairByColor[p.color] = p;
      _dotColor[p.a] = p.color;
      _dotColor[p.b] = p.color;
      _paths[p.color] = [];
    }
  }

  // ---------------------------------------------------------------- queries

  int? get activeColor => _active;
  List<FlowPair> get pairs => level.pairs;

  List<int> pathOf(int color) => _paths[color] ?? const [];

  int dotColorAt(int cell) => _dotColor[cell];

  bool isDot(int cell) => _dotColor[cell] != -1;

  /// Colour owning [cell] through a drawn path, or -1.
  int ownerOf(int cell) {
    for (final e in _paths.entries) {
      if (e.value.contains(cell)) return e.key;
    }
    return -1;
  }

  bool isComplete(int color) {
    final p = _paths[color]!;
    final pair = _pairByColor[color]!;
    if (p.length < 2) return false;
    final ends = {pair.a, pair.b};
    return ends.contains(p.first) && ends.contains(p.last) && p.first != p.last;
  }

  int get connectedCount => pairs.where((p) => isComplete(p.color)).length;

  int get filledCells {
    var n = 0;
    for (final p in _paths.values) {
      n += p.length;
    }
    return n;
  }

  double get fillRatio => filledCells / (size * size);

  bool get isSolved => connectedCount == pairs.length && filledCells == size * size;

  bool get canUndo => _undoStack.isNotEmpty;

  int get starRating {
    final n = pairs.length;
    var stars = 1;
    if (moves <= (n * 1.6).ceil()) {
      stars = 3;
    } else if (moves <= (n * 2.6).ceil()) {
      stars = 2;
    }
    if (hintsUsed > 0 && stars > 2) stars = 2;
    return stars;
  }

  bool areAdjacent(int a, int b) {
    final ar = a ~/ size, ac = a % size, br = b ~/ size, bc = b % size;
    return (ar - br).abs() + (ac - bc).abs() == 1;
  }

  // ----------------------------------------------------------------- drag

  Map<int, List<int>> _snapshot() =>
      {for (final e in _paths.entries) e.key: List<int>.from(e.value)};

  bool _sameAs(Map<int, List<int>> s) {
    for (final e in _paths.entries) {
      final o = s[e.key]!;
      if (o.length != e.value.length) return false;
      for (var i = 0; i < o.length; i++) {
        if (o[i] != e.value[i]) return false;
      }
    }
    return true;
  }

  /// Begin a drag on [cell]. Returns the resulting event.
  MoveEvent startDrag(int cell) {
    hintedColor = null;
    final dot = _dotColor[cell];
    _dragSnapshot = _snapshot();
    if (dot != -1) {
      _paths[dot] = [cell];
      _active = dot;
      return MoveEvent.started;
    }
    final owner = ownerOf(cell);
    if (owner != -1) {
      final p = _paths[owner]!;
      final idx = p.indexOf(cell);
      // Tapping the middle of a finished path resumes drawing from there.
      _paths[owner] = p.sublist(0, idx + 1);
      _active = owner;
      return MoveEvent.started;
    }
    _active = null;
    _dragSnapshot = null;
    return MoveEvent.none;
  }

  /// Move the active drag to [cell]; handles non-adjacent jumps by stepping.
  MoveEvent dragTo(int cell) {
    final c = _active;
    if (c == null) return MoveEvent.none;
    var result = MoveEvent.none;
    var guard = 0;
    while (guard++ < 4) {
      final last = _paths[c]!.last;
      if (last == cell) break;
      final next = _stepToward(last, cell);
      final ev = _stepTo(c, next);
      if (ev != MoveEvent.none) result = ev;
      if (ev == MoveEvent.blocked || ev == MoveEvent.none) break;
      if (_paths[c]!.last != next) break;
    }
    return result;
  }

  int _stepToward(int from, int to) {
    final fr = from ~/ size, fc = from % size, tr = to ~/ size, tc = to % size;
    final dr = tr - fr, dc = tc - fc;
    if (dr.abs() >= dc.abs() && dr != 0) {
      return (fr + dr.sign) * size + fc;
    }
    return fr * size + (fc + dc.sign);
  }

  MoveEvent _stepTo(int c, int cell) {
    final path = _paths[c]!;
    final last = path.last;
    if (!areAdjacent(last, cell)) return MoveEvent.none;

    // Backtrack along our own path.
    final own = path.indexOf(cell);
    if (own != -1) {
      if (own == path.length - 1) return MoveEvent.none;
      _paths[c] = path.sublist(0, own + 1);
      return MoveEvent.backtracked;
    }

    // A completed path can only be shortened, never extended.
    if (isComplete(c)) return MoveEvent.blocked;

    final dot = _dotColor[cell];
    if (dot != -1 && dot != c) return MoveEvent.blocked;

    var cut = false;
    final owner = ownerOf(cell);
    if (owner != -1 && owner != c) {
      final other = _paths[owner]!;
      final idx = other.indexOf(cell);
      _paths[owner] = other.sublist(0, idx);
      cut = true;
    }
    path.add(cell);
    if (dot == c) {
      return MoveEvent.connected;
    }
    return cut ? MoveEvent.cut : MoveEvent.extended;
  }

  /// Ends the drag. Returns true if the board state changed (counts a move).
  bool endDrag() {
    final snap = _dragSnapshot;
    _active = null;
    _dragSnapshot = null;
    if (snap == null) return false;
    if (_sameAs(snap)) return false;
    // A path that is just a lone dot is not a meaningful state.
    for (final e in _paths.entries) {
      if (e.value.length == 1) {
        // keep lone dots empty for cleanliness
        _paths[e.key] = [];
      }
    }
    if (_sameAs(snap)) return false;
    _undoStack.add(_Snap(snap, moves));
    if (_undoStack.length > 200) _undoStack.removeAt(0);
    moves++;
    return true;
  }

  // ----------------------------------------------------------- utilities

  bool undo() {
    if (_undoStack.isEmpty) return false;
    final snap = _undoStack.removeLast();
    for (final e in snap.paths.entries) {
      _paths[e.key] = List<int>.from(e.value);
    }
    moves = snap.moves;
    hintedColor = null;
    return true;
  }

  void reset() {
    for (final k in _paths.keys.toList()) {
      _paths[k] = [];
    }
    _undoStack.clear();
    _dragSnapshot = null;
    _active = null;
    moves = 0;
    hintsUsed = 0;
    hintedColor = null;
  }

  /// Reveals the solution for one colour. Returns the colour, or null if the
  /// puzzle is already solved.
  int? applyHint() {
    // Prefer a colour that is not yet connected, else one that differs from
    // the stored solution.
    FlowPair? target;
    for (final p in pairs) {
      if (!isComplete(p.color)) {
        target = p;
        break;
      }
    }
    if (target == null) {
      for (final p in pairs) {
        final cur = _paths[p.color]!;
        if (!_isSolutionPath(p, cur)) {
          target = p;
          break;
        }
      }
    }
    if (target == null) return null;

    final snap = _snapshot();
    // Remove cells of the target's solution from other paths.
    final solCells = target.solution.toSet();
    for (final e in _paths.entries.toList()) {
      if (e.key == target.color) continue;
      final p = e.value;
      final idx = p.indexWhere(solCells.contains);
      if (idx != -1) _paths[e.key] = p.sublist(0, idx);
    }
    _paths[target.color] = List<int>.from(target.solution);
    _undoStack.add(_Snap(snap, moves));
    hintsUsed++;
    hintedColor = target.color;
    return target.color;
  }

  bool _isSolutionPath(FlowPair p, List<int> cur) {
    if (cur.length != p.solution.length) return false;
    final fwd = List.generate(cur.length, (i) => cur[i] == p.solution[i]).every((e) => e);
    final rev = List.generate(cur.length, (i) => cur[i] == p.solution[cur.length - 1 - i])
        .every((e) => e);
    return fwd || rev;
  }
}

class _Snap {
  final Map<int, List<int>> paths;
  final int moves;
  const _Snap(this.paths, this.moves);
}
