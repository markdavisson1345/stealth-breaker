import 'dart:math';

import 'package:flutter/foundation.dart';

import '../config/game_balance.dart';
import '../models/achievement.dart';
import '../models/game_result.dart';
import '../models/game_settings.dart';
import '../models/player_progress.dart';
import '../models/power.dart';
import '../models/objective.dart';
import '../services/analytics_service.dart';
import '../services/achievement_service.dart';
import '../services/audio_service.dart';
import '../services/daily_challenge_service.dart';
import '../services/haptics_service.dart';
import '../services/inventory_service.dart';
import '../services/monetization_services.dart';
import '../services/persistence_service.dart';
import '../services/progression_event_bus.dart';

class AppController extends ChangeNotifier {
  AppController(
      {required this.persistence,
      required this.analytics,
      AudioService? audio,
      HapticsService? haptics,
      EntitlementService? entitlements,
      AchievementService? achievements,
      InventoryService? inventory,
      DailyChallengeService? dailyChallenges,
      ProgressionEventBus? events})
      : entitlements = entitlements ?? LocalEntitlementService(),
        audio = audio ?? const NoopAudioService(),
        haptics = haptics ?? NoopHapticsService(),
        achievements = achievements ?? const AchievementService(),
        inventory = inventory ?? const InventoryService(),
        dailyChallenges = dailyChallenges ?? const DailyChallengeService(),
        events = events ?? ProgressionEventBus();

  final PersistenceService persistence;
  final AnalyticsService analytics;
  final AudioService audio;
  final HapticsService haptics;
  final EntitlementService entitlements;
  final AchievementService achievements;
  final InventoryService inventory;
  final DailyChallengeService dailyChallenges;
  final ProgressionEventBus events;
  PlayerProgress progress = const PlayerProgress();
  GameSettings settings = const GameSettings();
  bool ready = false;

  int get completedAchievementCount =>
      progress.completedAchievementTiers.length;
  int get totalAchievementTiers => AchievementCatalog.allTiers.length;

  Future<void> initialize() async {
    progress = await persistence.loadProgress();
    settings = await persistence.loadSettings();
    if (progress.saveVersion < 3) {
      var charges = Map<String, int>.from(progress.powerCharges);
      for (final power in PowerId.values) {
        if (progress.unlockedPowers.contains(power.storageId) &&
            !charges.containsKey(power.storageId)) {
          charges[power.storageId] =
              GameBalance.initialPowerCharges[power] ?? 0;
        }
      }
      progress = progress.copyWith(saveVersion: 3, powerCharges: charges);
      await persistence.saveProgress(progress);
    }
    haptics.enabled = settings.haptics;
    await audio.initialize(settings);
    analytics.sessionStart();
    await _refreshObjectives(DateTime.now());
    ready = true;
    notifyListeners();
  }

  Future<void> updateSettings(GameSettings value) async {
    settings = value;
    haptics.enabled = value.haptics;
    await audio.applySettings(value);
    await persistence.saveSettings(settings);
    notifyListeners();
  }

  Future<List<AchievementUnlock>> recordShot(ShotReport shot) async {
    final counters = Map<String, int>.from(progress.achievementCounters);
    counters[AchievementFamilyId.brickBarrage.name] = max(
        counters[AchievementFamilyId.brickBarrage.name] ?? 0,
        shot.bricksDestroyed);
    final totalBricks = progress.totalBricksDestroyed + shot.bricksDestroyed;
    final stealth = progress.stealthBricksDestroyed + shot.stealthDestroyed;
    final bounces = progress.wallBounceHits + shot.wallBounceHits;
    counters[AchievementFamilyId.totalBricks.name] = totalBricks;
    counters[AchievementFamilyId.stealthHunter.name] = stealth;
    counters[AchievementFamilyId.ricochetMaster.name] = bounces;
    progress = progress.copyWith(
      totalBricksDestroyed: totalBricks,
      stealthBricksDestroyed: stealth,
      wallBounceHits: bounces,
      specialtyBricksDestroyed:
          progress.specialtyBricksDestroyed + shot.specialtiesDestroyed,
      highestOneShot: max(progress.highestOneShot, shot.bricksDestroyed),
      achievementCounters: counters,
    );
    _applyObjectiveProgress(
        bricks: shot.bricksDestroyed, stealth: shot.stealthDestroyed);
    final unlocks = _evaluateAchievements();
    await _save();
    analytics.shotSummary({
      'bricksDestroyed': shot.bricksDestroyed,
      'stealthDestroyed': shot.stealthDestroyed,
      'specialtiesDestroyed': shot.specialtiesDestroyed,
      'wallBounceHits': shot.wallBounceHits,
    });
    events.emit(ProgressionEvent(ProgressionEventType.shotCompleted, {
      'bricksDestroyed': shot.bricksDestroyed,
      'stealthDestroyed': shot.stealthDestroyed,
      'specialtiesDestroyed': shot.specialtiesDestroyed,
    }));
    return unlocks;
  }

