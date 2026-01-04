import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../../../ui-system/colors.dart';
import '../../../../ui-system/typography.dart';
import '../../../../ui-system/background.dart';
import '../../../../services/chat_realtime.dart';
import '../../../../services/chat_service.dart';
import '../../../../services/chat_sync_store.dart';
import '../../../../services/e2ee_service.dart';
import '../../../../services/group_e2ee_service.dart';
import '../../../../security/ratchet/group/sender_key_state.dart';
import '../../../../core/device/device_id.dart';
import '../../../../core/storage/secure_store.dart';
import 'chats_page.dart';

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

class ChatThreadPage extends StatefulWidget {
  final ChatPreview chat;

  const ChatThreadPage({super.key, required this.chat});

  @override
  State<ChatThreadPage> createState() => _ChatThreadPageState();
}

class _ChatThreadPageState extends State<ChatThreadPage> {
  static const int _initialPageSize = 60;
  static const int _pageSize = 40;

  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _composerFocus = FocusNode();
  final SecureStore _store = SecureStore();
  late final ChatSyncStore _syncStore = ChatSyncStore(store: _store);
  late final ChatService _chatService = ChatService(store: _store);
  late final ChatRealtime _realtime = ChatRealtime(store: _store);
  late final E2eeService _e2ee = E2eeService(store: _store);
  late final GroupE2eeService _groupE2ee =
      GroupE2eeService(store: _store, e2ee: _e2ee);
  late final DeviceIdStore _deviceIdStore = DeviceIdStore(_store);

  List<ChatMessage> _messages = <ChatMessage>[];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int? _oldestSeq;
  String? _userId;
  String? _deviceId;
  String? _peerUserId;
  bool _e2eeReady = false;
  Timer? _typingTimer;
  bool _isTyping = false;
  bool _peerTyping = false;
  Timer? _peerTypingTimer;
  bool _isAtBottom = true;
  ChatMessage? _editingMessage;
  bool _peerOnline = false;
  bool _groupReady = false;
  List<String> _groupMemberIds = <String>[];
  final Set<String> _hiddenMessageIds = <String>{};

