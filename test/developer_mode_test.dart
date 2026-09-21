import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:stealth_breaker/app/app_controller.dart';
import 'package:stealth_breaker/models/achievement.dart';
import 'package:stealth_breaker/models/objective.dart';
import 'package:stealth_breaker/models/player_progress.dart';
import 'package:stealth_breaker/models/power.dart';
import 'package:stealth_breaker/services/analytics_service.dart';

import 'support/developer_test_persistence.dart';

AppController _controller(
  MemoryDeveloperPersistence persistence,
  DateTime Function() clock,
) =>
    AppController(
      persistence: persistence,
      analytics: const NoopAnalyticsService(),
      clock: clock,
      developerModeAvailableForTesting: true,
    );

void main() {
  test('private normal and debug progression remain isolated', () async {
    final persistence = MemoryDeveloperPersistence(
      normal: const PlayerProgress(highestLevel: 6, totalStars: 9),
    );
    final controller =
        _controller(persistence, () => DateTime(2026, 9, 21, 10));
    await controller.initialize();
    expect(controller.progress.highestLevel, 6);

    await controller.setDeveloperMode(true);
    expect(controller.progress.highestLevel, 1);
    await controller.debugSetProgressStat('highestLevel', 40);
    await controller.debugSetProgressStat('totalStars', 88);

    await controller.setDeveloperMode(false);
    expect(controller.progress.highestLevel, 6);
    expect(controller.progress.totalStars, 9);

    await controller.setDeveloperMode(true);
    expect(controller.progress.highestLevel, 40);
    expect(controller.progress.totalStars, 88);

    await controller.resetAllDebugState();
    expect(controller.progress.highestLevel, 1);
    await controller.setDeveloperMode(false);
    expect(controller.progress.highestLevel, 6);
    expect(controller.progress.totalStars, 9);
  });

  test('debug clock supports shifts, explicit dates, persistence, and reset',
      () async {
    final real = DateTime(2026, 9, 21, 10, 30);
    final persistence = MemoryDeveloperPersistence();
    final controller = _controller(persistence, () => real);
    await controller.initialize();
    await controller.setDeveloperMode(true);

    await controller.shiftDebugClock(const Duration(days: 1));
    expect(controller.effectiveDateKey, '2026-09-22');
    await controller.shiftDebugClock(const Duration(days: -1));
    expect(controller.effectiveDateKey, '2026-09-21');
    await controller.shiftDebugClock(const Duration(days: 7));
    expect(controller.effectiveWeekKey, '2026-W40');
    await controller.setDebugClock(DateTime(2027, 1, 5, 8));
    expect(controller.effectiveDateKey, '2027-01-05');

    final reopened = _controller(persistence, () => real);
    await reopened.initialize();
    expect(reopened.developerMode, isTrue);
    expect(reopened.effectiveDateKey, '2027-01-05');
    await reopened.setDebugClock(null);
    expect(reopened.effectiveNow, real);
  });

  test('objective controls use stored objective state and grant once',
      () async {
    final persistence = MemoryDeveloperPersistence();
    final controller =
        _controller(persistence, () => DateTime(2026, 9, 21, 12));
    await controller.initialize();
    await controller.setDeveloperMode(true);
    final objective = controller.progress.dailyObjectives!.objectives.first;
    final pointsBefore = controller.progress.achievementPoints;

    await controller.debugSetObjectiveProgress(
        ObjectivePeriod.daily, 0, objective.target);
    expect(controller.progress.dailyObjectives!.objectives.first.completed,
        isTrue);
    expect(controller.progress.achievementPoints,
        pointsBefore + objective.reward.ap);
    await controller.debugSetObjectiveProgress(
        ObjectivePeriod.daily, 0, objective.target + 5);
    expect(controller.progress.achievementPoints,
        pointsBefore + objective.reward.ap);

    final ids = controller.progress.dailyObjectives!.objectives
        .map((value) => value.id)
        .toList();
    await controller.debugResetObjectiveSet(ObjectivePeriod.daily);
    expect(controller.progress.dailyObjectives!.objectives.first.progress, 0);
    expect(controller.progress.dailyObjectives!.objectives.map((value) => value.id),
        ids);
    await controller.shiftDebugClock(const Duration(days: 1));
    expect(controller.progress.dailyObjectives!.key, '2026-09-22');
    await controller.shiftDebugClock(const Duration(days: 7));
    expect(controller.progress.weeklyObjectives!.key, '2026-W40');
  });

  test('Daily Challenge and streak controls follow production calendar rules',
      () async {
    final persistence = MemoryDeveloperPersistence();
    final controller =
        _controller(persistence, () => DateTime(2026, 9, 21, 12));
    await controller.initialize();
    await controller.setDeveloperMode(true);

    await controller.debugCompleteDailyChallenge(score: 100);
    expect(controller.progress.dailyStreak, 1);
    expect(controller.progress.dailyChallengesCompleted, 1);
    await controller.debugCompleteDailyChallenge(score: 150);
    expect(controller.progress.dailyStreak, 1);
    expect(controller.progress.dailyChallengesCompleted, 1);
    expect(controller.progress.dailyBestScores['2026-09-21'], 150);

    await controller.shiftDebugClock(const Duration(days: 1));
    await controller.debugCompleteDailyChallenge();
    expect(controller.progress.dailyStreak, 2);
    await controller.shiftDebugClock(const Duration(days: 2));
    await controller.debugCompleteDailyChallenge();
    expect(controller.progress.dailyStreak, 1);
    expect(controller.progress.longestDailyStreak, 2);

    await controller.debugClearDailyChallenge();
    expect(controller.progress.lastDailyCompleted, isNull);
  });

  test('power, achievement, export, and debug reset use debug save only',
      () async {
    final persistence = MemoryDeveloperPersistence(
      normal: const PlayerProgress(highestLevel: 4),
    );
    final controller =
        _controller(persistence, () => DateTime(2026, 9, 21, 12));
    await controller.initialize();
    await controller.setDeveloperMode(true);

    await controller.debugUnlockPower(PowerId.scannerPulse);
    await controller.debugSetPowerCharges(PowerId.scannerPulse, 5);
    await controller.debugSetPowerCharges(PowerId.scannerPulse, -1);
    expect(controller.progress.powerCharges['scannerPulse'], 0);
    await controller.debugSetPowerCharges(PowerId.scannerPulse, 5);

    const family = AchievementFamilyId.totalBricks;
    final tier = AchievementCatalog.family(family).tiers.first;
    final first = await controller.debugSetAchievementValue(
        family, tier.threshold);
    expect(first, hasLength(1));
    final duplicate = await controller.debugSetAchievementValue(
        family, tier.threshold);
    expect(duplicate, isEmpty);

    final exported =
        jsonDecode(controller.exportDebugState()) as Map<String, dynamic>;
    expect(exported['build'], 'private-testing');
    expect(exported['progress'], isA<Map>());
    expect(controller.exportDebugState(), isNot(contains('password')));
    expect(controller.exportDebugState(), isNot(contains('token')));

    await controller.resetAllDebugState();
    expect(controller.progress.powerCharges, isEmpty);
    expect(controller.progress.completedAchievementTiers, isEmpty);
    await controller.setDeveloperMode(false);
    expect(controller.progress.highestLevel, 4);
  });
}
