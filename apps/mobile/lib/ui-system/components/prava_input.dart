import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../colors.dart';
import '../typography.dart';

enum PravaInputVariant {
  standard,
  auth,
  search,
  composer,
  chat,
  comment,
  profile,
  settings,
  compact,
  borderless,
  filled,
  elevated,
  transparent,
}

enum PravaInputSize { small, medium, large }

enum PravaInputFieldType {
  text,
  name,
  username,
  email,
  phone,
  password,
  search,
  address,
  bio,
  post,
  comment,
  chat,
  url,
  number,
  otp,
}

typedef PravaInputValidator = String? Function(String value);

class PravaInputValidators {
  PravaInputValidators._();

  static PravaInputValidator requiredField([String message = 'Required']) {
    return (value) => value.trim().isEmpty ? message : null;
  }

  static PravaInputValidator email([String message = 'Enter a valid email']) {
    return (value) {
      final text = value.trim();
      if (text.isEmpty) return null;
      final valid = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(text);
      return valid ? null : message;
    };
  }

  static PravaInputValidator phone([String message = 'Enter a valid phone']) {
    return (value) {
      final digits = value.replaceAll(RegExp(r'\D'), '');
      if (digits.isEmpty) return null;
      return digits.length >= 7 && digits.length <= 15 ? null : message;
    };
  }

  static PravaInputValidator username([
    String message = 'Use 3-30 letters, numbers, dots or underscores',
  ]) {
    return (value) {
      final text = value.trim();
      if (text.isEmpty) return null;
      return RegExp(r'^[a-zA-Z0-9._]{3,30}$').hasMatch(text) ? null : message;
    };
  }

  static PravaInputValidator url([String message = 'Enter a valid URL']) {
    return (value) {
      final text = value.trim();
      if (text.isEmpty) return null;
      final uri = Uri.tryParse(text);
      return uri != null && uri.hasScheme && uri.host.isNotEmpty
          ? null
          : message;
    };
  }

  static PravaInputValidator minLength(int min, [String? message]) {
    return (value) {
      if (value.isEmpty) return null;
      return value.length >= min ? null : message ?? 'Minimum $min characters';
    };
  }

  static PravaInputValidator maxLength(int max, [String? message]) {
    return (value) {
      return value.length <= max ? null : message ?? 'Maximum $max characters';
    };
  }

  static FormFieldValidator<String> compose(
    List<PravaInputValidator> validators,
  ) {
    return (value) {
      final text = value ?? '';
      for (final validator in validators) {
        final error = validator(text);
        if (error != null) return error;
      }
      return null;
    };
  }
}

class PravaInput extends StatefulWidget {
  const PravaInput({
    super.key,
    this.controller,
    this.initialValue,
    required this.hint,
    this.label,
    this.helperText,
    this.errorText,
    this.successText,
    this.fieldType = PravaInputFieldType.text,
    this.variant = PravaInputVariant.standard,
    this.size = PravaInputSize.medium,
    this.prefixIcon,
    this.prefix,
    this.suffixIcon,
    this.obscureText = false,
    this.showClearButton = false,
    this.showPasswordToggle,
    this.showCounter = false,
    this.maxLength,
    this.minLines,
    this.maxLines,
    this.expands = false,
    this.textAlignVertical,
    this.scrollPhysics,
    this.enabled = true,
    this.readOnly = false,
    this.requiredField = false,
    this.loading = false,
    this.autofocus = false,
    this.focusNode,
    this.nextFocusNode,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization,
    this.textAlign = TextAlign.start,
    this.autofillHints,
    this.inputFormatters,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.onSaved,
    this.onTap,
    this.onEditingComplete,
    this.sendIcon,
    this.onSend,
    this.semanticLabel,
    this.autovalidateMode,
  }) : assert(
         controller == null || initialValue == null,
         'Use either controller or initialValue, not both.',
       );

