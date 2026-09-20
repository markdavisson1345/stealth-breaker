import 'dart:async';

import 'package:flutter/material.dart';

import 'app/app_controller.dart';
import 'config/build_config.dart';
import 'config/game_identity.dart';
import 'screens/launch_screen.dart';
import 'services/analytics_service.dart';
import 'services/audio_service.dart';
import 'services/haptics_service.dart';
import 'services/persistence_service.dart';
import 'theme/stealth_theme.dart';

Future<void> main() async {
  await runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      final controller = AppController(
        persistence: SharedPreferencesPersistenceService(),
        analytics: const DebugAnalyticsService(
          enabled: BuildConfig.verboseLogging,
        ),
        audio: AudioplayersAudioService(),
        haptics: PlatformHapticsService(),
      );
      await controller.initialize();
      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        if (BuildConfig.verboseLogging) {
          debugPrintStack(stackTrace: details.stack);
        }
      };
      runApp(StealthBreakerApp(controller: controller));
    },
    (error, stack) {
      if (BuildConfig.verboseLogging) {
        debugPrint('Uncaught error: $error\n$stack');
      }
    },
  );
}

class StealthBreakerApp extends StatelessWidget {
  const StealthBreakerApp({super.key, required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: controller,
        builder: (context, _) => MaterialApp(
          debugShowCheckedModeBanner: false,
          title: GameIdentity.appName,
          theme: StealthTheme.dark,
          home: LaunchScreen(controller: controller),
        ),
      );
}
