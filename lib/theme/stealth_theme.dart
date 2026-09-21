import 'package:flutter/material.dart';

abstract final class StealthColors {
  static const background = Color(0xFF080B12);
  static const surface = Color(0xFF121824);
  static const surfaceRaised = Color(0xFF1D2635);
  static const cyan = Color(0xFF36E5FF);
  static const cyanSoft = Color(0xFF8EF1FF);
  static const violet = Color(0xFF8B5CFF);
  static const gold = Color(0xFFFFD75E);
  static const red = Color(0xFFFF4D5D);
  static const textPrimary = Color(0xFFF5F8FC);
  static const textSecondary = Color(0xFF91A0B5);
  static const border = Color(0xFF2A3547);
  static const disabled = Color(0xFF536075);
}

abstract final class StealthSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

abstract final class StealthRadii {
  static const small = 8.0;
  static const medium = 14.0;
  static const large = 20.0;
}

abstract final class StealthMotion {
  static const quick = Duration(milliseconds: 120);
  static const standard = Duration(milliseconds: 220);
  static const reveal = Duration(milliseconds: 420);
}

abstract final class StealthTextStyles {
  static const display = TextStyle(
    color: StealthColors.textPrimary,
    fontWeight: FontWeight.w800,
    letterSpacing: 2.2,
    height: 1.05,
  );
  static const title = TextStyle(
    color: StealthColors.textPrimary,
    fontWeight: FontWeight.w700,
    letterSpacing: .8,
  );
  static const body = TextStyle(
    color: StealthColors.textPrimary,
    fontWeight: FontWeight.w400,
    height: 1.35,
  );
  static const label = TextStyle(
    color: StealthColors.textSecondary,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.1,
    fontSize: 12,
  );
}

abstract final class StealthTheme {
  static const cardShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(StealthRadii.medium)),
    side: BorderSide(color: StealthColors.border),
  );
  static const dialogShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(StealthRadii.large)),
    side: BorderSide(color: StealthColors.border),
  );

  static ThemeData get dark {
    const scheme = ColorScheme.dark(
      primary: StealthColors.cyan,
      onPrimary: StealthColors.background,
      secondary: StealthColors.violet,
      onSecondary: StealthColors.textPrimary,
      error: StealthColors.red,
      surface: StealthColors.surface,
      onSurface: StealthColors.textPrimary,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: StealthColors.background,
      canvasColor: StealthColors.background,
      splashColor: StealthColors.cyan.withOpacity(.10),
      highlightColor: StealthColors.cyan.withOpacity(.06),
      textTheme: const TextTheme(
        displayLarge: StealthTextStyles.display,
        displayMedium: StealthTextStyles.display,
        displaySmall: StealthTextStyles.display,
        headlineLarge: StealthTextStyles.display,
        headlineMedium: StealthTextStyles.display,
        headlineSmall: StealthTextStyles.title,
        titleLarge: StealthTextStyles.title,
        titleMedium: StealthTextStyles.title,
        titleSmall: StealthTextStyles.title,
        bodyLarge: StealthTextStyles.body,
        bodyMedium: StealthTextStyles.body,
        bodySmall: TextStyle(color: StealthColors.textSecondary, height: 1.3),
        labelLarge: StealthTextStyles.title,
        labelMedium: StealthTextStyles.label,
        labelSmall: StealthTextStyles.label,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: StealthColors.textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: StealthColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.4,
        ),
      ),
      dividerTheme: const DividerThemeData(color: StealthColors.border),
      iconTheme: const IconThemeData(color: StealthColors.textSecondary),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: StealthColors.cyan,
        linearTrackColor: StealthColors.surfaceRaised,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? StealthColors.background
                : StealthColors.textSecondary),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? StealthColors.cyan
                : StealthColors.surfaceRaised),
      ),
    );
  }
}
