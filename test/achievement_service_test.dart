import 'package:flutter_test/flutter_test.dart';
import 'package:stealth_breaker/models/achievement.dart';
import 'package:stealth_breaker/models/player_progress.dart';
import 'package:stealth_breaker/services/achievement_service.dart';

void main() {
  const service = AchievementService();

  test('crossing one threshold completes one tier', () {
    final result = service.setCounter(
        const PlayerProgress(), AchievementFamilyId.brickBarrage, 5);
    expect(result.unlocks.map((u) => u.tier.id), ['brickBarrage_1']);
    expect(result.progress.achievementPoints, 1);
  });

  test('crossing multiple thresholds completes all eligible tiers', () {
    final result = service.setCounter(
        const PlayerProgress(), AchievementFamilyId.totalBricks, 200);
    expect(result.unlocks.map((u) => u.tier.id),
        ['totalBricks_1', 'totalBricks_2', 'totalBricks_3']);
  });

  test('reopening persisted progress does not re-award points', () {
    final first = service.setCounter(
        const PlayerProgress(), AchievementFamilyId.totalBricks, 100);
    final reopened = PlayerProgress.fromJson(first.progress.toJson());
    final second = service.evaluate(reopened);
    expect(second.unlocks, isEmpty);
    expect(second.progress.achievementPoints, first.progress.achievementPoints);
  });

  test('already completed earlier tier does not block later tier', () {
    final result = service.evaluate(const PlayerProgress(
      achievementCounters: {'totalBricks': 100},
      completedAchievementTiers: {'totalBricks_1'},
      achievementPoints: 1,
    ));
    expect(result.unlocks.single.tier.id, 'totalBricks_2');
    expect(result.progress.achievementPoints, 3);
  });

  test('final tier displays as fully completed state', () {
    final result = service.setCounter(
        const PlayerProgress(), AchievementFamilyId.brickBarrage, 20);
    expect(
        result.progress.completedAchievementTiers, contains('brickBarrage_5'));
    expect(result.unlocks.length, 5);
    expect(service.evaluate(result.progress).unlocks, isEmpty);
  });
}
