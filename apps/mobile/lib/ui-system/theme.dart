import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'colors.dart';
import 'typography.dart';

class PravaTheme {
  static const PageTransitionsTheme _cupertinoTransitions =
      PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
          TargetPlatform.fuchsia: CupertinoPageTransitionsBuilder(),
        },
      );

  static final light = _build(
    brightness: Brightness.light,
    tokens: PravaThemeColors.light,
  );

  static final dark = _build(
    brightness: Brightness.dark,
    tokens: PravaThemeColors.dark,
  );

  static ThemeData _build({
    required Brightness brightness,
    required PravaThemeColors tokens,
  }) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme(
      brightness: brightness,
      primary: tokens.brandPrimary,
      onPrimary: tokens.textInverse,
      secondary: tokens.brandContent,
      onSecondary: tokens.textInverse,
      error: tokens.statusError,
      onError: tokens.textInverse,
      surface: tokens.backgroundSurface,
      onSurface: tokens.textPrimary,
      surfaceContainerHighest: tokens.backgroundSurfaceRaised,
      outline: tokens.borderDefault,
      outlineVariant: tokens.borderSubtle,
      tertiary: tokens.premiumContent,
      onTertiary: isDark ? PravaColors.graphite1000 : PravaColors.graphite0,
    );

    final textTheme = TextTheme(
      headlineLarge: PravaTypography.h1.copyWith(color: tokens.textPrimary),
      headlineMedium: PravaTypography.h2.copyWith(color: tokens.textPrimary),
      titleLarge: PravaTypography.h2.copyWith(color: tokens.textPrimary),
      titleMedium: PravaTypography.bodyLarge.copyWith(
        color: tokens.textPrimary,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: PravaTypography.bodyLarge.copyWith(color: tokens.textPrimary),
      bodyMedium: PravaTypography.body.copyWith(color: tokens.textPrimary),
      bodySmall: PravaTypography.bodySmall.copyWith(
        color: tokens.textSecondary,
      ),
      labelLarge: PravaTypography.button.copyWith(color: tokens.textPrimary),
      labelMedium: PravaTypography.caption.copyWith(
        color: tokens.textSecondary,
      ),
    );

    OutlineInputBorder inputBorder(Color color, [double width = 1]) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: color, width: width),
      );
    }

    return ThemeData(
      brightness: brightness,
      fontFamily: PravaTypography.fontFamily,
      scaffoldBackgroundColor: tokens.backgroundCanvas,
      colorScheme: scheme,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      extensions: <ThemeExtension<dynamic>>[tokens],
      pageTransitionsTheme: _cupertinoTransitions,
      useMaterial3: true,
      dividerColor: tokens.divider,
      disabledColor: tokens.textDisabled,
      splashColor: tokens.brandContainer.withValues(alpha: isDark ? 0.16 : 0.3),
      highlightColor: tokens.backgroundHover,
      focusColor: tokens.focusRing,
      hoverColor: tokens.backgroundHover,
      appBarTheme: AppBarTheme(
        backgroundColor: tokens.backgroundSurface,
        foregroundColor: tokens.textPrimary,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: tokens.iconPrimary),
        titleTextStyle: PravaTypography.h2.copyWith(
          color: tokens.textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: tokens.backgroundSurface,
        selectedItemColor: tokens.brandContent,
        unselectedItemColor: tokens.iconSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: tokens.backgroundSurface,
        indicatorColor: tokens.brandContainer,
        surfaceTintColor: Colors.transparent,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? tokens.brandContent : tokens.iconSecondary,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return PravaTypography.caption.copyWith(
            color: selected ? tokens.brandContent : tokens.textTertiary,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          );
        }),
      ),
      iconTheme: IconThemeData(color: tokens.iconPrimary),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tokens.backgroundSurfaceSubtle,
        hoverColor: tokens.backgroundHover,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
        hintStyle: PravaTypography.body.copyWith(color: tokens.textTertiary),
        labelStyle: PravaTypography.body.copyWith(color: tokens.textSecondary),
        errorStyle: PravaTypography.caption.copyWith(color: tokens.statusError),
        prefixIconColor: tokens.iconSecondary,
        suffixIconColor: tokens.iconSecondary,
        border: inputBorder(tokens.borderDefault),
        enabledBorder: inputBorder(tokens.borderDefault),
        focusedBorder: inputBorder(tokens.focusBorder, 1.4),
        errorBorder: inputBorder(tokens.statusError),
        focusedErrorBorder: inputBorder(tokens.statusError, 1.4),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: tokens.brandPrimary,
        selectionColor: tokens.brandContainer,
        selectionHandleColor: tokens.brandPrimary,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: tokens.brandPrimary,
          foregroundColor: tokens.textInverse,
          disabledBackgroundColor: tokens.backgroundPressed,
          disabledForegroundColor: tokens.textDisabled,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: PravaTypography.button.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: tokens.textPrimary,
          side: BorderSide(color: tokens.borderDefault),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: tokens.brandContent,
          textStyle: PravaTypography.button.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: tokens.backgroundSurfaceSubtle,
        selectedColor: tokens.brandContainer,
        disabledColor: tokens.backgroundPressed,
        side: BorderSide(color: tokens.borderSubtle),
        labelStyle: PravaTypography.caption.copyWith(
          color: tokens.textSecondary,
          fontWeight: FontWeight.w600,
        ),
        secondaryLabelStyle: PravaTypography.caption.copyWith(
          color: tokens.brandContent,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return tokens.textDisabled;
          if (states.contains(WidgetState.selected)) {
            return isDark ? PravaColors.graphite1000 : PravaColors.graphite0;
          }
          return tokens.backgroundSurfaceRaised;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return tokens.backgroundPressed;
          }
          if (states.contains(WidgetState.selected)) return tokens.brandPrimary;
          return isDark ? PravaColors.graphite700 : PravaColors.graphite300;
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return tokens.brandPrimary;
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(tokens.textInverse),
        side: BorderSide(color: tokens.borderStrong),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return tokens.brandPrimary;
          return tokens.iconSecondary;
        }),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: isDark
            ? tokens.backgroundSurfaceRaised
            : tokens.backgroundSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDark
            ? tokens.backgroundSurfaceSubtle
            : tokens.backgroundSurface,
        modalBackgroundColor: isDark
            ? tokens.backgroundSurfaceSubtle
            : tokens.backgroundSurface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: tokens.backgroundSurfaceRaised,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: tokens.borderSubtle),
        ),
        textStyle: PravaTypography.body.copyWith(color: tokens.textPrimary),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: tokens.textPrimary,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: PravaTypography.caption.copyWith(color: tokens.textInverse),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: tokens.backgroundSurfaceRaised,
        contentTextStyle: PravaTypography.body.copyWith(
          color: tokens.textPrimary,
        ),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: tokens.borderSubtle),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: tokens.brandPrimary,
        linearTrackColor: tokens.backgroundPressed,
        circularTrackColor: tokens.backgroundPressed,
      ),
    );
  }
}
