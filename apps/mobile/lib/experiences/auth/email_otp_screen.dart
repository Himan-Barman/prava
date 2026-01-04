import 'dart:async';
import 'dart:ui';

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
import 'set_password_screen.dart';

enum EmailOtpFlow {
  signup,
  verify,
}

class EmailOtpScreen extends StatefulWidget {
  final String email;
  final String? username;
  final EmailOtpFlow flow;

  const EmailOtpScreen({
    super.key,
    required this.email,
    this.username,
    this.flow = EmailOtpFlow.signup,
  });

  @override
  State<EmailOtpScreen> createState() => _EmailOtpScreenState();
}

class _EmailOtpScreenState extends State<EmailOtpScreen> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _nodes = List.generate(6, (_) => FocusNode());

  bool _loading = false;
  bool _resending = false;
  int _secondsLeft = 60;
  Timer? _timer;

  final AuthService _auth = AuthService();

  @override
  void initState() {
    super.initState();
    _startTimer();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _nodes.first.requestFocus();
    });
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.clear();
      c.dispose();
    }
    for (final n in _nodes) {
      n.dispose();
    }
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsLeft = 60);

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft == 0) {
        t.cancel();
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  void _onChanged(String value, int index) {
    if (value.length > 1) {
      final digits = value.replaceAll(RegExp(r'\D'), '');
      if (digits.length >= 6) {
        _fillOtp(digits.substring(0, 6));
        _nodes.last.requestFocus();
        _verifyOtp();
        return;
      }
    }

    if (value.isNotEmpty && index < 5) {
      _nodes[index + 1].requestFocus();
    }

    if (value.isEmpty && index > 0) {
      _nodes[index - 1].requestFocus();
    }

    if (_complete) {
      _verifyOtp();
    }
  }

  String get _otp => _controllers.map((c) => c.text).join();

  bool get _complete =>
      _controllers.every((c) => c.text.isNotEmpty);

  void _fillOtp(String code) {
    for (int i = 0; i < 6; i++) {
      _controllers[i].text = code[i];
    }
  }

  Future<void> _pasteOtp() async {
    final data = await Clipboard.getData('text/plain');
    final value = data?.text ?? '';
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 6) {
      PravaToast.show(
        context,
        message: 'Clipboard does not contain a valid code',
        type: PravaToastType.warning,
      );
      return;
    }

    _fillOtp(digits.substring(0, 6));
    _nodes.last.requestFocus();
    _verifyOtp();
  }

  Future<void> _verifyOtp() async {
    if (!_complete || _loading) return;

    FocusScope.of(context).unfocus();
    HapticFeedback.mediumImpact();

    setState(() => _loading = true);

    try {
      await _auth.verifyEmailOtp(
        email: widget.email,
        code: _otp,
      );

      if (!mounted) return;

      setState(() => _loading = false);

      PravaToast.show(
        context,
        message: 'Email verified',
        type: PravaToastType.success,
      );

      if (widget.flow == EmailOtpFlow.signup) {
        PravaNavigator.pushReplacement(
          context,
          SetPasswordScreen(
            email: widget.email,
            username: widget.username,
          ),
        );
        return;
      }

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
          : 'Invalid or expired code';

      PravaToast.show(
        context,
        message: message,
        type: PravaToastType.error,
      );

      for (final c in _controllers) {
        c.clear();
      }
      _nodes.first.requestFocus();
    }
  }

  Future<void> _resendOtp() async {
    if (_resending) return;
    HapticFeedback.selectionClick();

    setState(() => _resending = true);

    try {
      await _auth.requestEmailOtp(email: widget.email);
      if (!mounted) return;
      setState(() => _resending = false);
      _startTimer();

      PravaToast.show(
        context,
        message: 'Verification code sent',
        type: PravaToastType.info,
      );
    } catch (err) {
      if (!mounted) return;
      setState(() => _resending = false);
      final message = err is ApiException
          ? err.message
          : 'Unable to resend code';
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
                          'Verify your email',
                          style: PravaTypography.h1.copyWith(
                            letterSpacing: -0.6,
                            color: primaryText,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Enter the 6-digit code sent to ${widget.email}.',
                          style: PravaTypography.body.copyWith(
                            color: secondaryText,
                          ),
                        ),
                        const SizedBox(height: 24),
                        _buildOtpCard(
                          isDark: isDark,
                          primaryText: primaryText,
                          secondaryText: secondaryText,
                          tertiaryText: tertiaryText,
                        ),
                        const SizedBox(height: 20),
                        Center(
                          child: GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Text(
                              'Change email',
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
          ],
        ),
      ),
    );
  }

  Widget _buildOtpCard({
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
                    Icons.mark_email_read_outlined,
                    size: 18,
                    color: PravaColors.accentPrimary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Email verification',
                    style: PravaTypography.body.copyWith(
                      color: primaryText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (index) {
                  return _OtpBox(
                    controller: _controllers[index],
                    focusNode: _nodes[index],
                    isDark: isDark,
                    onChanged: (value) => _onChanged(value, index),
                  );
                }),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _secondsLeft > 0
                          ? 'Resend in ${_secondsLeft}s'
                          : 'Didn\'t get a code?',
                      style: PravaTypography.caption.copyWith(
                        color: tertiaryText,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _secondsLeft > 0 ? null : _resendOtp,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: _secondsLeft > 0 ? 0.4 : 1,
                      child: Row(
                        children: [
                          if (_resending)
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else
                            Icon(
                              Icons.refresh,
                              size: 14,
                              color: PravaColors.accentPrimary,
                            ),
                          const SizedBox(width: 6),
                          Text(
                            'Resend',
                            style: PravaTypography.caption.copyWith(
                              color: PravaColors.accentPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: PravaButton(
                      label: _loading ? 'Verifying' : 'Verify',
                      loading: _loading,
                      onPressed: _complete ? _verifyOtp : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: _pasteOtp,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : Colors.white.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: cardBorder),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.content_paste_rounded,
                            size: 16,
                            color: secondaryText,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Paste',
                            style: PravaTypography.caption.copyWith(
                              color: secondaryText,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
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

class _OtpBox extends StatelessWidget {
  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.isDark,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isDark;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final fill = isDark ? PravaColors.darkSurface : PravaColors.lightSurface;
    final border = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.08);

    return SizedBox(
      width: 46,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        style: PravaTypography.h2,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(1),
        ],
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: fill,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: PravaColors.accentPrimary),
          ),
        ),
        onChanged: onChanged,
      ),
    );
  }
}