  Future<LevelCompletionResult> recordLevelComplete(
      LevelRunReport report, DateTime challengeDate) async {
    DailyChallengeCompletion? dailyResult;
    if (report.daily) {
      dailyResult = dailyChallenges.complete(
        progress: progress,
        challengeDate: challengeDate,
        score: report.scoreEarned,
      );
      progress = dailyResult.progress;
    }
    final streak = progress.dailyStreak;
    final dailyCompleted = progress.dailyChallengesCompleted;

    final stars = report.daily ? 0 : _starsFor(report);
    final starsByLevel = Map<String, int>.from(progress.levelStars);
    final oldStars = starsByLevel['${report.level}'] ?? 0;
    if (!report.daily && stars > oldStars) {
      starsByLevel['${report.level}'] = stars;
    }
    final levelsCompleted = progress.levelsCompleted + (report.daily ? 0 : 1);
    final efficient = progress.efficientLevels +
        (!report.daily && report.shotsRemaining > 0 ? 1 : 0);
    final counters = Map<String, int>.from(progress.achievementCounters)
      ..[AchievementFamilyId.levelMaster.name] = levelsCompleted
      ..[AchievementFamilyId.dailyChallenger.name] = dailyCompleted
      ..[AchievementFamilyId.dailyStreak.name] = streak
      ..[AchievementFamilyId.efficientBreaker.name] = efficient;
    final newTotalScore = progress.totalScore + report.scoreEarned;
    final newHigh = max(progress.highScore, report.scoreEarned);
    final personalBest = newHigh > progress.highScore ||
        report.bestCombo > progress.highestOneShot;
    final fewest = report.daily
        ? progress.fewestShotsUsed
        : (progress.fewestShotsUsed == 0
            ? report.shotsUsed
            : min(progress.fewestShotsUsed, report.shotsUsed));
    progress = progress.copyWith(
      highestLevel: report.daily
          ? progress.highestLevel
          : max(progress.highestLevel, report.level + 1),
      highScore: newHigh,
      totalScore: newTotalScore,
      levelsCompleted: levelsCompleted,
      achievementCounters: counters,
      efficientLevels: efficient,
      levelStars: starsByLevel,
      totalStars: starsByLevel.values.fold<int>(0, (sum, value) => sum + value),
      fewestShotsUsed: fewest,
    );
    _applyObjectiveProgress(
        levels: report.daily ? 0 : 1,
        stars: max(0, stars - oldStars),
        dailyChallenges: dailyResult?.firstCompletion == true ? 1 : 0,
        efficient: report.shotsRemaining >= 2 ? 1 : 0);
    final beforePoints = progress.achievementPoints;
    final unlocks = _evaluateAchievements();
    await _save();
    analytics.levelComplete(report.level, report.scoreEarned,
        daily: report.daily);
    if (report.daily) {
      if (dailyResult!.firstCompletion) {
        analytics.dailyComplete(dateKey(challengeDate), streak);
        events.emit(ProgressionEvent(
            ProgressionEventType.dailyChallengeCompleted,
            {'date': dateKey(challengeDate), 'streak': streak}));
      } else {
        analytics.dailyReplay(dateKey(challengeDate));
      }
      if (dailyResult.streakChanged) {
        analytics.streakChange(dailyResult.previousStreak, streak);
      }
    }
    for (var i = 0; i < max(0, stars - oldStars); i++) {
      analytics.event(
          'starEarned', {'level': report.level, 'star': oldStars + i + 1});
    }
    return LevelCompletionResult(
        report: report,
        stars: stars,
        newStars: max(0, stars - oldStars),
        unlocks: unlocks,
        pointsEarned: progress.achievementPoints - beforePoints,
        personalBest: personalBest,
        dailyFirstCompletion: dailyResult?.firstCompletion ?? false,
        streakChanged: dailyResult?.streakChanged ?? false);
  }

  int _starsFor(LevelRunReport report) {
    var stars = 1;
    if (report.shotsUsed <=
        max(1, report.shotsUsed + report.shotsRemaining - 2)) {
      stars = 2;
    }
    final mastery = switch (report.level % 4) {
      0 => report.shotsRemaining >= 3,
      1 => report.missedShots == 0,
      2 => report.stealthDestroyed >= 4,
      _ => report.scoreEarned >= 2500,
    };
    if (mastery) stars = 3;
    return stars;
  }

