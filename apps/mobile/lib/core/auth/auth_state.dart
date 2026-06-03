import 'dart:async';

import 'package:flutter/foundation.dart';

import '../storage/secure_store.dart';

/// Global authentication state for the app.
/// Tracks whether the user has an active session and notifies listeners
/// on auth state changes (login, logout, forced-logout on 401).
class AuthState extends ChangeNotifier {
  AuthState({SecureStore? store}) : _store = store ?? SecureStore();

  final SecureStore _store;

  bool _authenticated = false;
  bool _initializing = true;

  bool get authenticated => _authenticated;
  bool get initializing => _initializing;

  /// Called once at app start. Checks if we have stored tokens.
  Future<void> initialize() async {
    try {
      final accessToken = await _store.getAccessToken();
      final refreshToken = await _store.getRefreshToken();
      final userId = await _store.getUserId();

      _authenticated = accessToken != null &&
          accessToken.isNotEmpty &&
          refreshToken != null &&
          refreshToken.isNotEmpty &&
          userId != null &&
          userId.isNotEmpty;
    } catch (_) {
      _authenticated = false;
    }

    _initializing = false;
    notifyListeners();
  }

  /// Called after successful login/register.
  void onAuthenticated() {
    _authenticated = true;
    notifyListeners();
  }

  /// Called on logout or forced-logout (401 from token refresh).
  Future<void> onUnauthenticated() async {
    _authenticated = false;
    try {
      await _store.clearSession();
    } catch (_) {}
    notifyListeners();
  }
}
