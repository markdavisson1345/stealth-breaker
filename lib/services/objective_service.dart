import 'dart:math';

import '../config/objective_balance.dart';
import '../game/level/level_generator.dart';
import '../models/objective.dart';
import '../models/player_progress.dart';
import 'progression_event_bus.dart';

class ObjectiveGenerationContext {
  const ObjectiveGenerationContext({
    required this.highestLevel,
    required this.unlockedPowerCount,
    required this.availablePowerCharges,
    required this.dailyChallengeAvailable,
    required this.remainingWeekDays,
  });

  final int highestLevel;
  final int unlockedPowerCount;
  final int availablePowerCharges;
  final bool dailyChallengeAvailable;
  final int remainingWeekDays;
}

class ObjectiveEvaluation {
  const ObjectiveEvaluation({
    required this.daily,
    required this.weekly,
    required this.completions,
  });

  final ObjectiveSetState daily;
  final ObjectiveSetState weekly;
  final List<({ObjectivePeriod period, ObjectiveState objective})> completions;
}

class ObjectiveService {
  const ObjectiveService();

  ObjectiveSetState generate({
    required ObjectivePeriod period,
    required String key,
    required ObjectiveGenerationContext context,
  }) {
    final band = ObjectiveBalance.bandForLevel(context.highestLevel);
    final expectedLevels = ObjectiveBalance.target(
      period == ObjectivePeriod.daily
          ? ObjectiveBalance.dailyExpectedLevels
          : ObjectiveBalance.weeklyExpectedLevels,
      band,
    );
    final specialtyOpportunities = _conservativeOpportunities(
      key: key,
      startingLevel: context.highestLevel,
      levelCount: expectedLevels,
      metric: _OpportunityMetric.specialty,
    );
    final stealthOpportunities = _conservativeOpportunities(
      key: key,
      startingLevel: context.highestLevel,
      levelCount: expectedLevels,
      metric: _OpportunityMetric.stealth,
    );
    final brickOpportunities = _conservativeOpportunities(
      key: key,
      startingLevel: context.highestLevel,
      levelCount: expectedLevels,
      metric: _OpportunityMetric.bricks,
    );
    final candidates = _candidates(
      period: period,
      band: band,
      context: context,
      specialtyOpportunities: specialtyOpportunities,
      stealthOpportunities: stealthOpportunities,
      brickOpportunities: brickOpportunities,
    );
    final random = Random(_stableHash('${period.name}:$key'));
    candidates.shuffle(random);

    final selected = <_Candidate>[];
    final usedCategories = <ObjectiveCategory>{};
    for (final candidate in candidates) {
      if (selected.length == 3) break;
      if (usedCategories.add(candidate.category)) selected.add(candidate);
    }
    for (final candidate in candidates) {
      if (selected.length == 3) break;
      if (!selected.any((value) => value.type == candidate.type)) {
        selected.add(candidate);
      }
    }

    // Universal candidates always make this reachable, even when every
    // progression-gated mechanic is unavailable.
    final objectives = <ObjectiveState>[];
    for (var index = 0; index < selected.length; index++) {
      final candidate = selected[index];
      objectives.add(ObjectiveState(
        id: '${period.name}_${key}_${candidate.type.name}_${(index + 1).toString().padLeft(2, '0')}',
        type: candidate.type,
        category: candidate.category,
        description: candidate.description,
        target: candidate.target,
        qualifier: candidate.qualifier,
        reward: ObjectiveBalance.rewardFor(
          period: period,
          band: band,
          hasUnlockedPower: context.unlockedPowerCount > 0,
          slot: index,
        ),
      ));
    }
    return ObjectiveSetState(
      period: period,
      key: key,
      objectives: List.unmodifiable(objectives),
    );
  }

