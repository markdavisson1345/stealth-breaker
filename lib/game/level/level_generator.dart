import 'dart:math';

import '../../config/game_balance.dart';
import '../../models/brick.dart';
import '../../models/world.dart';

enum ChallengeType { none, memoryGrid, ricochetLanes, denseBoard, highHp }

class GeneratedLevel {
  const GeneratedLevel({
    required this.bricks,
    required this.shots,
    required this.seed,
    required this.world,
    required this.challengeType,
    required this.masteryDescription,
    required this.twoStarShotTarget,
  });
  final List<Brick> bricks;
  final int shots;
  final int seed;
  final WorldDefinition world;
  final ChallengeType challengeType;
  final String masteryDescription;
  final int twoStarShotTarget;

  int get brickCount => bricks.where((b) => b.exists).length;
  int get stealthCount => bricks.where((b) => b.isStealth).length;
  int get specialtyCount =>
      bricks.where((b) => b.specialType != BrickSpecialType.none).length;
}

abstract final class LevelGenerator {
  static const columns = GameBalance.columns;
  static const rows = GameBalance.rows;

  static GeneratedLevel generate(
      {required int level, required int seed, bool daily = false}) {
    final mixedSeed = _mix(seed, level);
    final random = Random(mixedSeed);
    final world = daily ? WorldCatalog.worlds[2] : WorldCatalog.forLevel(level);
    final levelInWorld = WorldCatalog.levelInWorld(level);
    final progress = (levelInWorld - 1) / (GameBalance.levelsPerWorld - 1);
    final challenge =
        daily ? ChallengeType.none : _challengeFor(level, world.number);
    var density =
        world.densityMin + (world.densityMax - world.densityMin) * progress;
    if (challenge == ChallengeType.denseBoard) {
      density = min(.90, density + .12);
    }

    final bricks = List.generate(
        rows * columns, (i) => Brick.empty(i ~/ columns, i % columns));
    final actual = <int>[];
    for (var i = 0; i < bricks.length; i++) {
      final row = i ~/ columns;
      final column = i % columns;
      final patternRequired =
          challenge == ChallengeType.ricochetLanes && ((row + column) % 3 == 0);
      if (patternRequired ||
          random.nextDouble() < density + (row == 0 ? .08 : 0)) {
        actual.add(i);
      }
    }
    final minimum = daily ? 24 : 12 + world.number * 2;
    final candidates = List.generate(bricks.length, (i) => i)..shuffle(random);
    for (final i in candidates) {
      if (actual.length >= minimum) break;
      if (!actual.contains(i)) actual.add(i);
    }
    actual.sort();

    for (final i in actual) {
      final hpRoll = random.nextDouble();
      var hp = hpRoll < world.hp3Rate
          ? 3
          : (hpRoll < world.hp3Rate + world.hp2Rate ? 2 : 1);
      if (challenge == ChallengeType.highHp) hp = max(2, hp);
      bricks[i] = Brick(
          row: i ~/ columns,
          column: i % columns,
          kind: BrickKind.normal,
          hitPoints: hp,
          maxHitPoints: hp);
    }

    final stealthMultiplier = world.stealthMultiplier * (daily ? 1.1 : 1);
    final stealthTarget =
        GameBalance.stealthTarget(actual.length, multiplier: stealthMultiplier);
    final stealthIndices = _distributedSelection(actual, stealthTarget, random);
    for (final i in stealthIndices) {
      bricks[i] = bricks[i].copyWith(kind: BrickKind.stealth);
    }

    final specialtyCap = GameBalance.specialtyCap(level, actual.length);
    final assigned = <int>[];
    final typeCounts = <BrickSpecialType, int>{};
    final eligibleTypes = world.specialties.toList()..shuffle(random);
    final specialtyCandidates = List<int>.from(actual)..shuffle(random);
    for (final i in specialtyCandidates) {
      if (assigned.length >= specialtyCap || eligibleTypes.isEmpty) break;
      for (final type in eligibleTypes) {
        if ((typeCounts[type] ?? 0) >=
            (GameBalance.specialtyTypeCaps[type] ?? 0)) {
          continue;
        }
        if (random.nextDouble() > (GameBalance.specialtyRarity[type] ?? 0)) {
          continue;
        }
        if (!_compatible(type, bricks[i], i, assigned, bricks, world.number)) {
          continue;
        }
        var brick = bricks[i];
        if (type == BrickSpecialType.reinforced) {
          brick = Brick(
              row: brick.row,
              column: brick.column,
              kind: brick.kind,
              hitPoints: 4,
              maxHitPoints: 4,
              specialType: type);
        } else {
          brick = brick.copyWith(specialType: type);
        }
        bricks[i] = brick;
        assigned.add(i);
        typeCounts[type] = (typeCounts[type] ?? 0) + 1;
        break;
      }
    }

    final totalHp = bricks
        .where((b) => b.exists)
        .fold<int>(0, (sum, b) => sum + b.hitPoints);
    final shots = max(8,
        min(18, 7 + (totalHp / 5).ceil() + world.shotBonus + (daily ? 1 : 0)));
    final mastery = switch (level % 4) {
      0 => 'Finish with 3 shots remaining',
      1 => 'Complete with no missed shots',
      2 => 'Destroy 4 stealth bricks efficiently',
      _ => 'Reach the mastery score target',
    };
    return GeneratedLevel(
      bricks: List.unmodifiable(bricks),
      shots: shots,
      seed: mixedSeed,
      world: world,
      challengeType: challenge,
      masteryDescription: mastery,
      twoStarShotTarget: max(3, shots - 2),
    );
  }

