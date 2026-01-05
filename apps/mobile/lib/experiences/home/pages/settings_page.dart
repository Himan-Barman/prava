import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../navigation/prava_navigator.dart';
import '../../../ui-system/background.dart';
import '../../../ui-system/colors.dart';
import '../../../ui-system/typography.dart';
import '../../../ui-system/feedback/prava_toast.dart';
import '../../../ui-system/feedback/toast_type.dart';
import '../../../services/account_service.dart';
import '../../../services/auth_service.dart';
import '../../../services/profile_service.dart';
import '../../../services/settings_service.dart';
import '../../../shell/settings_controller.dart';
import 'help_feedback_page.dart';
import 'account_information_page.dart';
import 'blocked_accounts_page.dart';
import 'data_export_page.dart';
import 'devices_page.dart';
import 'handle_links_page.dart';
import 'language_page.dart';
import 'legal_page.dart';
import 'muted_words_page.dart';
import 'security_center_page.dart';
import '../../auth/login_screen.dart';

const _privacyPolicyContent = '''
Prava respects your privacy. We collect the data you provide to create and
secure your account, deliver messages, and improve the service.

What we collect
- Account details (email, username, profile info)
- Usage and device data needed to operate the app
- Content you share (posts, messages, media)

How we use it
- Deliver core features and notifications
- Protect your account and detect abuse
- Improve performance and reliability

We do not sell your personal data. You can request an export or delete your
account at any time.
''';

