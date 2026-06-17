import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../services/settings_service.dart';
import '../../../shell/settings_controller.dart';
import '../../../ui-system/colors.dart';
import '../../../ui-system/feedback/prava_toast.dart';
import '../../../ui-system/feedback/toast_type.dart';
import '../../../ui-system/typography.dart';
import 'settings_detail_shell.dart';

class SettingsActivityPage extends StatefulWidget {
  const SettingsActivityPage({super.key});

  @override
  State<SettingsActivityPage> createState() => _SettingsActivityPageState();
}

class _SettingsActivityPageState extends State<SettingsActivityPage> {
  bool _loading = true;
  List<SettingsAuditEntry> _items = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await SettingsScope.of(context).fetchAudit();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      PravaToast.show(
        context,
        message: 'Unable to load setting activity',
        type: PravaToastType.error,
      );
    }
  }

  String _formatDate(DateTime? value) {
    if (value == null) return 'Unknown time';
    final now = DateTime.now();
    final diff = now.difference(value.toLocal());
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  String _label(String value) {
    final cleaned = value
        .replaceAll('_', ' ')
        .replaceAllMapped(
          RegExp(r'([a-z])([A-Z])'),
          (match) => '${match.group(1)} ${match.group(2)}',
        )
        .trim();
    if (cleaned.isEmpty) return 'Setting';
    return '${cleaned.substring(0, 1).toUpperCase()}${cleaned.substring(1)}';
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

    return SettingsDetailShell(
      title: 'Setting activity',
      actions: [
        IconButton(
          onPressed: _load,
          icon: const Icon(CupertinoIcons.refresh),
          color: primary,
        ),
      ],
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 28),
              itemCount: _items.isEmpty ? 1 : _items.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: border),
              itemBuilder: (context, index) {
                if (_items.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: Text(
                      'No setting changes recorded yet.',
                      style: PravaTypography.bodyMedium.copyWith(
                        color: secondary,
                      ),
                    ),
                  );
                }
                final item = _items[index];
                final isSensitive =
                    item.sensitivity == 'sensitive' ||
                    item.sensitivity == 'critical';
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color:
                              (isSensitive
                                      ? PravaColors.error
                                      : PravaColors.accentPrimary)
                                  .withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isSensitive
                              ? CupertinoIcons.exclamationmark_shield_fill
                              : CupertinoIcons.check_mark_circled_solid,
                          color: isSensitive
                              ? PravaColors.error
                              : PravaColors.accentPrimary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _label(item.key),
                              style: PravaTypography.bodyMedium.copyWith(
                                color: primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${_label(item.category)} · ${_formatDate(item.changedAt)}',
                              style: PravaTypography.caption.copyWith(
                                color: secondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
