import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../core/config/app_config.dart';
import '../core/device/device_id.dart';
import '../core/storage/secure_store.dart';

typedef ChatEventHandler = void Function(Map<String, dynamic> event);

class ChatRealtime {
  ChatRealtime({SecureStore? store})
      : _store = store ?? SecureStore(),
        _deviceIdStore = DeviceIdStore(store ?? SecureStore());

  final SecureStore _store;
  final DeviceIdStore _deviceIdStore;

  WebSocketChannel? _channel;
  ChatEventHandler? _handler;
  Timer? _reconnectTimer;
  bool _manualClose = false;
  int _reconnectAttempt = 0;

  bool get isConnected => _channel != null;

  Future<void> connect(ChatEventHandler onEvent) async {
    _handler = onEvent;
    _manualClose = false;
    await _openChannel();
  }

  Future<void> _openChannel() async {
    if (_channel != null) return;

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
    _reconnectAttempt = 0;

    _channel?.stream.listen(
      (data) {
        try {
          final decoded = jsonDecode(data.toString());
          if (decoded is Map<String, dynamic>) {
            _handler?.call(decoded);
          }
        } catch (_) {
          // ignore invalid payloads
        }
      },
      onDone: _handleDisconnect,
      onError: (_) => _handleDisconnect(),
    );
  }

  void _handleDisconnect() {
    _channel = null;
    if (_manualClose) return;
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_reconnectTimer != null) return;
    final delaySeconds = (_reconnectAttempt == 0)
        ? 1
        : (_reconnectAttempt < 6
            ? 2 << (_reconnectAttempt - 1)
            : 30);
    _reconnectAttempt += 1;
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      _reconnectTimer = null;
      _openChannel();
    });
  }

  void sendTyping({
    required String conversationId,
    required bool isTyping,
  }) {
    _send(
      isTyping ? 'TYPING_START' : 'TYPING_STOP',
      {'conversationId': conversationId},
    );
  }

  void sendMessage({
    required String conversationId,
    required String body,
    required String tempId,
    String contentType = 'text',
    String? mediaAssetId,
    DateTime? clientTimestamp,
  }) {
    _send('MESSAGE_SEND', {
      'conversationId': conversationId,
      'body': body,
      'contentType': contentType,
      'tempId': tempId,
      if (mediaAssetId != null) 'mediaAssetId': mediaAssetId,
      if (clientTimestamp != null)
        'clientTimestamp': clientTimestamp.millisecondsSinceEpoch,
    });
  }

  void sendReadReceipt({
    required String conversationId,
    required int lastReadSeq,
  }) {
    _send('READ_RECEIPT', {
      'conversationId': conversationId,
      'lastReadSeq': lastReadSeq,
    });
  }

  void sendDeliveryReceipt({
    required String conversationId,
    required int lastDeliveredSeq,
  }) {
    _send('DELIVERY_RECEIPT', {
      'conversationId': conversationId,
      'lastDeliveredSeq': lastDeliveredSeq,
    });
  }

  void editMessage({
    required String conversationId,
    required String messageId,
    required String body,
  }) {
    _send('MESSAGE_EDIT', {
      'conversationId': conversationId,
      'messageId': messageId,
      'body': body,
    });
  }

  void deleteMessage({
    required String conversationId,
    required String messageId,
  }) {
    _send('MESSAGE_DELETE', {
      'conversationId': conversationId,
      'messageId': messageId,
    });
  }

  void setReaction({
    required String conversationId,
    required String messageId,
    required String emoji,
  }) {
    _send('REACTION_SET', {
      'conversationId': conversationId,
      'messageId': messageId,
      'emoji': emoji,
    });
  }

  void removeReaction({
    required String conversationId,
    required String messageId,
  }) {
    _send('REACTION_REMOVE', {
      'conversationId': conversationId,
      'messageId': messageId,
    });
  }

  void subscribeConversation(String conversationId) {
    _send('CONVERSATION_SUBSCRIBE', {
      'conversationId': conversationId,
    });
  }

  void syncInit(List<Map<String, dynamic>> conversations) {
    _send('SYNC_INIT', {
      'conversations': conversations,
    });
  }

  void _send(String type, Map<String, dynamic> payload) {
    final channel = _channel;
    if (channel == null) return;
    channel.sink.add(jsonEncode({'type': type, 'payload': payload}));
  }

  Future<void> disconnect() async {
    _manualClose = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await _channel?.sink.close();
    _channel = null;
  }
}
