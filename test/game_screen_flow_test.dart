import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stealth_breaker/app/app_controller.dart';
import 'package:stealth_breaker/game/stealth_breaker_game.dart';
import 'package:stealth_breaker/models/game_settings.dart';
import 'package:stealth_breaker/models/objective.dart';
import 'package:stealth_breaker/models/player_progress.dart';
import 'package:stealth_breaker/screens/game_screen.dart';
import 'package:stealth_breaker/services/analytics_service.dart';
import 'package:stealth_breaker/services/persistence_service.dart';
import 'package:stealth_breaker/services/preview_security_service.dart';
import 'package:stealth_breaker/theme/stealth_theme.dart';

class _MemoryPersistence implements PersistenceService {
  _MemoryPersistence(this.progress);
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

const _filler = ObjectiveState(
  id: 'filler',
  type: ObjectiveType.destroyBricks,
  category: ObjectiveCategory.destruction,
  description: 'Destroy 9999 bricks',
  target: 9999,
  reward: ObjectiveReward(ap: 1),
);

Future<AppController> _controller() async {
  final persistence = _MemoryPersistence(const PlayerProgress(
    tutorialComplete: true,
    dailyObjectives: ObjectiveSetState(
      period: ObjectivePeriod.daily,
      key: '2026-09-22',
      objectives: [_filler, _filler, _filler],
    ),
    weeklyObjectives: ObjectiveSetState(
      period: ObjectivePeriod.weekly,
      key: '2026-W39',
      objectives: [_filler, _filler, _filler],
    ),
  ));
  final controller = AppController(
    persistence: persistence,
    analytics: const NoopAnalyticsService(),
    clock: () => DateTime(2026, 9, 22, 12),
  );
  await controller.initialize();
  return controller;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Pause is unavailable in preview and goal screens stay paused',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final controller = await _controller();
    await tester.pumpWidget(MaterialApp(
      theme: StealthTheme.dark,
      home: GameScreen(
        controller: controller,
        level: 1,
        seed: 12,
        previewSecurity: const NoopPreviewSecurityService(),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byTooltip('Pause'), findsNothing);
    await tester.pump(const Duration(seconds: 3));
    expect(find.byTooltip('Pause'), findsOneWidget);
    await tester.tap(find.byTooltip('Pause'));
    await tester.pump();
    expect(find.text('PAUSED'), findsOneWidget);

    await tester.tap(find.text('Objectives'));
    await tester.pump();
    expect(find.text('OBJECTIVES'), findsOneWidget);
    await tester.pageBack();
    await tester.pump();
    expect(find.text('PAUSED'), findsOneWidget);

    await tester.tap(find.text('Achievements'));
    await tester.pump();
    expect(find.text('ACHIEVEMENTS'), findsOneWidget);
    await tester.pageBack();
    await tester.pump();
    expect(find.text('PAUSED'), findsOneWidget);
  });

  testWidgets('earned achievement is acknowledged before level result',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final controller = await _controller();
    await tester.pumpWidget(MaterialApp(
      theme: StealthTheme.dark,
      home: GameScreen(
        controller: controller,
        level: 1,
        seed: 18,
        previewSecurity: const NoopPreviewSecurityService(),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 200));
    final widget = tester.widget<GameWidget>(find.byType(GameWidget));
    final game = widget.game as StealthBreakerGame;
    game.debugForceComplete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('ACHIEVEMENT UNLOCKED'), findsOneWidget);
    expect(find.text('LEVEL CLEARED'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('end-run-notice-continue')));
    await tester.pump();
    expect(find.text('LEVEL CLEARED'), findsOneWidget);
  });
}
