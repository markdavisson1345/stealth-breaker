import 'package:flame/components.dart';

import '../models/power.dart';

enum GamePhase {
  loading,
  preview,
  aiming,
  firing,
  paused,
  levelComplete,
  gameOver
}

class GameSnapshot {
  const GameSnapshot({
    required this.phase,
    required this.level,
    required this.seed,
    required this.score,
    required this.shotsRemaining,
    required this.bricksRemaining,
    required this.stealthRemaining,
    required this.ballPosition,
    required this.ballVelocity,
    required this.fps,
    required this.worldName,
    required this.specialtyRemaining,
    required this.activeBalls,
    required this.equippedPower,
    required this.powerUsed,
    required this.currentCombo,
    required this.previewSecondsRemaining,
  });

  final GamePhase phase;
  final int level;
  final int seed;
  final int score;
  final int shotsRemaining;
  final int bricksRemaining;
  final int stealthRemaining;
  final Vector2 ballPosition;
  final Vector2 ballVelocity;
  final double fps;
  final String worldName;
  final int specialtyRemaining;
  final int activeBalls;
  final PowerId? equippedPower;
  final bool powerUsed;
  final int currentCombo;
  final double previewSecondsRemaining;

  bool get canPause => phase == GamePhase.aiming || phase == GamePhase.firing;
  bool get canAim => phase == GamePhase.aiming;
}
