import '../core/network/api_client.dart';
import '../core/storage/secure_store.dart';

class NotificationActor {
  NotificationActor({
    required this.id,
    required this.username,
    required this.displayName,
    required this.isVerified,
  });

  final String id;
  final String username;
  final String displayName;
  final bool isVerified;

  factory NotificationActor.fromJson(Map<String, dynamic> json) {
    final username = json['username']?.toString() ?? '';
    return NotificationActor(
      id: json['id']?.toString() ?? '',
      username: username,
      displayName: json['displayName']?.toString() ?? username,
      isVerified: json['isVerified'] == true,
    );
  }
}

class NotificationItem {
  NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.readAt,
    this.data = const {},
    this.actor,
  });

  final String id;
  final String type;
  final String title;
  final String body;
  final DateTime createdAt;
  final DateTime? readAt;
  final Map<String, dynamic> data;
  final NotificationActor? actor;

  bool get isUnread => readAt == null;

  NotificationItem copyWith({
    DateTime? readAt,
  }) {
    return NotificationItem(
      id: id,
      type: type,
      title: title,
      body: body,
      createdAt: createdAt,
      readAt: readAt ?? this.readAt,
      data: data,
      actor: actor,
    );
  }

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? 'system',
      title: json['title']?.toString() ?? 'Notification',
      body: json['body']?.toString() ?? '',
      createdAt: _parseDate(json['createdAt']) ?? DateTime.now(),
      readAt: _parseDate(json['readAt']),
      data: json['data'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(
              json['data'] as Map<String, dynamic>,
            )
          : const <String, dynamic>{},
      actor: json['actor'] is Map<String, dynamic>
          ? NotificationActor.fromJson(
              json['actor'] as Map<String, dynamic>,
            )
          : null,
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    return null;
  }
}

class NotificationPage {
  NotificationPage({
    required this.items,
    this.nextCursor,
    this.unreadCount = 0,
  });

  final List<NotificationItem> items;
  final String? nextCursor;
  final int unreadCount;
}

class NotificationService {
  NotificationService({SecureStore? store})
      : _client = ApiClient(store ?? SecureStore());

  final ApiClient _client;

  Future<NotificationPage> fetchNotifications({
    int limit = 20,
    String? cursor,
  }) async {
    final query = <String, String>{
      'limit': limit.toString(),
    };
    if (cursor != null && cursor.isNotEmpty) {
      query['cursor'] = cursor;
    }

    final data = await _client.get(
      '/notifications',
      auth: true,
      query: query,
    );

    final payload = data is Map<String, dynamic>
        ? data
        : <String, dynamic>{};
    final rawItems = payload['items'];
    final items = rawItems is List
        ? rawItems
            .whereType<Map<String, dynamic>>()
            .map(NotificationItem.fromJson)
            .toList()
        : <NotificationItem>[];

    final nextCursor = payload['nextCursor']?.toString();
    final unreadCount = payload['unreadCount'];
    final count = unreadCount is num
        ? unreadCount.toInt()
        : int.tryParse(unreadCount?.toString() ?? '') ?? 0;

    return NotificationPage(
      items: items,
      nextCursor: nextCursor,
      unreadCount: count,
    );
  }

  Future<int> fetchUnreadCount() async {
    final data = await _client.get(
      '/notifications/unread-count',
      auth: true,
    );
    if (data is Map<String, dynamic>) {
      final count = data['count'];
      if (count is int) return count;
    }
    return 0;
  }

  Future<void> markRead(String notificationId) async {
    await _client.post(
      '/notifications/$notificationId/read',
      auth: true,
    );
  }

  Future<void> markAllRead() async {
    await _client.post(
      '/notifications/read-all',
      auth: true,
    );
  }
}
