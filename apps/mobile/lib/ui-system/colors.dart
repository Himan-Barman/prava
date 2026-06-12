import 'package:flutter/material.dart';

/// Prava Obsidian Sapphire color system.
///
/// Keep raw scale values centralized here. Components should prefer
/// `context.pravaColors` semantic tokens or the compatibility aliases below.
class PravaColors {
  PravaColors._();

  // Graphite neutral scale.
  static const Color graphite0 = Color(0xFFFFFFFF);
  static const Color graphite25 = Color(0xFFFCFDFE);
  static const Color graphite50 = Color(0xFFF7F9FC);
  static const Color graphite100 = Color(0xFFEFF3F7);
  static const Color graphite200 = Color(0xFFE1E7EE);
  static const Color graphite300 = Color(0xFFC9D2DD);
  static const Color graphite400 = Color(0xFF9AA6B4);
  static const Color graphite500 = Color(0xFF687485);
  static const Color graphite600 = Color(0xFF4F5B6A);
  static const Color graphite700 = Color(0xFF384453);
  static const Color graphite800 = Color(0xFF252F3B);
  static const Color graphite850 = Color(0xFF1B2531);
  static const Color graphite900 = Color(0xFF131B25);
  static const Color graphite950 = Color(0xFF0B1119);
  static const Color graphite1000 = Color(0xFF080D14);

  // Restrained royal sapphire brand scale.
  static const Color sapphire50 = Color(0xFFF3F6FF);
  static const Color sapphire100 = Color(0xFFE7EDFF);
  static const Color sapphire200 = Color(0xFFCCD9FF);
  static const Color sapphire300 = Color(0xFFA8BEFF);
  static const Color sapphire400 = Color(0xFF7E9FFF);
  static const Color sapphire500 = Color(0xFF5B7EFF);
  static const Color sapphire600 = Color(0xFF3D63F0);
  static const Color sapphire700 = Color(0xFF2C4FCC);
  static const Color sapphire800 = Color(0xFF263FA3);
  static const Color sapphire900 = Color(0xFF23377F);
  static const Color sapphire950 = Color(0xFF17234F);

  // Champagne gold premium scale.
  static const Color gold50 = Color(0xFFFFF9EC);
  static const Color gold100 = Color(0xFFFFF0C8);
  static const Color gold300 = Color(0xFFE8C16A);
  static const Color gold500 = Color(0xFFB5842F);
  static const Color gold700 = Color(0xFF74501C);
  static const Color gold900 = Color(0xFF493419);

  // Light semantic statuses.
  static const Color lightSuccess = Color(0xFF137A50);
  static const Color lightSuccessContainer = Color(0xFFEAF8F1);
  static const Color lightWarning = Color(0xFFA85F00);
  static const Color lightWarningContainer = Color(0xFFFFF5DF);
  static const Color lightError = Color(0xFFC23B52);
  static const Color lightErrorContainer = Color(0xFFFFF0F2);
  static const Color lightInfo = sapphire700;
  static const Color lightInfoContainer = sapphire50;

  // Dark semantic statuses.
  static const Color darkSuccess = Color(0xFF64DDA5);
  static const Color darkSuccessContainer = Color(0xFF123428);
  static const Color darkWarning = Color(0xFFF6C564);
  static const Color darkWarningContainer = Color(0xFF3B2A10);
  static const Color darkError = Color(0xFFFF8394);
  static const Color darkErrorContainer = Color(0xFF451A24);
  static const Color darkInfo = sapphire300;
  static const Color darkInfoContainer = sapphire950;

  // Light semantic tokens.
  static const Color lightBackgroundCanvas = graphite50;
  static const Color lightBackgroundSurface = graphite0;
  static const Color lightBackgroundSurfaceSubtle = graphite100;
  static const Color lightBackgroundSurfaceRaised = graphite25;
  static const Color lightBackgroundSurfaceInset = Color(0xFFF3F6F9);
  static const Color lightBackgroundHover = graphite100;
  static const Color lightBackgroundPressed = graphite200;

  static const Color lightTextPrimary = graphite900;
  static const Color lightTextSecondary = graphite600;
  static const Color lightTextTertiary = graphite500;
  static const Color lightTextDisabled = graphite400;
  static const Color lightTextInverse = graphite0;

  static const Color lightIconPrimary = graphite700;
  static const Color lightIconSecondary = graphite500;
  static const Color lightIconDisabled = graphite400;

