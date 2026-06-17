import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

import '../../../core/network/api_exception.dart';
import '../../../shell/settings_controller.dart';
import '../../../ui-system/colors.dart';
import '../../../ui-system/feedback/prava_toast.dart';
import '../../../ui-system/feedback/toast_type.dart';
import '../../../ui-system/typography.dart';
import 'settings_detail_shell.dart';

class LanguagePage extends StatelessWidget {
  const LanguagePage({super.key});

  static const _languages = [
    'English',
    'Hindi',
    'Bengali',
    'Spanish',
    'French',
    'German',
  ];

  String _errorMessage(Object error) {
    if (error is ApiException && error.message.trim().isNotEmpty) {
      return error.message;
    }
    return 'Unable to save language';
  }

  @override
  Widget build(BuildContext context) {
    final controller = SettingsScope.of(context);
    final current = controller.state.languageLabel;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border = isDark
        ? PravaColors.darkBorderSubtle
        : PravaColors.lightBorderSubtle;
    final primary = isDark
        ? PravaColors.darkTextPrimary
        : PravaColors.lightTextPrimary;
    final secondary = isDark
        ? PravaColors.darkTextSecondary
        : PravaColors.lightTextSecondary;

    return SettingsDetailShell(
      title: 'Language',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Column(
            children: _languages.map((language) {
              final selected = language == current;
              return Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    onTap: () async {
                      try {
                        await controller.updateNow(
                          controller.state.copyWith(languageLabel: language),
                        );
                        if (!context.mounted) return;
                        Navigator.of(context).pop();
                      } catch (error) {
                        if (!context.mounted) return;
                        PravaToast.show(
                          context,
                          message: _errorMessage(error),
                          type: PravaToastType.error,
                        );
                      }
                    },
                    title: Text(
                      language,
                      style: PravaTypography.bodyMedium.copyWith(
                        color: primary,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                    ),
                    trailing: selected
                        ? const Icon(
                            CupertinoIcons.check_mark_circled_solid,
                            color: PravaColors.accentPrimary,
                          )
                        : null,
                  ),
                  if (language != _languages.last)
                    Divider(height: 1, color: border),
                ],
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Text(
            'Language is saved to your account settings.',
            style: PravaTypography.caption.copyWith(color: secondary),
          ),
        ],
      ),
    );
  }
}
