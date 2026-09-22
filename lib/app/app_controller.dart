import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../config/game_balance.dart';
import '../config/build_config.dart';
import '../game/level/level_generator.dart';
import '../game/systems/star_rating.dart';
import '../models/achievement.dart';
import '../models/brick.dart';
import '../models/game_result.dart';
import '../models/game_settings.dart';
import '../models/player_progress.dart';
import '../models/power.dart';
import '../models/power_charge_award.dart';
import '../models/objective.dart';
import '../models/specialty_brick_info.dart';
import '../services/analytics_service.dart';
import '../services/achievement_service.dart';
import '../services/audio_service.dart';
import '../services/daily_challenge_service.dart';
import '../services/haptics_service.dart';
import '../services/inventory_service.dart';
import '../services/monetization_services.dart';
import '../services/objective_service.dart';
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
      ObjectiveService? objectives,
      ProgressionEventBus? events,
      Random? rewardRandom,
      DateTime Function()? clock,
      bool developerModeAvailableForTesting = false})
      : entitlements = entitlements ?? LocalEntitlementService(),
        audio = audio ?? const NoopAudioService(),
        haptics = haptics ?? NoopHapticsService(),
        achievements = achievements ?? const AchievementService(),
        inventory = inventory ?? const InventoryService(),
        dailyChallenges = dailyChallenges ?? const DailyChallengeService(),
        objectiveService = objectives ?? const ObjectiveService(),
        events = events ?? ProgressionEventBus(),
        _rewardRandom = rewardRandom ?? Random(),
        _clock = clock ?? DateTime.now,
        _developerModeAvailableForTesting = developerModeAvailableForTesting;

  final PersistenceService persistence;
  final AnalyticsService analytics;
  final AudioService audio;
  final HapticsService haptics;
  final EntitlementService entitlements;
  final AchievementService achievements;
  final InventoryService inventory;
  final DailyChallengeService dailyChallenges;
  final ObjectiveService objectiveService;
  final ProgressionEventBus events;
  final Random _rewardRandom;
  final DateTime Function() _clock;
  final bool _developerModeAvailableForTesting;
  final List<ObjectiveCompletionNotice> _objectiveNotices = [];
  DateTime? _debugClockOverride;
  PlayerProgress progress = const PlayerProgress();
  GameSettings settings = const GameSettings();
  bool ready = false;
  bool developerMode = false;

  DeveloperStatePersistenceService? get _developerPersistence =>
      persistence is DeveloperStatePersistenceService
          ? persistence as DeveloperStatePersistenceService
          : null;

  bool get supportsDeveloperMode =>
      (BuildConfig.privateTestingBuild || _developerModeAvailableForTesting) &&
      _developerPersistence != null;
  DateTime get realNow => _clock();
  DateTime get effectiveNow =>
      developerMode ? (_debugClockOverride ?? realNow) : realNow;
  DateTime? get debugClockOverride => _debugClockOverride;
  Duration get debugClockOffset => effectiveNow.difference(realNow);
  String get effectiveDateKey => dateKey(effectiveNow);
  String get effectiveWeekKey => weekKey(effectiveNow);
  int get effectiveDailyChallengeSeed =>
      LevelGenerator.seedForDate(effectiveNow);

  int get completedAchievementCount =>
      progress.completedAchievementTiers.length;
  int get totalAchievementTiers => AchievementCatalog.allTiers.length;

  Future<void> initialize() async {
    final developerPersistence = _developerPersistence;
    if (developerPersistence != null) {
      await developerPersistence.initializeDeveloperState();
      developerMode =
          supportsDeveloperMode && developerPersistence.developerMode;
      if (developerMode) {
        _debugClockOverride =
            await developerPersistence.loadDebugClockOverride();
      }
    }
    progress = await persistence.loadProgress();
    settings = await persistence.loadSettings();
    _migrateProgress();
    haptics.enabled = settings.haptics;
    await audio.initialize(settings);
    analytics.sessionStart();
    _ensureObjectivesCurrent(effectiveNow);
    await persistence.saveProgress(progress);
    ready = true;
    notifyListeners();
  }

  void _migrateProgress() {
    if (progress.saveVersion < 3) {
      final charges = Map<String, int>.from(progress.powerCharges);
      for (final power in PowerId.values) {
        if (progress.unlockedPowers.contains(power.storageId) &&
            !charges.containsKey(power.storageId)) {
          charges[power.storageId] =
              GameBalance.initialPowerCharges[power] ?? 0;
        }
      }
      progress = progress.copyWith(powerCharges: charges);
    }
    if (progress.saveVersion < 4) {
      progress = progress.copyWith(saveVersion: 4);
    }
  }

  Future<void> updateSettings(GameSettings value) async {
    settings = value;
    haptics.enabled = value.haptics;
    await audio.applySettings(value);
    await persistence.saveSettings(settings);
    notifyListeners();
  }

  Future<void> setDeveloperMode(bool enabled) async {
    final developerPersistence = _developerPersistence;
    if (!supportsDeveloperMode || developerPersistence == null) return;
    if (developerMode == enabled) return;
    await persistence.saveProgress(progress);
    await developerPersistence.setDeveloperMode(enabled);
    developerMode = enabled;
    _debugClockOverride =
        enabled ? await developerPersistence.loadDebugClockOverride() : null;
    progress = await persistence.loadProgress();
    _migrateProgress();
    _ensureObjectivesCurrent(effectiveNow);
    await persistence.saveProgress(progress);
    notifyListeners();
  }

  Future<void> setDebugClock(DateTime? value) async {
    if (!developerMode || !supportsDeveloperMode) return;
    _debugClockOverride = value;
    await _developerPersistence?.saveDebugClockOverride(value);
    _ensureObjectivesCurrent(effectiveNow);
    await _save();
  }

  Future<void> shiftDebugClock(Duration amount) async {
    await setDebugClock(effectiveNow.add(amount));
  }

  Future<void> debugSetObjectiveProgress(
      ObjectivePeriod period, int index, int value) async {
    if (!developerMode) return;
    _ensureObjectivesCurrent(effectiveNow);
    final set = period == ObjectivePeriod.daily
        ? progress.dailyObjectives!
        : progress.weeklyObjectives!;
    if (index < 0 || index >= set.objectives.length) return;
    final objectives = List<ObjectiveState>.from(set.objectives);
    final current = objectives[index];
    final nextProgress = max(0, value);
    final newlyCompleted = nextProgress >= current.target && !current.completed;
    final next = current.copyWith(
      progress: nextProgress,
      completed: current.completed || newlyCompleted,
      rewardGranted: current.rewardGranted || newlyCompleted,
      completedAtKey:
          newlyCompleted ? effectiveDateKey : current.completedAtKey,
    );
    objectives[index] = next;
    _replaceObjectiveSet(period, set.copyWith(objectives: objectives));
    if (newlyCompleted) _grantObjectiveCompletion(period, next);
    await _save();
  }

  Future<void> debugResetObjective(ObjectivePeriod period, int index) async {
    if (!developerMode) return;
    _ensureObjectivesCurrent(effectiveNow);
    final set = period == ObjectivePeriod.daily
        ? progress.dailyObjectives!
        : progress.weeklyObjectives!;
    if (index < 0 || index >= set.objectives.length) return;
    final objectives = List<ObjectiveState>.from(set.objectives);
    final current = objectives[index];
    objectives[index] = ObjectiveState(
      id: current.id,
      type: current.type,
      category: current.category,
      description: current.description,
      target: current.target,
      qualifier: current.qualifier,
      reward: current.reward,
    );
    _replaceObjectiveSet(period, set.copyWith(objectives: objectives));
    await _save();
  }

  Future<void> debugResetObjectiveSet(ObjectivePeriod period) async {
    if (!developerMode) return;
    _ensureObjectivesCurrent(effectiveNow);
    final set = period == ObjectivePeriod.daily
        ? progress.dailyObjectives!
        : progress.weeklyObjectives!;
    final reset = set.copyWith(
      objectives: set.objectives
          .map((current) => ObjectiveState(
                id: current.id,
                type: current.type,
                category: current.category,
                description: current.description,
                target: current.target,
                qualifier: current.qualifier,
                reward: current.reward,
              ))
          .toList(growable: false),
    );
    _replaceObjectiveSet(period, reset);
    await _save();
  }

  Future<void> debugRegenerateObjectives(ObjectivePeriod period) async {
    if (!developerMode) return;
    final key =
        period == ObjectivePeriod.daily ? effectiveDateKey : effectiveWeekKey;
    final generated = objectiveService.generate(
      period: period,
      key: key,
      context: ObjectiveService.contextFor(progress, effectiveNow),
    );
    _replaceObjectiveSet(period, generated);
    await _save();
  }

  void _replaceObjectiveSet(ObjectivePeriod period, ObjectiveSetState value) {
    progress = period == ObjectivePeriod.daily
        ? progress.copyWith(dailyObjectives: value)
        : progress.copyWith(weeklyObjectives: value);
  }

  Future<DailyChallengeCompletion> debugCompleteDailyChallenge(
      {int score = 1000}) async {
    final result = dailyChallenges.complete(
      progress: progress,
      challengeDate: effectiveNow,
      score: max(0, score),
    );
    progress = result.progress;
    if (result.firstCompletion) {
      _processProgressionEvent(ProgressionEvent(
        ProgressionEventType.dailyChallengeCompleted,
        {'date': effectiveDateKey, 'streak': result.currentStreak},
      ));
      _grantRandomUnlockedCharge(
        GameBalance.dailyChargeReward,
        PowerChargeAwardSource.dailyChallenge,
      );
      if (result.streakRewardClaimed) {
        _grantRandomUnlockedCharge(
          GameBalance.streakChargeRewards[result.currentStreak] ?? 0,
          PowerChargeAwardSource.streak,
        );
      }
    }
    final counters = Map<String, int>.from(progress.achievementCounters)
      ..[AchievementFamilyId.dailyChallenger.name] =
          progress.dailyChallengesCompleted
      ..[AchievementFamilyId.dailyStreak.name] = progress.dailyStreak;
    progress = progress.copyWith(achievementCounters: counters);
    _evaluateAchievements();
    await _save();
    return result;
  }

  Future<void> debugClearDailyChallenge({bool clearBestScore = true}) async {
    if (!developerMode) return;
    final bests = Map<String, int>.from(progress.dailyBestScores);
    if (clearBestScore) bests.remove(effectiveDateKey);
    final wasCurrent = progress.lastDailyCompleted == effectiveDateKey;
    progress = progress.copyWith(
      dailyBestScores: bests,
      dailyChallengesCompleted: wasCurrent
          ? max(0, progress.dailyChallengesCompleted - 1)
          : progress.dailyChallengesCompleted,
      dailyStreak: wasCurrent ? 0 : progress.dailyStreak,
      clearLastDailyCompleted: wasCurrent,
    );
    await _save();
  }

  Future<void> debugSetDailyBestScore(int? score) async {
    if (!developerMode) return;
    final bests = Map<String, int>.from(progress.dailyBestScores);
    if (score == null) {
      bests.remove(effectiveDateKey);
    } else {
      bests[effectiveDateKey] = max(0, score);
    }
    progress = progress.copyWith(dailyBestScores: bests);
    await _save();
  }

  Future<void> debugSetStreak({int? current, int? longest}) async {
    if (!developerMode) return;
    final nextCurrent = max(0, current ?? progress.dailyStreak);
    progress = progress.copyWith(
      dailyStreak: nextCurrent,
      longestDailyStreak:
          max(nextCurrent, max(0, longest ?? progress.longestDailyStreak)),
    );
    await _save();
  }

  Future<void> debugClearLastDailyCompletion() async {
    if (!developerMode) return;
    progress = progress.copyWith(clearLastDailyCompleted: true);
    await _save();
  }

  Future<void> debugUnlockPower(PowerId power) async {
    if (!developerMode) return;
    final unlocked = Set<String>.from(progress.unlockedPowers)
      ..add(power.storageId);
    final charges = Map<String, int>.from(progress.powerCharges);
    charges.putIfAbsent(power.storageId, () => 0);
    progress = progress.copyWith(
      unlockedPowers: unlocked,
      powerCharges: charges,
    );
    await _save();
  }

  Future<void> debugSetPowerCharges(PowerId power, int value) async {
    if (!developerMode) return;
    final charges = Map<String, int>.from(progress.powerCharges)
      ..[power.storageId] = max(0, value);
    progress = progress.copyWith(powerCharges: charges);
    await _save();
  }

  Future<void> debugResetPowerInventory() async {
    if (!developerMode) return;
    progress = progress.copyWith(
      unlockedPowers: {},
      powerCharges: {},
      clearEquippedPower: true,
    );
    await _save();
  }

  Future<List<AchievementUnlock>> debugSetAchievementValue(
      AchievementFamilyId family, int value) async {
    if (!developerMode) return const [];
    final current = progress.achievementCounters[family.name] ?? 0;
    if (value >= current) {
      final counters = Map<String, int>.from(progress.achievementCounters)
        ..[family.name] = max(0, value);
      progress = progress.copyWith(achievementCounters: counters);
      final unlocks = _evaluateAchievements();
      await _save();
      return unlocks;
    }
    final counters = Map<String, int>.from(progress.achievementCounters)
      ..[family.name] = max(0, value);
    progress = progress.copyWith(achievementCounters: counters);
    await _save();
    return const [];
  }

  Future<void> debugResetAchievementFamily(AchievementFamilyId family) async {
    if (!developerMode) return;
    final counters = Map<String, int>.from(progress.achievementCounters)
      ..[family.name] = 0;
    final completed = Set<String>.from(progress.completedAchievementTiers);
    var pointsToRemove = 0;
    for (final tier in AchievementCatalog.family(family).tiers) {
      if (completed.remove(tier.id)) pointsToRemove += tier.points;
    }
    progress = progress.copyWith(
      achievementCounters: counters,
      completedAchievementTiers: completed,
      achievementPoints: max(0, progress.achievementPoints - pointsToRemove),
    );
    await _save();
  }

  Future<void> debugSetProgressStat(String key, int value) async {
    if (!developerMode) return;
    final safe = max(0, value);
    progress = switch (key) {
      'highestLevel' => progress.copyWith(highestLevel: max(1, safe)),
      'totalStars' => progress.copyWith(totalStars: safe),
      'achievementPoints' => progress.copyWith(achievementPoints: safe),
      'totalBricksDestroyed' => progress.copyWith(totalBricksDestroyed: safe),
      'stealthBricksDestroyed' =>
        progress.copyWith(stealthBricksDestroyed: safe),
      'specialtyBricksDestroyed' =>
        progress.copyWith(specialtyBricksDestroyed: safe),
      'highestOneShot' => progress.copyWith(highestOneShot: safe),
      'dailyChallengesCompleted' =>
        progress.copyWith(dailyChallengesCompleted: safe),
      _ => progress,
    };
    await _save();
  }

  Future<void> debugResetProgressionStats() async {
    if (!developerMode) return;
    progress = progress.copyWith(
      highestLevel: 1,
      highScore: 0,
      totalScore: 0,
      totalBricksDestroyed: 0,
      stealthBricksDestroyed: 0,
      specialtyBricksDestroyed: 0,
      levelsCompleted: 0,
      highestOneShot: 0,
      fewestShotsUsed: 0,
      levelStars: {},
      totalStars: 0,
      wallBounceHits: 0,
      efficientLevels: 0,
    );
    await _save();
  }

  Future<void> debugResetDailyChallengeState() async {
    if (!developerMode) return;
    progress = progress.copyWith(
      dailyChallengesCompleted: 0,
      dailyStreak: 0,
      longestDailyStreak: 0,
      clearLastDailyCompleted: true,
      dailyBestScores: {},
      claimedStreakRewards: {},
    );
    await _save();
  }

  String exportDebugState() => const JsonEncoder.withIndent('  ').convert({
        'build': 'private-testing',
        'developerMode': developerMode,
        'realDateTime': realNow.toIso8601String(),
        'effectiveDateTime': effectiveNow.toIso8601String(),
        'debugClockOverride': _debugClockOverride?.toIso8601String(),
        'dailyChallengeSeed': effectiveDailyChallengeSeed,
        'saveSchemaVersion': progress.saveVersion,
        'progress': progress.toJson(),
      });

  Future<void> resetAllDebugState() async {
    final developerPersistence = _developerPersistence;
    if (!developerMode || developerPersistence == null) return;
    await developerPersistence.clearDebugProgress();
    _debugClockOverride = null;
    progress = const PlayerProgress();
    _ensureObjectivesCurrent(effectiveNow);
    await persistence.saveProgress(progress);
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
    _processProgressionEvent(ProgressionEvent(
      ProgressionEventType.shotCompleted,
      {
        'bricksDestroyed': shot.bricksDestroyed,
        'stealthDestroyed': shot.stealthDestroyed,
        'specialtiesDestroyed': shot.specialtiesDestroyed,
      },
    ));
    final unlocks = _evaluateAchievements();
    await _save();
    analytics.shotSummary({
      'bricksDestroyed': shot.bricksDestroyed,
      'stealthDestroyed': shot.stealthDestroyed,
      'specialtiesDestroyed': shot.specialtiesDestroyed,
      'wallBounceHits': shot.wallBounceHits,
    });
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

    final stars = report.daily
        ? 0
        : StarRating.calculate(
            levelCleared: true,
            originalStartingShots: report.originalStartingShots,
            shotsUsed: report.shotsUsed,
          );
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
    _processProgressionEvent(ProgressionEvent(
      ProgressionEventType.levelCompleted,
      {
        'daily': report.daily,
        'stars': stars,
        'starsEarned': max(0, stars - oldStars),
        'newThreeStar': stars == 3 && oldStars < 3,
        'shotsUsed': report.shotsUsed,
        'playerPowerActivated': report.powerUsed,
      },
    ));
    if (dailyResult?.firstCompletion == true) {
      _processProgressionEvent(ProgressionEvent(
        ProgressionEventType.dailyChallengeCompleted,
        {'date': dateKey(challengeDate), 'streak': streak},
      ));
    }
    final beforePoints = progress.achievementPoints;
    final unlocks = _evaluateAchievements();
    final chargeAwards = <PowerChargeAward>[
      ...unlocks
          .map((unlock) => unlock.chargeAward)
          .whereType<PowerChargeAward>(),
    ];
    if (report.daily) {
      if (dailyResult!.firstCompletion) {
        final award = _grantRandomUnlockedCharge(
          GameBalance.dailyChargeReward,
          PowerChargeAwardSource.dailyChallenge,
        );
        if (award != null) chargeAwards.add(award);
      }
      if (dailyResult.streakRewardClaimed) {
        final award = _grantRandomUnlockedCharge(
          GameBalance.streakChargeRewards[streak] ?? 0,
          PowerChargeAwardSource.streak,
        );
        if (award != null) chargeAwards.add(award);
      }
    } else {
      if (_rewardRandom.nextDouble() < GameBalance.normalLevelChargeChance) {
        final award = _grantRandomUnlockedCharge(
          1,
          PowerChargeAwardSource.levelCompletion,
        );
        if (award != null) chargeAwards.add(award);
      }
      if (stars == 3 && oldStars < 3) {
        final award = _grantRandomUnlockedCharge(
          GameBalance.masteryChargeReward,
          PowerChargeAwardSource.mastery,
        );
        if (award != null) chargeAwards.add(award);
      }
    }
    await _save();
    analytics.levelComplete(report.level, report.scoreEarned,
        daily: report.daily);
    if (report.daily) {
      if (dailyResult!.firstCompletion) {
        analytics.dailyComplete(dateKey(challengeDate), streak);
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
        chargeAwards: List.unmodifiable(chargeAwards),
        dailyFirstCompletion: dailyResult?.firstCompletion ?? false,
        streakChanged: dailyResult?.streakChanged ?? false);
  }

  List<AchievementUnlock> _evaluateAchievements() {
    final pointsBefore = progress.achievementPoints;
    final evaluation = achievements.evaluate(progress);
    progress = evaluation.progress;
    final unlocks = <AchievementUnlock>[];
    for (final unlock in evaluation.unlocks) {
      final chargeAward = _grantRandomUnlockedCharge(
        GameBalance.achievementChargeReward(unlock.tier),
        PowerChargeAwardSource.achievement,
      );
      final rewardedUnlock = AchievementUnlock(
        unlock.tier,
        chargeAward: chargeAward,
      );
      unlocks.add(rewardedUnlock);
      analytics.achievementComplete(unlock.tier.id, unlock.tier.points);
      events.emit(ProgressionEvent(ProgressionEventType.achievementCompleted,
          {'id': unlock.tier.id, 'points': unlock.tier.points}));
    }
    final pointsGranted = progress.achievementPoints - pointsBefore;
    if (pointsGranted > 0) {
      _processProgressionEvent(ProgressionEvent(
        ProgressionEventType.achievementPointsGranted,
        {'amount': pointsGranted},
      ));
    }
    return List.unmodifiable(unlocks);
  }

  PowerChargeAward? _grantRandomUnlockedCharge(
    int amount,
    PowerChargeAwardSource source,
  ) {
    if (amount <= 0) return null;
    final eligible = PowerId.values.where(isPowerUnlocked).toList();
    if (eligible.isEmpty) return null;
    final power = eligible[_rewardRandom.nextInt(eligible.length)];
    final grant = inventory.grant(
      progress.powerCharges,
      power.storageId,
      amount,
    );
    progress = progress.copyWith(powerCharges: grant.inventory);
    return PowerChargeAward(power: power, amount: amount, source: source);
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
    _processProgressionEvent(ProgressionEvent(
      ProgressionEventType.powerUpConsumed,
      {'id': id, 'remaining': change.remaining},
    ));
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
    if (amount > 0) {
      _processProgressionEvent(ProgressionEvent(
        ProgressionEventType.achievementPointsGranted,
        {'amount': amount},
      ));
    }
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
    _ensureObjectivesCurrent(effectiveNow);
    final completions =
        <({ObjectivePeriod period, ObjectiveState objective})>[];
    ObjectiveSetState complete(ObjectiveSetState set) => set.copyWith(
          objectives: set.objectives.map((objective) {
            if (objective.completed) return objective;
            final completed = objective.copyWith(
              progress: objective.target,
              completed: true,
              rewardGranted: true,
              completedAtKey: effectiveDateKey,
            );
            completions.add((period: set.period, objective: completed));
            return completed;
          }).toList(growable: false),
        );
    progress = progress.copyWith(
      dailyObjectives: complete(progress.dailyObjectives!),
      weeklyObjectives: complete(progress.weeklyObjectives!),
    );
    for (final completion in completions) {
      _grantObjectiveCompletion(completion.period, completion.objective);
    }
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
        dailyStreak: 0, clearLastDailyCompleted: true, dailyBestScores: {});
    await _save();
  }

  Future<List<SpecialtyBrickInfo>> recordSpecialtyIntroductions(
      Iterable<BrickSpecialType> types) async {
    final seen = Set<String>.from(progress.seenSpecialtyTutorials);
    final available = types.toSet();
    final introductions = SpecialtyBrickCatalog.all
        .where((info) =>
            available.contains(info.type) && !seen.contains(info.type.name))
        .toList(growable: false);
    if (introductions.isEmpty) return const [];
    seen.addAll(introductions.map((info) => info.type.name));
    progress = progress.copyWith(seenSpecialtyTutorials: seen);
    await _save();
    return introductions;
  }

  List<ObjectiveCompletionNotice> takeObjectiveNotices() {
    final values = List<ObjectiveCompletionNotice>.from(_objectiveNotices);
    _objectiveNotices.clear();
    return List.unmodifiable(values);
  }

  Future<void> clearAllData() async {
    await persistence.clear();
    progress = const PlayerProgress();
    settings = const GameSettings();
    notifyListeners();
  }

  Future<void> refreshObjectives(DateTime now) async {
    if (_ensureObjectivesCurrent(now)) await _save();
  }

  bool _ensureObjectivesCurrent(DateTime now) {
    final day = dateKey(now);
    final week = weekKey(now);
    final context = ObjectiveService.contextFor(progress, now);
    final daily = progress.dailyObjectives?.key == day &&
            progress.dailyObjectives?.objectives.length ==
                GameBalance.dailyObjectiveCount
        ? progress.dailyObjectives!
        : objectiveService.generate(
            period: ObjectivePeriod.daily, key: day, context: context);
    final weekly = progress.weeklyObjectives?.key == week &&
            progress.weeklyObjectives?.objectives.length == 3
        ? progress.weeklyObjectives!
        : objectiveService.generate(
            period: ObjectivePeriod.weekly, key: week, context: context);
    final changed = !identical(daily, progress.dailyObjectives) ||
        !identical(weekly, progress.weeklyObjectives);
    if (changed) {
      progress = progress.copyWith(
        dailyObjectives: daily,
        weeklyObjectives: weekly,
      );
    }
    return changed;
  }

  void _processProgressionEvent(ProgressionEvent event) {
    final now = effectiveNow;
    _ensureObjectivesCurrent(now);
    final evaluation = objectiveService.applyEvent(
      daily: progress.dailyObjectives!,
      weekly: progress.weeklyObjectives!,
      event: event,
      completionKey: dateKey(now),
    );
    progress = progress.copyWith(
      dailyObjectives: evaluation.daily,
      weeklyObjectives: evaluation.weekly,
    );
    events.emit(event);
    for (final completion in evaluation.completions) {
      _grantObjectiveCompletion(completion.period, completion.objective);
    }
  }

  void _grantObjectiveCompletion(
      ObjectivePeriod period, ObjectiveState objective) {
    progress = progress.copyWith(
      achievementPoints: progress.achievementPoints + objective.reward.ap,
    );
    final chargeAward = _grantRandomUnlockedCharge(
      objective.reward.powerCharges,
      period == ObjectivePeriod.daily
          ? PowerChargeAwardSource.dailyObjective
          : PowerChargeAwardSource.weeklyObjective,
    );
    _objectiveNotices.add(ObjectiveCompletionNotice(
      period: period,
      objective: objective,
      chargeLabel: chargeAward?.label,
    ));
    analytics.event('objectiveCompleted', {
      'id': objective.id,
      'period': period.name,
      'ap': objective.reward.ap,
    });
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
