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

abstract interface class DeveloperStatePersistenceService
    implements PersistenceService {
  bool get developerMode;
  Future<void> initializeDeveloperState();
  Future<void> setDeveloperMode(bool enabled);
  Future<DateTime?> loadDebugClockOverride();
  Future<void> saveDebugClockOverride(DateTime? value);
  Future<void> clearDebugProgress();
}

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

class PrivateTestingPersistenceService
    implements PlayerProfileRepository, DeveloperStatePersistenceService {
  static const _normalProgressKey =
      'stealth_breaker.private.normal.player_progress_v1';
  static const _debugProgressKey =
      'stealth_breaker.private.debug.player_progress_v1';
  static const _settingsKey = 'stealth_breaker.private.game_settings_v1';
  static const _developerModeKey = 'stealth_breaker.private.developer_mode_v1';
  static const _debugClockKey = 'stealth_breaker.private.debug_clock_v1';

  bool _developerMode = false;

  @override
  bool get developerMode => _developerMode;

  Future<SharedPreferences> get _preferences => SharedPreferences.getInstance();

  String get _activeProgressKey =>
      _developerMode ? _debugProgressKey : _normalProgressKey;

  @override
  Future<void> initializeDeveloperState() async {
    _developerMode =
        (await _preferences).getBool(_developerModeKey) ?? false;
  }

  @override
  Future<void> setDeveloperMode(bool enabled) async {
    _developerMode = enabled;
    await (await _preferences).setBool(_developerModeKey, enabled);
  }

  @override
  Future<PlayerProgress> loadProgress() async {
    final raw = (await _preferences).getString(_activeProgressKey);
    if (raw == null) return const PlayerProgress();
    try {
      return PlayerProgress.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const PlayerProgress();
    }
  }

  @override
  Future<void> saveProgress(PlayerProgress progress) async {
    await (await _preferences)
        .setString(_activeProgressKey, jsonEncode(progress.toJson()));
  }

  @override
  Future<GameSettings> loadSettings() async {
    final raw = (await _preferences).getString(_settingsKey);
    if (raw == null) return const GameSettings();
    try {
      return GameSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const GameSettings();
    }
  }

  @override
  Future<void> saveSettings(GameSettings settings) async {
    await (await _preferences)
        .setString(_settingsKey, jsonEncode(settings.toJson()));
  }

  @override
  Future<DateTime?> loadDebugClockOverride() async {
    final raw = (await _preferences).getString(_debugClockKey);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  @override
  Future<void> saveDebugClockOverride(DateTime? value) async {
    final preferences = await _preferences;
    if (value == null) {
      await preferences.remove(_debugClockKey);
    } else {
      await preferences.setString(_debugClockKey, value.toIso8601String());
    }
  }

  @override
  Future<void> clearDebugProgress() async {
    final preferences = await _preferences;
    await preferences.remove(_debugProgressKey);
    await preferences.remove(_debugClockKey);
  }

  @override
  Future<void> clear() async {
    final preferences = await _preferences;
    await preferences.remove(_activeProgressKey);
  }
}
