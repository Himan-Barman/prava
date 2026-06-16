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
import '../../ui-system/components/prava_input.dart';
import '../../ui-system/feedback/prava_toast.dart';
import '../../ui-system/feedback/toast_type.dart';
import '../../ui-system/typography.dart';
import '../home/home_shell.dart';
import 'auth_step_progress.dart';

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
  int _step = 0;

  Country? _selectedCountry;

  final AuthService _auth = AuthService();

  @override
  void initState() {
    super.initState();

    _selectedCountry = Country.parse('IN');
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

  String get _countryCodeDigits => _selectedCountry?.phoneCode ?? '';
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

  bool get _identityValid => _firstNameValid && _lastNameValid;
  bool get _contactValid => _countryValid && _phoneValid;
  bool get _canContinueIdentity => !_loading && _identityValid;
  bool get _canSubmitDetails => !_loading && _identityValid && _contactValid;

  String get _phonePreview {
    if (!_countryValid || !_phoneValid) return '';
    return '+$_countryCodeDigits $_phoneDigits';
  }

  void _goToContactStep() {
    if (!_canContinueIdentity) return;

    FocusScope.of(context).unfocus();
    HapticFeedback.selectionClick();
    setState(() => _step = 1);

    Future.delayed(const Duration(milliseconds: 260), () {
      if (mounted) _phoneFocus.requestFocus();
    });
  }

  void _goToIdentityStep() {
    FocusScope.of(context).unfocus();
    HapticFeedback.selectionClick();
    setState(() => _step = 0);
  }

  Future<void> _submitDetails() async {
    if (!_canSubmitDetails) return;

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

      PravaToast.show(context, message: message, type: PravaToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tokens = context.pravaColors;
    final primaryText = tokens.textPrimary;
    final secondaryText = tokens.textSecondary;
    final tertiaryText = tokens.textTertiary;
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    final title = _step == 0
        ? 'Complete your profile'
        : 'Add your phone number';
    final subtitle = _step == 0
        ? 'Tell us your name before we secure your contact details.'
        : 'India is selected by default. You can change it anytime.';

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Stack(
          children: [
            _buildBackground(isDark),
            SafeArea(
              child: AnimatedPadding(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                padding: EdgeInsets.only(bottom: keyboardInset),
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      style: PravaTypography.displayMedium
                                          .copyWith(
                                            letterSpacing: -0.6,
                                            color: primaryText,
                                          ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      subtitle,
                                      style: PravaTypography.bodyMedium
                                          .copyWith(color: secondaryText),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              AuthStepBadge(
                                currentStep: 4,
                                isDark: isDark,
                                textColor: secondaryText,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const AuthStepIndicator(currentStep: 4),
                          const SizedBox(height: 24),
                          _buildDetailsCard(
                            isDark: isDark,
                            primaryText: primaryText,
                            secondaryText: secondaryText,
                            tertiaryText: tertiaryText,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _step == 0
                                ? 'Details 1 of 2'
                                : 'Details 2 of 2. Your phone stays private and is used for account recovery.',
                            style: PravaTypography.caption.copyWith(
                              color: tertiaryText,
                              fontWeight: _step == 0 ? FontWeight.w600 : null,
                            ),
                          ),
                        ],
                      ),
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
    final tokens = context.pravaColors;
    final cardColor = tokens.backgroundSurface.withValues(alpha: 0.94);
    final cardBorder = tokens.borderSubtle;
    final shadowColor = tokens.shadowMedium;

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
                    _step == 0
                        ? Icons.person_outline
                        : Icons.phone_iphone_outlined,
                    size: 18,
                    color: tokens.brandContent,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _step == 0 ? 'Identity details' : 'Phone details',
                      style: PravaTypography.bodyMedium.copyWith(
                        color: primaryText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  _DetailsStepPills(step: _step, isDark: isDark),
                ],
              ),
              const SizedBox(height: 16),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  final offset = _step == 0 ? -0.04 : 0.04;
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: Offset(offset, 0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: _step == 0
                    ? _buildIdentityStep()
                    : _buildPhoneStep(
                        isDark: isDark,
                        primaryText: primaryText,
                        tertiaryText: tertiaryText,
                      ),
              ),
              const SizedBox(height: 12),
              Text(
                _step == 0
                    ? 'Your name helps friends recognize the right account.'
                    : 'Protected with encrypted storage and device-bound sessions.',
                style: PravaTypography.caption.copyWith(color: secondaryText),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIdentityStep() {
    return Column(
      key: const ValueKey('identity-step'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LuxeInput(
          controller: _firstNameController,
          focusNode: _firstNameFocus,
          hint: 'First name',
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          keyboardType: TextInputType.name,
          autofillHints: const [AutofillHints.givenName],
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r"[A-Za-z '\\-]")),
            LengthLimitingTextInputFormatter(64),
          ],
          suffixIcon: _statusIcon(_firstName, _firstNameValid),
          onSubmitted: (_) => _lastNameFocus.requestFocus(),
        ),
        const SizedBox(height: 14),
        _LuxeInput(
          controller: _lastNameController,
          focusNode: _lastNameFocus,
          hint: 'Last name',
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          keyboardType: TextInputType.name,
          autofillHints: const [AutofillHints.familyName],
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r"[A-Za-z '\\-]")),
            LengthLimitingTextInputFormatter(64),
          ],
          suffixIcon: _statusIcon(_lastName, _lastNameValid),
          onSubmitted: (_) => _goToContactStep(),
        ),
        const SizedBox(height: 22),
        PravaButton(
          label: 'Continue',
          onPressed: _canContinueIdentity ? _goToContactStep : null,
        ),
      ],
    );
  }

  Widget _buildPhoneStep({
    required bool isDark,
    required Color primaryText,
    required Color tertiaryText,
  }) {
    return Column(
      key: const ValueKey('phone-step'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCountryPickerField(
          isDark: isDark,
          primaryText: primaryText,
          tertiaryText: tertiaryText,
        ),
        const SizedBox(height: 14),
        _LuxeInput(
          controller: _phoneController,
          focusNode: _phoneFocus,
          hint: 'Phone number',
          textInputAction: TextInputAction.done,
          keyboardType: TextInputType.phone,
          autofillHints: const [AutofillHints.telephoneNumber],
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(14),
          ],
          suffixIcon: _statusIcon(_phoneDigits, _phoneValid),
          onSubmitted: (_) => _submitDetails(),
        ),
        const SizedBox(height: 12),
        Text(
          _phonePreview.isNotEmpty
              ? 'Saved as $_phonePreview'
              : 'Enter your full number without the country code.',
          style: PravaTypography.caption.copyWith(color: tertiaryText),
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            GestureDetector(
              onTap: _loading ? null : _goToIdentityStep,
              child: Container(
                height: 54,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Back',
                  style: PravaTypography.buttonMedium.copyWith(
                    color: primaryText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: PravaButton(
                label: 'Finish',
                loading: _loading,
                onPressed: _canSubmitDetails ? _submitDetails : null,
              ),
            ),
          ],
        ),
      ],
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
        textStyle: PravaTypography.bodyMedium.copyWith(
          color: isDark
              ? PravaColors.darkTextPrimary
              : PravaColors.lightTextPrimary,
        ),
        searchTextStyle: PravaTypography.bodyMedium.copyWith(
          color: isDark
              ? PravaColors.darkTextPrimary
              : PravaColors.lightTextPrimary,
        ),
        inputDecoration: InputDecoration(
          hintText: 'Search country',
          hintStyle: PravaTypography.bodyMedium.copyWith(
            color: isDark
                ? PravaColors.darkTextTertiary
                : PravaColors.lightTextTertiary,
          ),
          filled: true,
          fillColor: isDark
              ? PravaColors.darkSurface
              : PravaColors.lightSurface,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
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
                style: PravaTypography.bodyMedium.copyWith(
                  color: selected != null ? primaryText : tertiaryText,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (phoneCode.isNotEmpty) ...[
              const SizedBox(width: 6),
              Text(
                '+$phoneCode',
                style: PravaTypography.bodyMedium.copyWith(
                  color: primaryText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(width: 4),
            Icon(Icons.expand_more, size: 18, color: tertiaryText),
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

class _DetailsStepPills extends StatelessWidget {
  const _DetailsStepPills({required this.step, required this.isDark});

  final int step;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final inactive = isDark
        ? Colors.white.withValues(alpha: 0.16)
        : Colors.black.withValues(alpha: 0.12);

    return Row(
      children: [
        _DetailsStepPill(active: step == 0, inactive: inactive),
        const SizedBox(width: 6),
        _DetailsStepPill(active: step == 1, inactive: inactive),
      ],
    );
  }
}

class _DetailsStepPill extends StatelessWidget {
  const _DetailsStepPill({required this.active, required this.inactive});

  final bool active;
  final Color inactive;

  @override
  Widget build(BuildContext context) {
    final tokens = context.pravaColors;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      width: active ? 28 : 14,
      height: 6,
      decoration: BoxDecoration(
        color: active ? tokens.brandPrimary : inactive,
        borderRadius: BorderRadius.circular(999),
      ),
    );
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
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final fieldType = keyboardType == TextInputType.phone
        ? PravaInputFieldType.phone
        : textCapitalization == TextCapitalization.words
        ? PravaInputFieldType.name
        : PravaInputFieldType.text;

    return PravaInput(
      controller: controller,
      hint: hint,
      focusNode: focusNode,
      fieldType: fieldType,
      variant: PravaInputVariant.auth,
      size: PravaInputSize.medium,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      inputFormatters: inputFormatters,
      suffixIcon: suffixIcon,
      showClearButton: false,
      onSubmitted: onSubmitted,
    );
  }
}