  static const Color lightBorderSubtle = graphite200;
  static const Color lightBorderDefault = graphite300;
  static const Color lightBorderStrong = graphite400;
  static const Color lightDivider = graphite200;

  static const Color lightBrandPrimary = sapphire600;
  static const Color lightBrandPrimaryHover = sapphire700;
  static const Color lightBrandPrimaryPressed = sapphire800;
  static const Color lightBrandContainer = sapphire100;
  static const Color lightBrandContent = sapphire700;
  static const Color lightLinkDefault = sapphire700;

  static const Color lightOverlayModal = Color(0xA3131B25);
  static const Color lightShadowSoft = Color(0x0F0B1119);
  static const Color lightShadowMedium = Color(0x1F0B1119);
  static const Color lightSocialLikeActive = Color(0xFFD64263);
  static const Color lightSocialRepostActive = Color(0xFF14845D);
  static const Color lightPremiumContent = gold700;
  static const Color lightPremiumContainer = gold50;

  // Dark semantic tokens.
  static const Color darkBackgroundCanvas = graphite1000;
  static const Color darkBackgroundSurface = graphite950;
  static const Color darkBackgroundSurfaceSubtle = graphite900;
  static const Color darkBackgroundSurfaceRaised = graphite850;
  static const Color darkBackgroundSurfaceInset = Color(0xFF070B10);
  static const Color darkBackgroundHover = graphite850;
  static const Color darkBackgroundPressed = graphite800;

  static const Color darkTextPrimary = graphite50;
  static const Color darkTextSecondary = graphite300;
  static const Color darkTextTertiary = graphite400;
  static const Color darkTextDisabled = graphite500;
  static const Color darkTextInverse = graphite1000;

  static const Color darkIconPrimary = graphite300;
  static const Color darkIconSecondary = graphite400;
  static const Color darkIconDisabled = graphite500;

  static const Color darkBorderSubtle = graphite850;
  static const Color darkBorderDefault = graphite800;
  static const Color darkBorderStrong = graphite700;
  static const Color darkDivider = graphite850;

  static const Color darkBrandPrimary = sapphire400;
  static const Color darkBrandPrimaryHover = sapphire300;
  static const Color darkBrandPrimaryPressed = sapphire500;
  static const Color darkBrandContainer = sapphire950;
  static const Color darkBrandContent = sapphire300;
  static const Color darkLinkDefault = sapphire300;

  static const Color darkOverlayModal = Color(0xAD000000);
  static const Color darkShadowSoft = Color(0x3D000000);
  static const Color darkShadowMedium = Color(0x6B000000);
  static const Color darkSocialLikeActive = Color(0xFFFF7892);
  static const Color darkSocialRepostActive = Color(0xFF62D9A7);
  static const Color darkPremiumContent = gold300;
  static const Color darkPremiumContainer = gold900;

  // Compatibility aliases used throughout the existing mobile app.
  static const Color lightBgMain = lightBackgroundCanvas;
  static const Color lightBgSurface = lightBackgroundSurface;
  static const Color lightBgElevated = lightBackgroundSurfaceRaised;
  static const Color darkBgMain = darkBackgroundCanvas;
  static const Color darkBgSurface = darkBackgroundSurface;
  static const Color darkBgElevated = darkBackgroundSurfaceRaised;

  static const Color accentPrimary = lightBrandPrimary;
  static const Color accentMuted = sapphire300;
  static const Color success = lightSuccess;
  static const Color warning = lightWarning;
  static const Color error = lightError;

  static const Color lightPrimary = lightBrandPrimary;
  static const Color lightScaffoldBackground = lightBackgroundCanvas;
  static const Color lightSurface = lightBackgroundSurfaceSubtle;
  static const Color darkPrimary = darkBrandPrimary;
  static const Color darkScaffoldBackground = darkBackgroundCanvas;
  static const Color darkSurface = darkBackgroundSurfaceSubtle;
}

