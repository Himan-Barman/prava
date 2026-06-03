import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/network/api_exception.dart';
import '../../services/auth_service.dart';
import '../../navigation/prava_navigator.dart';
import '../../ui-system/background.dart';
import '../../ui-system/colors.dart';
import '../../ui-system/components/prava_button.dart';
import '../../ui-system/components/prava_password_input.dart';
import '../../ui-system/feedback/prava_toast.dart';
import '../../ui-system/feedback/toast_type.dart';
import '../../ui-system/typography.dart';
import 'auth_step_progress.dart';
import 'set_details_screen.dart';

class SetPasswordScreen extends StatefulWidget {
  final String email;
  final String? username;

  const SetPasswordScreen({
    super.key,
    required this.email,
    this.username,
  });

  @override
  State<SetPasswordScreen> createState() => _SetPasswordScreenState();
}

class _SetPasswordScreenState extends State<SetPasswordScreen> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _loading = false;

  bool _hasLength = false;
  bool _hasUpper = false;
  bool _hasNumber = false;
  bool _hasSymbol = false;
  bool _matches = false;

  final AuthService _auth = AuthService();

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_evaluatePassword);
    _confirmController.addListener(_evaluatePassword);
  }

  @override
  void dispose() {
    _passwordController.removeListener(_evaluatePassword);
    _confirmController.removeListener(_evaluatePassword);

    _passwordController.clear();
    _confirmController.clear();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _evaluatePassword() {
    final value = _passwordController.text;
    final confirm = _confirmController.text;

    final hasLength = value.length >= 12;
    final hasUpper = RegExp(r'[A-Z]').hasMatch(value);
    final hasNumber = RegExp(r'\d').hasMatch(value);
    final hasSymbol = RegExp(r'[^A-Za-z0-9]').hasMatch(value);

    setState(() {
      _hasLength = hasLength;
      _hasUpper = hasUpper;
      _hasNumber = hasNumber;
      _hasSymbol = hasSymbol;
      _matches = confirm.isNotEmpty && value == confirm;
    });
  }

  bool get _valid =>
      _hasLength &&
      _hasUpper &&
      _hasNumber &&
      _hasSymbol &&
      _matches;

  bool _shouldAutoLoginAfterRegisterError(ApiException error) {
    if (error.statusCode >= 500) {
      return true;
    }
    final lower = error.message.toLowerCase();
    return lower.contains('account created') ||
        lower.contains('email already exists');
  }

  Future<void> _setPassword() async {
    if (!_valid || _loading) return;

    FocusScope.of(context).unfocus();
    HapticFeedback.mediumImpact();

    setState(() => _loading = true);

    try {
      final session = await _auth.register(
        email: widget.email,
        password: _passwordController.text,
        username: widget.username,
      );

      if (!mounted) return;

      setState(() => _loading = false);

      if (!session.isVerified) {
        PravaToast.show(
          context,
          message: 'Check your email to verify the account',
          type: PravaToastType.info,
        );
      }

      PravaToast.show(
        context,
        message: 'Account created successfully',
        type: PravaToastType.success,
      );

      PravaNavigator.pushReplacement(
        context,
        const SetDetailsScreen(),
      );
    } catch (err) {
      if (err is ApiException &&
          _shouldAutoLoginAfterRegisterError(err)) {
        try {
          await _auth.login(
            email: widget.email,
            password: _passwordController.text,
          );
          if (!mounted) return;

          setState(() => _loading = false);
          PravaToast.show(
            context,
            message: 'Account created successfully',
            type: PravaToastType.success,
          );
          PravaNavigator.pushReplacement(
            context,
            const SetDetailsScreen(),
          );
          return;
        } catch (_) {
          // Fall through to default error rendering.
        }
      }

      if (!mounted) return;

      setState(() => _loading = false);

      final message = err is ApiException
          ? err.message
          : 'Failed to set password';

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
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;

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
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Secure your account',
                                      style: PravaTypography.h1.copyWith(
                                        letterSpacing: -0.6,
                                        color: primaryText,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Create a strong password to unlock your private workspace.',
                                      style: PravaTypography.body.copyWith(
                                        color: secondaryText,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              AuthStepBadge(
                                currentStep: 3,
                                isDark: isDark,
                                textColor: secondaryText,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const AuthStepIndicator(currentStep: 3),
                          const SizedBox(height: 24),
                          _buildPasswordCard(
                            isDark: isDark,
                            primaryText: primaryText,
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

  Widget _buildPasswordCard({
    required bool isDark,
    required Color primaryText,
  }) {
    final cardColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.white.withValues(alpha: 0.9);
    final cardBorder = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.08);
    final shadowColor = isDark
        ? Colors.black.withValues(alpha: 0.4)
        : Colors.black.withValues(alpha: 0.08);

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
                  const Icon(
                    Icons.lock_outline,
                    size: 18,
                    color: PravaColors.accentPrimary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Password security',
                    style: PravaTypography.body.copyWith(
                      color: primaryText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              PravaPasswordInput(
                hint: 'Password',
                controller: _passwordController,
                autofillHints: const [AutofillHints.newPassword],
              ),
              const SizedBox(height: 14),
              PravaPasswordInput(
                hint: 'Confirm password',
                controller: _confirmController,
                autofillHints: const [AutofillHints.newPassword],
              ),
              const SizedBox(height: 22),
              PravaButton(
                label: 'Set password',
                loading: _loading,
                onPressed: _valid ? _setPassword : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBackground(bool isDark) {
    return PravaBackground(isDark: isDark);
  }
}
