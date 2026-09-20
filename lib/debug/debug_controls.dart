import 'package:flutter/material.dart';

import '../app/app_controller.dart';
import '../game/level/level_generator.dart';
import '../game/stealth_breaker_game.dart';
import '../models/achievement.dart';
import '../models/brick.dart';
import '../models/power.dart';

class DebugControls extends StatefulWidget {
  const DebugControls(
      {super.key,
      required this.game,
      required this.controller,
      required this.onDailyDateChanged,
      required this.onAchievementUnlocked});
  final StealthBreakerGame game;
  final AppController controller;
  final ValueChanged<DateTime> onDailyDateChanged;
  final ValueChanged<AchievementUnlock?> onAchievementUnlocked;

  @override
  State<DebugControls> createState() => _DebugControlsState();
}

class _DebugControlsState extends State<DebugControls> {
  late final level = TextEditingController(text: '${widget.game.level}');
  late final seed = TextEditingController(text: '${widget.game.seed}');
  late final shots =
      TextEditingController(text: '${widget.game.shotsRemaining}');
  late final points = TextEditingController(text: '5');
  late final specialtyCount = TextEditingController(text: '1');
  late final achievementValue = TextEditingController(text: '100');
  late final date = TextEditingController(
      text: DateTime.now().toIso8601String().substring(0, 10));

