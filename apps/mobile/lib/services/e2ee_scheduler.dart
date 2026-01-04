import 'dart:async';

import 'e2ee_service.dart';

class E2eeKeyRefreshScheduler {
  E2eeKeyRefreshScheduler({
    E2eeService? e2eeService,
    Duration interval = const Duration(hours: 12),
  })  : _e2ee = e2eeService ?? E2eeService(),
        _interval = interval;

  final E2eeService _e2ee;
  final Duration _interval;
  Timer? _timer;

  bool get isRunning => _timer != null;

  Future<void> start() async {
    if (_timer != null) return;
    await _runOnce();
    _timer = Timer.periodic(_interval, (_) {
      _runOnce();
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _runOnce() async {
    try {
      await _e2ee.refreshKeysIfNeeded();
    } catch (_) {
      // ignore refresh failures
    }
  }
}
