import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../../../ui-system/colors.dart';
import '../../../../ui-system/components/prava_input.dart';
import '../../../../ui-system/typography.dart';
import '../../../../ui-system/skeleton/chat_list_skeleton.dart';
import '../../../../navigation/prava_navigator.dart';
import '../../../../ui-system/background.dart';
import '../../../../services/chat_service.dart';
import '../../../../services/chat_realtime.dart';
import '../../../../services/chat_sync_store.dart';
import '../../../../services/e2ee_service.dart';
import '../../../../services/group_e2ee_service.dart';
import '../../../../services/privacy_service.dart';
import '../../../../core/storage/secure_store.dart';
import 'chat_thread_page.dart';
import '../../pages/new_group_page.dart';
import '../profile/public_profile_page.dart';
import 'message_requests_page.dart';

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
    case 'image':
    case 'video':
    case 'file':
    case 'audio':
    case 'voice_note':
      return ChatMessageType.media;
    case 'text':
    default:
      return ChatMessageType.text;
  }
}

enum _ChatListFilter {
  all,
  unread,
  direct,
  favoriteGroups,
  groups,
  starred,
  archived,
  broadcasts,
}

class ChatsPageController {
  VoidCallback? _openNewGroup;
  VoidCallback? _openMessageRequests;
  VoidCallback? _showBroadcasts;
  VoidCallback? _showStarred;

  void openNewGroup() => _openNewGroup?.call();
  void openMessageRequests() => _openMessageRequests?.call();
  void showBroadcasts() => _showBroadcasts?.call();
  void showStarred() => _showStarred?.call();

  void _bind({
    required VoidCallback openNewGroup,
    required VoidCallback openMessageRequests,
    required VoidCallback showBroadcasts,
    required VoidCallback showStarred,
  }) {
    _openNewGroup = openNewGroup;
    _openMessageRequests = openMessageRequests;
    _showBroadcasts = showBroadcasts;
    _showStarred = showStarred;
  }

  void _unbind() {
    _openNewGroup = null;
    _openMessageRequests = null;
    _showBroadcasts = null;
    _showStarred = null;
  }
}

class ChatsPage extends StatefulWidget {
  const ChatsPage({super.key, this.controller});

  final ChatsPageController? controller;

  @override
  State<ChatsPage> createState() => _ChatsPageState();
}

class _ChatsPageState extends State<ChatsPage> {
  final TextEditingController _searchController = TextEditingController();
  final ChatService _chatService = ChatService();
  final ChatRealtime _realtime = ChatRealtime();
  final SecureStore _store = SecureStore();
  final ChatSyncStore _syncStore = ChatSyncStore();
  final PrivacyService _privacyService = PrivacyService();

  List<ChatPreview> _chats = [];
  bool _loading = true;
  String? _userId;
  _ChatListFilter _filter = _ChatListFilter.all;
  final Map<String, Set<String>> _onlineByConversation = {};
  final Map<String, Timer> _typingTimers = {};

  @override
  void initState() {
    super.initState();
    _bindController(widget.controller);
    _searchController.addListener(_onSearchChange);
    _bootstrap();
  }

