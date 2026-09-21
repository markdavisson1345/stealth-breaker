import 'dart:math';
import 'dart:ui';

import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';

import '../config/game_balance.dart';
import '../models/brick.dart';
import '../models/game_result.dart';
import '../models/power.dart';
import '../models/specialty_brick_info.dart';
import '../services/analytics_service.dart';
import '../theme/stealth_theme.dart';
import 'game_snapshot.dart';
import 'level/level_generator.dart';
import 'systems/preview_window.dart';

typedef ShotCompleteCallback = Future<void> Function(ShotReport report);
typedef LevelCompleteCallback = Future<void> Function(LevelRunReport report);

enum GameplayFeedback {
  levelStart,
  previewScan,
  stealthDisappear,
  ballLaunch,
  wallBounce,
  brickHit,
  brickBreak,
  hiddenHit,
  specialtyActivated,
  largeCombo,
  levelComplete,
  levelFailed,
}

class _ActiveBall {
  _ActiveBall(this.position, this.velocity);
  Vector2 position;
  Vector2 velocity;
  bool powerDamageAvailable = false;
  bool bouncedSinceLastHit = false;
}

class _Particle {
  _Particle(this.position, this.velocity, this.color, this.life);
  Vector2 position;
  Vector2 velocity;
  Color color;
  double life;
}

class StealthBreakerGame extends FlameGame {
  StealthBreakerGame({
    required this.initialLevel,
    required this.baseSeed,
    required this.isDaily,
    required this.analytics,
    required this.onShotComplete,
    required this.onLevelComplete,
    required this.onGameOver,
    required this.onFeedback,
    required this.onSpecialtiesAvailable,
    required this.trajectorySteps,
    required this.showTrajectory,
    this.equippedPower,
  }) : snapshot = ValueNotifier(GameSnapshot(
          phase: GamePhase.loading,
          level: initialLevel,
          seed: baseSeed,
          score: 0,
          shotsRemaining: 0,
          bricksRemaining: 0,
          stealthRemaining: 0,
          ballPosition: Vector2.zero(),
          ballVelocity: Vector2.zero(),
          fps: 0,
          worldName: '',
          specialtyRemaining: 0,
          activeBalls: 0,
          equippedPower: isDaily ? null : equippedPower,
          powerUsed: false,
          currentCombo: 0,
          previewSecondsRemaining: 0,
        ));

  final int initialLevel;
  final int baseSeed;
  final bool isDaily;
  final AnalyticsService analytics;
  final ShotCompleteCallback onShotComplete;
  final LevelCompleteCallback onLevelComplete;
  final Future<void> Function(int score) onGameOver;
  final ValueChanged<GameplayFeedback> onFeedback;
  final ValueChanged<Set<BrickSpecialType>> onSpecialtiesAvailable;
  final int trajectorySteps;
  final bool showTrajectory;
  final PowerId? equippedPower;
  final ValueNotifier<GameSnapshot> snapshot;

  static const columns = GameBalance.columns;
  static const rows = GameBalance.rows;
  static const ballRadius = GameBalance.ballRadius;
  static const ballSpeed = GameBalance.ballSpeed;

  GamePhase phase = GamePhase.loading;
  GamePhase _phaseBeforePause = GamePhase.aiming;
  late PreviewWindow _previewWindow;
  DateTime? _lastPreviewShownAt;
  late GeneratedLevel _levelData;
  List<Brick> bricks = const [];
  List<Brick> _originalBricks = const [];
  final List<_ActiveBall> _balls = [];
  final List<_Particle> _particles = [];
  final Map<int, DateTime> _hiddenHitFlashes = {};
  int level = 1;
  int seed = 1;
  int _inputSeed = 1;
  int score = 0;
  int _levelStartScore = 0;
  int shotsRemaining = 0;
  int _initialShots = 0;
  int _shotsUsedThisLevel = 0;
  int stealthDestroyedThisLevel = 0;
  int bricksDestroyedThisLevel = 0;
  int specialtiesDestroyedThisLevel = 0;
  int wallBounceHitsThisLevel = 0;
  int _shotDestroyed = 0;
  int _shotStealth = 0;
  int _shotSpecialties = 0;
  int _shotBounceHits = 0;
  int bestCombo = 0;
  int missedShots = 0;
  bool revealStealthOverride = false;
  bool hideStealthOverride = false;
  bool collisionDebug = false;
  bool _completionReported = false;
  bool _lossReported = false;
  bool _powerUsed = false;
  bool _powerShotArmed = false;
  DateTime? _scannerExpiresAt;
  Vector2 launchPosition = Vector2.zero();
  Vector2? aimPoint;
  double _brickWidth = 38;
  double _brickHeight = 20;
  double _gridLeft = 0;
  double _gridTop = 30;
  double _fps = 0;
  double _notifyAccumulator = 0;

