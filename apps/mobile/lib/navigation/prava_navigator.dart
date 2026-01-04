import 'package:flutter/cupertino.dart';

class PravaNavigator {
  static CupertinoPageRoute<T> route<T>(
    Widget page, {
    bool fullscreenDialog = false,
    RouteSettings? settings,
  }) {
    return CupertinoPageRoute<T>(
      builder: (_) => page,
      fullscreenDialog: fullscreenDialog,
      settings: settings,
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
