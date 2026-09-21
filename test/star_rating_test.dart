import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:stealth_breaker/app/app_controller.dart';
import 'package:stealth_breaker/game/systems/star_rating.dart';
import 'package:stealth_breaker/models/game_result.dart';
import 'package:stealth_breaker/models/game_settings.dart';
import 'package:stealth_breaker/models/objective.dart';
import 'package:stealth_breaker/models/player_progress.dart';
import 'package:stealth_breaker/models/power_charge_award.dart';
import 'package:stealth_breaker/services/analytics_service.dart';
import 'package:stealth_breaker/services/persistence_service.dart';

class _MemoryPersistence implements PersistenceService {
  PlayerProgress progress = const PlayerProgress();
  GameSettings settings = const GameSettings();

  @override
  Future<void> clear() async {
    progress = const PlayerProgress();
    settings = const GameSettings();
  }

  @override
  Future<PlayerProgress> loadProgress() async => progress;

  @override
  Future<GameSettings> loadSettings() async => settings;

  @override
  Future<void> saveProgress(PlayerProgress value) async => progress = value;

  @override
  Future<void> saveSettings(GameSettings value) async => settings = value;
}

class _FixedRandom implements Random {
  const _FixedRandom(this.value);

  final double value;

  @override
  bool nextBool() => value < .5;

  @override
  double nextDouble() => value;

  @override
  int nextInt(int max) => 0;
}

LevelRunReport _report({
  required int remaining,
  int originalStartingShots = 18,
  int level = 19,
}) =>
    LevelRunReport(
      level: level,
      scoreEarned: 100,
      originalStartingShots: originalStartingShots,
      shotsUsed: max(0, originalStartingShots - remaining),
      shotsRemaining: remaining,
      bricksDestroyed: 12,
      stealthDestroyed: 2,
      bestCombo: 5,
      wallBounceHits: 1,
      specialtiesDestroyed: 0,
      missedShots: 0,
      daily: false,
    );