  ObjectiveEvaluation applyEvent({
    required ObjectiveSetState daily,
    required ObjectiveSetState weekly,
    required ProgressionEvent event,
    required String completionKey,
  }) {
    final completions =
        <({ObjectivePeriod period, ObjectiveState objective})>[];
    var updatedDaily = _applyToSet(
      daily,
      event,
      completionKey,
      (objective) => completions.add(
          (period: ObjectivePeriod.daily, objective: objective)),
    );
    var updatedWeekly = _applyToSet(
      weekly,
      event,
      completionKey,
      (objective) => completions.add(
          (period: ObjectivePeriod.weekly, objective: objective)),
    );

    final dailyCompletions = completions
        .where((value) => value.period == ObjectivePeriod.daily)
        .length;
    if (dailyCompletions > 0) {
      updatedWeekly = _applyToSet(
        updatedWeekly,
        ProgressionEvent(ProgressionEventType.dailyObjectiveCompleted,
            {'count': dailyCompletions}),
        completionKey,
        (objective) => completions.add(
            (period: ObjectivePeriod.weekly, objective: objective)),
      );
    }
    return ObjectiveEvaluation(
      daily: updatedDaily,
      weekly: updatedWeekly,
      completions: List.unmodifiable(completions),
    );
  }

  ObjectiveSetState _applyToSet(
    ObjectiveSetState set,
    ProgressionEvent event,
    String completionKey,
    void Function(ObjectiveState objective) onComplete,
  ) {
    var changed = false;
    final values = set.objectives.map((objective) {
      if (objective.completed) return objective;
      final nextProgress = _progressFor(objective, event);
      if (nextProgress == objective.progress) return objective;
      changed = true;
      if (nextProgress < objective.target) {
        return objective.copyWith(progress: nextProgress);
      }
      final completed = objective.copyWith(
        progress: nextProgress,
        completed: true,
        rewardGranted: true,
        completedAtKey: completionKey,
      );
      onComplete(completed);
      return completed;
    }).toList(growable: false);
    return changed ? set.copyWith(objectives: List.unmodifiable(values)) : set;
  }

  int _progressFor(ObjectiveState objective, ProgressionEvent event) {
    final data = event.data;
    int amount(String key, [int fallback = 0]) =>
        (data[key] as num?)?.toInt() ?? fallback;
    switch (objective.type) {
      case ObjectiveType.destroyBricks:
        return event.type == ProgressionEventType.shotCompleted
            ? objective.progress + amount('bricksDestroyed')
            : objective.progress;
      case ObjectiveType.destroyStealthBricks:
        return event.type == ProgressionEventType.shotCompleted
            ? objective.progress + amount('stealthDestroyed')
            : objective.progress;
      case ObjectiveType.destroySpecialtyBricks:
        return event.type == ProgressionEventType.shotCompleted
            ? objective.progress + amount('specialtiesDestroyed')
            : objective.progress;
      case ObjectiveType.bestShot:
        return event.type == ProgressionEventType.shotCompleted
            ? max(objective.progress, amount('bricksDestroyed'))
            : objective.progress;
      case ObjectiveType.highValueShots:
        return event.type == ProgressionEventType.shotCompleted &&
                amount('bricksDestroyed') >= objective.qualifier
            ? objective.progress + 1
            : objective.progress;
      case ObjectiveType.completeLevels:
        return event.type == ProgressionEventType.levelCompleted &&
                data['daily'] != true
            ? objective.progress + 1
            : objective.progress;
      case ObjectiveType.earnStars:
        return event.type == ProgressionEventType.levelCompleted
            ? objective.progress + amount('starsEarned')
            : objective.progress;
      case ObjectiveType.efficientLevels:
        return event.type == ProgressionEventType.levelCompleted &&
                data['daily'] != true &&
                amount('shotsUsed', 999) <= objective.qualifier
            ? objective.progress + 1
            : objective.progress;
      case ObjectiveType.completeLevelsWithoutPower:
        return event.type == ProgressionEventType.levelCompleted &&
                data['daily'] != true &&
                data['powerUsed'] != true
            ? objective.progress + 1
            : objective.progress;
      case ObjectiveType.threeStarCompletions:
        return event.type == ProgressionEventType.levelCompleted &&
                amount('stars') >= 3
            ? objective.progress + 1
            : objective.progress;
      case ObjectiveType.completeDailyChallenges:
        return event.type == ProgressionEventType.dailyChallengeCompleted
            ? objective.progress + 1
            : objective.progress;
      case ObjectiveType.usePowerUps:
        return event.type == ProgressionEventType.powerUpConsumed
            ? objective.progress + 1
            : objective.progress;
      case ObjectiveType.completeDailyObjectives:
        return event.type == ProgressionEventType.dailyObjectiveCompleted
            ? objective.progress + amount('count', 1)
            : objective.progress;
      case ObjectiveType.earnAchievementPoints:
        return event.type == ProgressionEventType.achievementPointsGranted
            ? objective.progress + amount('amount')
            : objective.progress;
    }
  }