  List<AchievementUnlock> _evaluateAchievements() {
    final evaluation = achievements.evaluate(progress);
    progress = evaluation.progress;
    for (final unlock in evaluation.unlocks) {
      analytics.achievementComplete(unlock.tier.id, unlock.tier.points);
      events.emit(ProgressionEvent(ProgressionEventType.achievementCompleted,
          {'id': unlock.tier.id, 'points': unlock.tier.points}));
    }
    return evaluation.unlocks;
  }

  Future<AchievementUnlock?> debugUnlockAchievement(String tierId) async {
    final tier = AchievementCatalog.tierById(tierId);
    if (tier == null) return null;
    final counters = Map<String, int>.from(progress.achievementCounters);
    counters[tier.family.name] =
        max(counters[tier.family.name] ?? 0, tier.threshold);
    progress = progress.copyWith(achievementCounters: counters);
    final unlocks = _evaluateAchievements();
    await _save();
    for (final unlock in unlocks) {
      if (unlock.tier.id == tierId) return unlock;
    }
    return null;
  }

  Future<bool> unlockPower(PowerId power) async {
    final cost = GameBalance.powerCosts[power] ?? 0;
    if (isPowerUnlocked(power) || progress.achievementPoints < cost) {
      return false;
    }
    final unlocked = Set<String>.from(progress.unlockedPowers)
      ..add(power.storageId);
    final grant = inventory.grant(progress.powerCharges, power.storageId,
        GameBalance.initialPowerCharges[power] ?? 0);
    progress = progress.copyWith(
        unlockedPowers: unlocked,
        powerCharges: grant.inventory,
        achievementPoints: progress.achievementPoints - cost);
    await entitlements.setEntitlement('power_${power.storageId}', true);
    analytics.powerUnlock(power.storageId);
    await _save();
    return true;
  }

  bool isPowerUnlocked(PowerId power) =>
      progress.isPowerUnlocked(power) ||
      entitlements.hasEntitlement('power_${power.storageId}');

  Future<void> equipPower(PowerId? power) async {
    if (power != null &&
        (!isPowerUnlocked(power) ||
            (progress.powerCharges[power.storageId] ?? 0) <= 0)) {
      return;
    }
    progress = progress.copyWith(
        equippedPower: power?.storageId, clearEquippedPower: power == null);
    await _save();
  }

  Future<PowerId?> consumeEquippedPowerForLevel() async {
    final id = progress.equippedPower;
    if (id == null) return null;
    final power = PowerId.values.where((p) => p.storageId == id).firstOrNull;
    if (power == null) return null;
    final change = inventory.consume(progress.powerCharges, id);
    if (!change.changed) return null;
    progress = progress.copyWith(
      powerCharges: change.inventory,
      clearEquippedPower: change.remaining == 0,
    );
    analytics.powerUse(id);
    events.emit(ProgressionEvent(ProgressionEventType.powerUpConsumed,
        {'id': id, 'remaining': change.remaining}));
    await _save();
    return power;
  }

  Future<int> grantPowerCharges(PowerId power, int amount, {int? cap}) async {
    final change = inventory
        .grant(progress.powerCharges, power.storageId, amount, cap: cap);
    if (change.changed) {
      progress = progress.copyWith(powerCharges: change.inventory);
      await _save();
    }
    return change.remaining;
  }

  Future<void> addAchievementPoints(int amount) async {
    progress = progress.copyWith(
        achievementPoints: max(0, progress.achievementPoints + amount));
    await _save();
  }

  Future<List<AchievementUnlock>> debugSetAchievementCounter(
      AchievementFamilyId family, int value) async {
    final evaluation = achievements.setCounter(progress, family, max(0, value));
    progress = evaluation.progress;
    await _save();
    return evaluation.unlocks;
  }

  Future<void> debugCompleteObjectives() async {
    final date = progress.dailyObjectiveDate ?? dateKey(DateTime.now());
    final values = Map<String, int>.from(progress.dailyObjectiveProgress);
    for (final objective in ObjectiveCatalog.dailyFor(date)) {
      values[objective.id] = objective.target;
    }
    progress = progress.copyWith(
        dailyObjectiveProgress: values,
        weeklyObjectiveProgress: ObjectiveCatalog.weekly.target);
    await _save();
  }

