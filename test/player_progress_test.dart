import 'package:flutter_test/flutter_test.dart';
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
    );
    final decoded = PlayerProgress.fromJson(progress.toJson());
    expect(decoded.highestLevel, 4);
    expect(decoded.highScore, 900);
    expect(decoded.completedAchievementTiers, contains('levelMaster_1'));
    expect(decoded.achievementPoints, 5);
    expect(decoded.levelStars['1'], 3);
    expect(decoded.powerCharges['scannerPulse'], 4);
    expect(decoded.claimedStreakRewards, contains(3));
    expect(decoded.saveVersion, 3);
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
