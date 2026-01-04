import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../../ui-system/background.dart';
import '../../../ui-system/colors.dart';
import '../../../ui-system/typography.dart';
import '../../../ui-system/feedback/prava_toast.dart';
import '../../../ui-system/feedback/toast_type.dart';

class ArchivedChatsPage extends StatefulWidget {
  const ArchivedChatsPage({super.key});

  @override
  State<ArchivedChatsPage> createState() => _ArchivedChatsPageState();
}

class _ArchivedChatsPageState extends State<ArchivedChatsPage> {
  final TextEditingController _searchController = TextEditingController();

  List<_ArchivedChat> _archived =
      List<_ArchivedChat>.from(_seedArchivedChats);
  bool _keepArchived = true;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_ArchivedChat> get _visibleChats {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _archived;
    return _archived
        .where(
          (chat) =>
              chat.name.toLowerCase().contains(query) ||
              chat.lastMessage.toLowerCase().contains(query),
        )
        .toList();
  }

  void _unarchive(_ArchivedChat chat) {
    HapticFeedback.selectionClick();
    setState(() => _archived.removeWhere((item) => item.id == chat.id));
    PravaToast.show(
      context,
      message: 'Chat restored',
      type: PravaToastType.success,
    );
  }

  void _restoreAll() {
    if (_archived.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() => _archived.clear());
    PravaToast.show(
      context,
      message: 'All archived chats restored',
      type: PravaToastType.success,
    );
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

    final chats = _visibleChats;

    return Scaffold(
      body: Stack(
        children: [
          _PageBackdrop(isDark: isDark),
          SafeArea(
            child: Column(
              children: [
                _TopBar(
                  title: 'Archived',
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: _KeepArchivedCard(
                    value: _keepArchived,
                    onChanged: (value) {
                      HapticFeedback.selectionClick();
                      setState(() => _keepArchived = value);
                    },
                    primary: primary,
                    secondary: secondary,
                    border: border,
                    isDark: isDark,
                  ),
                ),
                Expanded(
                  child: chats.isEmpty
                      ? _EmptyState(
                          hasQuery:
                              _searchController.text.trim().isNotEmpty,
                          primary: primary,
                          secondary: secondary,
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          physics: const BouncingScrollPhysics(
                            parent: AlwaysScrollableScrollPhysics(),
                          ),
                          itemCount: chats.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final chat = chats[index];
                            return _ArchivedChatCard(
                              chat: chat,
                              isDark: isDark,
                              primary: primary,
                              secondary: secondary,
                              border: border,
                              onUnarchive: () => _unarchive(chat),
                            );
                          },
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
    required this.title,
    required this.onBack,
    required this.onRestore,
  });

  final String title;
  final VoidCallback onBack;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary =
        isDark ? PravaColors.darkTextPrimary : PravaColors.lightTextPrimary;
    final surface =
        isDark ? Colors.black.withValues(alpha: 0.45) : Colors.white.withValues(alpha: 0.8);
    final border =
        isDark ? PravaColors.darkBorderSubtle : PravaColors.lightBorderSubtle;

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
                _IconPill(
                  icon: CupertinoIcons.back,
                  onTap: onBack,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: PravaTypography.h3.copyWith(
                      color: primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onRestore,
                  child: Text(
                    'Restore all',
                    style: PravaTypography.button.copyWith(
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
            color: isDark ? Colors.white10 : Colors.white.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: border),
          ),
          child: CupertinoSearchTextField(
            controller: controller,
            placeholder: 'Search archived chats',
            backgroundColor: Colors.transparent,
          ),
        ),
      ),
    );
  }
}

class _KeepArchivedCard extends StatelessWidget {
  const _KeepArchivedCard({
    required this.value,
    required this.onChanged,
    required this.primary,
    required this.secondary,
    required this.border,
    required this.isDark,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final Color primary;
  final Color secondary;
  final Color border;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: PravaColors.accentPrimary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              CupertinoIcons.archivebox_fill,
              size: 18,
              color: PravaColors.accentPrimary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Keep chats archived',
                  style: PravaTypography.body.copyWith(
                    color: primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Stay archived when new messages arrive',
                  style: PravaTypography.caption.copyWith(color: secondary),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: PravaColors.accentPrimary,
          ),
        ],
      ),
    );
  }
}

class _ArchivedChatCard extends StatelessWidget {
  const _ArchivedChatCard({
    required this.chat,
    required this.isDark,
    required this.primary,
    required this.secondary,
    required this.border,
    required this.onUnarchive,
  });

  final _ArchivedChat chat;
  final bool isDark;
  final Color primary;
  final Color secondary;
  final Color border;
  final VoidCallback onUnarchive;

  Color _avatarColor(String name) {
    const palette = [
      Color(0xFF5B8CFF),
      Color(0xFF2EC4B6),
      Color(0xFFFFB703),
      Color(0xFFFF6B6B),
      Color(0xFF845EC2),
    ];
    final hash = name.codeUnits.fold<int>(0, (acc, c) => acc + c);
    return palette[hash % palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final accent = _avatarColor(chat.name);
    final baseColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.white.withValues(alpha: 0.9);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: baseColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: accent.withValues(alpha: 0.18),
            child: chat.isGroup
                ? Icon(
                    CupertinoIcons.person_2_fill,
                    color: accent,
                  )
                : Text(
                    chat.initials,
                    style: PravaTypography.h3.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w700,
                    ),
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
                        chat.name,
                        style: PravaTypography.body.copyWith(
                          color: primary,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      chat.time,
                      style: PravaTypography.caption.copyWith(color: secondary),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  chat.lastMessage,
                  style: PravaTypography.caption.copyWith(color: secondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (chat.unreadCount > 0)
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
          const SizedBox(width: 8),
          IconButton(
            onPressed: onUnarchive,
            icon: const Icon(CupertinoIcons.arrow_up_circle),
            color: PravaColors.accentPrimary,
          ),
        ],
      ),
    );
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
          child: Icon(
            CupertinoIcons.archivebox,
            size: 40,
            color: secondary,
          ),
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
            style: PravaTypography.body.copyWith(color: secondary),
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
        child: Icon(
          icon,
          size: 18,
          color: PravaColors.accentPrimary,
        ),
      ),
    );
  }
}

