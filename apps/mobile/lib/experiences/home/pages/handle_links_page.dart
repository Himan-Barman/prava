import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/network/api_exception.dart';
import '../../../services/account_service.dart';
import '../../../services/auth_service.dart';
import '../../../ui-system/colors.dart';
import '../../../ui-system/components/prava_button.dart';
import '../../../ui-system/components/prava_input.dart';
import '../../../ui-system/feedback/prava_toast.dart';
import '../../../ui-system/feedback/toast_type.dart';
import '../../../ui-system/typography.dart';
import 'settings_detail_shell.dart';

class HandleLinksPage extends StatefulWidget {
  const HandleLinksPage({super.key});

  @override
  State<HandleLinksPage> createState() => _HandleLinksPageState();
}

class _HandleLinksPageState extends State<HandleLinksPage> {
  final AccountService _accountService = AccountService();
  final AuthService _authService = AuthService();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  AccountInfo? _account;
  Timer? _usernameTimer;
  bool _loading = true;
  bool _checkingUsername = false;
  bool _saving = false;
  bool? _usernameAvailable;
  String _checkedUsername = '';
  int _checkSerial = 0;

  @override
  void initState() {
    super.initState();
    _loadAccount();
    _usernameController.addListener(_handleUsernameChanged);
    _passwordController.addListener(_handlePasswordChanged);
  }

