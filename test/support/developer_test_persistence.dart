import 'package:stealth_breaker/models/game_settings.dart';
import 'package:stealth_breaker/models/player_progress.dart';
import 'package:stealth_breaker/services/persistence_service.dart';

class MemoryDeveloperPersistence implements DeveloperStatePersistenceService {
  MemoryDeveloperPersistence({
    this.normal = const PlayerProgress(),
    this.debug = const PlayerProgress(),
    this.settings = const GameSettings(),
    this.developerMode = false,
  });

  PlayerProgress normal;
  PlayerProgress debug;
  GameSettings settings;
  DateTime? debugClock;

  @override
  bool developerMode;

  @override
  Future<void> initializeDeveloperState() async {}

  @override
  Future<void> setDeveloperMode(bool enabled) async {
    developerMode = enabled;
  }

  @override
  Future<PlayerProgress> loadProgress() async => developerMode ? debug : normal;

  @override
  Future<void> saveProgress(PlayerProgress progress) async {
    if (developerMode) {
      debug = progress;
    } else {
      normal = progress;
    }
  }

  @override
  Future<GameSettings> loadSettings() async => settings;

  @override
  Future<void> saveSettings(GameSettings value) async => settings = value;

  @override
  Future<DateTime?> loadDebugClockOverride() async => debugClock;

  @override
  Future<void> saveDebugClockOverride(DateTime? value) async {
    debugClock = value;
  }

  @override
  Future<void> clearDebugProgress() async {
    debug = const PlayerProgress();
    debugClock = null;
  }

  @override
  Future<void> clear() async {
    if (developerMode) {
      debug = const PlayerProgress();
    } else {
      normal = const PlayerProgress();
    }
  }
}
