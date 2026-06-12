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
    final tokens = context.pravaColors;
    OutlineInputBorder border(Color color, [double width = 1]) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: color, width: width),
      );
    }

    return TextField(
      controller: controller,
      focusNode: focusNode,
      obscureText: obscureText,
      keyboardType: keyboardType,
      autofillHints: autofillHints, // ?. PASS TO TEXTFIELD
      inputFormatters: inputFormatters,
      style: PravaTypography.body.copyWith(color: tokens.textPrimary),
      cursorColor: tokens.brandPrimary,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: PravaTypography.body.copyWith(color: tokens.textTertiary),
        filled: true,
        fillColor: tokens.backgroundSurfaceSubtle,
        suffixIcon: suffixIcon,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
        border: border(tokens.borderDefault),
        enabledBorder: border(tokens.borderDefault),
        focusedBorder: border(tokens.focusBorder, 1.4),
        errorBorder: border(tokens.statusError),
        focusedErrorBorder: border(tokens.statusError, 1.4),
      ),
    );
  }
}
