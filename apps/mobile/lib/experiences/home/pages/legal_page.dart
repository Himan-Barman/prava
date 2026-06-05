import 'package:flutter/material.dart';

import '../../../ui-system/colors.dart';
import '../../../ui-system/typography.dart';
import 'settings_detail_shell.dart';

class LegalPage extends StatelessWidget {
  const LegalPage({super.key, required this.title, required this.content});

  final String title;
  final String content;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark
        ? PravaColors.darkTextPrimary
        : PravaColors.lightTextPrimary;
    final secondary = isDark
        ? PravaColors.darkTextSecondary
        : PravaColors.lightTextSecondary;
    return SettingsDetailShell(
      title: title,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Text(
            title,
            style: PravaTypography.h3.copyWith(
              color: primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: PravaTypography.body.copyWith(color: secondary, height: 1.5),
          ),
        ],
      ),
    );
  }
}