  List<_Candidate> _candidates({
    required ObjectivePeriod period,
    required ObjectiveProgressionBand band,
    required ObjectiveGenerationContext context,
    required int specialtyOpportunities,
    required int stealthOpportunities,
    required int brickOpportunities,
  }) {
    final daily = period == ObjectivePeriod.daily;
    final levelTarget = ObjectiveBalance.target(
      daily
          ? ObjectiveBalance.dailyLevelTargets
          : ObjectiveBalance.weeklyLevelTargets,
      band,
    );
    final configuredBrickTarget = ObjectiveBalance.target(
      daily
          ? ObjectiveBalance.dailyBrickTargets
          : ObjectiveBalance.weeklyBrickTargets,
      band,
    );
    final brickTarget = max(1, min(configuredBrickTarget, brickOpportunities));
    final starTarget = ObjectiveBalance.target(
      daily
          ? ObjectiveBalance.dailyStarTargets
          : ObjectiveBalance.weeklyStarTargets,
      band,
    );
    final bestShot = ObjectiveBalance.target(ObjectiveBalance.bestShotTargets, band);
    final efficientLimit =
        ObjectiveBalance.target(ObjectiveBalance.efficientShotLimits, band);
    final candidates = <_Candidate>[
      _Candidate(ObjectiveType.destroyBricks, ObjectiveCategory.destruction,
          'Destroy $brickTarget bricks', brickTarget),
      _Candidate(ObjectiveType.completeLevels, ObjectiveCategory.completion,
          'Complete $levelTarget levels', levelTarget),
      _Candidate(ObjectiveType.earnStars, ObjectiveCategory.performance,
          'Earn $starTarget stars', starTarget),
      _Candidate(
        ObjectiveType.completeLevelsWithoutPower,
        ObjectiveCategory.completion,
        'Complete ${daily ? 1 : max(3, levelTarget ~/ 2)} levels without a power',
        daily ? 1 : max(3, levelTarget ~/ 2),
      ),
      _Candidate(
        ObjectiveType.efficientLevels,
        ObjectiveCategory.performance,
        'Complete ${daily ? 1 : 3} level${daily ? '' : 's'} in $efficientLimit shots or fewer',
        daily ? 1 : 3,
        qualifier: efficientLimit,
      ),
    ];
    if (daily) {
      candidates.add(_Candidate(
        ObjectiveType.bestShot,
        ObjectiveCategory.performance,
        'Destroy $bestShot bricks in one shot',
        bestShot,
      ));
    }

    if (stealthOpportunities > 0) {
      final configured = switch ((daily, band)) {
        (true, ObjectiveProgressionBand.early) => 4,
        (true, ObjectiveProgressionBand.mid) => 8,
        (true, ObjectiveProgressionBand.late) => 12,
        (false, ObjectiveProgressionBand.early) => 20,
        (false, ObjectiveProgressionBand.mid) => 35,
        (false, ObjectiveProgressionBand.late) => 55,
      };
      final target = min(configured, stealthOpportunities);
      if (target > 0) {
        candidates.add(_Candidate(
          ObjectiveType.destroyStealthBricks,
          ObjectiveCategory.destruction,
          'Destroy $target stealth bricks',
          target,
        ));
      }
    }
    if (specialtyOpportunities > 0) {
      final configured = daily ? 3 : 10;
      final target = min(configured, specialtyOpportunities);
      if (target > 0) {
        candidates.add(_Candidate(
          ObjectiveType.destroySpecialtyBricks,
          ObjectiveCategory.destruction,
          'Destroy $target specialty brick${target == 1 ? '' : 's'}',
          target,
        ));
      }
    }
    if (context.dailyChallengeAvailable) {
      final target = daily ? 1 : min(4, context.remainingWeekDays);
      if (target > 0) {
        candidates.add(_Candidate(
          ObjectiveType.completeDailyChallenges,
          ObjectiveCategory.challenge,
          'Complete $target Daily Challenge${target == 1 ? '' : 's'}',
          target,
        ));
      }
    }
    if (!daily) {
      final dailyObjectiveTarget = min(8, context.remainingWeekDays * 3);
      if (dailyObjectiveTarget > 0) {
        candidates.add(_Candidate(
          ObjectiveType.completeDailyObjectives,
          ObjectiveCategory.challenge,
          'Complete $dailyObjectiveTarget Daily Objectives',
          dailyObjectiveTarget,
        ));
      }
      candidates.add(_Candidate(
        ObjectiveType.threeStarCompletions,
        ObjectiveCategory.performance,
        'Earn ${band == ObjectiveProgressionBand.early ? 2 : 4} three-star completions',
        band == ObjectiveProgressionBand.early ? 2 : 4,
      ));
      candidates.add(_Candidate(
        ObjectiveType.highValueShots,
        ObjectiveCategory.performance,
        'Make 5 shots that destroy at least $bestShot bricks',
        5,
        qualifier: bestShot,
      ));
    }
    if (context.unlockedPowerCount > 0 && context.availablePowerCharges > 0) {
      final configured = daily ? 2 : 5;
      final target = min(configured, context.availablePowerCharges);
      candidates.add(_Candidate(
        ObjectiveType.usePowerUps,
        ObjectiveCategory.power,
        'Use power-ups $target time${target == 1 ? '' : 's'}',
        target,
      ));
    }
    return candidates;
  }

