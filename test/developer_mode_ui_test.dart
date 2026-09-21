import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stealth_breaker/app/app_controller.dart';
import 'package:stealth_breaker/screens/settings_screen.dart';
import 'package:stealth_breaker/services/analytics_service.dart';

import 'support/developer_test_persistence.dart';

void main() {
  testWidgets('private toggle shows and hides Developer Tools', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 1000);
    addTearDown(tester.view.reset);
    final controller = AppController(
      persistence: MemoryDeveloperPersistence(),
      analytics: const NoopAnalyticsService(),
      developerModeAvailableForTesting: true,
    );
    await controller.initialize();
    await tester.pumpWidget(MaterialApp(
      home: SettingsScreen(controller: controller),
    ));

    expect(find.text('Developer Mode'), findsOneWidget);
    expect(find.text('Open Developer Tools'), findsNothing);
    final toggle = find.widgetWithText(SwitchListTile, 'Developer Mode');
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(find.text('Open Developer Tools'), findsOneWidget);

    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(find.text('Open Developer Tools'), findsNothing);
  });
}
