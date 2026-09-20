import 'package:flutter/foundation.dart';

abstract interface class AnalyticsService {
  void event(String name, [Map<String, Object?> parameters = const {}]);
}

extension SemanticAnalytics on AnalyticsService {
  void sessionStart() => event('sessionStart');
  void screenView(String screen) => event('screenView', {'screen': screen});
  void levelStart(int level, {bool daily = false}) =>
      event('levelStart', {'level': level, 'daily': daily});
  void levelComplete(int level, int score, {bool daily = false}) =>
      event('levelComplete', {'level': level, 'score': score, 'daily': daily});
  void levelFailed(int level) => event('levelFailed', {'level': level});
  void shotSummary(Map<String, Object?> summary) =>
      event('shotSummary', summary);
  void dailyStart(String date) => event('dailyChallengeStart', {'date': date});
  void dailyComplete(String date, int streak) =>
      event('dailyChallengeComplete', {'date': date, 'streak': streak});
  void dailyReplay(String date) =>
      event('dailyChallengeReplay', {'date': date});
  void achievementComplete(String id, int points) =>
      event('achievementComplete', {'id': id, 'points': points});
  void powerUnlock(String id) => event('powerUnlock', {'id': id});
  void powerUse(String id) => event('powerUse', {'id': id});
  void streakChange(int from, int to) =>
      event('streakChange', {'from': from, 'to': to});
  void settingChange(String id, Object value) =>
      event('settingChange', {'id': id, 'value': value});
}

class DebugAnalyticsService implements AnalyticsService {
  const DebugAnalyticsService({required this.enabled});
  final bool enabled;

  @override
  void event(String name, [Map<String, Object?> parameters = const {}]) {
    if (enabled) debugPrint('[analytics] $name $parameters');
  }
}

class NoopAnalyticsService implements AnalyticsService {
  const NoopAnalyticsService();
  @override
  void event(String name, [Map<String, Object?> parameters = const {}]) {}
}
