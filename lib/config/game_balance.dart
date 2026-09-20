import '../models/achievement.dart';
import '../models/brick.dart';
import '../models/power.dart';

abstract final class GameBalance {
  static const int columns = 8;
  static const int rows = 6;
  static const double ballRadius = 4.5;
  static const double ballSpeed = 860;
  static const Duration previewDuration = Duration(seconds: 3);
  static const Duration restartPreviewCooldown = Duration(seconds: 30);
  static const double maxBrickWidth = 52;
  static const double brickAspectRatio = 0.48;
  static const int levelsPerWorld = 10;
  static const int dailyObjectiveCount = 3;
  static const int maxStreakSaves = 3;

  static const Map<int, int> streakRewards = {3: 1, 7: 2, 14: 3, 30: 5};

  static int stealthTarget(int brickCount, {required double multiplier}) {
    final base = switch (brickCount) {
      <= 9 => 1,
      <= 15 => 2,
      <= 23 => 3,
      <= 31 => 4,
      <= 39 => 5,
      <= 44 => 6,
      _ => 7,
    };
    final scaled = (base * multiplier).round();
    final cap = (brickCount * 0.30).floor().clamp(1, 14);
    return scaled.clamp(1, cap);
  }

  static int specialtyCap(int level, int brickCount) {
    final progressionCap =
        level <= 5 ? 0 : (level <= 10 ? 1 : (level <= 20 ? 2 : 3));
    final densityCap = (brickCount * 0.10).floor();
    return progressionCap.clamp(0, densityCap);
  }

  static const Map<BrickSpecialType, double> specialtyRarity = {
    BrickSpecialType.explosive: 0.04,
    BrickSpecialType.split: 0.02,
    BrickSpecialType.reinforced: 0.06,
    BrickSpecialType.bonus: 0.04,
    BrickSpecialType.extraShot: 0.02,
  };

  static const Map<BrickSpecialType, int> specialtyTypeCaps = {
    BrickSpecialType.explosive: 2,
    BrickSpecialType.split: 1,
    BrickSpecialType.reinforced: 3,
    BrickSpecialType.bonus: 2,
    BrickSpecialType.extraShot: 1,
  };

  static const Map<PowerId, int> powerCosts = {
    PowerId.scannerPulse: 8,
    PowerId.trajectoryPlus: 12,
    PowerId.powerShot: 18,
    PowerId.secondChance: 30,
  };

  static const Map<PowerId, int> initialPowerCharges = {
    PowerId.scannerPulse: 5,
    PowerId.trajectoryPlus: 5,
    PowerId.powerShot: 4,
    PowerId.secondChance: 3,
  };

  static const Map<AchievementFamilyId, List<int>> achievementThresholds = {
    AchievementFamilyId.brickBarrage: [5, 8, 12, 16, 20],
    AchievementFamilyId.totalBricks: [50, 100, 200, 500, 1000, 2500],
    AchievementFamilyId.stealthHunter: [10, 25, 50, 100, 250],
    AchievementFamilyId.levelMaster: [1, 5, 10, 25, 50],
    AchievementFamilyId.dailyChallenger: [1, 5, 15, 30],
    AchievementFamilyId.dailyStreak: [3, 7, 14, 30],
    AchievementFamilyId.ricochetMaster: [10, 50, 150, 400],
    AchievementFamilyId.efficientBreaker: [1, 5, 15, 35],
  };

  static const List<int> achievementPointRewards = [1, 2, 3, 5, 8, 13];
}
