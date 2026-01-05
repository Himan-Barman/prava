import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../services/account_service.dart';
import '../../../ui-system/colors.dart';
import '../../../ui-system/typography.dart';
import '../../../ui-system/components/prava_button.dart';
import '../../../ui-system/components/prava_input.dart';
import '../../../ui-system/feedback/prava_toast.dart';
import '../../../ui-system/feedback/toast_type.dart';
import 'settings_detail_shell.dart';

class AccountInformationPage extends StatefulWidget {
  const AccountInformationPage({super.key});

  @override
  State<AccountInformationPage> createState() =>
      _AccountInformationPageState();
}

class _AccountInformationPageState extends State<AccountInformationPage> {
  final AccountService _service = AccountService();
  final _emailController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneCountryController = TextEditingController();
  final _phoneController = TextEditingController();

  AccountInfo? _account;
  bool _loading = true;
  bool _savingDetails = false;
  bool _savingEmail = false;

  @override
  void initState() {
    super.initState();
    _loadAccount();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneCountryController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadAccount() async {
    try {
      final info = await _service.fetchAccountInfo();
      if (!mounted) return;
      setState(() {
        _account = info;
        _emailController.text = info.email;
        _firstNameController.text = info.firstName;
        _lastNameController.text = info.lastName;
        _phoneCountryController.text = info.phoneCountryCode;
        _phoneController.text = info.phoneNumber;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      PravaToast.show(
        context,
        message: 'Unable to load account details',
        type: PravaToastType.error,
      );
    }
  }

  bool _isNameValid(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed.length > 64) return false;
    return RegExp(r"^[A-Za-z][A-Za-z '\-]*$").hasMatch(trimmed);
  }

  bool _isCountryValid(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return false;
    return RegExp(r'^\+?\d{1,4}$').hasMatch(trimmed);
  }

  bool _isPhoneValid(String country, String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return false;
    if (!RegExp(r'^\d{4,14}$').hasMatch(digits)) return false;
    final countryDigits =
        country.replaceAll(RegExp(r'\D'), '').trim();
    return (countryDigits.length + digits.length) <= 15;
  }

  Future<void> _saveDetails() async {
    if (_savingDetails) return;
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final country = _phoneCountryController.text.trim();
    final phone = _phoneController.text.trim();

    if (!_isNameValid(firstName) || !_isNameValid(lastName)) {
      PravaToast.show(
        context,
        message: 'Enter a valid first and last name',
        type: PravaToastType.warning,
      );
      return;
    }

    if (!_isCountryValid(country) || !_isPhoneValid(country, phone)) {
      PravaToast.show(
        context,
        message: 'Enter a valid phone number',
        type: PravaToastType.warning,
      );
      return;
    }

    setState(() => _savingDetails = true);

    try {
      final normalizedCountry =
          country.startsWith('+') ? country : '+$country';
      final updated = await _service.updateDetails(
        firstName: firstName,
        lastName: lastName,
        phoneCountryCode: normalizedCountry,
        phoneNumber: phone.replaceAll(RegExp(r'\D'), ''),
      );
      if (!mounted) return;
      setState(() {
        _account = updated;
        _savingDetails = false;
      });
      PravaToast.show(
        context,
        message: 'Details updated',
        type: PravaToastType.success,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _savingDetails = false);
      PravaToast.show(
        context,
        message: 'Unable to update details',
        type: PravaToastType.error,
      );
    }
  }

  Future<void> _saveEmail() async {
    if (_savingEmail) return;
    final email = _emailController.text.trim();
    if (!email.contains('@')) {
      PravaToast.show(
        context,
        message: 'Enter a valid email address',
        type: PravaToastType.warning,
      );
      return;
    }

    setState(() => _savingEmail = true);
    try {
      final updated = await _service.updateEmail(email);
      if (!mounted) return;
      setState(() {
        _account = updated;
        _savingEmail = false;
      });
      PravaToast.show(
        context,
        message: 'Email updated. Check your inbox to verify.',
        type: PravaToastType.info,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _savingEmail = false);
      PravaToast.show(
        context,
        message: 'Unable to update email',
        type: PravaToastType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary =
        isDark ? PravaColors.darkTextPrimary : PravaColors.lightTextPrimary;
    final secondary =
        isDark ? PravaColors.darkTextSecondary : PravaColors.lightTextSecondary;
    final surface =
        isDark ? PravaColors.darkBgSurface : PravaColors.lightBgSurface;
    final border =
        isDark ? PravaColors.darkBorderSubtle : PravaColors.lightBorderSubtle;

    return SettingsDetailShell(
      title: 'Account information',
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                _SectionCard(
                  title: 'Email',
                  subtitle: _account?.isVerified == true
                      ? 'Verified'
                      : 'Verify your email to secure the account',
                  primary: primary,
                  secondary: secondary,
                  border: border,
                  surface: surface,
                  child: Column(
                    children: [
                      PravaInput(
                        controller: _emailController,
                        hint: 'Email address',
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 12),
                      PravaButton(
                        label: 'Update email',
                        loading: _savingEmail,
                        onPressed: _savingEmail ? null : _saveEmail,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'Personal details',
                  subtitle: 'Keep your contact info current.',
                  primary: primary,
                  secondary: secondary,
                  border: border,
                  surface: surface,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: PravaInput(
                              controller: _firstNameController,
                              hint: 'First name',
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r"[A-Za-z '\\-]"),
                                ),
                                LengthLimitingTextInputFormatter(64),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: PravaInput(
                              controller: _lastNameController,
                              hint: 'Last name',
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r"[A-Za-z '\\-]"),
                                ),
                                LengthLimitingTextInputFormatter(64),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          SizedBox(
                            width: 120,
                            child: PravaInput(
                              controller: _phoneCountryController,
                              hint: '+91',
                              keyboardType: TextInputType.phone,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9+]'),
                                ),
                                LengthLimitingTextInputFormatter(4),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: PravaInput(
                              controller: _phoneController,
                              hint: 'Phone number',
                              keyboardType: TextInputType.phone,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(14),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      PravaButton(
                        label: 'Save details',
                        loading: _savingDetails,
                        onPressed: _savingDetails ? null : _saveDetails,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.primary,
    required this.secondary,
    required this.border,
    required this.surface,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Color primary;
  final Color secondary;
  final Color border;
  final Color surface;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: PravaTypography.h3.copyWith(
                  color: primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: PravaTypography.bodySmall.copyWith(color: secondary),
              ),
              const SizedBox(height: 16),
              child,
            ],
          ),
        ),
      ),
    );
  }
}
