import 'dart:async';

import 'package:flutter/material.dart';

import '../app/app_controller.dart';
import '../models/objective.dart';
import '../theme/stealth_theme.dart';
import '../widgets/game_icons.dart';
import '../widgets/stealth_components.dart';

class ObjectivesScreen extends StatefulWidget {
  const ObjectivesScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<ObjectivesScreen> createState() => _ObjectivesScreenState();
}

class _ObjectivesScreenState extends State<ObjectivesScreen> {
  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
  }

  Future<void> _refresh() async {
    await widget.controller.refreshObjectives(widget.controller.effectiveNow);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.controller.progress;
    final daily = progress.dailyObjectives;
    final weekly = progress.weeklyObjectives;
    return Scaffold(
      body: StealthScreenBackground(
        child: Column(children: [
          StealthHeader(
            title: 'Objectives',
            subtitle: 'Fresh goals, steady progress',
            trailing: Text(
              '${progress.achievementPoints} AP',
              style:
                  StealthTextStyles.title.copyWith(color: StealthColors.gold),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                _periodHeader(
                  'Daily Objectives',
                  daily?.key ?? widget.controller.effectiveDateKey,
                  'Resets at local midnight',
                ),
                ...?daily?.objectives.map(
                  (objective) => _objectiveCard(
                    objective,
                    accent: StealthColors.cyan,
                    icon: GameIconType.achievement,
                  ),
                ),
                const SizedBox(height: 10),
                _periodHeader(
                  'Weekly Objectives',
                  weekly?.key ?? widget.controller.effectiveWeekKey,
                  'Monday–Sunday',
                ),
                ...?weekly?.objectives.map(
                  (objective) => _objectiveCard(
                    objective,
                    accent: StealthColors.violet,
                    icon: GameIconType.streak,
                  ),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _periodHeader(String title, String key, String resetText) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 8, 2, 8),
        child: LayoutBuilder(builder: (context, constraints) {
          final schedule = Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(key, style: StealthTextStyles.label),
              Text(resetText,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(fontSize: 10)),
            ],
          );
          if (constraints.maxWidth < 430) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                StealthSectionHeader(title),
                Align(alignment: Alignment.centerRight, child: schedule),
              ],
            );
          }
          return Row(children: [
            Expanded(child: StealthSectionHeader(title)),
            schedule,
          ]);
        }),
      );

  Widget _objectiveCard(
    ObjectiveState objective, {
    required Color accent,
    required GameIconType icon,
  }) {
    final completed = objective.completed;
    final rewardParts = <String>['+${objective.reward.ap} AP'];
    if (objective.reward.powerCharges > 0) {
      rewardParts.add(
          '+${objective.reward.powerCharges} Power Charge${objective.reward.powerCharges == 1 ? '' : 's'}');
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: StealthCard(
        accent: completed ? StealthColors.gold : accent,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            GameIcon(
              completed ? GameIconType.reward : icon,
              size: 26,
              color: completed ? StealthColors.gold : accent,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                objective.description,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
          ]),
          const SizedBox(height: 5),
          Text(
            'Reward: ${rewardParts.join(' + ')}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          StealthProgressBar(
            value: objective.progress / objective.target,
            color: completed ? StealthColors.gold : accent,
          ),
          const SizedBox(height: 7),
          Row(children: [
            Text(
              '${objective.progress.clamp(0, objective.target)} / ${objective.target}',
              style: StealthTextStyles.label,
            ),
            const Spacer(),
            Text(
              completed ? 'COMPLETE' : 'IN PROGRESS',
              style: StealthTextStyles.label.copyWith(
                color: completed
                    ? StealthColors.gold
                    : StealthColors.textSecondary,
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}