  @override
  void dispose() {
    _usernameTimer?.cancel();
    _usernameController.removeListener(_handleUsernameChanged);
    _passwordController.removeListener(_handlePasswordChanged);
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadAccount() async {
    try {
      final info = await _accountService.fetchAccountInfo();
      if (!mounted) return;
      setState(() {
        _account = info;
        _usernameController.text = info.username;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      PravaToast.show(
        context,
        message: 'Unable to load username settings',
        type: PravaToastType.error,
      );
    }
  }

  String get _candidate => _usernameController.text.trim().toLowerCase();

  bool get _changed {
    final current = _account?.username.trim().toLowerCase() ?? '';
    return _candidate.isNotEmpty && _candidate != current;
  }

  bool get _validUsername {
    return RegExp(r'^[a-z0-9_.]{3,32}$').hasMatch(_candidate);
  }

  bool get _canSubmit {
    return !_saving &&
        _account?.canChangeUsername == true &&
        _changed &&
        _validUsername &&
        _usernameAvailable == true &&
        _checkedUsername == _candidate &&
        _passwordController.text.isNotEmpty;
  }

  void _handleUsernameChanged() {
    _usernameTimer?.cancel();
    setState(() {
      _usernameAvailable = null;
      _checkedUsername = '';
      _checkingUsername = false;
    });

    if (!_changed || !_validUsername) return;

    _usernameTimer = Timer(
      const Duration(milliseconds: 450),
      () => _checkUsernameAvailability(),
    );
  }

  void _handlePasswordChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _checkUsernameAvailability() async {
    final username = _candidate;
    _usernameTimer?.cancel();

    if (!_changed) {
      setState(() {
        _usernameAvailable = null;
        _checkedUsername = '';
        _checkingUsername = false;
      });
      return;
    }

    if (!_validUsername) {
      setState(() {
        _usernameAvailable = false;
        _checkedUsername = username;
        _checkingUsername = false;
      });
      return;
    }

    final serial = ++_checkSerial;
    setState(() => _checkingUsername = true);

    try {
      final available = await _authService.isUsernameAvailable(username);
      if (!mounted || serial != _checkSerial) return;
      setState(() {
        _usernameAvailable = available;
        _checkedUsername = username;
        _checkingUsername = false;
      });
    } catch (_) {
      if (!mounted || serial != _checkSerial) return;
      setState(() {
        _usernameAvailable = false;
        _checkedUsername = username;
        _checkingUsername = false;
      });
      PravaToast.show(
        context,
        message: 'Unable to check username',
        type: PravaToastType.error,
      );
    }
  }

  Future<void> _changeUsername() async {
    if (_saving) return;
    if (!_canSubmit) {
      if (!_changed) {
        _showWarning('Enter a new username');
      } else if (!_validUsername) {
        _showWarning('Use 3-32 letters, numbers, dots, or underscores');
      } else if (_usernameAvailable != true || _checkedUsername != _candidate) {
        _showWarning('Check username availability first');
      } else if (_passwordController.text.isEmpty) {
        _showWarning('Enter your password');
      }
      return;
    }

    setState(() => _saving = true);
    try {
      final updated = await _accountService.changeUsername(
        username: _candidate,
        password: _passwordController.text,
      );
      if (!mounted) return;
      setState(() {
        _account = updated;
        _usernameController.text = updated.username;
        _passwordController.clear();
        _usernameAvailable = null;
        _checkedUsername = '';
        _saving = false;
      });
      PravaToast.show(
        context,
        message: 'Username changed',
        type: PravaToastType.success,
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      PravaToast.show(
        context,
        message: _friendlyError(error),
        type: PravaToastType.error,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      PravaToast.show(
        context,
        message: 'Unable to change username',
        type: PravaToastType.error,
      );
    }
  }

  void _showWarning(String message) {
    PravaToast.show(context, message: message, type: PravaToastType.warning);
  }

  String _friendlyError(ApiException error) {
    if (error.statusCode == 401) return 'Password is incorrect';
    if (error.statusCode == 409) return 'Username is not available';
    if (error.statusCode == 429) {
      return 'Username can be changed once every 3 months';
    }
    return error.message;
  }

  String _formatDate(DateTime? value) {
    if (value == null) return '';
    final local = value.toLocal();
    return MaterialLocalizations.of(context).formatMediumDate(local);
  }

  Widget? _usernameSuffix() {
    if (_checkingUsername) {
      return const Padding(
        padding: EdgeInsets.all(14),
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (!_changed || _checkedUsername != _candidate) return null;
    if (_usernameAvailable == true) {
      return const Icon(
        CupertinoIcons.check_mark_circled_solid,
        color: PravaColors.success,
      );
    }
    if (_usernameAvailable == false) {
      return const Icon(
        CupertinoIcons.xmark_circle_fill,
        color: PravaColors.error,
      );
    }
    return null;
  }

  String _statusText() {
    if (!_changed) return 'Current username';
    if (!_validUsername) {
      return 'Use 3-32 letters, numbers, dots, or underscores';
    }
    if (_checkingUsername) return 'Checking database...';
    if (_checkedUsername != _candidate) return 'Waiting to check availability';
    if (_usernameAvailable == true) return 'Username is available';
    if (_usernameAvailable == false) return 'Username is taken';
    return 'Search your preferred username';
  }

  Color _statusColor(Color secondary) {
    if (_checkedUsername == _candidate && _usernameAvailable == true) {
      return PravaColors.success;
    }
    if ((!_validUsername && _changed) ||
        (_checkedUsername == _candidate && _usernameAvailable == false)) {
      return PravaColors.error;
    }
    return secondary;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark
        ? PravaColors.darkTextPrimary
        : PravaColors.lightTextPrimary;
    final secondary = isDark
        ? PravaColors.darkTextSecondary
        : PravaColors.lightTextSecondary;
    final account = _account;
    final canChange = account?.canChangeUsername == true;
    final nextChangeLabel = _formatDate(account?.nextUsernameChangeAt);

    return SettingsDetailShell(
      title: 'Username',
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                Text(
                  'Current username',
                  style: PravaTypography.caption.copyWith(color: secondary),
                ),
                const SizedBox(height: 6),
                Text(
                  '@${account?.username ?? ''}',
                  style: PravaTypography.h3.copyWith(
                    color: primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 18),
                PravaInput(
                  controller: _usernameController,
                  hint: 'Search username',
                  suffixIcon: _usernameSuffix(),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9_.]')),
                    LengthLimitingTextInputFormatter(32),
                    _LowerCaseTextFormatter(),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _statusText(),
                  style: PravaTypography.caption.copyWith(
                    color: _statusColor(secondary),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),
                PravaButton(
                  label: 'Check availability',
                  loading: _checkingUsername,
                  onPressed: _changed && _validUsername
                      ? _checkUsernameAvailability
                      : null,
                ),
                const SizedBox(height: 24),
                Text(
                  'Password verification',
                  style: PravaTypography.body.copyWith(
                    color: primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                PravaInput(
                  controller: _passwordController,
                  hint: 'Password',
                  obscureText: true,
                  autofillHints: const [AutofillHints.password],
                ),
                const SizedBox(height: 12),
                Text(
                  canChange
                      ? 'You can change your username now. After changing it, the next change is available after 3 months.'
                      : nextChangeLabel.isEmpty
                      ? 'Username can be changed once every 3 months.'
                      : 'You can change your username again after $nextChangeLabel.',
                  style: PravaTypography.caption.copyWith(color: secondary),
                ),
                const SizedBox(height: 22),
                PravaButton(
                  label: 'Change username',
                  loading: _saving,
                  onPressed: _canSubmit ? _changeUsername : null,
                ),
              ],
            ),
    );
  }
}

class _LowerCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toLowerCase());
  }
}
