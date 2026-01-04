import 'package:flutter/material.dart';
import 'colors.dart';
import 'typography.dart';

class PravaTheme {
  static const PageTransitionsTheme _cupertinoTransitions =
      PageTransitionsTheme(
    builders: <TargetPlatform, PageTransitionsBuilder>{
      TargetPlatform.android: const CupertinoPageTransitionsBuilder(),
      TargetPlatform.iOS: const CupertinoPageTransitionsBuilder(),
      TargetPlatform.macOS: const CupertinoPageTransitionsBuilder(),
      TargetPlatform.windows: const CupertinoPageTransitionsBuilder(),
      TargetPlatform.linux: const CupertinoPageTransitionsBuilder(),
      TargetPlatform.fuchsia: const CupertinoPageTransitionsBuilder(),
    },
  );

  static final light = ThemeData(
    brightness: Brightness.light,
    fontFamily: PravaTypography.fontFamily,
    scaffoldBackgroundColor: PravaColors.lightScaffoldBackground,
    pageTransitionsTheme: _cupertinoTransitions,
    colorScheme: const ColorScheme.light(
      primary: PravaColors.accentPrimary,
      surface: PravaColors.lightBgSurface,
      error: PravaColors.error,
    ),
    textTheme: TextTheme(
      headlineLarge: PravaTypography.h1.copyWith(
        color: PravaColors.lightTextPrimary,
      ),
      headlineMedium: PravaTypography.h2.copyWith(
        color: PravaColors.lightTextPrimary,
      ),
      bodyLarge: PravaTypography.bodyLarge.copyWith(
        color: PravaColors.lightTextPrimary,
      ),
      bodyMedium: PravaTypography.body.copyWith(
        color: PravaColors.lightTextPrimary,
      ),
      bodySmall: PravaTypography.bodySmall.copyWith(
        color: PravaColors.lightTextSecondary,
      ),
      labelLarge: PravaTypography.button.copyWith(
        color: PravaColors.lightTextPrimary,
      ),
    ),
    useMaterial3: true,
  );

  static final dark = ThemeData(
    brightness: Brightness.dark,
    fontFamily: PravaTypography.fontFamily,
    scaffoldBackgroundColor: PravaColors.darkScaffoldBackground,
    pageTransitionsTheme: _cupertinoTransitions,
    colorScheme: const ColorScheme.dark(
      primary: PravaColors.accentPrimary,
      surface: PravaColors.darkBgSurface,
      error: PravaColors.error,
    ),
    textTheme: TextTheme(
      headlineLarge: PravaTypography.h1.copyWith(
        color: PravaColors.darkTextPrimary,
      ),
      headlineMedium: PravaTypography.h2.copyWith(
        color: PravaColors.darkTextPrimary,
      ),
      bodyLarge: PravaTypography.bodyLarge.copyWith(
        color: PravaColors.darkTextPrimary,
      ),
      bodyMedium: PravaTypography.body.copyWith(
        color: PravaColors.darkTextPrimary,
      ),
      bodySmall: PravaTypography.bodySmall.copyWith(
        color: PravaColors.darkTextSecondary,
      ),
      labelLarge: PravaTypography.button.copyWith(
        color: PravaColors.darkTextPrimary,
      ),
    ),
    useMaterial3: true,
  );
}
