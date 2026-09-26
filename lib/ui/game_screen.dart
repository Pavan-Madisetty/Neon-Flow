import 'package:flutter/material.dart';

import '../core/audio_service.dart';
import '../core/game_engine.dart';
import '../core/level.dart';
import '../core/services.dart';
import 'flow_board.dart';
import 'store_screen.dart';
import 'theme.dart';
import 'widgets.dart';

class GameScreen extends StatefulWidget {
  final int levelId;
  const GameScreen({super.key, required this.levelId});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late Level _level;
  late GameEngine _engine;
  bool _solved = false;
  bool _showWin = false;
  int _winStars = 0;

  @override
  void initState() {
    super.initState();
    _load(widget.levelId);
  }

  void _load(int id) {
    _level = Services.levels.byId(id);
    _engine = GameEngine(_level);
    _solved = false;
    _showWin = false;
  }

  // ----------------------------------------------------------------- events

  void _onMove(MoveEvent e) {
    final a = Services.audio;
    switch (e) {
      case MoveEvent.started:
        a.play(Sfx.tap, volume: 0.7);
        a.light();
        break;
      case MoveEvent.connected:
        a.play(Sfx.connect);
        a.medium();
        break;
      case MoveEvent.cut:
        a.play(Sfx.cut, volume: 0.8);
        a.light();
        break;
      case MoveEvent.blocked:
        a.light();
        break;
      case MoveEvent.extended:
      case MoveEvent.backtracked:
        a.light();
        break;
      case MoveEvent.none:
        break;
    }
    setState(() {});
  }

  void _onDragEnd(bool changed) {
    if (_engine.isSolved && !_solved) {
      _win();
    } else {
      setState(() {});
    }
  }

  Future<void> _win() async {
    _solved = true;
    _winStars = _engine.starRating;
    await Services.progress.recordWin(_level.id, _winStars, _engine.moves);
    Services.audio.play(Sfx.win);
    Services.audio.heavy();
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;
    setState(() => _showWin = true);
  }

  // ---------------------------------------------------------------- actions

  Future<void> _hint() async {
    if (_solved) return;
    if (Services.progress.hints <= 0) {
      Services.audio.play(Sfx.error);
      _openStore(reason: 'You are out of hints');
      return;
    }
    final color = _engine.applyHint();
    if (color == null) return;
    await Services.progress.useHint();
    Services.audio.play(Sfx.hint);
    Services.audio.medium();
    setState(() {});
    if (_engine.isSolved) _win();
  }

  void _undo() {
    if (_solved) return;
    if (_engine.undo()) {
      Services.audio.play(Sfx.undo);
      Services.audio.light();
      setState(() {});
    } else {
      Services.audio.play(Sfx.error, volume: 0.5);
    }
  }

  void _reset() {
    Services.audio.play(Sfx.click);
    setState(() => _engine.reset());
  }

