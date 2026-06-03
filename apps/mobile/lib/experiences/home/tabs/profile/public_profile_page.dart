import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../services/profile_visibility.dart';
import '../../../../services/public_profile_service.dart';
import '../../../../ui-system/background.dart';
import '../../../../ui-system/colors.dart';
import '../../../../ui-system/feedback/prava_toast.dart';
import '../../../../ui-system/feedback/toast_type.dart';
import '../../../../ui-system/typography.dart';

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

  PublicProfileSummary? _summary;
  bool _loading = true;
  bool _pendingFollow = false;
  bool _following = false;
  bool _followedBy = false;

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

  String _displayName(PublicProfileUser user) {
    return user.displayName.isNotEmpty ? user.displayName : user.username;
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1))
        .toUpperCase();
  }

  String _formatCount(int value) {
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

  List<_PublicStat> _stats(PublicProfileSummary summary) {
    final visibility = summary.visibility;
    String shown(String key, int value) {
      return visibility.canSee(key) ? _formatCount(value) : '--';
    }

    return [
      _PublicStat(label: 'Posts', value: shown('posts', summary.stats.posts)),
      _PublicStat(
        label: 'Followers',
        value: shown('followers', summary.stats.followers),
      ),
      _PublicStat(
        label: 'Following',
        value: shown('following', summary.stats.following),
      ),
      _PublicStat(label: 'Likes', value: shown('likes', summary.stats.likes)),
    ];
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
    final elevated =
        isDark ? PravaColors.darkBgElevated : PravaColors.lightBgElevated;
    final border =
        isDark ? PravaColors.darkBorderSubtle : PravaColors.lightBorderSubtle;

    return Scaffold(
      body: Stack(
        children: [
          PravaBackground(isDark: isDark),
          SafeArea(
            child: _buildBody(
              primary: primary,
              secondary: secondary,
              surface: surface,
              elevated: elevated,
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
    required Color surface,
    required Color elevated,
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
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: _TopBar(
                primary: primary,
                border: border,
                onBack: () => Navigator.of(context).pop(),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: _PublicHeaderCard(
                displayName: displayName,
                username: user.username,
                initials: _initials(displayName),
                verified: user.isVerified,
                relationship: _relationshipLabel(),
                bio: user.bio,
                bioVisible: visibility.canSee('bio'),
                following: _following,
                followedBy: _followedBy,
                pendingFollow: _pendingFollow,
                primary: primary,
                secondary: secondary,
                surface: elevated,
                border: border,
                onFollow: _toggleFollow,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: _PublicStatsCard(
                stats: _stats(summary),
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
              child: _PublicAboutCard(
                location: user.location,
                website: user.website,
                joined: _formatJoined(user.createdAt),
                visibility: visibility,
                primary: primary,
                secondary: secondary,
                surface: surface,
                border: border,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              child: Text(
                'Posts',
                style: PravaTypography.h3.copyWith(
                  color: primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          if (postsHidden)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: _LockedState(
                  title: 'Posts are private',
                  subtitle: 'This profile owner limits who can see posts.',
                  primary: primary,
                  secondary: secondary,
                  surface: surface,
                  border: border,
                ),
              ),
            )
          else if (summary.posts.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: _LockedState(
                  title: 'No public posts',
                  subtitle: 'Public posts from this profile will appear here.',
                  primary: primary,
                  secondary: secondary,
                  surface: surface,
                  border: border,
                  locked: false,
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverList.builder(
                itemCount: summary.posts.length * 2 - 1,
                itemBuilder: (context, index) {
                  if (index.isOdd) return const SizedBox(height: 12);
                  final post = summary.posts[index ~/ 2];
                  return _PublicPostCard(
                    post: post,
                    timestamp: _formatRelativeTime(post.createdAt),
                    primary: primary,
                    secondary: secondary,
                    surface: elevated,
                    border: border,
                    formatCount: _formatCount,
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.primary,
    required this.border,
    required this.onBack,
  });

  final Color primary;
  final Color border;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: onBack,
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white10
                  : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: border),
            ),
            child: Icon(CupertinoIcons.back, color: primary, size: 20),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          'Profile',
          style: PravaTypography.h3.copyWith(
            color: primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _PublicHeaderCard extends StatelessWidget {
  const _PublicHeaderCard({
    required this.displayName,
    required this.username,
    required this.initials,
    required this.verified,
    required this.relationship,
    required this.bio,
    required this.bioVisible,
    required this.following,
    required this.followedBy,
    required this.pendingFollow,
    required this.primary,
    required this.secondary,
    required this.surface,
    required this.border,
    required this.onFollow,
  });

  final String displayName;
  final String username;
  final String initials;
  final bool verified;
  final String relationship;
  final String bio;
  final bool bioVisible;
  final bool following;
  final bool followedBy;
  final bool pendingFollow;
  final Color primary;
  final Color secondary;
  final Color surface;
  final Color border;
  final VoidCallback onFollow;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Avatar(initials: initials),
              const SizedBox(width: 14),
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
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (verified) ...[
                          const SizedBox(width: 6),
                          const Icon(
                            CupertinoIcons.check_mark_circled_solid,
                            color: PravaColors.accentPrimary,
                            size: 18,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '@$username',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: PravaTypography.bodySmall.copyWith(
                        color: secondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _RelationshipPill(label: relationship, color: secondary),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (!bioVisible)
            _HiddenLine(label: 'Bio hidden by privacy', secondary: secondary)
          else if (bio.trim().isNotEmpty)
            Text(
              bio.trim(),
              style: PravaTypography.body.copyWith(color: primary),
            )
          else
            Text(
              'No public bio.',
              style: PravaTypography.bodySmall.copyWith(color: secondary),
            ),
          const SizedBox(height: 16),
          _FollowButton(
            following: following,
            followedBy: followedBy,
            pending: pendingFollow,
            onTap: onFollow,
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 32,
      backgroundColor: PravaColors.accentPrimary.withValues(alpha: 0.14),
      child: Text(
        initials,
        style: PravaTypography.h3.copyWith(
          color: PravaColors.accentPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
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
    final isFriend = following && followedBy;
    final label = isFriend
        ? 'Friends'
        : (following ? 'Following' : (followedBy ? 'Follow back' : 'Follow'));
    final isActive = !following;

    return GestureDetector(
      onTap: pending ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 48,
        decoration: BoxDecoration(
          color: isActive
              ? PravaColors.accentPrimary
              : PravaColors.accentPrimary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: pending
              ? const CupertinoActivityIndicator(radius: 9)
              : Text(
                  label,
                  style: PravaTypography.button.copyWith(
                    color: isActive ? Colors.white : PravaColors.accentPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      ),
    );
  }
}

class _PublicStatsCard extends StatelessWidget {
  const _PublicStatsCard({
    required this.stats,
    required this.primary,
    required this.secondary,
    required this.surface,
    required this.border,
  });

  final List<_PublicStat> stats;
  final Color primary;
  final Color secondary;
  final Color surface;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: stats.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.7,
        ),
        itemBuilder: (context, index) {
          final stat = stats[index];
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white10
                  : Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    stat.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PravaTypography.caption.copyWith(color: secondary),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  stat.value,
                  style: PravaTypography.h3.copyWith(
                    color: primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PublicAboutCard extends StatelessWidget {
  const _PublicAboutCard({
    required this.location,
    required this.website,
    required this.joined,
    required this.visibility,
    required this.primary,
    required this.secondary,
    required this.surface,
    required this.border,
  });

  final String location;
  final String website;
  final String joined;
  final ProfileVisibility visibility;
  final Color primary;
  final Color secondary;
  final Color surface;
  final Color border;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];

    void addVisible(String key, IconData icon, String label) {
      if (!visibility.canSee(key)) {
        rows.add(_HiddenDetail(label: ProfileVisibility.fieldLabel(key), secondary: secondary));
        rows.add(const SizedBox(height: 10));
        return;
      }
      if (label.trim().isEmpty) return;
      rows.add(_DetailRow(icon: icon, label: label, primary: primary, secondary: secondary));
      rows.add(const SizedBox(height: 10));
    }

    addVisible('location', CupertinoIcons.location_solid, location);
    addVisible('website', CupertinoIcons.link, website);
    addVisible('joined', CupertinoIcons.calendar, joined);
    if (rows.isNotEmpty) rows.removeLast();

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
            'Public Details',
            style: PravaTypography.h3.copyWith(
              color: primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          if (rows.isEmpty)
            Text(
              'No public details.',
              style: PravaTypography.bodySmall.copyWith(color: secondary),
            )
          else
            ...rows,
        ],
      ),
    );
  }
}

class _PublicPostCard extends StatelessWidget {
  const _PublicPostCard({
    required this.post,
    required this.timestamp,
    required this.primary,
    required this.secondary,
    required this.surface,
    required this.border,
    required this.formatCount,
  });

  final PublicProfilePost post;
  final String timestamp;
  final Color primary;
  final Color secondary;
  final Color surface;
  final Color border;
  final String Function(int) formatCount;

  @override
  Widget build(BuildContext context) {
    final tags = <String>[
      ...post.hashtags.map((tag) => tag.startsWith('#') ? tag : '#$tag'),
      ...post.mentions.map((tag) => tag.startsWith('@') ? tag : '@$tag'),
    ];

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
            timestamp,
            style: PravaTypography.caption.copyWith(color: secondary),
          ),
          const SizedBox(height: 10),
          Text(
            post.body,
            style: PravaTypography.body.copyWith(
              color: primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: tags
                  .take(6)
                  .map(
                    (tag) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: PravaColors.accentPrimary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        tag,
                        style: PravaTypography.caption.copyWith(
                          color: PravaColors.accentPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _PostMetric(
                icon: CupertinoIcons.heart,
                label: formatCount(post.likeCount),
                color: secondary,
              ),
              _PostMetric(
                icon: CupertinoIcons.chat_bubble,
                label: formatCount(post.commentCount),
                color: secondary,
              ),
              _PostMetric(
                icon: CupertinoIcons.arrowshape_turn_up_right,
                label: formatCount(post.shareCount),
                color: secondary,
              ),
            ],
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
    required this.surface,
    required this.border,
    this.locked = true,
  });

  final String title;
  final String subtitle;
  final Color primary;
  final Color secondary;
  final Color surface;
  final Color border;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            locked ? CupertinoIcons.lock_fill : CupertinoIcons.doc_text,
            size: 18,
            color: secondary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: PravaTypography.body.copyWith(
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
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: secondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
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

class _HiddenDetail extends StatelessWidget {
  const _HiddenDetail({
    required this.label,
    required this.secondary,
  });

  final String label;
  final Color secondary;

  @override
  Widget build(BuildContext context) {
    return _HiddenLine(label: '$label hidden by privacy', secondary: secondary);
  }
}

class _HiddenLine extends StatelessWidget {
  const _HiddenLine({
    required this.label,
    required this.secondary,
  });

  final String label;
  final Color secondary;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(CupertinoIcons.lock_fill, size: 14, color: secondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: PravaTypography.bodySmall.copyWith(color: secondary),
          ),
        ),
      ],
    );
  }
}

class _RelationshipPill extends StatelessWidget {
  const _RelationshipPill({
    required this.label,
    required this.color,
  });

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

class _PostMetric extends StatelessWidget {
  const _PostMetric({
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
          Text(
            'Profile unavailable',
            style: PravaTypography.h3.copyWith(
              color: primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'This profile could not be loaded right now.',
            textAlign: TextAlign.center,
            style: PravaTypography.bodySmall.copyWith(color: secondary),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: CupertinoButton(
                  color: PravaColors.accentPrimary,
                  onPressed: onRetry,
                  child: const Text('Retry'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: CupertinoButton(
                  color: secondary.withValues(alpha: 0.18),
                  onPressed: onBack,
                  child: Text(
                    'Back',
                    style: PravaTypography.button.copyWith(color: primary),
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

class _PublicStat {
  const _PublicStat({required this.label, required this.value});

  final String label;
  final String value;
}