  final TextEditingController? controller;
  final String? initialValue;
  final String hint;
  final String? label;
  final String? helperText;
  final String? errorText;
  final String? successText;
  final PravaInputFieldType fieldType;
  final PravaInputVariant variant;
  final PravaInputSize size;
  final Widget? prefixIcon;
  final Widget? prefix;
  final Widget? suffixIcon;
  final bool obscureText;
  final bool showClearButton;
  final bool? showPasswordToggle;
  final bool showCounter;
  final int? maxLength;
  final int? minLines;
  final int? maxLines;
  final bool expands;
  final TextAlignVertical? textAlignVertical;
  final ScrollPhysics? scrollPhysics;
  final bool enabled;
  final bool readOnly;
  final bool requiredField;
  final bool loading;
  final bool autofocus;
  final FocusNode? focusNode;
  final FocusNode? nextFocusNode;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization? textCapitalization;
  final TextAlign textAlign;
  final Iterable<String>? autofillHints;
  final List<TextInputFormatter>? inputFormatters;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FormFieldSetter<String>? onSaved;
  final VoidCallback? onTap;
  final VoidCallback? onEditingComplete;
  final IconData? sendIcon;
  final VoidCallback? onSend;
  final String? semanticLabel;
  final AutovalidateMode? autovalidateMode;

  @override
  State<PravaInput> createState() => _PravaInputState();
}

class _PravaInputState extends State<PravaInput> {
  late final TextEditingController _internalController;
  late final FocusNode _internalFocusNode;
  bool _obscure = false;
  bool _hovered = false;

  TextEditingController get _controller =>
      widget.controller ?? _internalController;

  FocusNode get _focusNode => widget.focusNode ?? _internalFocusNode;

  bool get _ownsController => widget.controller == null;

  bool get _ownsFocusNode => widget.focusNode == null;

  bool get _isPassword => widget.fieldType == PravaInputFieldType.password;

  bool get _showPasswordToggle =>
      widget.showPasswordToggle ??
      widget.fieldType == PravaInputFieldType.password || widget.obscureText;

  bool get _isMultiline {
    return switch (widget.fieldType) {
      PravaInputFieldType.bio ||
      PravaInputFieldType.post ||
      PravaInputFieldType.comment ||
      PravaInputFieldType.chat ||
      PravaInputFieldType.address => true,
      _ => false,
    };
  }

  @override
  void initState() {
    super.initState();
    _internalController = TextEditingController(text: widget.initialValue);
    _internalFocusNode = FocusNode();
    _obscure = _isPassword || widget.obscureText;
    _controller.addListener(_handleTextChanged);
    _focusNode.addListener(_handleFocusChanged);
  }

  @override
  void didUpdateWidget(covariant PravaInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldController = oldWidget.controller ?? _internalController;
    final newController = widget.controller ?? _internalController;
    if (oldController != newController) {
      oldController.removeListener(_handleTextChanged);
      newController.addListener(_handleTextChanged);
    }
    final oldFocusNode = oldWidget.focusNode ?? _internalFocusNode;
    final newFocusNode = widget.focusNode ?? _internalFocusNode;
    if (oldFocusNode != newFocusNode) {
      oldFocusNode.removeListener(_handleFocusChanged);
      newFocusNode.addListener(_handleFocusChanged);
    }
    if ((oldWidget.fieldType != widget.fieldType ||
            oldWidget.obscureText != widget.obscureText) &&
        (_isPassword || widget.obscureText)) {
      _obscure = true;
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleTextChanged);
    _focusNode.removeListener(_handleFocusChanged);
    if (_ownsController) _internalController.dispose();
    if (_ownsFocusNode) _internalFocusNode.dispose();
    super.dispose();
  }

  void _handleTextChanged() {
    if (mounted) setState(() {});
  }

