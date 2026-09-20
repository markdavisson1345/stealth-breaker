import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/game_settings.dart';
import '../models/player_progress.dart';

abstract interface class PersistenceService {
  Future<PlayerProgress> loadProgress();
  Future<GameSettings> loadSettings();
  Future<void> saveProgress(PlayerProgress progress);
  Future<void> saveSettings(GameSettings settings);
  Future<void> clear();
}

abstract interface class PlayerProfileRepository extends PersistenceService {}

class SharedPreferencesPersistenceService implements PlayerProfileRepository {
  static const _progressKey = 'stealth_breaker.player_progress_v3';
  static const _v2ProgressKey = 'player_progress_v2';
  static const _legacyProgressKey = 'player_progress_v1';
  static const _settingsKey = 'stealth_breaker.game_settings_v2';
  static const _legacySettingsKey = 'game_settings_v1';

  Future<SharedPreferences> get _preferences => SharedPreferences.getInstance();

  @override
  Future<PlayerProgress> loadProgress() async {
    final prefs = await _preferences;
    final raw = prefs.getString(_progressKey) ??
        prefs.getString(_v2ProgressKey) ??
        prefs.getString(_legacyProgressKey);
    if (raw == null) return const PlayerProgress();
    try {
      return PlayerProgress.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const PlayerProgress();
    }
  }

  @override
  Future<GameSettings> loadSettings() async {
    final prefs = await _preferences;
    final raw =
        prefs.getString(_settingsKey) ?? prefs.getString(_legacySettingsKey);
    if (raw == null) return const GameSettings();
    try {
      return GameSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const GameSettings();
    }
  }

  @override
  Future<void> saveProgress(PlayerProgress progress) async {
    final prefs = await _preferences;
    await prefs.setString(_progressKey, jsonEncode(progress.toJson()));
    await prefs.remove(_v2ProgressKey);
    await prefs.remove(_legacyProgressKey);
  }

  @override
  Future<void> saveSettings(GameSettings settings) async {
    await (await _preferences)
        .setString(_settingsKey, jsonEncode(settings.toJson()));
  }

  @override
  Future<void> clear() async {
    final prefs = await _preferences;
    await prefs.remove(_progressKey);
    await prefs.remove(_v2ProgressKey);
    await prefs.remove(_legacyProgressKey);
    await prefs.remove(_settingsKey);
    await prefs.remove(_legacySettingsKey);
  }
}