@immutable
class PravaThemeColors extends ThemeExtension<PravaThemeColors> {
  const PravaThemeColors({
    required this.backgroundCanvas,
    required this.backgroundSurface,
    required this.backgroundSurfaceSubtle,
    required this.backgroundSurfaceRaised,
    required this.backgroundSurfaceInset,
    required this.backgroundHover,
    required this.backgroundPressed,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textDisabled,
    required this.textInverse,
    required this.iconPrimary,
    required this.iconSecondary,
    required this.iconDisabled,
    required this.borderSubtle,
    required this.borderDefault,
    required this.borderStrong,
    required this.divider,
    required this.brandPrimary,
    required this.brandPrimaryHover,
    required this.brandPrimaryPressed,
    required this.brandContainer,
    required this.brandContent,
    required this.linkDefault,
    required this.focusBorder,
    required this.focusRing,
    required this.overlayModal,
    required this.shadowSoft,
    required this.shadowMedium,
    required this.statusSuccess,
    required this.statusSuccessContainer,
    required this.statusWarning,
    required this.statusWarningContainer,
    required this.statusError,
    required this.statusErrorContainer,
    required this.statusInfo,
    required this.statusInfoContainer,
    required this.socialLikeActive,
    required this.socialRepostActive,
    required this.premiumContent,
    required this.premiumContainer,
    required this.chatOwnBubble,
    required this.chatOwnText,
    required this.chatReceivedBubble,
    required this.chatReceivedText,
    required this.notificationUnread,
    required this.notificationRead,
    required this.skeletonBase,
    required this.skeletonShimmer,
  });

  final Color backgroundCanvas;
  final Color backgroundSurface;
  final Color backgroundSurfaceSubtle;
  final Color backgroundSurfaceRaised;
  final Color backgroundSurfaceInset;
  final Color backgroundHover;
  final Color backgroundPressed;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color textDisabled;
  final Color textInverse;
  final Color iconPrimary;
  final Color iconSecondary;
  final Color iconDisabled;
  final Color borderSubtle;
  final Color borderDefault;
  final Color borderStrong;
  final Color divider;
  final Color brandPrimary;
  final Color brandPrimaryHover;
  final Color brandPrimaryPressed;
  final Color brandContainer;
  final Color brandContent;
  final Color linkDefault;
  final Color focusBorder;
  final Color focusRing;
  final Color overlayModal;
  final Color shadowSoft;
  final Color shadowMedium;
  final Color statusSuccess;
  final Color statusSuccessContainer;
  final Color statusWarning;
  final Color statusWarningContainer;
  final Color statusError;
  final Color statusErrorContainer;
  final Color statusInfo;
  final Color statusInfoContainer;
  final Color socialLikeActive;
  final Color socialRepostActive;
  final Color premiumContent;
  final Color premiumContainer;
  final Color chatOwnBubble;
  final Color chatOwnText;
  final Color chatReceivedBubble;
  final Color chatReceivedText;
  final Color notificationUnread;
  final Color notificationRead;
  final Color skeletonBase;
  final Color skeletonShimmer;

  static const light = PravaThemeColors(
    backgroundCanvas: PravaColors.lightBackgroundCanvas,
    backgroundSurface: PravaColors.lightBackgroundSurface,
    backgroundSurfaceSubtle: PravaColors.lightBackgroundSurfaceSubtle,
    backgroundSurfaceRaised: PravaColors.lightBackgroundSurfaceRaised,
    backgroundSurfaceInset: PravaColors.lightBackgroundSurfaceInset,
    backgroundHover: PravaColors.lightBackgroundHover,
    backgroundPressed: PravaColors.lightBackgroundPressed,
    textPrimary: PravaColors.lightTextPrimary,
    textSecondary: PravaColors.lightTextSecondary,
    textTertiary: PravaColors.lightTextTertiary,
    textDisabled: PravaColors.lightTextDisabled,
    textInverse: PravaColors.lightTextInverse,
    iconPrimary: PravaColors.lightIconPrimary,
    iconSecondary: PravaColors.lightIconSecondary,
    iconDisabled: PravaColors.lightIconDisabled,
    borderSubtle: PravaColors.lightBorderSubtle,
    borderDefault: PravaColors.lightBorderDefault,
    borderStrong: PravaColors.lightBorderStrong,
    divider: PravaColors.lightDivider,
    brandPrimary: PravaColors.lightBrandPrimary,
    brandPrimaryHover: PravaColors.lightBrandPrimaryHover,
    brandPrimaryPressed: PravaColors.lightBrandPrimaryPressed,
    brandContainer: PravaColors.lightBrandContainer,
    brandContent: PravaColors.lightBrandContent,
    linkDefault: PravaColors.lightLinkDefault,
    focusBorder: PravaColors.lightBrandPrimary,
    focusRing: Color(0x383D63F0),
    overlayModal: PravaColors.lightOverlayModal,
    shadowSoft: PravaColors.lightShadowSoft,
    shadowMedium: PravaColors.lightShadowMedium,
    statusSuccess: PravaColors.lightSuccess,
    statusSuccessContainer: PravaColors.lightSuccessContainer,
    statusWarning: PravaColors.lightWarning,
    statusWarningContainer: PravaColors.lightWarningContainer,
    statusError: PravaColors.lightError,
    statusErrorContainer: PravaColors.lightErrorContainer,
    statusInfo: PravaColors.lightInfo,
    statusInfoContainer: PravaColors.lightInfoContainer,
    socialLikeActive: PravaColors.lightSocialLikeActive,
    socialRepostActive: PravaColors.lightSocialRepostActive,
    premiumContent: PravaColors.lightPremiumContent,
    premiumContainer: PravaColors.lightPremiumContainer,
    chatOwnBubble: PravaColors.lightBrandContainer,
    chatOwnText: PravaColors.lightTextPrimary,
    chatReceivedBubble: PravaColors.lightBackgroundSurface,
    chatReceivedText: PravaColors.lightTextPrimary,
    notificationUnread: PravaColors.lightInfoContainer,
    notificationRead: PravaColors.lightBackgroundSurface,
    skeletonBase: PravaColors.lightBackgroundSurfaceSubtle,
    skeletonShimmer: PravaColors.lightBackgroundPressed,
  );

