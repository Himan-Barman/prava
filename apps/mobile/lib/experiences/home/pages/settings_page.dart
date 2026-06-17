import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../navigation/prava_navigator.dart';
import '../../../services/account_service.dart';
import '../../../services/auth_service.dart';
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
  profileVisibility,
  privacy,
  security,
  notifications,
  chats,
  feed,
  friends,
  appearance,
  accessibility,
  dataStorage,
  ai,
  creator,
  support,
  legal,
  danger,
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final AccountService _accountService = AccountService();
  final AuthService _authService = AuthService();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  SettingsController? _settingsController;

  String _versionLabel = 'Prava';
  SettingsState _settings = SettingsState.defaults();
  AccountInfo? _accountInfo;
  bool _accountLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
    _loadAccountInfo();
    _searchController.addListener(_handleSearchChanged);
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
    _searchController.removeListener(_handleSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
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

  Future<void> _loadAccountInfo() async {
    try {
      final account = await _accountService.fetchAccountInfo();
      if (!mounted) return;
      setState(() {
        _accountInfo = account;
        _accountLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _accountLoading = false);
    }
  }

  void _handleSearchChanged() {
    final nextQuery = _searchController.text;
    if (nextQuery == _searchQuery) return;
    setState(() => _searchQuery = nextQuery);
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

  List<_SettingsSearchEntry> _filteredSearchEntries() {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return const [];
    return _categoryOrder
        .map(
          (category) => _SettingsSearchEntry(
            category: category,
            meta: _SettingsCategoryMeta.from(category),
            keywords: _keywordsForCategory(category),
          ),
        )
        .where((entry) => entry.matches(query))
        .toList(growable: false);
  }

  int _profileCompletion() {
    final account = _accountInfo;
    if (account == null) return 0;
    final values = [
      account.displayName,
      account.username,
      account.email,
      account.avatarUrl,
      account.bio,
      account.location,
      account.website,
      account.phoneNumber,
    ];
    final completed = values.where((value) => value.trim().isNotEmpty).length;
    return ((completed / values.length) * 100).round().clamp(0, 100);
  }

  String _accountTypeLabel() {
    if (_settings.creatorMode || _accountInfo?.aiCreator == true) {
      return 'Creator account';
    }
    if (_settings.professionalMode) return 'Professional account';
    final category = _accountInfo?.category.trim();
    if (category != null && category.isNotEmpty) return category;
    return 'Personal account';
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
    final border = isDark
        ? PravaColors.darkBorderSubtle
        : PravaColors.lightBorderSubtle;
    final searchResults = _filteredSearchEntries();
    final isSearching = _searchQuery.trim().isNotEmpty;

    return Scaffold(
      body: Stack(
        children: [
          PravaBackground(isDark: isDark),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 10),
                  child: _SettingsTopBar(
                    primary: primary,
                    onSearchTap: () => _searchFocusNode.requestFocus(),
                  ),
                ),
                Expanded(
                  child: CustomScrollView(
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(18, 4, 18, 14),
                        sliver: SliverToBoxAdapter(
                          child: _SettingsSearchBar(
                            controller: _searchController,
                            focusNode: _searchFocusNode,
                            primary: primary,
                            secondary: secondary,
                            border: border,
                            isDark: isDark,
                          ),
                        ),
                      ),
                      if (isSearching)
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(18, 0, 18, 28),
                          sliver: SliverToBoxAdapter(
                            child: _SettingsSearchResults(
                              results: searchResults,
                              query: _searchQuery.trim(),
                              primary: primary,
                              secondary: secondary,
                              border: border,
                              onOpenCategory: _openCategory,
                            ),
                          ),
                        )
                      else ...[
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
                          sliver: SliverToBoxAdapter(
                            child: _SettingsAccountCard(
                              account: _accountInfo,
                              loading: _accountLoading,
                              completion: _profileCompletion(),
                              accountType: _accountTypeLabel(),
                              primary: primary,
                              secondary: secondary,
                              border: border,
                              isDark: isDark,
                              onManage: () =>
                                  _openCategory(_SettingsCategory.account),
                            ),
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
                          sliver: SliverToBoxAdapter(
                            child: _SettingsQuickControls(
                              primary: primary,
                              secondary: secondary,
                              border: border,
                              onOpenCategory: _openCategory,
                            ),
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
                          sliver: SliverToBoxAdapter(
                            child: Text(
                              'Settings groups',
                              style: PravaTypography.bodySmall.copyWith(
                                color: secondary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(18, 0, 18, 28),
                          sliver: SliverList.separated(
                            itemCount: _categoryOrder.length,
                            separatorBuilder: (_, __) =>
                                Divider(height: 1, color: border),
                            itemBuilder: (context, index) {
                              final category = _categoryOrder[index];
                              final meta = _SettingsCategoryMeta.from(category);
                              return _SettingsCategoryTile(
                                meta: meta,
                                primary: primary,
                                secondary: secondary,
                                trailing: _categoryTrailing(
                                  category,
                                  _settings,
                                ),
                                onTap: () => _openCategory(category),
                              );
                            },
                          ),
                        ),
                      ],
                    ],
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
                    style: PravaTypography.bodyMedium.copyWith(
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

  void _showOptionSheet({
    required String title,
    required List<String> options,
    required String selected,
    required ValueChanged<String> onSelected,
    required bool isDark,
  }) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _SettingsSheet(
          title: title,
          isDark: isDark,
          child: Column(
            children: [
              for (final option in options)
                _SheetOption(
                  label: _labelForOption(option),
                  selected: option == selected,
                  onTap: () {
                    onSelected(option);
                    Navigator.of(context).pop();
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  String _labelForOption(String value) {
    switch (value) {
      case 'forYou':
        return 'For You';
      case 'closeFriends':
        return 'Close friends';
      case 'onlyMe':
        return 'Only me';
      case 'premiumDark':
        return 'Premium dark';
      case 'extraLarge':
        return 'Extra large';
      case 'data_storage':
        return 'Data storage';
      default:
        if (value.isEmpty) return value;
        return '${value.substring(0, 1).toUpperCase()}${value.substring(1)}';
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
    final border = isDark
        ? PravaColors.darkBorderSubtle
        : PravaColors.lightBorderSubtle;

    return SettingsDetailShell(
      title: meta.title,
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
        children: [
          ..._buildCategorySections(
            context: context,
            category: widget.category,
            primary: primary,
            secondary: secondary,
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
    required Color border,
    required bool isDark,
  }) {
    switch (category) {
      case _SettingsCategory.account:
        return [
          _SettingsSection(
            title: 'Account center',
            subtitle: 'Identity and profile controls.',
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
                title: 'Username',
                subtitle: 'Search and change your username',
                onTap: () =>
                    PravaNavigator.push(context, const HandleLinksPage()),
                color: primary,
                secondary: secondary,
              ),
            ],
          ),
        ];
      case _SettingsCategory.profileVisibility:
        return [
          _SettingsSection(
            title: 'Profile visibility',
            subtitle: 'Control who can see profile content.',
            border: border,
            children: [
              _SettingsToggleTile(
                icon: CupertinoIcons.lock_fill,
                title: 'Private account',
                subtitle: 'Approve new followers before they see posts',
                value: _settings.privateAccount,
                onChanged: (value) =>
                    _update(_settings.copyWith(privateAccount: value)),
                color: primary,
                secondary: secondary,
              ),
              _SettingsTile(
                icon: CupertinoIcons.eye,
                title: 'Preview profile as',
                subtitle: 'Public, follower, friend, close friend',
                onTap: () => PravaToast.show(
                  context,
                  message: 'Use profile command center to preview visibility',
                  type: PravaToastType.info,
                ),
                color: primary,
                secondary: secondary,
              ),
              _SettingsTile(
                icon: CupertinoIcons.link,
                title: 'Profile sharing',
                subtitle: 'Copy links and future QR controls',
                onTap: () =>
                    PravaNavigator.push(context, const HandleLinksPage()),
                color: primary,
                secondary: secondary,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _SettingsSection(
            title: 'Field visibility',
            subtitle: 'Bio, location, website, followers, friends.',
            border: border,
            children: [
              _SettingsTile(
                icon: CupertinoIcons.person_crop_rectangle,
                title: 'Detailed visibility controls',
                subtitle: 'Posts, replies, media, about, and lists',
                onTap: () => PravaToast.show(
                  context,
                  message: 'Profile visibility is enforced by the backend',
                  type: PravaToastType.success,
                ),
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
      case _SettingsCategory.chats:
        return [
          _SettingsSection(
            title: 'Message privacy',
            subtitle: 'Control who can reach you.',
            border: border,
            children: [
              _SettingsTile(
                icon: CupertinoIcons.chat_bubble_2_fill,
                title: 'Who can message me',
                subtitle: _labelForOption(_settings.whoCanMessage),
                onTap: () => _showOptionSheet(
                  title: 'Who can message me',
                  options: const ['everyone', 'followers', 'friends', 'nobody'],
                  selected: _settings.whoCanMessage,
                  isDark: isDark,
                  onSelected: (value) =>
                      _update(_settings.copyWith(whoCanMessage: value)),
                ),
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
                icon: CupertinoIcons.text_bubble,
                title: 'Message previews',
                subtitle: 'Show message text in notifications',
                value: _settings.messagePreview,
                onChanged: (value) =>
                    _update(_settings.copyWith(messagePreview: value)),
                color: primary,
                secondary: secondary,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _SettingsSection(
            title: 'Group chats',
            subtitle: 'Manage group invites and defaults.',
            border: border,
            children: [
              _SettingsTile(
                icon: CupertinoIcons.person_3_fill,
                title: 'Who can add me to groups',
                subtitle: _labelForOption(_settings.whoCanAddToGroups),
                onTap: () => _showOptionSheet(
                  title: 'Group invites',
                  options: const ['everyone', 'friends', 'nobody'],
                  selected: _settings.whoCanAddToGroups,
                  isDark: isDark,
                  onSelected: (value) =>
                      _update(_settings.copyWith(whoCanAddToGroups: value)),
                ),
                color: primary,
                secondary: secondary,
              ),
            ],
          ),
        ];
      case _SettingsCategory.feed:
        return [
          _SettingsSection(
            title: 'Feed mode',
            subtitle: 'Choose your default feed experience.',
            border: border,
            children: [
              _SettingsTile(
                icon: CupertinoIcons.rectangle_stack_fill,
                title: 'Default feed',
                subtitle: _labelForOption(_settings.defaultFeedMode),
                onTap: () => _showOptionSheet(
                  title: 'Default feed',
                  options: const [
                    'forYou',
                    'following',
                    'friends',
                    'latest',
                    'trending',
                  ],
                  selected: _settings.defaultFeedMode,
                  isDark: isDark,
                  onSelected: (value) =>
                      _update(_settings.copyWith(defaultFeedMode: value)),
                ),
                color: primary,
                secondary: secondary,
              ),
              _SettingsTile(
                icon: CupertinoIcons.slider_horizontal_3,
                title: 'Personalization level',
                subtitle: _labelForOption(_settings.personalizationLevel),
                onTap: () => _showOptionSheet(
                  title: 'Personalization',
                  options: const ['low', 'balanced', 'high'],
                  selected: _settings.personalizationLevel,
                  isDark: isDark,
                  onSelected: (value) =>
                      _update(_settings.copyWith(personalizationLevel: value)),
                ),
                color: primary,
                secondary: secondary,
              ),
              _SettingsToggleTile(
                icon: CupertinoIcons.sparkles,
                title: 'Recommended posts',
                subtitle: 'Use activity for For You ranking',
                value: _settings.showRecommendedPosts,
                onChanged: (value) =>
                    _update(_settings.copyWith(showRecommendedPosts: value)),
                color: primary,
                secondary: secondary,
              ),
              _SettingsToggleTile(
                icon: CupertinoIcons.flame,
                title: 'Trending posts',
                subtitle: 'Show trending content modules',
                value: _settings.showTrendingPosts,
                onChanged: (value) =>
                    _update(_settings.copyWith(showTrendingPosts: value)),
                color: primary,
                secondary: secondary,
              ),
              _SettingsToggleTile(
                icon: CupertinoIcons.person_2_fill,
                title: 'Friends first',
                subtitle: 'Prioritize friends in recommendations',
                value: _settings.showFriendsFirst,
                onChanged: (value) =>
                    _update(_settings.copyWith(showFriendsFirst: value)),
                color: primary,
                secondary: secondary,
              ),
            ],
          ),
        ];
      case _SettingsCategory.friends:
        return [
          _SettingsSection(
            title: 'Social graph',
            subtitle: 'Friend requests and close circles.',
            border: border,
            children: [
              _SettingsToggleTile(
                icon: CupertinoIcons.person_2_fill,
                title: 'People you may know',
                subtitle: 'Use signals to suggest friends',
                value: _settings.aiFriendSuggestions,
                onChanged: (value) =>
                    _update(_settings.copyWith(aiFriendSuggestions: value)),
                color: primary,
                secondary: secondary,
              ),
              _SettingsToggleTile(
                icon: CupertinoIcons.star_fill,
                title: 'Friends-first activity',
                subtitle: 'Prioritize mutual friend activity',
                value: _settings.showFriendsFirst,
                onChanged: (value) =>
                    _update(_settings.copyWith(showFriendsFirst: value)),
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
            ],
          ),
        ];
      case _SettingsCategory.appearance:
        return [
          _SettingsSection(
            title: 'Appearance',
            subtitle: 'Visual preferences.',
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
                title: 'Font size',
                subtitle: _labelForOption(_settings.fontSize),
                onTap: () => _showOptionSheet(
                  title: 'Font size',
                  options: const ['small', 'default', 'large', 'extraLarge'],
                  selected: _settings.fontSize,
                  isDark: isDark,
                  onSelected: (value) =>
                      _update(_settings.copyWith(fontSize: value)),
                ),
                color: primary,
                secondary: secondary,
              ),
              _SettingsTile(
                icon: CupertinoIcons.rectangle_grid_1x2,
                title: 'Display density',
                subtitle: _labelForOption(_settings.displayDensity),
                onTap: () => _showOptionSheet(
                  title: 'Display density',
                  options: const ['compact', 'comfortable', 'spacious'],
                  selected: _settings.displayDensity,
                  isDark: isDark,
                  onSelected: (value) =>
                      _update(_settings.copyWith(displayDensity: value)),
                ),
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
      case _SettingsCategory.accessibility:
        return [
          _SettingsSection(
            title: 'Readable interface',
            subtitle: 'Text, contrast, and screen reader support.',
            border: border,
            children: [
              _SettingsTile(
                icon: CupertinoIcons.textformat_size,
                title: 'Text size',
                subtitle: 'Scale ${_settings.textScale.toStringAsFixed(2)}x',
                onTap: () => _showTextSizeSheet(isDark),
                color: primary,
                secondary: secondary,
              ),
              _SettingsToggleTile(
                icon: CupertinoIcons.circle_lefthalf_fill,
                title: 'High contrast',
                subtitle: 'Increase contrast across surfaces',
                value: _settings.highContrast,
                onChanged: (value) =>
                    _update(_settings.copyWith(highContrast: value)),
                color: primary,
                secondary: secondary,
              ),
              _SettingsToggleTile(
                icon: CupertinoIcons.bold,
                title: 'Bold text',
                subtitle: 'Use heavier text for labels',
                value: _settings.boldText,
                onChanged: (value) =>
                    _update(_settings.copyWith(boldText: value)),
                color: primary,
                secondary: secondary,
              ),
              _SettingsToggleTile(
                icon: CupertinoIcons.hand_draw,
                title: 'Larger touch targets',
                subtitle: 'Make controls easier to tap',
                value: _settings.largerTouchTargets,
                onChanged: (value) =>
                    _update(_settings.copyWith(largerTouchTargets: value)),
                color: primary,
                secondary: secondary,
              ),
              _SettingsToggleTile(
                icon: CupertinoIcons.speaker_2_fill,
                title: 'Enhanced screen reader labels',
                subtitle: 'More descriptive accessibility labels',
                value: _settings.screenReaderEnhancedLabels,
                onChanged: (value) => _update(
                  _settings.copyWith(screenReaderEnhancedLabels: value),
                ),
                color: primary,
                secondary: secondary,
              ),
            ],
          ),
        ];
      case _SettingsCategory.dataStorage:
        return [
          _SettingsSection(
            title: 'Network and storage',
            subtitle: 'Control downloads and cache.',
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
                icon: CupertinoIcons.photo,
                title: 'Media quality',
                subtitle: _labelForOption(_settings.mediaQuality),
                onTap: () => _showOptionSheet(
                  title: 'Media quality',
                  options: const ['auto', 'low', 'standard', 'high'],
                  selected: _settings.mediaQuality,
                  isDark: isDark,
                  onSelected: (value) =>
                      _update(_settings.copyWith(mediaQuality: value)),
                ),
                color: primary,
                secondary: secondary,
              ),
              _SettingsTile(
                icon: CupertinoIcons.folder,
                title: 'Cache size',
                subtitle: _cacheSizeLabel,
                onTap: () {},
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
      case _SettingsCategory.ai:
        return [
          _SettingsSection(
            title: 'AI personalization',
            subtitle: 'Control recommendation intelligence.',
            border: border,
            children: [
              _SettingsToggleTile(
                icon: CupertinoIcons.sparkles,
                title: 'Personalized feed',
                subtitle: 'Use activity to improve For You',
                value: _settings.aiPersonalizedFeed,
                onChanged: (value) =>
                    _update(_settings.copyWith(aiPersonalizedFeed: value)),
                color: primary,
                secondary: secondary,
              ),
              _SettingsToggleTile(
                icon: CupertinoIcons.person_2_fill,
                title: 'AI friend suggestions',
                subtitle: 'Suggest relevant people',
                value: _settings.aiFriendSuggestions,
                onChanged: (value) =>
                    _update(_settings.copyWith(aiFriendSuggestions: value)),
                color: primary,
                secondary: secondary,
              ),
              _SettingsToggleTile(
                icon: CupertinoIcons.rectangle_stack,
                title: 'AI post recommendations',
                subtitle: 'Tune ranking with AI signals',
                value: _settings.aiPostRecommendations,
                onChanged: (value) =>
                    _update(_settings.copyWith(aiPostRecommendations: value)),
                color: primary,
                secondary: secondary,
              ),
              _SettingsToggleTile(
                icon: CupertinoIcons.chat_bubble_text,
                title: 'Smart replies',
                subtitle: 'Future AI reply suggestions',
                value: _settings.aiSmartReplies,
                onChanged: (value) =>
                    _update(_settings.copyWith(aiSmartReplies: value)),
                color: primary,
                secondary: secondary,
              ),
            ],
          ),
        ];
      case _SettingsCategory.creator:
        return [
          _SettingsSection(
            title: 'Creator mode',
            subtitle: 'Professional profile and analytics controls.',
            border: border,
            children: [
              _SettingsToggleTile(
                icon: CupertinoIcons.chart_bar_alt_fill,
                title: 'Creator account',
                subtitle: 'Enable creator tools and profile surfaces',
                value: _settings.creatorMode,
                onChanged: (value) =>
                    _update(_settings.copyWith(creatorMode: value)),
                color: primary,
                secondary: secondary,
              ),
              _SettingsToggleTile(
                icon: CupertinoIcons.briefcase_fill,
                title: 'Professional mode',
                subtitle: 'Business-oriented profile options',
                value: _settings.professionalMode,
                onChanged: (value) =>
                    _update(_settings.copyWith(professionalMode: value)),
                color: primary,
                secondary: secondary,
              ),
              _SettingsToggleTile(
                icon: CupertinoIcons.envelope_fill,
                title: 'Public contact button',
                subtitle: 'Show contact CTA on profile',
                value: _settings.publicContactButton,
                onChanged: (value) =>
                    _update(_settings.copyWith(publicContactButton: value)),
                color: primary,
                secondary: secondary,
              ),
              _SettingsToggleTile(
                icon: CupertinoIcons.checkmark_seal_fill,
                title: 'Creator badge',
                subtitle: 'Show creator badge publicly',
                value: _settings.showCreatorBadge,
                onChanged: (value) =>
                    _update(_settings.copyWith(showCreatorBadge: value)),
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
        ];
      case _SettingsCategory.legal:
        return [
          _SettingsSection(
            title: 'Legal',
            subtitle: 'Policies, licenses, and app version.',
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
                color: primary,
                secondary: secondary,
              ),
            ],
          ),
        ];
      case _SettingsCategory.danger:
        return [
          _SettingsSection(
            title: 'Session',
            subtitle: 'Sign out of this device.',
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
  _SettingsCategory.profileVisibility,
  _SettingsCategory.privacy,
  _SettingsCategory.security,
  _SettingsCategory.notifications,
  _SettingsCategory.chats,
  _SettingsCategory.feed,
  _SettingsCategory.friends,
  _SettingsCategory.appearance,
  _SettingsCategory.accessibility,
  _SettingsCategory.dataStorage,
  _SettingsCategory.ai,
  _SettingsCategory.creator,
  _SettingsCategory.support,
  _SettingsCategory.legal,
  _SettingsCategory.danger,
];

String _categoryTrailing(_SettingsCategory category, SettingsState settings) {
  switch (category) {
    case _SettingsCategory.account:
      return 'Profile';
    case _SettingsCategory.profileVisibility:
      return settings.privateAccount ? 'Private' : 'Public';
    case _SettingsCategory.privacy:
      return settings.privateAccount ? 'Private' : 'Public';
    case _SettingsCategory.security:
      return settings.twoFactor || settings.appLock ? 'Protected' : 'Standard';
    case _SettingsCategory.notifications:
      return settings.pushNotifications ? 'On' : 'Off';
    case _SettingsCategory.chats:
      return settings.whoCanMessage;
    case _SettingsCategory.feed:
      return settings.personalizationLevel;
    case _SettingsCategory.friends:
      return settings.showFriendsFirst ? 'Priority' : 'Standard';
    case _SettingsCategory.appearance:
      return settings.themeIndex == 2
          ? 'Dark'
          : settings.themeIndex == 1
          ? 'Light'
          : 'System';
    case _SettingsCategory.accessibility:
      return settings.reduceMotion || settings.highContrast
          ? 'Custom'
          : 'Default';
    case _SettingsCategory.dataStorage:
      return settings.dataSaver ? 'Saver' : 'Normal';
    case _SettingsCategory.ai:
      return settings.aiPersonalizedFeed ? 'On' : 'Off';
    case _SettingsCategory.creator:
      return settings.creatorMode ? 'Creator' : 'Personal';
    case _SettingsCategory.support:
      return 'Help';
    case _SettingsCategory.legal:
      return 'About';
    case _SettingsCategory.danger:
      return 'Session';
  }
}

List<String> _keywordsForCategory(_SettingsCategory category) {
  switch (category) {
    case _SettingsCategory.account:
      return const [
        'personal',
        'information',
        'username',
        'email',
        'phone',
        'password',
        'verification',
        'account type',
      ];
    case _SettingsCategory.profileVisibility:
      return const [
        'profile',
        'visibility',
        'public',
        'private',
        'bio',
        'followers',
        'preview',
        'sharing',
      ];
    case _SettingsCategory.privacy:
      return const [
        'privacy',
        'blocked',
        'muted',
        'activity',
        'read receipts',
        'mentions',
        'tags',
        'sensitive',
      ];
    case _SettingsCategory.security:
      return const [
        'security',
        'password',
        'two factor',
        '2fa',
        'login',
        'devices',
        'sessions',
        'biometric',
      ];
    case _SettingsCategory.notifications:
      return const [
        'notifications',
        'push',
        'email',
        'sound',
        'haptics',
        'quiet hours',
        'badge',
      ];
    case _SettingsCategory.chats:
      return const [
        'chats',
        'messages',
        'requests',
        'group',
        'read receipts',
        'preview',
        'typing',
      ];
    case _SettingsCategory.feed:
      return const [
        'feed',
        'for you',
        'following',
        'ranking',
        'recommendations',
        'topics',
        'muted words',
      ];
    case _SettingsCategory.friends:
      return const [
        'friends',
        'followers',
        'requests',
        'close friends',
        'suggestions',
        'social graph',
      ];
    case _SettingsCategory.appearance:
      return const [
        'appearance',
        'theme',
        'dark',
        'light',
        'font',
        'density',
        'language',
        'motion',
      ];
    case _SettingsCategory.accessibility:
      return const [
        'accessibility',
        'text size',
        'contrast',
        'bold',
        'motion',
        'screen reader',
        'touch',
      ];
    case _SettingsCategory.dataStorage:
      return const [
        'data',
        'storage',
        'cache',
        'download',
        'export',
        'media quality',
        'data saver',
      ];
    case _SettingsCategory.ai:
      return const [
        'ai',
        'personalization',
        'recommendations',
        'smart replies',
        'suggestions',
      ];
    case _SettingsCategory.creator:
      return const ['creator', 'professional', 'analytics', 'badge', 'contact'];
    case _SettingsCategory.support:
      return const [
        'help',
        'support',
        'report',
        'feedback',
        'ticket',
        'problem',
      ];
    case _SettingsCategory.legal:
      return const [
        'legal',
        'about',
        'privacy policy',
        'terms',
        'licenses',
        'version',
      ];
    case _SettingsCategory.danger:
      return const [
        'danger',
        'logout',
        'delete',
        'deactivate',
        'remove account',
      ];
  }
}

class _SettingsSearchEntry {
  const _SettingsSearchEntry({
    required this.category,
    required this.meta,
    required this.keywords,
  });

  final _SettingsCategory category;
  final _SettingsCategoryMeta meta;
  final List<String> keywords;

  bool matches(String query) {
    final haystack = [
      meta.title,
      meta.subtitle,
      ...keywords,
    ].join(' ').toLowerCase();
    return haystack.contains(query);
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
      case _SettingsCategory.profileVisibility:
        return const _SettingsCategoryMeta(
          title: 'Profile and visibility',
          subtitle: 'Profile privacy, fields, and preview',
          icon: CupertinoIcons.eye_fill,
          accent: Color(0xFF4D96FF),
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
      case _SettingsCategory.chats:
        return const _SettingsCategoryMeta(
          title: 'Chats and messages',
          subtitle: 'Message privacy, groups, and receipts',
          icon: CupertinoIcons.chat_bubble_2_fill,
          accent: Color(0xFF6C63FF),
        );
      case _SettingsCategory.feed:
        return const _SettingsCategoryMeta(
          title: 'Feed and content',
          subtitle: 'Ranking, topics, and personalization',
          icon: CupertinoIcons.square_list_fill,
          accent: Color(0xFFFF6B6B),
        );
      case _SettingsCategory.friends:
        return const _SettingsCategoryMeta(
          title: 'Friends and social graph',
          subtitle: 'Requests, close friends, suggestions',
          icon: CupertinoIcons.person_2_fill,
          accent: Color(0xFF00B894),
        );
      case _SettingsCategory.appearance:
        return const _SettingsCategoryMeta(
          title: 'Appearance',
          subtitle: 'Theme, accent, density, and motion',
          icon: CupertinoIcons.circle_lefthalf_fill,
          accent: Color(0xFF3CCB7F),
        );
      case _SettingsCategory.accessibility:
        return const _SettingsCategoryMeta(
          title: 'Accessibility',
          subtitle: 'Text, contrast, motion, touch targets',
          icon: CupertinoIcons.textformat_size,
          accent: Color(0xFF9B5DE5),
        );
      case _SettingsCategory.dataStorage:
        return const _SettingsCategoryMeta(
          title: 'Data and storage',
          subtitle: 'Network, cache, and export',
          icon: CupertinoIcons.tray_fill,
          accent: Color(0xFF00A6FB),
        );
      case _SettingsCategory.ai:
        return const _SettingsCategoryMeta(
          title: 'AI and personalization',
          subtitle: 'Recommendations and smart features',
          icon: CupertinoIcons.sparkles,
          accent: Color(0xFF64D2FF),
        );
      case _SettingsCategory.creator:
        return const _SettingsCategoryMeta(
          title: 'Creator and professional',
          subtitle: 'Creator mode, badge, analytics',
          icon: CupertinoIcons.chart_bar_alt_fill,
          accent: Color(0xFFFF8FAB),
        );
      case _SettingsCategory.support:
        return const _SettingsCategoryMeta(
          title: 'Help and support',
          subtitle: 'Help center, reports, support tickets',
          icon: CupertinoIcons.question_circle_fill,
          accent: Color(0xFFEF476F),
        );
      case _SettingsCategory.legal:
        return const _SettingsCategoryMeta(
          title: 'Legal and about',
          subtitle: 'Policies, licenses, version',
          icon: CupertinoIcons.doc_text_fill,
          accent: Color(0xFF8E8E93),
        );
      case _SettingsCategory.danger:
        return const _SettingsCategoryMeta(
          title: 'Danger zone',
          subtitle: 'Logout, deactivate, delete',
          icon: CupertinoIcons.square_arrow_right_fill,
          accent: PravaColors.error,
        );
    }
  }
}

class _SettingsTopBar extends StatelessWidget {
  const _SettingsTopBar({required this.primary, required this.onSearchTap});

  final Color primary;
  final VoidCallback onSearchTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Settings',
            style: PravaTypography.titleLarge.copyWith(
              color: primary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        IconButton(
          onPressed: onSearchTap,
          icon: Icon(CupertinoIcons.search, color: primary, size: 26),
          tooltip: 'Search settings',
        ),
      ],
    );
  }
}

class _SettingsSearchBar extends StatelessWidget {
  const _SettingsSearchBar({
    required this.controller,
    required this.focusNode,
    required this.primary,
    required this.secondary,
    required this.border,
    required this.isDark,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final Color primary;
  final Color secondary;
  final Color border;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final fill = isDark
        ? PravaColors.darkBgElevated
        : PravaColors.lightBgElevated;
    return Container(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        style: PravaTypography.bodyMedium.copyWith(color: primary),
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search settings',
          hintStyle: PravaTypography.bodyMedium.copyWith(color: secondary),
          border: InputBorder.none,
          prefixIcon: Icon(CupertinoIcons.search, color: secondary, size: 22),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  onPressed: controller.clear,
                  icon: Icon(
                    CupertinoIcons.xmark_circle_fill,
                    color: secondary,
                  ),
                  tooltip: 'Clear search',
                ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }
}

class _SettingsSearchResults extends StatelessWidget {
  const _SettingsSearchResults({
    required this.results,
    required this.query,
    required this.primary,
    required this.secondary,
    required this.border,
    required this.onOpenCategory,
  });

  final List<_SettingsSearchEntry> results;
  final String query;
  final Color primary;
  final Color secondary;
  final Color border;
  final ValueChanged<_SettingsCategory> onOpenCategory;

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 18),
        child: Column(
          children: [
            Icon(CupertinoIcons.search, color: secondary, size: 30),
            const SizedBox(height: 10),
            Text(
              'No settings found for "$query"',
              textAlign: TextAlign.center,
              style: PravaTypography.bodyMedium.copyWith(
                color: primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Try privacy, password, blocked, feed, or delete.',
              textAlign: TextAlign.center,
              style: PravaTypography.caption.copyWith(color: secondary),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Results',
          style: PravaTypography.bodySmall.copyWith(
            color: secondary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: border),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            children: [
              for (var i = 0; i < results.length; i++) ...[
                _SettingsCategoryTile(
                  meta: results[i].meta,
                  primary: primary,
                  secondary: secondary,
                  trailing: 'Open',
                  onTap: () => onOpenCategory(results[i].category),
                ),
                if (i != results.length - 1) Divider(height: 1, color: border),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsAccountCard extends StatelessWidget {
  const _SettingsAccountCard({
    required this.account,
    required this.loading,
    required this.completion,
    required this.accountType,
    required this.primary,
    required this.secondary,
    required this.border,
    required this.isDark,
    required this.onManage,
  });

  final AccountInfo? account;
  final bool loading;
  final int completion;
  final String accountType;
  final Color primary;
  final Color secondary;
  final Color border;
  final bool isDark;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final fill = isDark
        ? PravaColors.darkBgElevated
        : PravaColors.lightBgElevated;
    final name =
        (account?.displayName.trim().isNotEmpty == true
                ? account!.displayName
                : account?.username ?? 'Prava account')
            .trim();
    final username = account?.username.trim() ?? '';
    final avatar = account?.avatarUrl.trim() ?? '';
    final initial = name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'P';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 29,
              backgroundColor: PravaColors.accentPrimary.withValues(
                alpha: 0.16,
              ),
              backgroundImage: avatar.isEmpty ? null : NetworkImage(avatar),
              child: avatar.isEmpty
                  ? Text(
                      initial,
                      style: PravaTypography.titleMedium.copyWith(
                        color: PravaColors.accentPrimary,
                        fontWeight: FontWeight.w900,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 13),
            Expanded(
              child: loading
                  ? LinearProgressIndicator(
                      minHeight: 3,
                      color: PravaColors.accentPrimary,
                      backgroundColor: border,
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: PravaTypography.bodyMedium.copyWith(
                                  color: primary,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            if (account?.isVerified == true) ...[
                              const SizedBox(width: 5),
                              const Icon(
                                CupertinoIcons.checkmark_seal_fill,
                                color: PravaColors.accentPrimary,
                                size: 17,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          username.isEmpty ? accountType : '@$username',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: PravaTypography.caption.copyWith(
                            color: secondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            minHeight: 5,
                            value: completion / 100,
                            color: PravaColors.accentPrimary,
                            backgroundColor: border,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          '$completion% complete · $accountType',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: PravaTypography.caption.copyWith(
                            color: secondary,
                          ),
                        ),
                      ],
                    ),
            ),
            const SizedBox(width: 10),
            TextButton(onPressed: onManage, child: const Text('Manage')),
          ],
        ),
      ),
    );
  }
}

class _SettingsQuickControls extends StatelessWidget {
  const _SettingsQuickControls({
    required this.primary,
    required this.secondary,
    required this.border,
    required this.onOpenCategory,
  });

  final Color primary;
  final Color secondary;
  final Color border;
  final ValueChanged<_SettingsCategory> onOpenCategory;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick controls',
          style: PravaTypography.bodySmall.copyWith(
            color: secondary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.65,
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          children: [
            _QuickControlCard(
              title: 'Privacy Checkup',
              icon: CupertinoIcons.lock_shield,
              primary: primary,
              secondary: secondary,
              border: border,
              onTap: () => onOpenCategory(_SettingsCategory.privacy),
            ),
            _QuickControlCard(
              title: 'Security Checkup',
              icon: CupertinoIcons.shield_lefthalf_fill,
              primary: primary,
              secondary: secondary,
              border: border,
              onTap: () => onOpenCategory(_SettingsCategory.security),
            ),
            _QuickControlCard(
              title: 'Notifications',
              icon: CupertinoIcons.bell_fill,
              primary: primary,
              secondary: secondary,
              border: border,
              onTap: () => onOpenCategory(_SettingsCategory.notifications),
            ),
            _QuickControlCard(
              title: 'Appearance',
              icon: CupertinoIcons.circle_lefthalf_fill,
              primary: primary,
              secondary: secondary,
              border: border,
              onTap: () => onOpenCategory(_SettingsCategory.appearance),
            ),
            _QuickControlCard(
              title: 'Data & Storage',
              icon: CupertinoIcons.tray_fill,
              primary: primary,
              secondary: secondary,
              border: border,
              onTap: () => onOpenCategory(_SettingsCategory.dataStorage),
            ),
          ],
        ),
      ],
    );
  }
}

class _QuickControlCard extends StatelessWidget {
  const _QuickControlCard({
    required this.title,
    required this.icon,
    required this.primary,
    required this.secondary,
    required this.border,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final Color primary;
  final Color secondary;
  final Color border;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(icon, color: PravaColors.accentPrimary, size: 21),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PravaTypography.bodySmall.copyWith(
                    color: primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsCategoryTile extends StatelessWidget {
  const _SettingsCategoryTile({
    required this.meta,
    required this.primary,
    required this.secondary,
    required this.trailing,
    required this.onTap,
  });

  final _SettingsCategoryMeta meta;
  final Color primary;
  final Color secondary;
  final String trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            children: [
              Icon(meta.icon, color: meta.accent, size: 25),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      meta.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: PravaTypography.bodyMedium.copyWith(
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
            ],
          ),
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
    required this.border,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;
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
          style: PravaTypography.titleSmall.copyWith(
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
        Column(children: _withDividers()),
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
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color color;
  final Color secondary;
  final bool destructive;

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
            SizedBox(width: 30, child: Icon(icon, color: iconColor, size: 21)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: PravaTypography.bodyMedium.copyWith(
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
          SizedBox(
            width: 30,
            child: Icon(icon, color: PravaColors.accentPrimary, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: PravaTypography.bodyMedium.copyWith(
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
          Text(
            title,
            style: PravaTypography.titleSmall.copyWith(color: primary),
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
          ? const Icon(
              CupertinoIcons.check_mark_circled_solid,
              color: PravaColors.accentPrimary,
            )
          : null,
    );
  }
}
