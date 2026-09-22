import 'dart:math';
import 'dart:ui';

/// Lightweight trajectory sampling shared by aiming tutorials and gameplay-like
/// validation. Side and ceiling rebounds match the live board rules.
abstract final class TrajectoryPredictor {
  static bool hitsTarget({
    required Offset launch,
    required Offset aim,
    required Size fieldSize,
    required double ballRadius,
    required Rect target,
    required Iterable<Rect> blockers,
    int maxSteps = 1200,
    double stepDistance = 4,
  }) {
    var dx = aim.dx - launch.dx;
    var dy = aim.dy - launch.dy;
    final length = sqrt(dx * dx + dy * dy);
    if (dy > -15 || length < 25) return false;
    dx /= length;
    dy /= length;
    if (dy > -.18) {
      dy = -.18;
      final normalized = sqrt(dx * dx + dy * dy);
      dx /= normalized;
      dy /= normalized;
    }

    var position = launch;
    var velocity = Offset(dx * stepDistance, dy * stepDistance);
    for (var step = 0; step < maxSteps; step++) {
      position += velocity;
      if (position.dx <= ballRadius ||
          position.dx >= fieldSize.width - ballRadius) {
        velocity = Offset(-velocity.dx, velocity.dy);
        position = Offset(
          position.dx.clamp(ballRadius, fieldSize.width - ballRadius),
          position.dy,
        );
      }
      if (position.dy <= ballRadius) {
        velocity = Offset(velocity.dx, -velocity.dy);
        position = Offset(position.dx, ballRadius);
      }
      if (_circleIntersectsRect(position, ballRadius, target)) return true;
      if (blockers.any(
          (rect) => _circleIntersectsRect(position, ballRadius, rect))) {
        return false;
      }
      if (position.dy - ballRadius > fieldSize.height) return false;
    }
    return false;
  }

  static bool _circleIntersectsRect(
      Offset center, double radius, Rect rect) {
    final x = center.dx.clamp(rect.left, rect.right);
    final y = center.dy.clamp(rect.top, rect.bottom);
    final dx = center.dx - x;
    final dy = center.dy - y;
    return dx * dx + dy * dy <= radius * radius;
  }
}
