import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stealth_breaker/game/game_snapshot.dart';
import 'package:stealth_breaker/game/stealth_breaker_game.dart';
import 'package:stealth_breaker/models/brick.dart';
import 'package:stealth_breaker/models/game_result.dart';
import 'package:stealth_breaker/services/analytics_service.dart';
import 'package:stealth_breaker/services/audio_service.dart';
import 'package:stealth_breaker/services/preview_security_service.dart';

StealthBreakerGame gameForTest({
  void Function(GameplayFeedback)? onFeedback,
}) =>
    StealthBreakerGame(
      initialLevel: 30,
      baseSeed: 481516,
      isDaily: false,
      analytics: const NoopAnalyticsService(),
      onShotComplete: (ShotReport _) async {},
      onLevelComplete: (LevelRunReport _) async {},
      onGameOver: (_) async {},
      onFeedback: onFeedback ?? (_) {},
      onSpecialtiesAvailable: (_) {},
      trajectorySteps: 100,
      showTrajectory: true,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('preview expires once and cannot be restored', () async {
    var hiddenTransitions = 0;
    final game = gameForTest(onFeedback: (feedback) {
      if (feedback == GameplayFeedback.stealthDisappear) hiddenTransitions++;
    });
    await game.onLoad();
    expect(game.phase, GamePhase.preview);
    game.expirePreview();
    game.expirePreview();
    game.handleAppResumed();
    expect(game.phase, GamePhase.aiming);
    expect(hiddenTransitions, 1);
  });

  test('forced reinforced brick takes four hits', () async {
    final game = gameForTest();
    await game.onLoad();
    game.debugForceSpecialty(BrickSpecialType.reinforced);
    final index = game.debugBricks
        .indexWhere((brick) => brick.specialType == BrickSpecialType.reinforced);
    expect(game.debugBricks[index].hitPoints, 4);
    for (var i = 0; i < 3; i++) {
      game.debugDamageBrick(index);
    }
    expect(game.debugBricks[index].isDestroyed, isFalse);
    game.debugDamageBrick(index);
    expect(game.debugBricks[index].isDestroyed, isTrue);
  });

  test('forced specialty effects are observable and bounded', () async {
    final explosive = gameForTest();
    await explosive.onLoad();
    explosive.debugForceSpecialty(BrickSpecialType.explosive);
    final explosiveIndex = explosive.debugBricks.indexWhere(
        (brick) => brick.specialType == BrickSpecialType.explosive);
    final beforeDestroyed =
        explosive.debugBricks.where((brick) => brick.isDestroyed).length;
    explosive.debugDamageBrick(explosiveIndex, damage: 10);
    final afterDestroyed =
        explosive.debugBricks.where((brick) => brick.isDestroyed).length;
    expect(afterDestroyed - beforeDestroyed, greaterThan(1));

    final bonus = gameForTest();
    await bonus.onLoad();
    bonus.debugForceSpecialty(BrickSpecialType.bonus);
    final bonusIndex = bonus.debugBricks
        .indexWhere((brick) => brick.specialType == BrickSpecialType.bonus);
    bonus.debugDamageBrick(bonusIndex, damage: 10);
    expect(bonus.score, greaterThanOrEqualTo(600));

    final extra = gameForTest();
    await extra.onLoad();
    extra.debugForceSpecialty(BrickSpecialType.extraShot);
    final extraIndex = extra.debugBricks.indexWhere(
        (brick) => brick.specialType == BrickSpecialType.extraShot);
    final shotsBefore = extra.shotsRemaining;
    extra.debugDamageBrick(extraIndex, damage: 10);
    expect(extra.shotsRemaining, shotsBefore + 1);

    final split = gameForTest();
    await split.onLoad();
    split.debugForceSpecialty(BrickSpecialType.split);
    final splitIndex = split.debugBricks
        .indexWhere((brick) => brick.specialType == BrickSpecialType.split);
    split.debugDamageBrick(splitIndex, damage: 10);
    expect(split.debugActiveBallCount, 1);
    split.debugForceSpecialty(BrickSpecialType.split, count: 4);
    for (var i = 0; i < split.debugBricks.length; i++) {
      if (split.debugBricks[i].specialType == BrickSpecialType.split &&
          !split.debugBricks[i].isDestroyed) {
        split.debugDamageBrick(i, damage: 10);
      }
    }
    expect(split.debugActiveBallCount, lessThanOrEqualTo(3));
  });

  test('collision rate limiter recovers after a rapid burst', () {
    var now = DateTime(2026, 9, 22, 12);
    final limiter = SfxRateLimiter(clock: () => now);
    expect(limiter.allow('brick', const Duration(milliseconds: 32)), isTrue);
    for (var i = 0; i < 100; i++) {
      expect(limiter.allow('brick', const Duration(milliseconds: 32)), isFalse);
    }
    now = now.add(const Duration(milliseconds: 33));
    expect(limiter.allow('brick', const Duration(milliseconds: 32)), isTrue);
  });

  test('Android preview security channel enables and clears FLAG_SECURE',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    const channel = MethodChannel('stealth_breaker/preview_security');
    final methods = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      methods.add(call.method);
      return null;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));
    final security = PlatformPreviewSecurityService();
    await security.setPreviewProtected(true);
    await security.setPreviewProtected(false);
    expect(methods, ['enableSecurePreview', 'disableSecurePreview']);
  });
}
