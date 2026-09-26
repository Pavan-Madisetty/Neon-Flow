import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../core/app_config.dart';
import '../core/services.dart';
import 'theme.dart';

/// Big, glossy, press-animated button.
class GlowButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final Color color;
  final VoidCallback? onTap;
  final bool compact;

  const GlowButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.color = const Color(0xFF2F8BFF),
    this.compact = false,
  });

  @override
  State<GlowButton> createState() => _GlowButtonState();
}

class _GlowButtonState extends State<GlowButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final c = enabled ? widget.color : Colors.grey.shade700;
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.94 : 1,
        duration: const Duration(milliseconds: 90),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: widget.compact ? 18 : 28,
            vertical: widget.compact ? 10 : 16,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(40),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color.lerp(c, Colors.white, 0.25)!, c],
            ),
            boxShadow: [
              BoxShadow(color: c.withOpacity(0.55), blurRadius: 18, spreadRadius: 1),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, color: Colors.white, size: widget.compact ? 20 : 26),
                const SizedBox(width: 10),
              ],
              Text(
                widget.label,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: widget.compact ? 15 : 20,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Round icon button used in the game toolbar, with an optional badge.
class RoundIconButton extends StatelessWidget {
  final IconData icon;
  final String? label;
  final VoidCallback? onTap;
  final Color color;
  final String? badge;

  const RoundIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.label,
    this.badge,
    this.color = NeonTheme.panelLight,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: enabled ? color : color.withOpacity(0.4),
                  border: Border.all(color: Colors.white12),
                  boxShadow: enabled
                      ? [BoxShadow(color: color.withOpacity(0.5), blurRadius: 12)]
                      : null,
                ),
                child: Icon(icon, color: enabled ? Colors.white : Colors.white38, size: 26),
              ),
              if (badge != null)
                Positioned(
                  right: -4,
                  top: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: NeonTheme.gold,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      badge!,
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (label != null) ...[
            const SizedBox(height: 4),
            Text(label!, style: const TextStyle(fontSize: 12, color: NeonTheme.textDim)),
          ],
        ],
      ),
    );
  }
}

class StarRow extends StatelessWidget {
  final int stars;
  final double size;
  const StarRow({super.key, required this.stars, this.size = 16});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 3; i++)
          Icon(
            i < stars ? Icons.star_rounded : Icons.star_outline_rounded,
            size: size,
            color: i < stars ? NeonTheme.gold : Colors.white24,
          ),
      ],
    );
  }
}

/// Hint balance chip that opens the store when tapped.
class HintChip extends StatelessWidget {
  final VoidCallback? onTap;
  const HintChip({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Services.progress,
      builder: (_, __) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: NeonTheme.panelLight,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: NeonTheme.gold.withOpacity(0.5)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.lightbulb_rounded, color: NeonTheme.gold, size: 18),
            const SizedBox(width: 6),
            Text('${Services.progress.hints}',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
            if (onTap != null) ...[
              const SizedBox(width: 6),
              const Icon(Icons.add_circle, color: Colors.white70, size: 16),
            ],
          ]),
        ),
      ),
    );
  }
}

/// Adaptive banner ad that hides itself when banners are disabled.
class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    Services.monetization.addListener(_onConfig);
    _maybeLoad();
  }

  void _onConfig() {
    if (!Services.monetization.bannerEnabled) {
      _ad?.dispose();
      _ad = null;
      _loaded = false;
    } else if (_ad == null) {
      _maybeLoad();
    }
    if (mounted) setState(() {});
  }

  void _maybeLoad() {
    if (!Services.monetization.bannerEnabled || _ad != null) return;
    // Ads may still be initialising; retry shortly.
    if (!Services.ads.isReady) {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) _maybeLoad();
      });
      return;
    }
    final ad = BannerAd(
      adUnitId: AppConfig.banner,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, err) {
          ad.dispose();
          _ad = null;
          if (mounted) setState(() => _loaded = false);
        },
      ),
    );
    _ad = ad;
    ad.load();
  }

  @override
  void dispose() {
    Services.monetization.removeListener(_onConfig);
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (!Services.monetization.bannerEnabled || ad == null || !_loaded) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      width: ad.size.width.toDouble(),
      height: ad.size.height.toDouble(),
      child: AdWidget(ad: ad),
    );
  }
}

/// Lightweight confetti burst for the win screen.
class Confetti extends StatefulWidget {
  const Confetti({super.key});

  @override
  State<Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<Confetti> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))..forward();
  final _rng = math.Random();
  late final List<_Particle> _ps = List.generate(70, (i) => _Particle(_rng, i));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => CustomPaint(
          size: Size.infinite,
          painter: _ConfettiPainter(_ps, _c.value),
        ),
      ),
    );
  }
}

class _Particle {
  final double x, vx, vy, spin, size;
  final Color color;
  _Particle(math.Random r, int i)
      : x = 0.15 + r.nextDouble() * 0.7,
        vx = (r.nextDouble() - 0.5) * 0.9,
        vy = -(0.5 + r.nextDouble() * 0.9),
        spin = r.nextDouble() * 10,
        size = 5 + r.nextDouble() * 6,
        color = NeonTheme.colorFor(i);
}

class _ConfettiPainter extends CustomPainter {
  final List<_Particle> ps;
  final double t;
  _ConfettiPainter(this.ps, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in ps) {
      final x = (p.x + p.vx * t) * size.width;
      final y = (0.45 + p.vy * t + 1.6 * t * t) * size.height;
      if (y > size.height) continue;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.spin * t * 3);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.6),
          const Radius.circular(2),
        ),
        Paint()..color = p.color.withOpacity((1 - t * 0.7).clamp(0.0, 1.0)),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
