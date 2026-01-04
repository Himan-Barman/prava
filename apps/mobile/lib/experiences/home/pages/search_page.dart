import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../../navigation/prava_navigator.dart';
import '../../../ui-system/background.dart';
import '../../../ui-system/colors.dart';
import '../../../ui-system/typography.dart';
import '../../../ui-system/feedback/prava_toast.dart';
import '../../../ui-system/feedback/toast_type.dart';
import '../../../services/user_search_service.dart';
import '../../../services/chat_service.dart';
import '../tabs/chats/chat_thread_page.dart';
import '../tabs/chats/chats_page.dart';
import '../tabs/profile/public_profile_page.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _controller = TextEditingController();
  final UserSearchService _searchService = UserSearchService();
  final ChatService _chatService = ChatService();
  final Set<String> _pendingActions = <String>{};

  Timer? _debounce;
  int _searchToken = 0;
  bool _loading = false;
  String _query = '';
  List<UserSearchResult> _results = [];

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onQueryChanged);
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  String _normalizeQuery(String raw) {
    return raw.trim().toLowerCase().replaceFirst(RegExp(r'^@+'), '');
  }

  void _onQueryChanged() {
    final normalized = _normalizeQuery(_controller.text);
    if (normalized == _query) return;

    setState(() => _query = normalized);

    if (normalized.length < 2) {
      _debounce?.cancel();
      setState(() {
        _results = [];
        _loading = false;
      });
      return;
    }

    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 280),
      () => _runSearch(normalized),
    );
  }

  Future<void> _runSearch(String query) async {
    final token = ++_searchToken;
    setState(() => _loading = true);

    try {
      final results = await _searchService.searchUsers(query);
      if (!mounted || token != _searchToken) return;
      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || token != _searchToken) return;
      setState(() => _loading = false);
      PravaToast.show(
        context,
        message: 'Unable to search right now',
        type: PravaToastType.error,
      );
    }
  }

  bool _isPending(String userId) => _pendingActions.contains(userId);

  void _applySuggestion(String value) {
    _controller.text = value;
    _controller.selection =
        TextSelection.fromPosition(TextPosition(offset: value.length));
  }

  Future<void> _toggleFollow(UserSearchResult user) async {
    HapticFeedback.selectionClick();
    if (_isPending(user.id)) return;
    setState(() => _pendingActions.add(user.id));

    try {
      final following = await _searchService.toggleFollow(user.id);
      if (!mounted) return;
      setState(() {
        _pendingActions.remove(user.id);
        _updateResult(
          user.id,
          (item) => item.copyWith(isFollowing: following),
        );
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _pendingActions.remove(user.id));
      PravaToast.show(
        context,
        message: 'Unable to update friend status',
        type: PravaToastType.error,
      );
    }
  }

  void _updateResult(
    String userId,
    UserSearchResult Function(UserSearchResult) update,
  ) {
    final index = _results.indexWhere((item) => item.id == userId);
    if (index == -1) return;
    final updated = update(_results[index]);
    _results = List<UserSearchResult>.from(_results);
    _results[index] = updated;
  }

  Future<void> _startChat(UserSearchResult user) async {
    HapticFeedback.selectionClick();
    if (_isPending(user.id)) return;
    setState(() => _pendingActions.add(user.id));

    try {
      final conversationId =
          await _chatService.createDm(otherUserId: user.id);
      if (!mounted) return;
      setState(() => _pendingActions.remove(user.id));

      if (conversationId == null || conversationId.isEmpty) {
        PravaToast.show(
          context,
          message: 'Unable to start chat',
          type: PravaToastType.error,
        );
        return;
      }

      final preview = ChatPreview(
        id: conversationId,
        name: user.displayName.isNotEmpty ? user.displayName : user.username,
        lastMessage: 'Say hello on Prava',
        time: 'Now',
        unreadCount: 0,
        isGroup: false,
        isOnline: false,
        isMuted: false,
        isPinned: false,
        isTyping: false,
        lastMessageFromMe: false,
        delivery: MessageDeliveryState.sent,
        lastMessageId: null,
        lastMessageSeq: null,
        lastMessageType: ChatMessageType.text,
        lastMessageDeletedForAllAt: null,
      );

      PravaNavigator.push(
        context,
        ChatThreadPage(chat: preview),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _pendingActions.remove(user.id));
      PravaToast.show(
        context,
        message: 'Unable to start chat',
        type: PravaToastType.error,
      );
    }
  }

  void _openProfile(UserSearchResult user) {
    final profile = PublicProfile(
      displayName: user.displayName.isNotEmpty ? user.displayName : user.username,
      username: user.username,
      bio: 'Premium Prava member. Creating and connecting in realtime.',
      location: 'Prava Network',
      website: 'prava.app/@${user.username}',
      joined: 'Joined recently',
      verified: user.isVerified,
      online: user.isFriend,
      statusLine: user.isFriend ? 'Connected on Prava' : 'Active on Prava',
      coverCaption: 'Prava community',
      stats: [
        PublicStat(label: 'Posts', value: 0),
        PublicStat(label: 'Followers', value: 0),
        PublicStat(label: 'Following', value: 0),
      ],
      interests: ['Realtime', 'Community', 'Security'],
      posts: [
        PublicPost(
          body: 'New to Prava. Building my public profile.',
          timestamp: 'now',
          likes: '0',
          comments: '0',
          shares: '0',
          badge: 'New',
          tags: ['#prava'],
        ),
      ],
    );

    PravaNavigator.push(
      context,
      PublicProfilePage(
        userId: user.id,
        initialProfile: profile,
        initialIsFollowing: user.isFollowing,
        initialIsFollowedBy: user.isFollowedBy,
      ),
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

    final hasQuery = _query.length >= 2;

    return Scaffold(
      body: Stack(
        children: [
          _SearchBackdrop(isDark: isDark),
          SafeArea(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => FocusScope.of(context).unfocus(),
              child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                  child: Row(
                    children: [
                      Text(
                        'Search',
                        style: PravaTypography.h2.copyWith(
                          color: primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      _LivePill(loading: _loading),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: _SearchField(
                    controller: _controller,
                    border: border,
                    isDark: isDark,
                  ),
                ),
                if (hasQuery)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: Row(
                      children: [
                        Text(
                          _loading
                              ? 'Searching...'
                              : '${_results.length} results',
                          style:
                              PravaTypography.caption.copyWith(color: secondary),
                        ),
                        const Spacer(),
                        if (_loading)
                          const CupertinoActivityIndicator(radius: 8),
                      ],
                    ),
                  ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: hasQuery
                        ? _results.isEmpty && !_loading
                            ? _EmptyState(query: _query, primary: primary)
                            : ListView.separated(
                                key: const ValueKey('results'),
                                padding:
                                    const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                physics: const BouncingScrollPhysics(
                                  parent: AlwaysScrollableScrollPhysics(),
                                ),
                                itemCount: _results.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final user = _results[index];
                                  final pending = _isPending(user.id);
                                  return _UserResultTile(
                                    user: user,
                                    isDark: isDark,
                                    primary: primary,
                                    secondary: secondary,
                                    border: border,
                                    pending: pending,
                                    onTap: () => _openProfile(user),
                                    onAction: () {
                                      if (user.isFriend) {
                                        _startChat(user);
                                      } else {
                                        _toggleFollow(user);
                                      }
                                    },
                                  );
                                },
                              )
                        : _SearchTips(
                            onSuggestion: _applySuggestion,
                            primary: primary,
                            secondary: secondary,
                            isDark: isDark,
                          ),
                  ),
                ),
              ],
              ),
            ),
          ),
        ],
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
            autofocus: true,
            placeholder: 'Search by username',
            backgroundColor: Colors.transparent,
          ),
        ),
      ),
    );
  }
}

