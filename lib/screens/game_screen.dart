import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../app/app_controller.dart';
import '../config/build_config.dart';
import '../debug/debug_controls.dart';
import '../game/game_snapshot.dart';
import '../game/stealth_breaker_game.dart';
import '../models/achievement.dart';
import '../models/game_result.dart';
import '../models/game_settings.dart';
import '../models/power.dart';
import '../models/brick.dart';
import '../models/objective.dart';
import '../models/specialty_brick_info.dart';
import '../services/audio_service.dart';
import '../theme/stealth_theme.dart';
import '../widgets/game_icons.dart';
import '../widgets/playfield_frame.dart';
import '../widgets/specialty_brick_visual.dart';
import '../widgets/stealth_components.dart';

class GameScreen extends StatefulWidget {
  const GameScreen(
      {super.key,
      required this.controller,
      required this.level,
      this.seed,
      this.daily = false,
      this.challengeDate,
      this.reservedPower});
  final AppController controller;
  final int level;
  final int? seed;
  final bool daily;
  final DateTime? challengeDate;
  final PowerId? reservedPower;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  late DateTime _effectiveChallengeDate =
      widget.challengeDate ?? widget.controller.effectiveNow;
  final List<AchievementUnlock> _unlockQueue = [];
  AchievementUnlock? _shownUnlock;
  final List<ObjectiveCompletionNotice> _objectiveNoticeQueue = [];
  ObjectiveCompletionNotice? _shownObjectiveNotice;
  List<SpecialtyBrickInfo> _specialtyIntroductions = const [];
  LevelCompletionResult? _result;

  PowerId? get _equippedPower {
    if (widget.daily) return null;
    return widget.reservedPower;
  }

  late final StealthBreakerGame game = StealthBreakerGame(
    initialLevel: widget.level,
    baseSeed: widget.seed ??
        widget.controller.effectiveNow.millisecondsSinceEpoch & 0x7fffffff,
    isDaily: widget.daily,
    analytics: widget.controller.analytics,
    onShotComplete: _onShotComplete,
    onLevelComplete: _onLevelComplete,
    onGameOver: widget.controller.recordGameOver,
    onFeedback: _onGameplayFeedback,
    onSpecialtiesAvailable: _onSpecialtiesAvailable,
    trajectorySteps: switch (widget.controller.settings.effectsQuality) {
      EffectsQuality.low => 80,
      EffectsQuality.medium => 150,
      EffectsQuality.high => 220,
    },
    showTrajectory: widget.controller.settings.trajectoryPreview,
    equippedPower: _equippedPower,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(widget.controller.audio.playMusic(
        widget.daily ? MusicTrack.dailyChallenge : MusicTrack.gameplay));
    Timer(const Duration(milliseconds: 3500), () {
      if (mounted) {
        _enqueueObjectiveNotices(widget.controller.takeObjectiveNotices());
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    game.snapshot.dispose();
    unawaited(widget.controller.audio.playMusic(MusicTrack.menu));
    super.dispose();
  }

  Future<void> _onShotComplete(ShotReport report) async {
    final unlocks = await widget.controller.recordShot(report);
    if (!mounted) return;
    _enqueueUnlocks(unlocks);
    _enqueueObjectiveNotices(widget.controller.takeObjectiveNotices());
  }

  void _onGameplayFeedback(GameplayFeedback feedback) {
    switch (feedback) {
      case GameplayFeedback.levelStart:
        unawaited(widget.controller.audio.playLevelStart());
        break;
      case GameplayFeedback.previewScan:
        unawaited(widget.controller.audio.playPreviewScan());
        break;
      case GameplayFeedback.stealthDisappear:
        unawaited(widget.controller.audio.playStealthDisappear());
        break;
      case GameplayFeedback.ballLaunch:
        unawaited(widget.controller.audio.playBallLaunch());
        unawaited(widget.controller.haptics.light());
        break;
      case GameplayFeedback.wallBounce:
        unawaited(widget.controller.audio.playWallBounce());
        break;
      case GameplayFeedback.brickHit:
        unawaited(widget.controller.audio.playBrickHit());
        break;
      case GameplayFeedback.brickBreak:
        unawaited(widget.controller.audio.playBrickBreak());
        unawaited(widget.controller.haptics.light());
        break;
      case GameplayFeedback.hiddenHit:
        unawaited(widget.controller.audio.playStealthHit());
        unawaited(widget.controller.haptics.medium());
        break;
      case GameplayFeedback.specialtyActivated:
        unawaited(widget.controller.haptics.medium());
        break;
      case GameplayFeedback.largeCombo:
        unawaited(widget.controller.audio.playApReward());
        break;
      case GameplayFeedback.levelComplete:
        unawaited(widget.controller.audio.playLevelComplete());
        unawaited(widget.controller.haptics.success());
        break;
      case GameplayFeedback.levelFailed:
        unawaited(widget.controller.audio.playLevelFailed());
        break;
    }
  }

  Future<void> _onLevelComplete(LevelRunReport report) async {
    final result = await widget.controller
        .recordLevelComplete(report, _effectiveChallengeDate);
    if (!mounted) return;
    setState(() => _result = result);
    _enqueueUnlocks(result.unlocks);
    _enqueueObjectiveNotices(widget.controller.takeObjectiveNotices());
  }

  Future<void> _onSpecialtiesAvailable(Set<BrickSpecialType> types) async {
    final introductions =
        await widget.controller.recordSpecialtyIntroductions(types);
    if (!mounted) return;
    setState(() => _specialtyIntroductions = introductions);
  }

  void _enqueueUnlocks(Iterable<AchievementUnlock> unlocks) {
    _unlockQueue.addAll(unlocks);
    _showNextUnlock();
  }

  void _showNextUnlock() {
    if (!mounted ||
        _shownUnlock != null ||
        _shownObjectiveNotice != null ||
        _unlockQueue.isEmpty) {
      return;
    }
    setState(() => _shownUnlock = _unlockQueue.removeAt(0));
    unawaited(widget.controller.audio.playAchievementUnlock());
    unawaited(widget.controller.haptics.success());
    Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() => _shownUnlock = null);
      _showNextUnlock();
      _showNextObjectiveNotice();
    });
  }

