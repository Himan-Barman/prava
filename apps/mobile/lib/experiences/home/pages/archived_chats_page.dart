import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../navigation/prava_navigator.dart';
import '../../../services/chat_service.dart';
import '../../../ui-system/background.dart';
import '../../../ui-system/colors.dart';
import '../../../ui-system/components/prava_input.dart';
import '../../../ui-system/feedback/prava_toast.dart';
import '../../../ui-system/feedback/toast_type.dart';
import '../../../ui-system/typography.dart';
import '../tabs/chats/chat_thread_page.dart';
import '../tabs/chats/chats_page.dart';

class ArchivedChatsPage extends StatefulWidget {
  const ArchivedChatsPage({super.key});

  @override
  State<ArchivedChatsPage> createState() => _ArchivedChatsPageState();
}

class _ArchivedChatsPageState extends State<ArchivedChatsPage> {
  final ChatService _chatService = ChatService();
  final TextEditingController _searchController = TextEditingController();

  List<ConversationSummary> _archived = const [];
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      if (mounted) setState(() {});
    });
    _loadArchived();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadArchived() async {
    if (mounted) setState(() => _loading = true);
    try {
      final chats = await _chatService.listConversations(archived: true);
      if (mounted) setState(() => _archived = chats);
    } catch (_) {
      if (!mounted) return;
      PravaToast.show(
        context,
        message: 'Could not load archived chats',
        type: PravaToastType.error,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<ConversationSummary> get _visibleChats {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _archived;
    return _archived.where((chat) {
      return chat.title.toLowerCase().contains(query) ||
          chat.lastMessageBody.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _unarchive(ConversationSummary chat) async {
    HapticFeedback.selectionClick();
    final previous = _archived;
    setState(() {
      _archived = _archived.where((item) => item.id != chat.id).toList();
    });

    final ok = await _chatService.updatePreferences(
      conversationId: chat.id,
      isFavorite: chat.isFavorite,
      isStarred: chat.isStarred,
      isMuted: chat.isMuted,
      isArchived: false,
    );
    if (!ok && mounted) {
      setState(() => _archived = previous);
      PravaToast.show(
        context,
        message: 'Could not restore chat',
        type: PravaToastType.error,
      );
      return;
    }

    if (!mounted) return;
    PravaToast.show(
      context,
      message: 'Chat restored',
      type: PravaToastType.success,
    );
  }

  Future<void> _restoreAll() async {
    if (_archived.isEmpty || _saving) return;
    HapticFeedback.selectionClick();
    setState(() => _saving = true);
    final chats = List<ConversationSummary>.from(_archived);
    var failed = false;

    for (final chat in chats) {
      final ok = await _chatService.updatePreferences(
        conversationId: chat.id,
        isFavorite: chat.isFavorite,
        isStarred: chat.isStarred,
        isMuted: chat.isMuted,
        isArchived: false,
      );
      failed = failed || !ok;
    }

    if (!mounted) return;
    setState(() => _saving = false);
    await _loadArchived();
    if (!mounted) return;
    PravaToast.show(
      context,
      message: failed
          ? 'Some chats could not be restored'
          : 'All chats restored',
      type: failed ? PravaToastType.warning : PravaToastType.success,
    );
  }

  void _openChat(ConversationSummary chat) {
    HapticFeedback.selectionClick();
    Navigator.of(context, rootNavigator: true)
        .push(
          PravaNavigator.route(
            ChatThreadPage(chat: _toPreview(chat)),
            fullscreenDialog: true,
          ),
        )
        .then((_) => _loadArchived());
  }

  ChatPreview _toPreview(ConversationSummary chat) {
    return ChatPreview(
      id: chat.id,
      name: chat.title.trim().isEmpty ? 'Conversation' : chat.title.trim(),
      lastMessage: _preview(chat),
      time: _formatTime(chat.lastMessageAt ?? chat.updatedAt),
      unreadCount: chat.unreadCount,
      isGroup: chat.type == 'group',
      isOnline: false,
      isMuted: chat.isMuted,
      isPinned: chat.isStarred,
      isFavorite: chat.isFavorite,
      isStarred: chat.isStarred,
      isTyping: false,
      peerUserId: chat.peerUserId,
      avatarUrl: chat.peerAvatarUrl,
      peerLastSeenAt: chat.peerLastSeenAt,
      lastMessageFromMe: false,
      delivery: MessageDeliveryState.sent,
      lastMessageId: chat.lastMessageId,
      lastMessageSeq: chat.lastMessageSeq,
      lastMessageType: chat.lastMessageType,
      lastMessageDeletedForAllAt: chat.lastMessageDeletedForAllAt,
    );
  }

  String _preview(ConversationSummary chat) {
    if (chat.lastMessageDeletedForAllAt != null) return 'Message deleted';
    if (chat.lastMessageType == ChatMessageType.media) return 'Media message';
    final text = chat.lastMessageBody.trim();
    return text.isEmpty ? 'No messages yet' : text;
  }

  String _formatTime(DateTime? value) {
    if (value == null) return '';
    final now = DateTime.now();
    final local = value.toLocal();
    final diff = now.difference(local);
    if (diff.inMinutes < 1) return 'Now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${local.day}/${local.month}/${local.year}';
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
    final border = isDark
        ? PravaColors.darkBorderSubtle
        : PravaColors.lightBorderSubtle;
    final chats = _visibleChats;

    return Scaffold(
      body: Stack(
        children: [
          PravaBackground(isDark: isDark),
          SafeArea(
            child: Column(
              children: [
                _TopBar(
                  saving: _saving,
                  onBack: () => Navigator.of(context).pop(),
                  onRestore: _restoreAll,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: _SearchField(
                    controller: _searchController,
                    border: border,
                    isDark: isDark,
                  ),
                ),
                Expanded(
                  child: _loading
                      ? const Center(child: CupertinoActivityIndicator())
                      : chats.isEmpty
                      ? _EmptyState(
                          hasQuery: _searchController.text.trim().isNotEmpty,
                          primary: primary,
                          secondary: secondary,
                        )
                      : RefreshIndicator.adaptive(
                          onRefresh: _loadArchived,
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            physics: const BouncingScrollPhysics(
                              parent: AlwaysScrollableScrollPhysics(),
                            ),
                            itemCount: chats.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final chat = chats[index];
                              return _ConversationCard(
                                chat: chat,
                                preview: _preview(chat),
                                time: _formatTime(
                                  chat.lastMessageAt ?? chat.updatedAt,
                                ),
                                isDark: isDark,
                                primary: primary,
                                secondary: secondary,
                                border: border,
                                onTap: () => _openChat(chat),
                                onAction: () => _unarchive(chat),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.saving,
    required this.onBack,
    required this.onRestore,
  });

  final bool saving;
  final VoidCallback onBack;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark
        ? PravaColors.darkTextPrimary
        : PravaColors.lightTextPrimary;
    final surface = isDark
        ? Colors.black.withValues(alpha: 0.45)
        : Colors.white.withValues(alpha: 0.8);
    final border = isDark
        ? PravaColors.darkBorderSubtle
        : PravaColors.lightBorderSubtle;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: border),
            ),
            child: Row(
              children: [
                _IconPill(icon: CupertinoIcons.back, onTap: onBack),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Archived',
                    style: PravaTypography.titleSmall.copyWith(
                      color: primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: saving ? null : onRestore,
                  child: Text(
                    saving ? 'Restoring' : 'Restore all',
                    style: PravaTypography.buttonMedium.copyWith(
                      color: PravaColors.accentPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.border,
    required this.isDark,
  });

  final TextEditingController controller;
  final Color border;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white10
                : Colors.white.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: border),
          ),
          child: PravaSearchInput(
            controller: controller,
            hint: 'Search archived chats',
          ),
        ),
      ),
    );
  }
}

class _ConversationCard extends StatelessWidget {
  const _ConversationCard({
    required this.chat,
    required this.preview,
    required this.time,
    required this.isDark,
    required this.primary,
    required this.secondary,
    required this.border,
    required this.onTap,
    required this.onAction,
  });

  final ConversationSummary chat;
  final String preview;
  final String time;
  final bool isDark;
  final Color primary;
  final Color secondary;
  final Color border;
  final VoidCallback onTap;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final accent = _avatarColor(chat.title);
    final avatarUrl = chat.peerAvatarUrl.trim();

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: accent.withValues(alpha: 0.18),
              backgroundImage: avatarUrl.isEmpty
                  ? null
                  : NetworkImage(avatarUrl),
              child: avatarUrl.isNotEmpty
                  ? null
                  : Icon(
                      chat.type == 'group'
                          ? CupertinoIcons.person_2_fill
                          : CupertinoIcons.person_fill,
                      color: accent,
                    ),
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
                          chat.title.trim().isEmpty
                              ? 'Conversation'
                              : chat.title.trim(),
                          style: PravaTypography.bodyMedium.copyWith(
                            color: primary,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        time,
                        style: PravaTypography.caption.copyWith(
                          color: secondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    preview,
                    style: PravaTypography.caption.copyWith(color: secondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (chat.unreadCount > 0) ...[
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
              ),
            ],
            IconButton(
              onPressed: onAction,
              icon: const Icon(CupertinoIcons.arrow_up_circle),
              color: PravaColors.accentPrimary,
            ),
          ],
        ),
      ),
    );
  }

  Color _avatarColor(String value) {
    const palette = [
      Color(0xFF5B8CFF),
      Color(0xFF2EC4B6),
      Color(0xFFFFB703),
      Color(0xFFFF6B6B),
      Color(0xFF845EC2),
    ];
    final hash = value.codeUnits.fold<int>(0, (acc, code) => acc + code);
    return palette[hash % palette.length];
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.hasQuery,
    required this.primary,
    required this.secondary,
  });

  final bool hasQuery;
  final Color primary;
  final Color secondary;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 80, 16, 16),
      children: [
        Center(
          child: Icon(CupertinoIcons.archivebox, size: 40, color: secondary),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            hasQuery ? 'No matches' : 'No archived chats',
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
                ? 'Try another keyword.'
                : 'Archived chats will appear here.',
            textAlign: TextAlign.center,
            style: PravaTypography.bodyMedium.copyWith(color: secondary),
          ),
        ),
      ],
    );
  }
}

class _IconPill extends StatelessWidget {
  const _IconPill({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDark ? Colors.white10 : Colors.black12,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, size: 18, color: PravaColors.accentPrimary),
      ),
    );
  }
}
