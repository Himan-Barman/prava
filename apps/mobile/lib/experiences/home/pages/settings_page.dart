import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../navigation/prava_navigator.dart';
import '../../../services/account_service.dart';
import '../../../services/auth_service.dart';
import '../../../services/profile_service.dart';
import '../../../services/settings_service.dart';
import '../../../shell/settings_controller.dart';
import '../../../ui-system/background.dart';
import '../../../ui-system/colors.dart';
import '../../../ui-system/feedback/prava_toast.dart';
import '../../../ui-system/feedback/toast_type.dart';
import '../../../ui-system/typography.dart';
import '../../auth/login_screen.dart';
import 'account_information_page.dart';
import 'blocked_accounts_page.dart';
import 'data_export_page.dart';
import 'devices_page.dart';
import 'handle_links_page.dart';
import 'help_feedback_page.dart';
import 'language_page.dart';
import 'legal_page.dart';
import 'muted_words_page.dart';
import 'security_center_page.dart';
import 'settings_detail_shell.dart';

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

enum _SettingsCategory {
  account,
  privacy,
  security,
  notifications,
  display,
  data,
  support,
  actions,
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final AccountService _accountService = AccountService();
  final AuthService _authService = AuthService();
  final ProfileService _profileService = ProfileService();
  SettingsController? _settingsController;

  ProfileSummary? _summary;
  bool _loadingProfile = true;
  String _versionLabel = 'Prava';
  SettingsState _settings = SettingsState.defaults();

