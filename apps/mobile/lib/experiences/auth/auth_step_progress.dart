import 'package:flutter/material.dart';

import '../../ui-system/colors.dart';
import '../../ui-system/typography.dart';

class AuthStepBadge extends StatelessWidget {
  const AuthStepBadge({
    super.key,
    required this.currentStep,
    required this.isDark,
    required this.textColor,
    this.totalSteps = 4,
  });

  final int currentStep;
  final int totalSteps;
  final bool isDark;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final border = isDark
        ? Colors.white.withValues(alpha: 0.16)
        : Colors.black.withValues(alpha: 0.08);
    final background = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.04);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Text(
        'Step $currentStep of $totalSteps',
        style: PravaTypography.caption.copyWith(
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class AuthStepIndicator extends StatelessWidget {
  const AuthStepIndicator({
    super.key,
    required this.currentStep,
    this.totalSteps = 4,
  });

  final int currentStep;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(totalSteps, (index) {
        return Padding(
          padding: EdgeInsets.only(
            right: index == totalSteps - 1 ? 0 : 6,
          ),
          child: _AuthStepPill(active: index < currentStep),
        );
      }),
    );
  }
}

class _AuthStepPill extends StatelessWidget {
  const _AuthStepPill({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inactive = isDark
        ? Colors.white.withValues(alpha: 0.16)
        : Colors.black.withValues(alpha: 0.12);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      width: active ? 36 : 18,
      height: 6,
      decoration: BoxDecoration(
        color: active ? PravaColors.accentPrimary : inactive,
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}
