import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/network/api_exception.dart';
import '../../services/auth_service.dart';
import '../../navigation/prava_navigator.dart';
import '../../ui-system/colors.dart';
import '../../ui-system/components/prava_button.dart';
import '../../ui-system/components/prava_input.dart';
import '../../ui-system/feedback/prava_toast.dart';
import '../../ui-system/feedback/toast_type.dart';
import '../../ui-system/typography.dart';
import 'reset_password_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();

  bool _loading = false;
  bool _sent = false;
  final AuthService _auth = AuthService();

  @override
  void initState() {
    super.initState();
    _emailController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  bool get _canSend {
    final email = _emailController.text.trim();
    return email.isNotEmpty && email.contains('@') && !_loading;
  }

  Future<void> _requestReset() async {
    if (!_canSend) {
      PravaToast.show(
        context,
        message: 'Enter a valid email address',
        type: PravaToastType.warning,
      );
      return;
    }

    FocusScope.of(context).unfocus();
    HapticFeedback.lightImpact();

    final email = _emailController.text.trim();

    setState(() => _loading = true);

    try {
      await _auth.requestPasswordReset(email: email);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _sent = true;
      });
      PravaToast.show(
        context,
        message: 'If an account exists, we sent a reset code',
        type: PravaToastType.info,
      );
    } catch (err) {
      if (!mounted) return;
      setState(() => _loading = false);
      final message = err is ApiException
          ? err.message
          : 'Unable to send reset code';
      PravaToast.show(
        context,
        message: message,
        type: PravaToastType.error,
      );
    }
  }

  void _openReset() {
    HapticFeedback.selectionClick();
    PravaNavigator.push(
      context,
      ResetPasswordScreen(
        email: _emailController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText =
        isDark ? PravaColors.darkTextPrimary : PravaColors.lightTextPrimary;
    final secondaryText =
        isDark ? PravaColors.darkTextSecondary : PravaColors.lightTextSecondary;

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
                      'Reset your password',
                      style: PravaTypography.h1.copyWith(
                        letterSpacing: -0.6,
                        color: primaryText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Enter your email and we will send a secure reset code.',
                      style: PravaTypography.body.copyWith(
                        color: secondaryText,
                      ),
                    ),
                    const SizedBox(height: 28),
                    PravaInput(
                      hint: 'Email address',
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                    ),
                    const SizedBox(height: 20),
                    PravaButton(
                      label: _sent ? 'Resend reset code' : 'Send reset code',
                      loading: _loading,
                      onPressed: _canSend ? _requestReset : null,
                    ),
                    if (_sent) ...[
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.04)
                              : Colors.black.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.black.withValues(alpha: 0.08),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Check your inbox',
                              style: PravaTypography.body.copyWith(
                                color: primaryText,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'We sent a reset code to ${_emailController.text.trim()}.',
                              style: PravaTypography.bodySmall.copyWith(
                                color: secondaryText,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Reset codes expire in 10 minutes.',
                              style: PravaTypography.caption.copyWith(
                                color: secondaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      PravaButton(
                        label: 'Enter reset code',
                        onPressed: _openReset,
                      ),
                    ],
                    const SizedBox(height: 24),
                    Center(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Text(
                          'Back to sign in',
                          style: PravaTypography.body.copyWith(
                            color: PravaColors.accentPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
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