  static List<int> _distributedSelection(
      List<int> candidates, int count, Random random) {
    final remaining = List<int>.from(candidates)..shuffle(random);
    final selected = <int>[];
    while (selected.length < count && remaining.isNotEmpty) {
      var best = remaining.first;
      var bestScore = -1e9;
      for (final candidate in remaining) {
        final row = candidate ~/ columns;
        final col = candidate % columns;
        final minDistance = selected.isEmpty
            ? 99.0
            : selected.map((s) {
                final sr = s ~/ columns;
                final sc = s % columns;
                return sqrt(pow(row - sr, 2) + pow(col - sc, 2));
              }).reduce(min);
        final rowDiversity = selected.any((s) => s ~/ columns == row) ? 0 : 2.0;
        final columnDiversity =
            selected.any((s) => s % columns == col) ? 0 : 1.5;
        final adjacencyPenalty = selected.any((s) =>
                ((s ~/ columns - row).abs() + (s % columns - col).abs()) == 1)
            ? 20.0
            : 0.0;
        final score = minDistance * 5 +
            rowDiversity +
            columnDiversity -
            adjacencyPenalty +
            random.nextDouble();
        if (score > bestScore) {
          bestScore = score;
          best = candidate;
        }
      }
      selected.add(best);
      remaining.remove(best);
    }
    return selected;
  }

  static bool _compatible(BrickSpecialType type, Brick brick, int index,
      List<int> assigned, List<Brick> bricks, int world) {
    if (brick.isStealth &&
        (type == BrickSpecialType.extraShot ||
            type == BrickSpecialType.split)) {
      return false;
    }
    if (brick.isStealth && type == BrickSpecialType.explosive && world < 4) {
      return false;
    }
    if (type == BrickSpecialType.explosive &&
        assigned.any((i) {
          if (bricks[i].specialType != BrickSpecialType.explosive) return false;
          return ((i ~/ columns) - (index ~/ columns)).abs() <= 1 &&
              ((i % columns) - (index % columns)).abs() <= 1;
        })) {
      return false;
    }
    return true;
  }

  static ChallengeType _challengeFor(int level, int world) {
    if (!WorldCatalog.isMilestone(level)) return ChallengeType.none;
    return switch (world) {
      1 => ChallengeType.memoryGrid,
      2 => ChallengeType.denseBoard,
      3 => ChallengeType.ricochetLanes,
      _ => ChallengeType.highHp
    };
  }

  static int seedForDate(DateTime date) => int.parse(
      '${date.year.toString().padLeft(4, '0')}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}');

  static int _mix(int seed, int level) {
    var value = (seed ^ (level * 0x45d9f3b)) & 0x7fffffff;
    value = ((value ^ (value >> 16)) * 0x45d9f3b) & 0x7fffffff;
    return value ^ (value >> 16);
  }
}
