import 'dart:async';

import '../core/network/api_client.dart';
import '../core/storage/secure_store.dart';

class BackendKeepAliveService {
  BackendKeepAliveService({
    ApiClient? client,
    Duration interval = const Duration(minutes: 10),
  }) : _client = client ?? ApiClient(SecureStore()),
       _interval = interval;

  final ApiClient _client;
  final Duration _interval;
  Timer? _timer;
  bool _inFlight = false;
  bool _active = false;

  bool get isRunning => _timer != null;

  Future<void> start() async {
    if (_active) return;
    _active = true;
    await _ping();
    if (!_active) return;
    _timer = Timer.periodic(_interval, (_) {
      _ping();
    });
  }

  void stop() {
    _active = false;
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _ping() async {
    if (!_active || _inFlight) return;
    _inFlight = true;
    try {
      await _client.get('/health');
    } catch (_) {
      // Keepalive failures should never interrupt the user's current screen.
    } finally {
      _inFlight = false;
    }
  }
}
