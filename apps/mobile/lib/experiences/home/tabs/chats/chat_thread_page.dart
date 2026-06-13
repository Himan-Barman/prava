import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../ui-system/colors.dart';
import '../../../../ui-system/typography.dart';
import '../../../../ui-system/background.dart';
import '../../../../navigation/prava_navigator.dart';
import '../../../../services/chat_realtime.dart';
import '../../../../services/chat_service.dart';
import '../../../../services/chat_sync_store.dart';
import '../../../../services/e2ee_service.dart';
import '../../../../services/group_e2ee_service.dart';
import '../../../../services/media_service.dart';
import '../../../../security/ratchet/group/sender_key_state.dart';
import '../../../../core/device/device_id.dart';
import '../../../../core/storage/secure_store.dart';
import '../profile/public_profile_page.dart';
import 'chat_details_page.dart';
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
  late final MediaService _mediaService = MediaService(store: _store);
  late final ChatRealtime _realtime = ChatRealtime(store: _store);
  late final E2eeService _e2ee = E2eeService(store: _store);
  late final GroupE2eeService _groupE2ee = GroupE2eeService(
    store: _store,
    e2ee: _e2ee,
  );
  late final DeviceIdStore _deviceIdStore = DeviceIdStore(_store);
  final ImagePicker _imagePicker = ImagePicker();

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
  Timer? _draftTimer;
  bool _isTyping = false;
  bool _peerTyping = false;
  Timer? _peerTypingTimer;
  bool _isAtBottom = true;
  ChatMessage? _editingMessage;
  bool _peerOnline = false;
  DateTime? _peerLastSeenAt;
  bool _groupReady = false;
  bool _usingPlaintextFallback = false;
  bool _isMuted = false;
  bool _isStarred = false;
  bool _uploadingAttachment = false;
  final List<String> _recentEmojis = <String>[];
  List<String> _groupMemberIds = <String>[];
  final Set<String> _hiddenMessageIds = <String>{};
  final Set<String> _pinnedMessageIds = <String>{};
  final Set<String> _savedMessageIds = <String>{};

  bool get _isDmChat => !widget.chat.isGroup;
  bool get _isGroupChat => widget.chat.isGroup;
  bool get _isEncryptedChat => _isDmChat || _isGroupChat;

  @override
  void initState() {
    super.initState();
    _peerUserId = widget.chat.peerUserId.trim().isNotEmpty
        ? widget.chat.peerUserId.trim()
        : null;
    _peerLastSeenAt = widget.chat.peerLastSeenAt;
    _peerOnline = widget.chat.isOnline;
    _isMuted = widget.chat.isMuted;
    _isStarred = widget.chat.isStarred;
    if (widget.chat.draftText.trim().isNotEmpty) {
      _controller.text = widget.chat.draftText;
      _controller.selection = TextSelection.collapsed(
        offset: _controller.text.length,
      );
    }
    _scrollController.addListener(_handleScroll);
    _loadRecentEmojis();
    _bootstrap();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom(animated: false);
    });
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _draftTimer?.cancel();
    _peerTypingTimer?.cancel();
    if (_isTyping) {
      _realtime.sendTyping(conversationId: widget.chat.id, isTyping: false);
    }
    _syncDraft(_editingMessage == null ? _controller.text.trim() : '');
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
    await _loadPinnedMessages();
    await _loadSavedMessages();
    await _realtime.connect(_handleRealtimeEvent);
    _realtime.subscribeConversation(widget.chat.id);
  }

  Future<void> _resolvePeerUserId() async {
    if (!_isDmChat) return;
    if (_peerUserId != null && _peerUserId!.isNotEmpty) return;
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
      final pending = _messages
          .where((message) => message.seq == null)
          .toList();
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

  Future<void> _loadPinnedMessages() async {
    try {
      final pinned = await _chatService.listPinnedMessages(
        conversationId: widget.chat.id,
        limit: 20,
        currentUserId: _userId,
      );
      if (!mounted) return;
      setState(() {
        _pinnedMessageIds
          ..clear()
          ..addAll(
            pinned.map((message) => message.id).where((id) => id.isNotEmpty),
          );
      });
    } catch (_) {
      // Pinned messages are secondary metadata; the thread still works without them.
    }
  }

  Future<void> _loadSavedMessages() async {
    try {
      final saved = await _chatService.listSavedMessages(
        conversationId: widget.chat.id,
        limit: 80,
        currentUserId: _userId,
      );
      if (!mounted) return;
      setState(() {
        _savedMessageIds
          ..clear()
          ..addAll(
            saved.map((message) => message.id).where((id) => id.isNotEmpty),
          );
      });
    } catch (_) {
      // Saved messages are secondary metadata; the thread still works without them.
    }
  }

  Future<List<ChatMessage>> _decryptMessages(List<ChatMessage> messages) async {
    if (!_isEncryptedChat) return messages;
    final resolved = <ChatMessage>[];
    for (final message in messages) {
      resolved.add(await _decryptMessageIfNeeded(message));
    }
    return resolved;
  }

  Future<ChatMessage> _decryptMessageIfNeeded(ChatMessage message) async {
    if (!_isEncryptedChat) return message;
    final body = message.body;

    if (_isDmChat) {
      if (!E2eeService.isEncrypted(body)) return message;
      if (!_e2eeReady) {
        return message.copyWith(body: 'Encrypted message', encryptedBody: body);
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
        return message.copyWith(body: 'Encrypted message', encryptedBody: body);
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
    final senderDeviceId = _deviceId ?? await _deviceIdStore.getOrCreate();
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
    _syncDraft('');

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
      final prepared = await _prepareDmOutboundMessage(tempId, text);
      if (prepared == null || prepared.isEmpty) {
        _markFailed(tempId);
        return;
      }
      outboundBody = prepared;
    }

    try {
      final sent = await _chatService.sendMessage(
        conversationId: widget.chat.id,
        body: outboundBody,
        tempId: tempId,
        clientTimestamp: DateTime.now(),
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

  Future<void> _showAttachmentPicker() async {
    if (_uploadingAttachment) return;
    HapticFeedback.selectionClick();
    final action = await showCupertinoModalPopup<String>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Send attachment'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(context).pop('image'),
            child: const Text('Photo'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(context).pop('video'),
            child: const Text('Video'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
    if (!mounted || action == null) return;
    await _pickAndSendAttachment(isVideo: action == 'video');
  }

  Future<void> _pickAndSendAttachment({required bool isVideo}) async {
    if (_uploadingAttachment) return;
    XFile? picked;
    try {
      picked = isVideo
          ? await _imagePicker.pickVideo(source: ImageSource.gallery)
          : await _imagePicker.pickImage(
              source: ImageSource.gallery,
              imageQuality: 92,
            );
    } catch (_) {
      _showAttachmentError('Could not open media picker');
      return;
    }
    if (picked == null) return;

    setState(() => _uploadingAttachment = true);
    try {
      final bytes = await picked.readAsBytes();
      if (bytes.isEmpty) {
        throw Exception('empty attachment');
      }

      final fileName = picked.name.trim().isNotEmpty
          ? picked.name.trim()
          : (isVideo ? 'video.mp4' : 'photo.jpg');
      final mimeType = picked.mimeType?.trim().isNotEmpty == true
          ? picked.mimeType!.trim()
          : _mimeTypeForName(fileName, isVideo: isVideo);
      final attachmentType = isVideo ? 'video' : 'image';

      final init = await _chatService.initAttachmentUpload(
        conversationId: widget.chat.id,
        fileName: fileName,
        mimeType: mimeType,
        byteSize: bytes.length,
        attachmentType: attachmentType,
      );
      if (init == null || init.attachmentId.isEmpty) {
        throw Exception('attachment init failed');
      }
      if (init.maxBytes > 0 && bytes.length > init.maxBytes) {
        throw Exception('attachment too large');
      }

      final dataUri = 'data:$mimeType;base64,${base64Encode(bytes)}';
      final asset = await _mediaService.uploadChatMedia(
        dataUri: dataUri,
        resourceType: isVideo ? 'video' : 'image',
      );
      if (asset.assetId.isEmpty) {
        throw Exception('media upload failed');
      }

      final attachment = await _chatService.completeAttachmentUpload(
        attachmentId: init.attachmentId,
        uploadSessionId: init.uploadSessionId,
        mediaAssetId: asset.assetId,
      );
      final mediaAssetId = attachment?.mediaAssetId?.trim().isNotEmpty == true
          ? attachment!.mediaAssetId!.trim()
          : asset.assetId;
      await _sendMediaMessage(
        mediaAssetId: mediaAssetId,
        contentType: attachmentType,
        fallbackLabel: isVideo ? 'Video' : 'Photo',
      );
    } catch (error) {
      _showAttachmentError(
        error.toString().contains('too large')
            ? 'Attachment is too large'
            : 'Could not send attachment',
      );
    } finally {
      if (mounted) {
        setState(() => _uploadingAttachment = false);
      }
    }
  }

  Future<void> _sendMediaMessage({
    required String mediaAssetId,
    required String contentType,
    required String fallbackLabel,
  }) async {
    final tempId = _generateTempId();
    final caption = _controller.text.trim();
    final senderUserId = _userId ?? '';
    final senderDeviceId = _deviceId ?? await _deviceIdStore.getOrCreate();
    _deviceId ??= senderDeviceId;

    final message = ChatMessage(
      id: tempId,
      conversationId: widget.chat.id,
      senderUserId: senderUserId,
      senderDeviceId: senderDeviceId,
      body: caption.isEmpty ? fallbackLabel : caption,
      type: ChatMessageType.media,
      createdAt: DateTime.now(),
      clientTempId: tempId,
      mediaAssetId: mediaAssetId,
      deliveryState: MessageDeliveryState.sending,
      isOutgoing: true,
    );

    HapticFeedback.selectionClick();
    _stopTyping();
    setState(() {
      _messages = [..._messages, message];
      if (caption.isNotEmpty) {
        _controller.clear();
      }
    });
    if (caption.isNotEmpty) {
      _syncDraft('');
    }
    _scrollToBottom();

    String outboundBody = caption;
    if (caption.isNotEmpty) {
      if (_isGroupChat) {
        final encrypted = await _prepareGroupOutboundMessage(tempId, caption);
        if (encrypted == null || encrypted.isEmpty) {
          _markFailed(tempId);
          return;
        }
        outboundBody = encrypted;
      } else if (_isDmChat) {
        final prepared = await _prepareDmOutboundMessage(tempId, caption);
        if (prepared == null || prepared.isEmpty) {
          _markFailed(tempId);
          return;
        }
        outboundBody = prepared;
      }
    }

    try {
      final sent = await _chatService.sendMessage(
        conversationId: widget.chat.id,
        body: outboundBody,
        tempId: tempId,
        contentType: contentType,
        mediaAssetId: mediaAssetId,
        clientTimestamp: DateTime.now(),
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

  String _mimeTypeForName(String fileName, {required bool isVideo}) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.heic')) return 'image/heic';
    if (lower.endsWith('.mov')) return 'video/quicktime';
    if (lower.endsWith('.m4v')) return 'video/x-m4v';
    if (lower.endsWith('.webm')) return 'video/webm';
    if (lower.endsWith('.mp4')) return 'video/mp4';
    return isVideo ? 'video/mp4' : 'image/jpeg';
  }

  bool _isFallbackMediaLabel(String value) {
    final normalized = value.trim().toLowerCase();
    return normalized == 'photo' ||
        normalized == 'video' ||
        normalized == 'media attachment' ||
        normalized == 'media message';
  }

  void _showAttachmentError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  void _applyServerMessage(String tempId, ChatMessage serverMessage) {
    final index = _messages.indexWhere(
      (m) => m.clientTempId == tempId || m.id == tempId,
    );
    if (index == -1) return;

    final existing = _messages[index];
    final isEncrypted = _isEncryptedPayload(serverMessage.body);
    final serverBody =
        serverMessage.type == ChatMessageType.media &&
            serverMessage.body.trim().isEmpty
        ? existing.body
        : serverMessage.body;
    final updated = serverMessage.copyWith(
      body: isEncrypted ? existing.body : serverBody,
      encryptedBody: isEncrypted ? serverMessage.body : existing.encryptedBody,
      deliveryState: MessageDeliveryState.sent,
      isOutgoing: true,
      clientTempId: tempId,
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

    final isMediaMessage = message.type == ChatMessageType.media;
    final hasRealMediaCaption =
        isMediaMessage && !_isFallbackMediaLabel(message.body);
    final shouldEncryptBody = !isMediaMessage || hasRealMediaCaption;
    String outboundBody =
        isMediaMessage && !hasRealMediaCaption && message.encryptedBody == null
        ? ''
        : message.encryptedBody ?? message.body;
    if (_isGroupChat) {
      if (message.encryptedBody == null) {
        if (shouldEncryptBody) {
          final encrypted = await _prepareGroupOutboundMessage(
            message.id,
            message.body,
          );
          if (encrypted == null || encrypted.isEmpty) {
            _markFailed(tempId);
            return;
          }
          outboundBody = encrypted;
        }
      }
    } else if (_isDmChat) {
      if (message.encryptedBody == null) {
        if (shouldEncryptBody) {
          final prepared = await _prepareDmOutboundMessage(
            message.id,
            message.body,
          );
          if (prepared == null || prepared.isEmpty) {
            _markFailed(tempId);
            return;
          }
          outboundBody = prepared;
        }
      }
    }

    try {
      final sent = await _chatService.sendMessage(
        conversationId: widget.chat.id,
        body: outboundBody,
        tempId: tempId,
        contentType: message.type == ChatMessageType.media ? 'media' : 'text',
        mediaAssetId: message.mediaAssetId,
        clientTimestamp: DateTime.now(),
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
    final bundle = await _groupE2ee.ensureOwnSenderKey(groupId: widget.chat.id);
    if (bundle == null) return null;

    if (bundle.needsDistribution) {
      await _sendSenderKeyDistribution(senderKey: bundle.senderKey);
    }

    final result = await _groupE2ee.encryptGroupMessageWithKey(
      senderKey: bundle.senderKey,
      plaintext: plaintext,
    );
    if (result == null) return null;

    _updateMessage(messageId, (m) => m.copyWith(encryptedBody: result.body));

    return result.body;
  }

  Future<String?> _prepareDmOutboundMessage(
    String messageId,
    String plaintext,
  ) async {
    if (_peerUserId == null) {
      await _resolvePeerUserId();
    }
    await _ensureE2eeReady();

    final peerUserId = _peerUserId;
    if (!_e2eeReady || peerUserId == null || peerUserId.isEmpty) {
      _setPlaintextFallback(true);
      return plaintext;
    }

    try {
      final encrypted = await _e2ee.encryptBody(
        peerUserId: peerUserId,
        plaintext: plaintext,
      );
      if (encrypted == null || encrypted.isEmpty) {
        _setPlaintextFallback(true);
        return plaintext;
      }
      _setPlaintextFallback(false);
      _updateMessage(messageId, (m) => m.copyWith(encryptedBody: encrypted));
      return encrypted;
    } catch (_) {
      _setPlaintextFallback(true);
      return plaintext;
    }
  }

  void _setPlaintextFallback(bool value) {
    if (_usingPlaintextFallback == value) return;
    if (!mounted) {
      _usingPlaintextFallback = value;
      return;
    }
    setState(() => _usingPlaintextFallback = value);
  }

  Future<void> _sendSenderKeyDistribution({SenderKeyState? senderKey}) async {
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

      await _chatService.sendMessage(
        conversationId: widget.chat.id,
        body: envelope,
        contentType: 'system',
        tempId: _generateTempId(),
        clientTimestamp: DateTime.now(),
      );
    } catch (_) {}
  }

  String _generateTempId() {
    final rand = Random.secure();
    final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
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
      final encrypted = await _prepareGroupOutboundMessage(message.id, trimmed);
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

    if (!mounted) return;
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

  void _openPeerProfile() {
    final peerUserId = _peerUserId?.trim();
    if (!_isDmChat || peerUserId == null || peerUserId.isEmpty) return;
    HapticFeedback.selectionClick();
    PravaNavigator.push(context, PublicProfilePage(userId: peerUserId));
  }

  void _openConversationDetails() {
    final initial = widget.chat.name.isNotEmpty
        ? widget.chat.name[0].toUpperCase()
        : 'P';
    HapticFeedback.selectionClick();
    PravaNavigator.push<String>(
      context,
      ChatDetailsPage(
        conversationId: widget.chat.id,
        name: widget.chat.name,
        initial: initial,
        avatarUrl: widget.chat.avatarUrl,
        isGroup: widget.chat.isGroup,
        isMuted: _isMuted,
        isStarred: _isStarred,
        isArchived: widget.chat.isArchived,
        peerUserId: _peerUserId,
      ),
    ).then((result) {
      if (!mounted) return;
      if (result == 'cleared') {
        _applyLocalHistoryCleared();
        return;
      }
      if (result == 'deleted') {
        Navigator.of(context).maybePop('deleted');
      }
    });
  }

  Future<void> _showThreadOptions() async {
    HapticFeedback.selectionClick();
    final action = await showCupertinoModalPopup<String>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(widget.chat.name),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(context).pop('details'),
            child: const Text('Chat details'),
          ),
          if (_isDmChat)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.of(context).pop('profile'),
              child: const Text('View profile'),
            ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(context).pop('mute'),
            child: Text(
              _isMuted ? 'Unmute notifications' : 'Mute notifications',
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(context).pop('star'),
            child: Text(_isStarred ? 'Unstar chat' : 'Star chat'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(context).pop('saved'),
            child: const Text('Saved messages'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(context).pop('clear'),
            isDestructiveAction: true,
            child: const Text('Clear local view'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );

    if (!mounted || action == null) return;
    switch (action) {
      case 'details':
        _openConversationDetails();
        break;
      case 'profile':
        _openPeerProfile();
        break;
      case 'mute':
        await _updateThreadPreferences(isMuted: !_isMuted);
        break;
      case 'star':
        await _updateThreadPreferences(isStarred: !_isStarred);
        break;
      case 'saved':
        _showSavedMessages();
        break;
      case 'clear':
        await _clearLocalHistory();
        break;
    }
  }

  Future<void> _clearLocalHistory() async {
    HapticFeedback.selectionClick();
    try {
      final ok = await _chatService.clearLocalConversation(widget.chat.id);
      if (!ok) throw Exception('clear failed');
      if (!mounted) return;
      _applyLocalHistoryCleared();
    } catch (_) {
      _showThreadSnack('Could not clear chat');
    }
  }

  void _applyLocalHistoryCleared() {
    setState(() {
      _messages = <ChatMessage>[];
      _hiddenMessageIds.clear();
      _pinnedMessageIds.clear();
      _savedMessageIds.clear();
      _hasMore = false;
      _oldestSeq = null;
    });
    _showThreadSnack('Chat cleared on this device');
  }

  Future<void> _updateThreadPreferences({
    bool? isMuted,
    bool? isStarred,
  }) async {
    final previousMuted = _isMuted;
    final previousStarred = _isStarred;
    final nextMuted = isMuted ?? _isMuted;
    final nextStarred = isStarred ?? _isStarred;
    setState(() {
      _isMuted = nextMuted;
      _isStarred = nextStarred;
    });
    try {
      await _chatService.updatePreferences(
        conversationId: widget.chat.id,
        isFavorite: widget.chat.isFavorite,
        isStarred: nextStarred,
        isMuted: nextMuted,
        isArchived: widget.chat.isArchived,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isMuted = previousMuted;
        _isStarred = previousStarred;
      });
    }
  }

  Future<void> _loadRecentEmojis() async {
    try {
      final raw = await _store.getRecentEmojisJson();
      if (!mounted || raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      final emojis = decoded
          .map((item) => item.toString())
          .where((item) => item.trim().isNotEmpty)
          .take(48)
          .toList();
      if (emojis.isEmpty) return;
      setState(() {
        _recentEmojis
          ..clear()
          ..addAll(emojis);
      });
    } catch (_) {
      // Recent emojis are optional UI state.
    }
  }

  void _saveRecentEmojis() {
    void ignoreError(Object _, StackTrace __) {}
    _store
        .setRecentEmojisJson(jsonEncode(_recentEmojis))
        .then<void>((_) {})
        .catchError(ignoreError);
  }

  void _showEmojiPicker() {
    HapticFeedback.selectionClick();
    _composerFocus.unfocus();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) =>
          _EmojiPickerSheet(recent: _recentEmojis, onSelect: _insertEmoji),
    );
  }

  void _insertEmoji(String emoji) {
    if (emoji.isEmpty) return;
    final value = _controller.value;
    final start = value.selection.start >= 0
        ? value.selection.start
        : value.text.length;
    final end = value.selection.end >= 0 ? value.selection.end : start;
    final nextText = value.text.replaceRange(start, end, emoji);
    final nextOffset = start + emoji.length;
    _controller.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: nextOffset),
    );
    _handleTypingChanged(nextText);
    setState(() {
      _recentEmojis.remove(emoji);
      _recentEmojis.insert(0, emoji);
      if (_recentEmojis.length > 48) {
        _recentEmojis.removeRange(48, _recentEmojis.length);
      }
    });
    _saveRecentEmojis();
  }

  void _showMessageActions(ChatMessage message) {
    final canEdit =
        message.isOutgoing &&
        !message.isDeleted &&
        message.type == ChatMessageType.text &&
        message.seq != null;
    final canRetry =
        message.isOutgoing &&
        message.deliveryState == MessageDeliveryState.failed;
    final canCopy =
        !message.isDeleted &&
        message.type == ChatMessageType.text &&
        message.body.trim().isNotEmpty;
    final canDelete =
        message.isOutgoing && !message.isDeleted && message.seq != null;
    final canServerAction =
        !message.isDeleted &&
        message.seq != null &&
        message.id.trim().isNotEmpty;
    final isPinned = _pinnedMessageIds.contains(message.id);
    final isSaved = _savedMessageIds.contains(message.id);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: false,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final surface = isDark
            ? PravaColors.darkBgElevated
            : PravaColors.lightBgElevated;
        final border = isDark
            ? PravaColors.darkBorderSubtle
            : PravaColors.lightBorderSubtle;
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
                      Clipboard.setData(ClipboardData(text: message.body));
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
                if (canServerAction)
                  _SheetAction(
                    icon: isPinned
                        ? CupertinoIcons.pin_slash_fill
                        : CupertinoIcons.pin_fill,
                    label: isPinned ? 'Unpin message' : 'Pin message',
                    onTap: () {
                      Navigator.of(context).pop();
                      isPinned ? _unpinMessage(message) : _pinMessage(message);
                    },
                  ),
                if (canServerAction)
                  _SheetAction(
                    icon: isSaved
                        ? CupertinoIcons.bookmark
                        : CupertinoIcons.bookmark_fill,
                    label: isSaved ? 'Unsave message' : 'Save message',
                    onTap: () {
                      Navigator.of(context).pop();
                      isSaved ? _unsaveMessage(message) : _saveMessage(message);
                    },
                  ),
                if (canServerAction)
                  _SheetAction(
                    icon: CupertinoIcons.info_circle,
                    label: 'Message details',
                    onTap: () {
                      Navigator.of(context).pop();
                      _showMessageDetails(message);
                    },
                  ),
                if (canServerAction)
                  _SheetAction(
                    icon: CupertinoIcons.exclamationmark_bubble,
                    label: 'Report',
                    isDestructive: true,
                    onTap: () {
                      Navigator.of(context).pop();
                      _reportMessage(message);
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

  Future<void> _pinMessage(ChatMessage message) async {
    HapticFeedback.selectionClick();
    setState(() => _pinnedMessageIds.add(message.id));
    try {
      final ok = await _chatService.pinMessage(
        conversationId: widget.chat.id,
        messageId: message.id,
      );
      if (!ok) throw Exception('pin failed');
      _showThreadSnack('Message pinned');
    } catch (_) {
      if (!mounted) return;
      setState(() => _pinnedMessageIds.remove(message.id));
      _showThreadSnack('Could not pin message');
    }
  }

  Future<void> _unpinMessage(ChatMessage message) async {
    HapticFeedback.selectionClick();
    final wasPinned = _pinnedMessageIds.contains(message.id);
    setState(() => _pinnedMessageIds.remove(message.id));
    try {
      final ok = await _chatService.unpinMessage(
        conversationId: widget.chat.id,
        messageId: message.id,
      );
      if (!ok) throw Exception('unpin failed');
      _showThreadSnack('Message unpinned');
    } catch (_) {
      if (!mounted) return;
      if (wasPinned) {
        setState(() => _pinnedMessageIds.add(message.id));
      }
      _showThreadSnack('Could not unpin message');
    }
  }

  Future<void> _saveMessage(ChatMessage message) async {
    HapticFeedback.selectionClick();
    setState(() => _savedMessageIds.add(message.id));
    try {
      final ok = await _chatService.saveMessage(
        conversationId: widget.chat.id,
        messageId: message.id,
      );
      if (!ok) throw Exception('save failed');
      _showThreadSnack('Message saved');
    } catch (_) {
      if (!mounted) return;
      setState(() => _savedMessageIds.remove(message.id));
      _showThreadSnack('Could not save message');
    }
  }

  Future<void> _unsaveMessage(ChatMessage message) async {
    HapticFeedback.selectionClick();
    final wasSaved = _savedMessageIds.contains(message.id);
    setState(() => _savedMessageIds.remove(message.id));
    try {
      final ok = await _chatService.unsaveMessage(
        conversationId: widget.chat.id,
        messageId: message.id,
      );
      if (!ok) throw Exception('unsave failed');
      _showThreadSnack('Message removed from saved');
    } catch (_) {
      if (!mounted) return;
      if (wasSaved) {
        setState(() => _savedMessageIds.add(message.id));
      }
      _showThreadSnack('Could not unsave message');
    }
  }

  Future<void> _reportMessage(ChatMessage message) async {
    final reason = await showCupertinoModalPopup<String>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Report message'),
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
            onPressed: () => Navigator.of(context).pop('harmful_content'),
            child: const Text('Harmful content'),
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
    if (!mounted || reason == null) return;
    try {
      final ok = await _chatService.reportConversation(
        conversationId: widget.chat.id,
        messageId: message.id,
        reportedUserId: message.senderUserId == _userId
            ? null
            : message.senderUserId,
        reason: reason,
      );
      if (!ok) throw Exception('report failed');
      _showThreadSnack('Report sent');
    } catch (_) {
      _showThreadSnack('Could not send report');
    }
  }

  void _showMessageDetails(ChatMessage message) {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _MessageDetailsSheet(
        message: message,
        details: _chatService.getMessageDetails(
          conversationId: widget.chat.id,
          messageId: message.id,
        ),
        timeLabel: _formatTime(message.createdAt),
        isPinned: _pinnedMessageIds.contains(message.id),
      ),
    );
  }

  void _openMessageSearch() {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _MessageSearchSheet(
        title: 'Search chat',
        chatService: _chatService,
        conversationId: widget.chat.id,
        currentUserId: _userId,
        onOpenDetails: _showMessageDetails,
      ),
    );
  }

  void _showPinnedMessages() {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _PinnedMessagesSheet(
        chatService: _chatService,
        conversationId: widget.chat.id,
        currentUserId: _userId,
        onOpenDetails: _showMessageDetails,
      ),
    );
  }

  void _showSavedMessages() {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _SavedMessagesSheet(
        chatService: _chatService,
        conversationId: widget.chat.id,
        currentUserId: _userId,
        onOpenDetails: _showMessageDetails,
      ),
    );
  }

  void _showThreadSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  void _setReaction(ChatMessage message, String emoji) {
    final userId = _userId;
    if (userId == null || emoji.isEmpty) return;

    final existingIndex = message.reactions.indexWhere(
      (r) => r.userId == userId,
    );
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

    _updateMessage(message.id, (m) => m.copyWith(reactions: nextReactions));
  }

  void _handleTypingChanged(String value) {
    _scheduleDraftSync(value);
    final hasText = value.trim().isNotEmpty;

    if (hasText && !_isTyping) {
      _isTyping = true;
      _realtime.sendTyping(conversationId: widget.chat.id, isTyping: true);
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

  void _scheduleDraftSync(String value) {
    if (_editingMessage != null) return;
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 700), () {
      _syncDraft(value.trim());
    });
  }

  void _syncDraft(String value) {
    void ignoreError(Object _, StackTrace __) {}
    _chatService
        .updatePreferences(conversationId: widget.chat.id, draftText: value)
        .then<void>((_) {})
        .catchError(ignoreError);
  }

  void _stopTyping() {
    if (!_isTyping) return;
    _isTyping = false;
    _realtime.sendTyping(conversationId: widget.chat.id, isTyping: false);
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
      case 'MESSAGE_PINNED':
        _handlePinnedUpdate(payload, pinned: true);
        break;
      case 'MESSAGE_UNPINNED':
        _handlePinnedUpdate(payload, pinned: false);
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

    final message = ChatMessage.fromJson({
      'id': payload['messageId'],
      'clientMessageId': payload['clientMessageId'],
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
    }, currentUserId: _userId);
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
      final clientMessageId = resolved.clientTempId;
      final existingIndex = _messages.indexWhere(
        (m) =>
            m.id == resolved.id ||
            m.clientTempId == resolved.id ||
            (clientMessageId != null && m.clientTempId == clientMessageId),
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

    final index = _messages.indexWhere(
      (m) => m.clientTempId == tempId || m.id == tempId,
    );
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
    } else if (_isGroupChat && GroupE2eeService.isGroupEncrypted(body)) {
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

    _updateDeliveryStates(lastReadSeq, MessageDeliveryState.read);
  }

  void _handleDeliveryUpdate(Map<String, dynamic> payload) {
    final conversationId = payload['conversationId']?.toString();
    final lastDeliveredSeq = _parseInt(payload['lastDeliveredSeq']);
    if (conversationId != widget.chat.id || lastDeliveredSeq == null) return;

    _updateDeliveryStates(lastDeliveredSeq, MessageDeliveryState.delivered);
  }

  void _handleReactionUpdate(Map<String, dynamic> payload) {
    final conversationId = payload['conversationId']?.toString();
    final messageId = payload['messageId']?.toString();
    final userId = payload['userId']?.toString() ?? '';
    final emoji = payload['emoji']?.toString();
    if (conversationId != widget.chat.id || messageId == null) return;

    _updateMessage(messageId, (message) {
      final existingIndex = message.reactions.indexWhere(
        (r) => r.userId == userId,
      );
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
        nextReactions[existingIndex] = nextReactions[existingIndex].copyWith(
          emoji: emoji,
          updatedAt: updatedAt,
        );
      }

      return message.copyWith(reactions: nextReactions);
    });
  }

  void _handlePinnedUpdate(
    Map<String, dynamic> payload, {
    required bool pinned,
  }) {
    final conversationId = payload['conversationId']?.toString();
    final messageId = payload['messageId']?.toString();
    if (conversationId != widget.chat.id || messageId == null) return;
    if (!mounted) return;
    setState(() {
      if (pinned) {
        _pinnedMessageIds.add(messageId);
      } else {
        _pinnedMessageIds.remove(messageId);
      }
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
      _peerTypingTimer = Timer(const Duration(seconds: 4), () {
        if (!mounted) return;
        setState(() => _peerTyping = false);
      });
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
      setState(() {
        _peerOnline = isOnline;
        if (!isOnline) {
          _peerLastSeenAt = DateTime.now();
        }
      });
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

  void _updateDeliveryStates(int lastSeq, MessageDeliveryState state) {
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
      final filtered = data.where((m) => !existingIds.contains(m.id)).toList();
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

  String _formatDate(DateTime value) {
    final date = value.toLocal();
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

  String _formatTime(DateTime value) {
    final date = value.toLocal();
    final hour = date.hour;
    final minute = date.minute.toString().padLeft(2, '0');
    final suffix = hour >= 12 ? 'PM' : 'AM';
    final hour12 = hour % 12 == 0 ? 12 : hour % 12;
    return '$hour12:$minute $suffix';
  }

  String _formatActivityStatus() {
    if (_isGroupChat) {
      return _peerTyping ? 'Someone is typing...' : 'Group chat';
    }
    if (_peerTyping) return 'Typing...';
    if (_peerOnline) return 'Online';

    final seenAt = _peerLastSeenAt;
    if (seenAt == null) return 'Active recently';

    final now = DateTime.now();
    final diff = now.difference(seenAt);
    if (diff.inDays >= 7) {
      return 'Last active ${_formatDate(seenAt)}';
    }
    if (diff.inDays >= 1) {
      final days = diff.inDays;
      return 'Last active $days ${days == 1 ? 'day' : 'days'} ago';
    }
    return 'Last active ${_formatTime(seenAt)}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark
        ? PravaColors.darkTextPrimary
        : PravaColors.lightTextPrimary;
    final secondary = isDark
        ? PravaColors.darkTextSecondary
        : PravaColors.lightTextSecondary;
    final visibleMessages = _visibleMessages();
    final entries = _buildEntries(visibleMessages);
    final initial = widget.chat.name.isNotEmpty
        ? widget.chat.name[0].toUpperCase()
        : 'P';
    final subtitle = _formatActivityStatus();

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: isDark
          ? PravaColors.darkBgMain
          : PravaColors.lightBgMain,
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
                    avatarUrl: widget.chat.avatarUrl,
                    onTap: _openConversationDetails,
                    onSearch: _openMessageSearch,
                    onMore: _showThreadOptions,
                  ),
                  if (_pinnedMessageIds.isNotEmpty)
                    _PinnedBanner(
                      count: _pinnedMessageIds.length,
                      onTap: _showPinnedMessages,
                    ),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: _loading
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: PravaColors.accentPrimary,
                              ),
                            )
                          : ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                12,
                                16,
                                16,
                              ),
                              physics: const BouncingScrollPhysics(
                                parent: AlwaysScrollableScrollPhysics(),
                              ),
                              itemCount: entries.length,
                              itemBuilder: (context, index) {
                                final entry = entries[index];
                                switch (entry.type) {
                                  case _ChatEntryType.loading:
                                    return const Padding(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 8,
                                      ),
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
                                    return _EncryptionBanner(
                                      fallback: _usingPlaintextFallback,
                                    );
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
                                        messageIndex <
                                            visibleMessages.length - 1
                                        ? visibleMessages[messageIndex + 1]
                                        : null;
                                    final isFirst =
                                        prev == null ||
                                        !_isSameBlock(prev, message);
                                    final isLast =
                                        next == null ||
                                        !_isSameBlock(message, next);
                                    final showAvatar =
                                        !message.isOutgoing && isLast;
                                    return _MessageBubble(
                                      message: message,
                                      isDark: isDark,
                                      primary: primary,
                                      secondary: secondary,
                                      timeLabel: _formatTime(message.createdAt),
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
                  Padding(
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
                          onEmoji: _showEmojiPicker,
                          onAttach: _showAttachmentPicker,
                          onSend: () {
                            _sendMessage();
                          },
                          onChanged: _handleTypingChanged,
                          isUploading: _uploadingAttachment,
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
    required this.avatarUrl,
    required this.onTap,
    required this.onSearch,
    required this.onMore,
  });

  final String name;
  final String subtitle;
  final String initial;
  final String avatarUrl;
  final VoidCallback onTap;
  final VoidCallback onSearch;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border = isDark
        ? PravaColors.darkBorderSubtle
        : PravaColors.lightBorderSubtle;
    final primary = isDark
        ? PravaColors.darkTextPrimary
        : PravaColors.lightTextPrimary;
    final secondary = isDark
        ? PravaColors.darkTextSecondary
        : PravaColors.lightTextSecondary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Row(
              children: [
                SizedBox(
                  width: 48,
                  height: 48,
                  child: ClipOval(
                    child: avatarUrl.trim().isNotEmpty
                        ? Image.network(avatarUrl, fit: BoxFit.cover)
                        : Container(
                            color: PravaColors.accentPrimary.withValues(
                              alpha: 0.18,
                            ),
                            child: Center(
                              child: Text(
                                initial,
                                style: PravaTypography.h3.copyWith(
                                  color: PravaColors.accentPrimary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
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
                          fontWeight: FontWeight.w700,
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onSearch,
                  icon: Icon(CupertinoIcons.search, color: secondary, size: 21),
                ),
                IconButton(
                  onPressed: onMore,
                  icon: Icon(
                    CupertinoIcons.ellipsis_vertical,
                    color: secondary,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(height: 1, color: border),
        ],
      ),
    );
  }
}

class _PinnedBanner extends StatelessWidget {
  const _PinnedBanner({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark
        ? PravaColors.darkBgElevated
        : PravaColors.lightBgElevated;
    final border = isDark
        ? PravaColors.darkBorderSubtle
        : PravaColors.lightBorderSubtle;
    final primary = isDark
        ? PravaColors.darkTextPrimary
        : PravaColors.lightTextPrimary;
    final secondary = isDark
        ? PravaColors.darkTextSecondary
        : PravaColors.lightTextSecondary;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            const Icon(
              CupertinoIcons.pin_fill,
              color: PravaColors.accentPrimary,
              size: 17,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                count == 1 ? '1 pinned message' : '$count pinned messages',
                style: PravaTypography.body.copyWith(
                  color: primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              'View',
              style: PravaTypography.caption.copyWith(color: secondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageDetailsSheet extends StatelessWidget {
  const _MessageDetailsSheet({
    required this.message,
    required this.details,
    required this.timeLabel,
    required this.isPinned,
  });

  final ChatMessage message;
  final Future<Map<String, dynamic>?> details;
  final String timeLabel;
  final bool isPinned;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark
        ? PravaColors.darkBgElevated
        : PravaColors.lightBgElevated;
    final border = isDark
        ? PravaColors.darkBorderSubtle
        : PravaColors.lightBorderSubtle;
    final primary = isDark
        ? PravaColors.darkTextPrimary
        : PravaColors.lightTextPrimary;
    final secondary = isDark
        ? PravaColors.darkTextSecondary
        : PravaColors.lightTextSecondary;

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(18),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.76,
        ),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: border),
        ),
        child: FutureBuilder<Map<String, dynamic>?>(
          future: details,
          builder: (context, snapshot) {
            final rows = (snapshot.data?['receipts'] as List<dynamic>? ?? [])
                .whereType<Map<String, dynamic>>()
                .toList();
            final seenCount = rows.where((row) => row['seen'] == true).length;
            final deliveredCount = rows
                .where((row) => row['delivered'] == true)
                .length;

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Message details',
                        style: PravaTypography.h3.copyWith(color: primary),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(CupertinoIcons.xmark, color: secondary),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _DetailMetricRow(
                  icon: CupertinoIcons.clock_fill,
                  title: 'Sent',
                  value: timeLabel,
                ),
                _DetailMetricRow(
                  icon: CupertinoIcons.check_mark_circled_solid,
                  title: 'Delivered',
                  value: snapshot.connectionState == ConnectionState.waiting
                      ? 'Loading'
                      : deliveredCount.toString(),
                ),
                _DetailMetricRow(
                  icon: CupertinoIcons.eye_fill,
                  title: 'Seen',
                  value: snapshot.connectionState == ConnectionState.waiting
                      ? 'Loading'
                      : seenCount.toString(),
                ),
                if (isPinned)
                  const _DetailMetricRow(
                    icon: CupertinoIcons.pin_fill,
                    title: 'Pinned',
                    value: 'Yes',
                  ),
                const SizedBox(height: 12),
                Text(
                  'Receipts',
                  style: PravaTypography.label.copyWith(color: secondary),
                ),
                const SizedBox(height: 8),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(
                        color: PravaColors.accentPrimary,
                      ),
                    ),
                  )
                else if (rows.isEmpty)
                  Text(
                    'No receipt data yet',
                    style: PravaTypography.body.copyWith(color: secondary),
                  )
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: rows.length,
                      itemBuilder: (context, index) {
                        final row = rows[index];
                        final userId = row['userId']?.toString() ?? '';
                        final seen = row['seen'] == true;
                        final delivered = row['delivered'] == true;
                        final state = seen
                            ? 'Seen'
                            : delivered
                            ? 'Delivered'
                            : 'Pending';
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            seen
                                ? CupertinoIcons.eye_fill
                                : delivered
                                ? CupertinoIcons.check_mark_circled_solid
                                : CupertinoIcons.clock,
                            color: seen || delivered
                                ? PravaColors.accentPrimary
                                : secondary,
                          ),
                          title: Text(
                            userId,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: PravaTypography.body.copyWith(
                              color: primary,
                            ),
                          ),
                          trailing: Text(
                            state,
                            style: PravaTypography.caption.copyWith(
                              color: secondary,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DetailMetricRow extends StatelessWidget {
  const _DetailMetricRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark
        ? PravaColors.darkTextPrimary
        : PravaColors.lightTextPrimary;
    final secondary = isDark
        ? PravaColors.darkTextSecondary
        : PravaColors.lightTextSecondary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(icon, color: PravaColors.accentPrimary, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: PravaTypography.body.copyWith(color: primary),
            ),
          ),
          Text(
            value,
            style: PravaTypography.caption.copyWith(color: secondary),
          ),
        ],
      ),
    );
  }
}

class _MessageSearchSheet extends StatefulWidget {
  const _MessageSearchSheet({
    required this.title,
    required this.chatService,
    required this.conversationId,
    required this.currentUserId,
    required this.onOpenDetails,
  });

  final String title;
  final ChatService chatService;
  final String conversationId;
  final String? currentUserId;
  final ValueChanged<ChatMessage> onOpenDetails;

  @override
  State<_MessageSearchSheet> createState() => _MessageSearchSheetState();
}

class _MessageSearchSheetState extends State<_MessageSearchSheet> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  bool _loading = false;
  List<ChatMessage> _results = <ChatMessage>[];

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    final query = value.trim();
    if (query.length < 2) {
      setState(() {
        _loading = false;
        _results = <ChatMessage>[];
      });
      return;
    }
    setState(() => _loading = true);
    _debounce = Timer(const Duration(milliseconds: 360), () {
      _runSearch(query);
    });
  }

  Future<void> _runSearch(String query) async {
    try {
      final results = await widget.chatService.searchMessages(
        conversationId: widget.conversationId,
        query: query,
        limit: 40,
        currentUserId: widget.currentUserId,
      );
      if (!mounted || _controller.text.trim() != query) return;
      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _results = <ChatMessage>[];
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _MessageListSheetFrame(
      title: widget.title,
      child: Column(
        children: [
          CupertinoSearchTextField(
            controller: _controller,
            placeholder: 'Search messages',
            onChanged: _onChanged,
          ),
          const SizedBox(height: 14),
          if (_loading)
            const Expanded(
              child: Center(
                child: CircularProgressIndicator(
                  color: PravaColors.accentPrimary,
                ),
              ),
            )
          else if (_controller.text.trim().length < 2)
            const Expanded(
              child: _SheetEmptyState(text: 'Type at least 2 characters'),
            )
          else if (_results.isEmpty)
            const Expanded(child: _SheetEmptyState(text: 'No messages found'))
          else
            Expanded(
              child: ListView.builder(
                itemCount: _results.length,
                itemBuilder: (context, index) => _MessageResultTile(
                  message: _results[index],
                  onTap: () {
                    Navigator.of(context).pop();
                    widget.onOpenDetails(_results[index]);
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PinnedMessagesSheet extends StatelessWidget {
  const _PinnedMessagesSheet({
    required this.chatService,
    required this.conversationId,
    required this.currentUserId,
    required this.onOpenDetails,
  });

  final ChatService chatService;
  final String conversationId;
  final String? currentUserId;
  final ValueChanged<ChatMessage> onOpenDetails;

  @override
  Widget build(BuildContext context) {
    return _MessageListSheetFrame(
      title: 'Pinned messages',
      child: FutureBuilder<List<ChatMessage>>(
        future: chatService.listPinnedMessages(
          conversationId: conversationId,
          limit: 50,
          currentUserId: currentUserId,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: PravaColors.accentPrimary,
              ),
            );
          }
          final messages = snapshot.data ?? <ChatMessage>[];
          if (messages.isEmpty) {
            return const _SheetEmptyState(text: 'No pinned messages');
          }
          return ListView.builder(
            itemCount: messages.length,
            itemBuilder: (context, index) => _MessageResultTile(
              message: messages[index],
              onTap: () {
                Navigator.of(context).pop();
                onOpenDetails(messages[index]);
              },
            ),
          );
        },
      ),
    );
  }
}

class _SavedMessagesSheet extends StatelessWidget {
  const _SavedMessagesSheet({
    required this.chatService,
    required this.conversationId,
    required this.currentUserId,
    required this.onOpenDetails,
  });

  final ChatService chatService;
  final String conversationId;
  final String? currentUserId;
  final ValueChanged<ChatMessage> onOpenDetails;

  @override
  Widget build(BuildContext context) {
    return _MessageListSheetFrame(
      title: 'Saved messages',
      child: FutureBuilder<List<ChatMessage>>(
        future: chatService.listSavedMessages(
          conversationId: conversationId,
          limit: 80,
          currentUserId: currentUserId,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: PravaColors.accentPrimary,
              ),
            );
          }
          final messages = snapshot.data ?? <ChatMessage>[];
          if (messages.isEmpty) {
            return const _SheetEmptyState(text: 'No saved messages');
          }
          return ListView.builder(
            itemCount: messages.length,
            itemBuilder: (context, index) => _MessageResultTile(
              message: messages[index],
              onTap: () {
                Navigator.of(context).pop();
                onOpenDetails(messages[index]);
              },
            ),
          );
        },
      ),
    );
  }
}

class _MessageListSheetFrame extends StatelessWidget {
  const _MessageListSheetFrame({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark
        ? PravaColors.darkBgElevated
        : PravaColors.lightBgElevated;
    final border = isDark
        ? PravaColors.darkBorderSubtle
        : PravaColors.lightBorderSubtle;
    final primary = isDark
        ? PravaColors.darkTextPrimary
        : PravaColors.lightTextPrimary;
    final secondary = isDark
        ? PravaColors.darkTextSecondary
        : PravaColors.lightTextSecondary;

    return SafeArea(
      child: Container(
        height: MediaQuery.of(context).size.height * 0.72,
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: border),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: PravaTypography.h3.copyWith(color: primary),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(CupertinoIcons.xmark, color: secondary),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

class _MessageResultTile extends StatelessWidget {
  const _MessageResultTile({required this.message, required this.onTap});

  final ChatMessage message;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark
        ? PravaColors.darkTextPrimary
        : PravaColors.lightTextPrimary;
    final secondary = isDark
        ? PravaColors.darkTextSecondary
        : PravaColors.lightTextSecondary;
    final body = message.isDeleted
        ? 'Message deleted'
        : message.body.trim().isEmpty
        ? 'Media attachment'
        : message.body.trim();

    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      leading: Icon(
        message.type == ChatMessageType.media
            ? CupertinoIcons.photo_fill
            : CupertinoIcons.text_bubble_fill,
        color: PravaColors.accentPrimary,
      ),
      title: Text(
        body,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: PravaTypography.body.copyWith(color: primary),
      ),
      subtitle: Text(
        _compactDateTime(message.createdAt),
        style: PravaTypography.caption.copyWith(color: secondary),
      ),
    );
  }
}

class _SheetEmptyState extends StatelessWidget {
  const _SheetEmptyState({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).brightness == Brightness.dark
        ? PravaColors.darkTextSecondary
        : PravaColors.lightTextSecondary;
    return Center(
      child: Text(text, style: PravaTypography.body.copyWith(color: secondary)),
    );
  }
}

String _compactDateTime(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '${value.day}/${value.month}/${value.year} $hour:$minute';
}

class _EncryptionBanner extends StatelessWidget {
  const _EncryptionBanner({required this.fallback});

  final bool fallback;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark
        ? Colors.black.withValues(alpha: 0.22)
        : Colors.white.withValues(alpha: 0.75);
    final secondary = isDark
        ? PravaColors.darkTextSecondary
        : PravaColors.lightTextSecondary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Center(
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width - 48,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(CupertinoIcons.lock_fill, size: 14, color: secondary),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  fallback
                      ? 'Encryption will start when device keys are available'
                      : 'Secure message transport active',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: PravaTypography.caption.copyWith(color: secondary),
                ),
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
    final surface = isDark
        ? Colors.white10
        : Colors.black.withValues(alpha: 0.08);
    final secondary = isDark
        ? PravaColors.darkTextSecondary
        : PravaColors.lightTextSecondary;

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
    final alignment = isOutgoing ? Alignment.centerRight : Alignment.centerLeft;
    final bubbleColor = isOutgoing
        ? null
        : (isDark ? Colors.white10 : Colors.white);
    final gradient = isOutgoing
        ? const LinearGradient(
            colors: [PravaColors.accentPrimary, PravaColors.accentMuted],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : null;
    final isMedia = message.type == ChatMessageType.media;
    final displayBody = message.isDeleted
        ? 'Message deleted'
        : (isMedia
              ? (message.body.trim().isEmpty
                    ? 'Media attachment'
                    : message.body)
              : (message.body.trim().isEmpty
                    ? 'Message unavailable'
                    : message.body));
    final isEdited = message.editVersion > 0 && !message.isDeleted;
    final reactionSummary = _summarizeReactions(message.reactions);

    final radius = BorderRadius.only(
      topLeft: const Radius.circular(18),
      topRight: const Radius.circular(18),
      bottomLeft: Radius.circular(isOutgoing ? 18 : (isLast ? 6 : 18)),
      bottomRight: Radius.circular(isOutgoing ? (isLast ? 6 : 18) : 18),
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
          if (isMedia && !message.isDeleted)
            _MediaMessageContent(
              label: displayBody,
              color: isOutgoing ? Colors.white : primary,
            )
          else
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
      padding: EdgeInsets.only(top: isFirst ? 10 : 2, bottom: isLast ? 6 : 2),
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
                  backgroundColor: PravaColors.accentPrimary.withValues(
                    alpha: 0.18,
                  ),
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
                                    color: isOutgoing ? Colors.white : primary,
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

  List<_ReactionSummary> _summarizeReactions(List<ChatReaction> reactions) {
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

class _MediaMessageContent extends StatelessWidget {
  const _MediaMessageContent({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(CupertinoIcons.photo_fill, size: 18, color: color),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            label,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: PravaTypography.body.copyWith(color: color),
          ),
        ),
      ],
    );
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
        return const Icon(
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
    required this.onEmoji,
    required this.onAttach,
    required this.onSend,
    required this.onChanged,
    required this.isUploading,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onEmoji;
  final VoidCallback onAttach;
  final VoidCallback onSend;
  final ValueChanged<String> onChanged;
  final bool isUploading;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark
        ? Colors.black.withValues(alpha: 0.4)
        : Colors.white.withValues(alpha: 0.86);
    final border = isDark
        ? PravaColors.darkBorderSubtle
        : PravaColors.lightBorderSubtle;
    final primary = isDark
        ? PravaColors.darkTextPrimary
        : PravaColors.lightTextPrimary;
    final secondary = isDark
        ? PravaColors.darkTextSecondary
        : PravaColors.lightTextSecondary;

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
                    _ComposerIcon(icon: CupertinoIcons.smiley, onTap: onEmoji),
                    _ComposerIcon(
                      icon: CupertinoIcons.paperclip,
                      onTap: isUploading ? () {} : onAttach,
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
                          hintStyle: PravaTypography.body.copyWith(
                            color: secondary,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                    if (isUploading)
                      const Padding(
                        padding: EdgeInsets.only(right: 10),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: PravaColors.accentPrimary,
                          ),
                        ),
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
            final buttonColor = hasText
                ? PravaColors.accentPrimary
                : (isDark ? Colors.white12 : Colors.black12);
            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                if (hasText) {
                  onSend();
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: buttonColor,
                  boxShadow: hasText
                      ? [
                          BoxShadow(
                            color: PravaColors.accentPrimary.withValues(
                              alpha: 0.28,
                            ),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  CupertinoIcons.paperplane_fill,
                  color: hasText ? Colors.white : secondary,
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
    final surface = isDark
        ? Colors.white10
        : Colors.black.withValues(alpha: 0.06);
    final secondary = isDark
        ? PravaColors.darkTextSecondary
        : PravaColors.lightTextSecondary;

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
  const _EditingBanner({required this.preview, required this.onCancel});

  final String preview;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark
        ? Colors.white10
        : Colors.black.withValues(alpha: 0.06);
    final secondary = isDark
        ? PravaColors.darkTextSecondary
        : PravaColors.lightTextSecondary;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(
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
              child: Text(emoji, style: const TextStyle(fontSize: 22)),
            ),
          )
          .toList(),
    );
  }
}

class _EmojiPickerSheet extends StatefulWidget {
  const _EmojiPickerSheet({required this.recent, required this.onSelect});

  final List<String> recent;
  final ValueChanged<String> onSelect;

  @override
  State<_EmojiPickerSheet> createState() => _EmojiPickerSheetState();
}

class _EmojiPickerSheetState extends State<_EmojiPickerSheet> {
  late final List<String> _recent = List<String>.from(widget.recent);
  int _selected = 0;

  List<_EmojiCategory> get _categories => [
    _EmojiCategory(label: 'Recent', icon: Icons.access_time, emojis: _recent),
    ..._emojiCategories,
  ];

  void _select(String emoji) {
    widget.onSelect(emoji);
    setState(() {
      _recent.remove(emoji);
      _recent.insert(0, emoji);
      if (_recent.length > 48) {
        _recent.removeRange(48, _recent.length);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark
        ? PravaColors.darkBgElevated
        : PravaColors.lightBgElevated;
    final border = isDark
        ? PravaColors.darkBorderSubtle
        : PravaColors.lightBorderSubtle;
    final primary = isDark
        ? PravaColors.darkTextPrimary
        : PravaColors.lightTextPrimary;
    final secondary = isDark
        ? PravaColors.darkTextSecondary
        : PravaColors.lightTextSecondary;
    final categories = _categories;
    final selected = categories[_selected];

    return SafeArea(
      top: false,
      child: Container(
        height: min(MediaQuery.of(context).size.height * 0.56, 430),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: border)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: secondary.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            SizedBox(
              height: 52,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 4),
                itemBuilder: (context, index) {
                  final category = categories[index];
                  final active = index == _selected;
                  return IconButton(
                    tooltip: category.label,
                    onPressed: () => setState(() => _selected = index),
                    icon: Icon(
                      category.icon,
                      color: active ? PravaColors.accentPrimary : secondary,
                    ),
                  );
                },
              ),
            ),
            Divider(height: 1, color: border),
            Expanded(
              child: selected.emojis.isEmpty
                  ? Center(
                      child: Text(
                        'Recently used emojis appear here',
                        style: PravaTypography.body.copyWith(color: secondary),
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 22),
                      physics: const BouncingScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 8,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                          ),
                      itemCount: selected.emojis.length,
                      itemBuilder: (context, index) {
                        final emoji = selected.emojis[index];
                        return InkWell(
                          onTap: () => _select(emoji),
                          borderRadius: BorderRadius.circular(12),
                          child: Center(
                            child: Text(
                              emoji,
                              style: TextStyle(fontSize: 26, color: primary),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmojiCategory {
  const _EmojiCategory({
    required this.label,
    required this.icon,
    required this.emojis,
  });

  final String label;
  final IconData icon;
  final List<String> emojis;
}

const _emojiCategories = <_EmojiCategory>[
  _EmojiCategory(
    label: 'Smileys',
    icon: Icons.emoji_emotions_outlined,
    emojis: [
      '😀',
      '😃',
      '😄',
      '😁',
      '😆',
      '😅',
      '😂',
      '🤣',
      '😊',
      '😇',
      '🙂',
      '🙃',
      '😉',
      '😌',
      '😍',
      '🥰',
      '😘',
      '😗',
      '😙',
      '😚',
      '😋',
      '😛',
      '😝',
      '😜',
      '🤪',
      '🤨',
      '🧐',
      '🤓',
      '😎',
      '🥳',
      '😏',
      '😒',
      '😞',
      '😔',
      '😟',
      '😕',
      '🙁',
      '☹️',
      '😣',
      '😖',
      '😫',
      '😩',
      '🥺',
      '😢',
      '😭',
      '😤',
      '😠',
      '😡',
      '🤬',
      '🤯',
      '😳',
      '🥵',
      '🥶',
      '😱',
      '😨',
      '😰',
      '😥',
      '😓',
      '🤗',
      '🤔',
      '🫡',
      '🤭',
      '🫢',
      '🫣',
      '🤫',
      '🤥',
      '😶',
      '😐',
      '😑',
      '😬',
      '🙄',
      '😯',
      '😦',
      '😧',
      '😮',
      '😲',
      '🥱',
      '😴',
      '🤤',
      '😪',
      '😵',
      '🤐',
      '🥴',
      '🤢',
      '🤮',
      '🤧',
      '😷',
      '🤒',
      '🤕',
      '🤑',
      '🤠',
      '😈',
      '👿',
      '👻',
      '💀',
      '☠️',
      '💩',
      '🤡',
      '👹',
      '👺',
      '❤️',
      '🧡',
      '💛',
      '💚',
      '💙',
      '💜',
      '🖤',
      '🤍',
      '🤎',
      '💔',
      '❣️',
      '💕',
      '💞',
      '💓',
      '💗',
      '💖',
      '💘',
      '💝',
      '💟',
    ],
  ),
  _EmojiCategory(
    label: 'People',
    icon: Icons.people_outline,
    emojis: [
      '👍',
      '👎',
      '👌',
      '🤌',
      '🤏',
      '✌️',
      '🤞',
      '🫰',
      '🤟',
      '🤘',
      '🤙',
      '👈',
      '👉',
      '👆',
      '👇',
      '☝️',
      '✋',
      '🤚',
      '🖐️',
      '🖖',
      '👋',
      '🤝',
      '👏',
      '🙌',
      '🫶',
      '👐',
      '🤲',
      '🙏',
      '✍️',
      '💅',
      '🤳',
      '💪',
      '🦾',
      '🦵',
      '🦶',
      '👂',
      '🦻',
      '👃',
      '🧠',
      '🫀',
      '🫁',
      '🦷',
      '👀',
      '👁️',
      '👅',
      '👄',
      '👶',
      '🧒',
      '👦',
      '👧',
      '🧑',
      '👱',
      '👨',
      '🧔',
      '👩',
      '🧓',
      '👴',
      '👵',
      '🙍',
      '🙎',
      '🙅',
      '🙆',
      '💁',
      '🙋',
      '🧏',
      '🙇',
      '🤦',
      '🤷',
      '👮',
      '🕵️',
      '💂',
      '🥷',
      '👷',
      '🫅',
      '🤴',
      '👸',
      '👳',
      '👲',
      '🧕',
      '🤵',
      '👰',
      '🤰',
      '🫃',
      '🫄',
      '🤱',
      '👼',
      '🎅',
      '🧑‍🎄',
    ],
  ),
  _EmojiCategory(
    label: 'Nature',
    icon: Icons.eco_outlined,
    emojis: [
      '🐶',
      '🐱',
      '🐭',
      '🐹',
      '🐰',
      '🦊',
      '🐻',
      '🐼',
      '🐻‍❄️',
      '🐨',
      '🐯',
      '🦁',
      '🐮',
      '🐷',
      '🐸',
      '🐵',
      '🙈',
      '🙉',
      '🙊',
      '🐒',
      '🐔',
      '🐧',
      '🐦',
      '🐤',
      '🦆',
      '🦅',
      '🦉',
      '🦇',
      '🐺',
      '🐗',
      '🐴',
      '🦄',
      '🐝',
      '🪱',
      '🐛',
      '🦋',
      '🐌',
      '🐞',
      '🐜',
      '🪰',
      '🪲',
      '🪳',
      '🦟',
      '🦗',
      '🕷️',
      '🦂',
      '🐢',
      '🐍',
      '🦎',
      '🦖',
      '🦕',
      '🐙',
      '🦑',
      '🦐',
      '🦞',
      '🦀',
      '🐡',
      '🐠',
      '🐟',
      '🐬',
      '🐳',
      '🐋',
      '🦈',
      '🐊',
      '🌵',
      '🎄',
      '🌲',
      '🌳',
      '🌴',
      '🪵',
      '🌱',
      '🌿',
      '☘️',
      '🍀',
      '🎍',
      '🪴',
      '🎋',
      '🍃',
      '🍂',
      '🍁',
      '🍄',
      '🐚',
      '🪨',
      '🌾',
      '💐',
      '🌷',
      '🌹',
      '🥀',
      '🌺',
      '🌸',
      '🌼',
      '🌻',
      '🌞',
      '🌝',
      '🌛',
      '🌜',
    ],
  ),
  _EmojiCategory(
    label: 'Food',
    icon: Icons.restaurant_outlined,
    emojis: [
      '🍏',
      '🍎',
      '🍐',
      '🍊',
      '🍋',
      '🍌',
      '🍉',
      '🍇',
      '🍓',
      '🫐',
      '🍈',
      '🍒',
      '🍑',
      '🥭',
      '🍍',
      '🥥',
      '🥝',
      '🍅',
      '🍆',
      '🥑',
      '🥦',
      '🥬',
      '🥒',
      '🌶️',
      '🫑',
      '🌽',
      '🥕',
      '🫒',
      '🧄',
      '🧅',
      '🥔',
      '🍠',
      '🥐',
      '🥯',
      '🍞',
      '🥖',
      '🥨',
      '🧀',
      '🥚',
      '🍳',
      '🧈',
      '🥞',
      '🧇',
      '🥓',
      '🥩',
      '🍗',
      '🍖',
      '🌭',
      '🍔',
      '🍟',
      '🍕',
      '🫓',
      '🥪',
      '🥙',
      '🧆',
      '🌮',
      '🌯',
      '🫔',
      '🥗',
      '🥘',
      '🫕',
      '🍝',
      '🍜',
      '🍲',
      '🍛',
      '🍣',
      '🍱',
      '🥟',
      '🦪',
      '🍤',
      '🍙',
      '🍚',
      '🍘',
      '🍥',
      '🥠',
      '🥮',
      '🍢',
      '🍡',
      '🍧',
      '🍨',
      '🍦',
      '🥧',
      '🧁',
      '🍰',
      '🎂',
      '🍮',
      '🍭',
      '🍬',
      '🍫',
      '🍿',
      '🍩',
      '🍪',
      '🥛',
      '☕',
      '🫖',
      '🍵',
    ],
  ),
  _EmojiCategory(
    label: 'Travel',
    icon: Icons.flight_takeoff,
    emojis: [
      '🚗',
      '🚕',
      '🚙',
      '🚌',
      '🚎',
      '🏎️',
      '🚓',
      '🚑',
      '🚒',
      '🚐',
      '🛻',
      '🚚',
      '🚛',
      '🚜',
      '🛵',
      '🏍️',
      '🛺',
      '🚲',
      '🛴',
      '🛹',
      '🛼',
      '🚆',
      '🚇',
      '🚊',
      '🚉',
      '✈️',
      '🛫',
      '🛬',
      '🛩️',
      '💺',
      '🚁',
      '🚀',
      '🛸',
      '🚢',
      '⛵',
      '🚤',
      '🛥️',
      '🛳️',
      '⛴️',
      '⚓',
      '⛽',
      '🚧',
      '🚦',
      '🚥',
      '🗺️',
      '🗿',
      '🗽',
      '🗼',
      '🏰',
      '🏯',
      '🏟️',
      '🎡',
      '🎢',
      '🎠',
      '⛲',
      '⛱️',
      '🏖️',
      '🏝️',
      '🏜️',
      '🌋',
      '⛰️',
      '🏔️',
      '🗻',
      '🏕️',
      '🏠',
      '🏡',
      '🏘️',
      '🏚️',
      '🏗️',
      '🏭',
      '🏢',
      '🏬',
      '🏣',
      '🏤',
      '🏥',
      '🏦',
      '🏨',
      '🏪',
      '🏫',
      '🏩',
    ],
  ),
  _EmojiCategory(
    label: 'Activities',
    icon: Icons.sports_basketball_outlined,
    emojis: [
      '⚽',
      '🏀',
      '🏈',
      '⚾',
      '🥎',
      '🎾',
      '🏐',
      '🏉',
      '🥏',
      '🎱',
      '🪀',
      '🏓',
      '🏸',
      '🏒',
      '🏑',
      '🥍',
      '🏏',
      '🪃',
      '🥅',
      '⛳',
      '🪁',
      '🏹',
      '🎣',
      '🤿',
      '🥊',
      '🥋',
      '🎽',
      '🛹',
      '🛼',
      '🛷',
      '⛸️',
      '🥌',
      '🎿',
      '⛷️',
      '🏂',
      '🪂',
      '🏋️',
      '🤼',
      '🤸',
      '⛹️',
      '🤺',
      '🤾',
      '🏌️',
      '🏇',
      '🧘',
      '🏄',
      '🏊',
      '🤽',
      '🚣',
      '🧗',
      '🚵',
      '🚴',
      '🎯',
      '🎮',
      '🎲',
      '♟️',
      '🎭',
      '🎨',
      '🧩',
      '🎪',
      '🎤',
      '🎧',
      '🎼',
      '🎹',
      '🥁',
      '🪘',
      '🎷',
      '🎺',
      '🪗',
      '🎸',
      '🪕',
      '🎻',
      '🎬',
      '🏆',
      '🥇',
      '🥈',
      '🥉',
      '🏅',
      '🎖️',
      '🎗️',
    ],
  ),
  _EmojiCategory(
    label: 'Objects',
    icon: Icons.lightbulb_outline,
    emojis: [
      '⌚',
      '📱',
      '📲',
      '💻',
      '⌨️',
      '🖥️',
      '🖨️',
      '🖱️',
      '🖲️',
      '🕹️',
      '🗜️',
      '💽',
      '💾',
      '💿',
      '📀',
      '📼',
      '📷',
      '📸',
      '📹',
      '🎥',
      '📽️',
      '🎞️',
      '📞',
      '☎️',
      '📟',
      '📠',
      '📺',
      '📻',
      '🎙️',
      '🎚️',
      '🎛️',
      '🧭',
      '⏱️',
      '⏲️',
      '⏰',
      '🕰️',
      '⌛',
      '⏳',
      '📡',
      '🔋',
      '🪫',
      '🔌',
      '💡',
      '🔦',
      '🕯️',
      '🪔',
      '🧯',
      '🛢️',
      '💸',
      '💵',
      '💴',
      '💶',
      '💷',
      '🪙',
      '💰',
      '💳',
      '💎',
      '⚖️',
      '🪜',
      '🧰',
      '🪛',
      '🔧',
      '🔨',
      '⚒️',
      '🛠️',
      '⛏️',
      '🪚',
      '🔩',
      '⚙️',
      '🪤',
      '🧱',
      '⛓️',
      '🧲',
      '🔫',
      '💣',
      '🧨',
      '🪓',
      '🔪',
      '🗡️',
      '🛡️',
      '🚬',
      '⚰️',
      '🪦',
      '⚱️',
      '🏺',
      '🔮',
      '📿',
      '🧿',
    ],
  ),
  _EmojiCategory(
    label: 'Symbols',
    icon: Icons.emoji_symbols_outlined,
    emojis: [
      '✅',
      '☑️',
      '✔️',
      '❌',
      '❎',
      '➕',
      '➖',
      '➗',
      '✖️',
      '♾️',
      '‼️',
      '⁉️',
      '❓',
      '❔',
      '❕',
      '❗',
      '〰️',
      '💱',
      '💲',
      '⚕️',
      '♻️',
      '⚜️',
      '🔱',
      '📛',
      '🔰',
      '⭕',
      '🟢',
      '🟡',
      '🟠',
      '🔴',
      '🟣',
      '🔵',
      '⚫',
      '⚪',
      '🟤',
      '⬛',
      '⬜',
      '◼️',
      '◻️',
      '◾',
      '◽',
      '▪️',
      '▫️',
      '🔶',
      '🔷',
      '🔸',
      '🔹',
      '🔺',
      '🔻',
      '💠',
      '🔘',
      '🔳',
      '🔲',
      '🏁',
      '🚩',
      '🎌',
      '🏴',
      '🏳️',
      '🏳️‍🌈',
      '🏳️‍⚧️',
      '🇮🇳',
      '🇺🇸',
      '🇬🇧',
      '🇯🇵',
      '0️⃣',
      '1️⃣',
      '2️⃣',
      '3️⃣',
      '4️⃣',
      '5️⃣',
      '6️⃣',
      '7️⃣',
      '8️⃣',
      '9️⃣',
      '🔟',
      '#️⃣',
      '*️⃣',
    ],
  ),
];

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
    final color = isDestructive ? PravaColors.error : PravaColors.accentPrimary;

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
