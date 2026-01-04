import 'dart:ui';

import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/network/api_exception.dart';
import '../../services/auth_service.dart';
import '../../navigation/prava_navigator.dart';
import '../../ui-system/background.dart';
import '../../ui-system/colors.dart';
import '../../ui-system/components/prava_button.dart';
import '../../ui-system/feedback/prava_toast.dart';
import '../../ui-system/feedback/toast_type.dart';
import '../../ui-system/typography.dart';
import '../home/home_shell.dart';

class SetDetailsScreen extends StatefulWidget {
  const SetDetailsScreen({super.key});

  @override
  State<SetDetailsScreen> createState() => _SetDetailsScreenState();
}

class _SetDetailsScreenState extends State<SetDetailsScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();

  final _firstNameFocus = FocusNode();
  final _lastNameFocus = FocusNode();
  final _phoneFocus = FocusNode();

  bool _loading = false;

  Country? _selectedCountry;

  final AuthService _auth = AuthService();

  @override
  void initState() {
    super.initState();

    _firstNameController.addListener(_onChanged);
    _lastNameController.addListener(_onChanged);
    _phoneController.addListener(_onChanged);
  }

  @override
  void dispose() {
    _firstNameController.removeListener(_onChanged);
    _lastNameController.removeListener(_onChanged);
    _phoneController.removeListener(_onChanged);

    _firstNameController.clear();
    _lastNameController.clear();
    _phoneController.clear();

    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();

    _firstNameFocus.dispose();
    _lastNameFocus.dispose();
    _phoneFocus.dispose();

    super.dispose();
  }

  void _onChanged() {
    if (!mounted) return;
    setState(() {});
  }

  String get _firstName => _firstNameController.text.trim();
  String get _lastName => _lastNameController.text.trim();

  String get _countryCodeDigits =>
      _selectedCountry?.phoneCode ?? '';
  String get _phoneDigits =>
      _phoneController.text.replaceAll(RegExp(r'\D'), '');

  bool _isNameValid(String value) {
    if (value.isEmpty || value.length > 64) return false;
    return RegExp(r"^[A-Za-z][A-Za-z '\-]*$").hasMatch(value);
  }

  bool get _firstNameValid => _isNameValid(_firstName);
  bool get _lastNameValid => _isNameValid(_lastName);

  bool get _countryValid => _selectedCountry != null;

  bool get _phoneValid {
    if (!_countryValid) {
      return false;
    }
    if (!RegExp(r'^\d{4,14}$').hasMatch(_phoneDigits)) {
      return false;
    }
    return _countryCodeDigits.length + _phoneDigits.length <= 15;
  }

  bool get _canContinue =>
      !_loading &&
      _firstNameValid &&
      _lastNameValid &&
      _countryValid &&
      _phoneValid;

  String get _phonePreview {
    if (!_countryValid || !_phoneValid) return '';
    return '+$_countryCodeDigits $_phoneDigits';
  }

  Future<void> _submitDetails() async {
    if (!_canContinue) return;

    FocusScope.of(context).unfocus();
    HapticFeedback.mediumImpact();

    setState(() => _loading = true);

    try {
      await _auth.updateUserDetails(
        firstName: _firstName,
        lastName: _lastName,
        phoneCountryCode: '+${_selectedCountry!.phoneCode}',
        phoneNumber: _phoneDigits,
      );

      if (!mounted) return;
      setState(() => _loading = false);

      PravaToast.show(
        context,
        message: 'Profile details saved',
        type: PravaToastType.success,
      );

      PravaNavigator.pushAndRemoveUntil(
        context,
        const HomeShell(),
        (_) => false,
      );
    } catch (err) {
      if (!mounted) return;
      setState(() => _loading = false);

      final message = err is ApiException
          ? err.message
          : 'Unable to save details';

      PravaToast.show(
        context,
        message: message,
        type: PravaToastType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText =
        isDark ? PravaColors.darkTextPrimary : PravaColors.lightTextPrimary;
    final secondaryText =
        isDark ? PravaColors.darkTextSecondary : PravaColors.lightTextSecondary;
    final tertiaryText =
        isDark ? PravaColors.darkTextTertiary : PravaColors.lightTextTertiary;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Stack(
          children: [
            _buildBackground(isDark),
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Complete your profile',
                          style: PravaTypography.h1.copyWith(
                            letterSpacing: -0.6,
                            color: primaryText,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Add trusted details to protect your account.',
                          style: PravaTypography.body.copyWith(
                            color: secondaryText,
                          ),
                        ),
                        const SizedBox(height: 24),
                        _buildDetailsCard(
                          isDark: isDark,
                          primaryText: primaryText,
                          secondaryText: secondaryText,
                          tertiaryText: tertiaryText,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Your phone stays private and is used for account recovery.',
                          style: PravaTypography.caption.copyWith(
                            color: tertiaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsCard({
    required bool isDark,
    required Color primaryText,
    required Color secondaryText,
    required Color tertiaryText,
  }) {
    final cardColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.white.withValues(alpha: 0.9);
    final cardBorder = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.08);
    final shadowColor =
        isDark ? Colors.black.withValues(alpha: 0.4) : Colors.black.withValues(alpha: 0.08);

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: cardBorder),
            boxShadow: [
              BoxShadow(
                color: shadowColor,
                blurRadius: 24,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.person_outline,
                    size: 18,
                    color: PravaColors.accentPrimary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Identity details',
                    style: PravaTypography.body.copyWith(
                      color: primaryText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _LuxeInput(
                      controller: _firstNameController,
                      focusNode: _firstNameFocus,
                      hint: 'First name',
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      keyboardType: TextInputType.name,
                      autofillHints: const [AutofillHints.givenName],
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r"[A-Za-z '\\-]"),
                        ),
                        LengthLimitingTextInputFormatter(64),
                      ],
                      suffixIcon: _statusIcon(
                        _firstName,
                        _firstNameValid,
                      ),
                      onSubmitted: (_) =>
                          _lastNameFocus.requestFocus(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _LuxeInput(
                      controller: _lastNameController,
                      focusNode: _lastNameFocus,
                      hint: 'Last name',
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      keyboardType: TextInputType.name,
                      autofillHints: const [AutofillHints.familyName],
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r"[A-Za-z '\\-]"),
                        ),
                        LengthLimitingTextInputFormatter(64),
                      ],
                      suffixIcon: _statusIcon(
                        _lastName,
                        _lastNameValid,
                      ),
                      onSubmitted: (_) =>
                          _phoneFocus.requestFocus(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  SizedBox(
                    width: 170,
                    child: _buildCountryPickerField(
                      isDark: isDark,
                      primaryText: primaryText,
                      tertiaryText: tertiaryText,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _LuxeInput(
                      controller: _phoneController,
                      focusNode: _phoneFocus,
                      hint: 'Phone number',
                      textInputAction: TextInputAction.done,
                      keyboardType: TextInputType.phone,
                      autofillHints: const [
                        AutofillHints.telephoneNumber
                      ],
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(14),
                      ],
                      suffixIcon: _statusIcon(
                        _phoneDigits,
                        _phoneValid,
                      ),
                      onSubmitted: (_) => _submitDetails(),
                    ),
                  ),
                ],
              ),
              if (_phonePreview.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Saved as $_phonePreview',
                  style: PravaTypography.caption.copyWith(
                    color: tertiaryText,
                  ),
                ),
              ] else if (_phoneDigits.isNotEmpty ||
                  _countryValid) ...[
                const SizedBox(height: 12),
                Text(
                  'Enter your full number with country code.',
                  style: PravaTypography.caption.copyWith(
                    color: tertiaryText,
                  ),
                ),
              ],
              const SizedBox(height: 22),
              PravaButton(
                label: 'Continue',
                loading: _loading,
                onPressed: _canContinue ? _submitDetails : null,
              ),
              const SizedBox(height: 12),
              Text(
                'Protected with encrypted storage and device-bound sessions.',
                style: PravaTypography.caption.copyWith(
                  color: secondaryText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openCountryPicker(bool isDark) {
    FocusScope.of(context).unfocus();

    showCountryPicker(
      context: context,
      showPhoneCode: true,
      onSelect: (Country country) {
        setState(() => _selectedCountry = country);
      },
      countryListTheme: CountryListThemeData(
        backgroundColor: isDark
            ? PravaColors.darkBgElevated
            : PravaColors.lightBgElevated,
        textStyle: PravaTypography.body.copyWith(
          color: isDark
              ? PravaColors.darkTextPrimary
              : PravaColors.lightTextPrimary,
        ),
        searchTextStyle: PravaTypography.body.copyWith(
          color: isDark
              ? PravaColors.darkTextPrimary
              : PravaColors.lightTextPrimary,
        ),
        inputDecoration: InputDecoration(
          hintText: 'Search country',
          hintStyle: PravaTypography.body.copyWith(
            color: isDark
                ? PravaColors.darkTextTertiary
                : PravaColors.lightTextTertiary,
          ),
          filled: true,
          fillColor: isDark
              ? PravaColors.darkSurface
              : PravaColors.lightSurface,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildCountryPickerField({
    required bool isDark,
    required Color primaryText,
    required Color tertiaryText,
  }) {
    final selected = _selectedCountry;
    final fill = isDark ? PravaColors.darkSurface : PravaColors.lightSurface;
    final border = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.08);
    final label = selected?.name ?? 'Select country';
    final phoneCode = selected?.phoneCode ?? '';

    return GestureDetector(
      onTap: () => _openCountryPicker(isDark),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            Icon(
              Icons.public,
              size: 16,
              color: selected != null ? primaryText : tertiaryText,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: PravaTypography.body.copyWith(
                  color:
                      selected != null ? primaryText : tertiaryText,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (phoneCode.isNotEmpty) ...[
              const SizedBox(width: 6),
              Text(
                '+$phoneCode',
                style: PravaTypography.body.copyWith(
                  color: primaryText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(width: 4),
            Icon(
              Icons.expand_more,
              size: 18,
              color: tertiaryText,
            ),
          ],
        ),
      ),
    );
  }

  Widget? _statusIcon(String value, bool valid) {
    if (value.isEmpty) return null;
    return Icon(
      valid ? Icons.check_circle_outline : Icons.error_outline,
      size: 18,
      color: valid ? PravaColors.success : PravaColors.error,
    );
  }

  Widget _buildBackground(bool isDark) {
    return PravaBackground(isDark: isDark);
  }
}

class _LuxeInput extends StatelessWidget {
  const _LuxeInput({
    required this.controller,
    required this.hint,
    this.focusNode,
    this.textCapitalization = TextCapitalization.none,
    this.textInputAction,
    this.keyboardType = TextInputType.text,
    this.autofillHints,
    this.inputFormatters,
    this.suffixIcon,
    this.prefixText,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String hint;
  final FocusNode? focusNode;
  final TextCapitalization textCapitalization;
  final TextInputAction? textInputAction;
  final TextInputType keyboardType;
  final Iterable<String>? autofillHints;
  final List<TextInputFormatter>? inputFormatters;
  final Widget? suffixIcon;
  final String? prefixText;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return TextField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
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
        prefixText: prefixText,
        prefixStyle: PravaTypography.body.copyWith(
          color: isDark
              ? PravaColors.darkTextPrimary
              : PravaColors.lightTextPrimary,
          fontWeight: FontWeight.w600,
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
      onSubmitted: onSubmitted,
    );
  }
}
