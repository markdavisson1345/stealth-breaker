import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stealth_breaker/app/app_controller.dart';
import 'package:stealth_breaker/config/build_config.dart';
import 'package:stealth_breaker/screens/settings_screen.dart';
import 'package:stealth_breaker/services/analytics_service.dart';

import 'support/developer_test_persistence.dart';

void main() {
  testWidgets('public build omits Developer Mode and tools', (tester) async {
    expect(BuildConfig.privateTestingBuild, isFalse);
    final controller = AppController(
      persistence: MemoryDeveloperPersistence(),
      analytics: const NoopAnalyticsService(),
    );
    await controller.initialize();
    await tester.pumpWidget(MaterialApp(
      home: SettingsScreen(controller: controller),
    ));
    expect(find.text('Developer Mode'), findsNothing);
    expect(find.text('Open Developer Tools'), findsNothing);
  });
}
