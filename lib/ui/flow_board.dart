import 'package:flutter/material.dart';

import '../core/game_engine.dart';
import 'theme.dart';

typedef MoveCallback = void Function(MoveEvent event);
typedef DragEndCallback = void Function(bool changed);

/// The interactive, glowing game board.
class FlowBoard extends StatefulWidget {
  final GameEngine engine;
  final MoveCallback onMove;
  final DragEndCallback onDragEnd;
  final bool solved;
  final bool enabled;

  const FlowBoard({
    super.key,
    required this.engine,
    required this.onMove,
    required this.onDragEnd,
    this.solved = false,
    this.enabled = true,
  });

  @override
  State<FlowBoard> createState() => _FlowBoardState();
}

class _FlowBoardState extends State<FlowBoard> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))
        ..repeat(reverse: true);

  Offset? _finger;
  double _side = 0;

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  int? _cellAt(Offset p) {
    final n = widget.engine.size;
    final cell = _side / n;
    if (cell <= 0) return null;
    final c = (p.dx / cell).floor().clamp(0, n - 1);
    final r = (p.dy / cell).floor().clamp(0, n - 1);
    return r * n + c;
  }

  void _down(PointerDownEvent e) {
    if (!widget.enabled) return;
    final cell = _cellAt(e.localPosition);
    if (cell == null) return;
    final ev = widget.engine.startDrag(cell);
    _finger = e.localPosition;
    widget.onMove(ev);
    setState(() {});
  }

  void _move(PointerMoveEvent e) {
    if (!widget.enabled || widget.engine.activeColor == null) return;
    final cell = _cellAt(e.localPosition);
    if (cell == null) return;
    final ev = widget.engine.dragTo(cell);
    _finger = e.localPosition;
    if (ev != MoveEvent.none) widget.onMove(ev);
    setState(() {});
  }

  void _up() {
    if (widget.engine.activeColor == null) return;
    final changed = widget.engine.endDrag();
    _finger = null;
    widget.onDragEnd(changed);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      _side = box.biggest.shortestSide;
      return Center(
        child: SizedBox(
          width: _side,
          height: _side,
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: _down,
            onPointerMove: _move,
            onPointerUp: (_) => _up(),
            onPointerCancel: (_) => _up(),
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (_, __) => CustomPaint(
                painter: _BoardPainter(
                  engine: widget.engine,
                  pulse: _pulse.value,
                  finger: _finger,
                  solved: widget.solved,
                ),
              ),
            ),
          ),
        ),
      );
    });
  }
}

class _BoardPainter extends CustomPainter {
  final GameEngine engine;
  final double pulse;
  final Offset? finger;
  final bool solved;

  _BoardPainter({
    required this.engine,
    required this.pulse,
    required this.finger,
    required this.solved,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final n = engine.size;
    final cell = size.width / n;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(cell * 0.28),
    );

    // Board background + border glow.
    canvas.drawRRect(
      rrect.inflate(2),
      Paint()
        ..color = solved
            ? NeonTheme.gold.withOpacity(0.35 + 0.25 * pulse)
            : const Color(0xFF3A57FF).withOpacity(0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    canvas.drawRRect(rrect, Paint()..color = const Color(0xFF0A0E24));
    canvas.save();
    canvas.clipRRect(rrect);

    // Cells.
    final gridPaint = Paint()
      ..color = const Color(0xFF243067).withOpacity(0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (var r = 0; r < n; r++) {
      for (var c = 0; c < n; c++) {
        final rect = Rect.fromLTWH(c * cell, r * cell, cell, cell).deflate(1.5);
        final rr = RRect.fromRectAndRadius(rect, Radius.circular(cell * 0.14));
        canvas.drawRRect(rr, Paint()..color = const Color(0xFF10163A));
        canvas.drawRRect(rr, gridPaint);
      }
    }

    Offset center(int idx) => Offset((idx % n + 0.5) * cell, (idx ~/ n + 0.5) * cell);

    // Tinted cell fill under paths (makes progress readable at a glance).
    for (final pair in engine.pairs) {
      final path = engine.pathOf(pair.color);
      final color = NeonTheme.colorFor(pair.color);
      for (final idx in path) {
        final rect = Rect.fromCenter(center: center(idx), width: cell, height: cell).deflate(1.5);
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(cell * 0.14)),
          Paint()..color = color.withOpacity(0.13),
        );
      }
    }

    // Paths.
    for (final pair in engine.pairs) {
      final pts = engine.pathOf(pair.color);
      if (pts.length < 2) continue;
      final color = NeonTheme.colorFor(pair.color);
      final p = Path()..moveTo(center(pts.first).dx, center(pts.first).dy);
      for (var i = 1; i < pts.length; i++) {
        final o = center(pts[i]);
        p.lineTo(o.dx, o.dy);
      }
      final hinted = engine.hintedColor == pair.color;
      final complete = engine.isComplete(pair.color);
      final glowAlpha = hinted ? 0.55 + 0.35 * pulse : (complete ? 0.42 : 0.3);

      canvas.drawPath(
        p,
        Paint()
          ..color = color.withOpacity(glowAlpha)
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = cell * 0.62
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, cell * 0.16),
      );
      canvas.drawPath(
        p,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = cell * 0.34,
      );
      canvas.drawPath(
        p,
        Paint()
          ..color = Colors.white.withOpacity(0.28)
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = cell * 0.09,
      );
    }

    // Finger halo on the active colour.
    final active = engine.activeColor;
    if (active != null && finger != null) {
      final color = NeonTheme.colorFor(active);
      canvas.drawCircle(
        finger!,
        cell * 0.62,
        Paint()
          ..color = color.withOpacity(0.28)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, cell * 0.22),
      );
    }

    // Dots.
    for (final pair in engine.pairs) {
      final color = NeonTheme.colorFor(pair.color);
      final complete = engine.isComplete(pair.color);
      final k = complete ? 1.0 + 0.07 * pulse : 1.0;
      for (final idx in [pair.a, pair.b]) {
        final c = center(idx);
        canvas.drawCircle(
          c,
          cell * 0.4 * k,
          Paint()
            ..color = color.withOpacity(complete ? 0.6 : 0.42)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, cell * 0.14),
        );
        canvas.drawCircle(c, cell * 0.3 * k, Paint()..color = color);
        canvas.drawCircle(
          c.translate(-cell * 0.08, -cell * 0.09),
          cell * 0.09,
          Paint()..color = Colors.white.withOpacity(0.55),
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BoardPainter old) => true;
}
