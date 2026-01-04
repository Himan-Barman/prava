import 'package:flutter/material.dart';

/// Prava Design System — Colors
/// Light mode is the primary experience.
/// Dark mode is fully supported as a first-class citizen.
class PravaColors {
  PravaColors._();

  /* ==========================================================================
   * LIGHT MODE (Primary)
   * ======================================================================= */

  // Backgrounds
  static const Color lightBgMain = Color(0xFFFFFFFF);   // App background
  static const Color lightBgSurface = Color(0xFFF6F6F6); // Cards, lists
  static const Color lightBgElevated = Color(0xFFFFFFFF); // Modals, sheets

  // Text
  static const Color lightTextPrimary = Color(0xFF0C0C0C);
  static const Color lightTextSecondary = Color(0xFF4A4A4A);
  static const Color lightTextTertiary = Color(0xFF8A8A8A);

  // Borders
  static const Color lightBorderSubtle = Color(0xFFE5E5E5);

  /* ==========================================================================
   * DARK MODE (Secondary, premium)
   * ======================================================================= */

  // Backgrounds
  static const Color darkBgMain = Color(0xFF0C0C0C);
  static const Color darkBgSurface = Color(0xFF1D1D1D);
  static const Color darkBgElevated = Color(0xFF292929);

  // Text
  static const Color darkTextPrimary = Color(0xFFF2F2F2);
  static const Color darkTextSecondary = Color(0xFFB3B3B3);
  static const Color darkTextTertiary = Color(0xFF7A7A7A);

  // Borders
  static const Color darkBorderSubtle = Color(0xFF2E2E2E);

  /* ==========================================================================
   * BRAND & STATES (Shared)
   * ======================================================================= */

  // Brand / Accent
  static const Color accentPrimary = Color(0xFF5B8CFF);
  static const Color accentMuted = Color(0xFF8FA9FF);

  // States
  static const Color success = Color(0xFF3CCB7F);
  static const Color warning = Color(0xFFF4C430);
  static const Color error = Color(0xFFE5533D);

  /* ==========================================================================
   * THEME HELPERS (Material-friendly)
   * ======================================================================= */

  // Light theme bindings
  static const Color lightPrimary = accentPrimary;
  static const Color lightScaffoldBackground = lightBgMain;
  static const Color lightSurface = lightBgSurface;

  // Dark theme bindings
  static const Color darkPrimary = accentPrimary;
  static const Color darkScaffoldBackground = darkBgMain;
  static const Color darkSurface = darkBgSurface;
}