  void _handleFocusChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.pravaColors;
    final metrics = _PravaInputMetrics.forSize(widget.size, widget.variant);
    final colors = _PravaInputColors.resolve(
      tokens: tokens,
      variant: widget.variant,
      focused: _focusNode.hasFocus,
      hovered: _hovered,
      enabled: widget.enabled,
      readOnly: widget.readOnly,
      hasError: widget.errorText != null,
      hasSuccess: widget.successText != null,
    );
    final inputStyle = _textStyle(tokens);
    final label = widget.label;
    final supportingText = _supportingText;
    final counter = _counterText;
    final field = MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: colors.fill,
          borderRadius: BorderRadius.circular(metrics.radius),
          border: Border.all(color: colors.border, width: colors.borderWidth),
          boxShadow: colors.shadow,
        ),
        child: Semantics(
          label: widget.semanticLabel ?? label ?? widget.hint,
          textField: true,
          enabled: widget.enabled,
          readOnly: widget.readOnly,
          child: TextFormField(
            controller: _controller,
            focusNode: _focusNode,
            enabled: widget.enabled,
            readOnly: widget.readOnly,
            autofocus: widget.autofocus,
            obscureText: _showPasswordToggle ? _obscure : false,
            keyboardType: widget.keyboardType ?? _keyboardType,
            textInputAction: widget.textInputAction ?? _textInputAction,
            textCapitalization:
                widget.textCapitalization ?? _textCapitalization,
            textAlign: widget.textAlign,
            autofillHints: widget.autofillHints ?? _autofillHints,
            inputFormatters: _inputFormatters,
            minLines: widget.expands ? null : _minLines,
            maxLines: widget.expands ? null : _maxLines,
            expands: widget.expands,
            textAlignVertical: widget.textAlignVertical,
            scrollPhysics: widget.scrollPhysics,
            maxLength: widget.maxLength,
            autocorrect: _autocorrect,
            enableSuggestions: _enableSuggestions,
            cursorColor: tokens.brandPrimary,
            style: inputStyle,
            validator: _validator,
            onChanged: widget.onChanged,
            onSaved: widget.onSaved,
            onTap: widget.onTap,
            onFieldSubmitted: _handleSubmitted,
            onEditingComplete: widget.onEditingComplete,
            autovalidateMode: widget.autovalidateMode,
            buildCounter: widget.showCounter ? null : _hiddenCounterBuilder,
            decoration: InputDecoration(
              isDense: true,
              filled: false,
              hintText: widget.hint,
              hintStyle: _placeholderStyle(tokens),
              prefixIcon: _prefixIcon(tokens, metrics),
              prefix: widget.prefix,
              suffixIcon: _suffix(tokens, metrics),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              contentPadding: metrics.padding,
              errorStyle: PravaTypography.errorText.copyWith(
                color: tokens.statusError,
              ),
              counterStyle: PravaTypography.caption.copyWith(
                color: tokens.textTertiary,
              ),
            ),
          ),
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          _PravaInputLabel(
            label: label,
            requiredField: widget.requiredField,
            color: colors.label,
          ),
          const SizedBox(height: 8),
        ],
        field,
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 160),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeOutCubic,
          child: supportingText == null && counter == null
              ? const SizedBox.shrink()
              : Padding(
                  key: ValueKey('$supportingText-$counter'),
                  padding: const EdgeInsets.only(top: 7),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (supportingText != null)
                        Expanded(
                          child: Text(
                            supportingText.text,
                            style: supportingText.style,
                          ),
                        ),
                      if (counter != null) ...[
                        if (supportingText != null) const SizedBox(width: 12),
                        Text(
                          counter,
                          style: PravaTypography.caption.copyWith(
                            color: tokens.textTertiary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget? _prefixIcon(PravaThemeColors tokens, _PravaInputMetrics metrics) {
    final icon =
        widget.prefixIcon ??
        (widget.fieldType == PravaInputFieldType.search
            ? const Icon(Icons.search_rounded)
            : null);
    if (icon == null) return null;
    return IconTheme(
      data: IconThemeData(color: tokens.iconSecondary, size: metrics.iconSize),
      child: icon,
    );
  }

  Widget? _suffix(PravaThemeColors tokens, _PravaInputMetrics metrics) {
    final actions = <Widget>[];
    if (widget.loading) {
      actions.add(
        SizedBox(
          width: metrics.iconSize,
          height: metrics.iconSize,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: tokens.brandPrimary,
          ),
        ),
      );
    } else if (widget.successText != null) {
      actions.add(
        Icon(
          Icons.check_circle_rounded,
          color: tokens.statusSuccess,
          size: metrics.iconSize,
        ),
      );
    }
    if (widget.showClearButton && _controller.text.isNotEmpty) {
      actions.add(
        _PravaInputIconButton(
          tooltip: 'Clear',
          icon: Icons.close_rounded,
          color: tokens.iconSecondary,
          size: metrics.iconSize,
          onTap: widget.enabled && !widget.readOnly
              ? () {
                  _controller.clear();
                  widget.onChanged?.call('');
                }
              : null,
        ),
      );
    }
    if (_showPasswordToggle) {
      actions.add(
        _PravaInputIconButton(
          tooltip: _obscure ? 'Show password' : 'Hide password',
          icon: _obscure
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined,
          color: tokens.iconSecondary,
          size: metrics.iconSize,
          onTap: widget.enabled
              ? () {
                  HapticFeedback.selectionClick();
                  setState(() => _obscure = !_obscure);
                }
              : null,
        ),
      );
    }
    if (widget.suffixIcon != null) {
      actions.add(widget.suffixIcon!);
    }
    if (widget.onSend != null) {
      actions.add(
        _PravaInputIconButton(
          tooltip: 'Send',
          icon: widget.sendIcon ?? Icons.arrow_upward_rounded,
          color: tokens.brandContent,
          size: metrics.iconSize + 2,
          onTap: widget.enabled ? widget.onSend : null,
        ),
      );
    }
    if (actions.isEmpty) return null;
    return Padding(
      padding: EdgeInsets.only(right: metrics.trailingPadding),
      child: Row(mainAxisSize: MainAxisSize.min, children: actions),
    );
  }

  Widget? _hiddenCounterBuilder(
    BuildContext context, {
    required int currentLength,
    required bool isFocused,
    required int? maxLength,
  }) {
    return null;
  }

  void _handleSubmitted(String value) {
    widget.onSubmitted?.call(value);
    final next = widget.nextFocusNode;
    if (next != null) {
      next.requestFocus();
      return;
    }
    if (widget.textInputAction == TextInputAction.next) {
      FocusScope.of(context).nextFocus();
    }
  }

  String? Function(String?)? get _validator {
    final validators = <PravaInputValidator>[];
    if (widget.requiredField) {
      validators.add(PravaInputValidators.requiredField());
    }
    switch (widget.fieldType) {
      case PravaInputFieldType.email:
        validators.add(PravaInputValidators.email());
      case PravaInputFieldType.phone:
        validators.add(PravaInputValidators.phone());
      case PravaInputFieldType.username:
        validators.add(PravaInputValidators.username());
      case PravaInputFieldType.url:
        validators.add(PravaInputValidators.url());
      default:
        break;
    }
    if (widget.validator != null) {
      validators.add((value) => widget.validator!(value));
    }
    if (validators.isEmpty) return null;
    return PravaInputValidators.compose(validators);
  }

  TextInputType get _keyboardType {
    return switch (widget.fieldType) {
      PravaInputFieldType.email => TextInputType.emailAddress,
      PravaInputFieldType.phone => TextInputType.phone,
      PravaInputFieldType.password => TextInputType.visiblePassword,
      PravaInputFieldType.search => TextInputType.text,
      PravaInputFieldType.address ||
      PravaInputFieldType.bio ||
      PravaInputFieldType.post ||
      PravaInputFieldType.comment ||
      PravaInputFieldType.chat => TextInputType.multiline,
      PravaInputFieldType.url => TextInputType.url,
      PravaInputFieldType.number ||
      PravaInputFieldType.otp => TextInputType.number,
      _ => TextInputType.text,
    };
  }

  TextInputAction get _textInputAction {
    if (_isMultiline) return TextInputAction.newline;
    return switch (widget.fieldType) {
      PravaInputFieldType.search => TextInputAction.search,
      PravaInputFieldType.chat ||
      PravaInputFieldType.comment => TextInputAction.send,
      _ =>
        widget.nextFocusNode != null
            ? TextInputAction.next
            : TextInputAction.done,
    };
  }

  TextCapitalization get _textCapitalization {
    return switch (widget.fieldType) {
      PravaInputFieldType.name => TextCapitalization.words,
      PravaInputFieldType.address ||
      PravaInputFieldType.bio ||
      PravaInputFieldType.post ||
      PravaInputFieldType.comment ||
      PravaInputFieldType.chat => TextCapitalization.sentences,
      _ => TextCapitalization.none,
    };
  }

  Iterable<String>? get _autofillHints {
    return switch (widget.fieldType) {
      PravaInputFieldType.name => const [AutofillHints.name],
      PravaInputFieldType.username => const [AutofillHints.username],
      PravaInputFieldType.email => const [AutofillHints.email],
      PravaInputFieldType.phone => const [AutofillHints.telephoneNumber],
      PravaInputFieldType.password => const [
        AutofillHints.password,
        AutofillHints.newPassword,
      ],
      PravaInputFieldType.address => const [AutofillHints.fullStreetAddress],
      PravaInputFieldType.url => const [AutofillHints.url],
      PravaInputFieldType.otp => const [AutofillHints.oneTimeCode],
      _ => null,
    };
  }

  List<TextInputFormatter>? get _inputFormatters {
    final formatters = <TextInputFormatter>[...?widget.inputFormatters];
    if (widget.fieldType == PravaInputFieldType.otp) {
      formatters.add(FilteringTextInputFormatter.digitsOnly);
      if (widget.maxLength != null) {
        formatters.add(LengthLimitingTextInputFormatter(widget.maxLength));
      }
    }
    if (widget.fieldType == PravaInputFieldType.number) {
      formatters.add(FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')));
    }
    if (widget.fieldType == PravaInputFieldType.username) {
      formatters.add(
        FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9._]')),
      );
    }
    return formatters.isEmpty ? null : formatters;
  }

  bool get _autocorrect {
    return switch (widget.fieldType) {
      PravaInputFieldType.email ||
      PravaInputFieldType.username ||
      PravaInputFieldType.password ||
      PravaInputFieldType.search ||
      PravaInputFieldType.url ||
      PravaInputFieldType.otp => false,
      _ => true,
    };
  }

  bool get _enableSuggestions {
    return switch (widget.fieldType) {
      PravaInputFieldType.email ||
      PravaInputFieldType.username ||
      PravaInputFieldType.password ||
      PravaInputFieldType.url ||
      PravaInputFieldType.otp => false,
      _ => true,
    };
  }

  int get _minLines {
    if (widget.minLines != null) return widget.minLines!;
    return switch (widget.fieldType) {
      PravaInputFieldType.bio => 3,
      PravaInputFieldType.post => 5,
      PravaInputFieldType.comment || PravaInputFieldType.chat => 1,
      PravaInputFieldType.address => 2,
      _ => 1,
    };
  }

  int get _maxLines {
    if (_showPasswordToggle) return 1;
    if (widget.maxLines != null) return widget.maxLines!;
    return switch (widget.fieldType) {
      PravaInputFieldType.bio => 6,
      PravaInputFieldType.post => 10,
      PravaInputFieldType.comment || PravaInputFieldType.chat => 5,
      PravaInputFieldType.address => 4,
      _ => 1,
    };
  }

  TextStyle _textStyle(PravaThemeColors tokens) {
    final style = switch (widget.fieldType) {
      PravaInputFieldType.search => PravaTypography.searchText,
      PravaInputFieldType.post => PravaTypography.composerText,
      PravaInputFieldType.comment => PravaTypography.commentText,
      PravaInputFieldType.chat => PravaTypography.chatMessage,
      _ =>
        widget.size == PravaInputSize.small
            ? PravaTypography.bodySmall
            : PravaTypography.inputText,
    };
    return style.copyWith(
      color: widget.enabled ? tokens.textPrimary : tokens.textDisabled,
    );
  }

  TextStyle _placeholderStyle(PravaThemeColors tokens) {
    final style = widget.fieldType == PravaInputFieldType.search
        ? PravaTypography.searchText
        : PravaTypography.inputPlaceholder;
    return style.copyWith(color: tokens.textTertiary);
  }

  _PravaSupportingText? get _supportingText {
    final tokens = context.pravaColors;
    if (widget.errorText != null) {
      return _PravaSupportingText(
        widget.errorText!,
        PravaTypography.errorText.copyWith(color: tokens.statusError),
      );
    }
    if (widget.successText != null) {
      return _PravaSupportingText(
        widget.successText!,
        PravaTypography.helperText.copyWith(color: tokens.statusSuccess),
      );
    }
    if (widget.helperText != null) {
      return _PravaSupportingText(
        widget.helperText!,
        PravaTypography.helperText.copyWith(color: tokens.textSecondary),
      );
    }
    return null;
  }

  String? get _counterText {
    if (!widget.showCounter || widget.maxLength == null) return null;
    return '${_controller.text.length}/${widget.maxLength}';
  }
}

class _PravaInputLabel extends StatelessWidget {
  const _PravaInputLabel({
    required this.label,
    required this.requiredField,
    required this.color,
  });

  final String label;
  final bool requiredField;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tokens = context.pravaColors;
    return RichText(
      text: TextSpan(
        style: PravaTypography.fieldLabel.copyWith(color: color),
        children: [
          TextSpan(text: label),
          if (requiredField)
            TextSpan(
              text: ' *',
              style: PravaTypography.fieldLabel.copyWith(
                color: tokens.statusError,
              ),
            ),
        ],
      ),
    );
  }
}

class _PravaInputIconButton extends StatelessWidget {
  const _PravaInputIconButton({
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.size,
    this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final Color color;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onTap,
        radius: 20,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, color: color, size: size),
        ),
      ),
    );
  }
}

