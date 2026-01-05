import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../services/account_service.dart';
import '../../../services/auth_service.dart';
import '../../../ui-system/colors.dart';
import '../../../ui-system/typography.dart';
import '../../../ui-system/components/prava_button.dart';
import '../../../ui-system/components/prava_input.dart';
import '../../../ui-system/feedback/prava_toast.dart';
import '../../../ui-system/feedback/toast_type.dart';
import 'settings_detail_shell.dart';

class HandleLinksPage extends StatefulWidget {
  const HandleLinksPage({super.key});

  @override
  State<HandleLinksPage> createState() => _HandleLinksPageState();
}

class _HandleLinksPageState extends State<HandleLinksPage> {
  final AccountService _accountService = AccountService();
  final AuthService _authService = AuthService();

  final _usernameController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _bioController = TextEditingController();
  final _locationController = TextEditingController();
  final _websiteController = TextEditingController();

  AccountInfo? _account;
  bool _loading = true;
  bool _saving = false;
  bool _checkingUsername = false;
  bool? _usernameAvailable;
  Timer? _usernameTimer;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _usernameController.addListener(_onUsernameChanged);
  }

  @override
  void dispose() {
    _usernameTimer?.cancel();
    _usernameController.removeListener(_onUsernameChanged);
    _usernameController.dispose();
    _displayNameController.dispose();
    _bioController.dispose();
    _locationController.dispose();
    _websiteController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final info = await _accountService.fetchAccountInfo();
      if (!mounted) return;
      setState(() {
        _account = info;
        _usernameController.text = info.username;
        _displayNameController.text = info.displayName;
        _bioController.text = info.bio;
        _locationController.text = info.location;
        _websiteController.text = info.website;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      PravaToast.show(
        context,
        message: 'Unable to load profile details',
        type: PravaToastType.error,
      );
    }
  }

  void _onUsernameChanged() {
    final text = _usernameController.text.trim();
    final current = _account?.username ?? '';
    _usernameTimer?.cancel();

    if (text.isEmpty || text == current) {
      setState(() {
        _usernameAvailable = null;
        _checkingUsername = false;
      });
      return;
    }

    if (text.length < 3) {
      setState(() {
        _usernameAvailable = false;
        _checkingUsername = false;
      });
      return;
    }

    setState(() => _checkingUsername = true);
    _usernameTimer = Timer(const Duration(milliseconds: 450), () async {
      try {
        final available = await _authService.isUsernameAvailable(text);
        if (!mounted) return;
        setState(() {
          _usernameAvailable = available;
          _checkingUsername = false;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _usernameAvailable = false;
          _checkingUsername = false;
        });
      }
    });
  }

  Future<void> _saveProfile() async {
    if (_saving) return;
    final username = _usernameController.text.trim();
    if (username.isEmpty) {
      PravaToast.show(
        context,
        message: 'Username is required',
        type: PravaToastType.warning,
      );
      return;
    }
    if (_usernameAvailable == false) {
      PravaToast.show(
        context,
        message: 'Choose a different username',
        type: PravaToastType.warning,
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final updated = await _accountService.updateHandle(
        username: username,
        displayName: _displayNameController.text.trim(),
        bio: _bioController.text.trim(),
        location: _locationController.text.trim(),
        website: _websiteController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _account = updated;
        _saving = false;
      });
      PravaToast.show(
        context,
        message: 'Profile updated',
        type: PravaToastType.success,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      PravaToast.show(
        context,
        message: 'Unable to update profile',
        type: PravaToastType.error,
      );
    }
  }

  String _usernameStatus() {
    if (_checkingUsername) return 'Checking availability...';
    if (_usernameAvailable == null) return 'Username';
    return _usernameAvailable == true ? 'Username is available' : 'Username is taken';
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

    return SettingsDetailShell(
      title: 'Handle and links',
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                _SectionCard(
                  title: 'Public profile',
                  subtitle: _usernameStatus(),
                  primary: primary,
                  secondary: secondary,
                  border: border,
                  surface: surface,
                  child: Column(
                    children: [
                      PravaInput(
                        controller: _usernameController,
                        hint: 'Username',
                      ),
                      const SizedBox(height: 12),
                      PravaInput(
                        controller: _displayNameController,
                        hint: 'Display name',
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _bioController,
                        maxLines: 4,
                        style: PravaTypography.body.copyWith(color: primary),
                        decoration: InputDecoration(
                          hintText: 'Bio',
                          hintStyle:
                              PravaTypography.body.copyWith(color: secondary),
                          border: InputBorder.none,
                          filled: true,
                          fillColor: isDark
                              ? PravaColors.darkSurface
                              : PravaColors.lightSurface,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      PravaInput(
                        controller: _locationController,
                        hint: 'Location',
                      ),
                      const SizedBox(height: 12),
                      PravaInput(
                        controller: _websiteController,
                        hint: 'Website',
                        keyboardType: TextInputType.url,
                      ),
                      const SizedBox(height: 12),
                      PravaButton(
                        label: 'Save changes',
                        loading: _saving,
                        onPressed: _saving ? null : _saveProfile,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.primary,
    required this.secondary,
    required this.border,
    required this.surface,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Color primary;
  final Color secondary;
  final Color border;
  final Color surface;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: PravaTypography.h3.copyWith(
                  color: primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: PravaTypography.bodySmall.copyWith(color: secondary),
              ),
              const SizedBox(height: 16),
              child,
            ],
          ),
        ),
      ),
    );
  }
}
