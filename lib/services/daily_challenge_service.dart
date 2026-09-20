import 'dart:math';

import '../config/game_balance.dart';
import '../models/player_progress.dart';

class DailyChallengeCompletion {
  const DailyChallengeCompletion({
    required this.progress,
    required this.firstCompletion,
    required this.streakChanged,
    required this.previousStreak,
    required this.currentStreak,
    required this.rewardPoints,
  });

  final PlayerProgress progress;
  final bool firstCompletion;
  final bool streakChanged;
  final int previousStreak;
  final int currentStreak;
  final int rewardPoints;
}

class DailyChallengeService {
  const DailyChallengeService();

  DailyChallengeCompletion complete({
    required PlayerProgress progress,
    required DateTime challengeDate,
    required int score,
  }) {
    final day = dateKey(challengeDate);
    final bests = Map<String, int>.from(progress.dailyBestScores);
    bests[day] = max(bests[day] ?? 0, score);
    if (progress.lastDailyCompleted == day) {
      return DailyChallengeCompletion(
        progress: progress.copyWith(dailyBestScores: bests),
        firstCompletion: false,
        streakChanged: false,
        previousStreak: progress.dailyStreak,
        currentStreak: progress.dailyStreak,
        rewardPoints: 0,
      );
    }

    final previousStreak = progress.dailyStreak;
    final consecutive = progress.lastDailyCompleted ==
        dateKey(
            DateTime(challengeDate.year, challengeDate.month, challengeDate.day)
                .subtract(const Duration(days: 1)));
    final streak = consecutive ? previousStreak + 1 : 1;
    final claimed = Set<int>.from(progress.claimedStreakRewards);
    var rewardPoints = 0;
    final reward = GameBalance.streakRewards[streak];
    if (reward != null && claimed.add(streak)) rewardPoints = reward;

    return DailyChallengeCompletion(
      progress: progress.copyWith(
        dailyChallengesCompleted: progress.dailyChallengesCompleted + 1,
        dailyStreak: streak,
        longestDailyStreak: max(progress.longestDailyStreak, streak),
        lastDailyCompleted: day,
        dailyBestScores: bests,
        claimedStreakRewards: claimed,
        achievementPoints: progress.achievementPoints + rewardPoints,
      ),
      firstCompletion: true,
      streakChanged: streak != previousStreak,
      previousStreak: previousStreak,
      currentStreak: streak,
      rewardPoints: rewardPoints,
    );
  }

  static String dateKey(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
