import 'package:flutter_test/flutter_test.dart';
import 'package:stealth_breaker/app/app_controller.dart';
import 'package:stealth_breaker/models/game_result.dart';
import 'package:stealth_breaker/models/game_settings.dart';
import 'package:stealth_breaker/models/player_progress.dart';
import 'package:stealth_breaker/models/power.dart';
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

void main() {
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
    expect(controller.progress.powerCharges['scannerPulse'], 5);
    await controller.equipPower(PowerId.scannerPulse);
    expect(
        await controller.consumeEquippedPowerForLevel(), PowerId.scannerPulse);
    expect(controller.progress.powerCharges['scannerPulse'], 4);
    final reopened = AppController(
        persistence: persistence, analytics: const NoopAnalyticsService());
    await reopened.initialize();
    expect(reopened.progress.powerCharges['scannerPulse'], 4);
  });
}
