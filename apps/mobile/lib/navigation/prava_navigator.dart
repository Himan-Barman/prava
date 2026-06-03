import 'package:flutter/material.dart';

class PravaNavigator {
  static PageRoute<T> route<T>(
    Widget page, {
    bool fullscreenDialog = false,
    RouteSettings? settings,
  }) {
    return PageRouteBuilder<T>(
      pageBuilder: (_, __, ___) => page,
      fullscreenDialog: fullscreenDialog,
      settings: settings,
      transitionDuration: const Duration(milliseconds: 260),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      transitionsBuilder: (_, animation, __, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.04, 0),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  static Future<T?> push<T>(
    BuildContext context,
    Widget page, {
    bool fullscreenDialog = false,
    RouteSettings? settings,
  }) {
    return Navigator.of(context).push<T>(
      route<T>(
        page,
        fullscreenDialog: fullscreenDialog,
        settings: settings,
      ),
    );
  }

  static Future<T?> pushReplacement<T, TO>(
    BuildContext context,
    Widget page, {
    bool fullscreenDialog = false,
    RouteSettings? settings,
    TO? result,
  }) {
    return Navigator.of(context).pushReplacement<T, TO>(
      route<T>(
        page,
        fullscreenDialog: fullscreenDialog,
        settings: settings,
      ),
      result: result,
    );
  }

  static Future<T?> pushAndRemoveUntil<T>(
    BuildContext context,
    Widget page,
    RoutePredicate predicate, {
    bool fullscreenDialog = false,
    RouteSettings? settings,
  }) {
    return Navigator.of(context).pushAndRemoveUntil<T>(
      route<T>(
        page,
        fullscreenDialog: fullscreenDialog,
        settings: settings,
      ),
      predicate,
    );
  }

  static void pop<T>(BuildContext context, [T? result]) {
    Navigator.of(context).pop<T>(result);
  }
}
