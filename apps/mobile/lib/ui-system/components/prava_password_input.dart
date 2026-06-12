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
    final tokens = context.pravaColors;
    OutlineInputBorder border(Color color, [double width = 1]) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: color, width: width),
      );
    }

    return TextField(
      controller: widget.controller,
      obscureText: _obscure,
      autofillHints: widget.autofillHints, // ✅ PASS
      enableSuggestions: false,
      autocorrect: false,
      keyboardType: TextInputType.visiblePassword,
      style: PravaTypography.body.copyWith(color: tokens.textPrimary),
      cursorColor: tokens.brandPrimary,
      decoration: InputDecoration(
        hintText: widget.hint,
        hintStyle: PravaTypography.body.copyWith(color: tokens.textTertiary),
        filled: true,
        fillColor: tokens.backgroundSurfaceSubtle,
        suffixIcon: IconButton(
          splashRadius: 18,
          icon: Icon(
            _obscure
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            size: 20,
            color: tokens.iconSecondary,
          ),
          onPressed: () {
            HapticFeedback.selectionClick();
            setState(() => _obscure = !_obscure);
          },
        ),
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
