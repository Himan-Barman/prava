import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

import '../../../shell/settings_controller.dart';
import '../../../ui-system/colors.dart';
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

  @override
  Widget build(BuildContext context) {
    final controller = SettingsScope.of(context);
    final current = controller.state.languageLabel;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface =
        isDark ? PravaColors.darkBgSurface : PravaColors.lightBgSurface;
    final border =
        isDark ? PravaColors.darkBorderSubtle : PravaColors.lightBorderSubtle;
    final primary =
        isDark ? PravaColors.darkTextPrimary : PravaColors.lightTextPrimary;
    final secondary =
        isDark ? PravaColors.darkTextSecondary : PravaColors.lightTextSecondary;

    return SettingsDetailShell(
      title: 'Language',
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
              children: _languages.map((language) {
                final selected = language == current;
                return Column(
                  children: [
                    ListTile(
                      onTap: () {
                        controller.update(
                          controller.state
                              .copyWith(languageLabel: language),
                        );
                        Navigator.of(context).pop();
                      },
                      title: Text(
                        language,
                        style: PravaTypography.body.copyWith(
                          color: primary,
                          fontWeight:
                              selected ? FontWeight.w600 : FontWeight.w500,
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
