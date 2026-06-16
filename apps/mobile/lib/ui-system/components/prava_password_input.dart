import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'prava_input.dart';

class PravaPasswordInput extends StatelessWidget {
  const PravaPasswordInput({
    super.key,
    required this.hint,
    required this.controller,
    this.label,
    this.helperText,
    this.errorText,
    this.successText,
    this.focusNode,
    this.nextFocusNode,
    this.autofillHints,
    this.inputFormatters,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.requiredField = false,
    this.loading = false,
    this.enabled = true,
    this.readOnly = false,
  });

  final String hint;
  final TextEditingController controller;
  final String? label;
  final String? helperText;
  final String? errorText;
  final String? successText;
  final FocusNode? focusNode;
  final FocusNode? nextFocusNode;
  final Iterable<String>? autofillHints;
  final List<TextInputFormatter>? inputFormatters;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool requiredField;
  final bool loading;
  final bool enabled;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    return PravaInput(
      controller: controller,
      hint: hint,
      label: label,
      helperText: helperText,
      errorText: errorText,
      successText: successText,
      fieldType: PravaInputFieldType.password,
      variant: PravaInputVariant.auth,
      focusNode: focusNode,
      nextFocusNode: nextFocusNode,
      autofillHints: autofillHints,
      inputFormatters: inputFormatters,
      validator: validator,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      requiredField: requiredField,
      loading: loading,
      enabled: enabled,
      readOnly: readOnly,
      showPasswordToggle: true,
    );
  }
}
