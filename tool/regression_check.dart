import 'package:stealth_breaker/game/level/level_generator.dart';
import 'package:stealth_breaker/game/systems/preview_window.dart';
import 'package:stealth_breaker/models/objective.dart';
import 'package:stealth_breaker/models/player_progress.dart';
import 'package:stealth_breaker/models/brick.dart';
import 'package:stealth_breaker/models/achievement.dart';
import 'package:stealth_breaker/services/achievement_service.dart';
import 'package:stealth_breaker/services/daily_challenge_service.dart';
import 'package:stealth_breaker/services/inventory_service.dart';

void check(bool condition, String message) {
  if (!condition) throw StateError(message);
}

void main() {
  final first = LevelGenerator.generate(level: 18, seed: 8888, daily: true);
  final second = LevelGenerator.generate(level: 18, seed: 8888, daily: true);
  check(first.bricks.length == 48, 'grid is not 8x6');
  check(
      first.bricks
              .map((b) => '${b.kind}:${b.hitPoints}:${b.specialType}')
              .join('|') ==
          second.bricks
              .map((b) => '${b.kind}:${b.hitPoints}:${b.specialType}')
              .join('|'),
      'seeded generation is not deterministic');
  final stealth = first.bricks.where((b) => b.isStealth).toList();
  check(stealth.length >= 3, 'daily stealth count is too low');
  for (var i = 0; i < stealth.length; i++) {
    for (var j = i + 1; j < stealth.length; j++) {
      final distance = (stealth[i].row - stealth[j].row).abs() +
          (stealth[i].column - stealth[j].column).abs();
      check(distance != 1, 'stealth bricks are directly adjacent');
    }
  }

  for (var seed = 1; seed <= 100; seed++) {
    final generated = LevelGenerator.generate(level: 38, seed: seed);
    if (generated.brickCount >= 40) {
      check(generated.stealthCount >= 6,
          'dense board has too few stealth bricks');
    }
    check(generated.stealthCount / generated.brickCount <= .31,
        'stealth cap exceeded');
    check(generated.specialtyCount <= 3, 'specialty cap exceeded');
    for (final brick in generated.bricks) {
      check(
          !(brick.isStealth &&
              (brick.specialType == BrickSpecialType.split ||
                  brick.specialType == BrickSpecialType.extraShot)),
          'prohibited stealth-specialty combination generated');
    }
    final explosive = generated.bricks
        .where((b) => b.specialType == BrickSpecialType.explosive)
        .toList();
    for (var i = 0; i < explosive.length; i++) {
      for (var j = i + 1; j < explosive.length; j++) {
        check(
            (explosive[i].row - explosive[j].row).abs() > 1 ||
                (explosive[i].column - explosive[j].column).abs() > 1,
            'adjacent explosive bricks generated');
      }
    }
  }

  final shown = DateTime.utc(2026, 9, 19, 12);
  check(
      !PreviewWindow.allowRestartPreview(
          now: shown.add(const Duration(seconds: 29)),
          lastPreviewShownAt: shown,
          cooldown: const Duration(seconds: 30)),
      'restart preview opened before cooldown');
  check(
      PreviewWindow.allowRestartPreview(
          now: shown.add(const Duration(seconds: 30)),
          lastPreviewShownAt: shown,
          cooldown: const Duration(seconds: 30)),
      'restart preview stayed blocked after cooldown');

  final migrated = PlayerProgress.fromJson({
    'highestLevel': 8,
    'achievementProgress': {'stealth_10': 12, 'combo_5': 6}
  });
  check(
      migrated.highestLevel == 8 &&
          migrated.achievementCounters['stealthHunter'] == 12,
      'v1 save migration failed');
  check(
      ObjectiveCatalog.dailyFor('2026-09-19').map((e) => e.id).join(',') ==
          ObjectiveCatalog.dailyFor('2026-09-19').map((e) => e.id).join(','),
      'daily objectives are not deterministic');

  const achievements = AchievementService();
  final evaluation = achievements.setCounter(
      const PlayerProgress(), AchievementFamilyId.totalBricks, 100);
  check(
      evaluation.unlocks.map((e) => e.tier.id).join(',') ==
          'totalBricks_1,totalBricks_2',
      'tier pipeline did not unlock sequential tiers');
  check(evaluation.progress.achievementPoints == 3,
      'achievement point rewards are inconsistent');
  final repeated = achievements.setCounter(
      evaluation.progress, AchievementFamilyId.totalBricks, 100);
  check(repeated.unlocks.isEmpty && repeated.progress.achievementPoints == 3,
      'completed achievement rewarded twice');
  final finalTier = achievements.setCounter(
      const PlayerProgress(), AchievementFamilyId.brickBarrage, 20);
  check(finalTier.unlocks.length == 5,
      'crossing multiple achievement thresholds missed a tier');

  const daily = DailyChallengeService();
  final dayOne = daily.complete(
      progress: const PlayerProgress(),
      challengeDate: DateTime.utc(2026, 9, 19),
      score: 900);
  check(
      dayOne.firstCompletion &&
          dayOne.progress.dailyChallengesCompleted == 1 &&
          dayOne.progress.dailyStreak == 1,
      'first daily completion was not recorded');
  final replay = daily.complete(
      progress: dayOne.progress,
      challengeDate: DateTime.utc(2026, 9, 19),
      score: 1200);
  check(
      !replay.firstCompletion &&
          replay.progress.dailyChallengesCompleted == 1 &&
          replay.progress.dailyStreak == 1 &&
          replay.progress.dailyBestScores['2026-09-19'] == 1200,
      'daily replay was not idempotent');
  final dayTwo = daily.complete(
      progress: replay.progress,
      challengeDate: DateTime.utc(2026, 9, 20),
      score: 800);
  check(dayTwo.progress.dailyStreak == 2,
      'next calendar day did not extend the streak');
  final missedDay = daily.complete(
      progress: dayTwo.progress,
      challengeDate: DateTime.utc(2026, 9, 22),
      score: 700);
  check(
      missedDay.progress.dailyStreak == 1 &&
          missedDay.progress.longestDailyStreak == 2,
      'missed day did not reset only the current streak');

  const inventory = InventoryService();
  final granted = inventory.grant(const {}, 'scannerPulse', 5);
  final consumed = inventory.consume(granted.inventory, 'scannerPulse');
  check(granted.remaining == 5 && consumed.changed && consumed.remaining == 4,
      'consumable inventory transaction failed');
  final roundTrip = PlayerProgress.fromJson(
      PlayerProgress(powerCharges: consumed.inventory).toJson());
  check(roundTrip.powerCharges['scannerPulse'] == 4,
      'inventory did not survive save round-trip');

  // ignore: avoid_print
  print(
      'PASS: seeded level rules, preview cooldown, schema migration, achievement tiers/idempotence, daily streak transactions, and consumable inventory persistence.');
}