  void _enqueueObjectiveNotices(Iterable<ObjectiveCompletionNotice> notices) {
    _objectiveNoticeQueue.addAll(notices);
    _showNextObjectiveNotice();
  }

  void _showNextObjectiveNotice() {
    if (!mounted ||
        _shownObjectiveNotice != null ||
        _shownUnlock != null ||
        _objectiveNoticeQueue.isEmpty) {
      return;
    }
    setState(() =>
        _shownObjectiveNotice = _objectiveNoticeQueue.removeAt(0));
    Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() => _shownObjectiveNotice = null);
      _showNextObjectiveNotice();
      _showNextUnlock();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) game.handleAppResumed();
  }

  void _mainMenu() => Navigator.of(context).popUntil((route) => route.isFirst);

  void _showDebug() => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => FractionallySizedBox(
            heightFactor: .92,
            child: DebugControls(
              game: game,
              controller: widget.controller,
              onDailyDateChanged: (date) => _effectiveChallengeDate = date,
              onAchievementUnlocked: (unlock) {
                if (unlock != null) _enqueueUnlocks([unlock]);
              },
            )),
      );

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: false,
        onPopInvoked: (didPop) {
          if (!didPop) _confirmExit();
        },
        child: Scaffold(
          body: SafeArea(
            child: ValueListenableBuilder<GameSnapshot>(
              valueListenable: game.snapshot,
              builder: (context, state, _) {
                if (state.phase != GamePhase.firing) {
                  WidgetsBinding.instance
                      .addPostFrameCallback((_) => _showNextUnlock());
                }
                return Column(children: [
                  _hud(state),
                  Expanded(
                      child: PlayfieldFrame(
                          child: Stack(children: [
                    Positioned.fill(
                        child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanStart: (d) => game.beginAim(d.localPosition),
                      onPanUpdate: (d) => game.updateAim(d.localPosition),
                      onPanEnd: (_) {
                        final wasAiming = game.phase == GamePhase.aiming;
                        game.releaseAim();
                        if (wasAiming && game.phase == GamePhase.firing) {
                          unawaited(widget.controller.haptics.light());
                        }
                      },
                      onPanCancel: game.releaseAim,
                      child: GameWidget(game: game),
                    )),
                    if (state.phase == GamePhase.preview)
                      _previewOverlay(state),
                    if (widget.controller.settings.showCombo &&
                        state.phase == GamePhase.firing &&
                        state.currentCombo >= 2)
                      _comboBadge(state.currentCombo),
                    if (state.phase == GamePhase.paused) _pauseOverlay(),
                    if (state.phase == GamePhase.levelComplete)
                      _completeOverlay(state),
                    if (state.phase == GamePhase.gameOver)
                      _gameOverOverlay(state),
                    if (_shownUnlock != null) _achievementToast(_shownUnlock!),
                    if (_shownObjectiveNotice != null)
                      _objectiveToast(_shownObjectiveNotice!),
                    if (state.phase == GamePhase.preview &&
                        _specialtyIntroductions.isNotEmpty)
                      _specialtyIntroduction(),
                    if (BuildConfig.developerTools &&
                        widget.controller.developerMode)
                      _debugReadout(state),
                  ]))),
                ]);
              },
            ),
          ),
        ),
      );

  Widget _hud(GameSnapshot state) => Container(
        decoration: const BoxDecoration(
          color: StealthColors.surface,
          border: Border(bottom: BorderSide(color: StealthColors.border)),
        ),
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        child: Row(children: [
          Expanded(
              child: _hudValue(widget.daily ? 'DAILY' : 'LEVEL',
                  widget.daily ? 'CHALLENGE' : '${state.level}')),
          Container(width: 1, height: 28, color: StealthColors.border),
          Expanded(child: _hudValue('SCORE', '${state.score}', centered: true)),
          Container(width: 1, height: 28, color: StealthColors.border),
          Expanded(
              child: _hudValue('SHOTS', '${state.shotsRemaining}',
                  centered: true)),
          if (state.equippedPower != null)
            IconButton(
              tooltip: state.powerUsed
                  ? 'Power already used'
                  : state.equippedPower!.displayName,
              onPressed: state.powerUsed
                  ? null
                  : () {
                      if (game.activatePower()) setState(() {});
                    },
              icon: Icon(_powerIcon(state.equippedPower!),
                  color: state.powerUsed
                      ? StealthColors.disabled
                      : StealthColors.cyan),
            ),
          if (state.canPause)
            IconButton(
                tooltip: 'Pause',
                onPressed: game.requestPause,
                icon: const Icon(Icons.pause_rounded)),
          if (BuildConfig.developerTools && widget.controller.developerMode)
            IconButton(
                tooltip: 'Developer tools',
                onPressed: _showDebug,
                icon: const Icon(Icons.bug_report_rounded,
                    color: StealthColors.gold)),
        ]),
      );

  Widget _hudValue(String label, String value, {bool centered = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          crossAxisAlignment:
              centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
          children: [
            Text(label, style: StealthTextStyles.label.copyWith(fontSize: 9)),
            const SizedBox(height: 2),
            Text(value,
                maxLines: 1,
                overflow: TextOverflow.fade,
                style: StealthTextStyles.title.copyWith(fontSize: 14)),
          ],
        ),
      );

  IconData _powerIcon(PowerId power) => switch (power) {
        PowerId.scannerPulse => Icons.radar,
        PowerId.trajectoryPlus => Icons.route,
        PowerId.powerShot => Icons.bolt,
        PowerId.secondChance => Icons.replay_circle_filled,
      };

  Widget _previewOverlay(GameSnapshot state) => IgnorePointer(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
            child: StealthCard(
              accent: StealthColors.violet,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const GameIcon(GameIconType.preview,
                    size: 25, color: StealthColors.violet),
                const SizedBox(width: 10),
                Flexible(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                      Text('MEMORIZE THE VIOLET BRICKS',
                          style: StealthTextStyles.label.copyWith(
                              color: StealthColors.textPrimary, fontSize: 10)),
                      Text('They disappear when the preview ends',
                          style: Theme.of(context).textTheme.bodySmall),
                    ])),
                const SizedBox(width: 12),
                Text(state.previewSecondsRemaining.toStringAsFixed(1),
                    style: StealthTextStyles.display
                        .copyWith(color: StealthColors.violet, fontSize: 22)),
              ]),
            ),
          ),
        ),
      );

  Widget _comboBadge(int combo) => Positioned(
        top: 14,
        right: 14,
        child: IgnorePointer(
            child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
              color: StealthColors.surface.withOpacity(.92),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: StealthColors.cyan.withOpacity(.7))),
          child: Row(children: [
            const GameIcon(GameIconType.combo, size: 20),
            const SizedBox(width: 6),
            Text('${combo}x',
                style: StealthTextStyles.display
                    .copyWith(color: StealthColors.cyan, fontSize: 17)),
          ]),
        )),
      );

  Widget _pauseOverlay() => _centerPanel(title: 'PAUSED', children: [
        StealthButton(
            label: 'Resume',
            icon: Icons.play_arrow_rounded,
            onPressed: game.resumeFromPause),
        StealthButton(
            label: 'Restart Level',
            icon: Icons.restart_alt_rounded,
            style: StealthButtonStyle.secondary,
            onPressed: game.restartLevel),
        StealthButton(
            label: 'Main Menu',
            icon: Icons.home_outlined,
            style: StealthButtonStyle.subdued,
            onPressed: _mainMenu),
      ]);

  Widget _completeOverlay(GameSnapshot state) {
    final result = _result;
    if (result == null) {
      return _centerPanel(
          title: 'LEVEL CLEARED',
          accent: StealthColors.gold,
          children: const [CircularProgressIndicator()]);
    }
    final r = result.report;
    return _centerPanel(
        title: widget.daily ? 'DAILY COMPLETE' : 'LEVEL CLEARED',
        accent: StealthColors.gold,
        children: [
          if (!widget.daily)
            Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                    3,
                    (i) => Icon(
                        i < result.stars
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        color: StealthColors.gold,
                        size: 34))),
          Text('+${r.scoreEarned}',
              style: StealthTextStyles.display
                  .copyWith(color: StealthColors.gold, fontSize: 30)),
          const Text('SCORE EARNED', style: StealthTextStyles.label),
          _resultStats(r),
          if (result.pointsEarned > 0)
            Text('+${result.pointsEarned} Achievement Points',
                style: const TextStyle(
                    color: StealthColors.gold, fontWeight: FontWeight.bold)),
          ...result.chargeAwards.map((award) => Text(award.label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: StealthColors.cyan, fontWeight: FontWeight.bold))),
          if (result.personalBest)
            const Text('NEW PERSONAL RECORD',
                style: TextStyle(
                    color: StealthColors.cyan, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          if (!widget.daily)
            StealthButton(
                label: 'Next Level',
                icon: Icons.arrow_forward_rounded,
                onPressed: () {
                  setState(() => _result = null);
                  game.nextLevel();
                }),
          StealthButton(
              label: 'Replay',
              icon: Icons.replay_rounded,
              style: StealthButtonStyle.secondary,
              onPressed: () {
                setState(() => _result = null);
                game.replayLevel();
              }),
          StealthButton(
              label: 'Main Menu',
              icon: Icons.home_outlined,
              style: StealthButtonStyle.subdued,
              onPressed: _mainMenu),
        ]);
  }

  Widget _resultStats(LevelRunReport r) => StealthCard(
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          _resultRow(
              'Shots', '${r.shotsUsed} used', '${r.shotsRemaining} left'),
          const Divider(height: 16),
          _resultRow('Bricks', '${r.bricksDestroyed}',
              '${r.stealthDestroyed} stealth'),
          const Divider(height: 16),
          _resultRow('Best shot', '${r.bestCombo}',
              '${r.specialtiesDestroyed} specialty'),
        ]),
      );

  Widget _resultRow(String label, String value, String detail) =>
      Row(children: [
        Expanded(
            child: Text(label.toUpperCase(),
                style: StealthTextStyles.label.copyWith(fontSize: 9))),
        Text(value, style: StealthTextStyles.title.copyWith(fontSize: 12)),
        const SizedBox(width: 8),
        Text(detail,
            style: const TextStyle(
                fontSize: 11, color: StealthColors.textSecondary)),
      ]);

  Widget _gameOverOverlay(GameSnapshot state) =>
      _centerPanel(title: 'LEVEL FAILED', accent: StealthColors.red, children: [
        const GameIcon(GameIconType.stealth,
            size: 42, color: StealthColors.red),
        Text(
            '${state.stealthRemaining} stealth • ${state.bricksRemaining} total remain',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall),
        Text('${state.score}',
            style: StealthTextStyles.display.copyWith(fontSize: 28)),
        const Text('FINAL SCORE', style: StealthTextStyles.label),
        if (state.equippedPower == PowerId.secondChance && !state.powerUsed)
          StealthButton(
              label: 'Use Second Chance',
              icon: Icons.replay_circle_filled,
              onPressed: game.activatePower),
        StealthButton(
            label: 'Retry',
            icon: Icons.replay_rounded,
            onPressed: game.restartLevel),
        StealthButton(
            label: 'Main Menu',
            icon: Icons.home_outlined,
            style: StealthButtonStyle.subdued,
            onPressed: _mainMenu),
      ]);

  Widget _achievementToast(AchievementUnlock unlock) {
    final family = AchievementCatalog.family(unlock.tier.family);
    return Positioned(
        top: 214,
        left: 12,
        right: 12,
        child: IgnorePointer(
            child: Center(
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 310),
                    child: StealthCard(
                      accent: StealthColors.gold,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      child: Row(children: [
                        const AchievementBadge(
                            state: GameIconType.achievement,
                            color: StealthColors.gold,
                            size: 30),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                              Text(
                                  '${family.name} ${unlock.tier.roman} • +${unlock.tier.points} AP',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: StealthColors.gold)),
                              Text(
                                  family.descriptionBuilder(
                                      unlock.tier.threshold),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 10)),
                              if (unlock.chargeAward != null)
                                Text(unlock.chargeAward!.label,
                                    maxLines: 1,
                                    style: StealthTextStyles.label.copyWith(
                                        color: StealthColors.cyan,
                                        fontSize: 9)),
                            ])),
                      ]),
                    )))));
  }

  Widget _objectiveToast(ObjectiveCompletionNotice notice) => Positioned(
        top: 214,
        left: 12,
        right: 12,
        child: IgnorePointer(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 310),
              child: StealthCard(
                accent: StealthColors.cyan,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Row(children: [
                  const GameIcon(GameIconType.reward,
                      size: 28, color: StealthColors.cyan),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(notice.title,
                            style: StealthTextStyles.label.copyWith(
                                color: StealthColors.cyan, fontSize: 10)),
                        Text(
                          '${notice.objective.description} • +${notice.objective.reward.ap} AP',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        if (notice.chargeLabel != null)
                          Text(notice.chargeLabel!,
                              style: StealthTextStyles.label.copyWith(
                                  color: StealthColors.gold, fontSize: 9)),
                      ],
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
      );

  Widget _specialtyIntroduction() => Positioned(
        top: 214,
        left: 12,
        right: 12,
        child: IgnorePointer(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 350),
              child: StealthCard(
                accent: StealthColors.violet,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('NEW SPECIALTY BRICK',
                        style: StealthTextStyles.label.copyWith(
                            color: StealthColors.violet, fontSize: 10)),
                    const SizedBox(height: 5),
                    ..._specialtyIntroductions.map(
                      (info) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(children: [
                          SpecialtyBrickVisual(info: info, width: 44),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${info.name} — ${info.description}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 10),
                            ),
                          ),
                        ]),
                      ),
                    ),
                    Text('Review all specialty bricks in How to Play.',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(fontSize: 9)),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

  Widget _centerPanel(
          {required String title,
          required List<Widget> children,
          Color accent = StealthColors.cyan}) =>
      Positioned.fill(
          child: ColoredBox(
        color: StealthColors.background.withOpacity(.86),
        child: Center(
            child: SingleChildScrollView(
                child: Padding(
          padding: const EdgeInsets.all(18),
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: StealthCard(
                  accent: accent,
                  padding: const EdgeInsets.all(20),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(title,
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: accent,
                                letterSpacing: 2)),
                    const SizedBox(height: 14),
                    ...children.map((w) => Padding(
                        padding: const EdgeInsets.only(bottom: 9), child: w)),
                  ]))),
        ))),
      ));

  Widget _debugReadout(GameSnapshot state) => Positioned(
      left: 6,
      bottom: 6,
      child: IgnorePointer(
          child: Container(
        padding: const EdgeInsets.all(5),
        color: Colors.black54,
        child: Text(
            '${state.phase.name} seed:${state.seed} fps:${state.fps.toStringAsFixed(0)}\nball:${state.ballPosition.x.toStringAsFixed(1)},${state.ballPosition.y.toStringAsFixed(1)} vel:${state.ballVelocity.x.toStringAsFixed(0)},${state.ballVelocity.y.toStringAsFixed(0)}\nbricks:${state.bricksRemaining} stealth:${state.stealthRemaining} special:${state.specialtyRemaining} balls:${state.activeBalls}',
            style: const TextStyle(
                fontFamily: 'monospace', fontSize: 9, color: Colors.white70)),
      )));

  Future<void> _confirmExit() async {
    final leave = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
              backgroundColor: StealthColors.surface,
              shape: StealthTheme.dialogShape,
              title: const Text('Leave game?'),
              content: const Text('Current level progress will be lost.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Stay')),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Main Menu'))
              ],
            ));
    if (leave == true && mounted) _mainMenu();
  }
}
