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
  Widget build(BuildContext context) {
    final p = widget.controller.progress;
    final objectives = ObjectiveCatalog.dailyFor(
        p.dailyObjectiveDate ?? AppController.dateKey(DateTime.now()));
    return Scaffold(
        body: StealthScreenBackground(
            child: Column(children: [
      StealthHeader(
          title: 'Objectives',
          subtitle: 'Fresh goals, steady progress',
          trailing: Text('${p.achievementPoints} AP',
              style:
                  StealthTextStyles.title.copyWith(color: StealthColors.gold))),
      Expanded(
          child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
            const StealthSectionHeader('Daily'),
            ...objectives.map((o) => _dailyCard(
                o,
                p.dailyObjectiveProgress[o.id] ?? 0,
                p.claimedDailyObjectives.contains(o.id))),
            const SizedBox(height: 10),
            const StealthSectionHeader('Weekly'),
            _weeklyCard(),
            const SizedBox(height: 12),
            StealthCard(
                child: Row(children: [
              const GameIcon(GameIconType.reward,
                  size: 28, color: StealthColors.gold),
              const SizedBox(width: 12),
              const Expanded(
                  child: Text('STORED STREAK SAVES',
                      style: StealthTextStyles.label)),
              Text('${p.streakSaves} / 3',
                  style: StealthTextStyles.title
                      .copyWith(color: StealthColors.gold)),
            ])),
          ])),
    ])));
  }

  Widget _dailyCard(ObjectiveDefinition o, int value, bool claimed) {
    final ready = value >= o.target;
    return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: StealthCard(
          accent: claimed
              ? StealthColors.gold
              : ready
                  ? StealthColors.cyan
                  : null,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              GameIcon(claimed ? GameIconType.reward : GameIconType.achievement,
                  size: 26,
                  color: claimed ? StealthColors.gold : StealthColors.cyan),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(o.description,
                      style: Theme.of(context).textTheme.titleSmall)),
              Text('+${o.rewardPoints} AP',
                  style: StealthTextStyles.label
                      .copyWith(color: StealthColors.gold)),
            ]),
            const SizedBox(height: 12),
            StealthProgressBar(
                value: value / o.target,
                color: claimed ? StealthColors.gold : StealthColors.cyan),
            const SizedBox(height: 7),
            Row(children: [
              Text('${value.clamp(0, o.target)} / ${o.target}',
                  style: StealthTextStyles.label),
              const Spacer(),
              if (ready && !claimed)
                SizedBox(
                    width: 120,
                    child: StealthButton(
                        label: 'Claim',
                        expanded: false,
                        onPressed: () async {
                          await widget.controller.claimDailyObjective(o);
                          if (mounted) setState(() {});
                        }))
              else
                Text(claimed ? 'CLAIMED' : 'IN PROGRESS',
                    style: StealthTextStyles.label.copyWith(
                        color: claimed
                            ? StealthColors.gold
                            : StealthColors.textSecondary)),
            ]),
          ]),
        ));
  }

  Widget _weeklyCard() {
    final p = widget.controller.progress;
    const o = ObjectiveCatalog.weekly;
    final ready = p.weeklyObjectiveProgress >= o.target;
    return StealthCard(
        accent: p.weeklyObjectiveClaimed
            ? StealthColors.gold
            : StealthColors.violet,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const GameIcon(GameIconType.streak,
                size: 28, color: StealthColors.violet),
            const SizedBox(width: 10),
            Expanded(
                child: Text(o.description,
                    style: Theme.of(context).textTheme.titleSmall)),
          ]),
          const SizedBox(height: 7),
          Text('Reward: ${o.rewardPoints} AP + 1 Streak Save',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          StealthProgressBar(
              value: p.weeklyObjectiveProgress / o.target,
              color: StealthColors.violet),
          const SizedBox(height: 7),
          Row(children: [
            Text(
                '${p.weeklyObjectiveProgress.clamp(0, o.target)} / ${o.target}',
                style: StealthTextStyles.label),
            const Spacer(),
            if (ready && !p.weeklyObjectiveClaimed)
              SizedBox(
                  width: 120,
                  child: StealthButton(
                      label: 'Claim',
                      expanded: false,
                      onPressed: () async {
                        await widget.controller.claimWeeklyObjective();
                        if (mounted) setState(() {});
                      }))
            else
              Text(p.weeklyObjectiveClaimed ? 'CLAIMED' : 'IN PROGRESS',
                  style: StealthTextStyles.label.copyWith(
                      color: p.weeklyObjectiveClaimed
                          ? StealthColors.gold
                          : StealthColors.textSecondary)),
          ]),
        ]));
  }
}
