import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/storage/secure_store.dart';
import '../../../../navigation/prava_navigator.dart';
import '../../../../services/chat_service.dart';
import '../../../../ui-system/background.dart';
import '../../../../ui-system/colors.dart';
import '../../../../ui-system/typography.dart';
import '../profile/public_profile_page.dart';

class ChatDetailsPage extends StatefulWidget {
  const ChatDetailsPage({
    super.key,
    required this.conversationId,
    required this.name,
    required this.initial,
    required this.isGroup,
    required this.isMuted,
    required this.isStarred,
    required this.isArchived,
    this.peerUserId,
    this.avatarUrl,
  });

  final String conversationId;
  final String name;
  final String initial;
  final bool isGroup;
  final bool isMuted;
  final bool isStarred;
  final bool isArchived;
  final String? peerUserId;
  final String? avatarUrl;

  @override
  State<ChatDetailsPage> createState() => _ChatDetailsPageState();
}

class _ChatDetailsPageState extends State<ChatDetailsPage> {
  late final ChatService _chatService = ChatService(store: SecureStore());

  bool _loading = true;
  bool _isMuted = false;
  bool _isStarred = false;
  bool _isArchived = false;
  List<ConversationMember> _members = <ConversationMember>[];
  List<ChatAttachment> _attachments = <ChatAttachment>[];
  List<GroupInvite> _invites = <GroupInvite>[];
  List<ChatMessage> _pinnedMessages = <ChatMessage>[];
  List<ChatMessage> _savedMessages = <ChatMessage>[];

  @override
  void initState() {
    super.initState();
    _isMuted = widget.isMuted;
    _isStarred = widget.isStarred;
    _isArchived = widget.isArchived;
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait<dynamic>([
        _chatService.listMembers(conversationId: widget.conversationId),
        _chatService.listAttachments(
          conversationId: widget.conversationId,
          limit: 24,
        ),
        if (widget.isGroup)
          _chatService.listGroupInvites(conversationId: widget.conversationId)
        else
          Future<List<GroupInvite>>.value(<GroupInvite>[]),
        _chatService.listPinnedMessages(
          conversationId: widget.conversationId,
          limit: 10,
        ),
        _chatService.listSavedMessages(
          conversationId: widget.conversationId,
          limit: 10,
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _members = results[0] as List<ConversationMember>;
        _attachments = results[1] as List<ChatAttachment>;
        _invites = results[2] as List<GroupInvite>;
        _pinnedMessages = results[3] as List<ChatMessage>;
        _savedMessages = results[4] as List<ChatMessage>;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showSnack('Could not load chat details');
    }
  }

  Future<void> _setPreference({
    bool? muted,
    bool? starred,
    bool? archived,
  }) async {
    final previousMuted = _isMuted;
    final previousStarred = _isStarred;
    final previousArchived = _isArchived;
    final nextMuted = muted ?? _isMuted;
    final nextStarred = starred ?? _isStarred;
    final nextArchived = archived ?? _isArchived;

    setState(() {
      _isMuted = nextMuted;
      _isStarred = nextStarred;
      _isArchived = nextArchived;
    });

    try {
      final ok = await _chatService.updatePreferences(
        conversationId: widget.conversationId,
        isMuted: nextMuted,
        isStarred: nextStarred,
        isArchived: nextArchived,
      );
      if (!ok) throw Exception('preference update failed');
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isMuted = previousMuted;
        _isStarred = previousStarred;
        _isArchived = previousArchived;
      });
      _showSnack('Could not update chat setting');
    }
  }

  Future<void> _markUnread() async {
    HapticFeedback.selectionClick();
    try {
      final ok = await _chatService.markUnread(widget.conversationId);
      if (!ok) throw Exception('mark unread failed');
      _showSnack('Marked as unread');
    } catch (_) {
      _showSnack('Could not mark unread');
    }
  }

  Future<void> _clearLocalHistory() async {
    HapticFeedback.selectionClick();
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Clear chat history?'),
        content: const Text(
          'Messages will be hidden for you on this device and account. Other people will still see them.',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final ok = await _chatService.clearLocalConversation(
        widget.conversationId,
      );
      if (!ok) throw Exception('clear failed');
      if (!mounted) return;
      setState(() {
        _pinnedMessages = <ChatMessage>[];
        _savedMessages = <ChatMessage>[];
      });
      PravaNavigator.pop(context, 'cleared');
    } catch (_) {
      _showSnack('Could not clear chat history');
    }
  }

  Future<void> _deleteLocalConversation() async {
    HapticFeedback.selectionClick();
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Delete chat?'),
        content: const Text(
          'This removes the conversation from your chat list until a new message arrives.',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final ok = await _chatService.deleteConversationLocal(
        widget.conversationId,
      );
      if (!ok) throw Exception('delete failed');
      if (!mounted) return;
      PravaNavigator.pop(context, 'deleted');
    } catch (_) {
      _showSnack('Could not delete chat');
    }
  }