void main() {
  group('star efficiency thresholds', () {
    for (final testCase in <(int, int)>[
      (0, 1),
      (2, 1),
      (3, 1),
      (4, 2),
      (6, 2),
      (7, 3),
      (10, 3),
    ]) {
      test('18 starting shots with ${testCase.$1} remaining earns ${testCase.$2}',
          () {
        expect(
          StarRating.calculate(
            levelCleared: true,
            originalStartingShots: 18,
            shotsUsed: 18 - testCase.$1,
          ),
          testCase.$2,
        );
      });
    }

    test('failed level earns no stars', () {
      expect(
        StarRating.calculate(
          levelCleared: false,
          originalStartingShots: 18,
          shotsUsed: 1,
        ),
        0,
      );
    });

    test('extra shots do not change the original allowance thresholds', () {
      expect(
        StarRating.calculate(
          levelCleared: true,
          originalStartingShots: 18,
          shotsUsed: 16,
        ),
        1,
      );
    });
  });

  test('replays only add improved stars and dependent objectives use the delta',
      () async {
    const dailyStarObjective = ObjectiveState(
      id: 'daily_2026-09-21_earnStars_01',
      type: ObjectiveType.earnStars,
      category: ObjectiveCategory.performance,
      description: 'Earn 3 stars',
      target: 3,
      reward: ObjectiveReward(ap: 0),
    );
    const dailyFillerOne = ObjectiveState(
      id: 'daily_2026-09-21_completeLevels_02',
      type: ObjectiveType.completeLevels,
      category: ObjectiveCategory.completion,
      description: 'Complete 99 levels',
      target: 99,
      reward: ObjectiveReward(ap: 0),
    );
    const dailyFillerTwo = ObjectiveState(
      id: 'daily_2026-09-21_destroyBricks_03',
      type: ObjectiveType.destroyBricks,
      category: ObjectiveCategory.destruction,
      description: 'Destroy 999 bricks',
      target: 999,
      reward: ObjectiveReward(ap: 0),
    );
    const weeklyMasteryObjective = ObjectiveState(
      id: 'weekly_2026-W39_threeStarCompletions_01',
      type: ObjectiveType.threeStarCompletions,
      category: ObjectiveCategory.performance,
      description: 'Earn 1 three-star completion',
      target: 1,
      reward: ObjectiveReward(ap: 0),
    );
    const weeklyFillerOne = ObjectiveState(
      id: 'weekly_2026-W39_completeLevels_02',
      type: ObjectiveType.completeLevels,
      category: ObjectiveCategory.completion,
      description: 'Complete 99 levels',
      target: 99,
      reward: ObjectiveReward(ap: 0),
    );
    const weeklyFillerTwo = ObjectiveState(
      id: 'weekly_2026-W39_destroyBricks_03',
      type: ObjectiveType.destroyBricks,
      category: ObjectiveCategory.destruction,
      description: 'Destroy 999 bricks',
      target: 999,
      reward: ObjectiveReward(ap: 0),
    );
    final persistence = _MemoryPersistence()
      ..progress = const PlayerProgress(
        unlockedPowers: {'scannerPulse'},
        powerCharges: {'scannerPulse': 0},
        dailyObjectives: ObjectiveSetState(
          period: ObjectivePeriod.daily,
          key: '2026-09-21',
          objectives: [dailyStarObjective, dailyFillerOne, dailyFillerTwo],
        ),
        weeklyObjectives: ObjectiveSetState(
          period: ObjectivePeriod.weekly,
          key: '2026-W39',
          objectives: [
            weeklyMasteryObjective,
            weeklyFillerOne,
            weeklyFillerTwo,
          ],
        ),
      );
    final controller = AppController(
      persistence: persistence,
      analytics: const NoopAnalyticsService(),
      rewardRandom: const _FixedRandom(1),
      clock: () => DateTime(2026, 9, 21, 12),
    );
    await controller.initialize();

    final first = await controller.recordLevelComplete(
      _report(remaining: 3),
      DateTime(2026, 9, 21),
    );
    expect(first.stars, 1);
    expect(first.newStars, 1);
    expect(controller.progress.levelStars['19'], 1);
    expect(controller.progress.totalStars, 1);

    final second = await controller.recordLevelComplete(
      _report(remaining: 4),
      DateTime(2026, 9, 21),
    );
    expect(second.stars, 2);
    expect(second.newStars, 1);
    expect(controller.progress.levelStars['19'], 2);
    expect(controller.progress.totalStars, 2);

    final lowerReplay = await controller.recordLevelComplete(
      _report(remaining: 3),
      DateTime(2026, 9, 21),
    );
    expect(lowerReplay.stars, 1);
    expect(lowerReplay.newStars, 0);
    expect(controller.progress.levelStars['19'], 2);
    expect(controller.progress.totalStars, 2);

    final third = await controller.recordLevelComplete(
      _report(remaining: 7),
      DateTime(2026, 9, 21),
    );
    expect(third.stars, 3);
    expect(third.newStars, 1);
    expect(controller.progress.levelStars['19'], 3);
    expect(controller.progress.totalStars, 3);
    expect(
      third.chargeAwards.where(
        (award) => award.source == PowerChargeAwardSource.mastery,
      ),
      hasLength(1),
    );
    expect(
      controller.progress.dailyObjectives!.objectives.first.progress,
      3,
    );
    expect(
      controller.progress.weeklyObjectives!.objectives.first.progress,
      1,
    );

    final repeatedMastery = await controller.recordLevelComplete(
      _report(remaining: 10),
      DateTime(2026, 9, 21),
    );
    expect(repeatedMastery.newStars, 0);
    expect(
      repeatedMastery.chargeAwards.where(
        (award) => award.source == PowerChargeAwardSource.mastery,
      ),
      isEmpty,
    );
    expect(controller.progress.totalStars, 3);
    expect(
      controller.progress.weeklyObjectives!.objectives.first.progress,
      1,
    );

    final reopened = AppController(
      persistence: persistence,
      analytics: const NoopAnalyticsService(),
      rewardRandom: const _FixedRandom(1),
      clock: () => DateTime(2026, 9, 21, 12),
    );
    await reopened.initialize();
    expect(reopened.progress.levelStars['19'], 3);
    expect(reopened.progress.totalStars, 3);
  });
}
