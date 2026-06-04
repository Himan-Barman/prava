import 'package:flutter/material.dart';

import '../core/auth/auth_state.dart';
import '../core/storage/secure_store.dart';
import '../experiences/auth/login_screen.dart';
import '../experiences/home/home_shell.dart';
import '../navigation/prava_navigator.dart';
import '../services/backend_keepalive_service.dart';
import '../ui-system/theme.dart';
import 'deep_link_handler.dart';
import 'settings_controller.dart';

class PravaApp extends StatefulWidget {
  const PravaApp({super.key, required this.settingsController});

  final SettingsController settingsController;

  @override
  State<PravaApp> createState() => _PravaAppState();
}

class _PravaAppState extends State<PravaApp> {
  final GlobalKey<NavigatorState> _navigatorKey =
      GlobalKey<NavigatorState>();
  late final DeepLinkHandler _deepLinks;
  late final AuthState _authState;
  late final SecureStore _store;
  late final BackendKeepAliveService _backendKeepAlive;

  @override
  void initState() {
    super.initState();
    _store = SecureStore();
    _authState = AuthState(store: _store);
    _backendKeepAlive = BackendKeepAliveService();
    _deepLinks = DeepLinkHandler(navigatorKey: _navigatorKey);
    _deepLinks.start();
    _backendKeepAlive.start();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _deepLinks.notifyReady();
    });

    // Check session on startup
    _authState.initialize();

    // Listen for forced logouts (e.g. token refresh failure)
    _authState.addListener(_onAuthChanged);
  }

  void _onAuthChanged() {
    if (!_authState.initializing && !_authState.authenticated) {
      // Force redirect to login when session is invalidated
      final nav = _navigatorKey.currentState;
      if (nav != null) {
        nav.pushAndRemoveUntil(
          PravaNavigator.route(const LoginScreen()),
          (_) => false,
        );
      }
    }
  }

  @override
  void dispose() {
    _authState.removeListener(_onAuthChanged);
    _backendKeepAlive.stop();
    _deepLinks.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SettingsScope(
      controller: widget.settingsController,
      child: AnimatedBuilder(
        animation: Listenable.merge([widget.settingsController, _authState]),
        builder: (context, _) {
          return MaterialApp(
            navigatorKey: _navigatorKey,
            title: 'Prava',
            debugShowCheckedModeBanner: false,

            // dYOz Light mode (PRIMARY)
            theme: PravaTheme.light,

            // dYOT Dark mode (ready)
            darkTheme: PravaTheme.dark,
            themeMode: widget.settingsController.themeMode,

            home: _buildHome(),
            builder: (context, child) {
              final media = MediaQuery.of(context);
              final textScaler = TextScaler.linear(
                widget.settingsController.textScale,
              );
              return MediaQuery(
                data: media.copyWith(
                  textScaler: textScaler,
                  disableAnimations: widget.settingsController.reduceMotion,
                ),
                child: child ?? const SizedBox.shrink(),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildHome() {
    // Still initializing — show a branded loading screen
    if (_authState.initializing) {
      return const _AuthGate();
    }

    // Has valid session — go straight to HomeShell
    if (_authState.authenticated) {
      return const HomeShell();
    }

    // No session — show login
    return const LoginScreen();
  }
}

/// Minimal loading gate while checking session on app startup.
/// Shows the app branding with a subtle loading indicator.
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0C0C0C) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0C0C0C);

    return Scaffold(
      backgroundColor: bg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'PRAVA',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: textColor,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: textColor.withValues(alpha: 0.3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
