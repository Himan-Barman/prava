import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../core/config/app_config.dart';
import '../core/device/device_id.dart';
import '../core/storage/secure_store.dart';

typedef FeedEventHandler = void Function(Map<String, dynamic> event);

class FeedRealtime {
  FeedRealtime({SecureStore? store})
      : _store = store ?? SecureStore(),
        _deviceIdStore = DeviceIdStore(store ?? SecureStore());

  final SecureStore _store;
  final DeviceIdStore _deviceIdStore;

  WebSocketChannel? _channel;

  Future<void> connect(FeedEventHandler onEvent) async {
    final token = await _store.getAccessToken();
    if (token == null || token.isEmpty) return;

    final deviceId = await _deviceIdStore.getOrCreate();
    final url = Uri.parse(AppConfig.wsBaseUrl).replace(
      queryParameters: {
        'token': token,
        'deviceId': deviceId,
      },
    );

    _channel = WebSocketChannel.connect(url);
    _channel?.stream.listen((data) {
      try {
        final decoded = jsonDecode(data.toString());
        if (decoded is Map<String, dynamic>) {
          onEvent(decoded);
        }
      } catch (_) {
        // ignore invalid payloads
      }
    });

    _channel?.sink.add(
      jsonEncode({
        'type': 'FEED_SUBSCRIBE',
      }),
    );
  }

  Future<void> disconnect() async {
    await _channel?.sink.close();
    _channel = null;
  }
}