  Future<void> debugForceStars(int level, int stars) async {
    final map = Map<String, int>.from(progress.levelStars);
    map['$level'] = max(map['$level'] ?? 0, stars.clamp(0, 3));
    progress = progress.copyWith(
        levelStars: map,
        totalStars: map.values.fold<int>(0, (sum, value) => sum + value));
    await _save();
  }

  Future<bool> claimDailyObjective(ObjectiveDefinition objective) async {
    final value = progress.dailyObjectiveProgress[objective.id] ?? 0;
    if (value < objective.target ||
        progress.claimedDailyObjectives.contains(objective.id)) {
      return false;
    }
    final claimed = Set<String>.from(progress.claimedDailyObjectives)
      ..add(objective.id);
    progress = progress.copyWith(
        claimedDailyObjectives: claimed,
        achievementPoints: progress.achievementPoints + objective.rewardPoints);
    analytics.event('dailyObjectiveCompleted', {'id': objective.id});
    await _save();
    return true;
  }

  Future<bool> claimWeeklyObjective() async {
    const objective = ObjectiveCatalog.weekly;
    if (progress.weeklyObjectiveProgress < objective.target ||
        progress.weeklyObjectiveClaimed) {
      return false;
    }
    progress = progress.copyWith(
        weeklyObjectiveClaimed: true,
        achievementPoints: progress.achievementPoints + objective.rewardPoints,
        streakSaves: min(GameBalance.maxStreakSaves, progress.streakSaves + 1));
    analytics.event('weeklyObjectiveCompleted');
    await _save();
    return true;
  }

  Future<void> setTutorialComplete(bool value) async {
    progress = progress.copyWith(tutorialComplete: value);
    await _save();
  }

  Future<void> recordGameOver(int runScore) async {
    if (runScore > progress.highScore) {
      progress = progress.copyWith(highScore: runScore);
      await _save();
    }
  }

  Future<void> resetAchievements() async {
    progress = progress.copyWith(
        achievementCounters: {},
        completedAchievementTiers: {},
        achievementPoints: 0);
    await _save();
  }

  Future<void> resetDaily() async {
    progress = progress.copyWith(
        dailyStreak: 0,
        clearLastDailyCompleted: true,
        dailyBestScores: {},
        dailyObjectiveProgress: {},
        claimedDailyObjectives: {});
    await _save();
  }

  Future<void> clearAllData() async {
    await persistence.clear();
    progress = const PlayerProgress();
    settings = const GameSettings();
    notifyListeners();
  }

  Future<void> _refreshObjectives(DateTime now) async {
    final day = dateKey(now);
    final week = weekKey(now);
    if (progress.dailyObjectiveDate != day ||
        progress.weeklyObjectiveKey != week) {
      progress = progress.copyWith(
        dailyObjectiveDate: day,
        dailyObjectiveProgress: progress.dailyObjectiveDate == day
            ? progress.dailyObjectiveProgress
            : {},
        claimedDailyObjectives: progress.dailyObjectiveDate == day
            ? progress.claimedDailyObjectives
            : {},
        weeklyObjectiveKey: week,
        weeklyObjectiveProgress: progress.weeklyObjectiveKey == week
            ? progress.weeklyObjectiveProgress
            : 0,
        weeklyObjectiveClaimed: progress.weeklyObjectiveKey == week &&
            progress.weeklyObjectiveClaimed,
      );
      await persistence.saveProgress(progress);
    }
  }

  void _applyObjectiveProgress(
      {int bricks = 0,
      int stealth = 0,
      int levels = 0,
      int stars = 0,
      int dailyChallenges = 0,
      int efficient = 0}) {
    final map = Map<String, int>.from(progress.dailyObjectiveProgress);
    map['bricks'] = (map['bricks'] ?? 0) + bricks;
    map['stealth'] = (map['stealth'] ?? 0) + stealth;
    map['levels'] = (map['levels'] ?? 0) + levels;
    map['efficient'] = (map['efficient'] ?? 0) + efficient;
    progress = progress.copyWith(
        dailyObjectiveProgress: map,
        weeklyObjectiveProgress:
            progress.weeklyObjectiveProgress + stars + dailyChallenges * 3);
  }

  Future<void> _save() async {
    await persistence.saveProgress(progress);
    notifyListeners();
  }

  static String dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  static String weekKey(DateTime date) {
    final thursday = date.add(Duration(days: 4 - date.weekday));
    final first = DateTime(thursday.year, 1, 1);
    final week = 1 + thursday.difference(first).inDays ~/ 7;
    return '${thursday.year}-W${week.toString().padLeft(2, '0')}';
  }
}
