import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../colors.dart';
import '../typography.dart';

class PravaInput extends StatelessWidget {
  const PravaInput({
    super.key,
    required this.controller,
    required this.hint,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.suffixIcon,
    this.focusNode,
    this.autofillHints, // ?. ADD THIS
    this.inputFormatters,
  });

  final TextEditingController controller;
  final String hint;
  final bool obscureText;
  final TextInputType keyboardType;
  final Widget? suffixIcon;
  final FocusNode? focusNode;
  final Iterable<String>? autofillHints; // ?. ADD THIS
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return TextField(
      controller: controller,
      focusNode: focusNode,
      obscureText: obscureText,
      keyboardType: keyboardType,
      autofillHints: autofillHints, // ?. PASS TO TEXTFIELD
      inputFormatters: inputFormatters,
      style: PravaTypography.body.copyWith(
        color: isDark
            ? PravaColors.darkTextPrimary
            : PravaColors.lightTextPrimary,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: PravaTypography.body.copyWith(
          color: isDark
              ? PravaColors.darkTextTertiary
              : PravaColors.lightTextTertiary,
        ),
        filled: true,
        fillColor: isDark
            ? PravaColors.darkSurface
            : PravaColors.lightSurface,
        suffixIcon: suffixIcon,
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
