import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';

import '../experiences/auth/reset_password_screen.dart';
import '../navigation/prava_navigator.dart';

class DeepLinkHandler {
  DeepLinkHandler({required GlobalKey<NavigatorState> navigatorKey})
      : _navigatorKey = navigatorKey,
        _links = AppLinks();

  final GlobalKey<NavigatorState> _navigatorKey;
  final AppLinks _links;
  StreamSubscription<Uri>? _subscription;
  Uri? _pending;

  Future<void> start() async {
    _subscription?.cancel();
    _subscription = _links.uriLinkStream.listen(_handleUri, onError: (_) {});
    final initial = await _links.getInitialLink();
    if (initial != null) {
      _pending = initial;
      _tryHandlePending();
    }
  }

  void notifyReady() {
    _tryHandlePending();
  }

  void dispose() {
    _subscription?.cancel();
  }

  void _tryHandlePending() {
    final pending = _pending;
    if (pending == null) return;
    if (_navigatorKey.currentState == null) return;
    _pending = null;
    _handleUri(pending);
  }

  void _handleUri(Uri uri) {
    if (_navigatorKey.currentState == null) {
      _pending = uri;
      return;
    }

    final route = _normalizeRoute(uri);
    if (route != '/reset' && route != '/password-reset') {
      return;
    }

    String? token =
        uri.queryParameters['token'] ?? uri.queryParameters['code'];
    if (token == null || token.isEmpty) {
      final segments = uri.pathSegments;
      if (segments.isNotEmpty) {
        final last = segments.last.trim();
        if (last.length >= 20 || RegExp(r'^\d{6}$').hasMatch(last)) {
          token = last;
        }
      }
    }

    if (token == null || token.isEmpty) return;

    final email = uri.queryParameters['email'];
    _navigatorKey.currentState!.push(
      PravaNavigator.route(
        ResetPasswordScreen(
          email: email,
          initialToken: token,
        ),
      ),
    );
  }

  String _normalizeRoute(Uri uri) {
    if (uri.path.isNotEmpty) {
      final cleaned = uri.path.startsWith('/')
          ? uri.path
          : '/${uri.path}';
      return cleaned.toLowerCase();
    }
    if (uri.host.isNotEmpty) {
      return '/${uri.host.toLowerCase()}';
    }
    return '/';
  }
}
