import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../../../navigation/prava_navigator.dart';
import '../../../../ui-system/background.dart';
import '../../../../ui-system/colors.dart';
import '../../../../ui-system/typography.dart';
import '../../../../ui-system/feedback/prava_toast.dart';
import '../../../../ui-system/feedback/toast_type.dart';
import '../../../../services/public_profile_service.dart';
import '../../../../services/user_search_service.dart';
import '../../../../services/chat_service.dart';
import '../chats/chat_thread_page.dart';
import '../chats/chats_page.dart';

class PublicProfilePage extends StatefulWidget {
  const PublicProfilePage({
    super.key,
    required this.userId,
    this.initialProfile,
    this.initialIsFollowing = false,
    this.initialIsFollowedBy = false,
  });

  final String userId;
  final PublicProfile? initialProfile;
  final bool initialIsFollowing;
  final bool initialIsFollowedBy;

  @override
  State<PublicProfilePage> createState() => _PublicProfilePageState();
}

class _PublicProfilePageState extends State<PublicProfilePage> {
  final PublicProfileService _profileService = PublicProfileService();
  final UserSearchService _userService = UserSearchService();
  final ChatService _chatService = ChatService();

  PublicProfile? _profile;
  bool _loading = false;
  bool _pendingFollow = false;
  bool _pendingChat = false;
  bool _following = false;
  bool _followedBy = false;

  @override
  void initState() {
    super.initState();
    _profile = widget.initialProfile;
    _following = widget.initialIsFollowing;
    _followedBy = widget.initialIsFollowedBy;
    if (widget.userId.isNotEmpty) {
      _loadProfile();
    }
  }

