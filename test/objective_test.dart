import 'package:flutter_test/flutter_test.dart';
import 'package:stealth_breaker/config/objective_balance.dart';
import 'package:stealth_breaker/game/level/level_generator.dart';
import 'package:stealth_breaker/models/objective.dart';
import 'package:stealth_breaker/services/objective_service.dart';
import 'package:stealth_breaker/services/progression_event_bus.dart';

void main() {
  const service = ObjectiveService();

  ObjectiveGenerationContext context({
    int level = 1,
    int unlockedPowers = 0,
    int charges = 0,
    int remainingDays = 7,
  }) =>
      ObjectiveGenerationContext(
        highestLevel: level,
        unlockedPowerCount: unlockedPowers,
        availablePowerCharges: charges,
        dailyChallengeAvailable: true,
        remainingWeekDays: remainingDays,
      );

  test('daily objectives are stable, distinct, and exactly three', () {
    final first = service.generate(
      period: ObjectivePeriod.daily,
      key: '2026-09-21',
      context: context(),
    );
    final second = service.generate(
      period: ObjectivePeriod.daily,
      key: '2026-09-21',
      context: context(),
    );
    expect(first.objectives, hasLength(3));
    expect(first.objectives.map((value) => value.id),
        second.objectives.map((value) => value.id));
    expect(first.objectives.map((value) => value.type).toSet(), hasLength(3));
    expect(first.objectives.every((value) => value.id.startsWith('daily_2026-09-21_')),
        isTrue);
  });

  test('weekly objectives are stable and larger than daily basics', () {
    final daily = service.generate(
      period: ObjectivePeriod.daily,
      key: '2026-09-21',
      context: context(),
    );
    final weekly = service.generate(
      period: ObjectivePeriod.weekly,
      key: '2026-W39',
      context: context(),
    );
    expect(weekly.objectives, hasLength(3));
    expect(weekly.objectives.map((value) => value.id).toSet(), hasLength(3));
    final dailyBricks = daily.objectives
        .where((value) => value.type == ObjectiveType.destroyBricks);
    final weeklyBricks = weekly.objectives
        .where((value) => value.type == ObjectiveType.destroyBricks);
    if (dailyBricks.isNotEmpty && weeklyBricks.isNotEmpty) {
      expect(weeklyBricks.single.target, greaterThan(dailyBricks.single.target));
    }
  });

  test('early progression filters specialties and locked powers', () {
    for (var day = 1; day <= 20; day++) {
      final set = service.generate(
        period: ObjectivePeriod.daily,
        key: '2026-09-${day.toString().padLeft(2, '0')}',
        context: context(level: 1),
      );
      expect(set.objectives.map((value) => value.type),
          isNot(contains(ObjectiveType.destroySpecialtyBricks)));
      expect(set.objectives.map((value) => value.type),
          isNot(contains(ObjectiveType.usePowerUps)));
    }
  });

  test('progression bands raise configured targets without changing generation',
      () {
    expect(ObjectiveBalance.bandForLevel(1), ObjectiveProgressionBand.early);
    expect(ObjectiveBalance.bandForLevel(18), ObjectiveProgressionBand.mid);
    expect(ObjectiveBalance.bandForLevel(30), ObjectiveProgressionBand.late);
    expect(ObjectiveBalance.dailyBrickTargets[ObjectiveProgressionBand.early],
        lessThan(ObjectiveBalance
            .dailyBrickTargets[ObjectiveProgressionBand.late]!));

    final before = LevelGenerator.generate(level: 28, seed: 7788);
    service.generate(
      period: ObjectivePeriod.daily,
      key: 'generation-is-read-only',
      context: context(level: 28),
    );
    final after = LevelGenerator.generate(level: 28, seed: 7788);
    expect(after.specialtyCount, before.specialtyCount);
    expect(after.bricks.map((value) => value.specialType),
        before.bricks.map((value) => value.specialType));
  });

  test('specialty targets stay within conservative sampled opportunities', () {
    var found = false;
    for (var index = 0; index < 60; index++) {
      final key = 'specialty-safe-$index';
      final set = service.generate(
        period: ObjectivePeriod.daily,
        key: key,
        context: context(level: 28),
      );
      final opportunities = service.conservativeSpecialtyOpportunities(
        key: key,
        startingLevel: 28,
        levelCount: ObjectiveBalance.dailyExpectedLevels[
            ObjectiveProgressionBand.late]!,
      );
      for (final objective in set.objectives) {
        if (objective.type == ObjectiveType.destroySpecialtyBricks) {
          found = true;
          expect(objective.target, lessThanOrEqualTo(opportunities));
        }
      }
    }
    expect(found, isTrue);
  });

  test('power objectives never exceed currently available charges', () {
    var found = false;
    for (var day = 1; day <= 40; day++) {
      final set = service.generate(
        period: ObjectivePeriod.daily,
        key: 'power-key-$day',
        context: context(level: 18, unlockedPowers: 1, charges: 1),
      );
      for (final objective in set.objectives) {
        if (objective.type == ObjectiveType.usePowerUps) {
          found = true;
          expect(objective.target, lessThanOrEqualTo(1));
        }
      }
    }
    expect(found, isTrue);
  });

  test('weekly Daily Challenge target respects remaining days', () {
    var found = false;
    for (var index = 0; index < 40; index++) {
      final set = service.generate(
        period: ObjectivePeriod.weekly,
        key: 'late-week-$index',
        context: context(level: 18, remainingDays: 2),
      );
      for (final objective in set.objectives) {
        if (objective.type == ObjectiveType.completeDailyChallenges) {
          found = true;
          expect(objective.target, lessThanOrEqualTo(2));
        }
      }
    }
    expect(found, isTrue);
  });

  test('fallback objectives fill invalid specialized pools', () {
    final set = service.generate(
      period: ObjectivePeriod.daily,
      key: 'fallback',
      context: const ObjectiveGenerationContext(
        highestLevel: 1,
        unlockedPowerCount: 0,
        availablePowerCharges: 0,
        dailyChallengeAvailable: false,
        remainingWeekDays: 1,
      ),
    );
    expect(set.objectives, hasLength(3));
    expect(
      set.objectives.every((value) => const {
            ObjectiveType.destroyBricks,
            ObjectiveType.destroyStealthBricks,
            ObjectiveType.completeLevels,
            ObjectiveType.earnStars,
            ObjectiveType.bestShot,
            ObjectiveType.efficientLevels,
            ObjectiveType.completeLevelsWithoutPower,
          }.contains(value.type)),
      isTrue,
    );
  });

  test('event completion is immediate and reward is returned once', () {
    const dailyObjective = ObjectiveState(
      id: 'daily_test_destroyBricks_01',
      type: ObjectiveType.destroyBricks,
      category: ObjectiveCategory.destruction,
      description: 'Destroy 5 bricks',
      target: 5,
      reward: ObjectiveReward(ap: 2),
    );
    const weeklyObjective = ObjectiveState(
      id: 'weekly_test_destroyBricks_01',
      type: ObjectiveType.destroyBricks,
      category: ObjectiveCategory.destruction,
      description: 'Destroy 50 bricks',
      target: 50,
      reward: ObjectiveReward(ap: 8),
    );
    const daily = ObjectiveSetState(
      period: ObjectivePeriod.daily,
      key: '2026-09-21',
      objectives: [dailyObjective],
    );
    const weekly = ObjectiveSetState(
      period: ObjectivePeriod.weekly,
      key: '2026-W39',
      objectives: [weeklyObjective],
    );
    const event = ProgressionEvent(
      ProgressionEventType.shotCompleted,
      {'bricksDestroyed': 6},
    );
    final first = service.applyEvent(
      daily: daily,
      weekly: weekly,
      event: event,
      completionKey: '2026-09-21',
    );
    expect(first.daily.objectives.single.completed, isTrue);
    expect(first.daily.objectives.single.rewardGranted, isTrue);
    expect(first.completions, hasLength(1));

    final replay = service.applyEvent(
      daily: first.daily,
      weekly: first.weekly,
      event: event,
      completionKey: '2026-09-21',
    );
    expect(replay.completions, isEmpty);
  });
}
