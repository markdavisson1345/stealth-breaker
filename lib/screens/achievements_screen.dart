import 'package:flutter/material.dart';

import '../app/app_controller.dart';
import '../models/achievement.dart';
import '../theme/stealth_theme.dart';
import '../widgets/game_icons.dart';
import '../widgets/stealth_components.dart';

class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key, required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: StealthScreenBackground(
          child: Column(children: [
            StealthHeader(
              title: 'Achievements',
              subtitle:
                  '${controller.completedAchievementCount} tiers completed',
              trailing: _pointsPill(),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                itemCount: AchievementCatalog.families.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) =>
                    _familyCard(context, AchievementCatalog.families[index]),
              ),
            ),
          ]),
        ),
      );

  Widget _pointsPill() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
            color: StealthColors.gold.withValues(alpha: .10),
            borderRadius: BorderRadius.circular(20),
            border:
                Border.all(color: StealthColors.gold.withValues(alpha: .55))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const GameIcon(GameIconType.reward,
              size: 20, color: StealthColors.gold),
          const SizedBox(width: 6),
          Text('${controller.progress.achievementPoints} AP',
              style: StealthTextStyles.title
                  .copyWith(fontSize: 13, color: StealthColors.gold)),
        ]),
      );

  Widget _familyCard(BuildContext context, AchievementFamily family) {
    final completed = family.tiers
        .where((tier) =>
            controller.progress.completedAchievementTiers.contains(tier.id))
        .toList();
    AchievementTier? active;
    for (final tier in family.tiers) {
      if (!controller.progress.completedAchievementTiers.contains(tier.id)) {
        active = tier;
        break;
      }
    }
    final mastered = active == null;
    final shown = active ?? family.tiers.last;
    final value = controller.progress.achievementCounters[family.id.name] ?? 0;
    final accent = mastered
        ? StealthColors.gold
        : family.id == AchievementFamilyId.stealthHunter
            ? StealthColors.violet
            : StealthColors.cyan;
    final progress = mastered ? 1.0 : (value / shown.threshold).clamp(0.0, 1.0);
    final nextIndex = shown.index + 1;

    return StealthCard(
      accent: mastered ? StealthColors.gold : null,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          AchievementBadge(
              state: mastered ? GameIconType.reward : _iconFor(family.id),
              color: accent),
          const SizedBox(width: 13),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('${family.name} ${shown.roman}'.toUpperCase(),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: mastered
                            ? StealthColors.gold
                            : StealthColors.textPrimary,
                        letterSpacing: 1.1)),
                const SizedBox(height: 4),
                Text(
                    mastered
                        ? 'All tiers completed'
                        : family.descriptionBuilder(shown.threshold),
                    style: Theme.of(context).textTheme.bodySmall),
              ])),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('+${shown.points} AP',
                style: StealthTextStyles.label
                    .copyWith(color: StealthColors.gold)),
            const SizedBox(height: 4),
            Text(mastered ? 'COMPLETE' : 'IN PROGRESS',
                style: StealthTextStyles.label
                    .copyWith(fontSize: 9, color: accent)),
          ]),
        ]),
        const SizedBox(height: 14),
        StealthProgressBar(value: progress, color: accent),
        const SizedBox(height: 7),
        Row(children: [
          Text(
              mastered
                  ? '${shown.threshold} / ${shown.threshold}'
                  : '${value.clamp(0, shown.threshold)} / ${shown.threshold}',
              style: StealthTextStyles.title.copyWith(fontSize: 13)),
          const Spacer(),
          Text('${completed.length}/${family.tiers.length} TIERS',
              style: StealthTextStyles.label.copyWith(fontSize: 10)),
        ]),
        if (completed.isNotEmpty) ...[
          const SizedBox(height: 13),
          Wrap(
              spacing: 7,
              runSpacing: 7,
              children: completed
                  .map((tier) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                            color: StealthColors.gold.withValues(alpha: .08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color:
                                    StealthColors.gold.withValues(alpha: .35))),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.check_rounded,
                              size: 14, color: StealthColors.gold),
                          const SizedBox(width: 4),
                          Text('${tier.roman}  ${tier.threshold}',
                              style: StealthTextStyles.label.copyWith(
                                  fontSize: 10, color: StealthColors.gold)),
                        ]),
                      ))
                  .toList()),
        ],
        if (!mastered && nextIndex < family.tiers.length) ...[
          const SizedBox(height: 10),
          Row(children: [
            const GameIcon(GameIconType.locked,
                size: 15, color: StealthColors.disabled),
            const SizedBox(width: 6),
            Text('Tier ${family.tiers[nextIndex].roman} unlocks next',
                style: StealthTextStyles.label.copyWith(fontSize: 10)),
          ]),
        ],
      ]),
    );
  }

  GameIconType _iconFor(AchievementFamilyId id) => switch (id) {
        AchievementFamilyId.brickBarrage => GameIconType.combo,
        AchievementFamilyId.totalBricks => GameIconType.achievement,
        AchievementFamilyId.stealthHunter => GameIconType.stealth,
        AchievementFamilyId.levelMaster => GameIconType.newBest,
        AchievementFamilyId.dailyChallenger => GameIconType.preview,
        AchievementFamilyId.dailyStreak => GameIconType.streak,
        AchievementFamilyId.ricochetMaster => GameIconType.shots,
        AchievementFamilyId.efficientBreaker => GameIconType.accuracy,
      };
}
