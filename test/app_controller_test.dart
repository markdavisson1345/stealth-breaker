import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:stealth_breaker/app/app_controller.dart';
import 'package:stealth_breaker/models/game_result.dart';
import 'package:stealth_breaker/models/game_settings.dart';
import 'package:stealth_breaker/models/brick.dart';
import 'package:stealth_breaker/models/objective.dart';
import 'package:stealth_breaker/models/player_progress.dart';
import 'package:stealth_breaker/models/power.dart';
import 'package:stealth_breaker/models/power_charge_award.dart';
import 'package:stealth_breaker/services/analytics_service.dart';
import 'package:stealth_breaker/services/persistence_service.dart';

class MemoryPersistence implements PersistenceService {
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

class FixedRandom implements Random {
  FixedRandom(this.value);
  final double value;

  @override
  bool nextBool() => value < .5;

  @override
  double nextDouble() => value;

  @override
  int nextInt(int max) => 0;
}

LevelRunReport normalReport({int level = 1}) => LevelRunReport(
    level: level,
    scoreEarned: 100,
    originalStartingShots: 5,
    shotsUsed: 2,
    shotsRemaining: 3,
    bricksDestroyed: 5,
    stealthDestroyed: 1,
    bestCombo: 5,
    wallBounceHits: 1,
    specialtiesDestroyed: 0,
    missedShots: 0,
    daily: false);

LevelRunReport dailyReport() => const LevelRunReport(
    level: 8,
    scoreEarned: 100,
    originalStartingShots: 4,
    shotsUsed: 3,
    shotsRemaining: 1,
    bricksDestroyed: 10,
    stealthDestroyed: 3,
    bestCombo: 5,
    wallBounceHits: 2,
    specialtiesDestroyed: 1,
    missedShots: 0,
    daily: true);

void main() {
  test('objective sets survive restart and reset on the next period', () async {
    final persistence = MemoryPersistence();
    var now = DateTime(2026, 9, 21, 10);
    final controller = AppController(
      persistence: persistence,
      analytics: const NoopAnalyticsService(),
      clock: () => now,
    );
    await controller.initialize();
    final dailyIds = controller.progress.dailyObjectives!.objectives
        .map((value) => value.id)
        .toList();
    final weeklyIds = controller.progress.weeklyObjectives!.objectives
        .map((value) => value.id)
        .toList();
    expect(dailyIds, hasLength(3));
    expect(weeklyIds, hasLength(3));

    final reopened = AppController(
      persistence: persistence,
      analytics: const NoopAnalyticsService(),
      clock: () => now,
    );
    await reopened.initialize();
    expect(
        reopened.progress.dailyObjectives!.objectives.map((value) => value.id),
        dailyIds);
    expect(
        reopened.progress.weeklyObjectives!.objectives.map((value) => value.id),
        weeklyIds);

    now = DateTime(2026, 9, 22, 1);
    await reopened.refreshObjectives(now);
    expect(reopened.progress.dailyObjectives!.key, '2026-09-22');
    expect(
        reopened.progress.dailyObjectives!.objectives.map((value) => value.id),
        isNot(dailyIds));
    expect(
        reopened.progress.weeklyObjectives!.objectives.map((value) => value.id),
        weeklyIds);

    now = DateTime(2026, 9, 28, 1);
    await reopened.refreshObjectives(now);
    expect(reopened.progress.weeklyObjectives!.key, '2026-W40');
    expect(
        reopened.progress.weeklyObjectives!.objectives.map((value) => value.id),
        isNot(weeklyIds));
  });

  test('objective progress and reward persist without duplicate grant',
      () async {
    const incomplete = ObjectiveState(
      id: 'daily_2026-09-21_destroyBricks_01',
      type: ObjectiveType.destroyBricks,
      category: ObjectiveCategory.destruction,
      description: 'Destroy 1 brick',
      target: 1,
      reward: ObjectiveReward(ap: 2),
    );
    const fillerOne = ObjectiveState(
      id: 'daily_2026-09-21_completeLevels_02',
      type: ObjectiveType.completeLevels,
      category: ObjectiveCategory.completion,
      description: 'Complete 99 levels',
      target: 99,
      reward: ObjectiveReward(ap: 2),
    );
    const fillerTwo = ObjectiveState(
      id: 'daily_2026-09-21_earnStars_03',
      type: ObjectiveType.earnStars,
      category: ObjectiveCategory.performance,
      description: 'Earn 99 stars',
      target: 99,
      reward: ObjectiveReward(ap: 2),
    );
    const fillerThree = ObjectiveState(
      id: 'weekly_2026-W39_bestShot_03',
      type: ObjectiveType.bestShot,
      category: ObjectiveCategory.performance,
      description: 'Destroy 99 bricks in one shot',
      target: 99,
      reward: ObjectiveReward(ap: 8),
    );
    const weeklyFillers = ObjectiveSetState(
      period: ObjectivePeriod.weekly,
      key: '2026-W39',
      objectives: [fillerOne, fillerTwo, fillerThree],
    );
    final persistence = MemoryPersistence()
      ..progress = const PlayerProgress(
        dailyObjectives: ObjectiveSetState(
          period: ObjectivePeriod.daily,
          key: '2026-09-21',
          objectives: [incomplete, fillerOne, fillerTwo],
        ),
        weeklyObjectives: weeklyFillers,
      );
    final controller = AppController(
      persistence: persistence,
      analytics: const NoopAnalyticsService(),
      clock: () => DateTime(2026, 9, 21, 12),
    );
    await controller.initialize();
    const shot = ShotReport(
      bricksDestroyed: 1,
      stealthDestroyed: 0,
      wallBounceHits: 0,
      specialtiesDestroyed: 0,
    );
    await controller.recordShot(shot);
    expect(controller.progress.dailyObjectives!.objectives.first.completed,
        isTrue);
    expect(controller.progress.achievementPoints, 2);
    await controller.recordShot(shot);
    expect(controller.progress.achievementPoints, 2);

    final reopened = AppController(
      persistence: persistence,
      analytics: const NoopAnalyticsService(),
      clock: () => DateTime(2026, 9, 21, 12),
    );
    await reopened.initialize();
    expect(reopened.progress.dailyObjectives!.objectives.first.rewardGranted,
        isTrue);
    expect(reopened.progress.achievementPoints, 2);
  });

  test('specialty introductions are recorded once and survive restart',
      () async {
    final persistence = MemoryPersistence();
    final controller = AppController(
      persistence: persistence,
      analytics: const NoopAnalyticsService(),
    );
    await controller.initialize();
    final first = await controller.recordSpecialtyIntroductions(
        {BrickSpecialType.bonus, BrickSpecialType.extraShot});
    expect(first.map((value) => value.type),
        [BrickSpecialType.bonus, BrickSpecialType.extraShot]);
    expect(
        await controller.recordSpecialtyIntroductions(
            {BrickSpecialType.bonus, BrickSpecialType.extraShot}),
        isEmpty);

    final reopened = AppController(
      persistence: persistence,
      analytics: const NoopAnalyticsService(),
    );
    await reopened.initialize();
    expect(
        await reopened.recordSpecialtyIntroductions({BrickSpecialType.bonus}),
        isEmpty);
  });

  test('debug unlock uses counters, points, persistence, and tier pipeline',
      () async {
    final persistence = MemoryPersistence();
    final controller = AppController(
        persistence: persistence, analytics: const NoopAnalyticsService());
    await controller.initialize();
    final unlock = await controller.debugUnlockAchievement('totalBricks_2');
    expect(unlock?.tier.id, 'totalBricks_2');
    expect(controller.progress.achievementCounters['totalBricks'], 100);
    expect(controller.progress.completedAchievementTiers,
        containsAll(['totalBricks_1', 'totalBricks_2']));
    expect(controller.progress.achievementPoints, 3);
    expect(persistence.progress.achievementPoints, 3);
  });

  test('one-shot progress unlocks current tier and activates the next',
      () async {
    final controller = AppController(
        persistence: MemoryPersistence(),
        analytics: const NoopAnalyticsService());
    await controller.initialize();
    final unlocks = await controller.recordShot(const ShotReport(
        bricksDestroyed: 8,
        stealthDestroyed: 0,
        wallBounceHits: 0,
        specialtiesDestroyed: 0));
    expect(unlocks.map((u) => u.tier.id),
        containsAll(['brickBarrage_1', 'brickBarrage_2']));
    expect(controller.progress.achievementCounters['brickBarrage'], 8);
  });

  test('Daily Challenge completion is idempotent and streak uses calendar days',
      () async {
    final controller = AppController(
        persistence: MemoryPersistence(),
        analytics: const NoopAnalyticsService());
    await controller.initialize();
    LevelRunReport report(int score) => LevelRunReport(
        level: 8,
        scoreEarned: score,
        originalStartingShots: 4,
        shotsUsed: 3,
        shotsRemaining: 1,
        bricksDestroyed: 10,
        stealthDestroyed: 3,
        bestCombo: 5,
        wallBounceHits: 2,
        specialtiesDestroyed: 1,
        missedShots: 0,
        daily: true);
    await controller.recordLevelComplete(report(100), DateTime(2026, 9, 19));
    await controller.recordLevelComplete(report(150), DateTime(2026, 9, 19));
    expect(controller.progress.dailyChallengesCompleted, 1);
    expect(controller.progress.dailyStreak, 1);
    expect(controller.progress.dailyBestScores['2026-09-19'], 150);
    await controller.recordLevelComplete(report(120), DateTime(2026, 9, 20));
    expect(controller.progress.dailyStreak, 2);
    await controller.recordLevelComplete(report(130), DateTime(2026, 9, 22));
    expect(controller.progress.dailyStreak, 1);
    expect(controller.progress.longestDailyStreak, 2);
  });

  test('power unlock grants consumable charges and level start consumes one',
      () async {
    final persistence = MemoryPersistence()
      ..progress = const PlayerProgress(achievementPoints: 50);
    final controller = AppController(
        persistence: persistence, analytics: const NoopAnalyticsService());
    await controller.initialize();
    expect(await controller.unlockPower(PowerId.scannerPulse), isTrue);
    expect(controller.progress.powerCharges['scannerPulse'], 3);
    await controller.equipPower(PowerId.scannerPulse);
    expect(
        await controller.consumeEquippedPowerForLevel(), PowerId.scannerPulse);
    expect(controller.progress.powerCharges['scannerPulse'], 2);
    final reopened = AppController(
        persistence: persistence, analytics: const NoopAnalyticsService());
    await reopened.initialize();
    expect(reopened.progress.powerCharges['scannerPulse'], 2);
  });

  test('normal completion and first mastery award unlocked power charges',
      () async {
    final persistence = MemoryPersistence()
      ..progress = const PlayerProgress(
          unlockedPowers: {'scannerPulse'}, powerCharges: {'scannerPulse': 0});
    final controller = AppController(
        persistence: persistence,
        analytics: const NoopAnalyticsService(),
        rewardRandom: FixedRandom(0));
    await controller.initialize();
    final first = await controller.recordLevelComplete(
        normalReport(), DateTime(2026, 9, 19));
    expect(
        first.chargeAwards.map((award) => award.source),
        containsAll([
          PowerChargeAwardSource.levelCompletion,
          PowerChargeAwardSource.mastery,
        ]));
    final replay = await controller.recordLevelComplete(
        normalReport(), DateTime(2026, 9, 19));
    expect(
        replay.chargeAwards
            .where((award) => award.source == PowerChargeAwardSource.mastery),
        isEmpty);
  });

  test('daily and streak charge rewards are once per completion record',
      () async {
    final persistence = MemoryPersistence()
      ..progress = const PlayerProgress(
          unlockedPowers: {'scannerPulse'}, powerCharges: {'scannerPulse': 0});
    final controller = AppController(
        persistence: persistence,
        analytics: const NoopAnalyticsService(),
        rewardRandom: FixedRandom(1));
    await controller.initialize();
    final first = await controller.recordLevelComplete(
        dailyReport(), DateTime(2026, 9, 19));
    expect(
        first.chargeAwards.where(
            (award) => award.source == PowerChargeAwardSource.dailyChallenge),
        hasLength(1));
    final replay = await controller.recordLevelComplete(
        dailyReport(), DateTime(2026, 9, 19));
    expect(
        replay.chargeAwards.where(
            (award) => award.source == PowerChargeAwardSource.dailyChallenge),
        isEmpty);
    await controller.recordLevelComplete(dailyReport(), DateTime(2026, 9, 20));
    final third = await controller.recordLevelComplete(
        dailyReport(), DateTime(2026, 9, 21));
    final streak = third.chargeAwards
        .singleWhere((award) => award.source == PowerChargeAwardSource.streak);
    expect(streak.amount, 1);
  });

  test('achievement charge reward is once per tier and never targets locks',
      () async {
    final lockedController = AppController(
        persistence: MemoryPersistence(),
        analytics: const NoopAnalyticsService(),
        rewardRandom: FixedRandom(0));
    await lockedController.initialize();
    final locked =
        await lockedController.debugUnlockAchievement('totalBricks_1');
    expect(locked?.chargeAward, isNull);

    final persistence = MemoryPersistence()
      ..progress = const PlayerProgress(
          unlockedPowers: {'scannerPulse'}, powerCharges: {'scannerPulse': 0});
    final controller = AppController(
        persistence: persistence,
        analytics: const NoopAnalyticsService(),
        rewardRandom: FixedRandom(0));
    await controller.initialize();
    final unlock = await controller.debugUnlockAchievement('totalBricks_1');
    expect(unlock?.chargeAward?.amount, 1);
    expect(await controller.debugUnlockAchievement('totalBricks_1'), isNull);
    expect(controller.progress.powerCharges['scannerPulse'], 1);
  });

  test('no-power objective tracks activation, not specialty effects or equip',
      () async {
    const noPower = ObjectiveState(
      id: 'daily_2026-09-21_completeLevelsWithoutPower_01',
      type: ObjectiveType.completeLevelsWithoutPower,
      category: ObjectiveCategory.completion,
      description: 'Complete 4 levels without a power',
      target: 4,
      reward: ObjectiveReward(ap: 2),
    );
    const filler = ObjectiveState(
      id: 'filler',
      type: ObjectiveType.destroyBricks,
      category: ObjectiveCategory.destruction,
      description: 'Destroy 999 bricks',
      target: 999,
      reward: ObjectiveReward(ap: 1),
    );
    const fillerTwo = ObjectiveState(
      id: 'filler_two',
      type: ObjectiveType.bestShot,
      category: ObjectiveCategory.performance,
      description: 'Hit 999 bricks',
      target: 999,
      reward: ObjectiveReward(ap: 1),
    );
    final persistence = MemoryPersistence()
      ..progress = const PlayerProgress(
        unlockedPowers: {'scannerPulse'},
        equippedPower: 'scannerPulse',
        powerCharges: {'scannerPulse': 5},
        dailyObjectives: ObjectiveSetState(
          period: ObjectivePeriod.daily,
          key: '2026-09-21',
          objectives: [noPower, filler, fillerTwo],
        ),
        weeklyObjectives: ObjectiveSetState(
          period: ObjectivePeriod.weekly,
          key: '2026-W39',
          objectives: [filler, fillerTwo, noPower],
        ),
      );
    final controller = AppController(
      persistence: persistence,
      analytics: const NoopAnalyticsService(),
      clock: () => DateTime(2026, 9, 21, 12),
      rewardRandom: FixedRandom(1),
    );
    await controller.initialize();

    LevelRunReport report({required bool powerUsed}) => LevelRunReport(
          level: 1,
          scoreEarned: 100,
          originalStartingShots: 10,
          shotsUsed: 8,
          shotsRemaining: 2,
          bricksDestroyed: 8,
          stealthDestroyed: 1,
          bestCombo: 3,
          wallBounceHits: 0,
          specialtiesDestroyed: 5,
          missedShots: 0,
          daily: false,
          powerUsed: powerUsed,
        );

    await controller.recordLevelComplete(
        report(powerUsed: false), DateTime(2026, 9, 21));
    expect(controller.progress.dailyObjectives!.objectives.first.progress, 1,
        reason: 'equipped but unused powers and specialty bricks still qualify');
    await controller.recordLevelComplete(
        report(powerUsed: true), DateTime(2026, 9, 21));
    expect(controller.progress.dailyObjectives!.objectives.first.progress, 1,
        reason: 'an activated player power invalidates the completion');
  });
}
