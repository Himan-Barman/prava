import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../navigation/prava_navigator.dart';
import '../../../../services/chat_service.dart';
import '../../../../services/profile_visibility.dart';
import '../../../../services/public_profile_service.dart';
import '../../../../ui-system/background.dart';
import '../../../../ui-system/colors.dart';
import '../../../../ui-system/feedback/prava_toast.dart';
import '../../../../ui-system/feedback/toast_type.dart';
import '../../../../ui-system/typography.dart';
import '../chats/chat_thread_page.dart';
import '../chats/chats_page.dart';
import 'profile_content_pages.dart';

class PublicProfilePage extends StatefulWidget {
  const PublicProfilePage({
    super.key,
    required this.userId,
    this.initialIsFollowing = false,
    this.initialIsFollowedBy = false,
  });

  final String userId;
  final bool initialIsFollowing;
  final bool initialIsFollowedBy;

  @override
  State<PublicProfilePage> createState() => _PublicProfilePageState();
}

class _PublicProfilePageState extends State<PublicProfilePage> {
  final PublicProfileService _profileService = PublicProfileService();
  final ChatService _chatService = ChatService();

  PublicProfileSummary? _summary;
  bool _loading = true;
  bool _pendingFollow = false;
  bool _openingChat = false;
  bool _following = false;
  bool _followedBy = false;
  bool _requested = false;
  bool _incomingRequestPending = false;
  bool _closeFriend = false;
  bool _muted = false;
  bool _restricted = false;
  _PublicProfileContentTab _contentTab = _PublicProfileContentTab.all;
  final Set<String> _collapsedSections = {};

  @override
  void initState() {
    super.initState();
    _following = widget.initialIsFollowing;
    _followedBy = widget.initialIsFollowedBy;
    _loadProfile();
  }

