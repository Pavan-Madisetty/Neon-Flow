import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../core/app_config.dart';
import '../core/audio_service.dart';
import '../core/services.dart';
import 'theme.dart';
import 'widgets.dart';

/// Hint store: rewarded video + Google Play consumable packs. Each section
/// obeys the runtime monetisation switches.
class StoreScreen extends StatefulWidget {
  final String? reason;
  const StoreScreen({super.key, this.reason});

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  bool _busy = false;
  String? _lastShownMessage;

  @override
  void initState() {
    super.initState();
    Services.iap.addListener(_onIap);
  }

  @override
  void dispose() {
    Services.iap.removeListener(_onIap);
    super.dispose();
  }

  void _onIap() {
    final msg = Services.iap.lastMessage;
    if (msg != null && msg != _lastShownMessage && mounted) {
      _lastShownMessage = msg;
      _toast(msg);
      Services.iap.lastMessage = null;
      _lastShownMessage = null;
    }
    if (mounted) setState(() {});
  }

  void _toast(String m) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _watchAd() async {
    if (_busy) return;
    setState(() => _busy = true);
    Services.audio.play(Sfx.click);
    final earned = await Services.ads.showRewarded();
    if (earned) {
      await Services.progress.addHints(AppConfig.rewardedHintAmount);
      Services.audio.play(Sfx.hint);
      if (mounted) _toast('+${AppConfig.rewardedHintAmount} hint earned!');
    } else if (mounted) {
      _toast('No video is available right now. Try again in a moment.');
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final cfg = Services.monetization;
    return Scaffold(
      body: NeonBackground(
        child: SafeArea(
          child: ListenableBuilder(
            listenable: Listenable.merge([cfg, Services.progress, Services.iap]),
            builder: (context, _) {
              final iap = Services.iap;
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
                    child: Row(children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_rounded),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Text('Hint Store',
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                      const Spacer(),
                      const HintChip(),
                    ]),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(18),
                      children: [
                        if (widget.reason != null)
                          Container(
                            margin: const EdgeInsets.only(bottom: 14),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF4B5C).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text('${widget.reason}. Grab some more below!',
                                style: const TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        const Center(
                          child: Icon(Icons.lightbulb_rounded, size: 72, color: NeonTheme.gold),
                        ),
                        const SizedBox(height: 6),
                        const Center(
                          child: Text(
                            'A hint instantly solves one colour.',
                            style: TextStyle(color: NeonTheme.textDim),
                          ),
                        ),
                        const SizedBox(height: 22),
                        if (cfg.rewardedEnabled)
                          _StoreTile(
                            icon: Icons.play_circle_fill_rounded,
                            color: const Color(0xFF39D353),
                            title: 'Watch a video',
                            subtitle: '+${AppConfig.rewardedHintAmount} free hint',
                            trailing: _busy ? 'Loading…' : 'FREE',
                            onTap: _busy ? null : _watchAd,
                          ),
                        if (cfg.iapEnabled) ...[
                          const SizedBox(height: 10),
                          if (iap.loading)
                            const Padding(
                              padding: EdgeInsets.all(30),
                              child: Center(child: CircularProgressIndicator()),
                            )
                          else if (!iap.available || iap.products.isEmpty)
                            _StoreNote(
                              iap.available
                                  ? 'Hint packs are not available yet.'
                                  : 'Google Play purchases are unavailable on this device.',
                            )
                          else
                            for (final p in iap.products) ...[
                              _StoreTile(
                                icon: Icons.lightbulb_circle_rounded,
                                color: const Color(0xFFFF8A1F),
                                title: '${iap.hintsFor(p)} Hints',
                                subtitle: p.description.isEmpty ? 'Hint pack' : p.description,
                                trailing: p.price,
                                onTap: () {
                                  Services.audio.play(Sfx.click);
                                  iap.buy(p);
                                },
                              ),
                              const SizedBox(height: 10),
                            ],
                        ],
                        if (!cfg.rewardedEnabled && !cfg.iapEnabled)
                          const _StoreNote('The store is currently closed. Check back soon!'),
                      ],
                    ),
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

class _StoreTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title, subtitle, trailing;
  final VoidCallback? onTap;

  const _StoreTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: NeonTheme.panel,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.55)),
          boxShadow: [BoxShadow(color: color.withOpacity(0.15), blurRadius: 14)],
        ),
        child: Row(children: [
          Icon(icon, size: 40, color: color),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              Text(subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: NeonTheme.textDim, fontSize: 12)),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
            child: Text(trailing,
                style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white)),
          ),
        ]),
      ),
    );
  }
}

class _StoreNote extends StatelessWidget {
  final String text;
  const _StoreNote(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(18),
        child: Center(
          child: Text(text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: NeonTheme.textDim)),
        ),
      );
}
