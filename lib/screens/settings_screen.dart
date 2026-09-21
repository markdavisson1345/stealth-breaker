import 'dart:async';

import 'package:flutter/material.dart';

import '../app/app_controller.dart';
import '../config/build_config.dart';
import '../models/game_settings.dart';
import '../services/analytics_service.dart';
import '../services/audio_service.dart';
import 'developer_tools_screen.dart';
import 'tutorial_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.controller});
  final AppController controller;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late GameSettings value = widget.controller.settings;

  Future<void> _save(GameSettings next, String setting, Object changed) async {
    setState(() => value = next);
    widget.controller.analytics.settingChange(setting, changed);
    await widget.controller.updateSettings(next);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            SwitchListTile(
              secondary: const Icon(Icons.volume_up_rounded),
              title: const Text('Sound effects'),
              value: value.soundEffects,
              onChanged: (v) =>
                  _save(value.copyWith(soundEffects: v), 'sfxEnabled', v),
            ),
            _volume('SFX volume', value.sfxVolume, value.soundEffects,
                (v) => _save(value.copyWith(sfxVolume: v), 'sfxVolume', v)),
            SwitchListTile(
              secondary: const Icon(Icons.music_note_rounded),
              title: const Text('Music'),
              value: value.music,
              onChanged: (v) =>
                  _save(value.copyWith(music: v), 'musicEnabled', v),
            ),
            _volume('Music volume', value.musicVolume, value.music,
                (v) => _save(value.copyWith(musicVolume: v), 'musicVolume', v)),
            SwitchListTile(
              secondary: const Icon(Icons.vibration_rounded),
              title: const Text('Haptics'),
              subtitle:
                  const Text('Native device feedback; browser support varies'),
              value: value.haptics,
              onChanged: (v) =>
                  _save(value.copyWith(haptics: v), 'hapticsEnabled', v),
            ),
            ListTile(
              title: const Text('Effects quality'),
              trailing: DropdownButton<EffectsQuality>(
                value: value.effectsQuality,
                items: EffectsQuality.values
                    .map((q) => DropdownMenuItem(value: q, child: Text(q.name)))
                    .toList(),
                onChanged: (q) {
                  if (q != null) {
                    _save(value.copyWith(effectsQuality: q), 'effectsQuality',
                        q.name);
                  }
                },
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.school_rounded),
              title: const Text('Replay tutorial'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TutorialScreen(controller: widget.controller),
                ),
              ),
            ),
            if (BuildConfig.privateTestingBuild) ...[
              const Divider(),
              SwitchListTile(
                secondary:
                    const Icon(Icons.developer_mode, color: Colors.amberAccent),
                title: const Text('Developer Mode'),
                subtitle: const Text(
                    'Switches between isolated private-normal and private-debug saves'),
                value: widget.controller.developerMode,
                onChanged: (enabled) async {
                  await widget.controller.setDeveloperMode(enabled);
                  if (mounted) setState(() {});
                },
              ),
              if (widget.controller.developerMode)
                ListTile(
                  leading:
                      const Icon(Icons.build_circle, color: Colors.amberAccent),
                  title: const Text('Open Developer Tools'),
                  subtitle: const Text('DEBUG MODE is active'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          DeveloperToolsScreen(controller: widget.controller),
                    ),
                  ),
                ),
            ],
            if (BuildConfig.developerTools && widget.controller.developerMode)
              _audioLab(),
          ],
        ),
      );

  Widget _volume(String title, double current, bool enabled,
          ValueChanged<double> set) =>
      ListTile(
        title: Text(title),
        subtitle: Slider(
          value: current,
          divisions: 20,
          label: '${(current * 100).round()}%',
          onChanged: enabled ? set : null,
        ),
        trailing: Text('${(current * 100).round()}%'),
      );

  Widget _audioLab() => ExpansionTile(
        leading: const Icon(Icons.science_rounded, color: Colors.amber),
        title: const Text('Developer audio lab'),
        subtitle: const Text('Debug builds only'),
        children: [
          Wrap(spacing: 8, runSpacing: 8, children: [
            _test('UI tap', widget.controller.audio.playUiTap),
            _test('UI back', widget.controller.audio.playUiBack),
            _test('Confirm', widget.controller.audio.playUiConfirm),
            _test('Launch', widget.controller.audio.playBallLaunch),
            _test('Wall', widget.controller.audio.playWallBounce),
            _test('Brick hit', widget.controller.audio.playBrickHit),
            _test('Brick break', widget.controller.audio.playBrickBreak),
            _test('Stealth', widget.controller.audio.playStealthHit),
            _test('Complete', widget.controller.audio.playLevelComplete),
            _test('Failed', widget.controller.audio.playLevelFailed),
            _test('Achievement', widget.controller.audio.playAchievementUnlock),
            _test('AP reward', widget.controller.audio.playApReward),
          ]),
          const SizedBox(height: 10),
          Wrap(spacing: 8, children: [
            _test('Menu music',
                () => widget.controller.audio.playMusic(MusicTrack.menu)),
            _test('Game music',
                () => widget.controller.audio.playMusic(MusicTrack.gameplay)),
            _test(
                'Daily music',
                () => widget.controller.audio
                    .playMusic(MusicTrack.dailyChallenge)),
            _test('Stop music', widget.controller.audio.stopMusic),
          ]),
          const SizedBox(height: 12),
        ],
      );

  Widget _test(String label, Future<void> Function() action) =>
      OutlinedButton(onPressed: () => unawaited(action()), child: Text(label));
}
