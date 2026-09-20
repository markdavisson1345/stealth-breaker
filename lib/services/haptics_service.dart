import 'package:flutter/services.dart';

abstract interface class HapticsService {
  bool get enabled;
  set enabled(bool value);
  Future<void> light();
  Future<void> medium();
  Future<void> success();
}

class PlatformHapticsService implements HapticsService {
  PlatformHapticsService({bool enabled = true}) : _enabled = enabled;
  bool _enabled;
  @override
  bool get enabled => _enabled;
  @override
  set enabled(bool value) => _enabled = value;
  @override
  Future<void> light() =>
      _enabled ? HapticFeedback.lightImpact() : Future.value();
  @override
  Future<void> medium() =>
      _enabled ? HapticFeedback.mediumImpact() : Future.value();
  @override
  Future<void> success() =>
      _enabled ? HapticFeedback.mediumImpact() : Future.value();
}

class NoopHapticsService implements HapticsService {
  NoopHapticsService({this.enabled = true});
  @override
  bool enabled;
  @override
  Future<void> light() async {}
  @override
  Future<void> medium() async {}
  @override
  Future<void> success() async {}
}