  Vector2 get ballPosition =>
      _balls.isEmpty ? launchPosition : _balls.first.position;
  Vector2 get ballVelocity =>
      _balls.isEmpty ? Vector2.zero() : _balls.first.velocity;
  String get worldName => _levelData.world.name;
  int get brickCount => bricks.where((b) => b.exists).length;
  int get stealthCount => bricks.where((b) => b.isStealth).length;
  int get specialtyCount =>
      bricks.where((b) => b.specialType != BrickSpecialType.none).length;
  DateTime? get lastPreviewShownAt => _lastPreviewShownAt;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    startLevel(level: initialLevel, seedOverride: baseSeed);
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _recalculateLayout();
    if (phase != GamePhase.firing) _resetBall();
  }

  void startLevel(
      {required int level, int? seedOverride, bool showPreview = true}) {
    onFeedback(GameplayFeedback.levelStart);
    this.level = max(1, level);
    _inputSeed = seedOverride ?? baseSeed;
    _levelData = LevelGenerator.generate(
        level: this.level, seed: _inputSeed, daily: isDaily);
    seed = _levelData.seed;
    _originalBricks = List<Brick>.from(_levelData.bricks);
    onSpecialtiesAvailable(_originalBricks
        .map((brick) => brick.specialType)
        .where((type) => type != BrickSpecialType.none)
        .toSet());
    _resetLevelState(showPreview: showPreview);
    analytics.event(
        'worldStarted', {'world': _levelData.world.number, 'name': worldName});
    analytics.event('levelStarted', {
      'level': level,
      'seed': seed,
      'daily': isDaily,
      'challenge': _levelData.challengeType.name
    });
  }

  void _resetLevelState({required bool showPreview}) {
    bricks = List<Brick>.from(_originalBricks);
    shotsRemaining = _levelData.shots;
    _initialShots = shotsRemaining;
    _shotsUsedThisLevel = 0;
    stealthDestroyedThisLevel = 0;
    bricksDestroyedThisLevel = 0;
    specialtiesDestroyedThisLevel = 0;
    wallBounceHitsThisLevel = 0;
    _levelStartScore = score;
    bestCombo = 0;
    missedShots = 0;
    _completionReported = false;
    _lossReported = false;
    _powerUsed = false;
    _powerShotArmed = false;
    _scannerExpiresAt = null;
    revealStealthOverride = false;
    hideStealthOverride = false;
    aimPoint = null;
    _balls.clear();
    _particles.clear();
    _hiddenHitFlashes.clear();
    _recalculateLayout();
    _resetBall();
    if (showPreview) {
      final now = DateTime.now();
      _lastPreviewShownAt = now;
      _previewWindow = PreviewWindow.start(now, GameBalance.previewDuration);
      _setPhase(GamePhase.preview);
      onFeedback(GameplayFeedback.previewScan);
    } else {
      _previewWindow = PreviewWindow(expiresAt: DateTime.now());
      _setPhase(GamePhase.aiming);
    }
  }

  void restartLevel() {
    resumeEngine();
    score = _levelStartScore;
    final now = DateTime.now();
    final allowPreview = PreviewWindow.allowRestartPreview(
        now: now,
        lastPreviewShownAt: _lastPreviewShownAt,
        cooldown: GameBalance.restartPreviewCooldown);
    _resetLevelState(showPreview: allowPreview);
    analytics.event(allowPreview ? 'levelRestarted' : 'restartWithoutPreview',
        {'level': level, 'seed': seed});
  }

  void nextLevel() {
    if (phase != GamePhase.levelComplete || isDaily) return;
    startLevel(level: level + 1);
  }

  void replayLevel() {
    if (phase != GamePhase.levelComplete) return;
    score = _levelStartScore;
    _resetLevelState(showPreview: true);
  }

  void handleAppResumed() {
    if (phase == GamePhase.preview &&
        _previewWindow.isExpiredAt(DateTime.now())) {
      _finishPreview();
    }
    if (_scannerExpiresAt != null &&
        !DateTime.now().isBefore(_scannerExpiresAt!)) {
      _scannerExpiresAt = null;
    }
  }

  bool requestPause() {
    if (phase == GamePhase.preview ||
        phase == GamePhase.loading ||
        phase == GamePhase.levelComplete ||
        phase == GamePhase.gameOver) {
      return false;
    }
    if (phase != GamePhase.aiming && phase != GamePhase.firing) return false;
    _phaseBeforePause = phase;
    _setPhase(GamePhase.paused);
    pauseEngine();
    return true;
  }

  void resumeFromPause() {
    if (phase != GamePhase.paused) return;
    resumeEngine();
    _setPhase(_phaseBeforePause);
  }

  bool activatePower() {
    if (isDaily || equippedPower == null || _powerUsed) return false;
    switch (equippedPower!) {
      case PowerId.scannerPulse:
        if (phase != GamePhase.aiming) return false;
        _scannerExpiresAt = DateTime.now().add(const Duration(seconds: 2));
        break;
      case PowerId.trajectoryPlus:
        return false; // Passive; always active while equipped.
      case PowerId.powerShot:
        if (phase != GamePhase.aiming) return false;
        _powerShotArmed = true;
        break;
      case PowerId.secondChance:
        if (phase != GamePhase.gameOver) return false;
        shotsRemaining = 1;
        _lossReported = false;
        _setPhase(GamePhase.aiming);
        break;
    }
    _powerUsed = true;
    analytics.event(
        'powerUsed', {'power': equippedPower!.storageId, 'level': level});
    _notify();
    return true;
  }

  void beginAim(Offset localPosition) {
    if (phase != GamePhase.aiming) return;
    aimPoint =
        Vector2(localPosition.dx, min(localPosition.dy, launchPosition.y - 20));
    _notify();
  }

  void updateAim(Offset localPosition) {
    if (phase != GamePhase.aiming || aimPoint == null) return;
    aimPoint = Vector2(localPosition.dx.clamp(0, size.x).toDouble(),
        min(localPosition.dy, launchPosition.y - 20));
  }

  void releaseAim() {
    if (phase != GamePhase.aiming || aimPoint == null) return;
    final direction = aimPoint! - launchPosition;
    aimPoint = null;
    if (direction.y > -15 || direction.length < 25) return;
    direction.normalize();
    if (direction.y > -0.18) direction.y = -0.18;
    direction.normalize();
    final ball = _ActiveBall(launchPosition.clone(), direction * ballSpeed)
      ..powerDamageAvailable = _powerShotArmed;
    _powerShotArmed = false;
    _balls
      ..clear()
      ..add(ball);
    _shotDestroyed = 0;
    _shotStealth = 0;
    _shotSpecialties = 0;
    _shotBounceHits = 0;
    _setPhase(GamePhase.firing);
    onFeedback(GameplayFeedback.ballLaunch);
    analytics
        .event('shotFired', {'level': level, 'shotsBefore': shotsRemaining});
  }

  @override
  void update(double dt) {
    super.update(dt);
    _fps =
        dt > 0 ? (_fps * .9) + ((1 / dt).clamp(0, 240).toDouble() * .1) : _fps;
    final now = DateTime.now();
    if (phase == GamePhase.preview && _previewWindow.isExpiredAt(now)) {
      _finishPreview();
    }
    if (_scannerExpiresAt != null && !now.isBefore(_scannerExpiresAt!)) {
      _scannerExpiresAt = null;
    }
    if (phase == GamePhase.firing) _updateBalls(min(dt, 1 / 20));
    _updateParticles(dt);
    _hiddenHitFlashes.removeWhere((_, expires) => !now.isBefore(expires));
    _notifyAccumulator += dt;
    if (_notifyAccumulator >= .08) {
      _notifyAccumulator = 0;
      _notify();
    }
  }

  void _finishPreview() {
    if (phase == GamePhase.preview) {
      _setPhase(GamePhase.aiming);
      onFeedback(GameplayFeedback.stealthDisappear);
    }
  }

  void _updateBalls(double dt) {
    final substeps = max(1, (ballSpeed * dt / 6).ceil());
    final stepDt = dt / substeps;
    for (var step = 0; step < substeps && phase == GamePhase.firing; step++) {
      final spawned = <_ActiveBall>[];
      for (final ball in List<_ActiveBall>.from(_balls)) {
        final previous = ball.position.clone();
        ball.position += ball.velocity * stepDt;
        if (ball.position.x - ballRadius <= 0 && ball.velocity.x < 0) {
          ball.position.x = ballRadius;
          ball.velocity.x = -ball.velocity.x;
          ball.bouncedSinceLastHit = true;
          onFeedback(GameplayFeedback.wallBounce);
        } else if (ball.position.x + ballRadius >= size.x &&
            ball.velocity.x > 0) {
          ball.position.x = size.x - ballRadius;
          ball.velocity.x = -ball.velocity.x;
          ball.bouncedSinceLastHit = true;
          onFeedback(GameplayFeedback.wallBounce);
        }
        if (ball.position.y - ballRadius <= 0 && ball.velocity.y < 0) {
          ball.position.y = ballRadius;
          ball.velocity.y = -ball.velocity.y;
          ball.bouncedSinceLastHit = true;
          onFeedback(GameplayFeedback.wallBounce);
        }
        for (var index = 0; index < bricks.length; index++) {
          final brick = bricks[index];
          if (!brick.exists ||
              brick.isDestroyed ||
              !_circleIntersectsRect(
                  ball.position, ballRadius, _brickRect(brick))) {
            continue;
          }
          final damage = ball.powerDamageAvailable ? 2 : 1;
          ball.powerDamageAvailable = false;
          _damageBrick(index, damage, ball, spawned);
          _bounceFromRect(ball, previous, _brickRect(brick));
          break;
        }
      }
      _balls.addAll(spawned);
      _balls.removeWhere((ball) => ball.position.y - ballRadius > size.y);
      if (_remainingBricks == 0) {
        _completeLevel();
        return;
      }
    }
    if (_balls.isEmpty && phase == GamePhase.firing) _finishShot();
  }

  void _damageBrick(
      int index, int damage, _ActiveBall ball, List<_ActiveBall> spawned,
      {Set<int>? explosionVisited}) {
    final brick = bricks[index];
    if (brick.isDestroyed) return;
    final damaged = brick.copyWith(hitPoints: max(0, brick.hitPoints - damage));
    onFeedback(GameplayFeedback.brickHit);
    bricks[index] = damaged;
    score += damaged.isDestroyed
        ? 100 * brick.maxHitPoints + _shotDestroyed * 20
        : 25;
    if (ball.bouncedSinceLastHit) {
      _shotBounceHits++;
      wallBounceHitsThisLevel++;
    }
    ball.bouncedSinceLastHit = false;
    _spawnParticles(
        _brickRect(brick).center,
        brick.isStealth ? StealthColors.violet : StealthColors.gold,
        damaged.isDestroyed ? 10 : 4);
    if (brick.isStealth && !_stealthVisible) {
      _hiddenHitFlashes[index] =
          DateTime.now().add(const Duration(milliseconds: 550));
      onFeedback(GameplayFeedback.hiddenHit);
    }
    if (!damaged.isDestroyed) return;
    onFeedback(GameplayFeedback.brickBreak);
    _shotDestroyed++;
    bricksDestroyedThisLevel++;
    bestCombo = max(bestCombo, _shotDestroyed);
    if (_shotDestroyed == 5 || _shotDestroyed == 10 || _shotDestroyed == 15) {
      onFeedback(GameplayFeedback.largeCombo);
    }
    if (brick.isStealth) {
      _shotStealth++;
      stealthDestroyedThisLevel++;
      analytics.event('stealthBrickHit', {'level': level});
    }
    if (brick.specialType != BrickSpecialType.none) {
      _shotSpecialties++;
      specialtiesDestroyedThisLevel++;
      analytics.event('specialtyBrickDestroyed',
          {'type': brick.specialType.name, 'level': level});
      onFeedback(GameplayFeedback.specialtyActivated);
    }
    switch (brick.specialType) {
      case BrickSpecialType.explosive:
        final visited = explosionVisited ?? <int>{};
        if (!visited.add(index)) break;
        for (var r = max(0, brick.row - 1);
            r <= min(rows - 1, brick.row + 1);
            r++) {
          for (var c = max(0, brick.column - 1);
              c <= min(columns - 1, brick.column + 1);
              c++) {
            final neighbor = r * columns + c;
            if (neighbor != index &&
                bricks[neighbor].exists &&
                !bricks[neighbor].isDestroyed) {
              _damageBrick(neighbor, 1, ball, spawned,
                  explosionVisited: visited);
            }
          }
        }
        break;
      case BrickSpecialType.split:
        if (_balls.length + spawned.length < 3) {
          final velocity = ball.velocity.clone()..rotate(.34);
          spawned.add(_ActiveBall(ball.position.clone(), velocity));
        }
        break;
      case BrickSpecialType.reinforced:
        break;
      case BrickSpecialType.bonus:
        score += 500;
        break;
      case BrickSpecialType.extraShot:
        shotsRemaining++;
        break;
      case BrickSpecialType.none:
        break;
    }
  }

  void _bounceFromRect(_ActiveBall ball, Vector2 previous, Rect rect) {
    final side = (previous.x + ballRadius <= rect.left ||
            previous.x - ballRadius >= rect.right) &&
        !(previous.y + ballRadius <= rect.top ||
            previous.y - ballRadius >= rect.bottom);
    if (side) {
      ball.velocity.x = -ball.velocity.x;
    } else {
      ball.velocity.y = -ball.velocity.y;
    }
    ball.position = previous;
  }

  void _finishShot() {
    if (phase != GamePhase.firing) return;
    _shotsUsedThisLevel++;
    shotsRemaining = max(0, shotsRemaining - 1);
    if (_shotDestroyed == 0) missedShots++;
    onShotComplete(ShotReport(
        bricksDestroyed: _shotDestroyed,
        stealthDestroyed: _shotStealth,
        wallBounceHits: _shotBounceHits,
        specialtiesDestroyed: _shotSpecialties));
    _resetBall();
    if (_remainingBricks == 0) {
      _completeLevel();
    } else if (shotsRemaining <= 0) {
      _setPhase(GamePhase.gameOver);
      onFeedback(GameplayFeedback.levelFailed);
      analytics.event('levelFailed', {'level': level, 'score': score});
      if (!_lossReported) {
        _lossReported = true;
        onGameOver(score);
      }
    } else {
      _setPhase(GamePhase.aiming);
    }
  }

  void _completeLevel() {
    if (phase == GamePhase.levelComplete || _completionReported) return;
    if (_balls.isNotEmpty) {
      onShotComplete(ShotReport(
          bricksDestroyed: _shotDestroyed,
          stealthDestroyed: _shotStealth,
          wallBounceHits: _shotBounceHits,
          specialtiesDestroyed: _shotSpecialties));
    }
    _balls.clear();
    aimPoint = null;
    _setPhase(GamePhase.levelComplete);
    onFeedback(GameplayFeedback.levelComplete);
    _completionReported = true;
    final report = LevelRunReport(
      level: level,
      scoreEarned: score - _levelStartScore,
      originalStartingShots: _initialShots,
      shotsUsed: _shotsUsedThisLevel,
      shotsRemaining: shotsRemaining,
      bricksDestroyed: bricksDestroyedThisLevel,
      stealthDestroyed: stealthDestroyedThisLevel,
      bestCombo: bestCombo,
      wallBounceHits: wallBounceHitsThisLevel,
      specialtiesDestroyed: specialtiesDestroyedThisLevel,
      missedShots: missedShots,
      daily: isDaily,
      powerUsed: _powerUsed,
    );
    onLevelComplete(report);
  }

  void _recalculateLayout() {
    if (size.x <= 0 || size.y <= 0) return;
    const gap = 4.0;
    final fieldWidth = min(size.x - 24, 440.0);
    _brickWidth = min(GameBalance.maxBrickWidth,
        (fieldWidth - gap * (columns - 1)) / columns);
    _brickHeight = _brickWidth * GameBalance.brickAspectRatio;
    final actualWidth = _brickWidth * columns + gap * (columns - 1);
    _gridLeft = (size.x - actualWidth) / 2;
    _gridTop = 34;
  }

  Rect _brickRect(Brick brick) => Rect.fromLTWH(
      _gridLeft + brick.column * (_brickWidth + 4),
      _gridTop + brick.row * (_brickHeight + 4),
      _brickWidth,
      _brickHeight);

  void _resetBall() {
    if (size.x <= 0 || size.y <= 0) return;
    launchPosition = Vector2(size.x / 2,
        max(_gridTop + rows * (_brickHeight + 4) + 60, size.y - 54));
    launchPosition.y = min(launchPosition.y, size.y - 42);
    _balls.clear();
  }

  bool _circleIntersectsRect(Vector2 center, double radius, Rect rect) {
    final x = center.x.clamp(rect.left, rect.right);
    final y = center.y.clamp(rect.top, rect.bottom);
    final dx = center.x - x;
    final dy = center.y - y;
    return dx * dx + dy * dy <= radius * radius;
  }

  int get _remainingBricks =>
      bricks.where((b) => b.exists && !b.isDestroyed).length;
  int get _remainingStealth =>
      bricks.where((b) => b.isStealth && !b.isDestroyed).length;
  int get _remainingSpecialties => bricks
      .where((b) => b.specialType != BrickSpecialType.none && !b.isDestroyed)
      .length;
  bool get _stealthVisible =>
      phase == GamePhase.preview ||
      revealStealthOverride ||
      (_scannerExpiresAt != null &&
          DateTime.now().isBefore(_scannerExpiresAt!));

  @override
  void render(Canvas canvas) {
    canvas.drawRect(Offset.zero & Size(size.x, size.y),
        Paint()..color = StealthColors.background);
    final gridPaint = Paint()
      ..color = StealthColors.cyan.withOpacity(.022)
      ..strokeWidth = 1;
    for (double x = 0; x < size.x; x += 32) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.y), gridPaint);
    }
    for (double y = 0; y < size.y; y += 32) {
      canvas.drawLine(Offset(0, y), Offset(size.x, y), gridPaint);
    }
    final border = Paint()
      ..color = StealthColors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawLine(const Offset(1, 0), Offset(1, size.y), border);
    canvas.drawLine(Offset(size.x - 1, 0), Offset(size.x - 1, size.y), border);
    canvas.drawLine(const Offset(0, 1), Offset(size.x, 1), border);
    for (var i = 0; i < bricks.length; i++) {
      final brick = bricks[i];
      if (!brick.exists || brick.isDestroyed) continue;
      final hidden =
          brick.isStealth && (!_stealthVisible || hideStealthOverride);
      if (!hidden) _renderBrick(canvas, brick);
      if (hidden && _hiddenHitFlashes.containsKey(i)) {
        _renderHiddenHit(canvas, brick);
      }
      if (collisionDebug) {
        canvas.drawRect(
            _brickRect(brick),
            Paint()
              ..color = StealthColors.cyan.withOpacity(.7)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1);
      }
    }
    if (showTrajectory && phase == GamePhase.aiming && aimPoint != null) {
      _renderTrajectory(canvas);
    }
    final drawBalls =
        _balls.isEmpty ? [launchPosition] : _balls.map((b) => b.position);
    for (final position in drawBalls) {
      canvas.drawCircle(Offset(position.x, position.y), ballRadius + 2,
          Paint()..color = StealthColors.cyan.withOpacity(.18));
      canvas.drawCircle(Offset(position.x, position.y), ballRadius,
          Paint()..color = StealthColors.textPrimary);
      if (collisionDebug) {
        canvas.drawCircle(
            Offset(position.x, position.y),
            ballRadius,
            Paint()
              ..color = const Color(0xFFFF00FF)
              ..style = PaintingStyle.stroke);
      }
    }
    for (final p in _particles) {
      canvas.drawCircle(Offset(p.position.x, p.position.y), 2.2,
          Paint()..color = p.color.withOpacity(p.life.clamp(0, 1).toDouble()));
    }
    super.render(canvas);
  }

  void _renderBrick(Canvas canvas, Brick brick) {
    final rect = _brickRect(brick);
    final color = switch (brick.hitPoints) {
      1 => StealthColors.red,
      2 => const Color(0xFFFFA54B),
      3 => StealthColors.gold,
      _ => StealthColors.textSecondary
    };
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(5));
    canvas.drawRRect(rrect, Paint()..color = color);
    if (brick.isStealth) {
      canvas.drawRRect(
          rrect,
          Paint()
            ..color = StealthColors.violet
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
    }
    if (brick.specialType != BrickSpecialType.none) {
      _renderSpecialty(canvas, rect, brick.specialType);
    }
    final paragraph = (ParagraphBuilder(
            ParagraphStyle(textAlign: TextAlign.center, fontSize: 11))
          ..pushStyle(TextStyle(
              color: const Color(0xFF111827), fontWeight: FontWeight.w700))
          ..addText('${brick.hitPoints}'))
        .build()
      ..layout(ParagraphConstraints(width: rect.width));
    canvas.drawParagraph(paragraph,
        Offset(rect.left, rect.top + (rect.height - paragraph.height) / 2));
  }

  void _renderSpecialty(Canvas canvas, Rect rect, BrickSpecialType type) {
    final symbol = SpecialtyBrickCatalog.byType(type).symbol;
    canvas.drawRRect(
        RRect.fromRectAndRadius(rect.deflate(2), const Radius.circular(4)),
        Paint()
          ..color = const Color(0xFFFFFFFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
    final paragraph = (ParagraphBuilder(
            ParagraphStyle(textAlign: TextAlign.right, fontSize: 9))
          ..pushStyle(TextStyle(
              color: const Color(0xFF111827), fontWeight: FontWeight.w700))
          ..addText(symbol))
        .build()
      ..layout(ParagraphConstraints(width: rect.width - 3));
    canvas.drawParagraph(paragraph, Offset(rect.left, rect.top + 1));
  }

  void _renderHiddenHit(Canvas canvas, Brick brick) {
    final rect = _brickRect(brick);
    canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(5)),
        Paint()
          ..color = StealthColors.violet.withOpacity(.9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3);
  }

  void _renderTrajectory(Canvas canvas) {
    final direction = aimPoint! - launchPosition;
    if (direction.y >= -15 || direction.length < 25) return;
    direction.normalize();
    if (direction.y > -.18) direction.y = -.18;
    direction.normalize();
    var position = launchPosition.clone();
    var velocity = direction * 12;
    final steps = equippedPower == PowerId.trajectoryPlus && !isDaily
        ? trajectorySteps * 2
        : trajectorySteps;
    final paint = Paint()..color = StealthColors.cyan.withOpacity(.72);
    for (var step = 0; step < steps; step++) {
      position += velocity;
      if (position.x <= ballRadius || position.x >= size.x - ballRadius) {
        velocity.x = -velocity.x;
        position.x =
            position.x.clamp(ballRadius, size.x - ballRadius).toDouble();
      }
      if (position.y <= ballRadius) {
        velocity.y = -velocity.y;
        position.y = ballRadius;
      }
      if (step % 4 == 0) {
        canvas.drawCircle(Offset(position.x, position.y), 1.5, paint);
      }
      if (position.y > size.y) break;
      final hit = bricks
          .where((b) =>
              b.exists && !b.isDestroyed && (!b.isStealth || _stealthVisible))
          .any((b) =>
              _circleIntersectsRect(position, ballRadius, _brickRect(b)));
      if (hit) break;
    }
  }

  void _spawnParticles(Offset center, Color color, int count) {
    final random = Random(center.dx.toInt() ^ center.dy.toInt() ^ score);
    for (var i = 0; i < count; i++) {
      final angle = random.nextDouble() * pi * 2;
      final speed = 25 + random.nextDouble() * 55;
      _particles.add(_Particle(Vector2(center.dx, center.dy),
          Vector2(cos(angle), sin(angle)) * speed, color, .6));
    }
    if (_particles.length > 100) {
      _particles.removeRange(0, _particles.length - 100);
    }
  }

  void _updateParticles(double dt) {
    for (final p in _particles) {
      p.position += p.velocity * dt;
      p.life -= dt;
    }
    _particles.removeWhere((p) => p.life <= 0);
  }

  void _setPhase(GamePhase value) {
    phase = value;
    _notify();
  }

  void _notify() {
    snapshot.value = GameSnapshot(
      phase: phase,
      level: level,
      seed: seed,
      score: score,
      shotsRemaining: shotsRemaining,
      bricksRemaining: _remainingBricks,
      stealthRemaining: _remainingStealth,
      ballPosition: ballPosition.clone(),
      ballVelocity: ballVelocity.clone(),
      fps: _fps,
      worldName: worldName,
      specialtyRemaining: _remainingSpecialties,
      activeBalls: _balls.length,
      equippedPower: isDaily ? null : equippedPower,
      powerUsed: _powerUsed,
      currentCombo: _shotDestroyed,
      previewSecondsRemaining: phase == GamePhase.preview
          ? max(
                  0,
                  _previewWindow.expiresAt
                      .difference(DateTime.now())
                      .inMilliseconds) /
              1000
          : 0,
    );
  }

  void debugJumpToLevel(int value) => startLevel(level: max(1, value));
  void debugUseSeed(int value) => startLevel(level: level, seedOverride: value);
  void debugForceComplete() {
    if (phase == GamePhase.levelComplete) return;
    for (var i = 0; i < bricks.length; i++) {
      if (bricks[i].exists && !bricks[i].isDestroyed) {
        bricksDestroyedThisLevel++;
        if (bricks[i].isStealth) stealthDestroyedThisLevel++;
        bricks[i] = bricks[i].copyWith(hitPoints: 0);
      }
    }
    _completeLevel();
  }

  void debugForceGameOver() {
    shotsRemaining = 0;
    _balls.clear();
    _setPhase(GamePhase.gameOver);
    if (!_lossReported) {
      _lossReported = true;
      onGameOver(score);
    }
  }

  void debugSetShots(int value) {
    shotsRemaining = max(0, value);
    _notify();
  }

  void debugSkipPreview() {
    _previewWindow = PreviewWindow(expiresAt: DateTime.now());
    _finishPreview();
  }

  void debugForceSpecialty(BrickSpecialType type, {int count = 1}) {
    var remaining = count.clamp(1, 8);
    for (var index = 0; index < bricks.length && remaining > 0; index++) {
      final brick = bricks[index];
      final compatible = brick.exists &&
          !brick.isDestroyed &&
          (!brick.isStealth ||
              (type != BrickSpecialType.split &&
                  type != BrickSpecialType.extraShot));
      if (!compatible) continue;
      bricks[index] = brick.copyWith(specialType: type);
      remaining--;
    }
    _notify();
  }
}
