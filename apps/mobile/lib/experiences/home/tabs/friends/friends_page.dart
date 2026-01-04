import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../navigation/prava_navigator.dart';
import '../../../../ui-system/background.dart';
import '../../../../ui-system/colors.dart';
import '../../../../ui-system/typography.dart';
import '../../../../ui-system/feedback/prava_toast.dart';
import '../../../../ui-system/feedback/toast_type.dart';
import '../../../../services/friend_connections_service.dart';
import '../profile/public_profile_page.dart';

enum FriendsSection { requests, sent, friends }

enum SentRequestStatus { pending, seen }

enum FriendMenuAction { viewProfile, remove, block }

class FriendsPage extends StatefulWidget {
  const FriendsPage({super.key});

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> {
  final FriendConnectionsService _connectionsService =
      FriendConnectionsService();
  final Set<String> _pendingActions = <String>{};

  FriendsSection _section = FriendsSection.requests;
  bool _loading = true;
  List<FriendRequest> _requests = [];
  List<SentRequest> _sent = [];
  List<FriendConnection> _friends = [];

  @override
  void initState() {
    super.initState();
    _loadConnections();
  }

  bool _isPending(String userId) => _pendingActions.contains(userId);

  Future<void> _loadConnections({bool silent = false}) async {
    if (!silent) {
      setState(() => _loading = true);
    }
    try {
      final response = await _connectionsService.fetchConnections(limit: 30);
      if (!mounted) return;
      setState(() {
        _applyConnections(response);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      PravaToast.show(
        context,
        message: 'Unable to load connections',
        type: PravaToastType.error,
      );
    }
  }

  void _applyConnections(FriendConnectionsResponse response) {
    final existingFriends = <String, FriendConnection>{
      for (final friend in _friends) friend.user.id: friend,
    };

    _requests = response.requests.map(_mapRequest).toList();
    _sent = response.sent.map(_mapSent).toList();
    _friends = response.friends
        .map(
          (item) => _mapFriend(
            item,
            existingFriends[item.user.id],
          ),
        )
        .toList();
  }

  FriendUser _mapUser(FriendConnectionUser user) {
    return FriendUser(
      id: user.id,
      displayName:
          user.displayName.isNotEmpty ? user.displayName : user.username,
      username: user.username,
      bio: user.bio,
      location: user.location,
      isVerified: user.isVerified,
      isOnline: user.isOnline,
      tags: const [],
      stats: const FriendStats(posts: 0, followers: 0, following: 0),
      joined: _formatJoined(user.createdAt),
      highlight:
          user.bio.isNotEmpty ? user.bio : 'Connecting on Prava',
    );
  }

  FriendRequest _mapRequest(FriendConnectionItem item) {
    final receivedAt = _formatRelativeTime(item.since);
    return FriendRequest(
      user: _mapUser(item.user),
      message: _requestMessage(item.user),
      mutualCount: 0,
      sharedSpaces: 0,
      receivedAt: receivedAt.isEmpty ? 'recently' : receivedAt,
      priorityLabel: _priorityLabel(item.since),
    );
  }

  SentRequest _mapSent(FriendConnectionItem item) {
    final time = _formatRelativeTime(item.since);
    final label = time.isEmpty ? 'Sent recently' : 'Sent $time';
    return SentRequest(
      user: _mapUser(item.user),
      status: SentRequestStatus.pending,
      timeLabel: label,
      note: item.user.bio.isNotEmpty
          ? item.user.bio
          : 'Awaiting response.',
    );
  }

  FriendConnection _mapFriend(
    FriendConnectionItem item,
    FriendConnection? existing,
  ) {
    return FriendConnection(
      user: _mapUser(item.user),
      connectedSince: _connectionLabel(item.since),
      mutualCount: 0,
      sharedSpaces: 0,
      presenceLabel:
          item.user.isOnline ? 'Active now' : 'Active recently',
      isFavorite: existing?.isFavorite ?? false,
      isMuted: existing?.isMuted ?? false,
      isPinned: existing?.isPinned ?? false,
    );
  }

  String _requestMessage(FriendConnectionUser user) {
    if (user.bio.isNotEmpty) return user.bio;
    if (user.location.isNotEmpty) {
      return 'Based in ${user.location}. Wants to connect.';
    }
    return 'Wants to connect on Prava.';
  }

  String _priorityLabel(DateTime? since) {
    if (since == null) return '';
    final diff = DateTime.now().difference(since);
    if (diff.inMinutes <= 10) return 'Priority';
    if (diff.inHours < 24) return 'New';
    return '';
  }

  String _formatRelativeTime(DateTime? value) {
    if (value == null) return '';
    final diff = DateTime.now().difference(value);

    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';

    final weeks = diff.inDays ~/ 7;
    if (weeks < 5) return '${weeks}w ago';

    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$month/$day/${value.year}';
  }

  String _formatJoined(DateTime? value) {
    if (value == null) return 'Joined recently';
    return 'Joined ${value.year}';
  }

  String _connectionLabel(DateTime? value) {
    final relative = _formatRelativeTime(value);
    if (relative.isEmpty) return 'Connected';
    if (relative == 'just now') return 'Connected just now';
    if (relative.contains('/')) return 'Connected $relative';
    return 'Connected $relative';
  }

  void _setSection(FriendsSection section) {
    if (_section == section) return;
    HapticFeedback.selectionClick();
    setState(() => _section = section);
  }

  Future<bool> _runAction(
    String userId,
    String failureMessage,
    Future<void> Function() action,
  ) async {
    if (_isPending(userId)) return false;
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
      if (mounted) {
        setState(() => _pendingActions.remove(userId));
      }
    }
  }

  Future<void> _acceptRequest(FriendRequest request) async {
    HapticFeedback.selectionClick();
    final ok = await _runAction(
      request.user.id,
      'Unable to accept request',
      () => _connectionsService.setFollow(request.user.id, true),
    );
    if (!ok || !mounted) return;

    setState(() {
      _requests.removeWhere((item) => item.user.id == request.user.id);
      _friends = List<FriendConnection>.from(_friends)
        ..insert(
          0,
          FriendConnection(
            user: request.user,
            connectedSince: 'Connected just now',
            mutualCount: request.mutualCount,
            sharedSpaces: request.sharedSpaces,
            presenceLabel:
                request.user.isOnline ? 'Active now' : 'Active recently',
            isFavorite: false,
            isMuted: false,
            isPinned: false,
          ),
        );
    });
    PravaToast.show(
      context,
      message: 'Friend request accepted',
      type: PravaToastType.success,
    );
  }

  Future<void> _declineRequest(FriendRequest request) async {
    HapticFeedback.selectionClick();
    final ok = await _runAction(
      request.user.id,
      'Unable to decline request',
      () => _connectionsService.removeFollower(request.user.id),
    );
    if (!ok || !mounted) return;

    setState(() {
      _requests.removeWhere((item) => item.user.id == request.user.id);
    });
    PravaToast.show(
      context,
      message: 'Request declined',
      type: PravaToastType.info,
    );
  }

  Future<void> _cancelSent(SentRequest request) async {
    HapticFeedback.selectionClick();
    final ok = await _runAction(
      request.user.id,
      'Unable to cancel request',
      () => _connectionsService.setFollow(request.user.id, false),
    );
    if (!ok || !mounted) return;

    setState(() {
      _sent.removeWhere((item) => item.user.id == request.user.id);
    });
    PravaToast.show(
      context,
      message: 'Request canceled',
      type: PravaToastType.warning,
    );
  }

  void _nudgeSent(SentRequest request) {
    HapticFeedback.selectionClick();
    _updateSentRequest(
      request.user.id,
      (item) => item.copyWith(
        status: SentRequestStatus.pending,
        timeLabel: 'Nudged just now',
      ),
    );
    PravaToast.show(
      context,
      message: 'Nudge sent to @${request.user.username}',
      type: PravaToastType.success,
    );
  }

  void _toggleFavorite(FriendConnection friend) {
    HapticFeedback.selectionClick();
    _updateFriend(
      friend.user.id,
      (item) => item.copyWith(isFavorite: !item.isFavorite),
    );
    PravaToast.show(
      context,
      message: friend.isFavorite
          ? 'Removed from favorites'
          : 'Marked as favorite',
      type: PravaToastType.info,
    );
  }

  void _toggleMute(FriendConnection friend) {
    HapticFeedback.selectionClick();
    _updateFriend(
      friend.user.id,
      (item) => item.copyWith(isMuted: !item.isMuted),
    );
    PravaToast.show(
      context,
      message: friend.isMuted ? 'Unmuted' : 'Muted notifications',
      type: PravaToastType.info,
    );
  }

  void _togglePinned(FriendConnection friend) {
    HapticFeedback.selectionClick();
    _updateFriend(
      friend.user.id,
      (item) => item.copyWith(isPinned: !item.isPinned),
    );
    PravaToast.show(
      context,
      message: friend.isPinned ? 'Unpinned' : 'Pinned to top',
      type: PravaToastType.success,
    );
  }

  Future<void> _handleFriendMenu(
    FriendConnection friend,
    FriendMenuAction action,
  ) async {
    HapticFeedback.selectionClick();
    switch (action) {
      case FriendMenuAction.viewProfile:
        _openProfile(
          friend.user,
          isFollowing: true,
          isFollowedBy: true,
        );
        return;
      case FriendMenuAction.remove:
        final ok = await _runAction(
          friend.user.id,
          'Unable to remove connection',
          () => _connectionsService.removeConnection(friend.user.id),
        );
        if (!ok || !mounted) return;
        setState(() {
          _friends.removeWhere((item) => item.user.id == friend.user.id);
        });
        PravaToast.show(
          context,
          message: 'Removed ${friend.user.displayName}',
          type: PravaToastType.warning,
        );
        return;
      case FriendMenuAction.block:
        final ok = await _runAction(
          friend.user.id,
          'Unable to block profile',
          () => _connectionsService.removeConnection(friend.user.id),
        );
        if (!ok || !mounted) return;
        setState(() {
          _friends.removeWhere((item) => item.user.id == friend.user.id);
        });
        PravaToast.show(
          context,
          message: 'Blocked ${friend.user.displayName}',
          type: PravaToastType.error,
        );
        return;
    }
  }

  void _updateFriend(
    String userId,
    FriendConnection Function(FriendConnection) update,
  ) {
    final index = _friends.indexWhere((item) => item.user.id == userId);
    if (index == -1) return;
    setState(() {
      final updated = update(_friends[index]);
      _friends = List<FriendConnection>.from(_friends);
      _friends[index] = updated;
    });
  }

  void _updateSentRequest(
    String userId,
    SentRequest Function(SentRequest) update,
  ) {
    final index = _sent.indexWhere((item) => item.user.id == userId);
    if (index == -1) return;
    setState(() {
      final updated = update(_sent[index]);
      _sent = List<SentRequest>.from(_sent);
      _sent[index] = updated;
    });
  }

  void _openProfile(
    FriendUser user, {
    required bool isFollowing,
    required bool isFollowedBy,
  }) {
    HapticFeedback.selectionClick();
    final profile = _buildPublicProfile(
      user,
      isFollowing: isFollowing,
      isFollowedBy: isFollowedBy,
    );
    PravaNavigator.push(
      context,
      PublicProfilePage(
        userId: user.id,
        initialProfile: profile,
        initialIsFollowing: isFollowing,
        initialIsFollowedBy: isFollowedBy,
      ),
    );
  }

  PublicProfile _buildPublicProfile(
    FriendUser user, {
    required bool isFollowing,
    required bool isFollowedBy,
  }) {
    String statusLine = 'Active on Prava';
    if (isFollowing && isFollowedBy) {
      statusLine = 'Connected on Prava';
    } else if (isFollowedBy) {
      statusLine = 'Requested you on Prava';
    } else if (isFollowing) {
      statusLine = 'You requested on Prava';
    }

    final tags = user.tags.isEmpty
        ? const ['#prava']
        : user.tags
            .take(3)
            .map(
              (tag) => '#${tag.toLowerCase().replaceAll(' ', '')}',
            )
            .toList();

    return PublicProfile(
      displayName: user.displayName,
      username: user.username,
      bio: user.bio,
      location: user.location,
      website: 'prava.app/@${user.username}',
      joined: user.joined,
      verified: user.isVerified,
      online: user.isOnline,
      statusLine: statusLine,
      coverCaption: user.highlight,
      stats: [
        PublicStat(label: 'Posts', value: user.stats.posts),
        PublicStat(label: 'Followers', value: user.stats.followers),
        PublicStat(label: 'Following', value: user.stats.following),
      ],
      interests: user.tags,
      posts: [
        PublicPost(
          body: user.highlight,
          timestamp: 'now',
          likes: _formatCount(user.stats.followers ~/ 3),
          comments: _formatCount(user.stats.followers ~/ 18),
          shares: _formatCount(user.stats.followers ~/ 40),
          badge: isFollowing && isFollowedBy ? 'Friend' : 'Update',
          tags: tags,
        ),
      ],
    );
  }

  String _sectionLabel(FriendsSection section) {
    switch (section) {
      case FriendsSection.requests:
        return 'Friend requests';
      case FriendsSection.sent:
        return 'Sent requests';
      case FriendsSection.friends:
        return 'Friends';
    }
  }

  Color _sentStatusColor(SentRequestStatus status) {
    switch (status) {
      case SentRequestStatus.pending:
        return PravaColors.warning;
      case SentRequestStatus.seen:
        return PravaColors.accentPrimary;
    }
  }

  static String _formatCount(int value) {
    if (value >= 1000000) {
      final short =
          (value / 1000000).toStringAsFixed(value % 1000000 == 0 ? 0 : 1);
      return '${short}M';
    }
    if (value >= 1000) {
      final short =
          (value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1);
      return '${short}K';
    }
    return value.toString();
  }

  Widget _buildSectionBody({
    required bool isDark,
    required Color primary,
    required Color secondary,
    required Color surface,
    required Color border,
  }) {
    if (_loading &&
        _requests.isEmpty &&
        _sent.isEmpty &&
        _friends.isEmpty) {
      return _LoadingState(primary: primary, secondary: secondary);
    }

    switch (_section) {
      case FriendsSection.requests:
        if (_requests.isEmpty) {
          return _EmptyState(
            key: const ValueKey('requests-empty'),
            icon: CupertinoIcons.person_crop_circle_badge_exclam,
            title: 'No requests yet',
            subtitle: 'New friend requests will appear here.',
            primary: primary,
            secondary: secondary,
          );
        }
        return ListView(
          key: const ValueKey('requests'),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          children: [
            _SectionHeader(
              title: _sectionLabel(FriendsSection.requests),
              subtitle:
                  '${_requests.length} pending | ${_friends.length} total friends',
              primary: primary,
              secondary: secondary,
            ),
            const SizedBox(height: 12),
            for (final request in _requests)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _FriendRequestCard(
                  request: request,
                  isDark: isDark,
                  primary: primary,
                  secondary: secondary,
                  border: border,
                  surface: surface,
                  onAccept: () {
                    _acceptRequest(request);
                  },
                  onDecline: () {
                    _declineRequest(request);
                  },
                  onProfile: () => _openProfile(
                    request.user,
                    isFollowing: false,
                    isFollowedBy: true,
                  ),
                ),
              ),
          ],
        );
      case FriendsSection.sent:
        if (_sent.isEmpty) {
          return _EmptyState(
            key: const ValueKey('sent-empty'),
            icon: CupertinoIcons.paperplane,
            title: 'No sent requests',
            subtitle: 'Send new requests to grow your circle.',
            primary: primary,
            secondary: secondary,
          );
        }
        return ListView(
          key: const ValueKey('sent'),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          children: [
            _SectionHeader(
              title: _sectionLabel(FriendsSection.sent),
              subtitle:
                  '${_sent.length} waiting | Track responses in realtime',
              primary: primary,
              secondary: secondary,
            ),
            const SizedBox(height: 12),
            for (final request in _sent)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _SentRequestCard(
                  request: request,
                  isDark: isDark,
                  primary: primary,
                  secondary: secondary,
                  border: border,
                  surface: surface,
                  statusColor: _sentStatusColor(request.status),
                  onCancel: () {
                    _cancelSent(request);
                  },
                  onNudge: () => _nudgeSent(request),
                  onProfile: () => _openProfile(
                    request.user,
                    isFollowing: true,
                    isFollowedBy: false,
                  ),
                ),
              ),
          ],
        );
      case FriendsSection.friends:
        if (_friends.isEmpty) {
          return _EmptyState(
            key: const ValueKey('friends-empty'),
            icon: CupertinoIcons.person_2,
            title: 'No friends yet',
            subtitle: 'Accept requests to start building your network.',
            primary: primary,
            secondary: secondary,
          );
        }
        return ListView(
          key: const ValueKey('friends'),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          children: [
            _SectionHeader(
              title: _sectionLabel(FriendsSection.friends),
              subtitle:
                  '${_friends.length} connections | Manage with full control',
              primary: primary,
              secondary: secondary,
            ),
            const SizedBox(height: 12),
            for (final friend in _friends)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _FriendCard(
                  friend: friend,
                  isDark: isDark,
                  primary: primary,
                  secondary: secondary,
                  border: border,
                  surface: surface,
                  onMessage: () {
                    HapticFeedback.selectionClick();
                    PravaToast.show(
                      context,
                      message: 'Opening chat with ${friend.user.displayName}',
                      type: PravaToastType.success,
                    );
                  },
                  onCall: () {
                    HapticFeedback.selectionClick();
                    PravaToast.show(
                      context,
                      message: 'Starting call with ${friend.user.displayName}',
                      type: PravaToastType.info,
                    );
                  },
                  onProfile: () => _openProfile(
                    friend.user,
                    isFollowing: true,
                    isFollowedBy: true,
                  ),
                  onToggleFavorite: () => _toggleFavorite(friend),
                  onToggleMute: () => _toggleMute(friend),
                  onTogglePinned: () => _togglePinned(friend),
                  onMenuAction: (action) {
                    _handleFriendMenu(friend, action);
                  },
                ),
              ),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary =
        isDark ? PravaColors.darkTextPrimary : PravaColors.lightTextPrimary;
    final secondary =
        isDark ? PravaColors.darkTextSecondary : PravaColors.lightTextSecondary;
    final surface =
        isDark ? PravaColors.darkBgSurface : PravaColors.lightBgSurface;
    final border =
        isDark ? PravaColors.darkBorderSubtle : PravaColors.lightBorderSubtle;

    return Scaffold(
      body: Stack(
        children: [
          _FriendsBackdrop(isDark: isDark),
          SafeArea(
            child: Column(
              children: [
                _FriendsTopBar(
                  section: _section,
                  primary: primary,
                  border: border,
                  isDark: isDark,
                  loading: _loading,
                  onSectionChanged: _setSection,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: _SummaryStrip(
                    selected: _section,
                    requests: _requests.length,
                    sent: _sent.length,
                    friends: _friends.length,
                    primary: primary,
                    secondary: secondary,
                    surface: surface,
                    border: border,
                    isDark: isDark,
                    onSelect: _setSection,
                  ),
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    transitionBuilder: (child, animation) {
                      final fade = FadeTransition(
                        opacity: animation,
                        child: child,
                      );
                      return SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.06),
                          end: Offset.zero,
                        ).animate(animation),
                        child: fade,
                      );
                    },
                    child: _buildSectionBody(
                      isDark: isDark,
                      primary: primary,
                      secondary: secondary,
                      surface: surface,
                      border: border,
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

class _FriendsTopBar extends StatelessWidget {
  const _FriendsTopBar({
    required this.section,
    required this.primary,
    required this.border,
    required this.isDark,
    required this.loading,
    required this.onSectionChanged,
  });

  final FriendsSection section;
  final Color primary;
  final Color border;
  final bool isDark;
  final bool loading;
  final ValueChanged<FriendsSection> onSectionChanged;

  @override
  Widget build(BuildContext context) {
    final surface =
        isDark ? Colors.black.withValues(alpha: 0.45) : Colors.white.withValues(alpha: 0.8);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: border),
            ),
            child: Row(
              children: [
                Text(
                  'Friends',
                  style: PravaTypography.h3.copyWith(
                    color: primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                _RealtimePill(loading: loading),
                const SizedBox(width: 8),
                _SectionMenu(
                  section: section,
                  onChanged: onSectionChanged,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionMenu extends StatelessWidget {
  const _SectionMenu({
    required this.section,
    required this.onChanged,
  });

  final FriendsSection section;
  final ValueChanged<FriendsSection> onChanged;

  String _label(FriendsSection section) {
    switch (section) {
      case FriendsSection.requests:
        return 'Requests';
      case FriendsSection.sent:
        return 'Sent';
      case FriendsSection.friends:
        return 'Friends';
    }
  }

  IconData _icon(FriendsSection section) {
    switch (section) {
      case FriendsSection.requests:
        return CupertinoIcons.person_crop_circle_badge_plus;
      case FriendsSection.sent:
        return CupertinoIcons.paperplane_fill;
      case FriendsSection.friends:
        return CupertinoIcons.person_2_fill;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary =
        isDark ? PravaColors.darkTextPrimary : PravaColors.lightTextPrimary;
    final border =
        isDark ? PravaColors.darkBorderSubtle : PravaColors.lightBorderSubtle;

    return PopupMenuButton<FriendsSection>(
      onSelected: onChanged,
      color:
          isDark ? PravaColors.darkBgElevated : PravaColors.lightBgElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      itemBuilder: (context) => [
        for (final option in FriendsSection.values)
          PopupMenuItem(
            value: option,
            child: Row(
              children: [
                Icon(
                  _icon(option),
                  size: 18,
                  color: PravaColors.accentPrimary,
                ),
                const SizedBox(width: 10),
                Text(
                  _label(option),
                  style: PravaTypography.body.copyWith(color: primary),
                ),
              ],
            ),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? Colors.white10 : Colors.black12,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _icon(section),
              size: 16,
              color: PravaColors.accentPrimary,
            ),
            const SizedBox(width: 6),
            Text(
              _label(section),
              style: PravaTypography.caption.copyWith(
                color: primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              CupertinoIcons.chevron_down,
              size: 14,
              color: primary,
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({
    required this.selected,
    required this.requests,
    required this.sent,
    required this.friends,
    required this.primary,
    required this.secondary,
    required this.surface,
    required this.border,
    required this.isDark,
    required this.onSelect,
  });

  final FriendsSection selected;
  final int requests;
  final int sent;
  final int friends;
  final Color primary;
  final Color secondary;
  final Color surface;
  final Color border;
  final bool isDark;
  final ValueChanged<FriendsSection> onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SummaryTile(
            label: 'Requests',
            count: requests,
            selected: selected == FriendsSection.requests,
            primary: primary,
            secondary: secondary,
            surface: surface,
            border: border,
            isDark: isDark,
            onTap: () => onSelect(FriendsSection.requests),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SummaryTile(
            label: 'Sent',
            count: sent,
            selected: selected == FriendsSection.sent,
            primary: primary,
            secondary: secondary,
            surface: surface,
            border: border,
            isDark: isDark,
            onTap: () => onSelect(FriendsSection.sent),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SummaryTile(
            label: 'Friends',
            count: friends,
            selected: selected == FriendsSection.friends,
            primary: primary,
            secondary: secondary,
            surface: surface,
            border: border,
            isDark: isDark,
            onTap: () => onSelect(FriendsSection.friends),
          ),
        ),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.label,
    required this.count,
    required this.selected,
    required this.primary,
    required this.secondary,
    required this.surface,
    required this.border,
    required this.isDark,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final Color primary;
  final Color secondary;
  final Color surface;
  final Color border;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final highlight = PravaColors.accentPrimary.withValues(alpha: 0.12);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? highlight : surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? PravaColors.accentPrimary.withValues(alpha: 0.4)
                : border,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: PravaColors.accentPrimary
                        .withValues(alpha: isDark ? 0.25 : 0.15),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ]
              : [],
        ),
        child: Column(
          children: [
            Text(
              count.toString(),
              style: PravaTypography.h3.copyWith(
                color: primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: PravaTypography.caption.copyWith(
                color: secondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: PravaTypography.h3.copyWith(
            color: primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: PravaTypography.bodySmall.copyWith(color: secondary),
        ),
      ],
    );
  }
}

class _FriendRequestCard extends StatelessWidget {
  const _FriendRequestCard({
    required this.request,
    required this.isDark,
    required this.primary,
    required this.secondary,
    required this.border,
    required this.surface,
    required this.onAccept,
    required this.onDecline,
    required this.onProfile,
  });

  final FriendRequest request;
  final bool isDark;
  final Color primary;
  final Color secondary;
  final Color border;
  final Color surface;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Avatar(
                initials: request.user.initials,
                isOnline: request.user.isOnline,
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
                            request.user.displayName,
                            style: PravaTypography.bodyLarge.copyWith(
                              color: primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (request.user.isVerified)
                          const Icon(
                            CupertinoIcons.checkmark_seal_fill,
                            size: 16,
                            color: PravaColors.accentPrimary,
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _HandleLink(
                          username: request.user.username,
                          onTap: onProfile,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          request.receivedAt,
                          style: PravaTypography.caption.copyWith(
                            color: secondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (request.priorityLabel.isNotEmpty)
                _StatusPill(
                  label: request.priorityLabel,
                  color: PravaColors.accentPrimary,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            request.message,
            style: PravaTypography.body.copyWith(color: primary),
          ),
          const SizedBox(height: 12),
          if (request.mutualCount > 0 || request.sharedSpaces > 0) ...[
            Row(
              children: [
                if (request.mutualCount > 0)
                  _MetaItem(
                    icon: CupertinoIcons.person_2_fill,
                    label: '${request.mutualCount} mutuals',
                    secondary: secondary,
                  ),
                if (request.mutualCount > 0 &&
                    request.sharedSpaces > 0)
                  const SizedBox(width: 12),
                if (request.sharedSpaces > 0)
                  _MetaItem(
                    icon: CupertinoIcons.square_stack_3d_up_fill,
                    label: '${request.sharedSpaces} shared spaces',
                    secondary: secondary,
                  ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          if (request.user.tags.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: request.user.tags
                  .map(
                    (tag) => _TagPill(label: tag, secondary: secondary),
                  )
                  .toList(),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  label: 'Accept',
                  onTap: onAccept,
                  filled: true,
                  icon: CupertinoIcons.check_mark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionButton(
                  label: 'Decline',
                  onTap: onDecline,
                  filled: false,
                  icon: CupertinoIcons.xmark,
                  color: PravaColors.error,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SentRequestCard extends StatelessWidget {
  const _SentRequestCard({
    required this.request,
    required this.isDark,
    required this.primary,
    required this.secondary,
    required this.border,
    required this.surface,
    required this.statusColor,
    required this.onCancel,
    required this.onNudge,
    required this.onProfile,
  });

  final SentRequest request;
  final bool isDark;
  final Color primary;
  final Color secondary;
  final Color border;
  final Color surface;
  final Color statusColor;
  final VoidCallback onCancel;
  final VoidCallback onNudge;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Avatar(
                initials: request.user.initials,
                isOnline: request.user.isOnline,
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
                            request.user.displayName,
                            style: PravaTypography.bodyLarge.copyWith(
                              color: primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (request.user.isVerified)
                          const Icon(
                            CupertinoIcons.checkmark_seal_fill,
                            size: 16,
                            color: PravaColors.accentPrimary,
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _HandleLink(
                          username: request.user.username,
                          onTap: onProfile,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          request.timeLabel,
                          style: PravaTypography.caption.copyWith(
                            color: secondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _StatusPill(
                label: request.statusLabel,
                color: statusColor,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            request.note,
            style: PravaTypography.body.copyWith(color: primary),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _MetaItem(
                icon: CupertinoIcons.clock_fill,
                label: request.timeLabel,
                secondary: secondary,
              ),
              const SizedBox(width: 12),
              _MetaItem(
                icon: CupertinoIcons.antenna_radiowaves_left_right,
                label: 'Realtime updates',
                secondary: secondary,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  label: 'Nudge',
                  onTap: onNudge,
                  filled: true,
                  icon: CupertinoIcons.bell_solid,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionButton(
                  label: 'Cancel',
                  onTap: onCancel,
                  filled: false,
                  icon: CupertinoIcons.xmark_circle,
                  color: PravaColors.error,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FriendCard extends StatelessWidget {
  const _FriendCard({
    required this.friend,
    required this.isDark,
    required this.primary,
    required this.secondary,
    required this.border,
    required this.surface,
    required this.onMessage,
    required this.onCall,
    required this.onProfile,
    required this.onToggleFavorite,
    required this.onToggleMute,
    required this.onTogglePinned,
    required this.onMenuAction,
  });

  final FriendConnection friend;
  final bool isDark;
  final Color primary;
  final Color secondary;
  final Color border;
  final Color surface;
  final VoidCallback onMessage;
  final VoidCallback onCall;
  final VoidCallback onProfile;
  final VoidCallback onToggleFavorite;
  final VoidCallback onToggleMute;
  final VoidCallback onTogglePinned;
  final ValueChanged<FriendMenuAction> onMenuAction;

  @override
  Widget build(BuildContext context) {
    final highlight = friend.isFavorite
        ? PravaColors.accentPrimary.withValues(alpha: 0.08)
        : surface;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: highlight,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Avatar(
                initials: friend.user.initials,
                isOnline: friend.user.isOnline,
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
                            friend.user.displayName,
                            style: PravaTypography.bodyLarge.copyWith(
                              color: primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (friend.user.isVerified)
                          const Icon(
                            CupertinoIcons.checkmark_seal_fill,
                            size: 16,
                            color: PravaColors.accentPrimary,
                          ),
                        if (friend.isFavorite) ...[
                          const SizedBox(width: 6),
                          const Icon(
                            CupertinoIcons.star_fill,
                            size: 14,
                            color: PravaColors.warning,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _HandleLink(
                          username: friend.user.username,
                          onTap: onProfile,
                        ),
                        const SizedBox(width: 8),
                        _StatusPill(
                          label: friend.presenceLabel,
                          color: friend.user.isOnline
                              ? PravaColors.success
                              : PravaColors.accentMuted,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<FriendMenuAction>(
                onSelected: onMenuAction,
                color: isDark
                    ? PravaColors.darkBgElevated
                    : PravaColors.lightBgElevated,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: FriendMenuAction.viewProfile,
                    child: Row(
                      children: [
                        const Icon(
                          CupertinoIcons.person_crop_circle,
                          size: 18,
                          color: PravaColors.accentPrimary,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'View profile',
                          style: PravaTypography.body.copyWith(color: primary),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: FriendMenuAction.remove,
                    child: Row(
                      children: [
                        const Icon(
                          CupertinoIcons.person_crop_circle_badge_minus,
                          size: 18,
                          color: PravaColors.warning,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Remove friend',
                          style: PravaTypography.body.copyWith(color: primary),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: FriendMenuAction.block,
                    child: Row(
                      children: [
                        const Icon(
                          CupertinoIcons.hand_raised_fill,
                          size: 18,
                          color: PravaColors.error,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Block',
                          style: PravaTypography.body.copyWith(
                            color: PravaColors.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                child: const _IconPill(icon: CupertinoIcons.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            friend.user.bio,
            style: PravaTypography.body.copyWith(color: primary),
          ),
          const SizedBox(height: 12),
          if (friend.user.tags.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: friend.user.tags
                  .map(
                    (tag) => _TagPill(label: tag, secondary: secondary),
                  )
                  .toList(),
            ),
            const SizedBox(height: 12),
          ],
          if (friend.mutualCount > 0 || friend.sharedSpaces > 0) ...[
            Row(
              children: [
                if (friend.mutualCount > 0)
                  _MetaItem(
                    icon: CupertinoIcons.person_2_fill,
                    label: '${friend.mutualCount} mutuals',
                    secondary: secondary,
                  ),
                if (friend.mutualCount > 0 &&
                    friend.sharedSpaces > 0)
                  const SizedBox(width: 12),
                if (friend.sharedSpaces > 0)
                  _MetaItem(
                    icon: CupertinoIcons.square_stack_3d_up_fill,
                    label: '${friend.sharedSpaces} shared spaces',
                    secondary: secondary,
                  ),
              ],
            ),
            const SizedBox(height: 6),
          ],
          _MetaItem(
            icon: CupertinoIcons.calendar,
            label: friend.connectedSince,
            secondary: secondary,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  label: 'Message',
                  onTap: onMessage,
                  filled: true,
                  icon: CupertinoIcons.chat_bubble_2_fill,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionButton(
                  label: 'Call',
                  onTap: onCall,
                  filled: false,
                  icon: CupertinoIcons.phone_fill,
                  color: PravaColors.accentPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _TogglePill(
                label: friend.isFavorite ? 'Favorited' : 'Favorite',
                icon: friend.isFavorite
                    ? CupertinoIcons.star_fill
                    : CupertinoIcons.star,
                active: friend.isFavorite,
                onTap: onToggleFavorite,
              ),
              _TogglePill(
                label: friend.isMuted ? 'Muted' : 'Mute',
                icon: friend.isMuted
                    ? CupertinoIcons.bell_slash_fill
                    : CupertinoIcons.bell,
                active: friend.isMuted,
                onTap: onToggleMute,
              ),
              _TogglePill(
                label: friend.isPinned ? 'Pinned' : 'Pin',
                icon: friend.isPinned
                    ? CupertinoIcons.pin_fill
                    : CupertinoIcons.pin,
                active: friend.isPinned,
                onTap: onTogglePinned,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.initials,
    required this.isOnline,
  });

  final String initials;
  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [
                PravaColors.accentPrimary,
                PravaColors.accentMuted,
              ],
            ),
          ),
          child: CircleAvatar(
            radius: 22,
            backgroundColor: PravaColors.accentPrimary.withValues(alpha: 0.15),
            child: Text(
              initials,
              style: PravaTypography.body.copyWith(
                color: PravaColors.accentPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        Positioned(
          right: 2,
          bottom: 2,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: isOnline ? 10 : 8,
            height: isOnline ? 10 : 8,
            decoration: BoxDecoration(
              color: isOnline ? PravaColors.success : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white,
                width: isOnline ? 2 : 1,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HandleLink extends StatelessWidget {
  const _HandleLink({
    required this.username,
    required this.onTap,
  });

  final String username;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        '@$username',
        style: PravaTypography.caption.copyWith(
          color: PravaColors.accentPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: PravaTypography.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _MetaItem extends StatelessWidget {
  const _MetaItem({
    required this.icon,
    required this.label,
    required this.secondary,
  });

  final IconData icon;
  final String label;
  final Color secondary;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: secondary),
        const SizedBox(width: 6),
        Text(
          label,
          style: PravaTypography.caption.copyWith(color: secondary),
        ),
      ],
    );
  }
}

class _TagPill extends StatelessWidget {
  const _TagPill({
    required this.label,
    required this.secondary,
  });

  final String label;
  final Color secondary;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : Colors.black12,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: PravaTypography.caption.copyWith(
          color: secondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.onTap,
    this.icon,
    this.filled = false,
    this.color,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final bool filled;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tint = color ?? PravaColors.accentPrimary;
    final background = isDark ? Colors.white10 : Colors.black12;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: filled
              ? LinearGradient(
                  colors: [
                    tint,
                    tint == PravaColors.accentPrimary
                        ? PravaColors.accentMuted
                        : tint.withValues(alpha: 0.8),
                  ],
                )
              : null,
          color: filled ? null : background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: filled ? Colors.transparent : tint.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 16,
                color: filled ? Colors.white : tint,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: PravaTypography.caption.copyWith(
                color: filled ? Colors.white : tint,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TogglePill extends StatelessWidget {
  const _TogglePill({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = PravaColors.accentPrimary;
    final inactive =
        isDark ? Colors.white10 : Colors.black12.withValues(alpha: 0.5);
    final textColor = active
        ? PravaColors.accentPrimary
        : (isDark
            ? PravaColors.darkTextSecondary
            : PravaColors.lightTextSecondary);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? baseColor.withValues(alpha: 0.14) : inactive,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color:
                active ? baseColor.withValues(alpha: 0.5) : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: textColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: PravaTypography.caption.copyWith(
                color: textColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconPill extends StatelessWidget {
  const _IconPill({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : Colors.black12,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        icon,
        size: 16,
        color:
            isDark ? PravaColors.darkTextPrimary : PravaColors.lightTextPrimary,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.primary,
    required this.secondary,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color primary;
  final Color secondary;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: PravaColors.accentPrimary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: PravaColors.accentPrimary, size: 32),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: PravaTypography.h3.copyWith(
                color: primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: PravaTypography.bodySmall.copyWith(color: secondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState({
    required this.primary,
    required this.secondary,
  });

  final Color primary;
  final Color secondary;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              height: 32,
              width: 32,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: PravaColors.accentPrimary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Syncing connections',
              style: PravaTypography.bodyLarge.copyWith(
                color: primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Hold on while we load your network.',
              textAlign: TextAlign.center,
              style: PravaTypography.bodySmall.copyWith(color: secondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _FriendsBackdrop extends StatelessWidget {
  const _FriendsBackdrop({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return PravaBackground(isDark: isDark);
  }
}

class _RealtimePill extends StatelessWidget {
  const _RealtimePill({required this.loading});

  final bool loading;

  @override
  Widget build(BuildContext context) {
    final label = loading ? 'Syncing' : 'Realtime';
    final dotColor =
        loading ? PravaColors.accentPrimary : PravaColors.success;
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
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
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

class FriendStats {
  const FriendStats({
    required this.posts,
    required this.followers,
    required this.following,
  });

  final int posts;
  final int followers;
  final int following;
}

class FriendUser {
  const FriendUser({
    required this.id,
    required this.displayName,
    required this.username,
    required this.bio,
    required this.location,
    required this.isVerified,
    required this.isOnline,
    required this.tags,
    required this.stats,
    required this.joined,
    required this.highlight,
  });

  final String id;
  final String displayName;
  final String username;
  final String bio;
  final String location;
  final bool isVerified;
  final bool isOnline;
  final List<String> tags;
  final FriendStats stats;
  final String joined;
  final String highlight;

  String get initials {
    final parts = displayName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1))
        .toUpperCase();
  }
}

class FriendRequest {
  const FriendRequest({
    required this.user,
    required this.message,
    required this.mutualCount,
    required this.sharedSpaces,
    required this.receivedAt,
    required this.priorityLabel,
  });

  final FriendUser user;
  final String message;
  final int mutualCount;
  final int sharedSpaces;
  final String receivedAt;
  final String priorityLabel;
}

class SentRequest {
  const SentRequest({
    required this.user,
    required this.status,
    required this.timeLabel,
    required this.note,
  });

  final FriendUser user;
  final SentRequestStatus status;
  final String timeLabel;
  final String note;

  String get statusLabel {
    switch (status) {
      case SentRequestStatus.pending:
        return 'Pending';
      case SentRequestStatus.seen:
        return 'Seen';
    }
  }

  SentRequest copyWith({
    SentRequestStatus? status,
    String? timeLabel,
    String? note,
  }) {
    return SentRequest(
      user: user,
      status: status ?? this.status,
      timeLabel: timeLabel ?? this.timeLabel,
      note: note ?? this.note,
    );
  }
}

class FriendConnection {
  const FriendConnection({
    required this.user,
    required this.connectedSince,
    required this.mutualCount,
    required this.sharedSpaces,
    required this.presenceLabel,
    required this.isFavorite,
    required this.isMuted,
    required this.isPinned,
  });

  final FriendUser user;
  final String connectedSince;
  final int mutualCount;
  final int sharedSpaces;
  final String presenceLabel;
  final bool isFavorite;
  final bool isMuted;
  final bool isPinned;

  FriendConnection copyWith({
    bool? isFavorite,
    bool? isMuted,
    bool? isPinned,
  }) {
    return FriendConnection(
      user: user,
      connectedSince: connectedSince,
      mutualCount: mutualCount,
      sharedSpaces: sharedSpaces,
      presenceLabel: presenceLabel,
      isFavorite: isFavorite ?? this.isFavorite,
      isMuted: isMuted ?? this.isMuted,
      isPinned: isPinned ?? this.isPinned,
    );
  }
}

