import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/network/api_exception.dart';
import '../../services/auth_service.dart';
import '../../ui-system/colors.dart';
import '../../ui-system/components/prava_button.dart';
import '../../ui-system/components/prava_input.dart';
import '../../ui-system/components/prava_password_input.dart';
import '../../ui-system/feedback/prava_toast.dart';
import '../../ui-system/feedback/toast_type.dart';
import '../../ui-system/typography.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({
    super.key,
    this.email,
    this.initialToken,
  });

  final String? email;
  final String? initialToken;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _tokenController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _loading = false;
  double _strength = 0.0;
  final AuthService _auth = AuthService();

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_checkStrength);
    _tokenController.addListener(_syncState);
    _confirmController.addListener(_syncState);
    if (widget.initialToken != null &&
        widget.initialToken!.trim().isNotEmpty) {
      _tokenController.text = widget.initialToken!.trim();
    }
  }

  @override
  void dispose() {
    _passwordController.removeListener(_checkStrength);
    _tokenController.removeListener(_syncState);
    _confirmController.removeListener(_syncState);
    _tokenController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _checkStrength() {
    final value = _passwordController.text;

    double score = 0;
    if (value.length >= 12) score += 0.25;
    if (RegExp(r'[A-Z]').hasMatch(value)) score += 0.15;
    if (RegExp(r'[a-z]').hasMatch(value)) score += 0.15;
    if (RegExp(r'\d').hasMatch(value)) score += 0.2;
    if (RegExp(r'[!@#\$&*~%^()\-_+=]').hasMatch(value)) {
      score += 0.25;
    }

    setState(() {
      _strength = score.clamp(0, 1);
    });
  }

  void _syncState() {
    setState(() {});
  }

  Color get _strengthColor {
    if (_strength < 0.4) return PravaColors.error;
    if (_strength < 0.7) return Colors.orange;
    return PravaColors.success;
  }

  bool get _valid {
    final token = _tokenController.text.trim();
    return RegExp(r'^\d{6}$').hasMatch(token) &&
        _strength >= 0.7 &&
        _passwordController.text.isNotEmpty &&
        _passwordController.text == _confirmController.text;
  }

  Future<void> _resetPassword() async {
    if (!_valid || _loading) return;

    FocusScope.of(context).unfocus();
    HapticFeedback.mediumImpact();

    setState(() => _loading = true);

    try {
      await _auth.confirmPasswordReset(
        token: _tokenController.text.trim(),
        newPassword: _passwordController.text,
      );
      if (!mounted) return;
      setState(() => _loading = false);
      PravaToast.show(
        context,
        message: 'Password updated. Sign in again.',
        type: PravaToastType.success,
      );
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (err) {
      if (!mounted) return;
      setState(() => _loading = false);
      final message = err is ApiException
          ? err.message
          : 'Unable to reset password';
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

    final subtitle = widget.email != null && widget.email!.isNotEmpty
        ? 'Enter the 6-digit reset code sent to ${widget.email}.'
        : 'Enter the 6-digit reset code from your email and choose a new password.';

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Set a new password',
                      style: PravaTypography.h1.copyWith(
                        letterSpacing: -0.6,
                        color: primaryText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      style: PravaTypography.body.copyWith(
                        color: secondaryText,
                      ),
                    ),
                    const SizedBox(height: 28),
                    PravaInput(
                      hint: '6-digit reset code',
                      controller: _tokenController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                    ),
                    const SizedBox(height: 18),
                    PravaPasswordInput(
                      hint: 'New password',
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
                    const SizedBox(height: 18),
                    PravaPasswordInput(
                      hint: 'Confirm password',
                      controller: _confirmController,
                      autofillHints: const [AutofillHints.newPassword],
                    ),
                    const SizedBox(height: 28),
                    PravaButton(
                      label: 'Update password',
                      loading: _loading,
                      onPressed: _valid ? _resetPassword : null,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'For security, all active sessions will be signed out.',
                      style: PravaTypography.caption.copyWith(
                        color: secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
