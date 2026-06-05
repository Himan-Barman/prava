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
    HapticFeedback.selectionClick();
    final nextFollow = !_following;
    setState(() => _pendingFollow = true);

    try {
      final following = await _profileService.setFollow(
        widget.userId,
        nextFollow,
      );
      if (!mounted) return;
      setState(() {
        _following = following;
        _pendingFollow = false;
      });
      await _loadProfile(silent: true);
      if (!mounted) return;
      PravaToast.show(
        context,
        message: _following && _followedBy
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
    return 'Joined ${value.year}';
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
    final primary = isDark
        ? PravaColors.darkTextPrimary
        : PravaColors.lightTextPrimary;
    final secondary = isDark
        ? PravaColors.darkTextSecondary
        : PravaColors.lightTextSecondary;
    final border = isDark
        ? PravaColors.darkBorderSubtle
        : PravaColors.lightBorderSubtle;

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
      color: PravaColors.accentPrimary,
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
              initials: _initials(displayName),
              avatarUrl: user.avatarUrl,
              verified: user.isVerified,
              relationship: _relationshipLabel(),
              bio: user.bio,
              bioVisible: visibility.canSee('bio'),
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
              pendingFollow: _pendingFollow,
              openingChat: _openingChat,
              primary: primary,
              secondary: secondary,
              border: border,
              onFollow: _toggleFollow,
              onMessage: _openChat,
              onPostsTap: () => _openPostsPage(summary),
              onFollowersTap: () =>
                  _openConnections(summary, ProfileConnectionKind.followers),
              onFollowingTap: () =>
                  _openConnections(summary, ProfileConnectionKind.following),
            ),
          ),
          SliverToBoxAdapter(
            child: _PublicProfileTabBar(
              value: _contentTab,
              primary: primary,
              secondary: secondary,
              border: border,
              onChanged: _setTab,
            ),
          ),
          if (_contentTab == _PublicProfileContentTab.all) ...[
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
          ] else
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

