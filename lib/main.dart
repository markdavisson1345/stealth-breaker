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
        persistence: BuildConfig.privateTestingBuild
            ? PrivateTestingPersistenceService()
            : SharedPreferencesPersistenceService(),
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

class StealthBreakerApp extends StatefulWidget {
  const StealthBreakerApp({super.key, required this.controller});
  final AppController controller;

  @override
  State<StealthBreakerApp> createState() => _StealthBreakerAppState();
}

class _StealthBreakerAppState extends State<StealthBreakerApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    unawaited(widget.controller.audio.handleLifecycleState(state));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(widget.controller.audio.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) => MaterialApp(
          debugShowCheckedModeBanner: false,
          title: GameIdentity.appName,
          theme: StealthTheme.dark,
          home: LaunchScreen(controller: widget.controller),
        ),
      );
}
