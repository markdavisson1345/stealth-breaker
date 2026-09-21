import 'achievement.dart';
import 'power_charge_award.dart';

class ShotReport {
  const ShotReport(
      {required this.bricksDestroyed,
      required this.stealthDestroyed,
      required this.wallBounceHits,
      required this.specialtiesDestroyed});
  final int bricksDestroyed;
  final int stealthDestroyed;
  final int wallBounceHits;
  final int specialtiesDestroyed;
}

class LevelRunReport {
  const LevelRunReport({
    required this.level,
    required this.scoreEarned,
    required this.shotsUsed,
    required this.shotsRemaining,
    required this.bricksDestroyed,
    required this.stealthDestroyed,
    required this.bestCombo,
    required this.wallBounceHits,
    required this.specialtiesDestroyed,
    required this.missedShots,
    required this.daily,
    this.powerUsed = false,
  });
  final int level;
  final int scoreEarned;
  final int shotsUsed;
  final int shotsRemaining;
  final int bricksDestroyed;
  final int stealthDestroyed;
  final int bestCombo;
  final int wallBounceHits;
  final int specialtiesDestroyed;
  final int missedShots;
  final bool daily;
  final bool powerUsed;
}

class LevelCompletionResult {
  const LevelCompletionResult(
      {required this.report,
      required this.stars,
      required this.newStars,
      required this.unlocks,
      required this.pointsEarned,
      required this.personalBest,
      this.chargeAwards = const [],
      this.dailyFirstCompletion = false,
      this.streakChanged = false});
  final LevelRunReport report;
  final int stars;
  final int newStars;
  final List<AchievementUnlock> unlocks;
  final int pointsEarned;
  final bool personalBest;
  final List<PowerChargeAward> chargeAwards;
  final bool dailyFirstCompletion;
  final bool streakChanged;
}
