import 'package:flutter/material.dart';

import '../colors.dart';
import '../typography.dart';

class PravaButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback? onPressed;

  const PravaButton({
    super.key,
    required this.label,
    this.loading = false,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final interactive = onPressed != null;
    final enabledTap = interactive && !loading;
    final buttonColor = interactive
        ? PravaColors.accentPrimary
        : (isDark
            ? Colors.white.withValues(alpha: 0.14)
            : Colors.black.withValues(alpha: 0.12));
    final contentColor = interactive
        ? Colors.white
        : (isDark
            ? Colors.white.withValues(alpha: 0.48)
            : Colors.black.withValues(alpha: 0.42));

    return AnimatedScale(
      scale: loading ? 0.98 : 1,
      duration: const Duration(milliseconds: 120),
      child: GestureDetector(
        onTap: enabledTap ? onPressed : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 54,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: buttonColor,
            boxShadow: !interactive || loading
                ? []
                : [
                    BoxShadow(
                      color:
                          PravaColors.accentPrimary.withValues(alpha: 0.24),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
          ),
          alignment: Alignment.center,
          child: loading
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  label,
                  style: PravaTypography.button.copyWith(
                    color: contentColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ),
    );
  }
}
