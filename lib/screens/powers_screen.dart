import 'package:flutter/material.dart';
import '../app/app_controller.dart';
import '../config/game_balance.dart';
import '../models/power.dart';
import '../theme/stealth_theme.dart';

class PowersScreen extends StatefulWidget {
  const PowersScreen({super.key, required this.controller});
  final AppController controller;
  @override
  State<PowersScreen> createState() => _PowersScreenState();
}

class _PowersScreenState extends State<PowersScreen> {
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Powers'), actions: [
          Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                  child: Text(
                      '${widget.controller.progress.achievementPoints} AP',
                      style: const TextStyle(
                          color: Colors.amberAccent,
                          fontWeight: FontWeight.bold))))
        ]),
        body: ListView(padding: const EdgeInsets.all(12), children: [
          const Card(
              color: StealthColors.surface,
              elevation: 0,
              margin: EdgeInsets.zero,
              shape: StealthTheme.cardShape,
              child: Padding(
                  padding: EdgeInsets.all(14),
                  child: Text(
                      'Equip one power before a normal level. Powers are disabled in Daily Challenges so every player gets the same test.'))),
          ...PowerId.values.map((power) {
            final unlocked = widget.controller.isPowerUnlocked(power);
            final equipped =
                widget.controller.progress.equippedPower == power.storageId;
            final cost = GameBalance.powerCosts[power] ?? 0;
            final charges =
                widget.controller.progress.powerCharges[power.storageId] ?? 0;
            return Card(
                color: StealthColors.surface,
                elevation: 0,
                margin: EdgeInsets.zero,
                shape: StealthTheme.cardShape,
                child: ListTile(
              leading:
                  CircleAvatar(child: Icon(unlocked ? Icons.bolt : Icons.lock)),
              title: Text(power.displayName),
              subtitle: Text(
                  '${power.description}\n${unlocked ? '$charges charge${charges == 1 ? '' : 's'} remaining' : '$cost Achievement Points • includes ${GameBalance.initialPowerCharges[power]} charges'}'),
              isThreeLine: true,
              trailing: equipped
                  ? const Chip(label: Text('EQUIPPED'))
                  : FilledButton.tonal(
                      onPressed: unlocked
                          ? charges > 0
                              ? () async {
                                  await widget.controller.equipPower(power);
                                  if (mounted) setState(() {});
                                }
                              : null
                          : widget.controller.progress.achievementPoints >= cost
                              ? () async {
                                  await widget.controller.unlockPower(power);
                                  if (mounted) setState(() {});
                                }
                              : null,
                      child: Text(unlocked ? 'Equip' : 'Unlock')),
            ));
          }),
          if (widget.controller.progress.equippedPower != null)
            TextButton(
                onPressed: () async {
                  await widget.controller.equipPower(null);
                  if (mounted) setState(() {});
                },
                child: const Text('Unequip current power')),
        ]),
      );
}
