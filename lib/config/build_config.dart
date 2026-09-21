import 'package:flutter/foundation.dart';

abstract final class BuildConfig {
  static const bool privateTestingBuild = bool.fromEnvironment(
    'STEALTH_PRIVATE_BUILD',
    defaultValue: false,
  );
  static const bool developerTools = bool.fromEnvironment(
    'STEALTH_DEBUG_TOOLS',
    defaultValue: privateTestingBuild || kDebugMode,
  );
  static const bool verboseLogging = bool.fromEnvironment(
    'STEALTH_VERBOSE_LOGGING',
    defaultValue: kDebugMode,
  );
}
