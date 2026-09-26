import 'package:flutter/material.dart';

import '../core/audio_service.dart';
import '../core/level.dart';
import '../core/services.dart';
import 'game_screen.dart';
import 'theme.dart';
import 'widgets.dart';

class LevelSelectScreen extends StatelessWidget {
  const LevelSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Open on the tab of the player's current level.
    final current = Services.progress.highestUnlocked.clamp(1, Services.levels.total);
    final initial = Services.levels.byId(current).difficulty.index;
    return DefaultTabController(
      length: 3,
      initialIndex: initial,
      child: Scaffold(
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
                    const Text('Stages',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                    const Spacer(),
                    const HintChip(),
                  ]),
                ),
                TabBar(
                  indicatorColor: NeonTheme.gold,
                  labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                  tabs: [for (final d in Difficulty.values) Tab(text: d.label.toUpperCase())],
                ),
                Expanded(
                  child: TabBarView(
                    children: [for (final d in Difficulty.values) _DifficultyTab(difficulty: d)],
                  ),
                ),
                const BannerAdWidget(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DifficultyTab extends StatelessWidget {
  final Difficulty difficulty;
  const _DifficultyTab({required this.difficulty});

  @override
  Widget build(BuildContext context) {
    final stages = Services.levels.stagesFor(difficulty);
    return ListenableBuilder(
      listenable: Services.progress,
      builder: (context, _) => ListView.builder(
        padding: const EdgeInsets.all(14),
        itemCount: stages.length,
        itemBuilder: (_, i) => _StageCard(stageIndex: stages[i], number: stages[i] + 1),
      ),
    );
  }
}

class _StageCard extends StatelessWidget {
  final int stageIndex;
  final int number;
  const _StageCard({required this.stageIndex, required this.number});

  @override
  Widget build(BuildContext context) {
    final repo = Services.levels;
    final progress = Services.progress;
    final levels = repo.stage(stageIndex);
    final first = levels.first.id;
    final last = levels.last.id;
    final stars = progress.starsInRange(first, last);
    final size = levels.first.size;
    final accent = NeonTheme.difficultyColor(levels.first.difficulty.label);
    final unlocked = progress.isUnlocked(first);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: NeonTheme.panel.withOpacity(0.92),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accent.withOpacity(unlocked ? 0.55 : 0.15)),
        boxShadow: [BoxShadow(color: accent.withOpacity(0.12), blurRadius: 16)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('Stage $number',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: accent.withOpacity(0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('${size}×$size',
                  style: TextStyle(color: accent, fontWeight: FontWeight.w800, fontSize: 12)),
            ),
            const Spacer(),
            const Icon(Icons.star_rounded, color: NeonTheme.gold, size: 18),
            const SizedBox(width: 3),
            Text('$stars/${levels.length * 3}',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
          ]),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 5,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.82,
            children: [for (final l in levels) _LevelTile(level: l, accent: accent)],
          ),
        ],
      ),
    );
  }
}

class _LevelTile extends StatelessWidget {
  final Level level;
  final Color accent;
  const _LevelTile({required this.level, required this.accent});

  @override
  Widget build(BuildContext context) {
    final progress = Services.progress;
    final unlocked = progress.isUnlocked(level.id);
    final stars = progress.starsFor(level.id);
    final isCurrent = level.id == progress.highestUnlocked;
    return GestureDetector(
      onTap: () {
        if (!unlocked) {
          Services.audio.play(Sfx.error);
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(const SnackBar(content: Text('Finish the previous level to unlock this one.')));
          return;
        }
        Services.audio.play(Sfx.click);
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => GameScreen(levelId: level.id)),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: unlocked ? NeonTheme.panelLight : const Color(0xFF12172F),
          border: Border.all(
            color: isCurrent ? NeonTheme.gold : (unlocked ? accent.withOpacity(0.5) : Colors.white10),
            width: isCurrent ? 2 : 1,
          ),
          boxShadow: isCurrent
              ? [BoxShadow(color: NeonTheme.gold.withOpacity(0.45), blurRadius: 12)]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (unlocked)
              Text('${level.id}',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900))
            else
              const Icon(Icons.lock_rounded, color: Colors.white24, size: 20),
            const SizedBox(height: 3),
            StarRow(stars: stars, size: 12),
          ],
        ),
      ),
    );
  }
}