  Future<void> _loadProfile({bool silent = false}) async {
    if (widget.userId.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    if (!silent) setState(() => _loading = true);

    try {
      final summary = await _profileService.fetchProfile(
        widget.userId,
        limit: 24,
      );
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _following = summary.relationship.isFollowing;
        _followedBy = summary.relationship.isFollowedBy;
        _requested = summary.relationship.requestPending;
        _incomingRequestPending = summary.relationship.incomingRequestPending;
        _closeFriend = summary.relationship.isCloseFriend;
        _muted = summary.relationship.isMuted;
        _restricted = summary.relationship.isRestricted;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      PravaToast.show(
        context,
        message: 'Unable to load profile',
        type: PravaToastType.error,
      );
    }
  }

  Future<void> _toggleFollow() async {
    if (_pendingFollow || widget.userId.isEmpty) return;
    if (_summary?.profileState == 'blockedByViewer') {
      await _setBlocked(false);
      return;
    }
    HapticFeedback.selectionClick();
    final nextFollow = !_following;
    setState(() => _pendingFollow = true);

    try {
      final result = await _profileService.setFollow(widget.userId, nextFollow);
      if (!mounted) return;
      setState(() {
        _following = result.following;
        _requested = result.requested;
        _pendingFollow = false;
      });
      await _loadProfile(silent: true);
      if (!mounted) return;
      PravaToast.show(
        context,
        message: _requested
            ? 'Follow request sent'
            : _following && _followedBy
            ? 'You are now friends'
            : (_following ? 'Following' : 'Unfollowed'),
        type: PravaToastType.success,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _pendingFollow = false);
      PravaToast.show(
        context,
        message: 'Unable to update follow status',
        type: PravaToastType.error,
      );
    }
  }

  Future<void> _performProfileAction(
    Future<void> Function() action, {
    required String successMessage,
    String errorMessage = 'Unable to update profile action',
  }) async {
    HapticFeedback.selectionClick();
    try {
      await action();
      await _loadProfile(silent: true);
      if (!mounted) return;
      PravaToast.show(
        context,
        message: successMessage,
        type: PravaToastType.success,
      );
    } catch (_) {
      if (!mounted) return;
      PravaToast.show(
        context,
        message: errorMessage,
        type: PravaToastType.error,
      );
    }
  }

  Future<void> _setBlocked(bool blocked) {
    return _performProfileAction(
      () => _profileService.setBlock(widget.userId, blocked),
      successMessage: blocked ? 'Profile blocked' : 'Profile unblocked',
      errorMessage: blocked ? 'Unable to block profile' : 'Unable to unblock',
    );
  }

  Future<void> _setMuted(bool muted) {
    return _performProfileAction(
      () => _profileService.setMute(widget.userId, muted),
      successMessage: muted ? 'Profile muted' : 'Profile unmuted',
      errorMessage: muted ? 'Unable to mute profile' : 'Unable to unmute',
    );
  }

  Future<void> _setRestricted(bool restricted) {
    return _performProfileAction(
      () => _profileService.setRestrict(widget.userId, restricted),
      successMessage: restricted ? 'Profile restricted' : 'Restriction removed',
      errorMessage: restricted
          ? 'Unable to restrict profile'
          : 'Unable to remove restriction',
    );
  }

  Future<void> _setCloseFriend(bool closeFriend) {
    return _performProfileAction(
      () => _profileService.setCloseFriend(widget.userId, closeFriend),
      successMessage: closeFriend
          ? 'Added to close friends'
          : 'Removed from close friends',
      errorMessage: closeFriend
          ? 'Follow this user before adding to close friends'
          : 'Unable to update close friends',
    );
  }

  Future<void> _removeFollower() {
    return _performProfileAction(
      () => _profileService.removeFollower(widget.userId),
      successMessage: 'Follower removed',
      errorMessage: 'Unable to remove follower',
    );
  }

  Future<void> _removeConnection() {
    return _performProfileAction(
      () => _profileService.removeConnection(widget.userId),
      successMessage: 'Connection removed',
      errorMessage: 'Unable to remove connection',
    );
  }

  Future<void> _reportProfile() {
    return _performProfileAction(
      () => _profileService.reportProfile(widget.userId, reason: 'other'),
      successMessage: 'Profile report sent',
      errorMessage: 'Unable to report profile',
    );
  }

  Future<void> _copyProfileLink() async {
    final summary = _summary;
    final username = summary?.user.username.trim() ?? '';
    final suffix = username.isEmpty ? widget.userId : username;
    await Clipboard.setData(
      ClipboardData(text: 'https://pravachat.me/$suffix'),
    );
    if (!mounted) return;
    PravaToast.show(
      context,
      message: 'Profile link copied',
      type: PravaToastType.success,
    );
  }

  void _openMoreMenu() {
    final summary = _summary;
    if (summary == null) return;
    HapticFeedback.selectionClick();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _ProfileActionSheet(
          summary: summary,
          following: _following,
          followedBy: _followedBy,
          closeFriend: _closeFriend,
          muted: _muted,
          restricted: _restricted,
          incomingRequestPending: _incomingRequestPending,
          onCopyLink: () {
            Navigator.of(sheetContext).pop();
            _copyProfileLink();
          },
          onToggleFollow: () {
            Navigator.of(sheetContext).pop();
            _toggleFollow();
          },
          onToggleCloseFriend: () {
            Navigator.of(sheetContext).pop();
            _setCloseFriend(!_closeFriend);
          },
          onToggleMute: () {
            Navigator.of(sheetContext).pop();
            _setMuted(!_muted);
          },
          onToggleRestrict: () {
            Navigator.of(sheetContext).pop();
            _setRestricted(!_restricted);
          },
          onRemoveFollower: () {
            Navigator.of(sheetContext).pop();
            _removeFollower();
          },
          onRemoveConnection: () {
            Navigator.of(sheetContext).pop();
            _removeConnection();
          },
          onBlock: () {
            Navigator.of(sheetContext).pop();
            _setBlocked(true);
          },
          onUnblock: () {
            Navigator.of(sheetContext).pop();
            _setBlocked(false);
          },
          onReport: () {
            Navigator.of(sheetContext).pop();
            _reportProfile();
          },
        );
      },
    );
  }

  Future<void> _openChat() async {
    final summary = _summary;
    if (_openingChat || summary == null || summary.user.id.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() => _openingChat = true);
    try {
      final user = summary.user;
      final conversationId = await _chatService.createDm(otherUserId: user.id);
      if (!mounted) return;
      if (conversationId == null || conversationId.isEmpty) {
        throw Exception('Conversation not created');
      }
      await Navigator.of(context, rootNavigator: true).push(
        PravaNavigator.route(
          ChatThreadPage(
            chat: ChatPreview(
              id: conversationId,
              name: _displayName(user),
              lastMessage: 'No messages yet',
              time: 'New',
              unreadCount: 0,
              isGroup: false,
              isOnline: false,
              isMuted: false,
              isPinned: false,
              isFavorite: false,
              isStarred: false,
              isTyping: false,
              peerUserId: user.id,
              avatarUrl: user.avatarUrl,
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
      if (mounted) setState(() => _openingChat = false);
    }
  }

  String _displayName(PublicProfileUser user) {
    return user.displayName.isNotEmpty ? user.displayName : user.username;
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  String _formatCount(int value) {
    if (value >= 1000000) {
      final short = (value / 1000000).toStringAsFixed(
        value % 1000000 == 0 ? 0 : 1,
      );
      return '${short}M';
    }
    if (value >= 1000) {
      final short = (value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1);
      return '${short}K';
    }
    return value.toString();
  }

  String _formatJoined(DateTime? value) {
    if (value == null) return '';
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
    return 'Joined ${months[value.month - 1]} ${value.year}';
  }

  bool _showVerifiedBadge(PublicProfileUser user) {
    if (!user.isVerified) return false;
    final type = user.verificationType.toLowerCase();
    return type.isEmpty ||
        type == 'verified' ||
        type.contains('mobile') ||
        type.contains('phone') ||
        type.contains('otp');
  }

  String _formatRelativeTime(DateTime value) {
    final diff = DateTime.now().difference(value);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    final weeks = diff.inDays ~/ 7;
    if (weeks < 5) return '${weeks}w';
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$month/$day/${value.year}';
  }

  String _relationshipLabel() {
    final summary = _summary;
    if (summary?.profileState == 'private') return 'Private profile';
    if (summary?.profileState == 'blockedByViewer') return 'Blocked';
    if (summary?.profileState == 'blocked') return 'Unavailable';
    if (_requested) return 'Requested';
    if (_following && _followedBy) return 'Friends';
    if (_following) return 'Following';
    if (_followedBy) return 'Follows you';
    return 'Public profile';
  }

  String _shownStat(ProfileVisibility visibility, String key, int value) {
    return visibility.canSee(key) ? _formatCount(value) : '--';
  }

  ProfilePostContentItem _contentItem(PublicProfilePost post) {
    return ProfilePostContentItem(
      body: post.body,
      createdAt: post.createdAt,
      likeCount: post.likeCount,
      commentCount: post.commentCount,
      shareCount: post.shareCount,
      mentions: post.mentions,
      hashtags: post.hashtags,
    );
  }

  void _openPostsPage(PublicProfileSummary summary) {
    final visible = summary.visibility.canSee('posts');
    HapticFeedback.selectionClick();
    Navigator.of(context, rootNavigator: true).push(
      PravaNavigator.route(
        ProfilePostListPage(
          title: 'Posts',
          posts: visible
              ? summary.posts.map(_contentItem).toList()
              : <ProfilePostContentItem>[],
          emptyTitle: visible ? 'No public posts' : 'Posts are private',
          emptySubtitle: visible
              ? 'Public posts from this profile will appear here.'
              : 'This profile owner limits who can see posts.',
        ),
        fullscreenDialog: true,
      ),
    );
  }

  void _openConnections(
    PublicProfileSummary summary,
    ProfileConnectionKind kind,
  ) {
    HapticFeedback.selectionClick();
    Navigator.of(context, rootNavigator: true).push(
      PravaNavigator.route(
        ProfileConnectionsPage(
          userId: summary.user.id,
          kind: kind,
          title: kind == ProfileConnectionKind.followers
              ? 'Followers'
              : 'Following',
          onOpenProfile: (pageContext, item) {
            PravaNavigator.push(
              pageContext,
              PublicProfilePage(
                userId: item.user.id,
                initialIsFollowing: item.isFollowing,
                initialIsFollowedBy: item.isFollowedBy,
              ),
            );
          },
        ),
        fullscreenDialog: true,
      ),
    );
  }

  void _setTab(_PublicProfileContentTab value) {
    if (_contentTab == value) return;
    HapticFeedback.selectionClick();
    setState(() => _contentTab = value);
  }

  void _toggleSection(String key) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_collapsedSections.contains(key)) {
        _collapsedSections.remove(key);
      } else {
        _collapsedSections.add(key);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tokens = context.pravaColors;
    final primary = tokens.textPrimary;
    final secondary = tokens.textSecondary;
    final border = tokens.borderSubtle;

    return Scaffold(
      body: Stack(
        children: [
          PravaBackground(isDark: isDark),
          SafeArea(
            child: _buildBody(
              primary: primary,
              secondary: secondary,
              border: border,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody({
    required Color primary,
    required Color secondary,
    required Color border,
  }) {
    final summary = _summary;
    if (_loading && summary == null) {
      return const Center(child: CupertinoActivityIndicator(radius: 12));
    }

    if (summary == null) {
      return _PublicProfileError(
        primary: primary,
        secondary: secondary,
        onBack: () => Navigator.of(context).pop(),
        onRetry: _loadProfile,
      );
    }

    final user = summary.user;
    final displayName = _displayName(user);
    final visibility = summary.visibility;
    final postsHidden = !visibility.canSee('posts');
    final titleUsername = user.username.isEmpty
        ? displayName
        : '@${user.username}';

    return RefreshIndicator(
      color: context.pravaColors.brandPrimary,
      onRefresh: _loadProfile,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: _TopBar(title: titleUsername, primary: primary),
            ),
          ),
          SliverToBoxAdapter(
            child: _PublicProfileHero(
              displayName: displayName,
              username: user.username,
              initials: _initials(displayName),
              avatarUrl: user.avatarUrl,
              verified: _showVerifiedBadge(user),
              relationship: _relationshipLabel(),
              bio: user.bio,
              bioVisible: visibility.canSee('bio'),
              location: user.location,
              locationVisible: visibility.canSee('location'),
              posts: _shownStat(visibility, 'posts', summary.stats.posts),
              followers: _shownStat(
                visibility,
                'followers',
                summary.stats.followers,
              ),
              following: _shownStat(
                visibility,
                'following',
                summary.stats.following,
              ),
              isFriend: _following && _followedBy,
              followingUser: _following,
              followedByUser: _followedBy,
              requested: _requested,
              profileState: summary.profileState,
              mutualFriends: summary.mutualFriends,
              pendingFollow: _pendingFollow,
              openingChat: _openingChat,
              primary: primary,
              secondary: secondary,
              border: border,
              onFollow: _toggleFollow,
              onMessage: _openChat,
              onMore: _openMoreMenu,
              onPostsTap: () => _openPostsPage(summary),
              onFollowersTap: () =>
                  _openConnections(summary, ProfileConnectionKind.followers),
              onFollowingTap: () =>
                  _openConnections(summary, ProfileConnectionKind.following),
            ),
          ),
          SliverToBoxAdapter(
            child: summary.tabs.isEmpty
                ? const SizedBox.shrink()
                : _PublicProfileTabBar(
                    value: _contentTab,
                    tabs: summary.tabs,
                    primary: primary,
                    secondary: secondary,
                    border: border,
                    onChanged: _setTab,
                  ),
          ),
          if (summary.profileState == 'private')
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
                child: _LockedState(
                  title: 'This account is private',
                  subtitle:
                      'Follow this account to see their posts, media, and activity.',
                  primary: primary,
                  secondary: secondary,
                  border: border,
                ),
              ),
            )
          else if (summary.profileState == 'blocked' ||
              summary.profileState == 'blockedByViewer')
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
                child: _LockedState(
                  title: summary.profileState == 'blockedByViewer'
                      ? 'Profile blocked'
                      : 'Profile unavailable',
                  subtitle: summary.profileState == 'blockedByViewer'
                      ? 'Unblock this profile to interact again.'
                      : 'This profile is not available to view.',
                  primary: primary,
                  secondary: secondary,
                  border: border,
                ),
              ),
            )
          else if (_contentTab == _PublicProfileContentTab.about) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: _PublicProfileSection(
                  title: 'Category',
                  primary: primary,
                  collapsed: _collapsedSections.contains('category'),
                  onToggle: () => _toggleSection('category'),
                  children: [
                    _PublicInfoRow(
                      icon: Icons.category_rounded,
                      title: user.category.trim().isEmpty
                          ? 'Creator'
                          : user.category.trim(),
                      value: '',
                      primary: primary,
                      secondary: secondary,
                    ),
                    _PublicInfoRow(
                      icon: CupertinoIcons.sparkles,
                      title: 'AI creator',
                      value: user.aiCreator ? 'Yes' : 'No',
                      primary: primary,
                      secondary: secondary,
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: _PublicProfileSection(
                  title: 'Personal details',
                  primary: primary,
                  collapsed: _collapsedSections.contains('personal'),
                  onToggle: () => _toggleSection('personal'),
                  children: [
                    if (visibility.canSee('location'))
                      _PublicInfoRow(
                        icon: CupertinoIcons.location,
                        title: user.location.trim().isEmpty
                            ? 'Location'
                            : user.location.trim(),
                        value: user.location.trim().isEmpty ? '-' : '',
                        primary: primary,
                        secondary: secondary,
                      )
                    else
                      _HiddenInfoRow(
                        label: ProfileVisibility.fieldLabel('location'),
                        primary: primary,
                        secondary: secondary,
                      ),
                    if (visibility.canSee('location'))
                      _PublicInfoRow(
                        icon: CupertinoIcons.house,
                        title: user.hometown.trim().isEmpty
                            ? 'Hometown'
                            : user.hometown.trim(),
                        value: user.hometown.trim().isEmpty ? '-' : '',
                        primary: primary,
                        secondary: secondary,
                      ),
                    if (visibility.canSee('joined'))
                      _PublicInfoRow(
                        icon: CupertinoIcons.calendar,
                        title: _formatJoined(user.createdAt).isEmpty
                            ? 'Joined'
                            : _formatJoined(user.createdAt),
                        value: _formatJoined(user.createdAt).isEmpty ? '-' : '',
                        primary: primary,
                        secondary: secondary,
                      )
                    else
                      _HiddenInfoRow(
                        label: ProfileVisibility.fieldLabel('joined'),
                        primary: primary,
                        secondary: secondary,
                      ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                child: _PublicProfileSection(
                  title: 'Links',
                  primary: primary,
                  collapsed: _collapsedSections.contains('links'),
                  onToggle: () => _toggleSection('links'),
                  children: [
                    if (visibility.canSee('website'))
                      _PublicInfoRow(
                        icon: CupertinoIcons.link,
                        title: user.website.trim().isEmpty
                            ? 'Website'
                            : user.website.trim(),
                        value: user.website.trim().isEmpty ? '-' : '',
                        primary: primary,
                        secondary: secondary,
                      )
                    else
                      _HiddenInfoRow(
                        label: ProfileVisibility.fieldLabel('website'),
                        primary: primary,
                        secondary: secondary,
                      ),
                  ],
                ),
              ),
            ),
          ] else if (_contentTab == _PublicProfileContentTab.media)
            SliverToBoxAdapter(
              child: _PublicPostsList(
                posts: summary.mediaPosts,
                primary: primary,
                secondary: secondary,
                border: border,
                formatCount: _formatCount,
                formatTime: _formatRelativeTime,
                emptyTitle: 'No media yet',
                emptySubtitle:
                    'Photos and videos this profile shares will appear here.',
              ),
            )
          else if (_contentTab == _PublicProfileContentTab.replies)
            SliverToBoxAdapter(
              child: _PublicPostsList(
                posts: summary.replies,
                primary: primary,
                secondary: secondary,
                border: border,
                formatCount: _formatCount,
                formatTime: _formatRelativeTime,
                emptyTitle: 'No replies yet',
                emptySubtitle:
                    'Replies this profile can share will appear here.',
              ),
            )
          else if (_contentTab == _PublicProfileContentTab.highlights)
            SliverToBoxAdapter(
              child: _HighlightsPanel(
                highlights: summary.highlights,
                primary: primary,
                secondary: secondary,
                border: border,
              ),
            )
          else
            SliverToBoxAdapter(
              child: postsHidden
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(20, 34, 20, 28),
                      child: _LockedState(
                        title: 'Posts are private',
                        subtitle:
                            'This profile owner limits who can see posts.',
                        primary: primary,
                        secondary: secondary,
                        border: border,
                      ),
                    )
                  : _PublicPostsList(
                      posts: summary.posts,
                      primary: primary,
                      secondary: secondary,
                      border: border,
                      formatCount: _formatCount,
                      formatTime: _formatRelativeTime,
                    ),
            ),
        ],
      ),
    );
  }
}

enum _PublicProfileContentTab { all, posts, replies, media, highlights, about }

class _TopBar extends StatelessWidget {
  const _TopBar({required this.title, required this.primary});

  final String title;
  final Color primary;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: PravaTypography.titleSmall.copyWith(
        color: primary,
        letterSpacing: 0,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _PublicProfileHero extends StatelessWidget {
  const _PublicProfileHero({
    required this.displayName,
    required this.username,
    required this.initials,
    required this.avatarUrl,
    required this.verified,
    required this.relationship,
    required this.bio,
    required this.bioVisible,
    required this.location,
    required this.locationVisible,
    required this.posts,
    required this.followers,
    required this.following,
    required this.isFriend,
    required this.followingUser,
    required this.followedByUser,
    required this.requested,
    required this.profileState,
    required this.mutualFriends,
    required this.pendingFollow,
    required this.openingChat,
    required this.primary,
    required this.secondary,
    required this.border,
    required this.onFollow,
    required this.onMessage,
    required this.onMore,
    required this.onPostsTap,
    required this.onFollowersTap,
    required this.onFollowingTap,
  });

  final String displayName;
  final String username;
  final String initials;
  final String avatarUrl;
  final bool verified;
  final String relationship;
  final String bio;
  final bool bioVisible;
  final String location;
  final bool locationVisible;
  final String posts;
  final String followers;
  final String following;
  final bool isFriend;
  final bool followingUser;
  final bool followedByUser;
  final bool requested;
  final String profileState;
  final List<PublicProfileMiniUser> mutualFriends;
  final bool pendingFollow;
  final bool openingChat;
  final Color primary;
  final Color secondary;
  final Color border;
  final VoidCallback onFollow;
  final VoidCallback onMessage;
  final VoidCallback onMore;
  final VoidCallback onPostsTap;
  final VoidCallback onFollowersTap;
  final VoidCallback onFollowingTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.pravaColors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      tokens.brandPrimary.withValues(alpha: 0.46),
                      tokens.backgroundSurface,
                      tokens.brandContainer.withValues(alpha: 0.72),
                    ],
                  ),
                ),
                child: _PublicProfileAvatar(
                  initials: initials,
                  url: avatarUrl,
                  size: 96,
                  borderColor: tokens.backgroundCanvas,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: PravaTypography.titleLarge.copyWith(
                              color: primary,
                              letterSpacing: 0,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        if (verified) ...[
                          const SizedBox(width: 7),
                          Icon(
                            CupertinoIcons.check_mark_circled_solid,
                            color: tokens.brandPrimary,
                            size: 21,
                          ),
                        ],
                      ],
                    ),
                    if (username.trim().isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        '@$username',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: PravaTypography.bodyMedium.copyWith(
                          color: secondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    if (!bioVisible || bio.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      if (!bioVisible)
                        _InlinePrivateLine(
                          label: 'Bio hidden by privacy',
                          color: secondary,
                        )
                      else
                        Text(
                          bio.trim(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: PravaTypography.bodyMedium.copyWith(
                            color: primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                    if (locationVisible && location.trim().isNotEmpty) ...[
                      const SizedBox(height: 7),
                      _PublicMetaPill(
                        icon: CupertinoIcons.location_solid,
                        label: location.trim(),
                        color: secondary,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _RelationshipPill(label: relationship, color: secondary),
          if (mutualFriends.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              mutualFriends
                  .take(3)
                  .map(
                    (friend) => friend.displayName.isNotEmpty
                        ? friend.displayName
                        : '@${friend.username}',
                  )
                  .join(', '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: PravaTypography.caption.copyWith(color: secondary),
            ),
          ],
          const SizedBox(height: 18),
          _PublicProfileStatsRow(
            posts: posts,
            followers: followers,
            following: following,
            primary: primary,
            secondary: secondary,
            border: border,
            onPostsTap: onPostsTap,
            onFollowersTap: onFollowersTap,
            onFollowingTap: onFollowingTap,
          ),
          const SizedBox(height: 22),
          _RelationActions(
            isFriend: isFriend,
            following: followingUser,
            followedBy: followedByUser,
            requested: requested,
            profileState: profileState,
            pendingFollow: pendingFollow,
            openingChat: openingChat,
            border: border,
            primary: primary,
            onFollow: onFollow,
            onMessage: onMessage,
            onMore: onMore,
          ),
        ],
      ),
    );
  }
}

class _PublicMetaPill extends StatelessWidget {
  const _PublicMetaPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 17),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: PravaTypography.bodySmall.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _PublicProfileStatsRow extends StatelessWidget {
  const _PublicProfileStatsRow({
    required this.posts,
    required this.followers,
    required this.following,
    required this.primary,
    required this.secondary,
    required this.border,
    required this.onPostsTap,
    required this.onFollowersTap,
    required this.onFollowingTap,
  });

  final String posts;
  final String followers;
  final String following;
  final Color primary;
  final Color secondary;
  final Color border;
  final VoidCallback onPostsTap;
  final VoidCallback onFollowersTap;
  final VoidCallback onFollowingTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _PublicProfileCount(
          label: 'Posts',
          value: posts,
          primary: primary,
          secondary: secondary,
          onTap: onPostsTap,
        ),
        _PublicStatDivider(border: border),
        _PublicProfileCount(
          label: 'Followers',
          value: followers,
          primary: primary,
          secondary: secondary,
          onTap: onFollowersTap,
        ),
        _PublicStatDivider(border: border),
        _PublicProfileCount(
          label: 'Following',
          value: following,
          primary: primary,
          secondary: secondary,
          onTap: onFollowingTap,
        ),
      ],
    );
  }
}

class _PublicStatDivider extends StatelessWidget {
  const _PublicStatDivider({required this.border});

  final Color border;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 34,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: border.withValues(alpha: 0.72),
    );
  }
}

class _PublicProfileTabBar extends StatelessWidget {
  const _PublicProfileTabBar({
    required this.value,
    required this.tabs,
    required this.primary,
    required this.secondary,
    required this.border,
    required this.onChanged,
  });

  final _PublicProfileContentTab value;
  final List<PublicProfileTab> tabs;
  final Color primary;
  final Color secondary;
  final Color border;
  final ValueChanged<_PublicProfileContentTab> onChanged;

  @override
  Widget build(BuildContext context) {
    final visibleTabs = [
      const PublicProfileTab(key: 'all', label: 'All', ownerOnly: false),
      ...tabs.where(
        (tab) => {
          'posts',
          'replies',
          'media',
          'highlights',
          'about',
        }.contains(tab.key),
      ),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            for (final tab in visibleTabs) ...[
              SizedBox(
                width: 112,
                child: _PublicProfileTabButton(
                  label: tab.label,
                  selected: value == _tabForKey(tab.key),
                  primary: primary,
                  secondary: secondary,
                  border: border,
                  onTap: () => onChanged(_tabForKey(tab.key)),
                ),
              ),
              const SizedBox(width: 10),
            ],
          ],
        ),
      ),
    );
  }

  _PublicProfileContentTab _tabForKey(String key) {
    switch (key) {
      case 'posts':
        return _PublicProfileContentTab.posts;
      case 'replies':
        return _PublicProfileContentTab.replies;
      case 'media':
        return _PublicProfileContentTab.media;
      case 'highlights':
        return _PublicProfileContentTab.highlights;
      case 'about':
        return _PublicProfileContentTab.about;
      default:
        return _PublicProfileContentTab.all;
    }
  }
}

