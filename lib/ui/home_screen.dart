import 'package:flutter/material.dart';

import '../core/audio_service.dart';
import '../core/services.dart';
import 'game_screen.dart';
import 'level_select_screen.dart';
import 'settings_screen.dart';
import 'store_screen.dart';
import 'theme.dart';
import 'widgets.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _push(BuildContext context, Widget page) {
    Services.audio.play(Sfx.click);
    Navigator.of(context).push(_fade(page));
  }

  static Route<T> _fade<T>(Widget page) => PageRouteBuilder<T>(
        pageBuilder: (_, __, ___) => page,
        transitionDuration: const Duration(milliseconds: 260),
        transitionsBuilder: (_, a, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: a, curve: Curves.easeOut),
          child: SlideTransition(
            position: Tween(begin: const Offset(0, 0.04), end: Offset.zero)
                .animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
            child: child,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NeonBackground(
        child: SafeArea(
          child: ListenableBuilder(
            listenable: Services.progress,
            builder: (context, _) {
              final p = Services.progress;
              final total = Services.levels.total;
              final next = p.continueLevel(total);
              final started = p.completedCount > 0;
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Row(
                      children: [
                        HintChip(onTap: () => _push(context, const StoreScreen())),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.settings_rounded, size: 28),
                          onPressed: () => _push(context, const SettingsScreen()),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(flex: 2),
                  const _Logo(),
                  const SizedBox(height: 10),
                  Text(
                    'CONNECT THE DOTS · FILL THE BOARD',
                    style: TextStyle(
                      color: NeonTheme.textDim.withOpacity(0.9),
                      fontSize: 11,
                      letterSpacing: 2.2,
                    ),
                  ),
                  const Spacer(flex: 2),
                  GlowButton(
                    label: started ? 'CONTINUE  ·  LEVEL $next' : 'PLAY',
                    icon: Icons.play_arrow_rounded,
                    color: const Color(0xFF2F8BFF),
                    onTap: () {
                      Services.audio.play(Sfx.click);
                      Navigator.of(context).push(_fade(GameScreen(levelId: next)));
                    },
                  ),
                  const SizedBox(height: 18),
                  GlowButton(
                    label: 'STAGES',
                    icon: Icons.grid_view_rounded,
                    color: const Color(0xFFB04BFF),
                    onTap: () => _push(context, const LevelSelectScreen()),
                  ),
                  const SizedBox(height: 18),
                  GlowButton(
                    label: 'GET HINTS',
                    icon: Icons.lightbulb_rounded,
                    color: const Color(0xFFFF8A1F),
                    compact: true,
                    onTap: () => _push(context, const StoreScreen()),
                  ),
                  const Spacer(flex: 2),
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(
                      color: NeonTheme.panel.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.star_rounded, color: NeonTheme.gold),
                      const SizedBox(width: 6),
                      Text('${p.totalStars} / ${total * 3}',
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(width: 22),
                      const Icon(Icons.check_circle_rounded, color: Color(0xFF39D353)),
                      const SizedBox(width: 6),
                      Text('${p.completedCount} / $total levels',
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                    ]),
                  ),
                  const BannerAdWidget(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Logo extends StatefulWidget {
  const _Logo();

  @override
  State<_Logo> createState() => _LogoState();
}

class _LogoState extends State<_Logo> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 3))
        ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final glow = 6 + 14 * _c.value;
        return Column(
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < 4; i++) ...[
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: NeonTheme.colorFor(i),
                      boxShadow: [
                        BoxShadow(color: NeonTheme.colorFor(i).withOpacity(0.8), blurRadius: glow),
                      ],
                    ),
                  ),
                  if (i < 3)
                    Container(
                      width: 22,
                      height: 8,
                      color: NeonTheme.colorFor(i).withOpacity(0.9),
                    ),
                ],
              ],
            ),
            const SizedBox(height: 14),
            ShaderMask(
              shaderCallback: (r) => const LinearGradient(
                colors: [Color(0xFFFF3B3B), Color(0xFFFFD21F), Color(0xFF39D353), Color(0xFF2F8BFF), Color(0xFFB04BFF)],
              ).createShader(r),
              child: const Text(
                'NEON FLOW',
                style: TextStyle(
                  fontSize: 46,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