  Future<void> _openStore({String? reason}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => StoreScreen(reason: reason)),
    );
    if (mounted) setState(() {});
  }

  Future<void> _next() async {
    final nextId = _level.id + 1;
    if (!Services.levels.hasLevel(nextId)) {
      Navigator.of(context).pop();
      return;
    }
    // Interstitial every N completed levels (runtime configurable).
    final cfg = Services.monetization;
    if (cfg.interstitialEnabled &&
        Services.progress.levelsSinceAd >= cfg.interstitialEvery &&
        _level.id >= 3) {
      final shown = await Services.ads.showInterstitial();
      if (shown) Services.progress.resetAdCounter();
    }
    if (!mounted) return;
    Services.audio.play(Sfx.click);
    setState(() => _load(nextId));
  }

  void _replay() {
    Services.audio.play(Sfx.click);
    setState(() {
      _engine.reset();
      _solved = false;
      _showWin = false;
    });
  }

  // ------------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final label = _level.difficulty.label;
    final accent = NeonTheme.difficultyColor(label);
    final best = Services.progress.bestMovesFor(_level.id);
    return Scaffold(
      body: NeonBackground(
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  _topBar(label, accent),
                  const SizedBox(height: 4),
                  _statsRow(best),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: FlowBoard(
                        key: ValueKey('board_${_level.id}'),
                        engine: _engine,
                        solved: _solved,
                        enabled: !_solved,
                        onMove: _onMove,
                        onDragEnd: _onDragEnd,
                      ),
                    ),
                  ),
                  _toolbar(),
                  const SizedBox(height: 10),
                  const BannerAdWidget(),
                ],
              ),
              if (_showWin) _winOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar(String label, Color accent) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 14, 0),
      child: Row(children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Level ${_level.id}',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          Text('$label · ${_level.size}×${_level.size}',
              style: TextStyle(color: accent, fontWeight: FontWeight.w700, fontSize: 12)),
        ]),
        const Spacer(),
        HintChip(onTap: () => _openStore()),
      ]),
    );
  }

  Widget _statsRow(int? best) {
    final total = _engine.pairs.length;
    final pct = (_engine.fillRatio * 100).round();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _stat('Flows', '${_engine.connectedCount}/$total'),
          _stat('Moves', '${_engine.moves}'),
          _stat('Filled', '$pct%'),
          _stat('Best', best?.toString() ?? '-'),
        ],
      ),
    );
  }

  Widget _stat(String k, String v) => Column(children: [
        Text(v, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        Text(k, style: const TextStyle(fontSize: 11, color: NeonTheme.textDim)),
      ]);

  Widget _toolbar() {
    return ListenableBuilder(
      listenable: Services.progress,
      builder: (_, __) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          RoundIconButton(
            icon: Icons.undo_rounded,
            label: 'Undo',
            onTap: _engine.canUndo && !_solved ? _undo : null,
          ),
          RoundIconButton(
            icon: Icons.lightbulb_rounded,
            label: 'Hint',
            color: const Color(0xFFB98A00),
            badge: '${Services.progress.hints}',
            onTap: _solved ? null : _hint,
          ),
          RoundIconButton(icon: Icons.refresh_rounded, label: 'Restart', onTap: _reset),
        ],
      ),
    );
  }

  Widget _winOverlay() {
    final hasNext = Services.levels.hasLevel(_level.id + 1);
    return Positioned.fill(
      child: Stack(
        children: [
          Positioned.fill(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 300),
              builder: (_, v, __) => Container(color: Colors.black.withOpacity(0.62 * v)),
            ),
          ),
          const Positioned.fill(child: Confetti()),
          Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.6, end: 1),
              duration: const Duration(milliseconds: 420),
              curve: Curves.elasticOut,
              builder: (_, v, child) => Transform.scale(scale: v, child: child),
              child: _WinCard(
                levelId: _level.id,
                stars: _winStars,
                moves: _engine.moves,
                best: Services.progress.bestMovesFor(_level.id) ?? _engine.moves,
                onNext: hasNext ? _next : null,
                onReplay: _replay,
                onMenu: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WinCard extends StatefulWidget {
  final int levelId, stars, moves, best;
  final VoidCallback? onNext;
  final VoidCallback onReplay;
  final VoidCallback onMenu;

  const _WinCard({
    required this.levelId,
    required this.stars,
    required this.moves,
    required this.best,
    required this.onNext,
    required this.onReplay,
    required this.onMenu,
  });

  @override
  State<_WinCard> createState() => _WinCardState();
}

class _WinCardState extends State<_WinCard> {
  @override
  void initState() {
    super.initState();
    for (var i = 0; i < widget.stars; i++) {
      Future<void>.delayed(Duration(milliseconds: 350 + i * 300), () {
        Services.audio.play(Sfx.star, volume: 0.8);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 310,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      decoration: BoxDecoration(
        color: NeonTheme.panel,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: NeonTheme.gold.withOpacity(0.6), width: 2),
        boxShadow: [BoxShadow(color: NeonTheme.gold.withOpacity(0.3), blurRadius: 30)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('LEVEL COMPLETE!',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
          const SizedBox(height: 4),
          Text('Level ${widget.levelId}', style: const TextStyle(color: NeonTheme.textDim)),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var i = 0; i < 3; i++)
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: i < widget.stars ? 1 : 0.0),
                duration: const Duration(milliseconds: 500),
                curve: Curves.elasticOut,
                builder: (_, v, __) {
                  final on = i < widget.stars;
                  return Padding(
                    padding: EdgeInsets.only(top: i == 1 ? 0 : 14, left: 2, right: 2),
                    child: Transform.scale(
                      scale: on ? 0.4 + 0.6 * v : 1,
                      child: Icon(
                        on ? Icons.star_rounded : Icons.star_outline_rounded,
                        size: i == 1 ? 68 : 54,
                        color: on ? NeonTheme.gold : Colors.white24,
                      ),
                    ),
                  );
                },
              ),
          ]),
          const SizedBox(height: 10),
          Text('Moves: ${widget.moves}   ·   Best: ${widget.best}',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),
          if (widget.onNext != null)
            GlowButton(
              label: 'NEXT LEVEL',
              icon: Icons.arrow_forward_rounded,
              color: const Color(0xFF39D353),
              onTap: widget.onNext,
            ),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            GlowButton(
              label: 'REPLAY',
              icon: Icons.replay_rounded,
              compact: true,
              color: const Color(0xFF2F8BFF),
              onTap: widget.onReplay,
            ),
            const SizedBox(width: 12),
            GlowButton(
              label: 'MENU',
              icon: Icons.home_rounded,
              compact: true,
              color: const Color(0xFF6B4BFF),
              onTap: widget.onMenu,
            ),
          ]),
        ],
      ),
    );
  }
}