class _PublicProfileTabButton extends StatelessWidget {
  const _PublicProfileTabButton({
    required this.label,
    required this.selected,
    required this.primary,
    required this.secondary,
    required this.border,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color primary;
  final Color secondary;
  final Color border;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.pravaColors;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 40,
        decoration: BoxDecoration(
          color: selected ? tokens.brandContainer : Colors.transparent,
          border: Border.all(color: selected ? tokens.brandPrimary : border),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Center(
          child: Text(
            label,
            style: PravaTypography.buttonMedium.copyWith(
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

class _RelationActions extends StatelessWidget {
  const _RelationActions({
    required this.isFriend,
    required this.following,
    required this.followedBy,
    required this.requested,
    required this.profileState,
    required this.pendingFollow,
    required this.openingChat,
    required this.border,
    required this.primary,
    required this.onFollow,
    required this.onMessage,
    required this.onMore,
  });

  final bool isFriend;
  final bool following;
  final bool followedBy;
  final bool requested;
  final String profileState;
  final bool pendingFollow;
  final bool openingChat;
  final Color border;
  final Color primary;
  final VoidCallback onFollow;
  final VoidCallback onMessage;
  final VoidCallback onMore;

  String get _followLabel {
    if (profileState == 'blockedByViewer') return 'Unblock';
    if (profileState == 'blocked') return 'Unavailable';
    if (requested) return 'Requested';
    if (isFriend) return 'Friends';
    if (following) return 'Following';
    if (followedBy) return 'Follow back';
    if (profileState == 'private') return 'Request Follow';
    return 'Follow';
  }

  @override
  Widget build(BuildContext context) {
    final moreButton = _PublicIconActionButton(
      icon: CupertinoIcons.ellipsis,
      label: 'More profile actions',
      onTap: onMore,
      border: border,
      primary: primary,
    );

    if (isFriend) {
      return Row(
        children: [
          Expanded(
            child: _PublicActionButton(
              label: 'Message',
              filled: true,
              loading: openingChat,
              onTap: openingChat ? null : onMessage,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _PublicActionButton(
              label: _followLabel,
              filled: false,
              loading: pendingFollow,
              border: border,
              primary: primary,
              onTap: pendingFollow ? null : onFollow,
            ),
          ),
          const SizedBox(width: 10),
          moreButton,
        ],
      );
    }

    final canMessage =
        profileState != 'private' &&
        profileState != 'blocked' &&
        profileState != 'blockedByViewer' &&
        (following || followedBy);

    return Row(
      children: [
        Expanded(
          child: _PublicActionButton(
            label: _followLabel,
            filled: !following && !requested,
            loading: pendingFollow,
            border: border,
            primary: primary,
            onTap: pendingFollow || profileState == 'blocked' ? null : onFollow,
          ),
        ),
        if (canMessage) ...[
          const SizedBox(width: 10),
          Expanded(
            child: _PublicActionButton(
              label: 'Message',
              filled: false,
              loading: openingChat,
              border: border,
              primary: primary,
              onTap: openingChat ? null : onMessage,
            ),
          ),
        ],
        const SizedBox(width: 10),
        moreButton,
      ],
    );
  }
}

class _PublicIconActionButton extends StatelessWidget {
  const _PublicIconActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.border,
    required this.primary,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color border;
  final Color primary;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border),
          ),
          child: Icon(icon, color: primary, size: 22),
        ),
      ),
    );
  }
}

class _ProfileActionSheet extends StatelessWidget {
  const _ProfileActionSheet({
    required this.summary,
    required this.following,
    required this.followedBy,
    required this.closeFriend,
    required this.muted,
    required this.restricted,
    required this.incomingRequestPending,
    required this.onCopyLink,
    required this.onToggleFollow,
    required this.onToggleCloseFriend,
    required this.onToggleMute,
    required this.onToggleRestrict,
    required this.onRemoveFollower,
    required this.onRemoveConnection,
    required this.onBlock,
    required this.onUnblock,
    required this.onReport,
  });

  final PublicProfileSummary summary;
  final bool following;
  final bool followedBy;
  final bool closeFriend;
  final bool muted;
  final bool restricted;
  final bool incomingRequestPending;
  final VoidCallback onCopyLink;
  final VoidCallback onToggleFollow;
  final VoidCallback onToggleCloseFriend;
  final VoidCallback onToggleMute;
  final VoidCallback onToggleRestrict;
  final VoidCallback onRemoveFollower;
  final VoidCallback onRemoveConnection;
  final VoidCallback onBlock;
  final VoidCallback onUnblock;
  final VoidCallback onReport;

  String get _followLabel {
    if (summary.profileState == 'private' &&
        summary.relationship.requestPending) {
      return 'Cancel follow request';
    }
    if (following) return 'Unfollow';
    if (incomingRequestPending || followedBy) return 'Follow back';
    return summary.profileState == 'private' ? 'Request follow' : 'Follow';
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.pravaColors;
    final isBlockedByViewer = summary.profileState == 'blockedByViewer';
    final isBlocked = summary.profileState == 'blocked';
    final isFriend = following && followedBy;
    final actions = <_ProfileSheetAction>[
      _ProfileSheetAction(
        icon: CupertinoIcons.link,
        label: 'Copy profile link',
        onTap: onCopyLink,
      ),
      if (isBlockedByViewer)
        _ProfileSheetAction(
          icon: CupertinoIcons.hand_raised_slash,
          label: 'Unblock',
          onTap: onUnblock,
          destructive: true,
        )
      else if (!isBlocked) ...[
        _ProfileSheetAction(
          icon: following
              ? CupertinoIcons.person_badge_minus
              : CupertinoIcons.person_badge_plus,
          label: _followLabel,
          onTap: onToggleFollow,
        ),
        if (following)
          _ProfileSheetAction(
            icon: closeFriend ? CupertinoIcons.star_slash : CupertinoIcons.star,
            label: closeFriend
                ? 'Remove from close friends'
                : 'Add to close friends',
            onTap: onToggleCloseFriend,
          ),
        _ProfileSheetAction(
          icon: muted ? CupertinoIcons.bell : CupertinoIcons.bell_slash,
          label: muted ? 'Unmute profile' : 'Mute profile',
          onTap: onToggleMute,
        ),
        _ProfileSheetAction(
          icon: restricted ? CupertinoIcons.lock_open : CupertinoIcons.lock,
          label: restricted ? 'Remove restriction' : 'Restrict profile',
          onTap: onToggleRestrict,
        ),
        if (followedBy)
          _ProfileSheetAction(
            icon: CupertinoIcons.person_crop_circle_badge_xmark,
            label: 'Remove follower',
            onTap: onRemoveFollower,
          ),
        if (isFriend)
          _ProfileSheetAction(
            icon: CupertinoIcons.person_2,
            label: 'Remove friend',
            onTap: onRemoveConnection,
          ),
        _ProfileSheetAction(
          icon: CupertinoIcons.hand_raised,
          label: 'Block profile',
          onTap: onBlock,
          destructive: true,
        ),
        _ProfileSheetAction(
          icon: CupertinoIcons.exclamationmark_bubble,
          label: 'Report profile',
          onTap: onReport,
          destructive: true,
        ),
      ],
    ];

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
        decoration: BoxDecoration(
          color: tokens.backgroundSurfaceRaised,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: tokens.borderSubtle),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 30,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: tokens.borderStrong,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              summary.user.displayName.isEmpty
                  ? '@${summary.user.username}'
                  : summary.user.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: PravaTypography.titleSmall.copyWith(
                color: tokens.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            for (final action in actions)
              _ProfileActionTile(action: action, tokens: tokens),
          ],
        ),
      ),
    );
  }
}

