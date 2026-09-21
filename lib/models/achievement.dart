import '../config/game_balance.dart';
import 'power_charge_award.dart';

enum AchievementFamilyId {
  brickBarrage,
  totalBricks,
  stealthHunter,
  levelMaster,
  dailyChallenger,
  dailyStreak,
  ricochetMaster,
  efficientBreaker,
}

class AchievementTier {
  const AchievementTier(
      {required this.family,
      required this.index,
      required this.threshold,
      required this.points});
  final AchievementFamilyId family;
  final int index;
  final int threshold;
  final int points;
  String get id => '${family.name}_${index + 1}';
  String get roman =>
      const ['I', 'II', 'III', 'IV', 'V', 'VI'][index.clamp(0, 5)];
}

class AchievementFamily {
  const AchievementFamily(
      {required this.id, required this.name, required this.descriptionBuilder});
  final AchievementFamilyId id;
  final String name;
  final String Function(int threshold) descriptionBuilder;

  List<AchievementTier> get tiers {
    final thresholds = GameBalance.achievementThresholds[id]!;
    return List.generate(
        thresholds.length,
        (i) => AchievementTier(
              family: id,
              index: i,
              threshold: thresholds[i],
              points: GameBalance.achievementPointRewards[
                  i.clamp(0, GameBalance.achievementPointRewards.length - 1)],
            ));
  }
}

abstract final class AchievementCatalog {
  static final families = <AchievementFamily>[
    AchievementFamily(
        id: AchievementFamilyId.brickBarrage,
        name: 'Brick Barrage',
        descriptionBuilder: (v) => 'Destroy $v bricks in one shot.'),
    AchievementFamily(
        id: AchievementFamilyId.totalBricks,
        name: 'Demolition Expert',
        descriptionBuilder: (v) => 'Destroy $v bricks in total.'),
    AchievementFamily(
        id: AchievementFamilyId.stealthHunter,
        name: 'Stealth Hunter',
        descriptionBuilder: (v) => 'Destroy $v stealth bricks.'),
    AchievementFamily(
        id: AchievementFamilyId.levelMaster,
        name: 'Level Master',
        descriptionBuilder: (v) => 'Complete $v levels.'),
    AchievementFamily(
        id: AchievementFamilyId.dailyChallenger,
        name: 'Daily Challenger',
        descriptionBuilder: (v) => 'Complete $v Daily Challenges.'),
    AchievementFamily(
        id: AchievementFamilyId.dailyStreak,
        name: 'Daily Streak',
        descriptionBuilder: (v) => 'Reach a $v-day Daily Challenge streak.'),
    AchievementFamily(
        id: AchievementFamilyId.ricochetMaster,
        name: 'Ricochet Master',
        descriptionBuilder: (v) => 'Hit $v bricks after a wall bounce.'),
    AchievementFamily(
        id: AchievementFamilyId.efficientBreaker,
        name: 'Efficient Breaker',
        descriptionBuilder: (v) => 'Complete $v levels with shots remaining.'),
  ];

  static AchievementFamily family(AchievementFamilyId id) =>
      families.firstWhere((e) => e.id == id);
  static Iterable<AchievementTier> get allTiers =>
      families.expand((f) => f.tiers);
  static AchievementTier? tierById(String id) {
    for (final tier in allTiers) {
      if (tier.id == id) return tier;
    }
    return null;
  }
}

class AchievementUnlock {
  const AchievementUnlock(this.tier, {this.chargeAward});
  final AchievementTier tier;
  final PowerChargeAward? chargeAward;
}
