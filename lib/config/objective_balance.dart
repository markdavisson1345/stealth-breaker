import '../models/objective.dart';

enum ObjectiveProgressionBand { early, mid, late }

abstract final class ObjectiveBalance {
  static ObjectiveProgressionBand bandForLevel(int level) => switch (level) {
        <= 10 => ObjectiveProgressionBand.early,
        <= 25 => ObjectiveProgressionBand.mid,
        _ => ObjectiveProgressionBand.late,
      };

  static const Map<ObjectiveProgressionBand, int> dailyExpectedLevels = {
    ObjectiveProgressionBand.early: 2,
    ObjectiveProgressionBand.mid: 3,
    ObjectiveProgressionBand.late: 4,
  };

  static const Map<ObjectiveProgressionBand, int> weeklyExpectedLevels = {
    ObjectiveProgressionBand.early: 8,
    ObjectiveProgressionBand.mid: 12,
    ObjectiveProgressionBand.late: 16,
  };

  static const Map<ObjectiveProgressionBand, int> dailyBrickTargets = {
    ObjectiveProgressionBand.early: 30,
    ObjectiveProgressionBand.mid: 60,
    ObjectiveProgressionBand.late: 100,
  };

  static const Map<ObjectiveProgressionBand, int> weeklyBrickTargets = {
    ObjectiveProgressionBand.early: 180,
    ObjectiveProgressionBand.mid: 320,
    ObjectiveProgressionBand.late: 500,
  };

  static const Map<ObjectiveProgressionBand, int> dailyLevelTargets = {
    ObjectiveProgressionBand.early: 2,
    ObjectiveProgressionBand.mid: 3,
    ObjectiveProgressionBand.late: 4,
  };

  static const Map<ObjectiveProgressionBand, int> weeklyLevelTargets = {
    ObjectiveProgressionBand.early: 8,
    ObjectiveProgressionBand.mid: 12,
    ObjectiveProgressionBand.late: 16,
  };

  static const Map<ObjectiveProgressionBand, int> dailyStarTargets = {
    ObjectiveProgressionBand.early: 3,
    ObjectiveProgressionBand.mid: 6,
    ObjectiveProgressionBand.late: 8,
  };

  static const Map<ObjectiveProgressionBand, int> weeklyStarTargets = {
    ObjectiveProgressionBand.early: 18,
    ObjectiveProgressionBand.mid: 28,
    ObjectiveProgressionBand.late: 40,
  };

  static const Map<ObjectiveProgressionBand, int> bestShotTargets = {
    ObjectiveProgressionBand.early: 5,
    ObjectiveProgressionBand.mid: 7,
    ObjectiveProgressionBand.late: 9,
  };

  static const Map<ObjectiveProgressionBand, int> efficientShotLimits = {
    ObjectiveProgressionBand.early: 12,
    ObjectiveProgressionBand.mid: 10,
    ObjectiveProgressionBand.late: 8,
  };

  static const Map<ObjectiveProgressionBand, int> dailyApRewards = {
    ObjectiveProgressionBand.early: 2,
    ObjectiveProgressionBand.mid: 3,
    ObjectiveProgressionBand.late: 4,
  };

  static const Map<ObjectiveProgressionBand, int> weeklyApRewards = {
    ObjectiveProgressionBand.early: 8,
    ObjectiveProgressionBand.mid: 12,
    ObjectiveProgressionBand.late: 16,
  };

  static const Map<ObjectiveProgressionBand, int> weeklyChargeRewards = {
    ObjectiveProgressionBand.early: 1,
    ObjectiveProgressionBand.mid: 1,
    ObjectiveProgressionBand.late: 2,
  };

  static const double randomizedOpportunitySafetyFactor = .70;
  static const int opportunitySamplesPerLevel = 24;

  static int target(Map<ObjectiveProgressionBand, int> values,
          ObjectiveProgressionBand band) =>
      values[band] ?? values.values.first;

  static ObjectiveReward rewardFor({
    required ObjectivePeriod period,
    required ObjectiveProgressionBand band,
    required bool hasUnlockedPower,
    required int slot,
  }) {
    if (period == ObjectivePeriod.weekly) {
      return ObjectiveReward(
        ap: target(weeklyApRewards, band),
        powerCharges:
            hasUnlockedPower ? target(weeklyChargeRewards, band) : 0,
      );
    }
    return ObjectiveReward(
      ap: target(dailyApRewards, band),
      powerCharges: hasUnlockedPower && slot == 2 ? 1 : 0,
    );
  }
}