class _PageBackdrop extends StatelessWidget {
  const _PageBackdrop({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return PravaBackground(isDark: isDark);
  }
}

class _ArchivedChat {
  const _ArchivedChat({
    required this.id,
    required this.name,
    required this.lastMessage,
    required this.time,
    required this.unreadCount,
    required this.isGroup,
  });

  final String id;
  final String name;
  final String lastMessage;
  final String time;
  final int unreadCount;
  final bool isGroup;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1))
        .toUpperCase();
  }
}

const List<_ArchivedChat> _seedArchivedChats = [
  _ArchivedChat(
    id: 'a1',
    name: 'Prava Core',
    lastMessage: 'Shipped the realtime sync patch.',
    time: 'Today',
    unreadCount: 2,
    isGroup: true,
  ),
  _ArchivedChat(
    id: 'a2',
    name: 'Meera Patel',
    lastMessage: 'Thanks! Will review the UI draft.',
    time: 'Yesterday',
    unreadCount: 0,
    isGroup: false,
  ),
  _ArchivedChat(
    id: 'a3',
    name: 'Creator Lab',
    lastMessage: 'Upload the teaser clips by 6 PM.',
    time: 'Sat',
    unreadCount: 1,
    isGroup: true,
  ),
  _ArchivedChat(
    id: 'a4',
    name: 'Aarav Sharma',
    lastMessage: 'Lets sync after the standup.',
    time: 'Fri',
    unreadCount: 0,
    isGroup: false,
  ),
];
