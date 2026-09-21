import 'package:flutter_test/flutter_test.dart';
import 'package:stealth_breaker/models/objective.dart';
import 'package:stealth_breaker/models/player_progress.dart';

void main() {
  test('progress survives JSON round trip', () {
    const progress = PlayerProgress(
      highestLevel: 4,
      highScore: 900,
      dailyStreak: 3,
      completedAchievementTiers: {'levelMaster_1'},
      achievementCounters: {'levelMaster': 1},
      achievementPoints: 5,
      levelStars: {'1': 3},
      powerCharges: {'scannerPulse': 4},
      claimedStreakRewards: {3},
      dailyObjectives: ObjectiveSetState(
        period: ObjectivePeriod.daily,
        key: '2026-09-21',
        objectives: [
          ObjectiveState(
            id: 'daily_2026-09-21_destroyBricks_01',
            type: ObjectiveType.destroyBricks,
            category: ObjectiveCategory.destruction,
            description: 'Destroy 30 bricks',
            target: 30,
            progress: 12,
            reward: ObjectiveReward(ap: 2),
          ),
        ],
      ),
      seenSpecialtyTutorials: {'bonus'},
    );
    final decoded = PlayerProgress.fromJson(progress.toJson());
    expect(decoded.highestLevel, 4);
    expect(decoded.highScore, 900);
    expect(decoded.completedAchievementTiers, contains('levelMaster_1'));
    expect(decoded.achievementPoints, 5);
    expect(decoded.levelStars['1'], 3);
    expect(decoded.powerCharges['scannerPulse'], 4);
    expect(decoded.claimedStreakRewards, contains(3));
    expect(decoded.saveVersion, 4);
    expect(decoded.dailyObjectives?.objectives.single.progress, 12);
    expect(decoded.seenSpecialtyTutorials, contains('bonus'));
  });

  test('legacy v1 achievement counters migrate without discarding progress',
      () {
    final decoded = PlayerProgress.fromJson({
      'highestLevel': 8,
      'stealthBricksDestroyed': 12,
      'achievementProgress': {'stealth_10': 12, 'combo_5': 6, 'first_level': 1},
    });
    expect(decoded.highestLevel, 8);
    expect(decoded.achievementCounters['stealthHunter'], 12);
    expect(decoded.achievementCounters['brickBarrage'], 6);
  });
}