  Future<void> _createInvite() async {
    HapticFeedback.selectionClick();
    try {
      final invite = await _chatService.createGroupInvite(
        conversationId: widget.conversationId,
        maxUses: 20,
        expiresInHours: 168,
        requiresApproval: true,
      );
      if (invite == null) throw Exception('invite failed');
      if (!mounted) return;
      setState(() => _invites = [invite, ..._invites]);
      await Clipboard.setData(ClipboardData(text: invite.inviteToken));
      _showSnack('Invite copied');
    } catch (_) {
      _showSnack('Could not create invite');
    }
  }

  Future<void> _reportConversation() async {
    final reason = await showCupertinoModalPopup<String>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(widget.isGroup ? 'Report group' : 'Report chat'),
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
    if (!mounted || reason == null) return;
    try {
      final ok = await _chatService.reportConversation(
        conversationId: widget.conversationId,
        reportedUserId: widget.isGroup ? null : widget.peerUserId,
        reason: reason,
      );
      if (!ok) throw Exception('report failed');
      _showSnack('Report sent');
    } catch (_) {
      _showSnack('Could not send report');
    }
  }

  void _openProfile() {
    final userId = widget.peerUserId?.trim();
    if (widget.isGroup || userId == null || userId.isEmpty) return;
    HapticFeedback.selectionClick();
    PravaNavigator.push(context, PublicProfilePage(userId: userId));
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
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

    return Scaffold(
      backgroundColor: isDark
          ? PravaColors.darkBgMain
          : PravaColors.lightBgMain,
      body: Stack(
        children: [
          const PravaBackground(),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Chat details',
                          style: PravaTypography.h2.copyWith(color: primary),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: Icon(CupertinoIcons.xmark, color: primary),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _loading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: PravaColors.accentPrimary,
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                          physics: const BouncingScrollPhysics(),
                          children: [
                            _ProfileHeader(
                              name: widget.name,
                              initial: widget.initial,
                              avatarUrl: widget.avatarUrl,
                              subtitle: widget.isGroup
                                  ? '${_members.length} members'
                                  : 'Direct message',
                              onTap: widget.isGroup ? null : _openProfile,
                            ),
                            const SizedBox(height: 24),
                            const _SectionTitle('Chat'),
                            _SwitchRow(
                              icon: CupertinoIcons.bell_slash_fill,
                              title: 'Mute notifications',
                              value: _isMuted,
                              onChanged: (value) =>
                                  _setPreference(muted: value),
                            ),
                            _SwitchRow(
                              icon: CupertinoIcons.star_fill,
                              title: 'Star chat',
                              value: _isStarred,
                              onChanged: (value) =>
                                  _setPreference(starred: value),
                            ),
                            _SwitchRow(
                              icon: CupertinoIcons.archivebox_fill,
                              title: 'Archived',
                              value: _isArchived,
                              onChanged: (value) =>
                                  _setPreference(archived: value),
                            ),
                            _ActionRow(
                              icon: CupertinoIcons.envelope_badge_fill,
                              title: 'Mark as unread',
                              subtitle: 'Show this chat as unread in Chats',
                              onTap: _markUnread,
                            ),
                            const SizedBox(height: 22),
                            const _SectionTitle('Shared media'),
                            if (_attachments.isEmpty)
                              _EmptyLine('No attachments yet', secondary)
                            else
                              ..._attachments
                                  .take(6)
                                  .map((item) => _AttachmentRow(item: item)),
                            const SizedBox(height: 22),
                            const _SectionTitle('Pinned messages'),
                            if (_pinnedMessages.isEmpty)
                              _EmptyLine('No pinned messages', secondary)
                            else
                              ..._pinnedMessages
                                  .take(5)
                                  .map(
                                    (message) =>
                                        _PinnedMessageRow(message: message),
                                  ),
                            const SizedBox(height: 22),
                            const _SectionTitle('Saved messages'),
                            if (_savedMessages.isEmpty)
                              _EmptyLine('No saved messages', secondary)
                            else
                              ..._savedMessages
                                  .take(5)
                                  .map(
                                    (message) =>
                                        _SavedMessageRow(message: message),
                                  ),
                            const SizedBox(height: 22),
                            const _SectionTitle('Safety'),
                            _ActionRow(
                              icon: CupertinoIcons.clear,
                              title: 'Clear local history',
                              subtitle: 'Hide previous messages for you',
                              isDestructive: true,
                              onTap: _clearLocalHistory,
                            ),
                            _ActionRow(
                              icon: CupertinoIcons.delete,
                              title: 'Delete chat locally',
                              subtitle: 'Remove this chat from your list',
                              isDestructive: true,
                              onTap: _deleteLocalConversation,
                            ),
                            _ActionRow(
                              icon: CupertinoIcons.exclamationmark_bubble,
                              title: widget.isGroup
                                  ? 'Report group'
                                  : 'Report chat',
                              subtitle: 'Send this to moderation for review',
                              isDestructive: true,
                              onTap: _reportConversation,
                            ),
                            if (widget.isGroup) ...[
                              const SizedBox(height: 22),
                              const _SectionTitle('Group'),
                              _ActionRow(
                                icon: CupertinoIcons.link,
                                title: 'Create invite link',
                                subtitle: _invites.isEmpty
                                    ? 'Approval required for new joins'
                                    : '${_invites.length} active invites',
                                onTap: _createInvite,
                              ),
                              ..._members.map(
                                (member) => _MemberRow(member: member),
                              ),
                            ],
                          ],
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

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.name,
    required this.initial,
    required this.subtitle,
    required this.avatarUrl,
    required this.onTap,
  });

  final String name;
  final String initial;
  final String subtitle;
  final String? avatarUrl;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark
        ? PravaColors.darkTextPrimary
        : PravaColors.lightTextPrimary;
    final secondary = isDark
        ? PravaColors.darkTextSecondary
        : PravaColors.lightTextSecondary;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        children: [
          CircleAvatar(
            radius: 42,
            backgroundColor: PravaColors.accentPrimary.withValues(alpha: 0.18),
            backgroundImage: avatarUrl != null && avatarUrl!.isNotEmpty
                ? NetworkImage(avatarUrl!)
                : null,
            child: avatarUrl == null || avatarUrl!.isEmpty
                ? Text(
                    initial,
                    style: PravaTypography.h1.copyWith(
                      color: PravaColors.accentPrimary,
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 14),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: PravaTypography.h2.copyWith(color: primary),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: PravaTypography.body.copyWith(color: secondary),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).brightness == Brightness.dark
        ? PravaColors.darkTextSecondary
        : PravaColors.lightTextSecondary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: PravaTypography.label.copyWith(
          color: secondary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).brightness == Brightness.dark
        ? PravaColors.darkTextPrimary
        : PravaColors.lightTextPrimary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: PravaColors.accentPrimary, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: PravaTypography.bodyLarge.copyWith(color: primary),
            ),
          ),
          CupertinoSwitch(
            value: value,
            activeTrackColor: PravaColors.accentPrimary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isDestructive = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark
        ? PravaColors.darkTextPrimary
        : PravaColors.lightTextPrimary;
    final secondary = isDark
        ? PravaColors.darkTextSecondary
        : PravaColors.lightTextSecondary;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(
              icon,
              color: isDestructive
                  ? PravaColors.error
                  : PravaColors.accentPrimary,
              size: 22,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: PravaTypography.bodyLarge.copyWith(
                      color: isDestructive ? PravaColors.error : primary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PravaTypography.caption.copyWith(color: secondary),
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

class _AttachmentRow extends StatelessWidget {
  const _AttachmentRow({required this.item});

  final ChatAttachment item;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark
        ? PravaColors.darkTextPrimary
        : PravaColors.lightTextPrimary;
    final secondary = isDark
        ? PravaColors.darkTextSecondary
        : PravaColors.lightTextSecondary;
    final icon = item.attachmentType == 'video'
        ? CupertinoIcons.videocam_fill
        : item.attachmentType == 'image'
        ? CupertinoIcons.photo_fill
        : CupertinoIcons.doc_fill;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Icon(icon, color: PravaColors.accentPrimary, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              item.fileName.isEmpty ? item.attachmentType : item.fileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: PravaTypography.body.copyWith(color: primary),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            item.status,
            style: PravaTypography.caption.copyWith(color: secondary),
          ),
        ],
      ),
    );
  }
}

class _PinnedMessageRow extends StatelessWidget {
  const _PinnedMessageRow({required this.message});

  final ChatMessage message;

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

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          const Icon(
            CupertinoIcons.pin_fill,
            color: PravaColors.accentPrimary,
            size: 20,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: PravaTypography.body.copyWith(color: primary),
                ),
                const SizedBox(height: 2),
                Text(
                  '${message.createdAt.day}/${message.createdAt.month}/${message.createdAt.year}',
                  style: PravaTypography.caption.copyWith(color: secondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SavedMessageRow extends StatelessWidget {
  const _SavedMessageRow({required this.message});

  final ChatMessage message;

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

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          const Icon(
            CupertinoIcons.bookmark_fill,
            color: PravaColors.accentPrimary,
            size: 20,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: PravaTypography.body.copyWith(color: primary),
                ),
                const SizedBox(height: 2),
                Text(
                  '${message.createdAt.day}/${message.createdAt.month}/${message.createdAt.year}',
                  style: PravaTypography.caption.copyWith(color: secondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({required this.member});

  final ConversationMember member;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).brightness == Brightness.dark
        ? PravaColors.darkTextPrimary
        : PravaColors.lightTextPrimary;
    final secondary = Theme.of(context).brightness == Brightness.dark
        ? PravaColors.darkTextSecondary
        : PravaColors.lightTextSecondary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: PravaColors.accentPrimary.withValues(alpha: 0.16),
            child: Text(
              member.userId.isEmpty ? '?' : member.userId[0].toUpperCase(),
              style: PravaTypography.caption.copyWith(
                color: PravaColors.accentPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              member.userId,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: PravaTypography.body.copyWith(color: primary),
            ),
          ),
          Text(
            member.role,
            style: PravaTypography.caption.copyWith(color: secondary),
          ),
        ],
      ),
    );
  }
}

class _EmptyLine extends StatelessWidget {
  const _EmptyLine(this.text, this.color);

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(text, style: PravaTypography.body.copyWith(color: color)),
    );
  }
}
