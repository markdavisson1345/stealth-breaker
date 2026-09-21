import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_controller.dart';
import '../config/game_balance.dart';
import '../models/achievement.dart';
import '../models/objective.dart';
import '../models/power.dart';
import '../theme/stealth_theme.dart';

class DeveloperToolsScreen extends StatefulWidget {
  const DeveloperToolsScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<DeveloperToolsScreen> createState() => _DeveloperToolsScreenState();
}

class _DeveloperToolsScreenState extends State<DeveloperToolsScreen> {
  AppController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    controller.addListener(_refresh);
    unawaited(controller.refreshObjectives(controller.effectiveNow));
  }

  @override
  void dispose() {
    controller.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Developer Tools'),
          actions: const [
            Padding(
              padding: EdgeInsets.only(right: 12),
              child: Chip(
                label: Text('DEBUG MODE'),
                backgroundColor: StealthColors.gold,
                labelStyle:
                    TextStyle(color: Colors.black, fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 36),
          children: [
            _clockSection(),
            _objectiveSection(ObjectivePeriod.daily),
            _objectiveSection(ObjectivePeriod.weekly),
            _dailyChallengeSection(),
            _streakSection(),
            _powerSection(),
            _achievementSection(),
            _progressionSection(),
            _exportSection(),
            _resetSection(),
          ],
        ),
      );

  Widget _section(String title, IconData icon, List<Widget> children) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(icon, color: StealthColors.cyan),
                const SizedBox(width: 8),
                Text(title, style: Theme.of(context).textTheme.titleMedium),
              ]),
              const Divider(),
              ...children,
            ],
          ),
        ),
      );

  Widget _clockSection() => _section('Debug clock', Icons.schedule, [
        _value('Real system time', controller.realNow.toIso8601String()),
        _value(
            'Effective game time', controller.effectiveNow.toIso8601String()),
        _value(
          'Override',
          controller.debugClockOverride == null
              ? 'Real date/time'
              : controller.debugClockOverride!.toIso8601String(),
        ),
        _value('Offset', _duration(controller.debugClockOffset)),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _action('Reset to Real Date', () => controller.setDebugClock(null)),
          _action('+1 Day',
              () => controller.shiftDebugClock(const Duration(days: 1))),
          _action('-1 Day',
              () => controller.shiftDebugClock(const Duration(days: -1))),
          _action('+7 Days',
              () => controller.shiftDebugClock(const Duration(days: 7))),
          _action('-7 Days',
              () => controller.shiftDebugClock(const Duration(days: -7))),
          _action('+1 Hour',
              () => controller.shiftDebugClock(const Duration(hours: 1))),
          _action('-1 Hour',
              () => controller.shiftDebugClock(const Duration(hours: -1))),
          _action('Set Specific Date', _pickDate),
        ]),
      ]);

  Widget _objectiveSection(ObjectivePeriod period) {
    final set = period == ObjectivePeriod.daily
        ? controller.progress.dailyObjectives
        : controller.progress.weeklyObjectives;
    final daily = period == ObjectivePeriod.daily;
    return _section(
      '${daily ? 'Daily' : 'Weekly'} Objectives',
      daily ? Icons.today : Icons.date_range,
      [
        _value(daily ? 'Effective date key' : 'Effective week key',
            set?.key ?? 'Not generated'),
        if (set != null)
          ...List.generate(set.objectives.length, (index) {
            final objective = set.objectives[index];
            return ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(objective.description),
              subtitle: Text(
                '${objective.progress}/${objective.target} • '
                '${objective.completed ? 'complete' : 'active'}',
              ),
              children: [
                _value('Stable ID', objective.id),
                _value('Completed', '${objective.completed}'),
                _value('Reward granted', '${objective.rewardGranted}'),
                _value('Reward',
                    '${objective.reward.ap} AP${objective.reward.powerCharges > 0 ? ' + ${objective.reward.powerCharges} charge(s)' : ''}'),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  _action(
                      '+1',
                      () => controller.debugSetObjectiveProgress(
                          period, index, objective.progress + 1)),
                  _action(
                      '+5',
                      () => controller.debugSetObjectiveProgress(
                          period, index, objective.progress + 5)),
                  _action('Set exact', () async {
                    final value = await _askInt(
                        'Set objective progress', objective.progress);
                    if (value != null) {
                      await controller.debugSetObjectiveProgress(
                          period, index, value);
                    }
                  }),
                  _action(
                      'Complete',
                      () => controller.debugSetObjectiveProgress(
                          period, index, objective.target)),
                  _action('Reset',
                      () => controller.debugResetObjective(period, index)),
                ]),
                const SizedBox(height: 8),
              ],
            );
          }),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _action('Regenerate current set',
              () => controller.debugRegenerateObjectives(period)),
          _action('Reset all progress',
              () => controller.debugResetObjectiveSet(period)),
        ]),
      ],
    );
  }

  Widget _dailyChallengeSection() {
    final key = controller.effectiveDateKey;
    final completed = controller.progress.lastDailyCompleted == key;
    final best = controller.progress.dailyBestScores[key];
    return _section('Daily Challenge', Icons.event_available, [
      _value('Effective challenge date', key),
      _value('Deterministic seed', '${controller.effectiveDailyChallengeSeed}'),
      _value('Completed', '$completed'),
      _value('Best score', best?.toString() ?? 'None'),
      _value('Completion reward status',
          completed ? 'Completion recorded' : 'Not granted for this date'),
      _value('Lifetime completions',
          '${controller.progress.dailyChallengesCompleted}'),
      Wrap(spacing: 8, runSpacing: 8, children: [
        _action(
            'Mark complete', () => controller.debugCompleteDailyChallenge()),
        _action('Clear completion',
            () => controller.debugClearDailyChallenge(clearBestScore: false)),
        _action('Set best score', () async {
          final value = await _askInt('Set best score', best ?? 1000);
          if (value != null) await controller.debugSetDailyBestScore(value);
        }),
        _action(
            'Clear best score', () => controller.debugSetDailyBestScore(null)),
        _action('Reset current date', controller.debugClearDailyChallenge),
        _action('Reload effective date',
            () => controller.refreshObjectives(controller.effectiveNow)),
      ]),
    ]);
  }

  Widget _streakSection() => _section('Streaks', Icons.local_fire_department, [
        _value('Current streak', '${controller.progress.dailyStreak}'),
        _value('Longest streak', '${controller.progress.longestDailyStreak}'),
        _value('Last completion',
            controller.progress.lastDailyCompleted ?? 'None'),
        _value(
            'Claimed milestones',
            controller.progress.claimedStreakRewards.join(', ').isEmpty
                ? 'None'
                : controller.progress.claimedStreakRewards.join(', ')),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _action('Set current', () async {
            final value = await _askInt(
                'Set current streak', controller.progress.dailyStreak);
            if (value != null) {
              await controller.debugSetStreak(current: value);
            }
          }),
          _action('Set longest', () async {
            final value = await _askInt(
                'Set longest streak', controller.progress.longestDailyStreak);
            if (value != null) {
              await controller.debugSetStreak(longest: value);
            }
          }),
          _action('Reset current', () => controller.debugSetStreak(current: 0)),
          _action('Clear last date', controller.debugClearLastDailyCompletion),
          _action('Complete effective date',
              () => controller.debugCompleteDailyChallenge()),
        ]),
      ]);

  Widget _powerSection() => _section(
        'Powers',
        Icons.bolt,
        PowerId.values.map((power) {
          final unlocked = controller.progress.isPowerUnlocked(power);
          final charges =
              controller.progress.powerCharges[power.storageId] ?? 0;
          return ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(power.displayName),
            subtitle:
                Text('${unlocked ? 'Unlocked' : 'Locked'} • $charges charges'),
            children: [
              Wrap(spacing: 8, runSpacing: 8, children: [
                _action('Unlock', () => controller.debugUnlockPower(power)),
                _action('+1',
                    () => controller.debugSetPowerCharges(power, charges + 1)),
                _action('+5',
                    () => controller.debugSetPowerCharges(power, charges + 5)),
                _action('-1',
                    () => controller.debugSetPowerCharges(power, charges - 1)),
                _action('Set exact', () async {
                  final value = await _askInt(
                      'Set ${power.displayName} charges', charges);
                  if (value != null) {
                    await controller.debugSetPowerCharges(power, value);
                  }
                }),
                _action(
                  'Reset baseline',
                  () => controller.debugSetPowerCharges(
                    power,
                    unlocked ? GameBalance.initialPowerCharges[power] ?? 0 : 0,
                  ),
                ),
              ]),
              const SizedBox(height: 8),
            ],
          );
        }).toList(),
      );

  Widget _achievementSection() => _section(
        'Achievements',
        Icons.emoji_events,
        [
          ...AchievementCatalog.families.map((family) {
            final value =
                controller.progress.achievementCounters[family.id.name] ?? 0;
            final completed = family.tiers
                .where((tier) => controller.progress.completedAchievementTiers
                    .contains(tier.id))
                .toList();
            final active = family.tiers
                .where((tier) => !controller.progress.completedAchievementTiers
                    .contains(tier.id))
                .firstOrNull;
            return ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(family.name),
              subtitle: Text(active == null
                  ? '$value • fully completed'
                  : '$value/${active.threshold} • tier ${active.roman}'),
              children: [
                _value('Tracked value', '$value'),
                _value('Active tier', active?.roman ?? 'Complete'),
                _value('Target', active?.threshold.toString() ?? '—'),
                _value(
                    'Completed tiers',
                    completed.isEmpty
                        ? 'None'
                        : completed.map((t) => t.roman).join(', ')),
                _value('Reward state',
                    '${completed.length}/${family.tiers.length} tier rewards granted'),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  _action('+1', () => _setAchievement(family.id, value + 1)),
                  _action('+10', () => _setAchievement(family.id, value + 10)),
                  _action('Set value', () async {
                    final next =
                        await _askInt('Set ${family.name} value', value);
                    if (next != null) await _setAchievement(family.id, next);
                  }),
                  if (active != null)
                    _action('Complete tier',
                        () => _setAchievement(family.id, active.threshold)),
                  _action('Reset family', () async {
                    if (await _confirm('Reset ${family.name}?')) {
                      await controller.debugResetAchievementFamily(family.id);
                    }
                  }),
                ]),
                const SizedBox(height: 8),
              ],
            );
          }),
          OutlinedButton.icon(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Sample achievement unlocked • +3 AP'),
                duration: Duration(seconds: 2),
              ),
            ),
            icon: const Icon(Icons.notifications_active),
            label: const Text('Trigger Sample Achievement Notification'),
          ),
        ],
      );

  Future<void> _setAchievement(AchievementFamilyId family, int value) async {
    final unlocks = await controller.debugSetAchievementValue(family, value);
    if (!mounted || unlocks.isEmpty) return;
    final labels = unlocks.map((unlock) {
      final definition = AchievementCatalog.family(unlock.tier.family);
      return '${definition.name} ${unlock.tier.roman}';
    }).join(', ');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Achievement unlocked: $labels')),
    );
  }

  Widget _progressionSection() {
    final values = <(String, String, int)>[
      ('Highest level', 'highestLevel', controller.progress.highestLevel),
      ('Total stars', 'totalStars', controller.progress.totalStars),
      (
        'Achievement Points',
        'achievementPoints',
        controller.progress.achievementPoints
      ),
      (
        'Total bricks',
        'totalBricksDestroyed',
        controller.progress.totalBricksDestroyed
      ),
      (
        'Stealth bricks',
        'stealthBricksDestroyed',
        controller.progress.stealthBricksDestroyed
      ),
      (
        'Specialty bricks',
        'specialtyBricksDestroyed',
        controller.progress.specialtyBricksDestroyed
      ),
      (
        'Best single shot',
        'highestOneShot',
        controller.progress.highestOneShot
      ),
      (
        'Daily Challenges',
        'dailyChallengesCompleted',
        controller.progress.dailyChallengesCompleted
      ),
    ];
    return _section('Progression and stats', Icons.bar_chart, [
      ...values.map((entry) => ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(entry.$1),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              Text('${entry.$3}'),
              IconButton(
                tooltip: 'Edit ${entry.$1}',
                onPressed: () async {
                  final value = await _askInt('Set ${entry.$1}', entry.$3);
                  if (value != null) {
                    await controller.debugSetProgressStat(entry.$2, value);
                  }
                },
                icon: const Icon(Icons.edit),
              ),
            ]),
          )),
    ]);
  }

  Widget _exportSection() => _section('State export', Icons.data_object, [
        const Text(
            'Exports non-sensitive gameplay and debug state only. No credentials or configuration secrets are included.'),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () async {
            await Clipboard.setData(
                ClipboardData(text: controller.exportDebugState()));
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Debug state copied to clipboard')),
            );
          },
          icon: const Icon(Icons.copy),
          label: const Text('Export Debug State'),
        ),
      ]);

  Widget _resetSection() => _section('Reset controls', Icons.delete_forever, [
        const Text('These actions affect only the active private-debug save.'),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _destructive('Daily Objectives',
              () => controller.debugResetObjectiveSet(ObjectivePeriod.daily)),
          _destructive('Weekly Objectives',
              () => controller.debugResetObjectiveSet(ObjectivePeriod.weekly)),
          _destructive(
              'Daily Challenge', controller.debugResetDailyChallengeState),
          _destructive('Streak Data', () async {
            await controller.debugSetStreak(current: 0, longest: 0);
            await controller.debugClearLastDailyCompletion();
          }),
          _destructive('Power Inventory', controller.debugResetPowerInventory),
          _destructive('Achievements', controller.resetAchievements),
          _destructive(
              'Progression Stats', controller.debugResetProgressionStats),
          _destructive('ALL DEBUG STATE', controller.resetAllDebugState),
        ]),
      ]);

  Widget _destructive(String label, Future<void> Function() action) =>
      OutlinedButton(
        style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent),
        onPressed: () async {
          if (await _confirm('Reset $label?')) await action();
        },
        child: Text('Reset $label'),
      );

  Widget _value(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 150,
            child: Text(label,
                style: const TextStyle(color: StealthColors.textSecondary)),
          ),
          Expanded(child: SelectableText(value)),
        ]),
      );

  Widget _action(String label, FutureOr<void> Function() action) =>
      OutlinedButton(
        onPressed: () async => action(),
        child: Text(label),
      );

  Future<int?> _askInt(String title, int initial) async {
    final input = TextEditingController(text: '$initial');
    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: input,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(signed: true),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, int.tryParse(input.text)),
            child: const Text('Set'),
          ),
        ],
      ),
    );
    input.dispose();
    return result;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: controller.effectiveNow,
    );
    if (picked != null) await controller.setDebugClock(picked);
  }

  Future<bool> _confirm(String title) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: const Text('This affects only the private-debug state.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
              child: const Text('Reset'),
            ),
          ],
        ),
      ) ??
      false;

  String _duration(Duration value) {
    final sign = value.isNegative ? '-' : '+';
    final absolute = value.abs();
    return '$sign${absolute.inDays}d ${absolute.inHours.remainder(24)}h '
        '${absolute.inMinutes.remainder(60)}m';
  }
}
