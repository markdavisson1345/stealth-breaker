import 'package:flutter/material.dart';
import '../app/app_controller.dart';
import '../theme/stealth_theme.dart';
import '../widgets/game_icons.dart';
import '../widgets/stealth_components.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key, required this.controller});
  final AppController controller;
  @override
  Widget build(BuildContext context) {
    final p = controller.progress;
    final stats = <(String, String, GameIconType, Color)>[
      (
        'Highest level',
        '${p.highestLevel}',
        GameIconType.newBest,
        StealthColors.cyan
      ),
      ('High score', '${p.highScore}', GameIconType.reward, StealthColors.gold),
      (
        'Levels completed',
        '${p.levelsCompleted}',
        GameIconType.achievement,
        StealthColors.cyan
      ),
      (
        'Bricks destroyed',
        '${p.totalBricksDestroyed}',
        GameIconType.combo,
        StealthColors.cyan
      ),
      (
        'Stealth destroyed',
        '${p.stealthBricksDestroyed}',
        GameIconType.stealth,
        StealthColors.violet
      ),
      (
        'Best single shot',
        '${p.highestOneShot}',
        GameIconType.combo,
        StealthColors.cyan
      ),
      (
        'Fewest shots used',
        p.fewestShotsUsed == 0 ? '—' : '${p.fewestShotsUsed}',
        GameIconType.accuracy,
        StealthColors.cyan
      ),
      (
        'Stars earned',
        '${p.totalStars}',
        GameIconType.reward,
        StealthColors.gold
      ),
      (
        'Specialty bricks',
        '${p.specialtyBricksDestroyed}',
        GameIconType.achievement,
        StealthColors.violet
      ),
      (
        'Daily challenges',
        '${p.dailyChallengesCompleted}',
        GameIconType.preview,
        StealthColors.violet
      ),
      (
        'Longest streak',
        '${p.longestDailyStreak} day${p.longestDailyStreak == 1 ? '' : 's'}',
        GameIconType.streak,
        StealthColors.gold
      ),
      (
        'Achievement Points',
        '${p.achievementPoints}',
        GameIconType.reward,
        StealthColors.gold
      ),
      (
        'Current streak',
        '${p.dailyStreak} day${p.dailyStreak == 1 ? '' : 's'}',
        GameIconType.streak,
        StealthColors.violet
      ),
    ];
    return Scaffold(
        body: StealthScreenBackground(
            child: Column(children: [
      const StealthHeader(
          title: 'Stats', subtitle: 'Your Stealth Breaker record'),
      Expanded(child: LayoutBuilder(builder: (context, constraints) {
        final columns = constraints.maxWidth >= 700 ? 3 : 2;
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              childAspectRatio: constraints.maxWidth < 380 ? 1.38 : 1.62,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10),
          itemCount: stats.length,
          itemBuilder: (_, i) => StealthCard(
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                GameIcon(stats[i].$3, size: 26, color: stats[i].$4),
                const SizedBox(height: 7),
                Text(stats[i].$2,
                    style: StealthTextStyles.display
                        .copyWith(fontSize: 23, color: stats[i].$4)),
                const SizedBox(height: 3),
                Text(stats[i].$1.toUpperCase(),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: StealthTextStyles.label.copyWith(fontSize: 9.5)),
              ])),
        );
      })),
    ])));
  }
}