  static const dark = PravaThemeColors(
    backgroundCanvas: PravaColors.darkBackgroundCanvas,
    backgroundSurface: PravaColors.darkBackgroundSurface,
    backgroundSurfaceSubtle: PravaColors.darkBackgroundSurfaceSubtle,
    backgroundSurfaceRaised: PravaColors.darkBackgroundSurfaceRaised,
    backgroundSurfaceInset: PravaColors.darkBackgroundSurfaceInset,
    backgroundHover: PravaColors.darkBackgroundHover,
    backgroundPressed: PravaColors.darkBackgroundPressed,
    textPrimary: PravaColors.darkTextPrimary,
    textSecondary: PravaColors.darkTextSecondary,
    textTertiary: PravaColors.darkTextTertiary,
    textDisabled: PravaColors.darkTextDisabled,
    textInverse: PravaColors.darkTextInverse,
    iconPrimary: PravaColors.darkIconPrimary,
    iconSecondary: PravaColors.darkIconSecondary,
    iconDisabled: PravaColors.darkIconDisabled,
    borderSubtle: PravaColors.darkBorderSubtle,
    borderDefault: PravaColors.darkBorderDefault,
    borderStrong: PravaColors.darkBorderStrong,
    divider: PravaColors.darkDivider,
    brandPrimary: PravaColors.darkBrandPrimary,
    brandPrimaryHover: PravaColors.darkBrandPrimaryHover,
    brandPrimaryPressed: PravaColors.darkBrandPrimaryPressed,
    brandContainer: PravaColors.darkBrandContainer,
    brandContent: PravaColors.darkBrandContent,
    linkDefault: PravaColors.darkLinkDefault,
    focusBorder: PravaColors.darkBrandPrimary,
    focusRing: Color(0x527E9FFF),
    overlayModal: PravaColors.darkOverlayModal,
    shadowSoft: PravaColors.darkShadowSoft,
    shadowMedium: PravaColors.darkShadowMedium,
    statusSuccess: PravaColors.darkSuccess,
    statusSuccessContainer: PravaColors.darkSuccessContainer,
    statusWarning: PravaColors.darkWarning,
    statusWarningContainer: PravaColors.darkWarningContainer,
    statusError: PravaColors.darkError,
    statusErrorContainer: PravaColors.darkErrorContainer,
    statusInfo: PravaColors.darkInfo,
    statusInfoContainer: PravaColors.darkInfoContainer,
    socialLikeActive: PravaColors.darkSocialLikeActive,
    socialRepostActive: PravaColors.darkSocialRepostActive,
    premiumContent: PravaColors.darkPremiumContent,
    premiumContainer: PravaColors.darkPremiumContainer,
    chatOwnBubble: PravaColors.darkBrandContainer,
    chatOwnText: PravaColors.darkTextPrimary,
    chatReceivedBubble: PravaColors.darkBackgroundSurfaceSubtle,
    chatReceivedText: PravaColors.darkTextPrimary,
    notificationUnread: PravaColors.darkInfoContainer,
    notificationRead: PravaColors.darkBackgroundSurface,
    skeletonBase: PravaColors.darkBackgroundSurfaceSubtle,
    skeletonShimmer: PravaColors.darkBackgroundPressed,
  );