  int _conservativeOpportunities({
    required String key,
    required int startingLevel,
    required int levelCount,
    required _OpportunityMetric metric,
  }) {
    var expected = 0.0;
    for (var offset = 0; offset < levelCount; offset++) {
      var total = 0;
      final level = startingLevel + offset;
      for (var sample = 0;
          sample < ObjectiveBalance.opportunitySamplesPerLevel;
          sample++) {
        final generated = LevelGenerator.generate(
          level: level,
          seed: _stableHash('$key:$level:$sample'),
        );
        total += switch (metric) {
          _OpportunityMetric.bricks => generated.brickCount,
          _OpportunityMetric.stealth => generated.stealthCount,
          _OpportunityMetric.specialty => generated.specialtyCount,
        };
      }
      expected += total / ObjectiveBalance.opportunitySamplesPerLevel;
    }
    return (expected * ObjectiveBalance.randomizedOpportunitySafetyFactor)
        .floor();
  }

  static int _stableHash(String value) => value.codeUnits
      .fold<int>(0, (hash, unit) => (hash * 31 + unit) & 0x7fffffff);

  static ObjectiveGenerationContext contextFor(
    PlayerProgress progress,
    DateTime now,
  ) {
    final charges = progress.unlockedPowers.fold<int>(
      0,
      (sum, id) => sum + (progress.powerCharges[id] ?? 0),
    );
    return ObjectiveGenerationContext(
      highestLevel: progress.highestLevel,
      unlockedPowerCount: progress.unlockedPowers.length,
      availablePowerCharges: charges,
      dailyChallengeAvailable: true,
      remainingWeekDays: 8 - now.weekday,
    );
  }
}

class _Candidate {
  const _Candidate(
    this.type,
    this.category,
    this.description,
    this.target, {
    this.qualifier = 0,
  });

  final ObjectiveType type;
  final ObjectiveCategory category;
  final String description;
  final int target;
  final int qualifier;
}

enum _OpportunityMetric { bricks, stealth, specialty }