class _LivePill extends StatelessWidget {
  const _LivePill({required this.loading});

  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: PravaColors.accentPrimary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: loading ? PravaColors.accentPrimary : PravaColors.success,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            loading ? 'Searching' : 'Live',
            style: PravaTypography.caption.copyWith(
              color: PravaColors.accentPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _UserResultTile extends StatelessWidget {
  const _UserResultTile({
    required this.user,
    required this.isDark,
    required this.primary,
    required this.secondary,
    required this.border,
    required this.pending,
    required this.onTap,
    required this.onAction,
  });

  final UserSearchResult user;
  final bool isDark;
  final Color primary;
  final Color secondary;
  final Color border;
  final bool pending;
  final VoidCallback onTap;
  final VoidCallback onAction;

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
    final name =
        user.displayName.isNotEmpty ? user.displayName : user.username;
    final accent = _avatarColor(name);
    final baseColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.white.withValues(alpha: 0.9);
    final idSnippet =
        user.id.length > 6 ? user.id.substring(0, 6).toUpperCase() : user.id;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Ink(
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
                child: Text(
                  name.substring(0, 1).toUpperCase(),
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
                        Flexible(
                          child: Text(
                            user.displayName.isNotEmpty
                                ? user.displayName
                                : user.username,
                            style: PravaTypography.body.copyWith(
                              color: primary,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (user.isVerified) ...[
                          const SizedBox(width: 6),
                          Icon(
                            CupertinoIcons.check_mark_circled_solid,
                            size: 14,
                            color: PravaColors.accentPrimary,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.id.isEmpty
                          ? user.handle
                          : '${user.handle} - ID $idSnippet',
                      style: PravaTypography.caption.copyWith(color: secondary),
                    ),
                  ],
                ),
              ),
              _ActionButton(
                user: user,
                pending: pending,
                onTap: onAction,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.user,
    required this.pending,
    required this.onTap,
  });

  final UserSearchResult user;
  final bool pending;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (pending) {
      return const SizedBox(
        width: 36,
        height: 36,
        child: CupertinoActivityIndicator(radius: 10),
      );
    }

    if (user.isFriend) {
      return _IconActionButton(
        icon: CupertinoIcons.chat_bubble_2_fill,
        onTap: onTap,
      );
    }

    if (user.isRequested) {
      return _TextActionButton(
        label: 'Requested',
        icon: CupertinoIcons.xmark,
        outlined: true,
        onTap: onTap,
      );
    }

    if (user.isFollowedByOnly) {
      return _TextActionButton(
        label: 'Follow back',
        icon: CupertinoIcons.person_add,
        outlined: false,
        onTap: onTap,
      );
    }

    return _TextActionButton(
      label: 'Add friend',
      icon: CupertinoIcons.person_add_solid,
      outlined: false,
      onTap: onTap,
    );
  }
}

class _IconActionButton extends StatelessWidget {
  const _IconActionButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: PravaColors.accentPrimary,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          size: 16,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _TextActionButton extends StatelessWidget {
  const _TextActionButton({
    required this.label,
    required this.icon,
    required this.outlined,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool outlined;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final border =
        outlined ? Border.all(color: PravaColors.accentPrimary) : null;
    final background =
        outlined ? Colors.transparent : PravaColors.accentPrimary;
    final color = outlined ? PravaColors.accentPrimary : Colors.white;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(14),
          border: border,
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: PravaTypography.caption.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchTips extends StatelessWidget {
  const _SearchTips({
    required this.onSuggestion,
    required this.primary,
    required this.secondary,
    required this.isDark,
  });

  final ValueChanged<String> onSuggestion;
  final Color primary;
  final Color secondary;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    const suggestions = ['himan', 'creator', 'design', 'prava'];
    final surface =
        isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05);

    return ListView(
      key: const ValueKey('tips'),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        Text(
          'Find people instantly',
          style: PravaTypography.h3.copyWith(
            color: primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Type a username to connect. We show results as you type.',
          style: PravaTypography.bodySmall.copyWith(color: secondary),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Try searching',
                style: PravaTypography.caption.copyWith(
                  color: secondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: suggestions
                    .map(
                      (value) => ActionChip(
                        label: Text(
                          value,
                          style: PravaTypography.caption.copyWith(
                            color: PravaColors.accentPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onPressed: () => onSuggestion(value),
                        backgroundColor:
                            PravaColors.accentPrimary.withValues(alpha: 0.12),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.query,
    required this.primary,
  });

  final String query;
  final Color primary;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const ValueKey('empty'),
      padding: const EdgeInsets.fromLTRB(16, 80, 16, 16),
      children: [
        Center(
          child: Icon(
            CupertinoIcons.person_2,
            size: 40,
            color: primary.withValues(alpha: 0.4),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            'No matches for \"$query\"',
            style: PravaTypography.bodyLarge.copyWith(
              color: primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _SearchBackdrop extends StatelessWidget {
  const _SearchBackdrop({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return PravaBackground(isDark: isDark);
  }
}