enum _PublicProfileContentTab { all, posts }

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
      style: PravaTypography.h3.copyWith(
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
    required this.initials,
    required this.avatarUrl,
    required this.verified,
    required this.relationship,
    required this.bio,
    required this.bioVisible,
    required this.posts,
    required this.followers,
    required this.following,
    required this.isFriend,
    required this.followingUser,
    required this.followedByUser,
    required this.pendingFollow,
    required this.openingChat,
    required this.primary,
    required this.secondary,
    required this.border,
    required this.onFollow,
    required this.onMessage,
    required this.onPostsTap,
    required this.onFollowersTap,
    required this.onFollowingTap,
  });

  final String displayName;
  final String initials;
  final String avatarUrl;
  final bool verified;
  final String relationship;
  final String bio;
  final bool bioVisible;
  final String posts;
  final String followers;
  final String following;
  final bool isFriend;
  final bool followingUser;
  final bool followedByUser;
  final bool pendingFollow;
  final bool openingChat;
  final Color primary;
  final Color secondary;
  final Color border;
  final VoidCallback onFollow;
  final VoidCallback onMessage;
  final VoidCallback onPostsTap;
  final VoidCallback onFollowersTap;
  final VoidCallback onFollowingTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? PravaColors.darkBgMain : PravaColors.lightBgMain;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _PublicProfileAvatar(
                initials: initials,
                url: avatarUrl,
                size: 92,
                borderColor: surface,
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
                            style: PravaTypography.h2.copyWith(
                              color: primary,
                              letterSpacing: 0,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (verified) ...[
                          const SizedBox(width: 6),
                          const Icon(
                            CupertinoIcons.check_mark_circled_solid,
                            color: PravaColors.accentPrimary,
                            size: 17,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    _RelationshipPill(label: relationship, color: secondary),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _PublicProfileCount(
                          label: 'posts',
                          value: posts,
                          primary: primary,
                          onTap: onPostsTap,
                        ),
                        _PublicProfileCount(
                          label: 'followers',
                          value: followers,
                          primary: primary,
                          onTap: onFollowersTap,
                        ),
                        _PublicProfileCount(
                          label: 'following',
                          value: following,
                          primary: primary,
                          onTap: onFollowingTap,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!bioVisible || bio.trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            if (!bioVisible)
              _InlinePrivateLine(
                label: 'Bio hidden by privacy',
                color: secondary,
              )
            else
              Text(
                bio.trim(),
                style: PravaTypography.body.copyWith(
                  color: primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
          const SizedBox(height: 18),
          _RelationActions(
            isFriend: isFriend,
            following: followingUser,
            followedBy: followedByUser,
            pendingFollow: pendingFollow,
            openingChat: openingChat,
            border: border,
            primary: primary,
            onFollow: onFollow,
            onMessage: onMessage,
          ),
        ],
      ),
    );
  }
}

class _PublicProfileTabBar extends StatelessWidget {
  const _PublicProfileTabBar({
    required this.value,
    required this.primary,
    required this.secondary,
    required this.border,
    required this.onChanged,
  });

  final _PublicProfileContentTab value;
  final Color primary;
  final Color secondary;
  final Color border;
  final ValueChanged<_PublicProfileContentTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 8),
      child: Row(
        children: [
          _PublicProfileTabButton(
            label: 'All',
            selected: value == _PublicProfileContentTab.all,
            primary: primary,
            secondary: secondary,
            border: border,
            onTap: () => onChanged(_PublicProfileContentTab.all),
          ),
          const SizedBox(width: 10),
          _PublicProfileTabButton(
            label: 'Posts',
            selected: value == _PublicProfileContentTab.posts,
            primary: primary,
            secondary: secondary,
            border: border,
            onTap: () => onChanged(_PublicProfileContentTab.posts),
          ),
        ],
      ),
    );
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
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 40,
          decoration: BoxDecoration(
            color: selected
                ? PravaColors.accentPrimary.withValues(alpha: 0.16)
                : Colors.transparent,
            border: Border.all(
              color: selected ? PravaColors.accentPrimary : border,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              label,
              style: PravaTypography.button.copyWith(
                color: selected ? PravaColors.accentPrimary : secondary,
                letterSpacing: 0,
                fontWeight: FontWeight.w800,
              ),
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
    required this.pendingFollow,
    required this.openingChat,
    required this.border,
    required this.primary,
    required this.onFollow,
    required this.onMessage,
  });

  final bool isFriend;
  final bool following;
  final bool followedBy;
  final bool pendingFollow;
  final bool openingChat;
  final Color border;
  final Color primary;
  final VoidCallback onFollow;
  final VoidCallback onMessage;

  String get _followLabel {
    if (isFriend) return 'Friends';
    if (following) return 'Following';
    if (followedBy) return 'Follow back';
    return 'Follow';
  }

  @override
  Widget build(BuildContext context) {
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
        ],
      );
    }

    return _PublicActionButton(
      label: _followLabel,
      filled: !following,
      loading: pendingFollow,
      border: border,
      primary: primary,
      onTap: pendingFollow ? null : onFollow,
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
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 44,
        decoration: BoxDecoration(
          color: filled ? PravaColors.accentPrimary : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: filled ? null : Border.all(color: border ?? Colors.white24),
        ),
        child: Center(
          child: loading
              ? CupertinoActivityIndicator(
                  radius: 9,
                  color: filled ? Colors.white : PravaColors.accentPrimary,
                )
              : Text(
                  label,
                  style: PravaTypography.button.copyWith(
                    color: filled
                        ? Colors.white
                        : (primary ?? PravaColors.accentPrimary),
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
                color: PravaColors.accentPrimary.withValues(alpha: 0.16),
                child: Center(
                  child: Text(
                    initials,
                    style: PravaTypography.h2.copyWith(
                      color: PravaColors.accentPrimary,
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
    required this.onTap,
  });

  final String label;
  final String value;
  final Color primary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: value,
                style: PravaTypography.body.copyWith(
                  color: primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              TextSpan(
                text: ' $label',
                style: PravaTypography.body.copyWith(color: primary),
              ),
            ],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
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
                    style: PravaTypography.h3.copyWith(
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
                    style: PravaTypography.body.copyWith(color: secondary),
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

class _PublicPostsList extends StatelessWidget {
  const _PublicPostsList({
    required this.posts,
    required this.primary,
    required this.secondary,
    required this.border,
    required this.formatCount,
    required this.formatTime,
  });

  final List<PublicProfilePost> posts;
  final Color primary;
  final Color secondary;
  final Color border;
  final String Function(int) formatCount;
  final String Function(DateTime) formatTime;

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
              'No public posts',
              style: PravaTypography.h3.copyWith(
                color: primary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Public posts from this profile will appear here.',
              textAlign: TextAlign.center,
              style: PravaTypography.body.copyWith(color: secondary),
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
                    color: PravaColors.accentPrimary,
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
                  style: PravaTypography.body.copyWith(color: secondary),
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
            style: PravaTypography.h3.copyWith(
              color: primary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This profile could not be loaded right now.',
            textAlign: TextAlign.center,
            style: PravaTypography.body.copyWith(color: secondary),
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
                      color: PravaColors.accentPrimary,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      'Retry',
                      style: PravaTypography.button.copyWith(
                        color: Colors.white,
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
                      style: PravaTypography.button.copyWith(
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
