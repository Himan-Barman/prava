import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../../../ui-system/colors.dart';
import '../../../../ui-system/typography.dart';
import '../../../../ui-system/skeleton/chat_list_skeleton.dart';
import '../../../../navigation/prava_navigator.dart';
import '../../../../ui-system/background.dart';
import '../../../../services/chat_service.dart';
import '../../../../services/chat_realtime.dart';
import '../../../../services/chat_sync_store.dart';
import '../../../../services/e2ee_service.dart';
import '../../../../services/group_e2ee_service.dart';
import '../../../../core/storage/secure_store.dart';
import 'chat_thread_page.dart';

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

class ChatsPage extends StatefulWidget {
  const ChatsPage({super.key});

  @override
  State<ChatsPage> createState() => _ChatsPageState();
}

class _ChatsPageState extends State<ChatsPage> {
  final TextEditingController _searchController = TextEditingController();
  final ChatService _chatService = ChatService();
  final ChatRealtime _realtime = ChatRealtime();
  final SecureStore _store = SecureStore();
  final ChatSyncStore _syncStore = ChatSyncStore();

  List<ChatPreview> _chats = [];
  bool _loading = true;
  String? _userId;
  final Map<String, Set<String>> _onlineByConversation = {};
  final Map<String, Timer> _typingTimers = {};

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChange);
    _bootstrap();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChange);
    _searchController.dispose();
    for (final timer in _typingTimers.values) {
      timer.cancel();
    }
    _typingTimers.clear();
    _realtime.disconnect();
    super.dispose();
  }

  void _onSearchChange() {
    if (mounted) setState(() {});
  }

  Future<void> _bootstrap() async {
    _userId = await _store.getUserId();
    await _loadChats();
    await _realtime.connect(_handleRealtimeEvent);
    await _syncInit();
  }

  Future<void> _loadChats({bool showLoading = true}) async {
    if (showLoading) {
      setState(() => _loading = true);
    }

    try {
      final data = await _chatService.listConversations();
      if (!mounted) return;

      setState(() {
        _chats = data.map(_mapConversation).toList();
        _loading = false;
      });

      for (final convo in data) {
        final seq = convo.lastMessageSeq;
        if (seq != null && seq > 0) {
          _syncStore.updateLastDeliveredSeq(convo.id, seq);
        }
      }
      if (_realtime.isConnected) {
        _syncInit();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _syncInit() async {
    if (!_realtime.isConnected) return;
    final state = await _syncStore.getLastDeliveredMap();
    final payload = _chats
        .map((chat) => {
              'conversationId': chat.id,
              'lastDeliveredSeq':
                  state[chat.id] ?? chat.lastMessageSeq ?? 0,
            })
        .toList();
    if (payload.isEmpty) return;
    _realtime.syncInit(payload);
  }

  ChatPreview _mapConversation(ConversationSummary convo) {
    final isGroup = convo.type == 'group';
    final title = convo.title.trim();
    final name =
        title.isNotEmpty ? title : (isGroup ? 'Group chat' : 'Conversation');

    final lastBody = convo.lastMessageBody.trim();
    final lastType = convo.lastMessageType;
    final isDeleted = convo.lastMessageDeletedForAllAt != null;
    final isEncrypted = _isEncryptedPayload(lastBody);
    final lastMessage = isDeleted
        ? 'Message deleted'
        : (lastType == ChatMessageType.media
            ? 'Media message'
            : (isEncrypted
                ? 'Encrypted message'
                : (lastBody.isNotEmpty
                    ? lastBody
                    : 'No messages yet')));

    final lastMessageFromMe =
        _userId != null && convo.lastMessageSenderUserId == _userId;

    final time =
        _formatChatTime(convo.lastMessageAt ?? convo.updatedAt);

    final onlineSet = _onlineByConversation[convo.id];

    return ChatPreview(
      id: convo.id,
      name: name,
      lastMessage: lastMessage,
      time: time,
      unreadCount: convo.unreadCount,
      isGroup: isGroup,
      isOnline: onlineSet != null && onlineSet.isNotEmpty,
      isMuted: false,
      isPinned: false,
      isTyping: _typingTimers.containsKey(convo.id),
      lastMessageFromMe: lastMessageFromMe,
      delivery: lastMessageFromMe
          ? MessageDeliveryState.sent
          : MessageDeliveryState.read,
      lastMessageId: convo.lastMessageId,
      lastMessageSeq: convo.lastMessageSeq,
      lastMessageType: convo.lastMessageType,
      lastMessageDeletedForAllAt: convo.lastMessageDeletedForAllAt,
    );
  }

  void _handleRealtimeEvent(Map<String, dynamic> event) {
    final type = event['type']?.toString();
    final payload = event['payload'];
    if (type == null || payload is! Map<String, dynamic>) return;

    switch (type) {
      case 'MESSAGE_PUSH':
        _handleMessagePush(payload);
        break;
      case 'MESSAGE_ACK':
        _handleMessageAck(payload);
        break;
      case 'READ_UPDATE':
        _handleReadUpdate(payload);
        break;
      case 'DELIVERY_UPDATE':
        _handleDeliveryUpdate(payload);
        break;
      case 'MESSAGE_EDIT':
        _handleMessageEdit(payload);
        break;
      case 'MESSAGE_DELETE':
        _handleMessageDelete(payload);
        break;
      case 'PRESENCE_UPDATE':
        _handlePresence(payload);
        break;
      case 'TYPING':
        _handleTyping(payload);
        break;
      default:
        break;
    }
  }

  void _handlePresence(Map<String, dynamic> payload) {
    final conversationId = payload['conversationId']?.toString();
    final userId = payload['userId']?.toString();
    final isOnline = payload['isOnline'] == true;

    if (conversationId == null || userId == null) return;
    if (userId == _userId) return;

    final set =
        _onlineByConversation.putIfAbsent(conversationId, () => <String>{});

    if (isOnline) {
      set.add(userId);
    } else {
      set.remove(userId);
    }

    _updateChat(
      conversationId,
      (chat) => chat.copyWith(isOnline: set.isNotEmpty),
    );
  }

  void _handleTyping(Map<String, dynamic> payload) {
    final conversationId = payload['conversationId']?.toString();
    final userId = payload['userId']?.toString();
    final isTyping = payload['isTyping'] == true;

    if (conversationId == null || userId == null) return;
    if (userId == _userId) return;

    if (isTyping) {
      _setTyping(conversationId, true);
      _typingTimers[conversationId]?.cancel();
      _typingTimers[conversationId] = Timer(
        const Duration(seconds: 4),
        () => _setTyping(conversationId, false),
      );
    } else {
      _typingTimers[conversationId]?.cancel();
      _typingTimers.remove(conversationId);
      _setTyping(conversationId, false);
    }
  }

  void _handleMessagePush(Map<String, dynamic> payload) {
    final conversationId = payload['conversationId']?.toString();
    if (conversationId == null) return;

    final senderUserId = payload['senderUserId']?.toString();
    final isFromMe = senderUserId != null && senderUserId == _userId;
    final body = payload['body']?.toString() ?? '';
    final contentType = payload['contentType']?.toString();
    final deletedForAllAt = _parseDate(payload['deletedForAllAt']);
    final createdAt = _parseDate(payload['createdAt']) ?? DateTime.now();
    final messageId = payload['messageId']?.toString();
    final seq = _parseInt(payload['seq']);

    final preview = _formatPreviewText(
      body: body,
      contentType: contentType,
      isDeleted: deletedForAllAt != null,
    );

    if (seq != null && seq > 0) {
      _syncStore.updateLastDeliveredSeq(conversationId, seq);
    }

    _updateChat(
      conversationId,
      (chat) => chat.copyWith(
        lastMessage: preview,
        time: _formatChatTime(createdAt),
        unreadCount: isFromMe ? chat.unreadCount : chat.unreadCount + 1,
        lastMessageFromMe: isFromMe,
        delivery: isFromMe ? MessageDeliveryState.sent : chat.delivery,
        lastMessageId: messageId ?? chat.lastMessageId,
        lastMessageSeq: seq ?? chat.lastMessageSeq,
        lastMessageType:
            contentType != null ? _parseContentType(contentType) : chat.lastMessageType,
        lastMessageDeletedForAllAt:
            deletedForAllAt ?? chat.lastMessageDeletedForAllAt,
      ),
    );
    _bumpChatToTop(conversationId);
  }

  void _handleMessageAck(Map<String, dynamic> payload) {
    final conversationId = payload['conversationId']?.toString();
    if (conversationId == null) return;

    final messageId = payload['messageId']?.toString();
    final seq = _parseInt(payload['seq']);
    final createdAt = _parseDate(payload['createdAt']);

    if (seq != null && seq > 0) {
      _syncStore.updateLastDeliveredSeq(conversationId, seq);
    }

    _updateChat(
      conversationId,
      (chat) => chat.copyWith(
        lastMessageId: messageId ?? chat.lastMessageId,
        lastMessageSeq: seq ?? chat.lastMessageSeq,
        time: createdAt != null ? _formatChatTime(createdAt) : chat.time,
        lastMessageFromMe: true,
        delivery: MessageDeliveryState.sent,
      ),
    );
  }

  void _handleReadUpdate(Map<String, dynamic> payload) {
    final conversationId = payload['conversationId']?.toString();
    final lastReadSeq = _parseInt(payload['lastReadSeq']);
    if (conversationId == null || lastReadSeq == null) return;

    _updateChat(conversationId, (chat) {
      if (!chat.lastMessageFromMe) return chat;
      if (chat.lastMessageSeq != null &&
          lastReadSeq >= chat.lastMessageSeq!) {
        return chat.copyWith(delivery: MessageDeliveryState.read);
      }
      return chat;
    });
  }

  void _handleDeliveryUpdate(Map<String, dynamic> payload) {
    final conversationId = payload['conversationId']?.toString();
    final lastDeliveredSeq = _parseInt(payload['lastDeliveredSeq']);
    if (conversationId == null || lastDeliveredSeq == null) return;

    _updateChat(conversationId, (chat) {
      if (!chat.lastMessageFromMe) return chat;
      if (chat.lastMessageSeq != null &&
          lastDeliveredSeq >= chat.lastMessageSeq!) {
        return chat.copyWith(delivery: MessageDeliveryState.delivered);
      }
      return chat;
    });
  }

  void _handleMessageEdit(Map<String, dynamic> payload) {
    final conversationId = payload['conversationId']?.toString();
    final messageId = payload['messageId']?.toString();
    final body = payload['body']?.toString() ?? '';
    if (conversationId == null || messageId == null) return;

    _updateChat(conversationId, (chat) {
      if (chat.lastMessageId != messageId) return chat;
      return chat.copyWith(
        lastMessage: _formatPreviewText(
          body: body,
          contentType: 'text',
          isDeleted: false,
        ),
      );
    });
  }

  void _handleMessageDelete(Map<String, dynamic> payload) {
    final conversationId = payload['conversationId']?.toString();
    final messageId = payload['messageId']?.toString();
    final deletedForAllAt = _parseDate(payload['deletedForAllAt']);
    if (conversationId == null || messageId == null) return;

    _updateChat(conversationId, (chat) {
      if (chat.lastMessageId != messageId) return chat;
      return chat.copyWith(
        lastMessage: 'Message deleted',
        lastMessageDeletedForAllAt:
            deletedForAllAt ?? chat.lastMessageDeletedForAllAt,
      );
    });
  }

  String _formatPreviewText({
    required String body,
    required String? contentType,
    required bool isDeleted,
  }) {
    if (isDeleted) return 'Message deleted';
    if (contentType == 'media') return 'Media message';
    if (_isEncryptedPayload(body)) return 'Encrypted message';
    final trimmed = body.trim();
    return trimmed.isEmpty ? 'New message' : trimmed;
  }

  bool _isEncryptedPayload(String body) {
    return E2eeService.isEncrypted(body) ||
        GroupE2eeService.isGroupEncrypted(body);
  }

  void _bumpChatToTop(String conversationId) {
    final index = _chats.indexWhere((chat) => chat.id == conversationId);
    if (index <= 0) return;
    if (!mounted) return;

    setState(() {
      final updated = _chats[index];
      _chats = List<ChatPreview>.from(_chats);
      _chats.removeAt(index);
      _chats.insert(0, updated);
    });
  }

  void _setTyping(String conversationId, bool isTyping) {
    _updateChat(
      conversationId,
      (chat) => chat.copyWith(isTyping: isTyping),
    );
  }

  void _updateChat(
    String conversationId,
    ChatPreview Function(ChatPreview) update,
  ) {
    final index = _chats.indexWhere((chat) => chat.id == conversationId);
    if (index == -1) return;

    final updated = update(_chats[index]);
    if (!mounted) return;

    setState(() {
      _chats = List<ChatPreview>.from(_chats);
      _chats[index] = updated;
    });
  }

  String _formatChatTime(DateTime? date) {
    if (date == null) return 'New';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final diffDays = today.difference(target).inDays;

    if (diffDays == 0) {
      final hour = date.hour;
      final minute = date.minute.toString().padLeft(2, '0');
      final suffix = hour >= 12 ? 'PM' : 'AM';
      final hour12 = hour % 12 == 0 ? 12 : hour % 12;
      return '$hour12:$minute $suffix';
    }

    if (diffDays == 1) return 'Yesterday';
    if (diffDays < 7) return _weekdayLabel(date.weekday);

    return '${date.month}/${date.day}/${date.year}';
  }

  String _weekdayLabel(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Mon';
      case DateTime.tuesday:
        return 'Tue';
      case DateTime.wednesday:
        return 'Wed';
      case DateTime.thursday:
        return 'Thu';
      case DateTime.friday:
        return 'Fri';
      case DateTime.saturday:
        return 'Sat';
      case DateTime.sunday:
        return 'Sun';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary =
        isDark ? PravaColors.darkTextPrimary : PravaColors.lightTextPrimary;
    final secondary =
        isDark ? PravaColors.darkTextSecondary : PravaColors.lightTextSecondary;
    final border =
        isDark ? PravaColors.darkBorderSubtle : PravaColors.lightBorderSubtle;
    final query = _searchController.text.trim().toLowerCase();
    final visibleChats = query.isEmpty
        ? _chats
        : _chats
            .where(
              (chat) =>
                  chat.name.toLowerCase().contains(query) ||
                  chat.lastMessage.toLowerCase().contains(query),
            )
            .toList();

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Stack(
        children: [
          _ChatsBackground(isDark: isDark),
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                child: Row(
                  children: [
                    Text(
                      'Chats',
                      style: PravaTypography.h2.copyWith(
                        color: primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    _HeaderPill(
                      label: 'New',
                      icon: CupertinoIcons.square_pencil,
                      onTap: () => HapticFeedback.selectionClick(),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white10
                            : Colors.white.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: border),
                      ),
                      child: CupertinoSearchTextField(
                        controller: _searchController,
                        placeholder: 'Search chats',
                        backgroundColor: Colors.transparent,
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Row(
                  children: const [
                    _QuickAction(
                      icon: CupertinoIcons.person_2,
                      label: 'New group',
                    ),
                    SizedBox(width: 10),
                    _QuickAction(
                      icon: CupertinoIcons.speaker_2,
                      label: 'Broadcast',
                    ),
                    SizedBox(width: 10),
                    _QuickAction(
                      icon: CupertinoIcons.star,
                      label: 'Starred',
                    ),
                  ],
                ),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: _loading
                      ? const ChatListSkeleton()
                      : RefreshIndicator(
                          onRefresh: () =>
                              _loadChats(showLoading: false),
                          color: PravaColors.accentPrimary,
                          child: visibleChats.isEmpty
                              ? _EmptyChatsState(
                                  hasQuery: query.isNotEmpty,
                                )
                              : ListView.separated(
                                  padding:
                                      const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                  physics: const BouncingScrollPhysics(
                                    parent: AlwaysScrollableScrollPhysics(),
                                  ),
                                  itemCount: visibleChats.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 12),
                                  itemBuilder: (context, index) {
                                    final chat = visibleChats[index];
                                    return _ChatTile(
                                      chat: chat,
                                      onTap: () {
                                        HapticFeedback.selectionClick();
                                        _updateChat(
                                          chat.id,
                                          (current) =>
                                              current.copyWith(unreadCount: 0),
                                        );
                                        PravaNavigator.push(
                                          context,
                                          ChatThreadPage(chat: chat),
                                        ).then((_) {
                                          _loadChats(showLoading: false);
                                        });
                                      },
                                    );
                                  },
                                ),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderPill extends StatelessWidget {
  const _HeaderPill({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              PravaColors.accentPrimary,
              PravaColors.accentMuted,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: PravaColors.accentPrimary.withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              label,
              style: PravaTypography.caption.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface =
        isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06);
    final secondary =
        isDark ? PravaColors.darkTextSecondary : PravaColors.lightTextSecondary;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: PravaColors.accentPrimary),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: PravaTypography.caption.copyWith(
                  color: secondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatsBackground extends StatelessWidget {
  const _ChatsBackground({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return PravaBackground(isDark: isDark);
  }
}

class _ChatTile extends StatelessWidget {
  const _ChatTile({required this.chat, required this.onTap});

  final ChatPreview chat;
  final VoidCallback onTap;

  Color _avatarColor(String name) {
    const palette = [
      Color(0xFF5B8CFF),
      Color(0xFF2EC4B6),
      Color(0xFFFFB703),
      Color(0xFFFF6B6B),
      Color(0xFF845EC2),
    ];

    final hash = name.codeUnits.fold(0, (acc, c) => acc + c);
    return palette[hash % palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary =
        isDark ? PravaColors.darkTextPrimary : PravaColors.lightTextPrimary;
    final secondary =
        isDark ? PravaColors.darkTextSecondary : PravaColors.lightTextSecondary;
    final border =
        isDark ? PravaColors.darkBorderSubtle : PravaColors.lightBorderSubtle;

    final isUnread = chat.unreadCount > 0;
    final baseColor = isDark
        ? (isUnread ? Colors.white12 : Colors.white10)
        : (isUnread ? Colors.white : Colors.white.withValues(alpha: 0.9));
    final accent = _avatarColor(chat.name);

    final previewStyle = chat.isTyping
        ? PravaTypography.caption.copyWith(
            color: PravaColors.accentPrimary,
            fontWeight: FontWeight.w600,
          )
        : PravaTypography.caption.copyWith(color: secondary);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: baseColor,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isUnread
                  ? PravaColors.accentPrimary.withValues(alpha: 0.35)
                  : border,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
                blurRadius: 16,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: accent.withValues(alpha: 0.18),
                      child: chat.isGroup
                          ? Icon(
                              CupertinoIcons.person_2_fill,
                              color: accent,
                            )
                          : Text(
                              chat.name[0].toUpperCase(),
                              style: PravaTypography.h3.copyWith(
                                color: accent,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                    if (chat.isOnline && !chat.isGroup)
                      Positioned(
                        right: 2,
                        bottom: 2,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: PravaColors.success,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: baseColor,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              chat.name,
                              style: PravaTypography.body.copyWith(
                                color: primary,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (chat.isPinned)
                            Icon(
                              CupertinoIcons.pin_fill,
                              size: 14,
                              color: PravaColors.accentPrimary,
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (chat.lastMessageFromMe)
                            Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: _DeliveryIcon(
                                state: chat.delivery,
                              ),
                            ),
                          Expanded(
                            child: Text(
                              chat.isTyping ? 'typing...' : chat.lastMessage,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: previewStyle,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      chat.time,
                      style: PravaTypography.caption.copyWith(
                        color: isUnread
                            ? PravaColors.accentPrimary
                            : secondary,
                        fontWeight:
                            isUnread ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (isUnread)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: PravaColors.accentPrimary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          chat.unreadCount.toString(),
                          style: PravaTypography.caption.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    else if (chat.isMuted)
                      Icon(
                        CupertinoIcons.bell_slash_fill,
                        size: 16,
                        color: secondary,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DeliveryIcon extends StatelessWidget {
  const _DeliveryIcon({required this.state});

  final MessageDeliveryState state;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? Colors.white54 : Colors.black45;

    switch (state) {
      case MessageDeliveryState.sending:
        return Icon(CupertinoIcons.clock, size: 14, color: muted);
      case MessageDeliveryState.sent:
        return Icon(Icons.check, size: 14, color: muted);
      case MessageDeliveryState.delivered:
        return Icon(Icons.done_all, size: 14, color: muted);
      case MessageDeliveryState.read:
        return Icon(Icons.done_all, size: 14, color: PravaColors.accentPrimary);
      case MessageDeliveryState.failed:
        return Icon(CupertinoIcons.exclamationmark_circle,
            size: 14, color: PravaColors.error);
    }
  }
}

class ChatPreview {
  final String id;
  final String name;
  final String lastMessage;
  final String time;
  final int unreadCount;
  final bool isGroup;
  final bool isOnline;
  final bool isMuted;
  final bool isPinned;
  final bool isTyping;
  final bool lastMessageFromMe;
  final MessageDeliveryState delivery;
  final String? lastMessageId;
  final int? lastMessageSeq;
  final ChatMessageType? lastMessageType;
  final DateTime? lastMessageDeletedForAllAt;

  const ChatPreview({
    required this.id,
    required this.name,
    required this.lastMessage,
    required this.time,
    required this.unreadCount,
    required this.isGroup,
    required this.isOnline,
    required this.isMuted,
    required this.isPinned,
    required this.isTyping,
    required this.lastMessageFromMe,
    required this.delivery,
    this.lastMessageId,
    this.lastMessageSeq,
    this.lastMessageType,
    this.lastMessageDeletedForAllAt,
  });

  ChatPreview copyWith({
    String? name,
    String? lastMessage,
    String? time,
    int? unreadCount,
    bool? isOnline,
    bool? isMuted,
    bool? isPinned,
    bool? isTyping,
    bool? lastMessageFromMe,
    MessageDeliveryState? delivery,
    String? lastMessageId,
    int? lastMessageSeq,
    ChatMessageType? lastMessageType,
    DateTime? lastMessageDeletedForAllAt,
  }) {
    return ChatPreview(
      id: id,
      name: name ?? this.name,
      lastMessage: lastMessage ?? this.lastMessage,
      time: time ?? this.time,
      unreadCount: unreadCount ?? this.unreadCount,
      isGroup: isGroup,
      isOnline: isOnline ?? this.isOnline,
      isMuted: isMuted ?? this.isMuted,
      isPinned: isPinned ?? this.isPinned,
      isTyping: isTyping ?? this.isTyping,
      lastMessageFromMe: lastMessageFromMe ?? this.lastMessageFromMe,
      delivery: delivery ?? this.delivery,
      lastMessageId: lastMessageId ?? this.lastMessageId,
      lastMessageSeq: lastMessageSeq ?? this.lastMessageSeq,
      lastMessageType: lastMessageType ?? this.lastMessageType,
      lastMessageDeletedForAllAt:
          lastMessageDeletedForAllAt ?? this.lastMessageDeletedForAllAt,
    );
  }
}

class _EmptyChatsState extends StatelessWidget {
  const _EmptyChatsState({required this.hasQuery});

  final bool hasQuery;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary =
        isDark ? PravaColors.darkTextPrimary : PravaColors.lightTextPrimary;
    final secondary =
        isDark ? PravaColors.darkTextSecondary : PravaColors.lightTextSecondary;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 80, 16, 16),
      children: [
        Center(
          child: Icon(
            CupertinoIcons.chat_bubble_2,
            size: 40,
            color: secondary,
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            hasQuery ? 'No matches' : 'No chats yet',
            style: PravaTypography.bodyLarge.copyWith(
              color: primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            hasQuery
                ? 'Try another name or message.'
                : 'Start a new conversation to see it here.',
            textAlign: TextAlign.center,
            style: PravaTypography.body.copyWith(color: secondary),
          ),
        ),
      ],
    );
  }
}
