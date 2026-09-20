import 'dart:math';

import '../models/achievement.dart';
import '../models/player_progress.dart';

class AchievementEvaluation {
  const AchievementEvaluation({required this.progress, required this.unlocks});
  final PlayerProgress progress;
  final List<AchievementUnlock> unlocks;
}

class AchievementService {
  const AchievementService();

  AchievementEvaluation setCounter(
      PlayerProgress progress, AchievementFamilyId family, int value) {
    final counters = Map<String, int>.from(progress.achievementCounters);
    counters[family.name] = max(counters[family.name] ?? 0, value);
    return evaluate(progress.copyWith(achievementCounters: counters));
  }

  AchievementEvaluation evaluate(PlayerProgress progress) {
    final completed = Set<String>.from(progress.completedAchievementTiers);
    final unlocks = <AchievementUnlock>[];
    var points = progress.achievementPoints;
    for (final family in AchievementCatalog.families) {
      final value = progress.achievementCounters[family.id.name] ?? 0;
      for (final tier in family.tiers) {
        if (completed.contains(tier.id)) continue;
        if (value < tier.threshold) break;
        completed.add(tier.id);
        points += tier.points;
        unlocks.add(AchievementUnlock(tier));
      }
    }
    return AchievementEvaluation(
      progress: progress.copyWith(
          completedAchievementTiers: completed, achievementPoints: points),
      unlocks: List.unmodifiable(unlocks),
    );
  }
}
