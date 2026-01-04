import '../core/device/device_id.dart';
import '../core/network/api_client.dart';
import '../core/storage/secure_store.dart';

enum MessageDeliveryState { sending, sent, delivered, read, failed }

enum ChatMessageType { text, system, media }

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value);
  }
  return DateTime.tryParse(value.toString());
}

int? _parseInt(dynamic value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '');
}

ChatMessageType _parseContentType(String? value) {
  switch (value) {
    case 'system':
      return ChatMessageType.system;
    case 'media':
      return ChatMessageType.media;
    case 'text':
    default:
      return ChatMessageType.text;
  }
}

class ChatReaction {
  ChatReaction({
    required this.userId,
    required this.emoji,
    required this.reactedAt,
    required this.updatedAt,
  });

  final String userId;
  final String emoji;
  final DateTime? reactedAt;
  final DateTime? updatedAt;

  factory ChatReaction.fromJson(Map<String, dynamic> json) {
    return ChatReaction(
      userId: json['userId']?.toString() ?? '',
      emoji: json['emoji']?.toString() ?? '',
      reactedAt: _parseDate(json['reactedAt']),
      updatedAt: _parseDate(json['updatedAt']),
    );
  }

  ChatReaction copyWith({
    String? emoji,
    DateTime? reactedAt,
    DateTime? updatedAt,
  }) {
    return ChatReaction(
      userId: userId,
      emoji: emoji ?? this.emoji,
      reactedAt: reactedAt ?? this.reactedAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class ChatMessage {
  ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderUserId,
    required this.senderDeviceId,
    required this.body,
    required this.type,
    required this.createdAt,
    this.seq,
    this.clientTempId,
    this.mediaAssetId,
    this.editVersion = 0,
    this.deletedForAllAt,
    this.reactions = const <ChatReaction>[],
    this.deliveryState = MessageDeliveryState.sent,
    this.isOutgoing = false,
    this.replyToId,
    this.encryptedBody,
  });

  final String id;
  final String conversationId;
  final String senderUserId;
  final String senderDeviceId;
  final int? seq;
  final ChatMessageType type;
  final String body;
  final String? clientTempId;
  final String? mediaAssetId;
  final int editVersion;
  final DateTime createdAt;
  final DateTime? deletedForAllAt;
  final List<ChatReaction> reactions;
  final MessageDeliveryState deliveryState;
  final bool isOutgoing;
  final String? replyToId;
  final String? encryptedBody;

  bool get isDeleted =>
      deletedForAllAt != null ||
      (type == ChatMessageType.system && body.isEmpty);

  ChatMessage copyWith({
    String? id,
    int? seq,
    String? body,
    ChatMessageType? type,
    String? mediaAssetId,
    int? editVersion,
    DateTime? createdAt,
    DateTime? deletedForAllAt,
    List<ChatReaction>? reactions,
    MessageDeliveryState? deliveryState,
    bool? isOutgoing,
    String? clientTempId,
    String? replyToId,
    String? encryptedBody,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      conversationId: conversationId,
      senderUserId: senderUserId,
      senderDeviceId: senderDeviceId,
      body: body ?? this.body,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      seq: seq ?? this.seq,
      clientTempId: clientTempId ?? this.clientTempId,
      mediaAssetId: mediaAssetId ?? this.mediaAssetId,
      editVersion: editVersion ?? this.editVersion,
      deletedForAllAt: deletedForAllAt ?? this.deletedForAllAt,
      reactions: reactions ?? this.reactions,
      deliveryState: deliveryState ?? this.deliveryState,
      isOutgoing: isOutgoing ?? this.isOutgoing,
      replyToId: replyToId ?? this.replyToId,
      encryptedBody: encryptedBody ?? this.encryptedBody,
    );
  }

  factory ChatMessage.fromJson(
    Map<String, dynamic> json, {
    String? currentUserId,
  }) {
    final senderId = json['senderUserId']?.toString() ?? '';
    final isOutgoing = currentUserId != null && senderId == currentUserId;
    final deliveredAt = _parseDate(json['deliveredAt']);
    final readAt = _parseDate(json['readAt']);

    MessageDeliveryState deliveryState = MessageDeliveryState.sent;
    if (isOutgoing) {
      if (readAt != null) {
        deliveryState = MessageDeliveryState.read;
      } else if (deliveredAt != null) {
        deliveryState = MessageDeliveryState.delivered;
      }
    }

    final reactions = (json['reactions'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(ChatReaction.fromJson)
        .toList();

    final createdAt = _parseDate(json['createdAt']) ?? DateTime.now();

    return ChatMessage(
      id: json['id']?.toString() ?? '',
      conversationId: json['conversationId']?.toString() ?? '',
      senderUserId: senderId,
      senderDeviceId: json['senderDeviceId']?.toString() ?? '',
      seq: _parseInt(json['seq']),
      type: _parseContentType(json['contentType']?.toString()),
      body: json['body']?.toString() ?? '',
      clientTempId: json['clientTempId']?.toString(),
      mediaAssetId: json['mediaAssetId']?.toString(),
      editVersion: _parseInt(json['editVersion']) ?? 0,
      createdAt: createdAt,
      deletedForAllAt: _parseDate(json['deletedForAllAt']),
      reactions: reactions,
      deliveryState: deliveryState,
      isOutgoing: isOutgoing,
      encryptedBody: null,
    );
  }

  factory ChatMessage.localText({
    required String tempId,
    required String conversationId,
    required String senderUserId,
    required String senderDeviceId,
    required String body,
  }) {
    return ChatMessage(
      id: tempId,
      conversationId: conversationId,
      senderUserId: senderUserId,
      senderDeviceId: senderDeviceId,
      body: body,
      type: ChatMessageType.text,
      createdAt: DateTime.now(),
      clientTempId: tempId,
      deliveryState: MessageDeliveryState.sending,
      isOutgoing: true,
      encryptedBody: null,
    );
  }
}

class ConversationMember {
  ConversationMember({
    required this.userId,
    required this.role,
    required this.joinedAt,
    required this.leftAt,
  });

  final String userId;
  final String role;
  final DateTime? joinedAt;
  final DateTime? leftAt;

  factory ConversationMember.fromJson(Map<String, dynamic> json) {
    return ConversationMember(
      userId: json['userId']?.toString() ?? '',
      role: json['role']?.toString() ?? '',
      joinedAt: _parseDate(json['joinedAt']),
      leftAt: _parseDate(json['leftAt']),
    );
  }
}

class ConversationSummary {
  ConversationSummary({
    required this.id,
    required this.type,
    required this.title,
    required this.lastMessageBody,
    required this.unreadCount,
    required this.lastMessageSenderUserId,
    required this.lastMessageAt,
    required this.updatedAt,
    this.lastMessageId,
    this.lastMessageSeq,
    this.lastMessageType,
    this.lastMessageEditVersion,
    this.lastMessageDeletedForAllAt,
  });

  final String id;
  final String type;
  final String title;
  final String lastMessageBody;
  final int unreadCount;
  final String? lastMessageSenderUserId;
  final DateTime? lastMessageAt;
  final DateTime? updatedAt;
  final String? lastMessageId;
  final int? lastMessageSeq;
  final ChatMessageType? lastMessageType;
  final int? lastMessageEditVersion;
  final DateTime? lastMessageDeletedForAllAt;

  factory ConversationSummary.fromJson(Map<String, dynamic> json) {
    return ConversationSummary(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Conversation',
      lastMessageBody: json['lastMessageBody']?.toString() ?? '',
      unreadCount: json['unreadCount'] is int
          ? json['unreadCount'] as int
          : int.tryParse(json['unreadCount']?.toString() ?? '') ?? 0,
      lastMessageSenderUserId:
          json['lastMessageSenderUserId']?.toString(),
      lastMessageAt: DateTime.tryParse(
        json['lastMessageCreatedAt']?.toString() ?? '',
      ),
      updatedAt:
          DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
      lastMessageId: json['lastMessageId']?.toString(),
      lastMessageSeq: _parseInt(json['lastMessageSeq']),
      lastMessageType: json['lastMessageContentType'] != null
          ? _parseContentType(
              json['lastMessageContentType']?.toString(),
            )
          : null,
      lastMessageEditVersion: _parseInt(json['lastMessageEditVersion']),
      lastMessageDeletedForAllAt:
          _parseDate(json['lastMessageDeletedForAllAt']),
    );
  }
}

class ChatService {
  ChatService({SecureStore? store})
      : _deviceIdStore = DeviceIdStore(store ?? SecureStore()),
        _client = ApiClient(store ?? SecureStore());

  final DeviceIdStore _deviceIdStore;
  final ApiClient _client;

  Future<List<ConversationSummary>> listConversations() async {
    final data = await _client.get('/conversations', auth: true);
    if (data is! List) return [];

    return data
        .whereType<Map<String, dynamic>>()
        .map(ConversationSummary.fromJson)
        .toList();
  }

  Future<List<ChatMessage>> listMessages({
    required String conversationId,
    int? limit,
    int? beforeSeq,
    String? currentUserId,
  }) async {
    final query = <String, String>{};
    if (limit != null) query['limit'] = limit.toString();
    if (beforeSeq != null) query['beforeSeq'] = beforeSeq.toString();

    final data = await _client.get(
      '/conversations/$conversationId/messages',
      auth: true,
      query: query.isEmpty ? null : query,
    );
    if (data is! List) return [];

    return data
        .whereType<Map<String, dynamic>>()
        .map(
          (row) => ChatMessage.fromJson(
            row,
            currentUserId: currentUserId,
          ),
        )
        .toList();
  }

  Future<List<ConversationMember>> listMembers({
    required String conversationId,
  }) async {
    final data = await _client.get(
      '/conversations/$conversationId/members',
      auth: true,
    );
    if (data is! List) return [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(ConversationMember.fromJson)
        .toList();
  }

  Future<ChatMessage?> sendMessage({
    required String conversationId,
    required String body,
    String contentType = 'text',
    String? tempId,
    String? mediaAssetId,
    DateTime? clientTimestamp,
  }) async {
    final deviceId = await _deviceIdStore.getOrCreate();
    final data = await _client.post(
      '/conversations/$conversationId/messages',
      auth: true,
      body: {
        'body': body,
        'deviceId': deviceId,
        'contentType': contentType,
        if (tempId != null) 'tempId': tempId,
        if (mediaAssetId != null) 'mediaAssetId': mediaAssetId,
        if (clientTimestamp != null)
          'clientTimestamp': clientTimestamp.toIso8601String(),
      },
    );

    if (data is Map<String, dynamic>) {
      final message = data['message'];
      if (message is Map<String, dynamic>) {
        return ChatMessage.fromJson(message);
      }
    }
    return null;
  }

  Future<String?> createDm({required String otherUserId}) async {
    final data = await _client.post(
      '/conversations/dm',
      auth: true,
      body: {
        'otherUserId': otherUserId,
      },
    );

    if (data is Map<String, dynamic>) {
      return data['conversationId']?.toString();
    }

    return null;
  }
}
