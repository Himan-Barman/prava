import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../services/settings_service.dart';
import '../../../shell/settings_controller.dart';
import '../../../ui-system/colors.dart';
import '../../../ui-system/components/prava_button.dart';
import '../../../ui-system/feedback/prava_toast.dart';
import '../../../ui-system/feedback/toast_type.dart';
import '../../../ui-system/typography.dart';
import 'settings_detail_shell.dart';

enum SettingsCheckupKind { privacy, security }

class SettingsCheckupPage extends StatefulWidget {
  const SettingsCheckupPage({super.key, required this.kind});

  final SettingsCheckupKind kind;

  @override
  State<SettingsCheckupPage> createState() => _SettingsCheckupPageState();
}

class _SettingsCheckupPageState extends State<SettingsCheckupPage> {
  SettingsCheckupResult? _result;
  bool _loading = true;

  bool get _isPrivacy => widget.kind == SettingsCheckupKind.privacy;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runCheckup());
  }

  Future<void> _runCheckup() async {
    setState(() => _loading = true);
    try {
      final controller = SettingsScope.of(context);
      final result = _isPrivacy
          ? await controller.runPrivacyCheckup()
          : await controller.runSecurityCheckup();
      if (!mounted) return;
      setState(() {
        _result = result;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      PravaToast.show(
        context,
        message: 'Unable to run checkup',
        type: PravaToastType.error,
      );
    }
  }

  String get _title => _isPrivacy ? 'Privacy checkup' : 'Security checkup';

  String get _subtitle => _isPrivacy
      ? 'Review profile visibility, discovery, tags, and message safety.'
      : 'Review login protection, devices, alerts, and recovery coverage.';

  IconData get _icon => _isPrivacy
      ? CupertinoIcons.lock_shield
      : CupertinoIcons.shield_lefthalf_fill;

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
    final result = _result;

    return SettingsDetailShell(
      title: _title,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 28),
              children: [
                Row(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: PravaColors.accentPrimary.withValues(
                          alpha: 0.14,
                        ),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Icon(
                        _icon,
                        color: PravaColors.accentPrimary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _subtitle,
                            style: PravaTypography.bodyMedium.copyWith(
                              color: primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'Score refreshes from your backend settings.',
                            style: PravaTypography.caption.copyWith(
                              color: secondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    border: Border.all(color: border),
                    borderRadius: BorderRadius.circular(22),
                    color:
                        (isDark
                                ? PravaColors.darkBgElevated
                                : PravaColors.lightBgElevated)
                            .withValues(alpha: 0.72),
                  ),
                  child: Row(
                    children: [
                      Text(
                        '${result?.score ?? 0}',
                        style: PravaTypography.titleLarge.copyWith(
                          color: primary,
                          fontWeight: FontWeight.w900,
                          fontSize: 46,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          (result?.score ?? 0) >= 85
                              ? 'Strong protection'
                              : 'Needs attention',
                          style: PravaTypography.titleSmall.copyWith(
                            color: primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Recommendations',
                  style: PravaTypography.titleSmall.copyWith(
                    color: primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                if (result == null || result.recommendations.isEmpty)
                  Text(
                    'No recommendations right now.',
                    style: PravaTypography.bodyMedium.copyWith(
                      color: secondary,
                    ),
                  )
                else
                  ...result.recommendations.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            CupertinoIcons.check_mark_circled_solid,
                            color: PravaColors.accentPrimary,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              item,
                              style: PravaTypography.bodyMedium.copyWith(
                                color: primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                PravaButton(label: 'Run again', onPressed: _runCheckup),
              ],
            ),
    );
  }
}
