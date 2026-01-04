import 'package:flutter/material.dart';

import '../experiences/auth/login_screen.dart';
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

  @override
  void initState() {
    super.initState();
    _deepLinks = DeepLinkHandler(navigatorKey: _navigatorKey);
    _deepLinks.start();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _deepLinks.notifyReady();
    });
  }

  @override
  void dispose() {
    _deepLinks.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SettingsScope(
      controller: widget.settingsController,
      child: AnimatedBuilder(
        animation: widget.settingsController,
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

            // dYsAI Entry screen
            home: const LoginScreen(),
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
}