  @override
  PravaThemeColors copyWith({
    Color? backgroundCanvas,
    Color? backgroundSurface,
    Color? backgroundSurfaceSubtle,
    Color? backgroundSurfaceRaised,
    Color? backgroundSurfaceInset,
    Color? backgroundHover,
    Color? backgroundPressed,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? textDisabled,
    Color? textInverse,
    Color? iconPrimary,
    Color? iconSecondary,
    Color? iconDisabled,
    Color? borderSubtle,
    Color? borderDefault,
    Color? borderStrong,
    Color? divider,
    Color? brandPrimary,
    Color? brandPrimaryHover,
    Color? brandPrimaryPressed,
    Color? brandContainer,
    Color? brandContent,
    Color? linkDefault,
    Color? focusBorder,
    Color? focusRing,
    Color? overlayModal,
    Color? shadowSoft,
    Color? shadowMedium,
    Color? statusSuccess,
    Color? statusSuccessContainer,
    Color? statusWarning,
    Color? statusWarningContainer,
    Color? statusError,
    Color? statusErrorContainer,
    Color? statusInfo,
    Color? statusInfoContainer,
    Color? socialLikeActive,
    Color? socialRepostActive,
    Color? premiumContent,
    Color? premiumContainer,
    Color? chatOwnBubble,
    Color? chatOwnText,
    Color? chatReceivedBubble,
    Color? chatReceivedText,
    Color? notificationUnread,
    Color? notificationRead,
    Color? skeletonBase,
    Color? skeletonShimmer,
  }) {
    return PravaThemeColors(
      backgroundCanvas: backgroundCanvas ?? this.backgroundCanvas,
      backgroundSurface: backgroundSurface ?? this.backgroundSurface,
      backgroundSurfaceSubtle:
          backgroundSurfaceSubtle ?? this.backgroundSurfaceSubtle,
      backgroundSurfaceRaised:
          backgroundSurfaceRaised ?? this.backgroundSurfaceRaised,
      backgroundSurfaceInset:
          backgroundSurfaceInset ?? this.backgroundSurfaceInset,
      backgroundHover: backgroundHover ?? this.backgroundHover,
      backgroundPressed: backgroundPressed ?? this.backgroundPressed,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      textDisabled: textDisabled ?? this.textDisabled,
      textInverse: textInverse ?? this.textInverse,
      iconPrimary: iconPrimary ?? this.iconPrimary,
      iconSecondary: iconSecondary ?? this.iconSecondary,
      iconDisabled: iconDisabled ?? this.iconDisabled,
      borderSubtle: borderSubtle ?? this.borderSubtle,
      borderDefault: borderDefault ?? this.borderDefault,
      borderStrong: borderStrong ?? this.borderStrong,
      divider: divider ?? this.divider,
      brandPrimary: brandPrimary ?? this.brandPrimary,
      brandPrimaryHover: brandPrimaryHover ?? this.brandPrimaryHover,
      brandPrimaryPressed: brandPrimaryPressed ?? this.brandPrimaryPressed,
      brandContainer: brandContainer ?? this.brandContainer,
      brandContent: brandContent ?? this.brandContent,
      linkDefault: linkDefault ?? this.linkDefault,
      focusBorder: focusBorder ?? this.focusBorder,
      focusRing: focusRing ?? this.focusRing,
      overlayModal: overlayModal ?? this.overlayModal,
      shadowSoft: shadowSoft ?? this.shadowSoft,
      shadowMedium: shadowMedium ?? this.shadowMedium,
      statusSuccess: statusSuccess ?? this.statusSuccess,
      statusSuccessContainer:
          statusSuccessContainer ?? this.statusSuccessContainer,
      statusWarning: statusWarning ?? this.statusWarning,
      statusWarningContainer:
          statusWarningContainer ?? this.statusWarningContainer,
      statusError: statusError ?? this.statusError,
      statusErrorContainer: statusErrorContainer ?? this.statusErrorContainer,
      statusInfo: statusInfo ?? this.statusInfo,
      statusInfoContainer: statusInfoContainer ?? this.statusInfoContainer,
      socialLikeActive: socialLikeActive ?? this.socialLikeActive,
      socialRepostActive: socialRepostActive ?? this.socialRepostActive,
      premiumContent: premiumContent ?? this.premiumContent,
      premiumContainer: premiumContainer ?? this.premiumContainer,
      chatOwnBubble: chatOwnBubble ?? this.chatOwnBubble,
      chatOwnText: chatOwnText ?? this.chatOwnText,
      chatReceivedBubble: chatReceivedBubble ?? this.chatReceivedBubble,
      chatReceivedText: chatReceivedText ?? this.chatReceivedText,
      notificationUnread: notificationUnread ?? this.notificationUnread,
      notificationRead: notificationRead ?? this.notificationRead,
      skeletonBase: skeletonBase ?? this.skeletonBase,
      skeletonShimmer: skeletonShimmer ?? this.skeletonShimmer,
    );
  }

