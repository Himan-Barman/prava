import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../colors.dart';
import '../typography.dart';

class PravaPasswordInput extends StatefulWidget {
  const PravaPasswordInput({
    super.key,
    required this.hint,
    required this.controller,
    this.autofillHints, // ✅ ADD
  });

  final String hint;
  final TextEditingController controller;
  final Iterable<String>? autofillHints; // ✅ ADD

  @override
  State<PravaPasswordInput> createState() => _PravaPasswordInputState();
}

class _PravaPasswordInputState extends State<PravaPasswordInput> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return TextField(
      controller: widget.controller,
      obscureText: _obscure,
      autofillHints: widget.autofillHints, // ✅ PASS
      enableSuggestions: false,
      autocorrect: false,
      keyboardType: TextInputType.visiblePassword,
      style: PravaTypography.body.copyWith(
        color: isDark
            ? PravaColors.darkTextPrimary
            : PravaColors.lightTextPrimary,
      ),
      decoration: InputDecoration(
        hintText: widget.hint,
        hintStyle: PravaTypography.body.copyWith(
          color: isDark
              ? PravaColors.darkTextTertiary
              : PravaColors.lightTextTertiary,
        ),
        filled: true,
        fillColor: isDark
            ? PravaColors.darkSurface
            : PravaColors.lightSurface,
        suffixIcon: IconButton(
          splashRadius: 18,
          icon: Icon(
            _obscure
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            size: 20,
            color: isDark
                ? PravaColors.darkTextSecondary
                : PravaColors.lightTextSecondary,
          ),
          onPressed: () {
            HapticFeedback.selectionClick();
            setState(() => _obscure = !_obscure);
          },
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
