import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../../core/network/api_exception.dart';
import '../../../navigation/prava_navigator.dart';
import '../../../shell/settings_controller.dart';
import '../../../services/settings_service.dart';
import '../../../ui-system/colors.dart';
import '../../../ui-system/feedback/prava_toast.dart';
import '../../../ui-system/feedback/toast_type.dart';
import '../../../ui-system/typography.dart';
import 'devices_page.dart';
import 'settings_detail_shell.dart';

class SecurityCenterPage extends StatefulWidget {
  const SecurityCenterPage({super.key});

  @override
  State<SecurityCenterPage> createState() => _SecurityCenterPageState();
}

class _SecurityCenterPageState extends State<SecurityCenterPage> {
  String _errorMessage(Object error) {
    if (error is ApiException && error.message.trim().isNotEmpty) {
      return error.message;
    }
    return 'Unable to save security setting';
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String actionLabel,
    bool destructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                actionLabel,
                style: destructive
                    ? PravaTypography.buttonMedium.copyWith(
                        color: PravaColors.error,
                      )
                    : null,
              ),
            ),
          ],
        );
      },
    );
    return result == true;
  }

  Future<void> _update(SettingsState next) async {
    HapticFeedback.selectionClick();
    try {
      await SettingsScope.of(context).updateNow(next);
    } catch (error) {
      if (!mounted) return;
      PravaToast.show(
        context,
        message: _errorMessage(error),
        type: PravaToastType.error,
      );
    }
  }

  Future<void> _confirmThenUpdate({
    required SettingsState next,
    required bool enabling,
    required String feature,
    required String enableMessage,
    required String disableMessage,
  }) async {
    final confirmed = await _confirm(
      title: enabling ? 'Enable $feature?' : 'Disable $feature?',
      message: enabling ? enableMessage : disableMessage,
      actionLabel: enabling ? 'Enable' : 'Disable',
      destructive: !enabling,
    );
    if (!confirmed) return;
    await _update(next);
  }

  @override
  Widget build(BuildContext context) {
    final controller = SettingsScope.of(context);
    final settings = controller.state;
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
      title: 'Security center',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Column(
            children: [
              _ToggleTile(
                icon: CupertinoIcons.shield_lefthalf_fill,
                title: 'Two factor authentication',
                subtitle: 'Require a code on login',
                value: settings.twoFactor,
                onChanged: (value) => _confirmThenUpdate(
                  next: settings.copyWith(twoFactor: value),
                  enabling: value,
                  feature: 'two factor authentication',
                  enableMessage:
                      'A verification code will be required on future logins.',
                  disableMessage:
                      'Your account will rely on password and device checks only.',
                ),
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
                onChanged: (value) => _confirmThenUpdate(
                  next: settings.copyWith(appLock: value),
                  enabling: value,
                  feature: 'app passcode',
                  enableMessage:
                      'Prava will require a local passcode before opening protected areas.',
                  disableMessage:
                      'Prava will stop asking for a local passcode on this device.',
                ),
                primary: primary,
                secondary: secondary,
              ),
              Divider(height: 1, color: border),
              _ToggleTile(
                icon: CupertinoIcons.lock_shield,
                title: 'Biometric unlock',
                subtitle: 'Use face or fingerprint',
                value: settings.biometrics,
                onChanged: (value) => _confirmThenUpdate(
                  next: settings.copyWith(biometrics: value),
                  enabling: value,
                  feature: 'biometric unlock',
                  enableMessage:
                      'Face or fingerprint unlock can be used where the device supports it.',
                  disableMessage:
                      'Biometric unlock will be disabled for Prava on this device.',
                ),
                primary: primary,
                secondary: secondary,
              ),
              Divider(height: 1, color: border),
              _ActionTile(
                icon: CupertinoIcons.device_phone_portrait,
                title: 'Devices',
                subtitle: 'Manage signed in devices',
                onTap: () => PravaNavigator.push(context, const DevicesPage()),
                primary: primary,
                secondary: secondary,
              ),
            ],
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
            activeThumbColor: Colors.white,
            activeTrackColor: PravaColors.accentPrimary,
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
          ],
        ),
      ),
    );
  }
}
