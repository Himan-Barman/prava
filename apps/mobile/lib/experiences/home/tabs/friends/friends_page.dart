import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../navigation/prava_navigator.dart';
import '../../../../services/chat_service.dart';
import '../../../../services/friend_connections_service.dart';
import '../../../../ui-system/colors.dart';
import '../../../../ui-system/feedback/prava_toast.dart';
import '../../../../ui-system/feedback/toast_type.dart';
import '../../../../ui-system/skeleton/chat_list_skeleton.dart';
import '../../../../ui-system/typography.dart';
import '../chats/chat_thread_page.dart';
import '../chats/chats_page.dart';
import '../profile/public_profile_page.dart';

enum _FriendsTab { friends, following, followers, requests }

class FriendsPage extends StatefulWidget {
  const FriendsPage({super.key});

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> {
  final FriendConnectionsService _connectionsService =
      FriendConnectionsService();
  final ChatService _chatService = ChatService();
  final TextEditingController _searchController = TextEditingController();

  final Set<String> _pendingActions = <String>{};
  _FriendsTab _tab = _FriendsTab.friends;
  bool _loading = true;
  List<FriendConnectionItem> _requests = [];
  List<FriendConnectionItem> _followingOnly = [];
  List<FriendConnectionItem> _friends = [];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadConnections();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadConnections({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final response = await _connectionsService.fetchConnections(limit: 100);
      if (!mounted) return;
      setState(() {
        _requests = response.requests;
        _followingOnly = response.sent;
        _friends = response.friends;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      PravaToast.show(
        context,
        message: 'Unable to load friends',
        type: PravaToastType.error,
      );
    }
  }

  bool _isPending(String userId) => _pendingActions.contains(userId);

  List<_FriendRowData> get _currentRows {
    final rows = switch (_tab) {
      _FriendsTab.friends =>
        _friends
            .map((item) => _FriendRowData(item, _FriendRowKind.friend))
            .toList(),
      _FriendsTab.following => [
        ..._followingOnly.map(
          (item) => _FriendRowData(item, _FriendRowKind.following),
        ),
        ..._friends.map((item) => _FriendRowData(item, _FriendRowKind.friend)),
      ],
      _FriendsTab.followers => [
        ..._requests.map(
          (item) => _FriendRowData(item, _FriendRowKind.follower),
        ),
        ..._friends.map((item) => _FriendRowData(item, _FriendRowKind.friend)),
      ],
      _FriendsTab.requests =>
        _requests
            .map((item) => _FriendRowData(item, _FriendRowKind.request))
            .toList(),
    };

    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return rows;
    return rows.where((row) {
      final user = row.item.user;
      return user.displayName.toLowerCase().contains(query) ||
          user.username.toLowerCase().contains(query);
    }).toList();
  }

  int _countFor(_FriendsTab tab) {
    return switch (tab) {
      _FriendsTab.friends => _friends.length,
      _FriendsTab.following => _followingOnly.length + _friends.length,
      _FriendsTab.followers => _requests.length + _friends.length,
      _FriendsTab.requests => _requests.length,
    };
  }

  String _searchPlaceholder() {
    return switch (_tab) {
      _FriendsTab.friends => 'Search friends',
      _FriendsTab.following => 'Search following',
      _FriendsTab.followers => 'Search followers',
      _FriendsTab.requests => 'Search friend requests',
    };
  }

  void _setTab(_FriendsTab tab) {
    if (_tab == tab) return;
    HapticFeedback.selectionClick();
    setState(() => _tab = tab);
  }

  void _openProfile(FriendConnectionItem item) {
    HapticFeedback.selectionClick();
    PravaNavigator.push(
      context,
      PublicProfilePage(
        userId: item.user.id,
        initialIsFollowing: item.isFollowing,
        initialIsFollowedBy: item.isFollowedBy,
      ),
    );
  }

  Future<void> _messageUser(FriendConnectionItem item) async {
    final user = item.user;
    if (_isPending(user.id)) return;
    HapticFeedback.selectionClick();
    setState(() => _pendingActions.add(user.id));
    try {
      final conversationId = await _chatService.createDm(otherUserId: user.id);
      if (!mounted) return;
      if (conversationId == null || conversationId.isEmpty) {
        throw Exception('Conversation not created');
      }
      final name = user.displayName.isNotEmpty
          ? user.displayName
          : user.username;
      await Navigator.of(context, rootNavigator: true).push(
        PravaNavigator.route(
          ChatThreadPage(
            chat: ChatPreview(
              id: conversationId,
              name: name,
              lastMessage: 'No messages yet',
              time: 'New',
              unreadCount: 0,
              isGroup: false,
              isOnline: user.isOnline,
              isMuted: false,
              isPinned: false,
              isFavorite: false,
              isStarred: false,
              isTyping: false,
              peerUserId: user.id,
              avatarUrl: user.avatarUrl,
              peerLastSeenAt: user.lastSeenAt,
              lastMessageFromMe: false,
              delivery: MessageDeliveryState.read,
            ),
          ),
          fullscreenDialog: true,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      PravaToast.show(
        context,
        message: 'Unable to open chat',
        type: PravaToastType.error,
      );
    } finally {
      if (mounted) setState(() => _pendingActions.remove(user.id));
    }
  }

  Future<void> _followBack(FriendConnectionItem item) async {
    final ok = await _runRelationshipAction(
      item.user.id,
      'Unable to follow back',
      () async {
        await _connectionsService.setFollow(item.user.id, true);
      },
    );
    if (ok) await _loadConnections(silent: true);
  }

  Future<void> _addFriend(FriendConnectionItem item) async {
    final ok = await _runRelationshipAction(
      item.user.id,
      'Unable to send request',
      () async {
        await _connectionsService.setFollow(item.user.id, true);
      },
    );
    if (!ok || !mounted) return;
    PravaToast.show(
      context,
      message: 'Friend request active',
      type: PravaToastType.success,
    );
  }

  Future<void> _unfriend(FriendConnectionItem item) async {
    final ok = await _runRelationshipAction(
      item.user.id,
      'Unable to unfriend',
      () => _connectionsService.removeConnection(item.user.id),
    );
    if (ok) await _loadConnections(silent: true);
  }

  Future<void> _removeFollower(FriendConnectionItem item) async {
    final ok = await _runRelationshipAction(
      item.user.id,
      'Unable to remove follower',
      () => _connectionsService.removeFollower(item.user.id),
    );
    if (ok) await _loadConnections(silent: true);
  }

  Future<void> _blockUser(FriendConnectionItem item) async {
    final ok = await _runRelationshipAction(
      item.user.id,
      'Unable to block user',
      () => _connectionsService.blockUser(item.user.id),
    );
    if (ok) await _loadConnections(silent: true);
  }

  Future<bool> _runRelationshipAction(
    String userId,
    String failureMessage,
    Future<void> Function() action,
  ) async {
    if (_isPending(userId)) return false;
    HapticFeedback.selectionClick();
    setState(() => _pendingActions.add(userId));
    try {
      await action();
      return true;
    } catch (_) {
      if (mounted) {
        PravaToast.show(
          context,
          message: failureMessage,
          type: PravaToastType.error,
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _pendingActions.remove(userId));
    }
  }

  Future<void> _showActions(_FriendRowData row) async {
    HapticFeedback.selectionClick();
    final isFriend = row.kind == _FriendRowKind.friend;
    final action = await showCupertinoModalPopup<String>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(_displayName(row.item.user)),
        actions: [
          if (!isFriend)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.of(context).pop('message'),
              child: const Text('Message'),
            ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(context).pop('profile'),
            child: const Text('View profile'),
          ),
          if (isFriend)
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.of(context).pop('unfriend'),
              child: const Text('Unfriend'),
            ),
          if (row.kind == _FriendRowKind.follower ||
              row.kind == _FriendRowKind.request)
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.of(context).pop('removeFollower'),
              child: const Text('Remove follower'),
            ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(context).pop('block'),
            child: const Text('Block'),
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
      case 'message':
        await _messageUser(row.item);
        break;
      case 'profile':
        _openProfile(row.item);
        break;
      case 'unfriend':
        await _unfriend(row.item);
        break;
      case 'removeFollower':
        await _removeFollower(row.item);
        break;
      case 'block':
        await _blockUser(row.item);
        break;
    }
  }

  String _displayName(FriendConnectionUser user) {
    return user.displayName.isNotEmpty ? user.displayName : user.username;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.pravaColors;
    final primary = tokens.textPrimary;
    final secondary = tokens.textSecondary;
    final border = tokens.borderSubtle;
    final rows = _currentRows;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Column(
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
                      color: tokens.backgroundSurface.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: border),
                    ),
                    child: CupertinoSearchTextField(
                      controller: _searchController,
                      placeholder: _searchPlaceholder(),
                      backgroundColor: Colors.transparent,
                      itemColor: tokens.iconSecondary,
                      style: PravaTypography.body.copyWith(
                        color: tokens.textPrimary,
                      ),
                      placeholderStyle: PravaTypography.body.copyWith(
                        color: tokens.textTertiary,
                      ),
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
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              children: [
                _FriendCapsule(
                  label: 'Friends',
                  count: _countFor(_FriendsTab.friends),
                  selected: _tab == _FriendsTab.friends,
                  onTap: () => _setTab(_FriendsTab.friends),
                ),
                const SizedBox(width: 8),
                _FriendCapsule(
                  label: 'Following',
                  count: _countFor(_FriendsTab.following),
                  selected: _tab == _FriendsTab.following,
                  onTap: () => _setTab(_FriendsTab.following),
                ),
                const SizedBox(width: 8),
                _FriendCapsule(
                  label: 'Followers',
                  count: _countFor(_FriendsTab.followers),
                  selected: _tab == _FriendsTab.followers,
                  onTap: () => _setTab(_FriendsTab.followers),
                ),
                const SizedBox(width: 8),
                _FriendCapsule(
                  label: 'Friend requests',
                  count: _countFor(_FriendsTab.requests),
                  selected: _tab == _FriendsTab.requests,
                  onTap: () => _setTab(_FriendsTab.requests),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const ChatListSkeleton()
                : RefreshIndicator(
                    onRefresh: () => _loadConnections(silent: true),
                    color: tokens.brandPrimary,
                    child: rows.isEmpty
                        ? _EmptyFriendsState(
                            title: _emptyTitle(),
                            subtitle: _searchController.text.trim().isEmpty
                                ? _emptySubtitle()
                                : 'Try another name or username.',
                            primary: primary,
                            secondary: secondary,
                          )
                        : ListView.separated(
                            keyboardDismissBehavior:
                                ScrollViewKeyboardDismissBehavior.onDrag,
                            physics: const BouncingScrollPhysics(
                              parent: AlwaysScrollableScrollPhysics(),
                            ),
                            padding: const EdgeInsets.fromLTRB(12, 2, 12, 18),
                            itemCount: rows.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final row = rows[index];
                              return _FriendRow(
                                row: row,
                                pending: _isPending(row.item.user.id),
                                primary: primary,
                                secondary: secondary,
                                onTap: () => _openProfile(row.item),
                                onPrimaryAction: () {
                                  switch (row.kind) {
                                    case _FriendRowKind.friend:
                                      _messageUser(row.item);
                                      break;
                                    case _FriendRowKind.follower:
                                      _followBack(row.item);
                                      break;
                                    case _FriendRowKind.following:
                                      _addFriend(row.item);
                                      break;
                                    case _FriendRowKind.request:
                                      _followBack(row.item);
                                      break;
                                  }
                                },
                                onMore: () => _showActions(row),
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  String _emptyTitle() {
    if (_searchController.text.trim().isNotEmpty) return 'No matches';
    return switch (_tab) {
      _FriendsTab.friends => 'No friends yet',
      _FriendsTab.following => 'Not following anyone',
      _FriendsTab.followers => 'No followers yet',
      _FriendsTab.requests => 'No friend requests',
    };
  }

  String _emptySubtitle() {
    return switch (_tab) {
      _FriendsTab.friends => 'Follow each other to become friends.',
      _FriendsTab.following => 'People you follow will show here.',
      _FriendsTab.followers => 'People following you will show here.',
      _FriendsTab.requests =>
        'New followers waiting for follow back show here.',
    };
  }
}

enum _FriendRowKind { friend, following, follower, request }

class _FriendRowData {
  const _FriendRowData(this.item, this.kind);

  final FriendConnectionItem item;
  final _FriendRowKind kind;
}

class _FriendCapsule extends StatelessWidget {
  const _FriendCapsule({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.pravaColors;
    final secondary = tokens.textSecondary;
    final border = tokens.borderSubtle;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        height: 36,
        decoration: BoxDecoration(
          color: selected ? tokens.brandContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? tokens.brandPrimary : border),
        ),
        child: Center(
          child: Text(
            '$label $count',
            style: PravaTypography.button.copyWith(
              color: selected ? tokens.brandContent : secondary,
              letterSpacing: 0,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _FriendRow extends StatelessWidget {
  const _FriendRow({
    required this.row,
    required this.pending,
    required this.primary,
    required this.secondary,
    required this.onTap,
    required this.onPrimaryAction,
    required this.onMore,
  });

  final _FriendRowData row;
  final bool pending;
  final Color primary;
  final Color secondary;
  final VoidCallback onTap;
  final VoidCallback onPrimaryAction;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final tokens = context.pravaColors;
    final surface = tokens.backgroundSurface;
    final border = tokens.borderSubtle;
    final user = row.item.user;
    final name = user.displayName.isNotEmpty ? user.displayName : user.username;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: border),
            boxShadow: [
              BoxShadow(
                color: tokens.shadowSoft,
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              _FriendAvatar(user: user),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: PravaTypography.bodyLarge.copyWith(
                              color: primary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (user.isVerified) ...[
                          const SizedBox(width: 5),
                          Icon(
                            CupertinoIcons.check_mark_circled_solid,
                            color: tokens.brandPrimary,
                            size: 15,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '@${user.username}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: PravaTypography.bodySmall.copyWith(
                        color: secondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _FriendActionButton(
                label: _buttonLabel(),
                pending: pending,
                compact: row.kind == _FriendRowKind.friend,
                onTap: onPrimaryAction,
              ),
              IconButton(
                onPressed: onMore,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                padding: EdgeInsets.zero,
                icon: Icon(
                  CupertinoIcons.ellipsis_vertical,
                  color: secondary,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _buttonLabel() {
    return switch (row.kind) {
      _FriendRowKind.friend => 'Message',
      _FriendRowKind.follower => 'Follow back',
      _FriendRowKind.following => 'Add friend',
      _FriendRowKind.request => 'Accept request',
    };
  }
}

class _FriendAvatar extends StatelessWidget {
  const _FriendAvatar({required this.user});

  final FriendConnectionUser user;

  @override
  Widget build(BuildContext context) {
    final tokens = context.pravaColors;
    final initial =
        (user.displayName.isNotEmpty ? user.displayName : user.username).trim();

    return SizedBox(
      width: 52,
      height: 52,
      child: ClipOval(
        child: user.avatarUrl.trim().isNotEmpty
            ? Image.network(user.avatarUrl, fit: BoxFit.cover)
            : Container(
                color: tokens.brandContainer,
                child: Center(
                  child: Text(
                    initial.isEmpty ? '?' : initial[0].toUpperCase(),
                    style: PravaTypography.h3.copyWith(
                      color: tokens.brandContent,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

class _FriendActionButton extends StatelessWidget {
  const _FriendActionButton({
    required this.label,
    required this.pending,
    required this.compact,
    required this.onTap,
  });

  final String label;
  final bool pending;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.pravaColors;
    final constraints = compact
        ? const BoxConstraints(minWidth: 72, maxWidth: 88)
        : const BoxConstraints(minWidth: 90, maxWidth: 118);

    return GestureDetector(
      onTap: pending ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 34,
        constraints: constraints,
        padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 12),
        decoration: BoxDecoration(
          color: pending ? tokens.brandContainer : tokens.brandPrimary,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Center(
          child: pending
              ? const CupertinoActivityIndicator(radius: 8)
              : Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PravaTypography.button.copyWith(
                    color: pending ? tokens.brandContent : tokens.textInverse,
                    letterSpacing: 0,
                    fontWeight: FontWeight.w800,
                  ),
                ),
        ),
      ),
    );
  }
}

class _EmptyFriendsState extends StatelessWidget {
  const _EmptyFriendsState({
    required this.title,
    required this.subtitle,
    required this.primary,
    required this.secondary,
  });

  final String title;
  final String subtitle;
  final Color primary;
  final Color secondary;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 80, 24, 16),
      children: [
        Icon(CupertinoIcons.person_2, size: 40, color: secondary),
        const SizedBox(height: 12),
        Text(
          title,
          textAlign: TextAlign.center,
          style: PravaTypography.bodyLarge.copyWith(
            color: primary,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: PravaTypography.body.copyWith(color: secondary),
        ),
      ],
    );
  }
}
