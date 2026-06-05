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
      transitionDuration: Duration(milliseconds: fullscreenDialog ? 340 : 300),
      reverseTransitionDuration: Duration(
        milliseconds: fullscreenDialog ? 260 : 240,
      ),
      transitionsBuilder: (_, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        final secondary = CurvedAnimation(
          parent: secondaryAnimation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        final begin = fullscreenDialog
            ? const Offset(0, 0.08)
            : const Offset(1, 0);
        final slide = Tween<Offset>(
          begin: begin,
          end: Offset.zero,
        ).animate(curved);
        final outgoingSlide = Tween<Offset>(
          begin: Offset.zero,
          end: fullscreenDialog ? Offset.zero : const Offset(-0.18, 0),
        ).animate(secondary);

        return FadeTransition(
          opacity: Tween<double>(begin: 0.96, end: 1).animate(curved),
          child: SlideTransition(
            position: outgoingSlide,
            child: SlideTransition(position: slide, child: child),
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
      route<T>(page, fullscreenDialog: fullscreenDialog, settings: settings),
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
      route<T>(page, fullscreenDialog: fullscreenDialog, settings: settings),
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
      route<T>(page, fullscreenDialog: fullscreenDialog, settings: settings),
      predicate,
    );
  }

  static void pop<T>(BuildContext context, [T? result]) {
    Navigator.of(context).pop<T>(result);
  }
}