class _PravaSupportingText {
  const _PravaSupportingText(this.text, this.style);

  final String text;
  final TextStyle style;
}

class _PravaInputMetrics {
  const _PravaInputMetrics({
    required this.radius,
    required this.padding,
    required this.iconSize,
    required this.trailingPadding,
  });

  final double radius;
  final EdgeInsets padding;
  final double iconSize;
  final double trailingPadding;

  static _PravaInputMetrics forSize(
    PravaInputSize size,
    PravaInputVariant variant,
  ) {
    final compact =
        variant == PravaInputVariant.compact ||
        variant == PravaInputVariant.search ||
        variant == PravaInputVariant.chat ||
        variant == PravaInputVariant.comment;
    return switch (size) {
      PravaInputSize.small => _PravaInputMetrics(
        radius: compact ? 16 : 14,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        iconSize: 18,
        trailingPadding: 6,
      ),
      PravaInputSize.large => _PravaInputMetrics(
        radius: variant == PravaInputVariant.composer ? 24 : 18,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        iconSize: 22,
        trailingPadding: 8,
      ),
      PravaInputSize.medium => _PravaInputMetrics(
        radius: compact ? 18 : 16,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 14 : 16,
          vertical: compact ? 12 : 15,
        ),
        iconSize: 20,
        trailingPadding: 7,
      ),
    };
  }
}

