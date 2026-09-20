import 'dart:math';

class ObjectiveDefinition {
  const ObjectiveDefinition(
      {required this.id,
      required this.description,
      required this.target,
      required this.rewardPoints});
  final String id;
  final String description;
  final int target;
  final int rewardPoints;
}

abstract final class ObjectiveCatalog {
  static const pool = <ObjectiveDefinition>[
    ObjectiveDefinition(
        id: 'bricks',
        description: 'Destroy 25 bricks',
        target: 25,
        rewardPoints: 1),
    ObjectiveDefinition(
        id: 'stealth',
        description: 'Destroy 8 stealth bricks',
        target: 8,
        rewardPoints: 2),
    ObjectiveDefinition(
        id: 'levels',
        description: 'Complete 3 levels',
        target: 3,
        rewardPoints: 2),
    ObjectiveDefinition(
        id: 'efficient',
        description: 'Finish a level with 2 shots remaining',
        target: 1,
        rewardPoints: 2),
  ];

  static List<ObjectiveDefinition> dailyFor(String dateKey) {
    final seed =
        dateKey.codeUnits.fold<int>(0, (a, b) => (a * 31 + b) & 0x7fffffff);
    final list = List<ObjectiveDefinition>.from(pool)..shuffle(Random(seed));
    return list.take(3).toList(growable: false);
  }

  static const weekly = ObjectiveDefinition(
      id: 'weekly_stars',
      description: 'Earn 20 weekly challenge points',
      target: 20,
      rewardPoints: 5);
}
