import 'package:flutter/material.dart';

import '../colors.dart';
import '../typography.dart';

enum PravaButtonVariant { primary, secondary, ghost, destructive }

class PravaButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback? onPressed;
  final PravaButtonVariant variant;

  const PravaButton({
    super.key,
    required this.label,
    this.loading = false,
    this.onPressed,
    this.variant = PravaButtonVariant.primary,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.pravaColors;
    final interactive = onPressed != null;
    final enabledTap = interactive && !loading;
    final fill = _fill(tokens, interactive);
    final foreground = _foreground(tokens, interactive);
    final border = _border(tokens, interactive);
    final shadow = variant == PravaButtonVariant.primary && interactive
        ? tokens.shadowSoft
        : Colors.transparent;

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
            color: fill,
            border: border,
            boxShadow: !interactive || loading
                ? []
                : [
                    BoxShadow(
                      color: shadow,
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
          ),
          alignment: Alignment.center,
          child: loading
              ? SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: foreground,
                  ),
                )
              : Text(
                  label,
                  style: PravaTypography.buttonLarge.copyWith(
                    color: foreground,
                  ),
                ),
        ),
      ),
    );
  }

  Color _fill(PravaThemeColors tokens, bool interactive) {
    if (!interactive) return tokens.backgroundPressed;
    switch (variant) {
      case PravaButtonVariant.primary:
        return tokens.brandPrimary;
      case PravaButtonVariant.secondary:
        return tokens.backgroundSurface;
      case PravaButtonVariant.ghost:
        return Colors.transparent;
      case PravaButtonVariant.destructive:
        return tokens.statusError;
    }
  }

  Color _foreground(PravaThemeColors tokens, bool interactive) {
    if (!interactive) return tokens.textDisabled;
    switch (variant) {
      case PravaButtonVariant.primary:
      case PravaButtonVariant.destructive:
        return tokens.textInverse;
      case PravaButtonVariant.secondary:
        return tokens.textPrimary;
      case PravaButtonVariant.ghost:
        return tokens.brandContent;
    }
  }

  Border? _border(PravaThemeColors tokens, bool interactive) {
    if (variant != PravaButtonVariant.secondary) return null;
    return Border.all(
      color: interactive ? tokens.borderDefault : tokens.borderSubtle,
    );
  }
}