  @override
  PravaThemeColors lerp(ThemeExtension<PravaThemeColors>? other, double t) {
    if (other is! PravaThemeColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return PravaThemeColors(
      backgroundCanvas: l(backgroundCanvas, other.backgroundCanvas),
      backgroundSurface: l(backgroundSurface, other.backgroundSurface),
      backgroundSurfaceSubtle: l(
        backgroundSurfaceSubtle,
        other.backgroundSurfaceSubtle,
      ),
      backgroundSurfaceRaised: l(
        backgroundSurfaceRaised,
        other.backgroundSurfaceRaised,
      ),
      backgroundSurfaceInset: l(
        backgroundSurfaceInset,
        other.backgroundSurfaceInset,
      ),
      backgroundHover: l(backgroundHover, other.backgroundHover),
      backgroundPressed: l(backgroundPressed, other.backgroundPressed),
      textPrimary: l(textPrimary, other.textPrimary),
      textSecondary: l(textSecondary, other.textSecondary),
      textTertiary: l(textTertiary, other.textTertiary),
      textDisabled: l(textDisabled, other.textDisabled),
      textInverse: l(textInverse, other.textInverse),
      iconPrimary: l(iconPrimary, other.iconPrimary),
      iconSecondary: l(iconSecondary, other.iconSecondary),
      iconDisabled: l(iconDisabled, other.iconDisabled),
      borderSubtle: l(borderSubtle, other.borderSubtle),
      borderDefault: l(borderDefault, other.borderDefault),
      borderStrong: l(borderStrong, other.borderStrong),
      divider: l(divider, other.divider),
      brandPrimary: l(brandPrimary, other.brandPrimary),
      brandPrimaryHover: l(brandPrimaryHover, other.brandPrimaryHover),
      brandPrimaryPressed: l(brandPrimaryPressed, other.brandPrimaryPressed),
      brandContainer: l(brandContainer, other.brandContainer),
      brandContent: l(brandContent, other.brandContent),
      linkDefault: l(linkDefault, other.linkDefault),
      focusBorder: l(focusBorder, other.focusBorder),
      focusRing: l(focusRing, other.focusRing),
      overlayModal: l(overlayModal, other.overlayModal),
      shadowSoft: l(shadowSoft, other.shadowSoft),
      shadowMedium: l(shadowMedium, other.shadowMedium),
      statusSuccess: l(statusSuccess, other.statusSuccess),
      statusSuccessContainer: l(
        statusSuccessContainer,
        other.statusSuccessContainer,
      ),
      statusWarning: l(statusWarning, other.statusWarning),
      statusWarningContainer: l(
        statusWarningContainer,
        other.statusWarningContainer,
      ),
      statusError: l(statusError, other.statusError),
      statusErrorContainer: l(statusErrorContainer, other.statusErrorContainer),
      statusInfo: l(statusInfo, other.statusInfo),
      statusInfoContainer: l(statusInfoContainer, other.statusInfoContainer),
      socialLikeActive: l(socialLikeActive, other.socialLikeActive),
      socialRepostActive: l(socialRepostActive, other.socialRepostActive),
      premiumContent: l(premiumContent, other.premiumContent),
      premiumContainer: l(premiumContainer, other.premiumContainer),
      chatOwnBubble: l(chatOwnBubble, other.chatOwnBubble),
      chatOwnText: l(chatOwnText, other.chatOwnText),
      chatReceivedBubble: l(chatReceivedBubble, other.chatReceivedBubble),
      chatReceivedText: l(chatReceivedText, other.chatReceivedText),
      notificationUnread: l(notificationUnread, other.notificationUnread),
      notificationRead: l(notificationRead, other.notificationRead),
      skeletonBase: l(skeletonBase, other.skeletonBase),
      skeletonShimmer: l(skeletonShimmer, other.skeletonShimmer),
    );
  }
}

extension PravaThemeContext on BuildContext {
  PravaThemeColors get pravaColors =>
      Theme.of(this).extension<PravaThemeColors>() ??
      (Theme.of(this).brightness == Brightness.dark
          ? PravaThemeColors.dark
          : PravaThemeColors.light);
}