class _PravaInputColors {
  const _PravaInputColors({
    required this.fill,
    required this.border,
    required this.borderWidth,
    required this.label,
    required this.shadow,
  });

  final Color fill;
  final Color border;
  final double borderWidth;
  final Color label;
  final List<BoxShadow> shadow;

  static _PravaInputColors resolve({
    required PravaThemeColors tokens,
    required PravaInputVariant variant,
    required bool focused,
    required bool hovered,
    required bool enabled,
    required bool readOnly,
    required bool hasError,
    required bool hasSuccess,
  }) {
    final disabled = !enabled;
    final transparent =
        variant == PravaInputVariant.transparent ||
        variant == PravaInputVariant.borderless;
    Color fill;
    switch (variant) {
      case PravaInputVariant.auth:
      case PravaInputVariant.elevated:
        fill = tokens.backgroundSurface;
      case PravaInputVariant.search:
      case PravaInputVariant.chat:
      case PravaInputVariant.comment:
      case PravaInputVariant.compact:
        fill = tokens.backgroundSurfaceSubtle;
      case PravaInputVariant.composer:
      case PravaInputVariant.profile:
      case PravaInputVariant.settings:
      case PravaInputVariant.filled:
      case PravaInputVariant.standard:
        fill = tokens.backgroundSurfaceSubtle;
      case PravaInputVariant.borderless:
      case PravaInputVariant.transparent:
        fill = Colors.transparent;
    }
    if (focused && !transparent) fill = tokens.backgroundSurfaceRaised;
    if (hovered && !focused && !transparent) fill = tokens.backgroundHover;
    if (disabled || readOnly) fill = tokens.backgroundPressed;

    Color border = transparent ? Colors.transparent : tokens.borderDefault;
    if (hasSuccess) border = tokens.statusSuccess;
    if (hasError) border = tokens.statusError;
    if (focused && !hasError) border = tokens.focusBorder;
    if (disabled || readOnly) border = tokens.borderSubtle;

    return _PravaInputColors(
      fill: fill,
      border: border,
      borderWidth: focused ? 1.4 : 1,
      label: disabled ? tokens.textDisabled : tokens.textSecondary,
      shadow: variant == PravaInputVariant.elevated && enabled
          ? [
              BoxShadow(
                color: tokens.shadowSoft,
                blurRadius: focused ? 22 : 14,
                offset: const Offset(0, 8),
              ),
            ]
          : const [],
    );
  }
}