  @override
  void dispose() {
    level.dispose();
    seed.dispose();
    shots.dispose();
    points.dispose();
    specialtyCount.dispose();
    achievementValue.dispose();
    date.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
          child: ListView(
        padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 8,
            bottom: MediaQuery.viewInsetsOf(context).bottom + 16),
        children: [
          Text('Developer Tools',
              style: Theme.of(context).textTheme.headlineSmall),
          Text(
              'World: ${widget.game.worldName}  •  bricks ${widget.game.brickCount}  •  stealth ${widget.game.stealthCount}  •  specialty ${widget.game.specialtyCount}'),
          Text(
              'Achievement Points: ${widget.controller.progress.achievementPoints}'),
          const SizedBox(height: 8),
          _numberAction(
              'Level',
              level,
              'Jump',
              () =>
                  widget.game.debugJumpToLevel(int.tryParse(level.text) ?? 1)),
          _numberAction('Seed', seed, 'Apply',
              () => widget.game.debugUseSeed(int.tryParse(seed.text) ?? 1)),
          _numberAction('Shots', shots, 'Set',
              () => widget.game.debugSetShots(int.tryParse(shots.text) ?? 1)),
          _numberAction('Achievement Points (+/-)', points, 'Apply', () async {
            await widget.controller
                .addAchievementPoints(int.tryParse(points.text) ?? 0);
            if (mounted) setState(() {});
          }),
          Row(children: [
            Expanded(
                child: TextField(
                    controller: date,
                    decoration: const InputDecoration(
                        labelText: 'Daily test date (YYYY-MM-DD)'))),
            TextButton(
                onPressed: () {
                  final parsed = DateTime.tryParse(date.text);
                  if (parsed != null) {
                    widget.onDailyDateChanged(parsed);
                    widget.game
                        .debugUseSeed(LevelGenerator.seedForDate(parsed));
                  }
                },
                child: const Text('Apply')),
          ]),
          const Divider(),
          Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton(
                onPressed: widget.game.restartLevel,
                child: const Text('Restart now')),
            OutlinedButton(
                onPressed: widget.game.debugSkipPreview,
                child: const Text('Skip preview')),
            OutlinedButton(
                onPressed: widget.game.debugForceComplete,
                child: const Text('Force complete')),
            OutlinedButton(
                onPressed: widget.game.debugForceGameOver,
                child: const Text('Force game over')),
            OutlinedButton(
                onPressed: () =>
                    setState(() => widget.game.revealStealthOverride = true),
                child: const Text('Reveal stealth')),
            OutlinedButton(
                onPressed: () => setState(() {
                      widget.game.revealStealthOverride = false;
                      widget.game.hideStealthOverride = true;
                    }),
                child: const Text('Hide stealth')),
            FilterChip(
                selected: widget.game.collisionDebug,
                label: const Text('Collision hitboxes'),
                onSelected: (v) =>
                    setState(() => widget.game.collisionDebug = v)),
          ]),
          const Divider(),
          const Text('Force specialty brick'),
          _numberField('Specialty count (used by chip below)', specialtyCount),
          Wrap(
              spacing: 6,
              children: BrickSpecialType.values
                  .where((t) => t != BrickSpecialType.none)
                  .map((type) => ActionChip(
                      label: Text(type.name),
                      onPressed: () => widget.game.debugForceSpecialty(type,
                          count: int.tryParse(specialtyCount.text) ?? 1)))
                  .toList()),
          const Divider(),
          _numberField('Achievement counter (used below)', achievementValue),
          ListTile(
              title: const Text('Set achievement-family progress'),
              trailing: PopupMenuButton<AchievementFamilyId>(
                onSelected: (family) async {
                  final unlocks = await widget.controller
                      .debugSetAchievementCounter(
                          family, int.tryParse(achievementValue.text) ?? 0);
                  for (final unlock in unlocks) {
                    widget.onAchievementUnlocked(unlock);
                  }
                  if (mounted) setState(() {});
                },
                itemBuilder: (_) => AchievementFamilyId.values
                    .map((family) => PopupMenuItem(
                        value: family,
                        child: Text(AchievementCatalog.family(family).name)))
                    .toList(),
              )),
          ListTile(
              title: const Text('Unlock achievement tier'),
              trailing: PopupMenuButton<String>(
                onSelected: (id) async {
                  final unlock =
                      await widget.controller.debugUnlockAchievement(id);
                  widget.onAchievementUnlocked(unlock);
                  if (mounted) setState(() {});
                },
                itemBuilder: (_) => AchievementCatalog.allTiers.map((tier) {
                  final family = AchievementCatalog.family(tier.family);
                  return PopupMenuItem(
                      value: tier.id,
                      child: Text('${family.name} ${tier.roman}'));
                }).toList(),
              )),
          ListTile(
              title: const Text('Unlock power'),
              trailing: PopupMenuButton<PowerId>(
                onSelected: (power) async {
                  final cost = widget.controller.progress.achievementPoints;
                  if (cost < 999) {
                    await widget.controller.addAchievementPoints(999 - cost);
                  }
                  await widget.controller.unlockPower(power);
                  if (mounted) setState(() {});
                },
                itemBuilder: (_) => PowerId.values
                    .map((p) =>
                        PopupMenuItem(value: p, child: Text(p.displayName)))
                    .toList(),
              )),
          ListTile(
              title: const Text('Equip power'),
              trailing: PopupMenuButton<PowerId>(
                onSelected: (power) async {
                  await widget.controller.equipPower(power);
                  if (mounted) setState(() {});
                },
                itemBuilder: (_) => PowerId.values
                    .map((p) => PopupMenuItem(
                        value: p,
                        enabled: widget.controller.isPowerUnlocked(p),
                        child: Text(p.displayName)))
                    .toList(),
              )),
          ListTile(
              title: const Text('Reset achievements'),
              trailing: const Icon(Icons.restart_alt),
              onTap: () async {
                await widget.controller.resetAchievements();
                if (mounted) setState(() {});
              }),
          ListTile(
              title: const Text('Force 3 stars for current level'),
              trailing: const Icon(Icons.star),
              onTap: () async {
                await widget.controller.debugForceStars(widget.game.level, 3);
                if (mounted) setState(() {});
              }),
          ListTile(
              title: const Text('Jump to next challenge level'),
              trailing: const Icon(Icons.flag),
              onTap: () {
                final next = ((widget.game.level + 9) ~/ 10) * 10;
                widget.game.debugJumpToLevel(next);
              }),
          ListTile(
              title: const Text('Complete current objectives'),
              trailing: const Icon(Icons.task_alt),
              onTap: () async {
                await widget.controller.debugCompleteObjectives();
                if (mounted) setState(() {});
              }),
          ListTile(
              title: const Text('Reset Daily Challenge'),
              trailing: const Icon(Icons.event_busy),
              onTap: widget.controller.resetDaily),
          ListTile(
              title: const Text('Clear all local save data'),
              textColor: Colors.redAccent,
              iconColor: Colors.redAccent,
              trailing: const Icon(Icons.delete_forever),
              onTap: () async {
                await widget.controller.clearAllData();
                if (context.mounted) Navigator.pop(context);
              }),
        ],
      ));

  Widget _numberAction(String label, TextEditingController controller,
          String action, VoidCallback callback) =>
      Row(children: [
        Expanded(
            child: TextField(
                controller: controller,
                keyboardType:
                    const TextInputType.numberWithOptions(signed: true),
                decoration: InputDecoration(labelText: label))),
        TextButton(onPressed: callback, child: Text(action)),
      ]);

  Widget _numberField(String label, TextEditingController controller) =>
      TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(signed: true),
        decoration: InputDecoration(labelText: label),
      );
}
