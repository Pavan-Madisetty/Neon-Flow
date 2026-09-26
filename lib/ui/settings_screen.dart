import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/audio_service.dart';
import '../core/services.dart';
import 'theme.dart';
import 'widgets.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _devUnlocked = kDebugMode;

  Future<void> _confirmReset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NeonTheme.panel,
        title: const Text('Reset progress?'),
        content: const Text('All stars and unlocked levels will be erased. Hints are kept.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset', style: TextStyle(color: Color(0xFFFF4B5C))),
          ),
        ],
      ),
    );
    if (ok == true) {
      await Services.progress.resetProgress();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Progress reset.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NeonBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
                child: Row(children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text('Settings',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                ]),
              ),
              Expanded(
                child: ListenableBuilder(
                  listenable: Listenable.merge([Services.progress, Services.monetization]),
                  builder: (context, _) {
                    final p = Services.progress;
                    final m = Services.monetization;
                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _Card(children: [
                          SwitchListTile(
                            secondary: const Icon(Icons.volume_up_rounded),
                            title: const Text('Sound effects'),
                            value: p.soundOn,
                            onChanged: (v) async {
                              await p.setSound(v);
                              Services.audio.play(Sfx.click);
                            },
                          ),
                          SwitchListTile(
                            secondary: const Icon(Icons.vibration_rounded),
                            title: const Text('Vibration'),
                            value: p.hapticsOn,
                            onChanged: (v) async {
                              await p.setHaptics(v);
                              Services.audio.light();
                            },
                          ),
                        ]),
                        const SizedBox(height: 14),
                        _Card(children: [
                          ListTile(
                            leading: const Icon(Icons.restart_alt_rounded),
                            title: const Text('Reset progress'),
                            onTap: _confirmReset,
                          ),
                          ListTile(
                            leading: const Icon(Icons.info_outline_rounded),
                            title: const Text('Neon Flow'),
                            subtitle: const Text('Version 1.0.0  ·  150 levels'),
                            onLongPress: () {
                              setState(() => _devUnlocked = true);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Monetisation controls unlocked')),
                              );
                            },
                          ),
                        ]),
                        if (_devUnlocked) ...[
                          const SizedBox(height: 14),
                          const Padding(
                            padding: EdgeInsets.only(left: 6, bottom: 6),
                            child: Text('MONETISATION (runtime switches)',
                                style: TextStyle(
                                    color: NeonTheme.gold,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12,
                                    letterSpacing: 1.2)),
                          ),
                          _Card(children: [
                            SwitchListTile(
                              title: const Text('All ads'),
                              subtitle: const Text('Master switch for banner, interstitial, rewarded'),
                              value: m.rawAds,
                              onChanged: m.setAds,
                            ),
                            SwitchListTile(
                              title: const Text('Banner ads'),
                              value: m.rawBanner,
                              onChanged: m.rawAds ? m.setBanner : null,
                            ),
                            SwitchListTile(
                              title: const Text('Interstitial ads'),
                              value: m.rawInterstitial,
                              onChanged: m.rawAds ? m.setInterstitial : null,
                            ),
                            SwitchListTile(
                              title: const Text('Rewarded ads (free hints)'),
                              value: m.rawRewarded,
                              onChanged: m.rawAds ? m.setRewarded : null,
                            ),
                            SwitchListTile(
                              title: const Text('Hint packs (in-app purchase)'),
                              value: m.iapEnabled,
                              onChanged: m.setIap,
                            ),
                            ListTile(
                              title: const Text('Interstitial every N levels'),
                              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline),
                                  onPressed: () => m.setInterstitialEvery(m.interstitialEvery - 1),
                                ),
                                Text('${m.interstitialEvery}',
                                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline),
                                  onPressed: () => m.setInterstitialEvery(m.interstitialEvery + 1),
                                ),
                              ]),
                            ),
                            ListTile(
                              leading: const Icon(Icons.cloud_download_rounded),
                              title: const Text('Fetch remote config now'),
                              onTap: () async {
                                await m.fetchRemote();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Remote config refreshed (if a URL is set).')),
                                  );
                                }
                              },
                            ),
                          ]),
                        ],
                      ],
                    );
                  },
                ),
              ),
              const BannerAdWidget(),
            ],
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final List<Widget> children;
  const _Card({required this.children});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: NeonTheme.panel.withOpacity(0.92),
          borderRadius: BorderRadius.circular(20),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(children: children),
      );
}
