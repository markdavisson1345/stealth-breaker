import 'dart:async';

enum ProgressionEventType {
  brickHit,
  brickDestroyed,
  stealthBrickHit,
  stealthBrickDestroyed,
  specialtyBrickDestroyed,
  shotStarted,
  shotCompleted,
  levelCompleted,
  dailyChallengeCompleted,
  achievementCompleted,
  achievementPointsGranted,
  powerUpConsumed,
  dailyObjectiveCompleted,
}

class ProgressionEvent {
  const ProgressionEvent(this.type, [this.data = const {}]);
  final ProgressionEventType type;
  final Map<String, Object?> data;
}

class ProgressionEventBus {
  final _controller = StreamController<ProgressionEvent>.broadcast(sync: true);
  Stream<ProgressionEvent> get events => _controller.stream;
  void emit(ProgressionEvent event) => _controller.add(event);
  Future<void> dispose() => _controller.close();
}