  @override
  void didUpdateWidget(covariant ChatsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._unbind();
      _bindController(widget.controller);
    }
  }

  @override
  void dispose() {
    widget.controller?._unbind();
    _searchController.removeListener(_onSearchChange);
    _searchController.dispose();
    for (final timer in _typingTimers.values) {
      timer.cancel();
    }
    _typingTimers.clear();
    _realtime.disconnect();
    super.dispose();
  }

  void _bindController(ChatsPageController? controller) {
    controller?._bind(
      openNewGroup: () {
        _openNewGroup();
      },
      openMessageRequests: () {
        _openMessageRequests();
      },
      showBroadcasts: _showBroadcasts,
      showStarred: _showStarred,
    );
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
      final data = await _chatService.listConversations(includeArchived: true);
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
        .map(
          (chat) => {
            'conversationId': chat.id,
            'lastDeliveredSeq': state[chat.id] ?? chat.lastMessageSeq ?? 0,
          },
        )
        .toList();
    if (payload.isEmpty) return;
    _realtime.syncInit(payload);
  }

  ChatPreview _mapConversation(ConversationSummary convo) {
    final isGroup = convo.type == 'group';
    final title = convo.title.trim();
    final name = title.isNotEmpty
        ? title
        : (isGroup ? 'Group chat' : 'Conversation');

    final lastBody = convo.lastMessageBody.trim();
    final lastType = convo.lastMessageType;
    final isDeleted = convo.lastMessageDeletedForAllAt != null;
    final isEncrypted = _isEncryptedPayload(lastBody);
    final draftText = convo.draftText.trim();
    final lastMessage = draftText.isNotEmpty
        ? 'Draft: $draftText'
        : isDeleted
        ? 'Message deleted'
        : (lastType == ChatMessageType.media
              ? 'Media message'
              : (isEncrypted
                    ? 'Encrypted message'
                    : (lastBody.isNotEmpty ? lastBody : 'No messages yet')));

    final lastMessageFromMe =
        _userId != null && convo.lastMessageSenderUserId == _userId;

    final time = _formatChatTime(convo.lastMessageAt ?? convo.updatedAt);

    final onlineSet = _onlineByConversation[convo.id];

    return ChatPreview(
      id: convo.id,
      name: name,
      lastMessage: lastMessage,
      time: time,
      unreadCount: convo.unreadCount,
      isGroup: isGroup,
      isOnline: onlineSet != null && onlineSet.isNotEmpty,
      isMuted: convo.isMuted,
      isPinned: convo.isStarred,
      isFavorite: convo.isFavorite,
      isStarred: convo.isStarred,
      isArchived: convo.isArchived,
      draftText: draftText,
      isTyping: _typingTimers.containsKey(convo.id),
      peerUserId: convo.peerUserId,
      avatarUrl: convo.peerAvatarUrl,
      peerLastSeenAt: convo.peerLastSeenAt,
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

  Future<void> _openNewGroup() async {
    final created = await PravaNavigator.push(context, const NewGroupPage());
    if (created != null) {
      _loadChats(showLoading: false);
    }
  }

  Future<void> _openMessageRequests() async {
    final changed = await PravaNavigator.push(
      context,
      const MessageRequestsPage(),
    );
    if (changed == true) {
      _loadChats(showLoading: false);
    }
  }

  void _showBroadcasts() {
    if (!mounted) return;
    setState(() => _filter = _ChatListFilter.broadcasts);
  }

  void _showStarred() {
    if (!mounted) return;
    setState(() => _filter = _ChatListFilter.starred);
  }

  String _filterEmptyTitle() {
    switch (_filter) {
      case _ChatListFilter.all:
        return 'No chats yet';
      case _ChatListFilter.unread:
        return 'No unread chats';
      case _ChatListFilter.direct:
        return 'No friend chats';
      case _ChatListFilter.favoriteGroups:
        return 'No favourite groups';
      case _ChatListFilter.groups:
        return 'No groups yet';
      case _ChatListFilter.starred:
        return 'No starred chats';
      case _ChatListFilter.archived:
        return 'No archived chats';
      case _ChatListFilter.broadcasts:
        return 'No broadcasts';
    }
  }

  String _filterEmptySubtitle() {
    switch (_filter) {
      case _ChatListFilter.all:
        return 'Start a new conversation to see it here.';
      case _ChatListFilter.unread:
        return 'Unread messages will appear here.';
      case _ChatListFilter.direct:
        return 'One-to-one friend chats will appear here.';
      case _ChatListFilter.favoriteGroups:
        return 'Favourite group chats will appear here.';
      case _ChatListFilter.groups:
        return 'Create or join a group to see it here.';
      case _ChatListFilter.starred:
        return 'Starred chats will appear here.';
      case _ChatListFilter.archived:
        return 'Archived chats will appear here.';
      case _ChatListFilter.broadcasts:
        return 'Broadcast lists will appear here.';
    }
  }

  List<ChatPreview> _applyFilter(List<ChatPreview> chats) {
    final activeChats = chats.where((chat) => !chat.isArchived).toList();
    switch (_filter) {
      case _ChatListFilter.all:
        return activeChats;
      case _ChatListFilter.unread:
        return activeChats.where((chat) => chat.unreadCount > 0).toList();
      case _ChatListFilter.direct:
        return activeChats.where((chat) => !chat.isGroup).toList();
      case _ChatListFilter.favoriteGroups:
        return activeChats
            .where((chat) => chat.isGroup && chat.isFavorite)
            .toList();
      case _ChatListFilter.groups:
        return activeChats.where((chat) => chat.isGroup).toList();
      case _ChatListFilter.starred:
        return activeChats.where((chat) => chat.isStarred).toList();
      case _ChatListFilter.archived:
        return chats.where((chat) => chat.isArchived).toList();
      case _ChatListFilter.broadcasts:
        return <ChatPreview>[];
    }
  }

  void _handleRealtimeEvent(Map<String, dynamic> event) {
    final type = event['type']?.toString();
    final payload = event['payload'];
    if (type == null || payload is! Map<String, dynamic>) return;

    switch (type) {
      case 'MESSAGE_PUSH':
        _handleMessagePush(payload);
        break;
      case 'MESSAGE_REQUEST_ACCEPTED':
        _loadChats(showLoading: false);
        break;
      case 'MESSAGE_REQUEST_DECLINED':
        _handleMessageRequestDeclined(payload);
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

    final set = _onlineByConversation.putIfAbsent(
      conversationId,
      () => <String>{},
    );

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

    final knownConversation = _chats.any((chat) => chat.id == conversationId);
    if (!knownConversation) {
      _loadChats(showLoading: false);
      return;
    }

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
        lastMessageType: contentType != null
            ? _parseContentType(contentType)
            : chat.lastMessageType,
        lastMessageDeletedForAllAt:
            deletedForAllAt ?? chat.lastMessageDeletedForAllAt,
      ),
    );
    _bumpChatToTop(conversationId);
  }

  void _handleMessageRequestDeclined(Map<String, dynamic> payload) {
    final conversationId = payload['conversationId']?.toString();
    if (conversationId == null) return;

    if (!mounted) return;
    setState(() {
      _chats = _chats.where((chat) => chat.id != conversationId).toList();
    });
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
      if (chat.lastMessageSeq != null && lastReadSeq >= chat.lastMessageSeq!) {
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
    _updateChat(conversationId, (chat) => chat.copyWith(isTyping: isTyping));
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

  Future<void> _updateChatPreferences(
    ChatPreview chat, {
    bool? isFavorite,
    bool? isStarred,
    bool? isMuted,
    bool? isArchived,
  }) async {
    final nextFavorite = isFavorite ?? chat.isFavorite;
    final nextStarred = isStarred ?? chat.isStarred;
    final nextMuted = isMuted ?? chat.isMuted;
    final nextArchived = isArchived ?? chat.isArchived;

    _updateChat(
      chat.id,
      (current) => current.copyWith(
        isFavorite: nextFavorite,
        isStarred: nextStarred,
        isPinned: nextStarred,
        isMuted: nextMuted,
        isArchived: nextArchived,
      ),
    );

    final ok = await _chatService.updatePreferences(
      conversationId: chat.id,
      isFavorite: nextFavorite,
      isStarred: nextStarred,
      isMuted: nextMuted,
      isArchived: nextArchived,
    );
    if (!ok && mounted) {
      _updateChat(
        chat.id,
        (current) => current.copyWith(
          isFavorite: chat.isFavorite,
          isStarred: chat.isStarred,
          isPinned: chat.isPinned,
          isMuted: chat.isMuted,
          isArchived: chat.isArchived,
        ),
      );
    }
  }

  Future<void> _setArchived(ChatPreview chat, bool archived) async {
    final previous = List<ChatPreview>.from(_chats);
    setState(() {
      _chats = _chats
          .map(
            (item) =>
                item.id == chat.id ? item.copyWith(isArchived: archived) : item,
          )
          .toList();
    });

    final ok = await _chatService.updatePreferences(
      conversationId: chat.id,
      isFavorite: chat.isFavorite,
      isStarred: chat.isStarred,
      isMuted: chat.isMuted,
      isArchived: archived,
    );
    if (!ok && mounted) {
      setState(() => _chats = previous);
    }
  }

  Future<bool> _confirmChatAction({
    required String title,
    required String message,
    required String action,
    bool destructive = false,
  }) async {
    final result = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: destructive,
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(action),
          ),
        ],
      ),
    );
    return result == true;
  }

  void _showChatSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _markChatRead(ChatPreview chat) async {
    final lastSeq = chat.lastMessageSeq;
    if (lastSeq == null || lastSeq <= 0) {
      _updateChat(chat.id, (current) => current.copyWith(unreadCount: 0));
      return;
    }
    final previous = chat.unreadCount;
    _updateChat(chat.id, (current) => current.copyWith(unreadCount: 0));
    final ok = await _chatService.markRead(
      conversationId: chat.id,
      lastReadSeq: lastSeq,
    );
    if (!ok && mounted) {
      _updateChat(
        chat.id,
        (current) => current.copyWith(unreadCount: previous),
      );
      _showChatSnack('Could not mark chat read');
    }
  }

  Future<void> _markChatUnread(ChatPreview chat) async {
    final previous = chat.unreadCount;
    _updateChat(chat.id, (current) => current.copyWith(unreadCount: 1));
    final ok = await _chatService.markUnread(chat.id);
    if (!ok && mounted) {
      _updateChat(
        chat.id,
        (current) => current.copyWith(unreadCount: previous),
      );
      _showChatSnack('Could not mark chat unread');
    }
  }

  Future<void> _clearChat(ChatPreview chat) async {
    final confirmed = await _confirmChatAction(
      title: 'Clear chat?',
      message: 'Messages will be cleared on this device.',
      action: 'Clear',
      destructive: true,
    );
    if (!confirmed) return;
    final ok = await _chatService.clearLocalConversation(chat.id);
    if (ok) {
      _loadChats(showLoading: false);
      _showChatSnack('Chat cleared');
    } else {
      _showChatSnack('Could not clear chat');
    }
  }

  Future<void> _deleteChat(ChatPreview chat) async {
    final confirmed = await _confirmChatAction(
      title: 'Delete chat?',
      message: 'This removes the conversation from your chat list.',
      action: 'Delete',
      destructive: true,
    );
    if (!confirmed) return;
    final ok = await _chatService.deleteConversationLocal(chat.id);
    if (ok) {
      setState(
        () => _chats = _chats.where((item) => item.id != chat.id).toList(),
      );
      _showChatSnack('Chat deleted');
    } else {
      _showChatSnack('Could not delete chat');
    }
  }

  void _openChatProfile(ChatPreview chat) {
    final peerId = chat.peerUserId.trim();
    if (chat.isGroup || peerId.isEmpty) return;
    PravaNavigator.push(context, PublicProfilePage(userId: peerId));
  }

  Future<void> _blockChatPeer(ChatPreview chat) async {
    final peerId = chat.peerUserId.trim();
    if (chat.isGroup || peerId.isEmpty) return;
    final confirmed = await _confirmChatAction(
      title: 'Block ${chat.name}?',
      message: 'They will not be able to message or interact with you.',
      action: 'Block',
      destructive: true,
    );
    if (!confirmed) return;
    try {
      await _privacyService.blockUser(peerId);
      setState(
        () => _chats = _chats.where((item) => item.id != chat.id).toList(),
      );
      _showChatSnack('User blocked');
    } catch (_) {
      _showChatSnack('Could not block user');
    }
  }

  Future<void> _reportChat(ChatPreview chat) async {
    final reason = await showCupertinoModalPopup<String>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text('Report ${chat.name}'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(context).pop('spam'),
            child: const Text('Spam'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(context).pop('harassment'),
            child: const Text('Harassment'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(context).pop('scam'),
            child: const Text('Scam or fraud'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(context).pop('other'),
            child: const Text('Other'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
    if (reason == null) return;
    final ok = await _chatService.reportConversation(
      conversationId: chat.id,
      reportedUserId: chat.isGroup ? null : chat.peerUserId,
      reason: reason,
    );
    _showChatSnack(ok ? 'Report sent' : 'Could not send report');
  }

  Future<void> _showChatActions(ChatPreview chat) async {
    HapticFeedback.selectionClick();
    final action = await showCupertinoModalPopup<String>(
      context: context,
      builder: (context) {
        final actions = <CupertinoActionSheetAction>[
          if (!chat.isGroup && chat.peerUserId.trim().isNotEmpty)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.of(context).pop('profile'),
              child: const Text('View profile'),
            ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(context).pop('star'),
            child: Text(chat.isStarred ? 'Unpin chat' : 'Pin chat'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(
              context,
            ).pop(chat.unreadCount > 0 ? 'read' : 'unread'),
            child: Text(
              chat.unreadCount > 0 ? 'Mark as read' : 'Mark as unread',
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(context).pop('mute'),
            child: Text(chat.isMuted ? 'Unmute' : 'Mute'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(context).pop('archive'),
            child: Text(chat.isArchived ? 'Unarchive chat' : 'Archive chat'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(context).pop('clear'),
            isDestructiveAction: true,
            child: const Text('Clear chat'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(context).pop('delete'),
            isDestructiveAction: true,
            child: const Text('Delete chat'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(context).pop('report'),
            isDestructiveAction: true,
            child: const Text('Report'),
          ),
        ];
        if (chat.isGroup) {
          actions.insert(
            2,
            CupertinoActionSheetAction(
              onPressed: () => Navigator.of(context).pop('favorite'),
              child: Text(
                chat.isFavorite
                    ? 'Remove from favourite groups'
                    : 'Add to favourite groups',
              ),
            ),
          );
        } else if (chat.peerUserId.trim().isNotEmpty) {
          actions.add(
            CupertinoActionSheetAction(
              onPressed: () => Navigator.of(context).pop('block'),
              isDestructiveAction: true,
              child: const Text('Block user'),
            ),
          );
        }

        return CupertinoActionSheet(
          title: Text(chat.name),
          actions: actions,
          cancelButton: CupertinoActionSheetAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        );
      },
    );

    if (action == 'profile') {
      _openChatProfile(chat);
    } else if (action == 'star') {
      _updateChatPreferences(chat, isStarred: !chat.isStarred);
    } else if (action == 'read') {
      _markChatRead(chat);
    } else if (action == 'unread') {
      _markChatUnread(chat);
    } else if (action == 'favorite') {
      _updateChatPreferences(chat, isFavorite: !chat.isFavorite);
    } else if (action == 'mute') {
      _updateChatPreferences(chat, isMuted: !chat.isMuted);
    } else if (action == 'archive') {
      _setArchived(chat, !chat.isArchived);
    } else if (action == 'clear') {
      _clearChat(chat);
    } else if (action == 'delete') {
      _deleteChat(chat);
    } else if (action == 'report') {
      _reportChat(chat);
    } else if (action == 'block') {
      _blockChatPeer(chat);
    }
  }

  String _formatChatTime(DateTime? date) {
    if (date == null) return 'New';

    final localDate = date.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(localDate.year, localDate.month, localDate.day);
    final diffDays = today.difference(target).inDays;

    if (diffDays == 0) {
      final hour = localDate.hour;
      final minute = localDate.minute.toString().padLeft(2, '0');
      final suffix = hour >= 12 ? 'PM' : 'AM';
      final hour12 = hour % 12 == 0 ? 12 : hour % 12;
      return '$hour12:$minute $suffix';
    }

    if (diffDays == 1) return 'Yesterday';
    if (diffDays < 7) return _weekdayLabel(localDate.weekday);

    return '${localDate.month}/${localDate.day}/${localDate.year}';
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
    final tokens = context.pravaColors;
    final border = tokens.borderSubtle;
    final query = _searchController.text.trim().toLowerCase();
    final searchedChats = query.isEmpty
        ? _chats
        : _chats
              .where(
                (chat) =>
                    chat.name.toLowerCase().contains(query) ||
                    chat.lastMessage.toLowerCase().contains(query),
              )
              .toList();
    final visibleChats = _applyFilter(searchedChats);

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Stack(
        children: [
          _ChatsBackground(isDark: isDark),
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                child: SizedBox(
                  height: 44,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                      child: Container(
                        decoration: BoxDecoration(
                          color: tokens.backgroundSurface.withValues(
                            alpha: 0.9,
                          ),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: border),
                        ),
                        child: PravaSearchInput(
                          controller: _searchController,
                          hint: 'Search chats',
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: 46,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _FilterChip(
                      label: 'All',
                      selected: _filter == _ChatListFilter.all,
                      onTap: () =>
                          setState(() => _filter = _ChatListFilter.all),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Unread',
                      selected: _filter == _ChatListFilter.unread,
                      onTap: () =>
                          setState(() => _filter = _ChatListFilter.unread),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Friends',
                      selected: _filter == _ChatListFilter.direct,
                      onTap: () =>
                          setState(() => _filter = _ChatListFilter.direct),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Groups',
                      selected: _filter == _ChatListFilter.groups,
                      onTap: () =>
                          setState(() => _filter = _ChatListFilter.groups),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Requests',
                      selected: false,
                      onTap: _openMessageRequests,
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Archived',
                      selected: _filter == _ChatListFilter.archived,
                      onTap: () =>
                          setState(() => _filter = _ChatListFilter.archived),
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
                          onRefresh: () => _loadChats(showLoading: false),
                          color: tokens.brandPrimary,
                          child: visibleChats.isEmpty
                              ? _EmptyChatsState(
                                  title: query.isEmpty
                                      ? _filterEmptyTitle()
                                      : 'No matches',
                                  subtitle: query.isEmpty
                                      ? _filterEmptySubtitle()
                                      : 'Try another name or message.',
                                )
                              : ListView.separated(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    0,
                                    16,
                                    16,
                                  ),
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
                                      onLongPress: () => _showChatActions(chat),
                                      onTap: () {
                                        HapticFeedback.selectionClick();
                                        _updateChat(
                                          chat.id,
                                          (current) =>
                                              current.copyWith(unreadCount: 0),
                                        );
                                        Navigator.of(
                                              context,
                                              rootNavigator: true,
                                            )
                                            .push(
                                              PravaNavigator.route(
                                                ChatThreadPage(chat: chat),
                                                fullscreenDialog: true,
                                              ),
                                            )
                                            .then((_) {
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

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.pravaColors;
    final background = selected
        ? tokens.brandPrimary
        : tokens.backgroundSurfaceSubtle;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: PravaTypography.caption.copyWith(
            color: selected ? tokens.textInverse : tokens.textSecondary,
            fontWeight: FontWeight.w700,
          ),
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
  const _ChatTile({
    required this.chat,
    required this.onTap,
    required this.onLongPress,
  });

  final ChatPreview chat;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  Color _avatarColor(String name, PravaThemeColors tokens) {
    final palette = [
      tokens.brandContent,
      tokens.statusSuccess,
      tokens.premiumContent,
      tokens.socialLikeActive,
      tokens.statusInfo,
    ];

    final hash = name.codeUnits.fold(0, (acc, c) => acc + c);
    return palette[hash % palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.pravaColors;
    final primary = tokens.textPrimary;
    final secondary = tokens.textSecondary;
    final border = tokens.borderSubtle;

    final isUnread = chat.unreadCount > 0;
    final baseColor = isUnread
        ? tokens.notificationUnread
        : tokens.backgroundSurface;
    final accent = _avatarColor(chat.name, tokens);

    final previewStyle = chat.isTyping
        ? PravaTypography.caption.copyWith(
            color: tokens.brandContent,
            fontWeight: FontWeight.w600,
          )
        : PravaTypography.caption.copyWith(color: secondary);
    final initial = chat.name.trim().isNotEmpty
        ? chat.name.trim()[0].toUpperCase()
        : 'P';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Ink(
          decoration: BoxDecoration(
            color: baseColor,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isUnread
                  ? tokens.brandPrimary.withValues(alpha: 0.35)
                  : border,
            ),
            boxShadow: [
              BoxShadow(
                color: tokens.shadowSoft,
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
                      backgroundImage:
                          !chat.isGroup && chat.avatarUrl.trim().isNotEmpty
                          ? NetworkImage(chat.avatarUrl.trim())
                          : null,
                      child: !chat.isGroup && chat.avatarUrl.trim().isNotEmpty
                          ? null
                          : chat.isGroup
                          ? Icon(CupertinoIcons.person_2_fill, color: accent)
                          : Text(
                              initial,
                              style: PravaTypography.titleSmall.copyWith(
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
                            color: tokens.statusSuccess,
                            shape: BoxShape.circle,
                            border: Border.all(color: baseColor, width: 2),
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
                              style: PravaTypography.bodyMedium.copyWith(
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
                              color: tokens.brandContent,
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (chat.lastMessageFromMe)
                            Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: _DeliveryIcon(state: chat.delivery),
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
                        color: isUnread ? tokens.brandContent : secondary,
                        fontWeight: isUnread
                            ? FontWeight.w600
                            : FontWeight.w400,
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
                          color: tokens.brandPrimary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          chat.unreadCount.toString(),
                          style: PravaTypography.caption.copyWith(
                            color: tokens.textInverse,
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
    final tokens = context.pravaColors;
    final muted = tokens.iconSecondary;

    switch (state) {
      case MessageDeliveryState.sending:
        return Icon(CupertinoIcons.clock, size: 14, color: muted);
      case MessageDeliveryState.sent:
        return Icon(Icons.check, size: 14, color: muted);
      case MessageDeliveryState.delivered:
        return Icon(Icons.done_all, size: 14, color: muted);
      case MessageDeliveryState.read:
        return Icon(Icons.done_all, size: 14, color: tokens.brandContent);
      case MessageDeliveryState.failed:
        return Icon(
          CupertinoIcons.exclamationmark_circle,
          size: 14,
          color: tokens.statusError,
        );
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
  final bool isFavorite;
  final bool isStarred;
  final bool isArchived;
  final String draftText;
  final bool isTyping;
  final String peerUserId;
  final String avatarUrl;
  final DateTime? peerLastSeenAt;
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
    this.isFavorite = false,
    this.isStarred = false,
    this.isArchived = false,
    this.draftText = '',
    required this.isTyping,
    this.peerUserId = '',
    this.avatarUrl = '',
    this.peerLastSeenAt,
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
    bool? isFavorite,
    bool? isStarred,
    bool? isArchived,
    String? draftText,
    bool? isTyping,
    String? peerUserId,
    String? avatarUrl,
    DateTime? peerLastSeenAt,
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
      isFavorite: isFavorite ?? this.isFavorite,
      isStarred: isStarred ?? this.isStarred,
      isArchived: isArchived ?? this.isArchived,
      draftText: draftText ?? this.draftText,
      isTyping: isTyping ?? this.isTyping,
      peerUserId: peerUserId ?? this.peerUserId,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      peerLastSeenAt: peerLastSeenAt ?? this.peerLastSeenAt,
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
  const _EmptyChatsState({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final tokens = context.pravaColors;
    final primary = tokens.textPrimary;
    final secondary = tokens.textSecondary;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 80, 16, 16),
      children: [
        Center(
          child: Icon(CupertinoIcons.chat_bubble_2, size: 40, color: secondary),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            title,
            style: PravaTypography.bodyLarge.copyWith(
              color: primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            subtitle,
            textAlign: TextAlign.center,
            style: PravaTypography.bodyMedium.copyWith(color: secondary),
          ),
        ),
      ],
    );
  }
}
