import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/network/api_exception.dart';
import '../../services/auth_service.dart';
import '../../navigation/prava_navigator.dart';
import '../../ui-system/background.dart';
import '../../ui-system/colors.dart';
import '../../ui-system/components/prava_button.dart';
import '../../ui-system/components/prava_input.dart';
import '../../ui-system/components/prava_password_input.dart';
import '../../ui-system/feedback/prava_toast.dart';
import '../../ui-system/feedback/toast_type.dart';
import '../../ui-system/typography.dart';
import '../home/home_shell.dart';
import 'email_otp_screen.dart';
import 'forgot_password_screen.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _loading = false;
  bool _showHeader = false;
  bool _showCard = false;
  final AuthService _auth = AuthService();

  late final AnimationController _lockController;

  @override
  void initState() {
    super.initState();
    _lockController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _showHeader = true);
      Future.delayed(const Duration(milliseconds: 120), () {
        if (!mounted) return;
        setState(() => _showCard = true);
      });
    });
  }

  @override
  void dispose() {
    _emailController.clear();
    _passwordController.clear();
    _emailController.dispose();
    _passwordController.dispose();
    _lockController.dispose();
    super.dispose();
  }

  Future<void> _onLogin() async {
    if (_loading) return;

    FocusScope.of(context).unfocus();
    HapticFeedback.lightImpact();

    final identifier = _emailController.text.trim();
    final password = _passwordController.text;

    if (identifier.isEmpty || password.isEmpty) {
      PravaToast.show(
        context,
        message: "Username / email and password are required",
        type: PravaToastType.warning,
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final session = await _auth.login(
        email: identifier,
        password: password,
      );

      if (!mounted) return;

      setState(() => _loading = false);

      if (!session.isVerified) {
        await _auth.requestEmailOtp(email: session.email);

        if (!mounted) return;

        PravaToast.show(
          context,
          message: "Verification code sent to ${session.email}",
          type: PravaToastType.info,
        );

        PravaNavigator.pushReplacement(
          context,
          EmailOtpScreen(
            email: session.email,
            flow: EmailOtpFlow.verify,
          ),
        );
        return;
      }

      PravaToast.show(
        context,
        message: "Welcome back",
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
          : "Login failed, please try again";

      PravaToast.show(
        context,
        message: message,
        type: PravaToastType.error,
      );
    }
  }

  void _devLogin() {
    HapticFeedback.selectionClick();

    PravaNavigator.pushAndRemoveUntil(
      context,
      const HomeShell(),
      (_) => false,
    );
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
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Stack(
          children: [
            _buildBackground(isDark),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 32, 24, 96),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 440),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AnimatedSlide(
                                  offset: _showHeader
                                      ? Offset.zero
                                      : const Offset(0, 0.05),
                                  duration: const Duration(milliseconds: 520),
                                  curve: Curves.easeOut,
                                  child: AnimatedOpacity(
                                    opacity: _showHeader ? 1 : 0,
                                    duration:
                                        const Duration(milliseconds: 520),
                                    curve: Curves.easeOut,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Prava",
                                          style: PravaTypography.h1.copyWith(
                                            letterSpacing: -0.8,
                                            color: primaryText,
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          "Sign in to your private workspace",
                                          style: PravaTypography.bodyLarge
                                              .copyWith(
                                            color: secondaryText,
                                            letterSpacing: 0.2,
                                          ),
                                        ),
                                        const SizedBox(height: 18),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 28),
                                AnimatedSlide(
                                  offset: _showCard
                                      ? Offset.zero
                                      : const Offset(0, 0.06),
                                  duration: const Duration(milliseconds: 560),
                                  curve: Curves.easeOut,
                                  child: AnimatedOpacity(
                                    opacity: _showCard ? 1 : 0,
                                    duration:
                                        const Duration(milliseconds: 560),
                                    curve: Curves.easeOut,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _buildLoginCard(
                                          isDark: isDark,
                                          primaryText: primaryText,
                                          secondaryText: secondaryText,
                                          tertiaryText: tertiaryText,
                                        ),
                                        const SizedBox(height: 20),
                                        Center(
                                          child: GestureDetector(
                                            onTap: () {
                                              HapticFeedback.selectionClick();
                                              PravaNavigator.push(
                                                context,
                                                const SignupScreen(),
                                              );
                                            },
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 16,
                                                vertical: 12,
                                              ),
                                              decoration: BoxDecoration(
                                                color: isDark
                                                    ? Colors.white
                                                        .withValues(alpha: 0.04)
                                                    : Colors.white
                                                        .withValues(alpha: 0.75),
                                                borderRadius:
                                                    BorderRadius.circular(18),
                                                border: Border.all(
                                                  color: isDark
                                                      ? Colors.white
                                                          .withValues(alpha: 0.1)
                                                      : Colors.black
                                                          .withValues(alpha: 0.06),
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    "New here?",
                                                    style: PravaTypography
                                                        .bodySmall
                                                        .copyWith(
                                                      color: secondaryText,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    "Create account",
                                                    style: PravaTypography
                                                        .bodySmall
                                                        .copyWith(
                                                      color: PravaColors
                                                          .accentPrimary,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Icon(
                                                    Icons
                                                        .arrow_forward_rounded,
                                                    size: 16,
                                                    color: PravaColors
                                                        .accentPrimary,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        if (kDebugMode) ...[
                                          const SizedBox(height: 18),
                                          Center(
                                            child: GestureDetector(
                                              onTap: _devLogin,
                                              child: Text(
                                                "Dev login (debug only)",
                                                style: PravaTypography.caption
                                                    .copyWith(
                                                  color: PravaColors
                                                      .accentPrimary,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
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
            Positioned(
              left: 0,
              right: 0,
              bottom: 12,
              child: SafeArea(
                top: false,
                child: Center(
                  child: _buildSecurityFooter(tertiaryText),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginCard({
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
              Text(
                "Welcome back",
                style: PravaTypography.h2.copyWith(
                  color: primaryText,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "Use your Prava ID or email to continue.",
                style: PravaTypography.body.copyWith(
                  color: secondaryText,
                ),
              ),
              const SizedBox(height: 22),
              AutofillGroup(
                child: Column(
                  children: [
                    PravaInput(
                      hint: "Email or username",
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [
                        AutofillHints.username,
                        AutofillHints.email,
                      ],
                    ),
                    const SizedBox(height: 14),
                    PravaPasswordInput(
                      hint: "Password",
                      controller: _passwordController,
                      autofillHints: const [AutofillHints.password],
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          PravaNavigator.push(
                            context,
                            const ForgotPasswordScreen(),
                          );
                        },
                        child: Text(
                          "Forgot password?",
                          style: PravaTypography.caption.copyWith(
                            color: PravaColors.accentPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _buildLoginButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoginButton() {
    return AnimatedBuilder(
      animation: Listenable.merge([_emailController, _passwordController]),
      builder: (context, _) {
        final canLogin = _emailController.text.trim().isNotEmpty &&
            _passwordController.text.isNotEmpty;
        final enabled = canLogin && !_loading;

        return AnimatedOpacity(
          duration: const Duration(milliseconds: 160),
          opacity: enabled ? 1 : 0.6,
          child: PravaButton(
            label: "Sign In",
            loading: _loading,
            onPressed: enabled ? _onLogin : null,
          ),
        );
      },
    );
  }

  Widget _buildBackground(bool isDark) {
    return PravaBackground(isDark: isDark);
  }

  Widget _buildSecurityFooter(Color tertiaryText) {
    return FadeTransition(
      opacity: Tween(begin: 0.35, end: 0.9).animate(
        CurvedAnimation(
          parent: _lockController,
          curve: Curves.easeInOut,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.lock_outline,
            size: 16,
            color: tertiaryText,
          ),
          const SizedBox(width: 6),
          Text(
            "End-to-end encrypted",
            style: PravaTypography.caption.copyWith(
              color: tertiaryText,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