const _termsOfServiceContent = '''
By using Prava, you agree to follow our community guidelines.

You are responsible for your account and any content you post. Do not upload
illegal, abusive, or harmful content. We may remove content or suspend accounts
that violate these rules.

The service is provided as-is without warranties. We may update these terms as
the product evolves.
''';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage>
    with TickerProviderStateMixin {
  final AccountService _accountService = AccountService();
  final AuthService _authService = AuthService();
  final ProfileService _profileService = ProfileService();
  SettingsController? _settingsController;

  ProfileSummary? _summary;
  bool _loadingProfile = true;
  String _versionLabel = 'Prava';

  late final AnimationController _introController;

  SettingsState _settings = SettingsState.defaults();
  String _cacheSizeLabel = '240 MB';

  @override
  void initState() {
    super.initState();
    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    _loadProfile();
    _loadPackageInfo();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = SettingsScope.of(context);
    if (_settingsController != controller) {
      _settingsController?.removeListener(_handleSettingsUpdate);
      _settingsController = controller;
      _settingsController?.addListener(_handleSettingsUpdate);
      _handleSettingsUpdate();
    }
  }

  @override
  void dispose() {
    _introController.dispose();
    _settingsController?.removeListener(_handleSettingsUpdate);
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final summary = await _profileService.fetchMyProfile(limit: 6);
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _loadingProfile = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingProfile = false);
    }
  }

  void _handleSettingsUpdate() {
    final controller = _settingsController;
    if (controller == null || !mounted) return;
    setState(() {
      _settings = controller.state;
    });
  }

  void _updateSettings(SettingsState next) {
    HapticFeedback.selectionClick();
    _settingsController?.update(next);
  }

  Future<void> _loadPackageInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() {
        _versionLabel = '${info.version}+${info.buildNumber}';
      });
    } catch (_) {}
  }

  String _formatCount(int value) {
    if (value >= 1000000) {
      final short = (value / 1000000)
          .toStringAsFixed(value % 1000000 == 0 ? 0 : 1);
      return '${short}M';
    }
    if (value >= 1000) {
      final short =
          (value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1);
      return '${short}K';
    }
    return value.toString();
  }

  String _themeLabel(int index) {
    switch (index) {
      case 1:
        return 'Light';
      case 2:
        return 'Dark';
      default:
        return 'System';
    }
  }

  Future<void> _confirmLogout() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Log out?'),
          content: const Text('You will be signed out of Prava.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Log out'),
            ),
          ],
        );
      },
    );

    if (result == true && mounted) {
      try {
        await _authService.logout();
      } catch (_) {}

      if (!mounted) return;
      PravaNavigator.pushAndRemoveUntil(
        context,
        const LoginScreen(),
        (_) => false,
      );
    }
  }

  Future<void> _confirmDeleteAccount() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete account?'),
          content: const Text(
            'This permanently deletes your account and data.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      try {
        await _accountService.deleteAccount();
        if (!mounted) return;
        await _authService.logout();
        if (!mounted) return;
        PravaNavigator.pushAndRemoveUntil(
          context,
          const LoginScreen(),
          (_) => false,
        );
      } catch (_) {
        if (!mounted) return;
        PravaToast.show(
          context,
          message: 'Unable to delete account',
          type: PravaToastType.error,
        );
      }
    }
  }

  void _showThemeSheet(bool isDark) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _SettingsSheet(
          title: 'Appearance',
          child: Column(
            children: [
              _SheetOption(
                label: 'System',
                selected: _settings.themeIndex == 0,
                onTap: () {
                  _updateSettings(_settings.copyWith(themeIndex: 0));
                  Navigator.of(context).pop();
                },
              ),
              _SheetOption(
                label: 'Light',
                selected: _settings.themeIndex == 1,
                onTap: () {
                  _updateSettings(_settings.copyWith(themeIndex: 1));
                  Navigator.of(context).pop();
                },
              ),
              _SheetOption(
                label: 'Dark',
                selected: _settings.themeIndex == 2,
                onTap: () {
                  _updateSettings(_settings.copyWith(themeIndex: 2));
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
          isDark: isDark,
        );
      },
    );
  }

  void _showTextSizeSheet(bool isDark) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        double tempScale = _settings.textScale;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return _SettingsSheet(
              title: 'Text size',
              isDark: isDark,
              child: Column(
                children: [
                  Text(
                    'Preview',
                    style: PravaTypography.caption.copyWith(
                      color: isDark
                          ? PravaColors.darkTextSecondary
                          : PravaColors.lightTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Prava settings look smooth at any size.',
                    textAlign: TextAlign.center,
                    style: PravaTypography.body.copyWith(
                      color: isDark
                          ? PravaColors.darkTextPrimary
                          : PravaColors.lightTextPrimary,
                      fontSize: 14 * tempScale,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Slider(
                    value: tempScale,
                    min: 0.9,
                    max: 1.2,
                    divisions: 6,
                    onChanged: (value) {
                      setSheetState(() => tempScale = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            _updateSettings(
                              _settings.copyWith(textScale: tempScale),
                            );
                            Navigator.of(context).pop();
                          },
                          child: const Text('Apply'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAnimatedSection(int index, Widget child) {
    final start = 0.05 * index;
    final end = (start + 0.35).clamp(0.0, 1.0).toDouble();
    final animation = CurvedAnimation(
      parent: _introController,
      curve: Interval(start, end, curve: Curves.easeOut),
    );

    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: animation.drive(
          Tween<Offset>(
            begin: const Offset(0, 0.08),
            end: Offset.zero,
          ),
        ),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary =
        isDark ? PravaColors.darkTextPrimary : PravaColors.lightTextPrimary;
    final secondary =
        isDark ? PravaColors.darkTextSecondary : PravaColors.lightTextSecondary;
    final surface =
        isDark ? PravaColors.darkBgSurface : PravaColors.lightBgSurface;
    final border =
        isDark ? PravaColors.darkBorderSubtle : PravaColors.lightBorderSubtle;

    final summary = _summary;
    final displayName = summary?.user.displayName.isNotEmpty == true
        ? summary!.user.displayName
        : 'Prava member';
    final username = summary?.user.username.isNotEmpty == true
        ? summary!.user.username
        : 'prava';
    final verified = summary?.user.isVerified == true;
    final followers = summary?.stats.followers ?? 0;
    final following = summary?.stats.following ?? 0;
    final posts = summary?.stats.posts ?? 0;

    var sectionIndex = 0;
    Widget wrapSection(Widget child) =>
        _buildAnimatedSection(sectionIndex++, child);

    return Scaffold(
      body: Stack(
        children: [
          _SettingsBackdrop(isDark: isDark),
          CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              SliverAppBar(
                pinned: true,
                expandedHeight: 170,
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(CupertinoIcons.back),
                  color: primary,
                  onPressed: () => Navigator.of(context).pop(),
                ),
                title: Text(
                  'Settings',
                  style: PravaTypography.h2.copyWith(color: primary),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: _SettingsHero(isDark: isDark),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: wrapSection(
                    _SettingsHeaderCard(
                      displayName: displayName,
                      username: username,
                      verified: verified,
                      followers: _formatCount(followers),
                      following: _formatCount(following),
                      posts: _formatCount(posts),
                      isDark: isDark,
                      loading: _loadingProfile,
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                  child: wrapSection(
                    _QuickActionsRow(
                      onEditProfile: () => PravaNavigator.push(
                        context,
                        const HandleLinksPage(),
                      ),
                      onAccount: () => PravaNavigator.push(
                        context,
                        const AccountInformationPage(),
                      ),
                      onSecurity: () => PravaNavigator.push(
                        context,
                        const SecurityCenterPage(),
                      ),
                      isDark: isDark,
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: wrapSection(
                    _SettingsSection(
                      title: 'Account',
                      subtitle: 'Identity and login tools.',
                      surface: surface,
                      border: border,
                      children: [
                        _SettingsTile(
                          icon: CupertinoIcons.person_crop_circle,
                          title: 'Account information',
                          subtitle: 'Username, email, and profile status',
                          onTap: () => PravaNavigator.push(
                            context,
                            const AccountInformationPage(),
                          ),
                          color: primary,
                          secondary: secondary,
                        ),
                        _SettingsTile(
                          icon: CupertinoIcons.at,
                          title: 'Handle and links',
                          subtitle: 'Manage username and profile links',
                          onTap: () => PravaNavigator.push(
                            context,
                            const HandleLinksPage(),
                          ),
                          color: primary,
                          secondary: secondary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: wrapSection(
                    _SettingsSection(
                      title: 'Privacy and safety',
                      subtitle: 'Control who can see and reach you.',
                      surface: surface,
                      border: border,
                      children: [
                        _SettingsToggleTile(
                          icon: CupertinoIcons.lock_fill,
                          title: 'Private account',
                          subtitle: 'Approve new followers',
                          value: _settings.privateAccount,
                          onChanged: (value) => _updateSettings(
                            _settings.copyWith(privateAccount: value),
                          ),
                          color: primary,
                          secondary: secondary,
                        ),
                        _SettingsToggleTile(
                          icon: CupertinoIcons.eye,
                          title: 'Activity status',
                          subtitle: 'Show when you are active',
                          value: _settings.activityStatus,
                          onChanged: (value) => _updateSettings(
                            _settings.copyWith(activityStatus: value),
                          ),
                          color: primary,
                          secondary: secondary,
                        ),
                        _SettingsToggleTile(
                          icon: CupertinoIcons.check_mark_circled,
                          title: 'Read receipts',
                          subtitle: 'Let people know when you read',
                          value: _settings.readReceipts,
                          onChanged: (value) => _updateSettings(
                            _settings.copyWith(readReceipts: value),
                          ),
                          color: primary,
                          secondary: secondary,
                        ),
                        _SettingsToggleTile(
                          icon: CupertinoIcons.photo_on_rectangle,
                          title: 'Sensitive content filter',
                          subtitle: 'Blur sensitive media',
                          value: _settings.sensitiveContent,
                          onChanged: (value) => _updateSettings(
                            _settings.copyWith(sensitiveContent: value),
                          ),
                          color: primary,
                          secondary: secondary,
                        ),
                        _SettingsToggleTile(
                          icon: CupertinoIcons.location,
                          title: 'Location sharing',
                          subtitle: 'Share location in posts',
                          value: _settings.locationSharing,
                          onChanged: (value) => _updateSettings(
                            _settings.copyWith(locationSharing: value),
                          ),
                          color: primary,
                          secondary: secondary,
                        ),
                        _SettingsTile(
                          icon: CupertinoIcons.person_badge_minus,
                          title: 'Blocked accounts',
                          subtitle: 'Manage blocked profiles',
                          onTap: () => PravaNavigator.push(
                            context,
                            const BlockedAccountsPage(),
                          ),
                          color: primary,
                          secondary: secondary,
                        ),
                        _SettingsTile(
                          icon: CupertinoIcons.textformat_abc,
                          title: 'Muted words',
                          subtitle: 'Hide topics and phrases',
                          onTap: () => PravaNavigator.push(
                            context,
                            const MutedWordsPage(),
                          ),
                          color: primary,
                          secondary: secondary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: wrapSection(
                    _SettingsSection(
                      title: 'Security',
                      subtitle: 'Protect your sessions and devices.',
                      surface: surface,
                      border: border,
                      children: [
                        _SettingsToggleTile(
                          icon: CupertinoIcons.shield_lefthalf_fill,
                          title: 'Two factor authentication',
                          subtitle: 'Require a code on login',
                          value: _settings.twoFactor,
                          onChanged: (value) => _updateSettings(
                            _settings.copyWith(twoFactor: value),
                          ),
                          color: primary,
                          secondary: secondary,
                        ),
                        _SettingsToggleTile(
                          icon: CupertinoIcons.bell,
                          title: 'Login alerts',
                          subtitle: 'Get notified on new logins',
                          value: _settings.loginAlerts,
                          onChanged: (value) => _updateSettings(
                            _settings.copyWith(loginAlerts: value),
                          ),
                          color: primary,
                          secondary: secondary,
                        ),
                        _SettingsToggleTile(
                          icon: CupertinoIcons.lock_circle_fill,
                          title: 'App passcode',
                          subtitle: 'Require a passcode to open',
                          value: _settings.appLock,
                          onChanged: (value) => _updateSettings(
                            _settings.copyWith(appLock: value),
                          ),
                          color: primary,
                          secondary: secondary,
                        ),
                        _SettingsToggleTile(
                          icon: CupertinoIcons.lock_shield,
                          title: 'Biometric unlock',
                          subtitle: 'Use face or fingerprint',
                          value: _settings.biometrics,
                          onChanged: (value) => _updateSettings(
                            _settings.copyWith(biometrics: value),
                          ),
                          color: primary,
                          secondary: secondary,
                        ),
                        _SettingsTile(
                          icon: CupertinoIcons.device_phone_portrait,
                          title: 'Devices',
                          subtitle: 'See active sessions',
                          onTap: () => PravaNavigator.push(
                            context,
                            const DevicesPage(),
                          ),
                          color: primary,
                          secondary: secondary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: wrapSection(
                    _SettingsSection(
                      title: 'Notifications',
                      subtitle: 'Fine tune alerts and sounds.',
                      surface: surface,
                      border: border,
                      children: [
                        _SettingsToggleTile(
                          icon: CupertinoIcons.app_badge,
                          title: 'Push notifications',
                          subtitle: 'Likes, messages, and follows',
                          value: _settings.pushNotifications,
                          onChanged: (value) => _updateSettings(
                            _settings.copyWith(pushNotifications: value),
                          ),
                          color: primary,
                          secondary: secondary,
                        ),
                        _SettingsToggleTile(
                          icon: CupertinoIcons.envelope_fill,
                          title: 'Email notifications',
                          subtitle: 'Security and digest emails',
                          value: _settings.emailNotifications,
                          onChanged: (value) => _updateSettings(
                            _settings.copyWith(emailNotifications: value),
                          ),
                          color: primary,
                          secondary: secondary,
                        ),
                        _SettingsToggleTile(
                          icon: CupertinoIcons.text_bubble_fill,
                          title: 'Message preview',
                          subtitle: 'Show content on lock screen',
                          value: _settings.messagePreview,
                          onChanged: (value) => _updateSettings(
                            _settings.copyWith(messagePreview: value),
                          ),
                          color: primary,
                          secondary: secondary,
                        ),
                        _SettingsToggleTile(
                          icon: CupertinoIcons.speaker_3_fill,
                          title: 'In app sounds',
                          subtitle: 'Audio feedback for actions',
                          value: _settings.inAppSounds,
                          onChanged: (value) => _updateSettings(
                            _settings.copyWith(inAppSounds: value),
                          ),
                          color: primary,
                          secondary: secondary,
                        ),
                        _SettingsToggleTile(
                          icon: CupertinoIcons.waveform,
                          title: 'Haptics',
                          subtitle: 'Vibration for interactions',
                          value: _settings.inAppHaptics,
                          onChanged: (value) => _updateSettings(
                            _settings.copyWith(inAppHaptics: value),
                          ),
                          color: primary,
                          secondary: secondary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: wrapSection(
                    _SettingsSection(
                      title: 'Content and display',
                      subtitle: 'Visual preferences and playback.',
                      surface: surface,
                      border: border,
                      children: [
                        _SettingsTile(
                          icon: CupertinoIcons.circle_lefthalf_fill,
                          title: 'Theme',
                          subtitle: _themeLabel(_settings.themeIndex),
                          onTap: () => _showThemeSheet(isDark),
                          color: primary,
                          secondary: secondary,
                        ),
                        _SettingsTile(
                          icon: CupertinoIcons.textformat_size,
                          title: 'Text size',
                          subtitle:
                              'Scale ${_settings.textScale.toStringAsFixed(2)}x',
                          onTap: () => _showTextSizeSheet(isDark),
                          color: primary,
                          secondary: secondary,
                        ),
                        _SettingsTile(
                          icon: CupertinoIcons.globe,
                          title: 'Language',
                          subtitle: _settings.languageLabel,
                          onTap: () => PravaNavigator.push(
                            context,
                            const LanguagePage(),
                          ),
                          color: primary,
                          secondary: secondary,
                        ),
                        _SettingsToggleTile(
                          icon: CupertinoIcons.film,
                          title: 'Autoplay videos',
                          subtitle: 'Play video previews automatically',
                          value: _settings.autoPlayVideos,
                          onChanged: (value) => _updateSettings(
                            _settings.copyWith(autoPlayVideos: value),
                          ),
                          color: primary,
                          secondary: secondary,
                        ),
                        _SettingsToggleTile(
                          icon: CupertinoIcons.slowmo,
                          title: 'Reduce motion',
                          subtitle: 'Simplify animations',
                          value: _settings.reduceMotion,
                          onChanged: (value) => _updateSettings(
                            _settings.copyWith(reduceMotion: value),
                          ),
                          color: primary,
                          secondary: secondary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: wrapSection(
                    _SettingsSection(
                      title: 'Data and storage',
                      subtitle: 'Control downloads and cache.',
                      surface: surface,
                      border: border,
                      children: [
                        _SettingsToggleTile(
                          icon: CupertinoIcons.battery_25,
                          title: 'Data saver',
                          subtitle: 'Use less data on mobile',
                          value: _settings.dataSaver,
                          onChanged: (value) => _updateSettings(
                            _settings.copyWith(dataSaver: value),
                          ),
                          color: primary,
                          secondary: secondary,
                        ),
                        _SettingsToggleTile(
                          icon: CupertinoIcons.arrow_down_circle,
                          title: 'Media auto download',
                          subtitle: 'Download media on wifi',
                          value: _settings.autoDownload,
                          onChanged: (value) => _updateSettings(
                            _settings.copyWith(autoDownload: value),
                          ),
                          color: primary,
                          secondary: secondary,
                        ),
                        _SettingsTile(
                          icon: CupertinoIcons.folder,
                          title: 'Cache size',
                          subtitle: _cacheSizeLabel,
                          onTap: () {},
                          showChevron: false,
                          color: primary,
                          secondary: secondary,
                        ),
                        _SettingsTile(
                          icon: CupertinoIcons.trash,
                          title: 'Clear cache',
                          subtitle: 'Remove temporary files',
                          onTap: () {
                            setState(() => _cacheSizeLabel = '0 MB');
                            PravaToast.show(
                              context,
                              message: 'Cache cleared',
                              type: PravaToastType.success,
                            );
                          },
                          color: primary,
                          secondary: secondary,
                        ),
                        _SettingsTile(
                          icon: CupertinoIcons.cloud_download,
                          title: 'Download your data',
                          subtitle: 'Export a copy of your data',
                          onTap: () => PravaNavigator.push(
                            context,
                            const DataExportPage(),
                          ),
                          color: primary,
                          secondary: secondary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: wrapSection(
                    _SettingsSection(
                      title: 'Support and legal',
                      subtitle: 'Help center and policies.',
                      surface: surface,
                      border: border,
                      children: [
                        _SettingsTile(
                          icon: CupertinoIcons.question_circle,
                          title: 'Help center',
                          subtitle: 'FAQs and contact support',
                          onTap: () => PravaNavigator.push(
                            context,
                            const HelpFeedbackPage(
                              initialSection: HelpFeedbackSection.help,
                            ),
                          ),
                          color: primary,
                          secondary: secondary,
                        ),
                        _SettingsTile(
                          icon: CupertinoIcons.exclamationmark_bubble,
                          title: 'Report a problem',
                          subtitle: 'Tell us what went wrong',
                          onTap: () => PravaNavigator.push(
                            context,
                            const HelpFeedbackPage(
                              initialSection: HelpFeedbackSection.report,
                            ),
                          ),
                          color: primary,
                          secondary: secondary,
                        ),
                        _SettingsTile(
                          icon: CupertinoIcons.chat_bubble_2,
                          title: 'Send feedback',
                          subtitle: 'Share ideas and feature requests',
                          onTap: () => PravaNavigator.push(
                            context,
                            const HelpFeedbackPage(
                              initialSection: HelpFeedbackSection.feedback,
                            ),
                          ),
                          color: primary,
                          secondary: secondary,
                        ),
                        _SettingsTile(
                          icon: CupertinoIcons.doc_text,
                          title: 'Privacy policy',
                          subtitle: 'How we handle your data',
                          onTap: () => PravaNavigator.push(
                            context,
                            const LegalPage(
                              title: 'Privacy policy',
                              content: _privacyPolicyContent,
                            ),
                          ),
                          color: primary,
                          secondary: secondary,
                        ),
                        _SettingsTile(
                          icon: CupertinoIcons.doc_on_doc,
                          title: 'Terms of service',
                          subtitle: 'Rules for using Prava',
                          onTap: () => PravaNavigator.push(
                            context,
                            const LegalPage(
                              title: 'Terms of service',
                              content: _termsOfServiceContent,
                            ),
                          ),
                          color: primary,
                          secondary: secondary,
                        ),
                        _SettingsTile(
                          icon: CupertinoIcons.info,
                          title: 'App version',
                          subtitle: _versionLabel,
                          onTap: () {},
                          showChevron: false,
                          color: primary,
                          secondary: secondary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  child: wrapSection(
                    _SettingsSection(
                      title: 'Account actions',
                      subtitle: 'Sign out or permanently delete.',
                      surface: surface,
                      border: border,
                      children: [
                        _SettingsTile(
                          icon: CupertinoIcons.square_arrow_right,
                          title: 'Log out',
                          subtitle: 'Sign out of this device',
                          onTap: _confirmLogout,
                          destructive: true,
                          color: primary,
                          secondary: secondary,
                        ),
                        _SettingsTile(
                          icon: CupertinoIcons.delete,
                          title: 'Delete account',
                          subtitle: 'Permanent and irreversible',
                          onTap: _confirmDeleteAccount,
                          destructive: true,
                          color: primary,
                          secondary: secondary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SettingsBackdrop extends StatelessWidget {
  const _SettingsBackdrop({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return PravaBackground(isDark: isDark);
  }
}

class _SettingsHero extends StatelessWidget {
  const _SettingsHero({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            PravaColors.accentPrimary.withValues(alpha: isDark ? 0.3 : 0.25),
            PravaColors.accentMuted.withValues(alpha: isDark ? 0.2 : 0.3),
            Colors.transparent,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );
  }
}

class _SettingsHeaderCard extends StatelessWidget {
  const _SettingsHeaderCard({
    required this.displayName,
    required this.username,
    required this.verified,
    required this.followers,
    required this.following,
    required this.posts,
    required this.isDark,
    required this.loading,
  });

  final String displayName;
  final String username;
  final bool verified;
  final String followers;
  final String following;
  final String posts;
  final bool isDark;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final primary =
        isDark ? PravaColors.darkTextPrimary : PravaColors.lightTextPrimary;
    final secondary =
        isDark ? PravaColors.darkTextSecondary : PravaColors.lightTextSecondary;

    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? Colors.white10 : Colors.white.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: isDark
                  ? PravaColors.darkBorderSubtle
                  : PravaColors.lightBorderSubtle,
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  _SettingsAvatar(
                    initials: displayName.isNotEmpty
                        ? displayName.substring(0, 1).toUpperCase()
                        : 'P',
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: PravaTypography.h3.copyWith(
                                  color: primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            if (verified)
                              Icon(
                                CupertinoIcons.check_mark_circled_solid,
                                size: 16,
                                color: PravaColors.accentPrimary,
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '@$username',
                          style: PravaTypography.caption.copyWith(
                            color: secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: PravaColors.accentPrimary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Member',
                      style: PravaTypography.caption.copyWith(
                        color: PravaColors.accentPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              AnimatedOpacity(
                opacity: loading ? 0.4 : 1,
                duration: const Duration(milliseconds: 200),
                child: Row(
                  children: [
                    Expanded(
                      child: _StatItem(
                        label: 'Posts',
                        value: posts,
                        primary: primary,
                        secondary: secondary,
                      ),
                    ),
                    Expanded(
                      child: _StatItem(
                        label: 'Followers',
                        value: followers,
                        primary: primary,
                        secondary: secondary,
                      ),
                    ),
                    Expanded(
                      child: _StatItem(
                        label: 'Following',
                        value: following,
                        primary: primary,
                        secondary: secondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsAvatar extends StatelessWidget {
  const _SettingsAvatar({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            PravaColors.accentPrimary,
            PravaColors.accentMuted,
          ],
        ),
      ),
      child: CircleAvatar(
        radius: 26,
        backgroundColor: PravaColors.accentPrimary.withValues(alpha: 0.15),
        child: Text(
          initials,
          style: PravaTypography.h3.copyWith(
            color: PravaColors.accentPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.label,
    required this.value,
    required this.primary,
    required this.secondary,
  });

  final String label;
  final String value;
  final Color primary;
  final Color secondary;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: PravaTypography.h3.copyWith(
            color: primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: PravaTypography.caption.copyWith(color: secondary),
        ),
      ],
    );
  }
}

class _QuickActionsRow extends StatelessWidget {
  const _QuickActionsRow({
    required this.onEditProfile,
    required this.onAccount,
    required this.onSecurity,
    required this.isDark,
  });

  final VoidCallback onEditProfile;
  final VoidCallback onAccount;
  final VoidCallback onSecurity;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _QuickAction(
            icon: CupertinoIcons.pencil,
            label: 'Edit profile',
            onTap: onEditProfile,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _QuickAction(
            icon: CupertinoIcons.person_crop_circle,
            label: 'Account',
            onTap: onAccount,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _QuickAction(
            icon: CupertinoIcons.shield,
            label: 'Security',
            onTap: onSecurity,
            isDark: isDark,
          ),
        ),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.isDark,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isDark ? Colors.white10 : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark
                ? PravaColors.darkBorderSubtle
                : PravaColors.lightBorderSubtle,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: PravaColors.accentPrimary, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: PravaTypography.caption.copyWith(
                  color: isDark
                      ? PravaColors.darkTextPrimary
                      : PravaColors.lightTextPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.subtitle,
    required this.children,
    required this.surface,
    required this.border,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;
  final Color surface;
  final Color border;

  List<Widget> _withDividers() {
    final items = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      items.add(children[i]);
      if (i != children.length - 1) {
        items.add(Divider(height: 1, color: border));
      }
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary =
        isDark ? PravaColors.darkTextPrimary : PravaColors.lightTextPrimary;
    final secondary =
        isDark ? PravaColors.darkTextSecondary : PravaColors.lightTextSecondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: PravaTypography.h3.copyWith(color: primary),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: PravaTypography.bodySmall.copyWith(color: secondary),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: border),
          ),
          child: Column(children: _withDividers()),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.color,
    required this.secondary,
    this.destructive = false,
    this.showChevron = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color color;
  final Color secondary;
  final bool destructive;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final iconColor =
        destructive ? PravaColors.error : PravaColors.accentPrimary;
    final textColor = destructive ? PravaColors.error : color;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: PravaTypography.body.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: PravaTypography.caption.copyWith(
                      color: destructive ? PravaColors.error : secondary,
                    ),
                  ),
                ],
              ),
            ),
            if (showChevron)
              Icon(
                CupertinoIcons.chevron_right,
                size: 16,
                color: secondary,
              ),
          ],
        ),
      ),
    );
  }
}

class _SettingsToggleTile extends StatelessWidget {
  const _SettingsToggleTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    required this.color,
    required this.secondary,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color color;
  final Color secondary;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: PravaColors.accentPrimary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child:
                Icon(icon, color: PravaColors.accentPrimary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: PravaTypography.body.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: PravaTypography.caption.copyWith(color: secondary),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: PravaColors.accentPrimary,
          ),
        ],
      ),
    );
  }
}

class _SettingsSheet extends StatelessWidget {
  const _SettingsSheet({
    required this.title,
    required this.child,
    required this.isDark,
  });

  final String title;
  final Widget child;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final background = isDark
        ? PravaColors.darkBgElevated
        : PravaColors.lightBgElevated;
    final primary =
        isDark ? PravaColors.darkTextPrimary : PravaColors.lightTextPrimary;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      decoration: BoxDecoration(
        color: background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: PravaTypography.h3.copyWith(color: primary),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _SheetOption extends StatelessWidget {
  const _SheetOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      title: Text(label),
      trailing: selected
          ? const Icon(CupertinoIcons.check_mark_circled_solid,
              color: PravaColors.accentPrimary)
          : null,
    );
  }
}
