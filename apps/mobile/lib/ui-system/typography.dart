import 'package:flutter/material.dart';

/// Prava Premium Typography System
///
/// Rules:
/// 1. UI code should use these named roles instead of creating ad hoc styles.
/// 2. Typography remains color-independent. Apply colors from PravaColors,
///    PravaThemeColors, ThemeData, or component state with `copyWith(color: ...)`.
/// 3. Role names describe intent: use `feedText` for post body, `username` for
///    visible social names, `chatMessage` for bubbles, `statNumber` for profile
///    metrics, `navLabel` for bottom navigation, and so on.
class PravaTypography {
  PravaTypography._();

  static const String fontFamily = 'Inter';

  static const List<String> fontFamilyFallback = <String>[
    'Roboto',
    'Noto Sans',
    'Arial',
  ];

  /* --------------------------------------------------------------------------
   * Display / Hero
   * Used for onboarding, empty states, premium landing sections.
   * ----------------------------------------------------------------------- */

  static const TextStyle displayLarge = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 34,
    fontWeight: FontWeight.w800,
    height: 1.10,
    letterSpacing: -1.10,
  );

  static const TextStyle displayMedium = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 30,
    fontWeight: FontWeight.w800,
    height: 1.12,
    letterSpacing: -0.90,
  );

  static const TextStyle displaySmall = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 26,
    fontWeight: FontWeight.w700,
    height: 1.16,
    letterSpacing: -0.70,
  );

  /* --------------------------------------------------------------------------
   * Titles
   * Used for screen titles, app bars, profile names, section headings.
   * ----------------------------------------------------------------------- */

  static const TextStyle titleLarge = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 1.20,
    letterSpacing: -0.55,
  );

  static const TextStyle titleMedium = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    height: 1.23,
    letterSpacing: -0.40,
  );

  static const TextStyle titleSmall = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.25,
    letterSpacing: -0.25,
  );

  static const TextStyle sectionTitle = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    height: 1.25,
    letterSpacing: -0.15,
  );

  static const TextStyle cardTitle = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 15,
    fontWeight: FontWeight.w700,
    height: 1.25,
    letterSpacing: -0.10,
  );

  /* --------------------------------------------------------------------------
   * Body
   * Used for descriptions, settings text, general readable content.
   * ----------------------------------------------------------------------- */

  static const TextStyle bodyLarge = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 17,
    fontWeight: FontWeight.w400,
    height: 1.46,
    letterSpacing: -0.05,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.45,
    letterSpacing: -0.02,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.38,
    letterSpacing: 0,
  );

  static const TextStyle description = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.42,
    letterSpacing: -0.01,
  );

  static const TextStyle secondaryDescription = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.38,
    letterSpacing: 0,
  );

  /* --------------------------------------------------------------------------
   * Social Feed
   * Used inside feed cards, comments, replies, reposts, composer.
   * ----------------------------------------------------------------------- */

  static const TextStyle feedText = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 15.5,
    fontWeight: FontWeight.w400,
    height: 1.48,
    letterSpacing: -0.03,
  );

  static const TextStyle feedTextLarge = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 17,
    fontWeight: FontWeight.w400,
    height: 1.50,
    letterSpacing: -0.05,
  );

  static const TextStyle username = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 15,
    fontWeight: FontWeight.w700,
    height: 1.22,
    letterSpacing: -0.12,
  );

  static const TextStyle userHandle = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.22,
    letterSpacing: -0.02,
  );

  static const TextStyle timestamp = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.20,
    letterSpacing: 0.08,
  );

  static const TextStyle postMeta = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 12.5,
    fontWeight: FontWeight.w500,
    height: 1.22,
    letterSpacing: 0.04,
  );

  static const TextStyle engagementCount = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    height: 1.20,
    letterSpacing: -0.05,
  );

  static const TextStyle commentText = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 14.5,
    fontWeight: FontWeight.w400,
    height: 1.44,
    letterSpacing: -0.02,
  );

  static const TextStyle replyText = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.42,
    letterSpacing: -0.01,
  );

  static const TextStyle composerText = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.45,
    letterSpacing: -0.03,
  );

  /* --------------------------------------------------------------------------
   * Chat
   * Used for DM, group chats, previews, statuses.
   * ----------------------------------------------------------------------- */

  static const TextStyle chatMessage = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 15.5,
    fontWeight: FontWeight.w400,
    height: 1.42,
    letterSpacing: -0.02,
  );

  static const TextStyle chatPreview = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.35,
    letterSpacing: -0.01,
  );

  static const TextStyle chatName = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 15,
    fontWeight: FontWeight.w700,
    height: 1.22,
    letterSpacing: -0.10,
  );

  static const TextStyle groupName = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 15.5,
    fontWeight: FontWeight.w700,
    height: 1.22,
    letterSpacing: -0.12,
  );

  static const TextStyle typingIndicator = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 1.30,
    letterSpacing: 0,
  );

  static const TextStyle messageTimestamp = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: 1.15,
    letterSpacing: 0.08,
  );

  static const TextStyle messageStatus = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 11.5,
    fontWeight: FontWeight.w500,
    height: 1.15,
    letterSpacing: 0.08,
  );

  static const TextStyle systemMessage = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 12.5,
    fontWeight: FontWeight.w500,
    height: 1.30,
    letterSpacing: 0.04,
  );

  /* --------------------------------------------------------------------------
   * Navigation
   * Used for bottom nav, tabs, menus, app bar actions.
   * ----------------------------------------------------------------------- */

  static const TextStyle navLabel = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 11.5,
    fontWeight: FontWeight.w600,
    height: 1.15,
    letterSpacing: 0.10,
  );

  static const TextStyle tabLabel = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 14,
    fontWeight: FontWeight.w700,
    height: 1.18,
    letterSpacing: -0.02,
  );

  static const TextStyle activeTabLabel = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 14,
    fontWeight: FontWeight.w800,
    height: 1.18,
    letterSpacing: -0.04,
  );

  static const TextStyle menuLabel = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.25,
    letterSpacing: 0,
  );

  static const TextStyle appBarAction = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 14,
    fontWeight: FontWeight.w700,
    height: 1.20,
    letterSpacing: 0.02,
  );

  /* --------------------------------------------------------------------------
   * Buttons
   * Used for CTA, primary, secondary, text buttons, chips.
   * ----------------------------------------------------------------------- */

  static const TextStyle buttonLarge = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 15,
    fontWeight: FontWeight.w700,
    height: 1.20,
    letterSpacing: 0.02,
  );

  static const TextStyle buttonMedium = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 14,
    fontWeight: FontWeight.w700,
    height: 1.20,
    letterSpacing: 0.03,
  );

  static const TextStyle buttonSmall = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 12.5,
    fontWeight: FontWeight.w700,
    height: 1.18,
    letterSpacing: 0.08,
  );

  static const TextStyle textButton = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 14,
    fontWeight: FontWeight.w700,
    height: 1.20,
    letterSpacing: 0.02,
  );

  static const TextStyle chipLabel = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 12.5,
    fontWeight: FontWeight.w600,
    height: 1.15,
    letterSpacing: 0.08,
  );

  /* --------------------------------------------------------------------------
   * Forms / Inputs
   * Used for search, composer, chat input, settings forms.
   * ----------------------------------------------------------------------- */

  static const TextStyle inputText = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.35,
    letterSpacing: -0.02,
  );

  static const TextStyle inputPlaceholder = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.35,
    letterSpacing: -0.02,
  );

  static const TextStyle fieldLabel = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    height: 1.22,
    letterSpacing: 0.02,
  );

  static const TextStyle helperText = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.30,
    letterSpacing: 0.04,
  );

  static const TextStyle errorText = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    height: 1.30,
    letterSpacing: 0.02,
  );

  static const TextStyle searchText = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.30,
    letterSpacing: -0.02,
  );

  /* --------------------------------------------------------------------------
   * Profile / Stats
   * Used for profile headers, bios, followers, following, badges.
   * ----------------------------------------------------------------------- */

  static const TextStyle profileName = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 24,
    fontWeight: FontWeight.w800,
    height: 1.18,
    letterSpacing: -0.55,
  );

  static const TextStyle profileHandle = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.22,
    letterSpacing: -0.02,
  );

  static const TextStyle bioText = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 14.5,
    fontWeight: FontWeight.w400,
    height: 1.45,
    letterSpacing: -0.02,
  );

  static const TextStyle statNumber = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 18,
    fontWeight: FontWeight.w800,
    height: 1.12,
    letterSpacing: -0.35,
  );

  static const TextStyle statLabel = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.20,
    letterSpacing: 0.05,
  );

  static const TextStyle badge = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    height: 1.10,
    letterSpacing: 0.16,
  );

  /* --------------------------------------------------------------------------
   * Notifications
   * ----------------------------------------------------------------------- */

  static const TextStyle notificationTitle = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 14.5,
    fontWeight: FontWeight.w700,
    height: 1.28,
    letterSpacing: -0.04,
  );

  static const TextStyle notificationBody = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.38,
    letterSpacing: -0.01,
  );

  static const TextStyle notificationActor = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 14.5,
    fontWeight: FontWeight.w700,
    height: 1.25,
    letterSpacing: -0.05,
  );

  static const TextStyle notificationTimestamp = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.20,
    letterSpacing: 0.06,
  );

  /* --------------------------------------------------------------------------
   * Settings / System UI
   * ----------------------------------------------------------------------- */

  static const TextStyle settingTitle = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.28,
    letterSpacing: -0.04,
  );

  static const TextStyle settingSubtitle = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.35,
    letterSpacing: 0,
  );

  static const TextStyle settingGroupHeading = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 12,
    fontWeight: FontWeight.w800,
    height: 1.18,
    letterSpacing: 0.35,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 11,
    fontWeight: FontWeight.w400,
    height: 1.25,
    letterSpacing: 0.15,
  );

  static const TextStyle tinyLabel = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 10.5,
    fontWeight: FontWeight.w600,
    height: 1.15,
    letterSpacing: 0.18,
  );

  static const TextStyle tooltip = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.25,
    letterSpacing: 0.04,
  );

  static const TextStyle toast = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 13.5,
    fontWeight: FontWeight.w600,
    height: 1.25,
    letterSpacing: -0.01,
  );

  static const TextStyle snackbarText = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 13.5,
    fontWeight: FontWeight.w500,
    height: 1.30,
    letterSpacing: -0.01,
  );

  static const TextStyle dialogTitle = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 20,
    fontWeight: FontWeight.w800,
    height: 1.20,
    letterSpacing: -0.35,
  );

  static const TextStyle dialogBody = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 14.5,
    fontWeight: FontWeight.w400,
    height: 1.45,
    letterSpacing: -0.01,
  );

  static const TextStyle dialogAction = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 14,
    fontWeight: FontWeight.w700,
    height: 1.20,
    letterSpacing: 0.02,
  );

  static const TextStyle logoMark = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 32,
    fontWeight: FontWeight.w800,
    height: 1,
    letterSpacing: 1.2,
  );

  static const TextStyle emojiReaction = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 22,
    fontWeight: FontWeight.w500,
    height: 1,
    letterSpacing: 0,
  );

  static const TextStyle emojiReactionLarge = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 26,
    fontWeight: FontWeight.w500,
    height: 1,
    letterSpacing: 0,
  );

  /// Splash logo scales with animation size, but the typography decision stays
  /// centralized here instead of being recreated in the splash widget.
  static TextStyle splashLogo(double size) {
    return logoMark.copyWith(fontSize: size, letterSpacing: size * 0.03);
  }

  /* --------------------------------------------------------------------------
   * Compatibility aliases
   * Kept for existing call sites while all styles remain centrally defined.
   * Prefer the role-based names above for new UI.
   * ----------------------------------------------------------------------- */

  static const TextStyle h1 = displayMedium;
  static const TextStyle h2 = titleLarge;
  static const TextStyle h3 = titleSmall;
  static const TextStyle body = bodyMedium;
  static const TextStyle label = chipLabel;
  static const TextStyle button = buttonMedium;

  /* --------------------------------------------------------------------------
   * Flutter TextTheme Mapping
   * Use this inside ThemeData.textTheme.
   * ----------------------------------------------------------------------- */

  static const TextTheme textTheme = TextTheme(
    displayLarge: displayLarge,
    displayMedium: displayMedium,
    displaySmall: displaySmall,
    headlineLarge: titleLarge,
    headlineMedium: titleMedium,
    headlineSmall: titleSmall,
    titleLarge: titleLarge,
    titleMedium: titleMedium,
    titleSmall: titleSmall,
    bodyLarge: bodyLarge,
    bodyMedium: bodyMedium,
    bodySmall: bodySmall,
    labelLarge: buttonMedium,
    labelMedium: chipLabel,
    labelSmall: tinyLabel,
  );
}