class PravaSearchInput extends StatelessWidget {
  const PravaSearchInput({
    super.key,
    required this.controller,
    this.hint = 'Search',
    this.focusNode,
    this.onChanged,
    this.onSubmitted,
    this.loading = false,
  });

  final TextEditingController controller;
  final String hint;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return PravaInput(
      controller: controller,
      hint: hint,
      fieldType: PravaInputFieldType.search,
      variant: PravaInputVariant.search,
      size: PravaInputSize.small,
      focusNode: focusNode,
      showClearButton: true,
      loading: loading,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
    );
  }
}

class PravaChatInput extends StatelessWidget {
  const PravaChatInput({
    super.key,
    required this.controller,
    this.hint = 'Message',
    this.focusNode,
    this.onChanged,
    this.onSubmitted,
    this.onSend,
    this.loading = false,
  });

  final TextEditingController controller;
  final String hint;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onSend;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return PravaInput(
      controller: controller,
      hint: hint,
      fieldType: PravaInputFieldType.chat,
      variant: PravaInputVariant.chat,
      size: PravaInputSize.medium,
      focusNode: focusNode,
      showClearButton: false,
      loading: loading,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      onSend: onSend,
    );
  }
}

class PravaComposerInput extends StatelessWidget {
  const PravaComposerInput({
    super.key,
    required this.controller,
    this.hint = 'Share something premium...',
    this.focusNode,
    this.maxLength,
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String hint;
  final FocusNode? focusNode;
  final int? maxLength;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return PravaInput(
      controller: controller,
      hint: hint,
      fieldType: PravaInputFieldType.post,
      variant: PravaInputVariant.composer,
      size: PravaInputSize.large,
      focusNode: focusNode,
      maxLength: maxLength,
      showCounter: maxLength != null,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
    );
  }
}

class PravaProfileInput extends StatelessWidget {
  const PravaProfileInput({
    super.key,
    required this.controller,
    required this.hint,
    this.label,
    this.fieldType = PravaInputFieldType.text,
    this.helperText,
    this.errorText,
    this.successText,
    this.maxLength,
    this.maxLines,
    this.requiredField = false,
    this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final String? label;
  final PravaInputFieldType fieldType;
  final String? helperText;
  final String? errorText;
  final String? successText;
  final int? maxLength;
  final int? maxLines;
  final bool requiredField;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return PravaInput(
      controller: controller,
      hint: hint,
      label: label,
      helperText: helperText,
      errorText: errorText,
      successText: successText,
      fieldType: fieldType,
      variant: PravaInputVariant.profile,
      maxLength: maxLength,
      maxLines: maxLines,
      showCounter: maxLength != null,
      requiredField: requiredField,
      onChanged: onChanged,
    );
  }
}

class PravaOtpInput extends StatelessWidget {
  const PravaOtpInput({
    super.key,
    required this.controller,
    this.hint = 'Code',
    this.length = 6,
    this.focusNode,
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String hint;
  final int length;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return PravaInput(
      controller: controller,
      hint: hint,
      fieldType: PravaInputFieldType.otp,
      variant: PravaInputVariant.auth,
      size: PravaInputSize.large,
      focusNode: focusNode,
      maxLength: length,
      showCounter: true,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(length),
      ],
      onChanged: onChanged,
      onSubmitted: onSubmitted,
    );
  }
}
