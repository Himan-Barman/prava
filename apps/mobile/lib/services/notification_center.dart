import 'dart:async';

import 'package:flutter/foundation.dart';

import 'notification_realtime.dart';
import 'notification_service.dart';

class NotificationCenter {
  NotificationCenter._();

  static final NotificationCenter instance = NotificationCenter._();

  final NotificationService _service = NotificationService();
  final NotificationRealtime _realtime = NotificationRealtime();
  final StreamController<NotificationItem> _stream =
      StreamController<NotificationItem>.broadcast();

  final ValueNotifier<int> unreadCount = ValueNotifier<int>(0);

  bool _initialized = false;
  bool _connecting = false;

  Stream<NotificationItem> get stream => _stream.stream;

  void ensureInitialized() {
    if (_initialized) return;
    _initialized = true;
    refreshUnread();
    _connect();
  }

  Future<void> refreshUnread() async {
    try {
      final count = await _service.fetchUnreadCount();
      unreadCount.value = count;
    } catch (_) {
      // ignore refresh failures
    }
  }

  void _connect() {
    if (_connecting) return;
    _connecting = true;
    _realtime.connect(_handleEvent);
  }

  void _handleEvent(Map<String, dynamic> event) {
    if (event['type'] != 'NOTIFICATION_PUSH') return;
    final payload = event['payload'];
    if (payload is! Map<String, dynamic>) return;

    final item = NotificationItem.fromJson(payload);
    _stream.add(item);

    if (item.isUnread) {
      unreadCount.value = unreadCount.value + 1;
    }
  }

  void applyRead() {
    if (unreadCount.value > 0) {
      unreadCount.value = unreadCount.value - 1;
    }
  }

  void applyReadAll() {
    unreadCount.value = 0;
  }

  Future<void> dispose() async {
    await _realtime.disconnect();
    await _stream.close();
    _initialized = false;
    _connecting = false;
  }
}
