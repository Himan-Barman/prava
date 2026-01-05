import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

import '../../../ui-system/background.dart';
import '../../../ui-system/colors.dart';
import '../../../ui-system/typography.dart';

class SettingsDetailShell extends StatelessWidget {
  const SettingsDetailShell({
    super.key,
    required this.title,
    required this.child,
    this.actions,
  });

  final String title;
  final Widget child;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: Stack(
        children: [
          PravaBackground(isDark: isDark),
          SafeArea(
            child: Column(
              children: [
                _TopBar(
                  title: title,
                  onBack: () => Navigator.of(context).pop(),
                  actions: actions,
                ),
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.onBack,
    this.actions,
  });

  final String title;
  final VoidCallback onBack;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary =
        isDark ? PravaColors.darkTextPrimary : PravaColors.lightTextPrimary;
    final surface =
        isDark ? Colors.black.withValues(alpha: 0.45) : Colors.white.withValues(alpha: 0.8);
    final border =
        isDark ? PravaColors.darkBorderSubtle : PravaColors.lightBorderSubtle;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: border),
            ),
            child: Row(
              children: [
                _IconPill(
                  icon: CupertinoIcons.back,
                  onTap: onBack,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: PravaTypography.h3.copyWith(
                      color: primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (actions != null) ...actions!,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IconPill extends StatelessWidget {
  const _IconPill({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDark ? Colors.white10 : Colors.black12,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(
          icon,
          size: 18,
          color: PravaColors.accentPrimary,
        ),
      ),
    );
  }
}