  Future<void> _loadProfile() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final summary = await _profileService.fetchProfile(
        widget.userId,
        limit: 12,
      );
      if (!mounted) return;
      setState(() {
        _loading = false;
        _profile = _buildProfileFromSummary(summary);
        _following = summary.relationship.isFollowing;
        _followedBy = summary.relationship.isFollowedBy;
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
    setState(() => _pendingFollow = true);
    try {
      final following = await _userService.toggleFollow(widget.userId);
      if (!mounted) return;
      setState(() {
        _pendingFollow = false;
        _following = following;
        if (_profile != null) {
          _profile = _profile!.copyWith(
            online: following && _followedBy,
            statusLine: _statusLine(
              isFollowing: following,
              isFollowedBy: _followedBy,
            ),
          );
        }
      });
      PravaToast.show(
        context,
        message: following ? 'Following' : 'Unfollowed',
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

  Future<void> _startChat() async {
    if (widget.userId.isEmpty || _pendingChat) return;
    final profile = _profile ?? widget.initialProfile;
    if (profile == null) return;
    HapticFeedback.selectionClick();
    setState(() => _pendingChat = true);

    try {
      final conversationId =
          await _chatService.createDm(otherUserId: widget.userId);
      if (!mounted) return;
      setState(() => _pendingChat = false);

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
        name: profile.displayName.isNotEmpty
            ? profile.displayName
            : profile.username,
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
      setState(() => _pendingChat = false);
      PravaToast.show(
        context,
        message: 'Unable to start chat',
        type: PravaToastType.error,
      );
    }
  }

  void _showAction(String label) {
    PravaToast.show(
      context,
      message: '$label coming soon',
      type: PravaToastType.info,
    );
  }

  String _formatCount(int value) {
    if (value >= 1000000) {
      final short = (value / 1000000)
          .toStringAsFixed(value % 1000000 == 0 ? 0 : 1);
      return '${short}M';
    }
    if (value >= 1000) {
      final short = (value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1);
      return '${short}K';
    }
    return value.toString();
  }

  String _formatRelativeTime(DateTime createdAt) {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    final weeks = (diff.inDays / 7).floor();
    if (weeks < 4) return '${weeks}w';
    final month = createdAt.month.toString().padLeft(2, '0');
    final day = createdAt.day.toString().padLeft(2, '0');
    return '${createdAt.year}-$month-$day';
  }

  String _statusLine({
    required bool isFollowing,
    required bool isFollowedBy,
  }) {
    if (isFollowing && isFollowedBy) {
      return 'Connected on Prava';
    }
    if (isFollowedBy) {
      return 'Follows you on Prava';
    }
    return 'Active on Prava';
  }

  PublicProfile _buildProfileFromSummary(PublicProfileSummary summary) {
    final user = summary.user;
    final displayName =
        user.displayName.isNotEmpty ? user.displayName : user.username;
    final joined = user.createdAt == null
        ? 'Joined recently'
        : 'Joined ${user.createdAt!.year}';
    final isMutual =
        summary.relationship.isFollowing && summary.relationship.isFollowedBy;
    final statusLine = _statusLine(
      isFollowing: summary.relationship.isFollowing,
      isFollowedBy: summary.relationship.isFollowedBy,
    );
    final coverCaption =
        user.location.isNotEmpty ? user.location : '@${user.username}';

    final interests = <String>{};
    for (final post in summary.posts) {
      for (final tag in post.hashtags) {
        final cleaned = tag.replaceFirst('#', '').trim();
        if (cleaned.isNotEmpty) {
          interests.add(cleaned);
        }
      }
    }
    final interestList = interests.isEmpty
        ? ['Realtime', 'Community', 'Security']
        : interests.take(4).toList();

    final posts = summary.posts.map((post) {
      final tags = <String>[];
      for (final tag in post.hashtags) {
        final cleaned = tag.trim();
        if (cleaned.isEmpty) continue;
        tags.add(cleaned.startsWith('#') ? cleaned : '#$cleaned');
      }
      if (tags.isEmpty) {
        tags.add('#prava');
      }

      return PublicPost(
        body: post.body.isNotEmpty ? post.body : 'No post yet.',
        timestamp: _formatRelativeTime(post.createdAt),
        likes: _formatCount(post.likeCount),
        comments: _formatCount(post.commentCount),
        shares: _formatCount(post.shareCount),
        badge: post.likeCount > 0 ? 'Popular' : 'New',
        tags: tags.take(3).toList(),
      );
    }).toList();

    return PublicProfile(
      displayName: displayName,
      username: user.username,
      bio: user.bio.isNotEmpty ? user.bio : 'No bio yet.',
      location: user.location,
      website:
          user.website.isNotEmpty ? user.website : 'prava.app/@${user.username}',
      joined: joined,
      verified: user.isVerified,
      online: isMutual,
      statusLine: statusLine,
      coverCaption: coverCaption,
      stats: [
        PublicStat(label: 'Posts', value: summary.stats.posts),
        PublicStat(label: 'Followers', value: summary.stats.followers),
        PublicStat(label: 'Following', value: summary.stats.following),
        PublicStat(label: 'Likes', value: summary.stats.likes),
      ],
      interests: interestList,
      posts: posts,
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile ?? widget.initialProfile;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary =
        isDark ? PravaColors.darkTextPrimary : PravaColors.lightTextPrimary;
    final secondary =
        isDark ? PravaColors.darkTextSecondary : PravaColors.lightTextSecondary;
    final surface =
        isDark ? PravaColors.darkBgSurface : PravaColors.lightBgSurface;
    final border =
        isDark ? PravaColors.darkBorderSubtle : PravaColors.lightBorderSubtle;

    if (profile == null && _loading) {
      return Scaffold(
        body: Stack(
          children: [
            _PageBackdrop(isDark: isDark),
            const Center(
              child: CupertinoActivityIndicator(radius: 12),
            ),
          ],
        ),
      );
    }

    if (profile == null) {
      return Scaffold(
        body: Stack(
          children: [
            _PageBackdrop(isDark: isDark),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Unable to load profile',
                    style: PravaTypography.body.copyWith(
                      color: primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  CupertinoButton(
                    color: PravaColors.accentPrimary,
                    onPressed: _loadProfile,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          _PageBackdrop(isDark: isDark),
          CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: _HeroCard(
                    profile: profile,
                    isDark: isDark,
                    onBack: () => Navigator.of(context).pop(),
                    onShare: () => _showAction('Share profile'),
                    onMore: () => _showAction('Profile options'),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: _HeaderCard(
                    profile: profile,
                    isDark: isDark,
                    primary: primary,
                    secondary: secondary,
                    surface: surface,
                    border: border,
                    following: _following,
                    followedBy: _followedBy,
                    pendingFollow: _pendingFollow,
                    pendingMessage: _pendingChat,
                    onFollow: _toggleFollow,
                    onMessage: _startChat,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: _StatStrip(
                    stats: profile.stats
                        .map(
                          (stat) => ProfileStat(
                            label: stat.label,
                            value: _formatCount(stat.value),
                          ),
                        )
                        .toList(),
                    primary: primary,
                    secondary: secondary,
                    surface: surface,
                    border: border,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: _AboutCard(
                    profile: profile,
                    primary: primary,
                    secondary: secondary,
                    surface: surface,
                    border: border,
                    isDark: isDark,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    'Latest posts',
                    style: PravaTypography.h3.copyWith(
                      color: primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                sliver: SliverList.builder(
                  itemCount: profile.posts.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _PostCard(
                        post: profile.posts[index],
                        isDark: isDark,
                        primary: primary,
                        secondary: secondary,
                        border: border,
                      ),
                    );
                  },
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.profile,
    required this.isDark,
    required this.onBack,
    required this.onShare,
    required this.onMore,
  });

  final PublicProfile profile;
  final bool isDark;
  final VoidCallback onBack;
  final VoidCallback onShare;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final gradient = LinearGradient(
      colors: [
        PravaColors.accentPrimary.withValues(alpha: isDark ? 0.35 : 0.55),
        PravaColors.accentMuted.withValues(alpha: isDark ? 0.25 : 0.4),
        isDark ? const Color(0xFF101322) : const Color(0xFFEAF1FF),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Container(
        height: 220,
        decoration: BoxDecoration(gradient: gradient),
        child: Stack(
          children: [
            Positioned(
              top: -40,
              right: -10,
              child: _BlurCircle(
                size: 160,
                color: Colors.white.withValues(alpha: 0.16),
              ),
            ),
            Positioned(
              bottom: -30,
              left: -20,
              child: _BlurCircle(
                size: 180,
                color: PravaColors.accentPrimary.withValues(alpha: 0.2),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              top: 12,
              child: Row(
                children: [
                  _IconPill(icon: CupertinoIcons.back, onTap: onBack),
                  const Spacer(),
                  _IconPill(icon: CupertinoIcons.share, onTap: onShare),
                  const SizedBox(width: 8),
                  _IconPill(
                    icon: CupertinoIcons.ellipsis_vertical,
                    onTap: onMore,
                  ),
                ],
              ),
            ),
            Align(
              alignment: Alignment.bottomLeft,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: isDark ? 0.08 : 0.55),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            CupertinoIcons.waveform_path_ecg,
                            color: PravaColors.accentPrimary,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            profile.statusLine,
                            style: PravaTypography.caption.copyWith(
                              color: isDark
                                  ? PravaColors.darkTextPrimary
                                  : PravaColors.lightTextPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Text(
                  profile.coverCaption,
                  style: PravaTypography.caption.copyWith(
                    color: isDark
                        ? PravaColors.darkTextSecondary
                        : PravaColors.lightTextSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.profile,
    required this.isDark,
    required this.primary,
    required this.secondary,
    required this.surface,
    required this.border,
    required this.following,
    required this.followedBy,
    required this.pendingFollow,
    required this.pendingMessage,
    required this.onFollow,
    required this.onMessage,
  });

  final PublicProfile profile;
  final bool isDark;
  final Color primary;
  final Color secondary;
  final Color surface;
  final Color border;
  final bool following;
  final bool followedBy;
  final bool pendingFollow;
  final bool pendingMessage;
  final VoidCallback onFollow;
  final VoidCallback onMessage;

  @override
  Widget build(BuildContext context) {
    final details = <Widget>[];
    void addDetail(IconData icon, String label) {
      if (label.trim().isEmpty) return;
      details.add(
        _AboutRow(
          icon: icon,
          label: label,
          primary: primary,
          secondary: secondary,
        ),
      );
      details.add(const SizedBox(height: 10));
    }

    addDetail(CupertinoIcons.location, profile.location);
    addDetail(CupertinoIcons.link, profile.website);
    addDetail(CupertinoIcons.calendar, profile.joined);
    if (details.isNotEmpty) {
      details.removeLast();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
            blurRadius: 22,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              _ProfileAvatar(
                initials: profile.initials,
                accent: PravaColors.accentPrimary,
                isOnline: profile.online,
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
                            profile.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: PravaTypography.h3.copyWith(
                              color: primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        if (profile.verified)
                          Icon(
                            CupertinoIcons.check_mark_circled_solid,
                            size: 16,
                            color: PravaColors.accentPrimary,
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '@${profile.username}',
                      style: PravaTypography.caption.copyWith(color: secondary),
                    ),
                  ],
                ),
              ),
              _FollowButton(
                following: following,
                followedBy: followedBy,
                pending: pendingFollow,
                onTap: onFollow,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              profile.bio,
              style: PravaTypography.bodySmall.copyWith(color: secondary),
            ),
          ),
          const SizedBox(height: 12),
          _ActionButton(
            icon: CupertinoIcons.chat_bubble_2,
            label: 'Message',
            onTap: onMessage,
            border: border,
            pending: pendingMessage,
          ),
        ],
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.initials,
    required this.accent,
    required this.isOnline,
  });

  final String initials;
  final Color accent;
  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                accent,
                PravaColors.accentMuted,
              ],
            ),
          ),
          child: CircleAvatar(
            radius: 26,
            backgroundColor: accent.withValues(alpha: 0.15),
            child: Text(
              initials,
              style: PravaTypography.h3.copyWith(
                color: accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        if (isOnline)
          Positioned(
            right: 4,
            bottom: 4,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: PravaColors.success,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: 2,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _FollowButton extends StatelessWidget {
  const _FollowButton({
    required this.following,
    required this.followedBy,
    required this.pending,
    required this.onTap,
  });

  final bool following;
  final bool followedBy;
  final bool pending;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = following ? 'Following' : (followedBy ? 'Follow back' : 'Follow');
    final backgroundGradient = following
        ? null
        : const LinearGradient(
            colors: [
              PravaColors.accentPrimary,
              PravaColors.accentMuted,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );
    final backgroundColor = following ? Colors.black12 : null;

    return GestureDetector(
      onTap: pending ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: backgroundGradient,
          color: backgroundColor,
        ),
        child: pending
            ? const CupertinoActivityIndicator(radius: 8)
            : Text(
                label,
                style: PravaTypography.caption.copyWith(
                  color: following ? PravaColors.accentPrimary : Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.border,
    required this.pending,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color border;
  final bool pending;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: pending ? null : onTap,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border),
        ),
        child: pending
            ? const Center(child: CupertinoActivityIndicator(radius: 8))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 16,
                    color: PravaColors.accentPrimary,
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
      ),
    );
  }
}

class _StatStrip extends StatelessWidget {
  const _StatStrip({
    required this.stats,
    required this.primary,
    required this.secondary,
    required this.surface,
    required this.border,
  });

  final List<ProfileStat> stats;
  final Color primary;
  final Color secondary;
  final Color surface;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Row(
        children: stats
            .map(
              (stat) => Expanded(
                child: Column(
                  children: [
                    Text(
                      stat.value,
                      style: PravaTypography.h3.copyWith(
                        color: primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      stat.label,
                      style: PravaTypography.caption.copyWith(color: secondary),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _AboutCard extends StatelessWidget {
  const _AboutCard({
    required this.profile,
    required this.primary,
    required this.secondary,
    required this.surface,
    required this.border,
    required this.isDark,
  });

  final PublicProfile profile;
  final Color primary;
  final Color secondary;
  final Color surface;
  final Color border;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final details = <Widget>[];
    void addDetail(IconData icon, String label) {
      if (label.trim().isEmpty) return;
      details.add(
        _AboutRow(
          icon: icon,
          label: label,
          primary: primary,
          secondary: secondary,
        ),
      );
      details.add(const SizedBox(height: 10));
    }

    addDetail(CupertinoIcons.location, profile.location);
    addDetail(CupertinoIcons.link, profile.website);
    addDetail(CupertinoIcons.calendar, profile.joined);
    if (details.isNotEmpty) {
      details.removeLast();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'About',
            style: PravaTypography.h3.copyWith(
              color: primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            profile.bio,
            style: PravaTypography.bodySmall.copyWith(color: secondary),
          ),
          const SizedBox(height: 12),
          if (details.isEmpty)
            Text(
              'No public details yet',
              style: PravaTypography.caption.copyWith(
                color: secondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          if (details.isNotEmpty) ...details,
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: profile.interests
                .map(
                  (interest) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : Colors.black12,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      interest,
                      style: PravaTypography.caption.copyWith(
                        color: secondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _AboutRow extends StatelessWidget {
  const _AboutRow({
    required this.icon,
    required this.label,
    required this.primary,
    required this.secondary,
  });

  final IconData icon;
  final String label;
  final Color primary;
  final Color secondary;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: secondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: PravaTypography.bodySmall.copyWith(
              color: primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({
    required this.post,
    required this.isDark,
    required this.primary,
    required this.secondary,
    required this.border,
  });

  final PublicPost post;
  final bool isDark;
  final Color primary;
  final Color secondary;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? PravaColors.darkBgElevated : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                post.timestamp,
                style: PravaTypography.caption.copyWith(color: secondary),
              ),
              const Spacer(),
              Text(
                post.badge,
                style: PravaTypography.caption.copyWith(
                  color: PravaColors.accentPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            post.body,
            style: PravaTypography.body.copyWith(
              color: primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: post.tags
                .map(
                  (tag) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : Colors.black12,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      tag,
                      style: PravaTypography.caption.copyWith(
                        color: secondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _PostAction(
                icon: CupertinoIcons.heart,
                label: post.likes,
                color: secondary,
              ),
              _PostAction(
                icon: CupertinoIcons.chat_bubble,
                label: post.comments,
                color: secondary,
              ),
              _PostAction(
                icon: CupertinoIcons.arrowshape_turn_up_right,
                label: post.shares,
                color: secondary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PostAction extends StatelessWidget {
  const _PostAction({
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
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: PravaTypography.caption.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _BlurCircle extends StatelessWidget {
  const _BlurCircle({
    required this.size,
    required this.color,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
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

class PublicProfile {
  PublicProfile({
    required this.displayName,
    required this.username,
    required this.bio,
    required this.location,
    required this.website,
    required this.joined,
    required this.verified,
    required this.online,
    required this.statusLine,
    required this.coverCaption,
    required this.stats,
    required this.interests,
    required this.posts,
  });

  final String displayName;
  final String username;
  final String bio;
  final String location;
  final String website;
  final String joined;
  final bool verified;
  final bool online;
  final String statusLine;
  final String coverCaption;
  final List<PublicStat> stats;
  final List<String> interests;
  final List<PublicPost> posts;

  String get initials {
    final parts = displayName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1))
        .toUpperCase();
  }

  PublicProfile copyWith({
    bool? online,
    String? statusLine,
    String? coverCaption,
  }) {
    return PublicProfile(
      displayName: displayName,
      username: username,
      bio: bio,
      location: location,
      website: website,
      joined: joined,
      verified: verified,
      online: online ?? this.online,
      statusLine: statusLine ?? this.statusLine,
      coverCaption: coverCaption ?? this.coverCaption,
      stats: stats,
      interests: interests,
      posts: posts,
    );
  }

  factory PublicProfile.sample() {
    return PublicProfile(
      displayName: 'Maya Sen',
      username: 'maya.sen',
      bio:
          'Designing realtime communities and creator tools. Building Prava public experiences.',
      location: 'Bangalore, IN',
      website: 'prava.app/maya',
      joined: 'Joined 2023',
      verified: true,
      online: true,
      statusLine: 'Live on Prava',
      coverCaption: 'Prava Creator Studio',
      stats: [
        PublicStat(label: 'Posts', value: 182),
        PublicStat(label: 'Followers', value: 24800),
        PublicStat(label: 'Following', value: 312),
        PublicStat(label: 'Likes', value: 130000),
      ],
      interests: [
        'Realtime',
        'Design systems',
        'Security',
        'Community',
      ],
      posts: [
        PublicPost(
          body:
              'Building a smooth, premium feed experience with realtime presence.',
          timestamp: '2h',
          likes: '12.4k',
          comments: '980',
          shares: '242',
          badge: 'Featured',
          tags: ['#product', '#realtime'],
        ),
        PublicPost(
          body:
              'Prava profiles are now crafted for creators. New insights soon.',
          timestamp: '1d',
          likes: '8.2k',
          comments: '620',
          shares: '180',
          badge: 'Update',
          tags: ['#creator', '#design'],
        ),
        PublicPost(
          body: 'Private communities with public touchpoints coming next.',
          timestamp: '3d',
          likes: '6.8k',
          comments: '512',
          shares: '140',
          badge: 'Roadmap',
          tags: ['#community', '#secure'],
        ),
      ],
    );
  }
}

class PublicStat {
  PublicStat({required this.label, required this.value});

  final String label;
  final int value;
}

class PublicPost {
  PublicPost({
    required this.body,
    required this.timestamp,
    required this.likes,
    required this.comments,
    required this.shares,
    required this.badge,
    required this.tags,
  });

  final String body;
  final String timestamp;
  final String likes;
  final String comments;
  final String shares;
  final String badge;
  final List<String> tags;
}

class ProfileStat {
  ProfileStat({required this.label, required this.value});

  final String label;
  final String value;
}