  bool get _isDmChat => !widget.chat.isGroup;
  bool get _isGroupChat => widget.chat.isGroup;
  bool get _isEncryptedChat => _isDmChat || _isGroupChat;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    _bootstrap();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom(animated: false);
    });
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _peerTypingTimer?.cancel();
    if (_isTyping) {
      _realtime.sendTyping(
        conversationId: widget.chat.id,
        isTyping: false,
      );
    }
    _realtime.disconnect();
    _scrollController.removeListener(_handleScroll);
    _controller.dispose();
    _scrollController.dispose();
    _composerFocus.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    _userId = await _store.getUserId();
    _deviceId = await _deviceIdStore.getOrCreate();
    await _resolvePeerUserId();
    await _ensureE2eeReady();
    await _ensureGroupReady();
    await _loadGroupMembers();
    await _loadMessages();
    await _realtime.connect(_handleRealtimeEvent);
    _realtime.subscribeConversation(widget.chat.id);
  }

  Future<void> _resolvePeerUserId() async {
    if (!_isDmChat) return;
    final current = _userId;
    if (current == null || current.isEmpty) return;
    try {
      final members = await _chatService.listMembers(
        conversationId: widget.chat.id,
      );
      final other = members.firstWhere(
        (member) => member.userId.isNotEmpty && member.userId != current,
        orElse: () => ConversationMember(
          userId: '',
          role: '',
          joinedAt: null,
          leftAt: null,
        ),
      );
      if (other.userId.isNotEmpty) {
        _peerUserId = other.userId;
      }
    } catch (_) {}
  }

  Future<void> _ensureE2eeReady() async {
    if (!_isDmChat || _e2eeReady) return;
    try {
      await _e2ee.ensureReady();
      if (!mounted) return;
      setState(() => _e2eeReady = true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _e2eeReady = false);
    }
  }

  Future<void> _ensureGroupReady() async {
    if (!_isGroupChat || _groupReady) return;
    try {
      await _groupE2ee.ensureReady();
      if (!mounted) return;
      setState(() => _groupReady = true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _groupReady = false);
    }
  }

  Future<void> _loadGroupMembers() async {
    if (!_isGroupChat) return;
    final current = _userId;
    if (current == null || current.isEmpty) return;
    try {
      final members = await _chatService.listMembers(
        conversationId: widget.chat.id,
      );
      _groupMemberIds = members
          .where((member) => member.leftAt == null)
          .map((member) => member.userId)
          .where((id) => id.isNotEmpty && id != current)
          .toList();
    } catch (_) {}
  }

  Future<void> _loadMessages() async {
    setState(() => _loading = true);
    try {
      final data = await _chatService.listMessages(
        conversationId: widget.chat.id,
        limit: _initialPageSize,
        currentUserId: _userId,
      );

      data.sort(_compareMessages);
      final decrypted = await _decryptMessages(data);
      final latestSeq = decrypted.fold<int>(
        0,
        (prev, message) =>
            (message.seq ?? 0) > prev ? (message.seq ?? 0) : prev,
      );
      if (latestSeq > 0) {
        _syncStore.updateLastDeliveredSeq(widget.chat.id, latestSeq);
      }

      if (!mounted) return;
      final pending =
          _messages.where((message) => message.seq == null).toList();
      final merged = [...decrypted, ...pending]..sort(_compareMessages);
      setState(() {
        _messages = merged;
        _loading = false;
        _hasMore = decrypted.length >= _initialPageSize;
        _oldestSeq = _findOldestSeq(decrypted);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom(animated: false);
      _sendDeliveryReceipt();
      _sendReadReceiptIfNeeded();
    });
  }

  Future<List<ChatMessage>> _decryptMessages(
    List<ChatMessage> messages,
  ) async {
    if (!_isEncryptedChat) return messages;
    final resolved = <ChatMessage>[];
    for (final message in messages) {
      resolved.add(await _decryptMessageIfNeeded(message));
    }
    return resolved;
  }

  Future<ChatMessage> _decryptMessageIfNeeded(
    ChatMessage message,
  ) async {
    if (!_isEncryptedChat) return message;
    final body = message.body;

    if (_isDmChat) {
      if (!E2eeService.isEncrypted(body)) return message;
      if (!_e2eeReady) {
        return message.copyWith(
          body: 'Encrypted message',
          encryptedBody: body,
        );
      }
      try {
        final plaintext = await _e2ee.decryptBody(
          body: body,
          senderUserId: message.senderUserId,
          senderDeviceId: message.senderDeviceId,
        );
        if (plaintext == null || plaintext.isEmpty) {
          return message.copyWith(
            body: 'Message unavailable',
            encryptedBody: body,
          );
        }
        return message.copyWith(body: plaintext, encryptedBody: body);
      } catch (_) {
        return message.copyWith(
          body: 'Message unavailable',
          encryptedBody: body,
        );
      }
    }

    if (_isGroupChat) {
      if (GroupE2eeService.isGroupEncrypted(body)) {
        if (!_groupReady) {
          return message.copyWith(
            body: 'Encrypted message',
            encryptedBody: body,
          );
        }
        try {
          final plaintext = await _groupE2ee.decryptGroupMessage(
            body: body,
            senderUserId: message.senderUserId,
            senderDeviceId: message.senderDeviceId,
          );
          if (plaintext == null || plaintext.isEmpty) {
            return message.copyWith(
              body: 'Message unavailable',
              encryptedBody: body,
            );
          }
          return message.copyWith(body: plaintext, encryptedBody: body);
        } catch (_) {
          return message.copyWith(
            body: 'Message unavailable',
            encryptedBody: body,
          );
        }
      }

      if (E2eeService.isEncrypted(body)) {
        if (!_groupReady) {
          return message.copyWith(
            body: 'Encrypted message',
            encryptedBody: body,
          );
        }
        final handled = await _handleGroupDistributionMessage(message);
        if (handled) {
          return message.copyWith(
            body: 'Encryption updated',
            type: ChatMessageType.system,
            encryptedBody: body,
          );
        }
        return message.copyWith(
          body: 'Encrypted message',
          encryptedBody: body,
        );
      }
    }

    return message;
  }

  Future<bool> _handleGroupDistributionMessage(ChatMessage message) async {
    final result = await _groupE2ee.handleDistributionMessage(
      body: message.body,
      senderUserId: message.senderUserId,
      senderDeviceId: message.senderDeviceId,
    );
    if (result == null) return false;
    if (result.groupId != widget.chat.id) return false;
    _hiddenMessageIds.add(message.id);
    return true;
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    final max = _scrollController.position.maxScrollExtent;
    final offset = _scrollController.offset;
    final atBottom = (max - offset) < 80;
    if (atBottom != _isAtBottom && mounted) {
      setState(() => _isAtBottom = atBottom);
    }
    if (atBottom) {
      _sendReadReceiptIfNeeded();
    }
    if (offset < 120) {
      _loadMoreMessages();
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    if (_editingMessage != null) {
      await _submitEdit(text);
      return;
    }

    HapticFeedback.selectionClick();
    _stopTyping();

    final tempId = _generateTempId();
    final senderUserId = _userId ?? '';
    final senderDeviceId =
        _deviceId ?? await _deviceIdStore.getOrCreate();
    _deviceId ??= senderDeviceId;

    final message = ChatMessage.localText(
      tempId: tempId,
      conversationId: widget.chat.id,
      senderUserId: senderUserId,
      senderDeviceId: senderDeviceId,
      body: text,
    );

    setState(() {
      _messages = [..._messages, message];
      _controller.clear();
    });

    _scrollToBottom();

    String outboundBody = text;
    if (_isGroupChat) {
      final encrypted = await _prepareGroupOutboundMessage(tempId, text);
      if (encrypted == null || encrypted.isEmpty) {
        _markFailed(tempId);
        return;
      }
      outboundBody = encrypted;
    } else if (_isDmChat) {
      if (_peerUserId == null) {
        await _resolvePeerUserId();
      }
      await _ensureE2eeReady();
      if (!_e2eeReady || _peerUserId == null || _peerUserId!.isEmpty) {
        _markFailed(tempId);
        return;
      }
      try {
        final encrypted = await _e2ee.encryptBody(
          peerUserId: _peerUserId!,
          plaintext: text,
        );
        if (encrypted == null || encrypted.isEmpty) {
          _markFailed(tempId);
          return;
        }
        outboundBody = encrypted;
        _updateMessage(
          tempId,
          (m) => m.copyWith(encryptedBody: encrypted),
        );
      } catch (_) {
        _markFailed(tempId);
        return;
      }
    }

    if (_realtime.isConnected) {
      _realtime.sendMessage(
        conversationId: widget.chat.id,
        body: outboundBody,
        tempId: tempId,
        contentType: 'text',
        clientTimestamp: DateTime.now(),
      );
      return;
    }

    try {
      final sent = await _chatService.sendMessage(
        conversationId: widget.chat.id,
        body: outboundBody,
        tempId: tempId,
      );
      if (sent != null) {
        _applyServerMessage(tempId, sent);
      } else {
        _markFailed(tempId);
      }
    } catch (_) {
      _markFailed(tempId);
    }
  }

  void _applyServerMessage(String tempId, ChatMessage serverMessage) {
    final index =
        _messages.indexWhere((m) => m.clientTempId == tempId || m.id == tempId);
    if (index == -1) return;

    final existing = _messages[index];
    final isEncrypted = _isEncryptedPayload(serverMessage.body);
    final updated = serverMessage.copyWith(
      body: isEncrypted ? existing.body : serverMessage.body,
      encryptedBody:
          isEncrypted ? serverMessage.body : existing.encryptedBody,
      deliveryState: MessageDeliveryState.sent,
      isOutgoing: true,
    );
    final seq = updated.seq;
    if (seq != null && seq > 0) {
      _syncStore.updateLastDeliveredSeq(widget.chat.id, seq);
    }

    setState(() {
      _messages = List<ChatMessage>.from(_messages);
      _messages[index] = updated;
      _messages.removeWhere(
        (m) => m.id == updated.id && m.clientTempId != tempId,
      );
    });
  }

  void _markFailed(String tempId) {
    _updateMessage(
      tempId,
      (m) => m.copyWith(deliveryState: MessageDeliveryState.failed),
    );
  }

  Future<void> _retryMessage(ChatMessage message) async {
    if (message.deliveryState != MessageDeliveryState.failed) return;

    final tempId = message.clientTempId ?? message.id;
    _updateMessage(
      message.id,
      (m) => m.copyWith(deliveryState: MessageDeliveryState.sending),
    );

    String outboundBody = message.encryptedBody ?? message.body;
    if (_isGroupChat) {
      if (message.encryptedBody == null) {
        final encrypted =
            await _prepareGroupOutboundMessage(message.id, message.body);
        if (encrypted == null || encrypted.isEmpty) {
          _markFailed(tempId);
          return;
        }
        outboundBody = encrypted;
      }
    } else if (_isDmChat) {
      if (_peerUserId == null) {
        await _resolvePeerUserId();
      }
      await _ensureE2eeReady();
      if (!_e2eeReady || _peerUserId == null || _peerUserId!.isEmpty) {
        _markFailed(tempId);
        return;
      }
      if (message.encryptedBody == null) {
        try {
          final encrypted = await _e2ee.encryptBody(
            peerUserId: _peerUserId!,
            plaintext: message.body,
          );
          if (encrypted == null || encrypted.isEmpty) {
            _markFailed(tempId);
            return;
          }
          outboundBody = encrypted;
          _updateMessage(
            message.id,
            (m) => m.copyWith(encryptedBody: encrypted),
          );
        } catch (_) {
          _markFailed(tempId);
          return;
        }
      }
    }

    if (_realtime.isConnected) {
      _realtime.sendMessage(
        conversationId: widget.chat.id,
        body: outboundBody,
        tempId: tempId,
        contentType:
            message.type == ChatMessageType.media ? 'media' : 'text',
        mediaAssetId: message.mediaAssetId,
        clientTimestamp: DateTime.now(),
      );
      return;
    }

    try {
      final sent = await _chatService.sendMessage(
        conversationId: widget.chat.id,
        body: outboundBody,
        tempId: tempId,
        contentType:
            message.type == ChatMessageType.media ? 'media' : 'text',
        mediaAssetId: message.mediaAssetId,
      );
      if (sent != null) {
        _applyServerMessage(tempId, sent);
      } else {
        _markFailed(tempId);
      }
    } catch (_) {
      _markFailed(tempId);
    }
  }

  Future<String?> _prepareGroupOutboundMessage(
    String messageId,
    String plaintext,
  ) async {
    await _ensureGroupReady();
    final bundle = await _groupE2ee.ensureOwnSenderKey(
      groupId: widget.chat.id,
    );
    if (bundle == null) return null;

    if (bundle.needsDistribution) {
      await _sendSenderKeyDistribution(senderKey: bundle.senderKey);
    }

    final result = await _groupE2ee.encryptGroupMessageWithKey(
      senderKey: bundle.senderKey,
      plaintext: plaintext,
    );
    if (result == null) return null;

    _updateMessage(
      messageId,
      (m) => m.copyWith(encryptedBody: result.body),
    );

    return result.body;
  }

  Future<void> _sendSenderKeyDistribution({
    SenderKeyState? senderKey,
  }) async {
    if (!_isGroupChat) return;
    if (_groupMemberIds.isEmpty) {
      await _loadGroupMembers();
    }
    if (_groupMemberIds.isEmpty) return;

    try {
      await _e2ee.ensureReady();
      final envelope = senderKey == null
          ? await _groupE2ee.buildDistributionEnvelope(
              groupId: widget.chat.id,
              memberUserIds: _groupMemberIds,
            )
          : await _groupE2ee.buildDistributionEnvelopeForKey(
              senderKey: senderKey,
              memberUserIds: _groupMemberIds,
            );
      if (envelope == null || envelope.isEmpty) return;

      if (_realtime.isConnected) {
        _realtime.sendMessage(
          conversationId: widget.chat.id,
          body: envelope,
          tempId: _generateTempId(),
          contentType: 'system',
          clientTimestamp: DateTime.now(),
        );
        return;
      }

      await _chatService.sendMessage(
        conversationId: widget.chat.id,
        body: envelope,
        contentType: 'system',
      );
    } catch (_) {}
  }

  String _generateTempId() {
    final rand = Random.secure();
    final bytes = List<int>.generate(8, (_) => rand.nextInt(256));
    final buffer = StringBuffer();
    for (final b in bytes) {
      buffer.write(b.toRadixString(16).padLeft(2, '0'));
    }
    return '${DateTime.now().microsecondsSinceEpoch}_$buffer';
  }

  bool _isEncryptedPayload(String body) {
    return E2eeService.isEncrypted(body) ||
        GroupE2eeService.isGroupEncrypted(body);
  }

  Future<void> _submitEdit(String text) async {
    final message = _editingMessage;
    if (message == null) return;

    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    String outboundBody = trimmed;
    String? encryptedBody;

    if (_isGroupChat) {
      final encrypted = await _prepareGroupOutboundMessage(
        message.id,
        trimmed,
      );
      if (encrypted == null || encrypted.isEmpty) return;
      outboundBody = encrypted;
      encryptedBody = encrypted;
    } else if (_isDmChat) {
      if (_peerUserId == null) {
        await _resolvePeerUserId();
      }
      await _ensureE2eeReady();
      if (!_e2eeReady || _peerUserId == null || _peerUserId!.isEmpty) {
        return;
      }
      try {
        final encrypted = await _e2ee.encryptBody(
          peerUserId: _peerUserId!,
          plaintext: trimmed,
        );
        if (encrypted == null || encrypted.isEmpty) return;
        outboundBody = encrypted;
        encryptedBody = encrypted;
      } catch (_) {
        return;
      }
    }

    _editingMessage = null;
    _controller.clear();

    _updateMessage(
      message.id,
      (m) => m.copyWith(
        body: trimmed,
        editVersion: m.editVersion + 1,
        encryptedBody: encryptedBody ?? m.encryptedBody,
      ),
    );

    _realtime.editMessage(
      conversationId: widget.chat.id,
      messageId: message.id,
      body: outboundBody,
    );

    FocusScope.of(context).unfocus();
  }

  void _startEditing(ChatMessage message) {
    if (!message.isOutgoing || message.isDeleted) return;
    if (message.deliveryState == MessageDeliveryState.sending ||
        message.deliveryState == MessageDeliveryState.failed) {
      return;
    }
    setState(() {
      _editingMessage = message;
    });
    _controller.text = message.body;
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: _controller.text.length),
    );
    _composerFocus.requestFocus();
  }

  void _cancelEditing() {
    setState(() {
      _editingMessage = null;
    });
    _controller.clear();
    _composerFocus.unfocus();
  }

  void _showMessageActions(ChatMessage message) {
    final canEdit = message.isOutgoing &&
        !message.isDeleted &&
        message.type == ChatMessageType.text &&
        message.seq != null;
    final canRetry = message.isOutgoing &&
        message.deliveryState == MessageDeliveryState.failed;
    final canCopy = !message.isDeleted &&
        message.type == ChatMessageType.text &&
        message.body.trim().isNotEmpty;
    final canDelete =
        message.isOutgoing && !message.isDeleted && message.seq != null;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: false,
      builder: (context) {
        final isDark =
            Theme.of(context).brightness == Brightness.dark;
        final surface =
            isDark ? PravaColors.darkBgElevated : PravaColors.lightBgElevated;
        final border =
            isDark ? PravaColors.darkBorderSubtle : PravaColors.lightBorderSubtle;
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ReactionPicker(
                  onSelect: (emoji) {
                    Navigator.of(context).pop();
                    _setReaction(message, emoji);
                  },
                ),
                const SizedBox(height: 12),
                if (canRetry)
                  _SheetAction(
                    icon: CupertinoIcons.arrow_clockwise,
                    label: 'Retry',
                    onTap: () {
                      Navigator.of(context).pop();
                      _retryMessage(message);
                    },
                  ),
                if (canCopy)
                  _SheetAction(
                    icon: CupertinoIcons.doc_on_doc,
                    label: 'Copy',
                    onTap: () {
                      Clipboard.setData(
                        ClipboardData(text: message.body),
                      );
                      Navigator.of(context).pop();
                    },
                  ),
                if (canEdit)
                  _SheetAction(
                    icon: CupertinoIcons.pencil,
                    label: 'Edit',
                    onTap: () {
                      Navigator.of(context).pop();
                      _startEditing(message);
                    },
                  ),
                if (canDelete)
                  _SheetAction(
                    icon: CupertinoIcons.trash,
                    label: 'Delete for everyone',
                    isDestructive: true,
                    onTap: () {
                      Navigator.of(context).pop();
                      _deleteMessage(message);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _deleteMessage(ChatMessage message) {
    _updateMessage(
      message.id,
      (m) => m.copyWith(
        body: '',
        type: ChatMessageType.system,
        deletedForAllAt: DateTime.now(),
      ),
    );
    _realtime.deleteMessage(
      conversationId: widget.chat.id,
      messageId: message.id,
    );
  }

  void _setReaction(ChatMessage message, String emoji) {
    final userId = _userId;
    if (userId == null || emoji.isEmpty) return;

    final existingIndex =
        message.reactions.indexWhere((r) => r.userId == userId);
    final nextReactions = List<ChatReaction>.from(message.reactions);

    if (existingIndex != -1) {
      final existing = nextReactions[existingIndex];
      if (existing.emoji == emoji) {
        nextReactions.removeAt(existingIndex);
        _realtime.removeReaction(
          conversationId: widget.chat.id,
          messageId: message.id,
        );
      } else {
        nextReactions[existingIndex] = existing.copyWith(
          emoji: emoji,
          updatedAt: DateTime.now(),
        );
        _realtime.setReaction(
          conversationId: widget.chat.id,
          messageId: message.id,
          emoji: emoji,
        );
      }
    } else {
      nextReactions.add(
        ChatReaction(
          userId: userId,
          emoji: emoji,
          reactedAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      _realtime.setReaction(
        conversationId: widget.chat.id,
        messageId: message.id,
        emoji: emoji,
      );
    }

    _updateMessage(
      message.id,
      (m) => m.copyWith(reactions: nextReactions),
    );
  }

  void _handleTypingChanged(String value) {
    final hasText = value.trim().isNotEmpty;

    if (hasText && !_isTyping) {
      _isTyping = true;
      _realtime.sendTyping(
        conversationId: widget.chat.id,
        isTyping: true,
      );
    }

    _typingTimer?.cancel();

    if (hasText) {
      _typingTimer = Timer(const Duration(seconds: 2), () {
        _stopTyping();
      });
    } else {
      _stopTyping();
    }
  }

  void _stopTyping() {
    if (!_isTyping) return;
    _isTyping = false;
    _realtime.sendTyping(
      conversationId: widget.chat.id,
      isTyping: false,
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
      case 'MESSAGE_EDIT':
        _handleMessageEdit(payload);
        break;
      case 'MESSAGE_DELETE':
        _handleMessageDelete(payload);
        break;
      case 'READ_UPDATE':
        _handleReadUpdate(payload);
        break;
      case 'DELIVERY_UPDATE':
        _handleDeliveryUpdate(payload);
        break;
      case 'REACTION_UPDATE':
        _handleReactionUpdate(payload);
        break;
      case 'TYPING':
        _handlePeerTyping(payload);
        break;
      case 'PRESENCE_UPDATE':
        _handlePresence(payload);
        break;
      default:
        break;
    }
  }

  void _handleMessagePush(Map<String, dynamic> payload) {
    final conversationId = payload['conversationId']?.toString();
    if (conversationId != widget.chat.id) return;

    final message = ChatMessage.fromJson(
      {
        'id': payload['messageId'],
        'conversationId': payload['conversationId'],
        'senderUserId': payload['senderUserId'],
        'senderDeviceId': payload['senderDeviceId'],
        'seq': payload['seq'],
        'contentType': payload['contentType'],
        'body': payload['body'],
        'mediaAssetId': payload['mediaAssetId'],
        'editVersion': payload['editVersion'],
        'deletedForAllAt': payload['deletedForAllAt'],
        'createdAt': payload['createdAt'],
      },
      currentUserId: _userId,
    );
    _processIncomingMessage(message);
  }

  Future<void> _processIncomingMessage(ChatMessage message) async {
    final resolved = await _decryptMessageIfNeeded(message);
    if (!mounted) return;
    final seq = resolved.seq;
    if (seq != null && seq > 0) {
      _syncStore.updateLastDeliveredSeq(widget.chat.id, seq);
    }
    var merged = resolved;
    if (resolved.isOutgoing && resolved.senderDeviceId == _deviceId) {
      final existingIndex = _messages.indexWhere(
        (m) => m.id == resolved.id || m.clientTempId == resolved.id,
      );
      if (existingIndex != -1) {
        final existing = _messages[existingIndex];
        final encryptedBody = _isEncryptedPayload(message.body)
            ? message.body
            : existing.encryptedBody;
        merged = resolved.copyWith(
          body: existing.body,
          encryptedBody: encryptedBody,
          clientTempId: existing.clientTempId ?? resolved.clientTempId,
          isOutgoing: true,
        );
      }
    }
    _upsertMessage(merged);
    _sendDeliveryReceipt();
    _sendReadReceiptIfNeeded();
    _scrollToBottomIfNeeded();
  }

  void _handleMessageAck(Map<String, dynamic> payload) {
    final conversationId = payload['conversationId']?.toString();
    if (conversationId != widget.chat.id) return;

    final tempId = payload['tempId']?.toString();
    final messageId = payload['messageId']?.toString();
    final seq = _parseInt(payload['seq']);
    final createdAt = _parseDate(payload['createdAt']);

    if (tempId == null || messageId == null) return;

    if (seq != null && seq > 0) {
      _syncStore.updateLastDeliveredSeq(widget.chat.id, seq);
    }

    final index = _messages.indexWhere((m) => m.clientTempId == tempId || m.id == tempId);
    if (index == -1) return;

    final updated = _messages[index].copyWith(
      id: messageId,
      seq: seq,
      createdAt: createdAt ?? _messages[index].createdAt,
      deliveryState: MessageDeliveryState.sent,
    );

    setState(() {
      _messages = List<ChatMessage>.from(_messages);
      _messages[index] = updated;
      _messages.removeWhere(
        (m) => m.id == messageId && m.clientTempId != tempId,
      );
    });
  }

  void _handleMessageEdit(Map<String, dynamic> payload) {
    final conversationId = payload['conversationId']?.toString();
    final messageId = payload['messageId']?.toString();
    final body = payload['body']?.toString() ?? '';
    final editVersion = _parseInt(payload['editVersion']) ?? 0;
    if (conversationId != widget.chat.id || messageId == null) return;

    _applyMessageEdit(messageId, body, editVersion);
  }

  Future<void> _applyMessageEdit(
    String messageId,
    String body,
    int editVersion,
  ) async {
    final index = _messages.indexWhere((m) => m.id == messageId);
    if (index == -1) return;

    var nextBody = body;
    String? encryptedBody;
    if (_isDmChat && E2eeService.isEncrypted(body)) {
      if (!_e2eeReady) {
        nextBody = 'Encrypted message';
        encryptedBody = body;
      } else {
        final existing = _messages[index];
        try {
          final plaintext = await _e2ee.decryptBody(
            body: body,
            senderUserId: existing.senderUserId,
            senderDeviceId: existing.senderDeviceId,
          );
          if (plaintext == null || plaintext.isEmpty) {
            nextBody = 'Message unavailable';
          } else {
            nextBody = plaintext;
          }
          encryptedBody = body;
        } catch (_) {
          nextBody = 'Message unavailable';
          encryptedBody = body;
        }
      }
    } else if (_isGroupChat &&
        GroupE2eeService.isGroupEncrypted(body)) {
      if (!_groupReady) {
        nextBody = 'Encrypted message';
        encryptedBody = body;
      } else {
        final existing = _messages[index];
        try {
          final plaintext = await _groupE2ee.decryptGroupMessage(
            body: body,
            senderUserId: existing.senderUserId,
            senderDeviceId: existing.senderDeviceId,
          );
          if (plaintext == null || plaintext.isEmpty) {
            nextBody = 'Message unavailable';
          } else {
            nextBody = plaintext;
          }
          encryptedBody = body;
        } catch (_) {
          nextBody = 'Message unavailable';
          encryptedBody = body;
        }
      }
    }

    _updateMessage(
      messageId,
      (m) => m.copyWith(
        body: nextBody,
        editVersion: editVersion,
        encryptedBody: encryptedBody ?? m.encryptedBody,
      ),
    );
  }

  void _handleMessageDelete(Map<String, dynamic> payload) {
    final conversationId = payload['conversationId']?.toString();
    final messageId = payload['messageId']?.toString();
    final deletedForAllAt = _parseDate(payload['deletedForAllAt']);
    if (conversationId != widget.chat.id || messageId == null) return;

    _updateMessage(
      messageId,
      (m) => m.copyWith(
        body: '',
        type: ChatMessageType.system,
        deletedForAllAt: deletedForAllAt ?? DateTime.now(),
      ),
    );
  }

  void _handleReadUpdate(Map<String, dynamic> payload) {
    final conversationId = payload['conversationId']?.toString();
    final lastReadSeq = _parseInt(payload['lastReadSeq']);
    if (conversationId != widget.chat.id || lastReadSeq == null) return;

    _updateDeliveryStates(
      lastReadSeq,
      MessageDeliveryState.read,
    );
  }

  void _handleDeliveryUpdate(Map<String, dynamic> payload) {
    final conversationId = payload['conversationId']?.toString();
    final lastDeliveredSeq = _parseInt(payload['lastDeliveredSeq']);
    if (conversationId != widget.chat.id || lastDeliveredSeq == null) return;

    _updateDeliveryStates(
      lastDeliveredSeq,
      MessageDeliveryState.delivered,
    );
  }

  void _handleReactionUpdate(Map<String, dynamic> payload) {
    final conversationId = payload['conversationId']?.toString();
    final messageId = payload['messageId']?.toString();
    final userId = payload['userId']?.toString() ?? '';
    final emoji = payload['emoji']?.toString();
    if (conversationId != widget.chat.id || messageId == null) return;

    _updateMessage(messageId, (message) {
      final existingIndex =
          message.reactions.indexWhere((r) => r.userId == userId);
      final updatedAt = _parseDate(payload['updatedAt']);
      final nextReactions = List<ChatReaction>.from(message.reactions);

      if (emoji == null || emoji.isEmpty) {
        if (existingIndex != -1) {
          nextReactions.removeAt(existingIndex);
        }
      } else if (existingIndex == -1) {
        nextReactions.add(
          ChatReaction(
            userId: userId,
            emoji: emoji,
            reactedAt: _parseDate(payload['updatedAt']),
            updatedAt: updatedAt,
          ),
        );
      } else {
        nextReactions[existingIndex] =
            nextReactions[existingIndex].copyWith(
          emoji: emoji,
          updatedAt: updatedAt,
        );
      }

      return message.copyWith(reactions: nextReactions);
    });
  }

  void _handlePeerTyping(Map<String, dynamic> payload) {
    final conversationId = payload['conversationId']?.toString();
    final userId = payload['userId']?.toString();
    if (conversationId != widget.chat.id) return;
    if (userId == null || userId == _userId) return;

    final isTyping = payload['isTyping'] == true;
    _peerTypingTimer?.cancel();
    if (!mounted) return;
    setState(() => _peerTyping = isTyping);
    if (isTyping) {
      _peerTypingTimer = Timer(
        const Duration(seconds: 4),
        () {
          if (!mounted) return;
          setState(() => _peerTyping = false);
        },
      );
    }
  }

  void _handlePresence(Map<String, dynamic> payload) {
    final conversationId = payload['conversationId']?.toString();
    if (conversationId != widget.chat.id) return;
    final userId = payload['userId']?.toString();
    if (userId == null || userId == _userId) return;
    final isOnline = payload['isOnline'] == true;
    if (widget.chat.isGroup) return;
    if (mounted) {
      setState(() => _peerOnline = isOnline);
    }
  }

  void _upsertMessage(ChatMessage message) {
    final index = _messages.indexWhere((m) => m.id == message.id);
    if (index != -1) {
      setState(() {
        _messages = List<ChatMessage>.from(_messages);
        _messages[index] = message;
        _oldestSeq = _findOldestSeq(_messages);
      });
      return;
    }

    setState(() {
      _messages = [..._messages, message];
      _messages.sort(_compareMessages);
      _oldestSeq = _findOldestSeq(_messages);
    });
  }

  void _updateMessage(
    String messageId,
    ChatMessage Function(ChatMessage) update,
  ) {
    final index = _messages.indexWhere((m) => m.id == messageId);
    if (index == -1) return;
    if (!mounted) return;

    setState(() {
      _messages = List<ChatMessage>.from(_messages);
      _messages[index] = update(_messages[index]);
    });
  }

  void _updateDeliveryStates(
    int lastSeq,
    MessageDeliveryState state,
  ) {
    if (!mounted) return;
    setState(() {
      _messages = _messages.map((message) {
        if (!message.isOutgoing) return message;
        if (message.seq != null && message.seq! <= lastSeq) {
          return message.copyWith(deliveryState: state);
        }
        return message;
      }).toList();
    });
  }

  void _sendDeliveryReceipt() {
    final latestSeq = _messages
        .where((m) => !m.isOutgoing)
        .map((m) => m.seq ?? 0)
        .fold<int>(0, (prev, next) => next > prev ? next : prev);
    if (latestSeq <= 0) return;
    _realtime.sendDeliveryReceipt(
      conversationId: widget.chat.id,
      lastDeliveredSeq: latestSeq,
    );
  }

  void _sendReadReceiptIfNeeded() {
    if (!_isAtBottom) return;
    final latestSeq = _messages
        .where((m) => !m.isOutgoing)
        .map((m) => m.seq ?? 0)
        .fold<int>(0, (prev, next) => next > prev ? next : prev);
    if (latestSeq <= 0) return;
    _realtime.sendReadReceipt(
      conversationId: widget.chat.id,
      lastReadSeq: latestSeq,
    );
  }

  void _scrollToBottomIfNeeded() {
    if (_isAtBottom) {
      _scrollToBottom();
    }
  }

  void _scrollToBottom({bool animated = true}) {
    if (!_scrollController.hasClients) return;
    final offset = _scrollController.position.maxScrollExtent;
    if (!animated) {
      _scrollController.jumpTo(offset);
      return;
    }

    _scrollController.animateTo(
      offset,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  List<_ChatEntry> _buildEntries(List<ChatMessage> messages) {
    final entries = <_ChatEntry>[
      if (_loadingMore) const _ChatEntry.loading(),
      if (_isEncryptedChat) const _ChatEntry.banner(),
    ];

    DateTime? lastDate;
    for (var i = 0; i < messages.length; i++) {
      final message = messages[i];
      final date = DateTime(
        message.createdAt.year,
        message.createdAt.month,
        message.createdAt.day,
      );

      if (lastDate == null || !_isSameDay(lastDate, date)) {
        entries.add(_ChatEntry.date(date));
        lastDate = date;
      }

      entries.add(_ChatEntry.message(message, i));
    }

    if (_peerTyping) {
      entries.add(const _ChatEntry.typing());
    }

    return entries;
  }

  List<ChatMessage> _visibleMessages() {
    if (_hiddenMessageIds.isEmpty) return _messages;
    return _messages
        .where((message) => !_hiddenMessageIds.contains(message.id))
        .toList();
  }

  int _compareMessages(ChatMessage a, ChatMessage b) {
    final aSeq = a.seq;
    final bSeq = b.seq;
    if (aSeq == null && bSeq == null) {
      return a.createdAt.compareTo(b.createdAt);
    }
    if (aSeq == null) return 1;
    if (bSeq == null) return -1;
    final seqCompare = aSeq.compareTo(bSeq);
    if (seqCompare != 0) return seqCompare;
    return a.createdAt.compareTo(b.createdAt);
  }

  int? _findOldestSeq(List<ChatMessage> messages) {
    int? minSeq;
    for (final message in messages) {
      final seq = message.seq;
      if (seq == null) continue;
      if (minSeq == null || seq < minSeq) {
        minSeq = seq;
      }
    }
    return minSeq;
  }

  Future<void> _loadMoreMessages() async {
    if (_loading || _loadingMore || !_hasMore) return;
    final beforeSeq = _oldestSeq;
    if (beforeSeq == null || beforeSeq <= 1) {
      _hasMore = false;
      return;
    }
    if (!_scrollController.hasClients) return;

    final beforeExtent = _scrollController.position.maxScrollExtent;
    final beforeOffset = _scrollController.offset;

    setState(() => _loadingMore = true);

    try {
      final data = await _chatService.listMessages(
        conversationId: widget.chat.id,
        limit: _pageSize,
        beforeSeq: beforeSeq,
        currentUserId: _userId,
      );

      data.sort(_compareMessages);

      if (!mounted) return;
      final existingIds = _messages.map((m) => m.id).toSet();
      final filtered =
          data.where((m) => !existingIds.contains(m.id)).toList();
      final decrypted = await _decryptMessages(filtered);

      setState(() {
        _messages = [...decrypted, ..._messages];
        _loadingMore = false;
        _oldestSeq = _findOldestSeq(_messages);
        _hasMore = data.length >= _pageSize;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) return;
        final newExtent = _scrollController.position.maxScrollExtent;
        final delta = newExtent - beforeExtent;
        if (delta > 0) {
          _scrollController.jumpTo(beforeOffset + delta);
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _isSameBlock(ChatMessage a, ChatMessage b) {
    if (a.isOutgoing != b.isOutgoing) return false;
    if (!_isSameDay(a.createdAt, b.createdAt)) return false;
    return a.createdAt.difference(b.createdAt).inMinutes.abs() <= 6;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final diff = today.difference(target).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${months[date.month - 1]} ${date.day}';
  }

  String _formatTime(DateTime date) {
    final hour = date.hour;
    final minute = date.minute.toString().padLeft(2, '0');
    final suffix = hour >= 12 ? 'PM' : 'AM';
    final hour12 = hour % 12 == 0 ? 12 : hour % 12;
    return '$hour12:$minute $suffix';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary =
        isDark ? PravaColors.darkTextPrimary : PravaColors.lightTextPrimary;
    final secondary =
        isDark ? PravaColors.darkTextSecondary : PravaColors.lightTextSecondary;
    final visibleMessages = _visibleMessages();
    final entries = _buildEntries(visibleMessages);
    final initial = widget.chat.name.isNotEmpty
        ? widget.chat.name[0].toUpperCase()
        : 'P';
    final subtitle = widget.chat.isGroup
        ? (_peerTyping ? 'Someone is typing...' : 'Group chat')
        : (_peerTyping
            ? 'Typing...'
            : (_peerOnline ? 'Online' : 'Active recently'));

    return Scaffold(
      backgroundColor:
          isDark ? PravaColors.darkBgMain : PravaColors.lightBgMain,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Stack(
          children: [
            _ChatBackground(isDark: isDark),
            SafeArea(
              child: Column(
                children: [
                  _ChatHeader(
                    name: widget.chat.name,
                    subtitle: subtitle,
                    initial: initial,
                  ),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: _loading
                          ? Center(
                              child: CircularProgressIndicator(
                                color: PravaColors.accentPrimary,
                              ),
                            )
                          : ListView.builder(
                              controller: _scrollController,
                              padding:
                                  const EdgeInsets.fromLTRB(16, 12, 16, 16),
                              physics: const BouncingScrollPhysics(
                                parent: AlwaysScrollableScrollPhysics(),
                              ),
                              itemCount: entries.length,
                              itemBuilder: (context, index) {
                                final entry = entries[index];
                                switch (entry.type) {
                                  case _ChatEntryType.loading:
                                    return const Padding(
                                      padding:
                                          EdgeInsets.symmetric(vertical: 8),
                                      child: Center(
                                        child: SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: PravaColors.accentPrimary,
                                          ),
                                        ),
                                      ),
                                    );
                                  case _ChatEntryType.banner:
                                    return const _EncryptionBanner();
                                  case _ChatEntryType.date:
                                    return _DateChip(
                                      label: _formatDate(entry.date!),
                                    );
                                  case _ChatEntryType.typing:
                                    return const _TypingBubble();
                                  case _ChatEntryType.message:
                                    final message = entry.message!;
                                    final messageIndex = entry.messageIndex!;
                                    final prev = messageIndex > 0
                                        ? visibleMessages[messageIndex - 1]
                                        : null;
                                    final next =
                                        messageIndex < visibleMessages.length - 1
                                            ? visibleMessages[messageIndex + 1]
                                            : null;
                                    final isFirst = prev == null ||
                                        !_isSameBlock(prev, message);
                                    final isLast = next == null ||
                                        !_isSameBlock(message, next);
                                    final showAvatar =
                                        !message.isOutgoing && isLast;
                                    return _MessageBubble(
                                      message: message,
                                      isDark: isDark,
                                      primary: primary,
                                      secondary: secondary,
                                      timeLabel:
                                          _formatTime(message.createdAt),
                                      showAvatar: showAvatar,
                                      initial: initial,
                                      isFirst: isFirst,
                                      isLast: isLast,
                                      onLongPress: () =>
                                          _showMessageActions(message),
                                    );
                                }
                              },
                            ),
                    ),
                  ),
                  AnimatedPadding(
                    duration: const Duration(milliseconds: 200),
                    padding: EdgeInsets.only(
                      left: 12,
                      right: 12,
                      bottom: MediaQuery.of(context).viewInsets.bottom + 8,
                      top: 4,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_editingMessage != null)
                          _EditingBanner(
                            preview: _editingMessage!.body,
                            onCancel: _cancelEditing,
                          ),
                        _ComposerBar(
                          controller: _controller,
                          focusNode: _composerFocus,
                          onSend: () {
                            _sendMessage();
                          },
                          onChanged: _handleTypingChanged,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _ChatEntryType { loading, banner, date, message, typing }

class _ChatEntry {
  const _ChatEntry.loading()
      : type = _ChatEntryType.loading,
        date = null,
        message = null,
        messageIndex = null;

  const _ChatEntry.banner()
      : type = _ChatEntryType.banner,
        date = null,
        message = null,
        messageIndex = null;

  const _ChatEntry.date(this.date)
      : type = _ChatEntryType.date,
        message = null,
        messageIndex = null;

  const _ChatEntry.message(this.message, this.messageIndex)
      : type = _ChatEntryType.message,
        date = null;

  const _ChatEntry.typing()
      : type = _ChatEntryType.typing,
        date = null,
        message = null,
        messageIndex = null;

  final _ChatEntryType type;
  final DateTime? date;
  final ChatMessage? message;
  final int? messageIndex;
}

class _ChatBackground extends StatelessWidget {
  const _ChatBackground({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return PravaBackground(isDark: isDark);
  }
}

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({
    required this.name,
    required this.subtitle,
    required this.initial,
  });

  final String name;
  final String subtitle;
  final String initial;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark
        ? Colors.black.withValues(alpha: 0.35)
        : Colors.white.withValues(alpha: 0.72);
    final border =
        isDark ? PravaColors.darkBorderSubtle : PravaColors.lightBorderSubtle;
    final primary =
        isDark ? PravaColors.darkTextPrimary : PravaColors.lightTextPrimary;
    final secondary =
        isDark ? PravaColors.darkTextSecondary : PravaColors.lightTextSecondary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: border),
            ),
            child: Row(
              children: [
                _HeaderAction(
                  icon: CupertinoIcons.back,
                  onTap: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  radius: 22,
                  backgroundColor:
                      PravaColors.accentPrimary.withValues(alpha: 0.18),
                  child: Text(
                    initial,
                    style: PravaTypography.h3.copyWith(
                      color: PravaColors.accentPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: PravaTypography.body.copyWith(
                          color: primary,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: PravaTypography.caption.copyWith(
                          color: secondary,
                        ),
                      ),
                    ],
                  ),
                ),
                _HeaderAction(
                  icon: CupertinoIcons.phone,
                  onTap: () {},
                ),
                const SizedBox(width: 6),
                _HeaderAction(
                  icon: CupertinoIcons.video_camera,
                  onTap: () {},
                ),
                const SizedBox(width: 6),
                _HeaderAction(
                  icon: CupertinoIcons.info,
                  onTap: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDark ? Colors.white10 : Colors.black12,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(
          icon,
          size: 18,
          color: PravaColors.accentPrimary,
        ),
      ),
    );
  }
}

class _EncryptionBanner extends StatelessWidget {
  const _EncryptionBanner();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark
        ? Colors.black.withValues(alpha: 0.22)
        : Colors.white.withValues(alpha: 0.75);
    final secondary =
        isDark ? PravaColors.darkTextSecondary : PravaColors.lightTextSecondary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                CupertinoIcons.lock_fill,
                size: 14,
                color: secondary,
              ),
              const SizedBox(width: 8),
              Text(
                'Messages are end-to-end encrypted',
                style: PravaTypography.caption.copyWith(color: secondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface =
        isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.08);
    final secondary =
        isDark ? PravaColors.darkTextSecondary : PravaColors.lightTextSecondary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            label,
            style: PravaTypography.caption.copyWith(color: secondary),
          ),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isDark,
    required this.primary,
    required this.secondary,
    required this.timeLabel,
    required this.showAvatar,
    required this.initial,
    required this.isFirst,
    required this.isLast,
    required this.onLongPress,
  });

  final ChatMessage message;
  final bool isDark;
  final Color primary;
  final Color secondary;
  final String timeLabel;
  final bool showAvatar;
  final String initial;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final isOutgoing = message.isOutgoing;
    final alignment =
        isOutgoing ? Alignment.centerRight : Alignment.centerLeft;
    final bubbleColor = isOutgoing
        ? null
        : (isDark ? Colors.white10 : Colors.white);
    final gradient = isOutgoing
        ? const LinearGradient(
            colors: [
              PravaColors.accentPrimary,
              PravaColors.accentMuted,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : null;
    final displayBody = message.isDeleted
        ? 'Message deleted'
        : (message.type == ChatMessageType.media
            ? 'Media message'
            : (message.body.trim().isEmpty
                ? 'Message unavailable'
                : message.body));
    final isEdited = message.editVersion > 0 && !message.isDeleted;
    final reactionSummary =
        _summarizeReactions(message.reactions);

    final radius = BorderRadius.only(
      topLeft: const Radius.circular(18),
      topRight: const Radius.circular(18),
      bottomLeft:
          Radius.circular(isOutgoing ? 18 : (isLast ? 6 : 18)),
      bottomRight:
          Radius.circular(isOutgoing ? (isLast ? 6 : 18) : 18),
    );

    final bubble = Container(
      constraints: const BoxConstraints(maxWidth: 280),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bubbleColor,
        gradient: gradient,
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isOutgoing ? 0.12 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            displayBody,
            style: PravaTypography.body.copyWith(
              color: isOutgoing ? Colors.white : primary,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                timeLabel,
                style: PravaTypography.caption.copyWith(
                  color: isOutgoing ? Colors.white70 : secondary,
                ),
              ),
              if (isEdited) ...[
                const SizedBox(width: 6),
                Text(
                  'Edited',
                  style: PravaTypography.caption.copyWith(
                    color: isOutgoing ? Colors.white70 : secondary,
                  ),
                ),
              ],
              if (isOutgoing &&
                  message.deliveryState == MessageDeliveryState.failed) ...[
                const SizedBox(width: 6),
                Text(
                  'Failed',
                  style: PravaTypography.caption.copyWith(
                    color: PravaColors.error,
                  ),
                ),
              ],
              if (isOutgoing) ...[
                const SizedBox(width: 4),
                _StatusIcon(
                  status: message.deliveryState,
                  color: message.deliveryState == MessageDeliveryState.read
                      ? Colors.white
                      : Colors.white70,
                ),
              ],
            ],
          ),
        ],
      ),
    );

    return Padding(
      padding: EdgeInsets.only(
        top: isFirst ? 10 : 2,
        bottom: isLast ? 6 : 2,
      ),
      child: Align(
        alignment: alignment,
        child: Row(
          mainAxisAlignment: isOutgoing
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isOutgoing) ...[
              if (showAvatar)
                CircleAvatar(
                  radius: 14,
                  backgroundColor:
                      PravaColors.accentPrimary.withValues(alpha: 0.18),
                  child: Text(
                    initial,
                    style: PravaTypography.caption.copyWith(
                      color: PravaColors.accentPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              else
                const SizedBox(width: 28),
              const SizedBox(width: 8),
            ],
            GestureDetector(
              onLongPress: onLongPress,
              child: Column(
                crossAxisAlignment: isOutgoing
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  bubble,
                  if (reactionSummary.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Wrap(
                        spacing: 6,
                        children: reactionSummary
                            .map(
                              (item) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: isOutgoing
                                      ? Colors.white24
                                      : Colors.black12,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${item.emoji} ${item.count}',
                                  style: PravaTypography.caption.copyWith(
                                    color:
                                        isOutgoing ? Colors.white : primary,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<_ReactionSummary> _summarizeReactions(
    List<ChatReaction> reactions,
  ) {
    final counts = <String, int>{};
    for (final reaction in reactions) {
      if (reaction.emoji.isEmpty) continue;
      counts[reaction.emoji] = (counts[reaction.emoji] ?? 0) + 1;
    }
    return counts.entries
        .map((entry) => _ReactionSummary(entry.key, entry.value))
        .toList();
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.status, required this.color});

  final MessageDeliveryState status;
  final Color color;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case MessageDeliveryState.sending:
        return Icon(CupertinoIcons.clock, size: 12, color: color);
      case MessageDeliveryState.sent:
        return Icon(Icons.check, size: 12, color: color);
      case MessageDeliveryState.delivered:
      case MessageDeliveryState.read:
        return Icon(Icons.done_all, size: 14, color: color);
      case MessageDeliveryState.failed:
        return Icon(
          CupertinoIcons.exclamationmark_circle,
          size: 12,
          color: PravaColors.error,
        );
    }
  }
}

class _ComposerBar extends StatelessWidget {
  const _ComposerBar({
    required this.controller,
    required this.focusNode,
    required this.onSend,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSend;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark
        ? Colors.black.withValues(alpha: 0.4)
        : Colors.white.withValues(alpha: 0.86);
    final border =
        isDark ? PravaColors.darkBorderSubtle : PravaColors.lightBorderSubtle;
    final primary =
        isDark ? PravaColors.darkTextPrimary : PravaColors.lightTextPrimary;
    final secondary =
        isDark ? PravaColors.darkTextSecondary : PravaColors.lightTextSecondary;

    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: border),
                ),
                child: Row(
                  children: [
                    _ComposerIcon(
                      icon: CupertinoIcons.smiley,
                      onTap: () {},
                    ),
                    Expanded(
                      child: TextField(
                        controller: controller,
                        focusNode: focusNode,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => onSend(),
                        onChanged: onChanged,
                        minLines: 1,
                        maxLines: 4,
                        style: PravaTypography.body.copyWith(color: primary),
                        decoration: InputDecoration(
                          hintText: 'Message',
                          hintStyle:
                              PravaTypography.body.copyWith(color: secondary),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                    _ComposerIcon(
                      icon: CupertinoIcons.photo,
                      onTap: () {},
                    ),
                    _ComposerIcon(
                      icon: CupertinoIcons.paperclip,
                      onTap: () {},
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, child) {
            final hasText = value.text.trim().isNotEmpty;
            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                if (hasText) {
                  onSend();
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [
                      PravaColors.accentPrimary,
                      PravaColors.accentMuted,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: PravaColors.accentPrimary.withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(
                  hasText
                      ? CupertinoIcons.paperplane_fill
                      : CupertinoIcons.mic_fill,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _ComposerIcon extends StatelessWidget {
  const _ComposerIcon({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return IconButton(
      icon: Icon(
        icon,
        size: 18,
        color: isDark
            ? PravaColors.darkTextSecondary
            : PravaColors.lightTextSecondary,
      ),
      onPressed: onTap,
    );
  }
}

class _ReactionSummary {
  final String emoji;
  final int count;

  const _ReactionSummary(this.emoji, this.count);
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface =
        isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06);
    final secondary =
        isDark ? PravaColors.darkTextSecondary : PravaColors.lightTextSecondary;

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            'typing...',
            style: PravaTypography.caption.copyWith(color: secondary),
          ),
        ),
      ),
    );
  }
}

class _EditingBanner extends StatelessWidget {
  const _EditingBanner({
    required this.preview,
    required this.onCancel,
  });

  final String preview;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface =
        isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06);
    final secondary =
        isDark ? PravaColors.darkTextSecondary : PravaColors.lightTextSecondary;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            CupertinoIcons.pencil,
            size: 16,
            color: PravaColors.accentPrimary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              preview,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: PravaTypography.caption.copyWith(color: secondary),
            ),
          ),
          IconButton(
            icon: Icon(
              CupertinoIcons.xmark_circle_fill,
              size: 18,
              color: secondary,
            ),
            onPressed: onCancel,
          ),
        ],
      ),
    );
  }
}

class _ReactionPicker extends StatelessWidget {
  const _ReactionPicker({required this.onSelect});

  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    const reactionCodePoints = <List<int>>[
      [0x1F44D],
      [0x2764, 0xFE0F],
      [0x1F602],
      [0x1F62E],
      [0x1F622],
      [0x1F64F],
    ];
    final reactions = reactionCodePoints
        .map((codes) => String.fromCharCodes(codes))
        .toList();
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: reactions
          .map(
            (emoji) => GestureDetector(
              onTap: () => onSelect(emoji),
              child: Text(
                emoji,
                style: const TextStyle(fontSize: 22),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _SheetAction extends StatelessWidget {
  const _SheetAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final color = isDestructive
        ? PravaColors.error
        : PravaColors.accentPrimary;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color),
      title: Text(
        label,
        style: PravaTypography.body.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
      onTap: onTap,
    );
  }
}
