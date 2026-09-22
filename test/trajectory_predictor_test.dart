import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:stealth_breaker/game/systems/trajectory_predictor.dart';

void main() {
  const field = Size(300, 500);
  const launch = Offset(150, 450);
  const target = Rect.fromLTWH(220, 90, 40, 20);

  test('direct predicted trajectory reaches tutorial target', () {
    expect(
      TrajectoryPredictor.hitsTarget(
        launch: launch,
        aim: target.center,
        fieldSize: field,
        ballRadius: 5,
        target: target,
        blockers: const [],
      ),
      isTrue,
    );
  });

  test('trajectory aimed away does not reach tutorial target', () {
    expect(
      TrajectoryPredictor.hitsTarget(
        launch: launch,
        aim: const Offset(80, 90),
        fieldSize: field,
        ballRadius: 5,
        target: target,
        blockers: const [],
      ),
      isFalse,
    );
  });

  test('predicted wall rebound can reach tutorial target', () {
    expect(
      TrajectoryPredictor.hitsTarget(
        launch: launch,
        aim: const Offset(295, 180),
        fieldSize: field,
        ballRadius: 5,
        target: const Rect.fromLTWH(225, 85, 55, 32),
        blockers: const [],
      ),
      isTrue,
    );
  });
}