  @override
  void initState() {
    super.initState();
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

  Future<void> _loadPackageInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() => _versionLabel = '${info.version}+${info.buildNumber}');
    } catch (_) {}
  }

  void _handleSettingsUpdate() {
    final controller = _settingsController;
    if (controller == null || !mounted) return;
    setState(() => _settings = controller.state);
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

    if (result != true || !mounted) return;
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

    if (result != true) return;
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

  String _formatCount(int value) {
    if (value >= 1000000) {
      final short = (value / 1000000).toStringAsFixed(
        value % 1000000 == 0 ? 0 : 1,
      );
      return '${short}M';
    }
    if (value >= 1000) {
      final short = (value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1);
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

  void _openCategory(_SettingsCategory category) {
    HapticFeedback.selectionClick();
    PravaNavigator.push(
      context,
      _SettingsCategoryPage(
        category: category,
        versionLabel: _versionLabel,
        onLogout: _confirmLogout,
        onDeleteAccount: _confirmDeleteAccount,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark
        ? PravaColors.darkTextPrimary
        : PravaColors.lightTextPrimary;
    final secondary = isDark
        ? PravaColors.darkTextSecondary
        : PravaColors.lightTextSecondary;
    final surface = isDark
        ? PravaColors.darkBgSurface
        : PravaColors.lightBgSurface;
    final border = isDark
        ? PravaColors.darkBorderSubtle
        : PravaColors.lightBorderSubtle;

    final summary = _summary;
    final displayName = summary?.user.displayName.isNotEmpty == true
        ? summary!.user.displayName
        : 'Prava member';
    final username = summary?.user.username.isNotEmpty == true
        ? summary!.user.username
        : 'prava';
    final verified = summary?.user.isVerified == true;

    return Scaffold(
      body: Stack(
        children: [
          PravaBackground(isDark: isDark),
          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 10),
                    child: _SettingsTopBar(primary: primary),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
                    child: _SettingsHeaderCard(
                      displayName: displayName,
                      username: username,
                      verified: verified,
                      posts: _formatCount(summary?.stats.posts ?? 0),
                      followers: _formatCount(summary?.stats.followers ?? 0),
                      following: _formatCount(summary?.stats.following ?? 0),
                      isDark: isDark,
                      loading: _loadingProfile,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                    child: _ControlCenterCard(
                      settings: _settings,
                      themeLabel: _themeLabel(_settings.themeIndex),
                      primary: primary,
                      secondary: secondary,
                      surface: surface,
                      border: border,
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 28),
                  sliver: SliverList.separated(
                    itemCount: _categoryOrder.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final category = _categoryOrder[index];
                      final meta = _SettingsCategoryMeta.from(category);
                      return _SettingsCategoryTile(
                        meta: meta,
                        primary: primary,
                        secondary: secondary,
                        surface: surface,
                        border: border,
                        trailing: _categoryTrailing(category, _settings),
                        onTap: () => _openCategory(category),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsCategoryPage extends StatefulWidget {
  const _SettingsCategoryPage({
    required this.category,
    required this.versionLabel,
    required this.onLogout,
    required this.onDeleteAccount,
  });

  final _SettingsCategory category;
  final String versionLabel;
  final VoidCallback onLogout;
  final VoidCallback onDeleteAccount;

  @override
  State<_SettingsCategoryPage> createState() => _SettingsCategoryPageState();
}

class _SettingsCategoryPageState extends State<_SettingsCategoryPage> {
  SettingsController? _controller;
  SettingsState _settings = SettingsState.defaults();
  String _cacheSizeLabel = '240 MB';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = SettingsScope.of(context);
    if (_controller != controller) {
      _controller?.removeListener(_handleUpdate);
      _controller = controller;
      _controller?.addListener(_handleUpdate);
      _handleUpdate();
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_handleUpdate);
    super.dispose();
  }

  void _handleUpdate() {
    final controller = _controller;
    if (controller == null || !mounted) return;
    setState(() => _settings = controller.state);
  }

  void _update(SettingsState next) {
    HapticFeedback.selectionClick();
    _controller?.update(next);
  }

  void _showThemeSheet(bool isDark) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _SettingsSheet(
          title: 'Appearance',
          isDark: isDark,
          child: Column(
            children: [
              _SheetOption(
                label: 'System',
                selected: _settings.themeIndex == 0,
                onTap: () {
                  _update(_settings.copyWith(themeIndex: 0));
                  Navigator.of(context).pop();
                },
              ),
              _SheetOption(
                label: 'Light',
                selected: _settings.themeIndex == 1,
                onTap: () {
                  _update(_settings.copyWith(themeIndex: 1));
                  Navigator.of(context).pop();
                },
              ),
              _SheetOption(
                label: 'Dark',
                selected: _settings.themeIndex == 2,
                onTap: () {
                  _update(_settings.copyWith(themeIndex: 2));
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
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
                            _update(_settings.copyWith(textScale: tempScale));
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

  void _clearCache() {
    HapticFeedback.selectionClick();
    setState(() => _cacheSizeLabel = '0 MB');
    PravaToast.show(
      context,
      message: 'Cache cleared',
      type: PravaToastType.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    final meta = _SettingsCategoryMeta.from(widget.category);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark
        ? PravaColors.darkTextPrimary
        : PravaColors.lightTextPrimary;
    final secondary = isDark
        ? PravaColors.darkTextSecondary
        : PravaColors.lightTextSecondary;
    final surface = isDark
        ? PravaColors.darkBgSurface
        : PravaColors.lightBgSurface;
    final border = isDark
        ? PravaColors.darkBorderSubtle
        : PravaColors.lightBorderSubtle;

    return SettingsDetailShell(
      title: meta.title,
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
        children: [
          _CategoryHero(meta: meta, primary: primary, secondary: secondary),
          const SizedBox(height: 14),
          ..._buildCategorySections(
            context: context,
            category: widget.category,
            primary: primary,
            secondary: secondary,
            surface: surface,
            border: border,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  List<Widget> _buildCategorySections({
    required BuildContext context,
    required _SettingsCategory category,
    required Color primary,
    required Color secondary,
    required Color surface,
    required Color border,
    required bool isDark,
  }) {
    switch (category) {
      case _SettingsCategory.account:
        return [
          _SettingsSection(
            title: 'Account center',
            subtitle: 'Identity and profile controls.',
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
                subtitle: 'Username and profile links',
                onTap: () =>
                    PravaNavigator.push(context, const HandleLinksPage()),
                color: primary,
                secondary: secondary,
              ),
            ],
          ),
        ];
      case _SettingsCategory.privacy:
        return [
          _SettingsSection(
            title: 'Visibility',
            subtitle: 'Control what others can see.',
            surface: surface,
            border: border,
            children: [
              _SettingsToggleTile(
                icon: CupertinoIcons.lock_fill,
                title: 'Private account',
                subtitle: 'Approve new followers',
                value: _settings.privateAccount,
                onChanged: (value) =>
                    _update(_settings.copyWith(privateAccount: value)),
                color: primary,
                secondary: secondary,
              ),
              _SettingsToggleTile(
                icon: CupertinoIcons.eye,
                title: 'Activity status',
                subtitle: 'Show when you are active',
                value: _settings.activityStatus,
                onChanged: (value) =>
                    _update(_settings.copyWith(activityStatus: value)),
                color: primary,
                secondary: secondary,
              ),
              _SettingsToggleTile(
                icon: CupertinoIcons.check_mark_circled,
                title: 'Read receipts',
                subtitle: 'Show when messages are read',
                value: _settings.readReceipts,
                onChanged: (value) =>
                    _update(_settings.copyWith(readReceipts: value)),
                color: primary,
                secondary: secondary,
              ),
              _SettingsToggleTile(
                icon: CupertinoIcons.location,
                title: 'Location sharing',
                subtitle: 'Share location in posts',
                value: _settings.locationSharing,
                onChanged: (value) =>
                    _update(_settings.copyWith(locationSharing: value)),
                color: primary,
                secondary: secondary,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _SettingsSection(
            title: 'Safety',
            subtitle: 'Filter people and content.',
            surface: surface,
            border: border,
            children: [
              _SettingsToggleTile(
                icon: CupertinoIcons.photo_on_rectangle,
                title: 'Sensitive content filter',
                subtitle: 'Blur sensitive media',
                value: _settings.sensitiveContent,
                onChanged: (value) =>
                    _update(_settings.copyWith(sensitiveContent: value)),
                color: primary,
                secondary: secondary,
              ),
              _SettingsTile(
                icon: CupertinoIcons.person_badge_minus,
                title: 'Blocked accounts',
                subtitle: 'Manage blocked profiles',
                onTap: () =>
                    PravaNavigator.push(context, const BlockedAccountsPage()),
                color: primary,
                secondary: secondary,
              ),
              _SettingsTile(
                icon: CupertinoIcons.textformat_abc,
                title: 'Muted words',
                subtitle: 'Hide topics and phrases',
                onTap: () =>
                    PravaNavigator.push(context, const MutedWordsPage()),
                color: primary,
                secondary: secondary,
              ),
            ],
          ),
        ];
      case _SettingsCategory.security:
        return [
          _SettingsSection(
            title: 'Login protection',
            subtitle: 'Secure access to your account.',
            surface: surface,
            border: border,
            children: [
              _SettingsTile(
                icon: CupertinoIcons.shield,
                title: 'Security center',
                subtitle: 'Password and account protection',
                onTap: () =>
                    PravaNavigator.push(context, const SecurityCenterPage()),
                color: primary,
                secondary: secondary,
              ),
              _SettingsToggleTile(
                icon: CupertinoIcons.shield_lefthalf_fill,
                title: 'Two factor authentication',
                subtitle: 'Require a code on login',
                value: _settings.twoFactor,
                onChanged: (value) =>
                    _update(_settings.copyWith(twoFactor: value)),
                color: primary,
                secondary: secondary,
              ),
              _SettingsToggleTile(
                icon: CupertinoIcons.bell,
                title: 'Login alerts',
                subtitle: 'Get notified on new logins',
                value: _settings.loginAlerts,
                onChanged: (value) =>
                    _update(_settings.copyWith(loginAlerts: value)),
                color: primary,
                secondary: secondary,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _SettingsSection(
            title: 'Device access',
            subtitle: 'Control device-level protection.',
            surface: surface,
            border: border,
            children: [
              _SettingsToggleTile(
                icon: CupertinoIcons.lock_circle_fill,
                title: 'App passcode',
                subtitle: 'Require a passcode to open',
                value: _settings.appLock,
                onChanged: (value) =>
                    _update(_settings.copyWith(appLock: value)),
                color: primary,
                secondary: secondary,
              ),
              _SettingsToggleTile(
                icon: CupertinoIcons.lock_shield,
                title: 'Biometric unlock',
                subtitle: 'Use face or fingerprint',
                value: _settings.biometrics,
                onChanged: (value) =>
                    _update(_settings.copyWith(biometrics: value)),
                color: primary,
                secondary: secondary,
              ),
              _SettingsTile(
                icon: CupertinoIcons.device_phone_portrait,
                title: 'Devices',
                subtitle: 'See active sessions',
                onTap: () => PravaNavigator.push(context, const DevicesPage()),
                color: primary,
                secondary: secondary,
              ),
            ],
          ),
        ];
      case _SettingsCategory.notifications:
        return [
          _SettingsSection(
            title: 'Channels',
            subtitle: 'Choose where alerts arrive.',
            surface: surface,
            border: border,
            children: [
              _SettingsToggleTile(
                icon: CupertinoIcons.app_badge,
                title: 'Push notifications',
                subtitle: 'Device alerts',
                value: _settings.pushNotifications,
                onChanged: (value) =>
                    _update(_settings.copyWith(pushNotifications: value)),
                color: primary,
                secondary: secondary,
              ),
              _SettingsToggleTile(
                icon: CupertinoIcons.envelope_fill,
                title: 'Email notifications',
                subtitle: 'Security and digest emails',
                value: _settings.emailNotifications,
                onChanged: (value) =>
                    _update(_settings.copyWith(emailNotifications: value)),
                color: primary,
                secondary: secondary,
              ),
              _SettingsToggleTile(
                icon: CupertinoIcons.speaker_3_fill,
                title: 'In app sounds',
                subtitle: 'Audio feedback',
                value: _settings.inAppSounds,
                onChanged: (value) =>
                    _update(_settings.copyWith(inAppSounds: value)),
                color: primary,
                secondary: secondary,
              ),
              _SettingsToggleTile(
                icon: CupertinoIcons.waveform,
                title: 'Haptics',
                subtitle: 'Vibration feedback',
                value: _settings.inAppHaptics,
                onChanged: (value) =>
                    _update(_settings.copyWith(inAppHaptics: value)),
                color: primary,
                secondary: secondary,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _SettingsSection(
            title: 'Notification types',
            subtitle: 'Fine tune event alerts.',
            surface: surface,
            border: border,
            children: [
              _SettingsToggleTile(
                icon: CupertinoIcons.square_list,
                title: 'Posts',
                subtitle: 'Likes, comments, and shares',
                value: _settings.notifyPosts,
                onChanged: (value) =>
                    _update(_settings.copyWith(notifyPosts: value)),
                color: primary,
                secondary: secondary,
              ),
              _SettingsToggleTile(
                icon: CupertinoIcons.chat_bubble_2_fill,
                title: 'Chats',
                subtitle: 'Messages and requests',
                value: _settings.notifyChats,
                onChanged: (value) =>
                    _update(_settings.copyWith(notifyChats: value)),
                color: primary,
                secondary: secondary,
              ),
              _SettingsToggleTile(
                icon: CupertinoIcons.at,
                title: 'Mentions',
                subtitle: 'Post and comment mentions',
                value: _settings.notifyMentions,
                onChanged: (value) =>
                    _update(_settings.copyWith(notifyMentions: value)),
                color: primary,
                secondary: secondary,
              ),
              _SettingsToggleTile(
                icon: CupertinoIcons.person_add,
                title: 'Follows',
                subtitle: 'Followers and friend activity',
                value: _settings.notifyFollows,
                onChanged: (value) =>
                    _update(_settings.copyWith(notifyFollows: value)),
                color: primary,
                secondary: secondary,
              ),
              _SettingsToggleTile(
                icon: CupertinoIcons.text_bubble_fill,
                title: 'Message preview',
                subtitle: 'Show message content',
                value: _settings.messagePreview,
                onChanged: (value) =>
                    _update(_settings.copyWith(messagePreview: value)),
                color: primary,
                secondary: secondary,
              ),
            ],
          ),
        ];
      case _SettingsCategory.display:
        return [
          _SettingsSection(
            title: 'Appearance',
            subtitle: 'Visual preferences.',
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
                subtitle: 'Scale ${_settings.textScale.toStringAsFixed(2)}x',
                onTap: () => _showTextSizeSheet(isDark),
                color: primary,
                secondary: secondary,
              ),
              _SettingsTile(
                icon: CupertinoIcons.globe,
                title: 'Language',
                subtitle: _settings.languageLabel,
                onTap: () => PravaNavigator.push(context, const LanguagePage()),
                color: primary,
                secondary: secondary,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _SettingsSection(
            title: 'Motion and media',
            subtitle: 'Playback behavior.',
            surface: surface,
            border: border,
            children: [
              _SettingsToggleTile(
                icon: CupertinoIcons.film,
                title: 'Autoplay videos',
                subtitle: 'Play video previews',
                value: _settings.autoPlayVideos,
                onChanged: (value) =>
                    _update(_settings.copyWith(autoPlayVideos: value)),
                color: primary,
                secondary: secondary,
              ),
              _SettingsToggleTile(
                icon: CupertinoIcons.slowmo,
                title: 'Reduce motion',
                subtitle: 'Simplify animations',
                value: _settings.reduceMotion,
                onChanged: (value) =>
                    _update(_settings.copyWith(reduceMotion: value)),
                color: primary,
                secondary: secondary,
              ),
            ],
          ),
        ];
      case _SettingsCategory.data:
        return [
          _SettingsSection(
            title: 'Network and storage',
            subtitle: 'Control downloads and cache.',
            surface: surface,
            border: border,
            children: [
              _SettingsToggleTile(
                icon: CupertinoIcons.battery_25,
                title: 'Data saver',
                subtitle: 'Use less mobile data',
                value: _settings.dataSaver,
                onChanged: (value) =>
                    _update(_settings.copyWith(dataSaver: value)),
                color: primary,
                secondary: secondary,
              ),
              _SettingsToggleTile(
                icon: CupertinoIcons.arrow_down_circle,
                title: 'Media auto download',
                subtitle: 'Download media on wifi',
                value: _settings.autoDownload,
                onChanged: (value) =>
                    _update(_settings.copyWith(autoDownload: value)),
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
                onTap: _clearCache,
                color: primary,
                secondary: secondary,
              ),
              _SettingsTile(
                icon: CupertinoIcons.cloud_download,
                title: 'Download your data',
                subtitle: 'Export a copy of your data',
                onTap: () =>
                    PravaNavigator.push(context, const DataExportPage()),
                color: primary,
                secondary: secondary,
              ),
            ],
          ),
        ];
      case _SettingsCategory.support:
        return [
          _SettingsSection(
            title: 'Support',
            subtitle: 'Help and feedback.',
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
                subtitle: 'Share ideas',
                onTap: () => PravaNavigator.push(
                  context,
                  const HelpFeedbackPage(
                    initialSection: HelpFeedbackSection.feedback,
                  ),
                ),
                color: primary,
                secondary: secondary,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _SettingsSection(
            title: 'Legal',
            subtitle: 'Policies and version.',
            surface: surface,
            border: border,
            children: [
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
                subtitle: widget.versionLabel,
                onTap: () {},
                showChevron: false,
                color: primary,
                secondary: secondary,
              ),
            ],
          ),
        ];
      case _SettingsCategory.actions:
        return [
          _SettingsSection(
            title: 'Session',
            subtitle: 'Sign out of this device.',
            surface: surface,
            border: border,
            children: [
              _SettingsTile(
                icon: CupertinoIcons.square_arrow_right,
                title: 'Log out',
                subtitle: 'End this session',
                onTap: widget.onLogout,
                destructive: true,
                color: primary,
                secondary: secondary,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _SettingsSection(
            title: 'Danger zone',
            subtitle: 'Permanent account action.',
            surface: surface,
            border: border,
            children: [
              _SettingsTile(
                icon: CupertinoIcons.delete,
                title: 'Delete account',
                subtitle: 'Permanent and irreversible',
                onTap: widget.onDeleteAccount,
                destructive: true,
                color: primary,
                secondary: secondary,
              ),
            ],
          ),
        ];
    }
  }
}

const _categoryOrder = [
  _SettingsCategory.account,
  _SettingsCategory.privacy,
  _SettingsCategory.security,
  _SettingsCategory.notifications,
  _SettingsCategory.display,
  _SettingsCategory.data,
  _SettingsCategory.support,
  _SettingsCategory.actions,
];

String _categoryTrailing(_SettingsCategory category, SettingsState settings) {
  switch (category) {
    case _SettingsCategory.account:
      return 'Profile';
    case _SettingsCategory.privacy:
      return settings.privateAccount ? 'Private' : 'Public';
    case _SettingsCategory.security:
      return settings.twoFactor || settings.appLock ? 'Protected' : 'Standard';
    case _SettingsCategory.notifications:
      return settings.pushNotifications ? 'On' : 'Off';
    case _SettingsCategory.display:
      return settings.themeIndex == 2
          ? 'Dark'
          : settings.themeIndex == 1
          ? 'Light'
          : 'System';
    case _SettingsCategory.data:
      return settings.dataSaver ? 'Saver' : 'Normal';
    case _SettingsCategory.support:
      return 'Help';
    case _SettingsCategory.actions:
      return 'Session';
  }
}

class _SettingsCategoryMeta {
  const _SettingsCategoryMeta({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;

  static _SettingsCategoryMeta from(_SettingsCategory category) {
    switch (category) {
      case _SettingsCategory.account:
        return const _SettingsCategoryMeta(
          title: 'Account center',
          subtitle: 'Identity, profile, and links',
          icon: CupertinoIcons.person_crop_circle,
          accent: Color(0xFF5B8CFF),
        );
      case _SettingsCategory.privacy:
        return const _SettingsCategoryMeta(
          title: 'Privacy and safety',
          subtitle: 'Visibility, blocks, and filters',
          icon: CupertinoIcons.lock_fill,
          accent: Color(0xFF2EC4B6),
        );
      case _SettingsCategory.security:
        return const _SettingsCategoryMeta(
          title: 'Security',
          subtitle: 'Login, devices, and app lock',
          icon: CupertinoIcons.shield_lefthalf_fill,
          accent: Color(0xFF845EC2),
        );
      case _SettingsCategory.notifications:
        return const _SettingsCategoryMeta(
          title: 'Notifications',
          subtitle: 'Alerts, sounds, and event types',
          icon: CupertinoIcons.bell_fill,
          accent: Color(0xFFFFB703),
        );
      case _SettingsCategory.display:
        return const _SettingsCategoryMeta(
          title: 'Display and accessibility',
          subtitle: 'Theme, text, and motion',
          icon: CupertinoIcons.circle_lefthalf_fill,
          accent: Color(0xFF3CCB7F),
        );
      case _SettingsCategory.data:
        return const _SettingsCategoryMeta(
          title: 'Data and storage',
          subtitle: 'Network, cache, and export',
          icon: CupertinoIcons.tray_fill,
          accent: Color(0xFF00A6FB),
        );
      case _SettingsCategory.support:
        return const _SettingsCategoryMeta(
          title: 'Support and legal',
          subtitle: 'Help, feedback, and policies',
          icon: CupertinoIcons.question_circle_fill,
          accent: Color(0xFFEF476F),
        );
      case _SettingsCategory.actions:
        return const _SettingsCategoryMeta(
          title: 'Account actions',
          subtitle: 'Log out or delete account',
          icon: CupertinoIcons.square_arrow_right_fill,
          accent: PravaColors.error,
        );
    }
  }
}

class _SettingsTopBar extends StatelessWidget {
  const _SettingsTopBar({required this.primary});

  final Color primary;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: const Size(40, 40),
          onPressed: () => Navigator.of(context).pop(),
          child: const Icon(CupertinoIcons.back, size: 24),
        ),
        const SizedBox(width: 8),
        Text(
          'Settings',
          style: PravaTypography.h2.copyWith(
            color: primary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
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
    final primary = isDark
        ? PravaColors.darkTextPrimary
        : PravaColors.lightTextPrimary;
    final secondary = isDark
        ? PravaColors.darkTextSecondary
        : PravaColors.lightTextSecondary;

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white10
                : Colors.white.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(8),
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
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            if (verified) ...[
                              const SizedBox(width: 6),
                              const Icon(
                                CupertinoIcons.check_mark_circled_solid,
                                size: 16,
                                color: PravaColors.accentPrimary,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '@$username',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: PravaTypography.caption.copyWith(
                            color: secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              AnimatedOpacity(
                opacity: loading ? 0.45 : 1,
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

class _ControlCenterCard extends StatelessWidget {
  const _ControlCenterCard({
    required this.settings,
    required this.themeLabel,
    required this.primary,
    required this.secondary,
    required this.surface,
    required this.border,
  });

  final SettingsState settings;
  final String themeLabel;
  final Color primary;
  final Color secondary;
  final Color surface;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Central control',
            style: PravaTypography.h3.copyWith(
              color: primary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ControlStatus(
                  label: 'Privacy',
                  value: settings.privateAccount ? 'Private' : 'Public',
                  icon: CupertinoIcons.lock,
                  primary: primary,
                  secondary: secondary,
                ),
              ),
              Expanded(
                child: _ControlStatus(
                  label: 'Alerts',
                  value: settings.pushNotifications ? 'On' : 'Off',
                  icon: CupertinoIcons.bell,
                  primary: primary,
                  secondary: secondary,
                ),
              ),
              Expanded(
                child: _ControlStatus(
                  label: 'Theme',
                  value: themeLabel,
                  icon: CupertinoIcons.circle_lefthalf_fill,
                  primary: primary,
                  secondary: secondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ControlStatus extends StatelessWidget {
  const _ControlStatus({
    required this.label,
    required this.value,
    required this.icon,
    required this.primary,
    required this.secondary,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color primary;
  final Color secondary;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: PravaColors.accentPrimary, size: 19),
        const SizedBox(height: 7),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: PravaTypography.caption.copyWith(
            color: primary,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: PravaTypography.caption.copyWith(color: secondary),
        ),
      ],
    );
  }
}

class _SettingsCategoryTile extends StatelessWidget {
  const _SettingsCategoryTile({
    required this.meta,
    required this.primary,
    required this.secondary,
    required this.surface,
    required this.border,
    required this.trailing,
    required this.onTap,
  });

  final _SettingsCategoryMeta meta;
  final Color primary;
  final Color secondary;
  final Color surface;
  final Color border;
  final String trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: border),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: meta.accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(meta.icon, color: meta.accent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      meta.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: PravaTypography.body.copyWith(
                        color: primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      meta.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: PravaTypography.caption.copyWith(color: secondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                trailing,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: PravaTypography.caption.copyWith(
                  color: secondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 6),
              Icon(CupertinoIcons.chevron_right, size: 16, color: secondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryHero extends StatelessWidget {
  const _CategoryHero({
    required this.meta,
    required this.primary,
    required this.secondary,
  });

  final _SettingsCategoryMeta meta;
  final Color primary;
  final Color secondary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: meta.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(meta.icon, color: meta.accent, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  meta.title,
                  style: PravaTypography.h3.copyWith(
                    color: primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  meta.subtitle,
                  style: PravaTypography.caption.copyWith(color: secondary),
                ),
              ],
            ),
          ),
        ],
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
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: PravaColors.accentPrimary,
      ),
      child: CircleAvatar(
        radius: 24,
        backgroundColor: PravaColors.accentPrimary.withValues(alpha: 0.15),
        child: Text(
          initials,
          style: PravaTypography.h3.copyWith(
            color: PravaColors.accentPrimary,
            fontWeight: FontWeight.w800,
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
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: PravaTypography.caption.copyWith(color: secondary)),
      ],
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
    final primary = isDark
        ? PravaColors.darkTextPrimary
        : PravaColors.lightTextPrimary;
    final secondary = isDark
        ? PravaColors.darkTextSecondary
        : PravaColors.lightTextSecondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: PravaTypography.h3.copyWith(
            color: primary,
            fontWeight: FontWeight.w800,
          ),
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
            borderRadius: BorderRadius.circular(8),
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
    final iconColor = destructive
        ? PravaColors.error
        : PravaColors.accentPrimary;
    final textColor = destructive ? PravaColors.error : color;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
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
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PravaTypography.caption.copyWith(
                      color: destructive ? PravaColors.error : secondary,
                    ),
                  ),
                ],
              ),
            ),
            if (showChevron)
              Icon(CupertinoIcons.chevron_right, size: 16, color: secondary),
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
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: PravaColors.accentPrimary, size: 18),
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
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PravaTypography.caption.copyWith(color: secondary),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: PravaColors.accentPrimary,
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
    final primary = isDark
        ? PravaColors.darkTextPrimary
        : PravaColors.lightTextPrimary;

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
          Text(title, style: PravaTypography.h3.copyWith(color: primary)),
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
          ? const Icon(
              CupertinoIcons.check_mark_circled_solid,
              color: PravaColors.accentPrimary,
            )
          : null,
    );
  }
}
