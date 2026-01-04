import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/auth_service.dart';
import '../../core/network/api_exception.dart';
import '../../navigation/prava_navigator.dart';
import '../../ui-system/background.dart';
import '../../ui-system/colors.dart';
import '../../ui-system/typography.dart';
import '../../ui-system/components/prava_button.dart';
import '../../ui-system/components/prava_input.dart';
import '../../ui-system/feedback/prava_toast.dart';
import '../../ui-system/feedback/toast_type.dart';
import 'email_otp_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _usernameFocus = FocusNode();
  final _emailFocus = FocusNode();

  bool _checkingUsername = false;
  bool _usernameAvailable = false;
  bool _usernameChecked = false;
  bool _usernameCheckFailed = false;
  bool _loading = false;

  Timer? _debounce;
  int _usernameCheckToken = 0;

  final AuthService _auth = AuthService();

  final List<TextInputFormatter> _usernameFormatters = [
    _LowercaseTextFormatter(),
    FilteringTextInputFormatter.allow(RegExp(r'[a-z0-9_]')),
    LengthLimitingTextInputFormatter(32),
  ];

  @override
  void initState() {
    super.initState();

    _usernameController.addListener(() {
      setState(() {
        _usernameChecked = false;
        _usernameCheckFailed = false;
      });
      _checkUsername(_usernameController.text);
    });

    _emailController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _usernameController.clear();
    _emailController.clear();
    _usernameController.dispose();
    _emailController.dispose();
    _usernameFocus.dispose();
    _emailFocus.dispose();
    super.dispose();
  }

  String get _usernameValue => _usernameController.text.trim();
  String get _emailValue => _emailController.text.trim();

  bool _isUsernameValid(String value) {
    return RegExp(r'^[a-z0-9_]{3,32}$').hasMatch(value);
  }

  bool get _usernameValid =>
      _isUsernameValid(_usernameValue.toLowerCase());

  bool get _emailValid {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
        .hasMatch(_emailValue);
  }

  bool get _canSendOtp =>
      _usernameChecked && _usernameAvailable && _emailValid && !_loading;

  // --------------------------------------------------
  // USERNAME AVAILABILITY CHECK (DEBOUNCED)
  // --------------------------------------------------
  void _checkUsername(String value) {
    _debounce?.cancel();

    final username = value.trim();
    final normalized = username.toLowerCase();

    if (username.isEmpty) {
      setState(() {
        _usernameAvailable = false;
        _checkingUsername = false;
        _usernameChecked = false;
        _usernameCheckFailed = false;
      });
      return;
    }

    if (!_isUsernameValid(normalized)) {
      setState(() {
        _usernameAvailable = false;
        _checkingUsername = false;
        _usernameChecked = true;
        _usernameCheckFailed = false;
      });
      return;
    }

    final currentCheck = ++_usernameCheckToken;
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      setState(() {
        _checkingUsername = true;
        _usernameChecked = false;
        _usernameCheckFailed = false;
      });

      try {
        final available = await _auth.isUsernameAvailable(normalized);
        if (!mounted || currentCheck != _usernameCheckToken) return;

        setState(() {
          _usernameAvailable = available;
          _checkingUsername = false;
          _usernameChecked = true;
          _usernameCheckFailed = false;
        });
      } catch (_) {
        if (!mounted || currentCheck != _usernameCheckToken) return;

        setState(() {
          _usernameAvailable = false;
          _checkingUsername = false;
          _usernameChecked = true;
          _usernameCheckFailed = true;
        });
      }
    });
  }

  // --------------------------------------------------
  // SEND OTP
  // --------------------------------------------------
  Future<void> _sendOtp() async {
    if (_loading) return;

    if (_checkingUsername) {
      PravaToast.show(
        context,
        message: "Checking username availability",
        type: PravaToastType.info,
      );
      return;
    }

    if (_usernameCheckFailed) {
      PravaToast.show(
        context,
        message: "Unable to verify username. Try again.",
        type: PravaToastType.warning,
      );
      return;
    }

    if (!_usernameValid) {
      PravaToast.show(
        context,
        message: "Username must be 3-32 characters (a-z, 0-9, _)",
        type: PravaToastType.warning,
      );
      return;
    }

    if (!_emailValid) {
      PravaToast.show(
        context,
        message: "Enter a valid email address",
        type: PravaToastType.warning,
      );
      return;
    }

    if (!_usernameChecked || !_usernameAvailable) {
      PravaToast.show(
        context,
        message: "Username is not available",
        type: PravaToastType.warning,
      );
      return;
    }

    FocusScope.of(context).unfocus();
    HapticFeedback.mediumImpact();

    setState(() => _loading = true);

    final email = _emailValue.toLowerCase();
    final username = _usernameValue.toLowerCase();

    try {
      await _auth.requestEmailOtp(email: email);
      if (!mounted) return;

      setState(() => _loading = false);

      PravaToast.show(
        context,
        message: "Verification code sent",
        type: PravaToastType.success,
      );

      PravaNavigator.push(
        context,
        EmailOtpScreen(
          email: email,
          username: username,
        ),
      );
    } catch (err) {
      if (!mounted) return;
      setState(() => _loading = false);
      final message = err is ApiException
          ? err.message
          : "Unable to send verification code";
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

    final primaryText = isDark
        ? PravaColors.darkTextPrimary
        : PravaColors.lightTextPrimary;
    final secondaryText = isDark
        ? PravaColors.darkTextSecondary
        : PravaColors.lightTextSecondary;
    final tertiaryText = isDark
        ? PravaColors.darkTextTertiary
        : PravaColors.lightTextTertiary;

    final status = _buildUsernameStatus(isDark, secondaryText);

    final emailSuffix = _emailValue.isEmpty
        ? null
        : Icon(
            _emailValid ? Icons.check_circle_outline : Icons.error_outline,
            size: 18,
            color: _emailValid ? PravaColors.success : PravaColors.error,
          );

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Stack(
          children: [
            _buildBackground(isDark),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 440),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "Create your account",
                                            style:
                                                PravaTypography.h1.copyWith(
                                              letterSpacing: -0.6,
                                              color: primaryText,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            "Secure signup with verified email and device-bound sessions.",
                                            style:
                                                PravaTypography.body.copyWith(
                                              color: secondaryText,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    _StepBadge(
                                      isDark: isDark,
                                      textColor: secondaryText,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                const _StepIndicator(),
                                const SizedBox(height: 20),
                                _buildFormCard(
                                  isDark: isDark,
                                  primaryText: primaryText,
                                  tertiaryText: tertiaryText,
                                  emailSuffix: emailSuffix,
                                  usernameStatus: status,
                                ),
                                const SizedBox(height: 24),
                                Center(
                                  child: GestureDetector(
                                    onTap: () => Navigator.pop(context),
                                    child: Text(
                                      "Back to sign in",
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
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormCard({
    required bool isDark,
    required Color primaryText,
    required Color tertiaryText,
    required Widget? emailSuffix,
    required Widget? usernameStatus,
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
              AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Prava ID",
                      style: PravaTypography.label.copyWith(
                        color: tertiaryText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _UsernameField(
                      controller: _usernameController,
                      focusNode: _usernameFocus,
                      inputFormatters: _usernameFormatters,
                      primaryText: primaryText,
                      tertiaryText: tertiaryText,
                      isDark: isDark,
                      status: usernameStatus,
                      onSubmitted: () => _emailFocus.requestFocus(),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Email address",
                      style: PravaTypography.label.copyWith(
                        color: tertiaryText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    PravaInput(
                      hint: "Email address",
                      controller: _emailController,
                      focusNode: _emailFocus,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      suffixIcon: emailSuffix,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              PravaButton(
                label: "Send verification code",
                loading: _loading,
                onPressed: _canSendOtp ? _sendOtp : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget? _buildUsernameStatus(bool isDark, Color secondaryText) {
    if (_usernameValue.isEmpty) return null;

    final background = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.05);

    if (_checkingUsername) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: secondaryText,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              "Checking",
              style: PravaTypography.caption.copyWith(
                color: secondaryText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    if (!_usernameValid) {
      return _StatusPill(
        label: "Invalid",
        color: PravaColors.error,
        background: background,
      );
    }

    if (_usernameCheckFailed) {
      return _StatusPill(
        label: "Retry",
        color: PravaColors.warning,
        background: background,
      );
    }

    if (_usernameChecked && _usernameAvailable) {
      return _StatusPill(
        label: "Available",
        color: PravaColors.success,
        background: background,
      );
    }

    if (_usernameChecked && !_usernameAvailable) {
      return _StatusPill(
        label: "Taken",
        color: PravaColors.error,
        background: background,
      );
    }

    return null;
  }

  Widget _buildBackground(bool isDark) {
    return PravaBackground(isDark: isDark);
  }
}

class _StepBadge extends StatelessWidget {
  const _StepBadge({
    required this.isDark,
    required this.textColor,
  });

  final bool isDark;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final border = isDark
        ? Colors.white.withValues(alpha: 0.16)
        : Colors.black.withValues(alpha: 0.08);
    final background = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.04);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Text(
        "Step 1 of 3",
        style: PravaTypography.caption.copyWith(
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        _StepPill(active: true),
        SizedBox(width: 6),
        _StepPill(active: false),
        SizedBox(width: 6),
        _StepPill(active: false),
      ],
    );
  }
}

class _StepPill extends StatelessWidget {
  const _StepPill({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inactive = isDark
        ? Colors.white.withValues(alpha: 0.16)
        : Colors.black.withValues(alpha: 0.12);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: active ? 36 : 18,
      height: 6,
      decoration: BoxDecoration(
        color: active ? PravaColors.accentPrimary : inactive,
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

class _UsernameField extends StatelessWidget {
  const _UsernameField({
    required this.controller,
    required this.focusNode,
    required this.inputFormatters,
    required this.primaryText,
    required this.tertiaryText,
    required this.isDark,
    required this.status,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final List<TextInputFormatter> inputFormatters;
  final Color primaryText;
  final Color tertiaryText;
  final bool isDark;
  final Widget? status;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    final fill = isDark ? PravaColors.darkSurface : PravaColors.lightSurface;
    final border = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.08);
    final hint = isDark
        ? PravaColors.darkTextTertiary
        : PravaColors.lightTextTertiary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Text(
            "@",
            style: PravaTypography.body.copyWith(
              color: primaryText,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 1,
            height: 22,
            color: border,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              inputFormatters: inputFormatters,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.none,
              enableSuggestions: false,
              autocorrect: false,
              autofillHints: const [AutofillHints.username],
              style: PravaTypography.body.copyWith(
                color: primaryText,
              ),
              cursorColor: PravaColors.accentPrimary,
              decoration: InputDecoration(
                hintText: "username",
                hintStyle: PravaTypography.body.copyWith(
                  color: hint,
                ),
                border: InputBorder.none,
                isCollapsed: true,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 18),
              ),
              onSubmitted: (_) => onSubmitted(),
            ),
          ),
          if (status != null) ...[
            const SizedBox(width: 10),
            status!,
          ],
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.color,
    required this.background,
  });

  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: PravaTypography.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}


class _LowercaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final lowered = newValue.text.toLowerCase();
    return newValue.copyWith(text: lowered, selection: newValue.selection);
  }
}
