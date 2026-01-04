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
  double _strength = 0.0;

  bool _hasLength = false;
  bool _hasUpper = false;
  bool _hasLower = false;
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
    final hasLower = RegExp(r'[a-z]').hasMatch(value);
    final hasNumber = RegExp(r'\d').hasMatch(value);
    final hasSymbol = RegExp(r'[!@#\$&*~%^()\-_+=]').hasMatch(value);

    double score = 0;
    if (hasLength) score += 0.25;
    if (hasUpper) score += 0.15;
    if (hasLower) score += 0.15;
    if (hasNumber) score += 0.2;
    if (hasSymbol) score += 0.25;

    setState(() {
      _hasLength = hasLength;
      _hasUpper = hasUpper;
      _hasLower = hasLower;
      _hasNumber = hasNumber;
      _hasSymbol = hasSymbol;
      _matches = confirm.isNotEmpty && value == confirm;
      _strength = score.clamp(0, 1);
    });
  }

  Color get _strengthColor {
    if (_strength < 0.4) return PravaColors.error;
    if (_strength < 0.7) return Colors.orange;
    return PravaColors.success;
  }

  bool get _valid =>
      _hasLength &&
      _hasUpper &&
      _hasLower &&
      _hasNumber &&
      _hasSymbol &&
      _matches;

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
        message: 'Password set successfully',
        type: PravaToastType.success,
      );

      PravaNavigator.pushReplacement(
        context,
        const SetDetailsScreen(),
      );
    } catch (err) {
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
                        const SizedBox(height: 24),
                        _buildPasswordCard(
                          isDark: isDark,
                          primaryText: primaryText,
                          secondaryText: secondaryText,
                          tertiaryText: tertiaryText,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Protected with Argon2id hashing and zero-knowledge design.',
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

  Widget _buildPasswordCard({
    required bool isDark,
    required Color primaryText,
    required Color secondaryText,
    required Color tertiaryText,
  }) {
    final confirmText = _confirmController.text;
    final showMatchState = confirmText.isNotEmpty;
    final matchLabel = showMatchState
        ? (_matches ? 'Passwords match' : 'Passwords must match')
        : 'Confirm your password';
    final matchColor = showMatchState
        ? (_matches ? secondaryText : PravaColors.error)
        : tertiaryText;
    final matchIcon = showMatchState
        ? (_matches
            ? Icons.check_circle_outline
            : Icons.error_outline)
        : Icons.info_outline;

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
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: _strength,
                  minHeight: 6,
                  backgroundColor:
                      isDark ? Colors.white12 : Colors.black12,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(_strengthColor),
                ),
              ),
              const SizedBox(height: 12),
              _RuleItem(
                label: '12+ characters',
                satisfied: _hasLength,
                activeColor: PravaColors.success,
                inactiveColor: tertiaryText,
              ),
              _RuleItem(
                label: 'Uppercase letter',
                satisfied: _hasUpper,
                activeColor: PravaColors.success,
                inactiveColor: tertiaryText,
              ),
              _RuleItem(
                label: 'Lowercase letter',
                satisfied: _hasLower,
                activeColor: PravaColors.success,
                inactiveColor: tertiaryText,
              ),
              _RuleItem(
                label: 'Number',
                satisfied: _hasNumber,
                activeColor: PravaColors.success,
                inactiveColor: tertiaryText,
              ),
              _RuleItem(
                label: 'Symbol',
                satisfied: _hasSymbol,
                activeColor: PravaColors.success,
                inactiveColor: tertiaryText,
              ),
              const SizedBox(height: 16),
              PravaPasswordInput(
                hint: 'Confirm password',
                controller: _confirmController,
                autofillHints: const [AutofillHints.newPassword],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    matchIcon,
                    size: 16,
                    color: showMatchState
                        ? (_matches
                            ? PravaColors.success
                            : PravaColors.error)
                        : tertiaryText,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    matchLabel,
                    style: PravaTypography.caption.copyWith(
                      color: matchColor,
                    ),
                  ),
                ],
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

class _RuleItem extends StatelessWidget {
  const _RuleItem({
    required this.label,
    required this.satisfied,
    required this.activeColor,
    required this.inactiveColor,
  });

  final String label;
  final bool satisfied;
  final Color activeColor;
  final Color inactiveColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(
            satisfied
                ? Icons.check_circle_outline
                : Icons.radio_button_unchecked,
            size: 16,
            color: satisfied ? activeColor : inactiveColor,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: PravaTypography.caption.copyWith(
              color: satisfied ? activeColor : inactiveColor,
            ),
          ),
        ],
      ),
    );
  }
}
