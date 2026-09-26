import 'dart:math' as math;

import 'package:flutter/material.dart';

class NeonTheme {
  static const Color bgTop = Color(0xFF0B1030);
  static const Color bgBottom = Color(0xFF05070F);
  static const Color panel = Color(0xFF141B3D);
  static const Color panelLight = Color(0xFF1E2755);
  static const Color gold = Color(0xFFFFC93C);
  static const Color textDim = Color(0xFF9AA5D6);

  /// Neon palette. Index = FlowPair.color.
  static const List<Color> flowColors = [
    Color(0xFFFF3B3B), // red
    Color(0xFF2F8BFF), // blue
    Color(0xFF39D353), // green
    Color(0xFFFFD21F), // yellow
    Color(0xFFFF8A1F), // orange
    Color(0xFF19D3E8), // cyan
    Color(0xFFB04BFF), // purple
    Color(0xFFFF4FB8), // pink
    Color(0xFFB5F03A), // lime
    Color(0xFFB8621B), // brown
    Color(0xFFE6E9FF), // white
  ];

  static Color colorFor(int i) => flowColors[i % flowColors.length];

  static Color difficultyColor(String label) {
    switch (label) {
      case 'Easy':
        return const Color(0xFF39D353);
      case 'Medium':
        return const Color(0xFFFFB020);
      default:
        return const Color(0xFFFF4B5C);
    }
  }

  static ThemeData get data => ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        scaffoldBackgroundColor: bgBottom,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF2F8BFF),
          secondary: gold,
          surface: panel,
        ),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5),
          titleLarge: TextStyle(fontWeight: FontWeight.w800),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: panelLight,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
}

/// Full-screen dark gradient with slowly drifting glowing dots.
class NeonBackground extends StatefulWidget {
  final Widget child;
  const NeonBackground({super.key, required this.child});

  @override
  State<NeonBackground> createState() => _NeonBackgroundState();
}

class _NeonBackgroundState extends State<NeonBackground> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 24))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [NeonTheme.bgTop, NeonTheme.bgBottom],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _c,
                builder: (_, __) => CustomPaint(painter: _OrbPainter(_c.value)),
              ),
            ),
          ),
          widget.child,
        ],
      ),
    );
  }
}

class _OrbPainter extends CustomPainter {
  final double t;
  _OrbPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < 14; i++) {
      final seed = i * 0.37;
      final x = (0.5 + 0.5 * math.sin(t * 2 * math.pi * (1 + i % 3) + seed * 9)) * size.width;
      final y = ((i * 0.083 + t * (0.25 + (i % 4) * 0.08)) % 1.0) * size.height;
      final color = NeonTheme.colorFor(i).withOpacity(0.16);
      final r = 6.0 + (i % 4) * 4;
      canvas.drawCircle(
        Offset(x, y),
        r * 2.6,
        Paint()..color = color..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 1.4),
      );
      canvas.drawCircle(Offset(x, y), r * 0.5, Paint()..color = color.withOpacity(0.5));
    }
  }

  @override
  bool shouldRepaint(_OrbPainter old) => old.t != t;
}
