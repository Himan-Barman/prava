import 'package:flutter/material.dart';

import 'prava_navigator.dart';
import '../experiences/feed/feed_screen.dart';

class PravaRouter {
  static Route<dynamic> generate(RouteSettings settings) {
    switch (settings.name) {
      case '/':
        return PravaNavigator.route(const FeedScreen());
      default:
        return PravaNavigator.route(
          const Scaffold(
            body: Center(child: Text('404')),
          ),
        );
    }
  }
}