class _ProfileSheetAction {
  const _ProfileSheetAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;
}

class _ProfileActionTile extends StatelessWidget {
  const _ProfileActionTile({required this.action, required this.tokens});

  final _ProfileSheetAction action;
  final PravaThemeColors tokens;

  @override
  Widget build(BuildContext context) {
    final color = action.destructive ? tokens.statusError : tokens.textPrimary;
    return Semantics(
      button: true,
      label: action.label,
      child: InkWell(
        onTap: action.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Icon(action.icon, color: color, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  action.label,
                  style: PravaTypography.bodyMedium.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PublicActionButton extends StatelessWidget {
  const _PublicActionButton({
    required this.label,
    required this.filled,
    required this.loading,
    required this.onTap,
    this.border,
    this.primary,
  });

  final String label;
  final bool filled;
  final bool loading;
  final VoidCallback? onTap;
  final Color? border;
  final Color? primary;

  @override
  Widget build(BuildContext context) {
    final tokens = context.pravaColors;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 44,
        decoration: BoxDecoration(
          color: filled ? tokens.brandPrimary : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: filled
              ? null
              : Border.all(color: border ?? tokens.borderSubtle),
        ),
        child: Center(
          child: loading
              ? CupertinoActivityIndicator(
                  radius: 9,
                  color: filled ? tokens.textInverse : tokens.brandPrimary,
                )
              : Text(
                  label,
                  style: PravaTypography.buttonMedium.copyWith(
                    color: filled
                        ? tokens.textInverse
                        : (primary ?? tokens.brandContent),
                    fontWeight: FontWeight.w800,
                  ),
                ),
        ),
      ),
    );
  }
}

class _PublicProfileAvatar extends StatelessWidget {
  const _PublicProfileAvatar({
    required this.initials,
    required this.url,
    required this.size,
    required this.borderColor,
  });

  final String initials;
  final String url;
  final double size;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    final tokens = context.pravaColors;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 4),
      ),
      child: ClipOval(
        child: url.trim().isEmpty
            ? Container(
                color: tokens.brandContainer,
                child: Center(
                  child: Text(
                    initials,
                    style: PravaTypography.titleLarge.copyWith(
                      color: tokens.brandContent,
                      letterSpacing: 0,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              )
            : Image.network(url, fit: BoxFit.cover),
      ),
    );
  }
}

class _PublicProfileCount extends StatelessWidget {
  const _PublicProfileCount({
    required this.label,
    required this.value,
    required this.primary,
    required this.secondary,
    required this.onTap,
  });

  final String label;
  final String value;
  final Color primary;
  final Color secondary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          children: [
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: PravaTypography.titleSmall.copyWith(
                color: primary,
                letterSpacing: 0,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: PravaTypography.bodySmall.copyWith(
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

class _PublicProfileSection extends StatelessWidget {
  const _PublicProfileSection({
    required this.title,
    required this.children,
    required this.primary,
    required this.collapsed,
    required this.onToggle,
  });

  final String title;
  final List<Widget> children;
  final Color primary;
  final bool collapsed;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: PravaTypography.titleSmall.copyWith(
                      color: primary,
                      letterSpacing: 0,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: collapsed ? 0.5 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: Icon(
                    CupertinoIcons.chevron_up,
                    color: primary,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: Column(children: children),
          secondChild: const SizedBox.shrink(),
          crossFadeState: collapsed
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 180),
        ),
      ],
    );
  }
}

class _PublicInfoRow extends StatelessWidget {
  const _PublicInfoRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.primary,
    required this.secondary,
  });

  final IconData icon;
  final String title;
  final String value;
  final Color primary;
  final Color secondary;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 38, child: Icon(icon, size: 24, color: primary)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: PravaTypography.bodyLarge.copyWith(
                    color: primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (value.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: PravaTypography.bodyMedium.copyWith(
                      color: secondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HiddenInfoRow extends StatelessWidget {
  const _HiddenInfoRow({
    required this.label,
    required this.primary,
    required this.secondary,
  });

  final String label;
  final Color primary;
  final Color secondary;

  @override
  Widget build(BuildContext context) {
    return _PublicInfoRow(
      icon: CupertinoIcons.lock_fill,
      title: label,
      value: 'Hidden by privacy',
      primary: primary,
      secondary: secondary,
    );
  }
}

class _HighlightsPanel extends StatelessWidget {
  const _HighlightsPanel({
    required this.highlights,
    required this.primary,
    required this.secondary,
    required this.border,
  });

  final List<PublicProfileHighlight> highlights;
  final Color primary;
  final Color secondary;
  final Color border;

  @override
  Widget build(BuildContext context) {
    final tokens = context.pravaColors;
    if (highlights.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 42, 24, 28),
        child: Column(
          children: [
            Icon(CupertinoIcons.sparkles, size: 34, color: secondary),
            const SizedBox(height: 12),
            Text(
              'No highlights yet',
              style: PravaTypography.titleSmall.copyWith(
                color: primary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Featured moments from this profile will appear here.',
              textAlign: TextAlign.center,
              style: PravaTypography.bodyMedium.copyWith(color: secondary),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      child: Column(
        children: [
          for (final item in highlights)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: tokens.backgroundSurfaceSubtle,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: tokens.brandContainer,
                      borderRadius: BorderRadius.circular(14),
                      image: item.coverUrl.trim().isEmpty
                          ? null
                          : DecorationImage(
                              image: NetworkImage(item.coverUrl),
                              fit: BoxFit.cover,
                            ),
                    ),
                    child: item.coverUrl.trim().isEmpty
                        ? Icon(
                            CupertinoIcons.sparkles,
                            color: tokens.brandContent,
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title.trim().isEmpty
                              ? 'Highlight'
                              : item.title.trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: PravaTypography.bodyLarge.copyWith(
                            color: primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          item.description.trim().isEmpty
                              ? '${item.mediaUrls.length} media items'
                              : item.description.trim(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: PravaTypography.bodySmall.copyWith(
                            color: secondary,
                          ),
                        ),
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

class _PublicPostsList extends StatelessWidget {
  const _PublicPostsList({
    required this.posts,
    required this.primary,
    required this.secondary,
    required this.border,
    required this.formatCount,
    required this.formatTime,
    this.emptyTitle = 'No public posts',
    this.emptySubtitle = 'Public posts from this profile will appear here.',
  });

  final List<PublicProfilePost> posts;
  final Color primary;
  final Color secondary;
  final Color border;
  final String Function(int) formatCount;
  final String Function(DateTime) formatTime;
  final String emptyTitle;
  final String emptySubtitle;

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 42, 24, 28),
        child: Column(
          children: [
            Icon(CupertinoIcons.text_bubble, size: 34, color: secondary),
            const SizedBox(height: 12),
            Text(
              emptyTitle,
              style: PravaTypography.titleSmall.copyWith(
                color: primary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              emptySubtitle,
              textAlign: TextAlign.center,
              style: PravaTypography.bodyMedium.copyWith(color: secondary),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      child: Column(
        children: posts
            .map(
              (post) => _PublicPostRow(
                post: post,
                timestamp: formatTime(post.createdAt),
                primary: primary,
                secondary: secondary,
                border: border,
                formatCount: formatCount,
              ),
            )
            .toList(),
      ),
    );
  }
}

class _PublicPostRow extends StatelessWidget {
  const _PublicPostRow({
    required this.post,
    required this.timestamp,
    required this.primary,
    required this.secondary,
    required this.border,
    required this.formatCount,
  });

  final PublicProfilePost post;
  final String timestamp;
  final Color primary;
  final Color secondary;
  final Color border;
  final String Function(int) formatCount;

  @override
  Widget build(BuildContext context) {
    final tokens = context.pravaColors;
    final body = post.body.trim().isEmpty ? 'Text post' : post.body.trim();
    final tags = <String>[
      ...post.hashtags.map((tag) => tag.startsWith('#') ? tag : '#$tag'),
      ...post.mentions.map((tag) => tag.startsWith('@') ? tag : '@$tag'),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            body,
            style: PravaTypography.bodyLarge.copyWith(
              color: primary,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: tags.take(6).map((tag) {
                return Text(
                  tag,
                  style: PravaTypography.caption.copyWith(
                    color: tokens.linkDefault,
                    fontWeight: FontWeight.w700,
                  ),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            '$timestamp - ${formatCount(post.likeCount)} likes - '
            '${formatCount(post.commentCount)} comments',
            style: PravaTypography.bodySmall.copyWith(color: secondary),
          ),
        ],
      ),
    );
  }
}

class _LockedState extends StatelessWidget {
  const _LockedState({
    required this.title,
    required this.subtitle,
    required this.primary,
    required this.secondary,
    required this.border,
  });

  final String title;
  final String subtitle;
  final Color primary;
  final Color secondary;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(CupertinoIcons.lock_fill, size: 20, color: secondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: PravaTypography.bodyLarge.copyWith(
                    color: primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: PravaTypography.bodyMedium.copyWith(color: secondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RelationshipPill extends StatelessWidget {
  const _RelationshipPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: PravaTypography.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _InlinePrivateLine extends StatelessWidget {
  const _InlinePrivateLine({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(CupertinoIcons.lock_fill, size: 14, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: PravaTypography.bodySmall.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

class _PublicProfileError extends StatelessWidget {
  const _PublicProfileError({
    required this.primary,
    required this.secondary,
    required this.onBack,
    required this.onRetry,
  });

  final Color primary;
  final Color secondary;
  final VoidCallback onBack;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final tokens = context.pravaColors;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            CupertinoIcons.person_crop_circle_badge_exclam,
            size: 42,
            color: secondary,
          ),
          const SizedBox(height: 14),
          Text(
            'Profile unavailable',
            style: PravaTypography.titleSmall.copyWith(
              color: primary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This profile could not be loaded right now.',
            textAlign: TextAlign.center,
            style: PravaTypography.bodyMedium.copyWith(color: secondary),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: onRetry,
                  child: Container(
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: tokens.brandPrimary,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      'Retry',
                      style: PravaTypography.buttonMedium.copyWith(
                        color: tokens.textInverse,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: onBack,
                  child: Container(
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: secondary.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      'Back',
                      style: PravaTypography.buttonMedium.copyWith(
                        color: primary,
                        fontWeight: FontWeight.w800,
                      ),
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
