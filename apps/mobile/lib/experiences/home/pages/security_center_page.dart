import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../../navigation/prava_navigator.dart';
import '../../../shell/settings_controller.dart';
import '../../../services/settings_service.dart';
import '../../../ui-system/colors.dart';
import '../../../ui-system/typography.dart';
import 'devices_page.dart';
import 'settings_detail_shell.dart';

class SecurityCenterPage extends StatefulWidget {
  const SecurityCenterPage({super.key});

  @override
  State<SecurityCenterPage> createState() => _SecurityCenterPageState();
}

class _SecurityCenterPageState extends State<SecurityCenterPage> {
  void _update(SettingsState next) {
    HapticFeedback.selectionClick();
    SettingsScope.of(context).update(next);
  }

  @override
  Widget build(BuildContext context) {
    final controller = SettingsScope.of(context);
    final settings = controller.state;
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
      title: 'Security center',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Container(
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: border),
            ),
            child: Column(
              children: [
                _ToggleTile(
                  icon: CupertinoIcons.shield_lefthalf_fill,
                  title: 'Two factor authentication',
                  subtitle: 'Require a code on login',
                  value: settings.twoFactor,
                  onChanged: (value) =>
                      _update(settings.copyWith(twoFactor: value)),
                  primary: primary,
                  secondary: secondary,
                ),
                Divider(height: 1, color: border),
                _ToggleTile(
                  icon: CupertinoIcons.bell,
                  title: 'Login alerts',
                  subtitle: 'Get notified on new logins',
                  value: settings.loginAlerts,
                  onChanged: (value) =>
                      _update(settings.copyWith(loginAlerts: value)),
                  primary: primary,
                  secondary: secondary,
                ),
                Divider(height: 1, color: border),
                _ToggleTile(
                  icon: CupertinoIcons.lock_circle_fill,
                  title: 'App passcode',
                  subtitle: 'Require a passcode to open',
                  value: settings.appLock,
                  onChanged: (value) =>
                      _update(settings.copyWith(appLock: value)),
                  primary: primary,
                  secondary: secondary,
                ),
                Divider(height: 1, color: border),
                _ToggleTile(
                  icon: CupertinoIcons.lock_shield,
                  title: 'Biometric unlock',
                  subtitle: 'Use face or fingerprint',
                  value: settings.biometrics,
                  onChanged: (value) =>
                      _update(settings.copyWith(biometrics: value)),
                  primary: primary,
                  secondary: secondary,
                ),
                Divider(height: 1, color: border),
                _ActionTile(
                  icon: CupertinoIcons.device_phone_portrait,
                  title: 'Devices',
                  subtitle: 'Manage signed in devices',
                  onTap: () => PravaNavigator.push(
                    context,
                    const DevicesPage(),
                  ),
                  primary: primary,
                  secondary: secondary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleTile extends StatelessWidget {
  const _ToggleTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    required this.primary,
    required this.secondary,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color primary;
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
                    color: primary,
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

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.primary,
    required this.secondary,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color primary;
  final Color secondary;

  @override
  Widget build(BuildContext context) {
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
                color: PravaColors.accentPrimary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
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
                      color: primary,
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
