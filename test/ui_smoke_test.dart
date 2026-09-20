import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stealth_breaker/app/app_controller.dart';
import 'package:stealth_breaker/models/game_settings.dart';
import 'package:stealth_breaker/models/player_progress.dart';
import 'package:stealth_breaker/screens/achievements_screen.dart';
import 'package:stealth_breaker/screens/daily_challenge_screen.dart';
import 'package:stealth_breaker/screens/launch_screen.dart';
import 'package:stealth_breaker/screens/settings_screen.dart';
import 'package:stealth_breaker/services/analytics_service.dart';
import 'package:stealth_breaker/services/persistence_service.dart';
import 'package:stealth_breaker/theme/stealth_theme.dart';

class _MemoryPersistence implements PersistenceService {
  PlayerProgress progress = const PlayerProgress(tutorialComplete: true);
  GameSettings settings = const GameSettings();

  @override
  Future<void> clear() async {}
  @override
  Future<PlayerProgress> loadProgress() async => progress;
  @override
  Future<GameSettings> loadSettings() async => settings;
  @override
  Future<void> saveProgress(PlayerProgress value) async => progress = value;
  @override
  Future<void> saveSettings(GameSettings value) async => settings = value;
}

Future<AppController> _controller() async {
  final controller = AppController(
      persistence: _MemoryPersistence(),
      analytics: const NoopAnalyticsService());
  await controller.initialize();
  return controller;
}

Widget _app(Widget child) => MaterialApp(theme: StealthTheme.dark, home: child);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> setPhoneSize(WidgetTester tester, Size size) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('home remains usable on a small phone', (tester) async {
    await setPhoneSize(tester, const Size(360, 640));
    final controller = await _controller();
    await tester.pumpWidget(_app(LaunchScreen(controller: controller)));
    await tester.pump();
    expect(find.text('PLAY'), findsOneWidget);
    expect(find.text('Daily Challenge'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('daily challenge fits a tall phone', (tester) async {
    await setPhoneSize(tester, const Size(412, 915));
    final controller = await _controller();
    await tester.pumpWidget(_app(DailyChallengeScreen(controller: controller)));
    await tester.pump();
    expect(find.text('START CHALLENGE'), findsOneWidget);
    expect(find.text('CHALLENGE MODIFIERS'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('achievement and settings screens render without overflow',
      (tester) async {
    await setPhoneSize(tester, const Size(360, 640));
    final controller = await _controller();
    await tester.pumpWidget(_app(AchievementsScreen(controller: controller)));
    await tester.pump();
    expect(find.textContaining('BRICK BARRAGE'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(_app(SettingsScreen(controller: controller)));
    await tester.pump();
    expect(find.text('Trajectory Preview'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('new visual settings survive JSON migration defaults', () {
    final defaults = GameSettings.fromJson(const {});
    expect(defaults.trajectoryPreview, isTrue);
    expect(defaults.showCombo, isTrue);
    final restored = GameSettings.fromJson(
        const GameSettings(trajectoryPreview: false, showCombo: false)
            .toJson());
    expect(restored.trajectoryPreview, isFalse);
    expect(restored.showCombo, isFalse);
  });
}
