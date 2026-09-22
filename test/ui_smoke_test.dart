import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flame/game.dart';
import 'package:stealth_breaker/app/app_controller.dart';
import 'package:stealth_breaker/main.dart';
import 'package:stealth_breaker/models/game_settings.dart';
import 'package:stealth_breaker/models/player_progress.dart';
import 'package:stealth_breaker/models/brick.dart';
import 'package:stealth_breaker/models/specialty_brick_info.dart';
import 'package:stealth_breaker/screens/achievements_screen.dart';
import 'package:stealth_breaker/screens/daily_challenge_screen.dart';
import 'package:stealth_breaker/screens/launch_screen.dart';
import 'package:stealth_breaker/screens/settings_screen.dart';
import 'package:stealth_breaker/screens/tutorial_screen.dart';
import 'package:stealth_breaker/services/analytics_service.dart';
import 'package:stealth_breaker/services/audio_service.dart';
import 'package:stealth_breaker/services/persistence_service.dart';
import 'package:stealth_breaker/theme/stealth_theme.dart';
import 'package:stealth_breaker/widgets/playfield_frame.dart';
import 'package:stealth_breaker/widgets/stealth_components.dart';

class _MemoryPersistence implements PersistenceService {
  _MemoryPersistence(
      {this.progress = const PlayerProgress(tutorialComplete: true)});
  PlayerProgress progress;
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

class _RecordingAudio extends NoopAudioService {
  final states = <AppLifecycleState>[];

  @override
  Future<void> handleLifecycleState(AppLifecycleState state) async {
    states.add(state);
  }
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
    await setPhoneSize(tester, const Size(320, 640));
    final controller = await _controller();
    await tester.pumpWidget(_app(LaunchScreen(controller: controller)));
    await tester.pump();
    expect(find.text('PLAY — LEVEL 1'), findsOneWidget);
    expect(find.text('DAILY CHALLENGE'), findsOneWidget);
    final objectives = tester.widget<Text>(find.text('Objectives'));
    expect(objectives.maxLines, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('playfield is height-derived and centered on wide viewports',
      (tester) async {
    const childKey = Key('playfield-child');
    Future<Size> layout(Size viewport) async {
      await setPhoneSize(tester, viewport);
      await tester.pumpWidget(const MaterialApp(
          home: Scaffold(
              body: PlayfieldFrame(child: SizedBox.expand(key: childKey)))));
      return tester.getSize(find.byKey(childKey));
    }

    final phone = await layout(const Size(390, 700));
    expect(phone.width, 390);
    expect(phone.width / phone.height, closeTo(9 / 16, .001));
    final desktop = await layout(const Size(1200, 700));
    expect(desktop.height, 700);
    expect(desktop.width, closeTo(393.75, .01));
    final ultrawide = await layout(const Size(2560, 700));
    expect(ultrawide, desktop);
  });

  testWidgets('tutorial remains usable at mobile and desktop sizes',
      (tester) async {
    for (final size in [const Size(390, 844), const Size(1440, 900)]) {
      await setPhoneSize(tester, size);
      final controller = await _controller();
      await tester.pumpWidget(_app(TutorialScreen(
        key: ValueKey(size),
        controller: controller,
      )));
      await tester.pump();
      final tutorialButton = find.byType(StealthButton);
      expect(tutorialButton, findsOneWidget);
      expect(tester.widget<StealthButton>(tutorialButton).label, 'Next');
      expect(tester.takeException(), isNull);
      await tester.tap(tutorialButton);
      await tester.pump();
      await tester.tap(tutorialButton);
      await tester.pump();
      final paint = find.byType(CustomPaint).last;
      final paintSize = tester.getSize(paint);
      final geometry = TutorialBoardGeometry(paintSize);
      final origin = tester.getTopLeft(paint);
      await tester.dragFrom(
          origin + geometry.ball, geometry.brickRect(16).center - geometry.ball);
      await tester.pump();
      expect(tester.widget<StealthButton>(tutorialButton).label, 'Next');
      await tester.tap(tutorialButton);
      await tester.pump();
      expect(find.byKey(const ValueKey('specialty-bricks-section')),
          findsOneWidget);
      expect(
          tester.widget<StealthButton>(tutorialButton).label, 'Start Breaking');
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('Play shows tutorial once and Back does not start gameplay',
      (tester) async {
    await setPhoneSize(tester, const Size(390, 844));
    final persistence = _MemoryPersistence(
        progress: const PlayerProgress(tutorialComplete: false));
    final controller = AppController(
        persistence: persistence, analytics: const NoopAnalyticsService());
    await controller.initialize();
    await tester.pumpWidget(_app(LaunchScreen(controller: controller)));
    await tester.tap(find.text('PLAY — LEVEL 1'));
    await tester.pumpAndSettle();
    expect(find.text('HOW TO PLAY'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byWidgetPredicate((widget) => widget is GameWidget),
        findsNothing);

    await controller.setTutorialComplete(true);
    await tester.tap(find.text('PLAY — LEVEL 1'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('HOW TO PLAY'), findsNothing);
    expect(find.byWidgetPredicate((widget) => widget is GameWidget),
        findsOneWidget);
  });

  testWidgets('specialty tutorial lists every implemented gameplay type',
      (tester) async {
    await setPhoneSize(tester, const Size(390, 844));
    await tester.pumpWidget(_app(const Scaffold(body: SpecialtyBricksSection())));
    await tester.pump();
    final implemented = BrickSpecialType.values
        .where((value) => value != BrickSpecialType.none)
        .toSet();
    expect(SpecialtyBrickCatalog.all.map((value) => value.type).toSet(),
        implemented);
    for (final info in SpecialtyBrickCatalog.all) {
      expect(find.text(info.name), findsOneWidget);
      expect(find.text(info.description), findsOneWidget);
    }
    expect(tester.takeException(), isNull);

    await setPhoneSize(tester, const Size(1440, 900));
    await tester.pumpWidget(_app(const Scaffold(body: SpecialtyBricksSection())));
    await tester.pump();
    expect(find.byKey(const ValueKey('specialty-bricks-section')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('app forwards foreground and background lifecycle to audio',
      (tester) async {
    final audio = _RecordingAudio();
    final controller = AppController(
        persistence: _MemoryPersistence(),
        analytics: const NoopAnalyticsService(),
        audio: audio);
    await controller.initialize();
    await tester.pumpWidget(StealthBreakerApp(controller: controller));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(
        audio.states,
        containsAllInOrder(
            [AppLifecycleState.hidden, AppLifecycleState.resumed]));
  });

  testWidgets('daily challenge fits a tall phone', (tester) async {
    await setPhoneSize(tester, const Size(412, 915));
    final controller = await _controller();
    await tester.pumpWidget(_app(DailyChallengeScreen(controller: controller)));
    await tester.pump();
    expect(find.text('START CHALLENGE'), findsOneWidget);
    expect(find.textContaining('bricks •'), findsOneWidget);
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
    expect(find.text('Sound effects'), findsOneWidget);
    expect(find.text('Music'), findsOneWidget);
    expect(find.text('Haptics'), findsOneWidget);
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
