import 'package:flutter_test/flutter_test.dart';
import 'package:stealth_breaker/game/level/level_generator.dart';

void main() {
  test('same seed and settings produce the same level', () {
    final first = LevelGenerator.generate(level: 7, seed: 12345);
    final second = LevelGenerator.generate(level: 7, seed: 12345);
    expect(first.seed, second.seed);
    expect(first.shots, second.shots);
    expect(
      first.bricks
          .map((b) => '${b.kind.name}:${b.hitPoints}:${b.specialType.name}')
          .toList(),
      second.bricks
          .map((b) => '${b.kind.name}:${b.hitPoints}:${b.specialType.name}')
          .toList(),
    );
  });

  test('level always has an 8 by 6 stable grid and is not empty', () {
    final level = LevelGenerator.generate(level: 1, seed: 1);
    expect(level.bricks, hasLength(48));
    expect(level.bricks.where((brick) => brick.exists).length,
        greaterThanOrEqualTo(12));
  });

  test('daily seed is stable for a calendar date', () {
    expect(LevelGenerator.seedForDate(DateTime(2026, 9, 19)), 20260919);
  });

  test('dense boards receive proportional stealth counts', () {
    for (var seed = 1; seed <= 30; seed++) {
      final level = LevelGenerator.generate(level: 38, seed: seed);
      if (level.brickCount >= 40) {
        expect(level.stealthCount, greaterThanOrEqualTo(6));
      }
      expect(level.stealthCount, greaterThan(0));
      expect(level.stealthCount / level.brickCount, lessThanOrEqualTo(.31));
    }
  });

  test('stealth selection avoids direct adjacency when space permits', () {
    final level = LevelGenerator.generate(level: 18, seed: 8888, daily: true);
    final stealth = level.bricks.where((b) => b.isStealth).toList();
    var adjacentPairs = 0;
    for (var i = 0; i < stealth.length; i++) {
      for (var j = i + 1; j < stealth.length; j++) {
        final distance = (stealth[i].row - stealth[j].row).abs() +
            (stealth[i].column - stealth[j].column).abs();
        if (distance == 1) adjacentPairs++;
      }
    }
    expect(adjacentPairs, 0);
    expect(stealth.map((b) => b.row).toSet().length, greaterThan(1));
    expect(stealth.map((b) => b.column).toSet().length, greaterThan(1));
  });

  test('specialty bricks stay under progression and density caps', () {
    for (var levelNumber = 1; levelNumber <= 35; levelNumber++) {
      final level = LevelGenerator.generate(level: levelNumber, seed: 77);
      final expectedCap = levelNumber <= 5
          ? 0
          : levelNumber <= 10
              ? 1
              : levelNumber <= 20
                  ? 2
                  : 3;
      expect(level.specialtyCount, lessThanOrEqualTo(expectedCap));
      expect(level.specialtyCount,
          lessThanOrEqualTo((level.brickCount * .10).floor()));
    }
  });
}
