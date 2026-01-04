import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../../../ui-system/colors.dart';
import '../../../../ui-system/typography.dart';
import '../../../../ui-system/skeleton/profile_skeleton.dart';
import '../../../../ui-system/feedback/prava_toast.dart';
import '../../../../ui-system/feedback/toast_type.dart';
import '../../../../services/profile_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final ProfileService _profileService = ProfileService();
  ProfileViewModel? _profile;

  bool _loading = true;
  bool _following = false;
  int _segmentIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  void _toggleFollow() {
    HapticFeedback.selectionClick();
    setState(() => _following = !_following);
  }

  void _setSegment(int index) {
    HapticFeedback.selectionClick();
    setState(() => _segmentIndex = index);
  }

  Future<void> _loadProfile() async {
    setState(() => _loading = true);
    try {
      final summary = await _profileService.fetchMyProfile(limit: 12);
      if (!mounted) return;
      setState(() {
        _profile = _buildProfile(summary);
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

  ProfileViewModel _buildProfile(ProfileSummary summary) {
    final template = ProfileViewModel.sample();
    final displayName = summary.user.displayName.isNotEmpty
        ? summary.user.displayName
        : template.displayName;
    final username = summary.user.username.isNotEmpty
        ? summary.user.username
        : template.username;
    final initials = _buildInitials(displayName);
    final joined = summary.user.createdAt != null
        ? 'Joined ${summary.user.createdAt!.year}'
        : template.joined;
    final bio = summary.user.bio.isNotEmpty ? summary.user.bio : template.bio;
    final location = summary.user.location.isNotEmpty
        ? summary.user.location
        : template.location;
    final website = summary.user.website.isNotEmpty
        ? summary.user.website
        : template.website;

    final stats = [
      ProfileStat(label: 'Posts', value: _formatCount(summary.stats.posts)),
      ProfileStat(
        label: 'Followers',
        value: _formatCount(summary.stats.followers),
      ),
      ProfileStat(
        label: 'Following',
        value: _formatCount(summary.stats.following),
      ),
      ProfileStat(label: 'Likes', value: _formatCount(summary.stats.likes)),
    ];

    final posts = summary.posts.map(_mapPost).toList();
    final liked = summary.liked.map(_mapPost).toList();

    return ProfileViewModel(
      displayName: displayName,
      username: username,
      initials: initials,
      bio: bio,
      statusLine: template.statusLine,
      liveBadge: template.liveBadge,
      coverCaption: template.coverCaption,
      tierLabel: template.tierLabel,
      activityTag: template.activityTag,
      online: template.online,
      verified: summary.user.isVerified,
      stats: stats,
      work: template.work,
      location: location,
      website: website,
      values: template.values,
      joined: joined,
      interests: template.interests,
      highlights: template.highlights,
      mutuals: template.mutuals,
      posts: posts.isNotEmpty ? posts : template.posts,
      media: template.media,
      liked: liked.isNotEmpty ? liked : template.liked,
      premiumHeadline: template.premiumHeadline,
      premiumSubhead: template.premiumSubhead,
      premiumCta: template.premiumCta,
    );
  }

  ProfilePost _mapPost(ProfileFeedPost post) {
    final tags = <String>[
      ...post.hashtags.map((tag) => '#$tag'),
      ...post.mentions.map((tag) => '@$tag'),
    ];

    return ProfilePost(
      body: post.body,
      timestamp: _formatTimeAgo(post.createdAt),
      likes: _formatCount(post.likeCount),
      comments: _formatCount(post.commentCount),
      shares: _formatCount(post.shareCount),
      tags: tags,
    );
  }

  String _buildInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1))
        .toUpperCase();
  }

  String _formatCount(int value) {
    if (value >= 1000000) {
      final short = (value / 1000000)
          .toStringAsFixed(value % 1000000 == 0 ? 0 : 1);
      return '${short}M';
    }
    if (value >= 1000) {
      final short = (value / 1000)
          .toStringAsFixed(value % 1000 == 0 ? 0 : 1);
      return '${short}K';
    }
    return value.toString();
  }

  String _formatTimeAgo(DateTime createdAt) {
    final now = DateTime.now();
    final diff = now.difference(createdAt);

    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';

    final weeks = diff.inDays ~/ 7;
    if (weeks < 5) return '${weeks}w';

    final month = createdAt.month.toString().padLeft(2, '0');
    final day = createdAt.day.toString().padLeft(2, '0');
    return '$month/$day/${createdAt.year}';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const ProfileSkeleton();
    }

    final profile = _profile ?? ProfileViewModel.sample();

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

    final slivers = <Widget>[
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              _ProfileHero(
                profile: profile,
                isDark: isDark,
                primary: primary,
                secondary: secondary,
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: -92,
                child: _IdentityCard(
                  profile: profile,
                  isDark: isDark,
                  primary: primary,
                  secondary: secondary,
                  surface: elevated,
                  border: border,
                  following: _following,
                  onFollow: _toggleFollow,
                ),
              ),
            ],
          ),
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 110)),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: _StatStrip(
            stats: profile.stats,
            primary: primary,
            secondary: secondary,
            surface: surface,
            border: border,
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: _PremiumPanel(
            profile: profile,
            isDark: isDark,
            primary: primary,
            secondary: secondary,
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: _HighlightRow(
            highlights: profile.highlights,
            primary: primary,
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: _AboutCard(
            profile: profile,
            isDark: isDark,
            primary: primary,
            secondary: secondary,
            surface: surface,
            border: border,
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: _FriendsRow(
            friends: profile.mutuals,
            isDark: isDark,
            primary: primary,
            secondary: secondary,
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: _ProfileSegmentedControl(
            value: _segmentIndex,
            onChanged: _setSegment,
            secondary: secondary,
            surface: surface,
          ),
        ),
      ),
    ];

    if (_segmentIndex == 0) {
      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          sliver: SliverList.builder(
            itemCount: profile.posts.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ProfilePostCard(
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
      );
    } else if (_segmentIndex == 1) {
      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          sliver: SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1,
            ),
            itemCount: profile.media.length,
            itemBuilder: (context, index) {
              return _MediaTile(
                media: profile.media[index],
                isDark: isDark,
              );
            },
          ),
        ),
      );
    } else {
      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          sliver: SliverList.builder(
            itemCount: profile.liked.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ProfilePostCard(
                  post: profile.liked[index],
                  isDark: isDark,
                  primary: primary,
                  secondary: secondary,
                  border: border,
                  liked: true,
                ),
              );
            },
          ),
        ),
      );
    }

    slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 24)));

    return CustomScrollView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: slivers,
    );
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.profile,
    required this.isDark,
    required this.primary,
    required this.secondary,
  });

  final ProfileViewModel profile;
  final bool isDark;
  final Color primary;
  final Color secondary;

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
        height: 230,
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
              top: 18,
              right: 16,
              child: Row(
                children: [
                  _HeroIconButton(
                    icon: CupertinoIcons.share,
                    onTap: () => HapticFeedback.selectionClick(),
                  ),
                  const SizedBox(width: 8),
                  _HeroIconButton(
                    icon: CupertinoIcons.settings,
                    onTap: () => HapticFeedback.selectionClick(),
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
                              color: primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: PravaColors.accentPrimary,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              profile.liveBadge,
                              style: PravaTypography.caption.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
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
                    color: secondary,
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

class _HeroIconButton extends StatelessWidget {
  const _HeroIconButton({
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
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
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

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({
    required this.profile,
    required this.isDark,
    required this.primary,
    required this.secondary,
    required this.surface,
    required this.border,
    required this.following,
    required this.onFollow,
  });

  final ProfileViewModel profile;
  final bool isDark;
  final Color primary;
  final Color secondary;
  final Color surface;
  final Color border;
  final bool following;
  final VoidCallback onFollow;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ProfileAvatar(
                initials: profile.initials,
                accent: PravaColors.accentPrimary,
                isOnline: profile.online,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            profile.displayName,
                            overflow: TextOverflow.ellipsis,
                            style: PravaTypography.h2.copyWith(
                              color: primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (profile.verified)
                          Icon(
                            CupertinoIcons.check_mark_circled_solid,
                            color: PravaColors.accentPrimary,
                            size: 18,
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '@${profile.username}',
                      style: PravaTypography.bodySmall.copyWith(
                        color: secondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _BadgeChip(
                          icon: CupertinoIcons.star_fill,
                          label: profile.tierLabel,
                          color: PravaColors.accentPrimary,
                        ),
                        _BadgeChip(
                          icon: CupertinoIcons.shield_lefthalf_fill,
                          label: 'Secure verified',
                          color: PravaColors.success,
                        ),
                        _BadgeChip(
                          icon: CupertinoIcons.sparkles,
                          label: profile.activityTag,
                          color: PravaColors.warning,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            profile.bio,
            style: PravaTypography.body.copyWith(
              color: primary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _FollowButton(
                  following: following,
                  onTap: onFollow,
                ),
              ),
              const SizedBox(width: 10),
              _SquareActionButton(
                icon: CupertinoIcons.chat_bubble_2_fill,
                onTap: () => HapticFeedback.selectionClick(),
              ),
              const SizedBox(width: 10),
              _SquareActionButton(
                icon: CupertinoIcons.video_camera_solid,
                onTap: () => HapticFeedback.selectionClick(),
              ),
            ],
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
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: CircleAvatar(
            radius: 30,
            backgroundColor: accent.withValues(alpha: 0.12),
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
            bottom: 2,
            right: 2,
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

class _BadgeChip extends StatelessWidget {
  const _BadgeChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
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
    );
  }
}

class _FollowButton extends StatelessWidget {
  const _FollowButton({
    required this.following,
    required this.onTap,
  });

  final bool following;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final border = Theme.of(context).brightness == Brightness.dark
        ? PravaColors.darkBorderSubtle
        : PravaColors.lightBorderSubtle;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          gradient: following
              ? null
              : LinearGradient(
                  colors: [
                    PravaColors.accentPrimary,
                    PravaColors.accentMuted,
                  ],
                ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: following ? border : Colors.transparent,
          ),
          color: following ? Colors.transparent : null,
          boxShadow: following
              ? []
              : [
                  BoxShadow(
                    color: PravaColors.accentPrimary.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
        ),
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              following ? 'Following' : 'Follow',
              key: ValueKey(following),
              style: PravaTypography.button.copyWith(
                color: following ? border : Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SquareActionButton extends StatelessWidget {
  const _SquareActionButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark ? Colors.white10 : Colors.black12;
    final color =
        isDark ? PravaColors.darkTextPrimary : PravaColors.lightTextPrimary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 46,
        width: 46,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(icon, color: color, size: 20),
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
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
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
                      style: PravaTypography.caption.copyWith(
                        color: secondary,
                      ),
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

class _PremiumPanel extends StatelessWidget {
  const _PremiumPanel({
    required this.profile,
    required this.isDark,
    required this.primary,
    required this.secondary,
  });

  final ProfileViewModel profile;
  final bool isDark;
  final Color primary;
  final Color secondary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: [
            PravaColors.accentPrimary.withValues(alpha: isDark ? 0.2 : 0.28),
            PravaColors.accentMuted.withValues(alpha: isDark ? 0.14 : 0.24),
            Colors.transparent,
          ],
        ),
        border: Border.all(
          color: PravaColors.accentPrimary.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: PravaColors.accentPrimary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              CupertinoIcons.star_circle_fill,
              color: PravaColors.accentPrimary,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.premiumHeadline,
                  style: PravaTypography.body.copyWith(
                    color: primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  profile.premiumSubhead,
                  style: PravaTypography.bodySmall.copyWith(
                    color: secondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            profile.premiumCta,
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

class _HighlightRow extends StatelessWidget {
  const _HighlightRow({
    required this.highlights,
    required this.primary,
  });

  final List<ProfileHighlight> highlights;
  final Color primary;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Highlights',
          style: PravaTypography.h3.copyWith(color: primary),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 110,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: highlights.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              return _HighlightCard(
                highlight: highlights[index],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _HighlightCard extends StatelessWidget {
  const _HighlightCard({
    required this.highlight,
  });

  final ProfileHighlight highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 168,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: highlight.gradient,
        ),
        boxShadow: [
          BoxShadow(
            color: highlight.gradient.first.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(highlight.icon, color: Colors.white, size: 20),
          const Spacer(),
          Text(
            highlight.title,
            style: PravaTypography.body.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            highlight.subtitle,
            style: PravaTypography.caption.copyWith(
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            highlight.tag,
            style: PravaTypography.caption.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutCard extends StatelessWidget {
  const _AboutCard({
    required this.profile,
    required this.isDark,
    required this.primary,
    required this.secondary,
    required this.surface,
    required this.border,
  });

  final ProfileViewModel profile;
  final bool isDark;
  final Color primary;
  final Color secondary;
  final Color surface;
  final Color border;

  @override
  Widget build(BuildContext context) {
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
          Row(
            children: [
              Text(
                'About',
                style: PravaTypography.h3.copyWith(color: primary),
              ),
              const Spacer(),
              Text(
                profile.joined,
                style: PravaTypography.caption.copyWith(color: secondary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _AboutRow(
            icon: CupertinoIcons.briefcase_fill,
            label: profile.work,
            primary: primary,
            secondary: secondary,
          ),
          const SizedBox(height: 10),
          _AboutRow(
            icon: CupertinoIcons.location_solid,
            label: profile.location,
            primary: primary,
            secondary: secondary,
          ),
          const SizedBox(height: 10),
          _AboutRow(
            icon: CupertinoIcons.link,
            label: profile.website,
            primary: primary,
            secondary: secondary,
          ),
          const SizedBox(height: 10),
          _AboutRow(
            icon: CupertinoIcons.heart_fill,
            label: profile.values,
            primary: primary,
            secondary: secondary,
          ),
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

class _FriendsRow extends StatelessWidget {
  const _FriendsRow({
    required this.friends,
    required this.isDark,
    required this.primary,
    required this.secondary,
  });

  final List<ProfileFriend> friends;
  final bool isDark;
  final Color primary;
  final Color secondary;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Inner circle',
              style: PravaTypography.h3.copyWith(color: primary),
            ),
            const Spacer(),
            Text(
              'See all',
              style: PravaTypography.caption.copyWith(
                color: PravaColors.accentPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 72,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: friends.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              return _FriendChip(
                friend: friends[index],
                isDark: isDark,
                secondary: secondary,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FriendChip extends StatelessWidget {
  const _FriendChip({
    required this.friend,
    required this.isDark,
    required this.secondary,
  });

  final ProfileFriend friend;
  final bool isDark;
  final Color secondary;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : Colors.black12,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: PravaColors.accentPrimary.withValues(alpha: 0.2),
            child: Text(
              friend.initials,
              style: PravaTypography.caption.copyWith(
                color: PravaColors.accentPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            friend.name,
            overflow: TextOverflow.ellipsis,
            style: PravaTypography.caption.copyWith(
              color: secondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileSegmentedControl extends StatelessWidget {
  const _ProfileSegmentedControl({
    required this.value,
    required this.onChanged,
    required this.secondary,
    required this.surface,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final Color secondary;
  final Color surface;

  @override
  Widget build(BuildContext context) {
    return CupertinoSlidingSegmentedControl<int>(
      groupValue: value,
      backgroundColor: surface,
      thumbColor: PravaColors.accentPrimary,
      children: {
        0: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'Posts',
            style: PravaTypography.label.copyWith(
              color: value == 0 ? Colors.white : secondary,
            ),
          ),
        ),
        1: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'Media',
            style: PravaTypography.label.copyWith(
              color: value == 1 ? Colors.white : secondary,
            ),
          ),
        ),
        2: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'Likes',
            style: PravaTypography.label.copyWith(
              color: value == 2 ? Colors.white : secondary,
            ),
          ),
        ),
      },
      onValueChanged: (next) {
        if (next == null) return;
        onChanged(next);
      },
    );
  }
}

class _ProfilePostCard extends StatelessWidget {
  const _ProfilePostCard({
    required this.post,
    required this.isDark,
    required this.primary,
    required this.secondary,
    required this.border,
    this.liked = false,
  });

  final ProfilePost post;
  final bool isDark;
  final Color primary;
  final Color secondary;
  final Color border;
  final bool liked;

  @override
  Widget build(BuildContext context) {
    final accent = liked ? PravaColors.accentPrimary : secondary;

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
              if (post.pinned)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: PravaColors.accentPrimary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        CupertinoIcons.pin_fill,
                        size: 12,
                        color: PravaColors.accentPrimary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Pinned',
                        style: PravaTypography.caption.copyWith(
                          color: PravaColors.accentPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              const Spacer(),
              Text(
                post.timestamp,
                style: PravaTypography.caption.copyWith(color: secondary),
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
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _PostAction(
                icon: liked
                    ? CupertinoIcons.heart_fill
                    : CupertinoIcons.heart,
                label: post.likes,
                color: accent,
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

class _MediaTile extends StatelessWidget {
  const _MediaTile({
    required this.media,
    required this.isDark,
  });

  final ProfileMedia media;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: media.gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Align(
        alignment: Alignment.bottomLeft,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Text(
            media.label,
            style: PravaTypography.caption.copyWith(
              color: Colors.white.withValues(alpha: isDark ? 0.8 : 0.95),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class ProfileViewModel {
  ProfileViewModel({
    required this.displayName,
    required this.username,
    required this.initials,
    required this.bio,
    required this.statusLine,
    required this.liveBadge,
    required this.coverCaption,
    required this.tierLabel,
    required this.activityTag,
    required this.online,
    required this.verified,
    required this.stats,
    required this.work,
    required this.location,
    required this.website,
    required this.values,
    required this.joined,
    required this.interests,
    required this.highlights,
    required this.mutuals,
    required this.posts,
    required this.media,
    required this.liked,
    required this.premiumHeadline,
    required this.premiumSubhead,
    required this.premiumCta,
  });

  final String displayName;
  final String username;
  final String initials;
  final String bio;
  final String statusLine;
  final String liveBadge;
  final String coverCaption;
  final String tierLabel;
  final String activityTag;
  final bool online;
  final bool verified;
  final List<ProfileStat> stats;
  final String work;
  final String location;
  final String website;
  final String values;
  final String joined;
  final List<String> interests;
  final List<ProfileHighlight> highlights;
  final List<ProfileFriend> mutuals;
  final List<ProfilePost> posts;
  final List<ProfileMedia> media;
  final List<ProfilePost> liked;
  final String premiumHeadline;
  final String premiumSubhead;
  final String premiumCta;

  factory ProfileViewModel.sample() {
    return ProfileViewModel(
      displayName: 'Himan Barman',
      username: 'himan.prava',
      initials: 'HB',
      bio:
          'Founder of Prava. Building a premium realtime social layer for the new internet.',
      statusLine: 'Active now on Prava',
      liveBadge: 'LIVE',
      coverCaption: 'Prava Creator Lab',
      tierLabel: 'Prava Plus',
      activityTag: 'Top 1% Creator',
      online: true,
      verified: true,
      stats: [
        ProfileStat(label: 'Posts', value: '428'),
        ProfileStat(label: 'Followers', value: '1.2M'),
        ProfileStat(label: 'Following', value: '312'),
        ProfileStat(label: 'Likes', value: '9.8M'),
      ],
      work: 'CEO at Prava Technologies',
      location: 'Bangalore, IN',
      website: 'prava.app',
      values: 'Secure messaging, realtime communities, creator-first',
      joined: 'Joined 2024',
      interests: [
        'Realtime systems',
        'Design systems',
        'Security',
        'AI',
        'Social graphs',
      ],
      highlights: [
        ProfileHighlight(
          title: 'Creator Studio',
          subtitle: 'Pinned drops',
          tag: 'New',
          icon: CupertinoIcons.bolt_fill,
          gradient: [
            const Color(0xFF4A6FFF),
            const Color(0xFF8FB2FF),
          ],
        ),
        ProfileHighlight(
          title: 'Daily Sparks',
          subtitle: 'Micro-posts',
          tag: '120Hz',
          icon: CupertinoIcons.sparkles,
          gradient: [
            const Color(0xFF1A1A1A),
            const Color(0xFF3A3A3A),
          ],
        ),
        ProfileHighlight(
          title: 'Communities',
          subtitle: 'Private groups',
          tag: 'Invite',
          icon: CupertinoIcons.person_2_fill,
          gradient: [
            const Color(0xFF0E9F6E),
            const Color(0xFF4ADFA8),
          ],
        ),
      ],
      mutuals: [
        ProfileFriend(name: 'Aarav', initials: 'AR'),
        ProfileFriend(name: 'Meera', initials: 'MP'),
        ProfileFriend(name: 'Ishan', initials: 'IS'),
        ProfileFriend(name: 'Riya', initials: 'RK'),
      ],
      posts: [
        ProfilePost(
          body:
              'Designing a feed that feels like silk. Premium motion, realtime presence, zero lag.',
          timestamp: '2h',
          likes: '18.2k',
          comments: '1.4k',
          shares: '402',
          pinned: true,
          tags: ['#product', '#ux', '#realtime'],
        ),
        ProfilePost(
          body:
              'Prava chat engine now handles multi-device receipts and presence with ease.',
          timestamp: '1d',
          likes: '9.7k',
          comments: '860',
          shares: '212',
          tags: ['#engineering', '#security'],
        ),
        ProfilePost(
          body:
              'Creator tools are coming next: premium profiles, paid rooms, and live drops.',
          timestamp: '4d',
          likes: '7.1k',
          comments: '602',
          shares: '190',
          tags: ['#creator', '#community'],
        ),
      ],
      liked: [
        ProfilePost(
          body:
              'Realtime reactions on Prava feel instant. Love the new interaction model.',
          timestamp: '5d',
          likes: '4.1k',
          comments: '260',
          shares: '96',
          tags: ['#feedback', '#design'],
        ),
        ProfilePost(
          body:
              'Privacy-first social graph is the future. Prava is ahead.',
          timestamp: '1w',
          likes: '12.4k',
          comments: '1.1k',
          shares: '322',
          tags: ['#privacy', '#trust'],
        ),
      ],
      media: [
        ProfileMedia(
          label: 'Launch',
          gradient: [
            const Color(0xFF5B8CFF),
            const Color(0xFF9BB8FF),
          ],
        ),
        ProfileMedia(
          label: 'Studio',
          gradient: [
            const Color(0xFF111827),
            const Color(0xFF374151),
          ],
        ),
        ProfileMedia(
          label: 'Team',
          gradient: [
            const Color(0xFF059669),
            const Color(0xFF34D399),
          ],
        ),
        ProfileMedia(
          label: 'Events',
          gradient: [
            const Color(0xFFB45309),
            const Color(0xFFF59E0B),
          ],
        ),
        ProfileMedia(
          label: 'Labs',
          gradient: [
            const Color(0xFF7C3AED),
            const Color(0xFFBFA5FF),
          ],
        ),
        ProfileMedia(
          label: 'Moments',
          gradient: [
            const Color(0xFF0F766E),
            const Color(0xFF5EEAD4),
          ],
        ),
      ],
      premiumHeadline: 'Prava Plus Creator',
      premiumSubhead:
          'Unlock premium rooms, revenue tools, and realtime analytics.',
      premiumCta: 'Manage',
    );
  }
}

class ProfileStat {
  ProfileStat({required this.label, required this.value});

  final String label;
  final String value;
}

class ProfileHighlight {
  ProfileHighlight({
    required this.title,
    required this.subtitle,
    required this.tag,
    required this.icon,
    required this.gradient,
  });

  final String title;
  final String subtitle;
  final String tag;
  final IconData icon;
  final List<Color> gradient;
}

class ProfileFriend {
  ProfileFriend({required this.name, required this.initials});

  final String name;
  final String initials;
}

class ProfilePost {
  ProfilePost({
    required this.body,
    required this.timestamp,
    required this.likes,
    required this.comments,
    required this.shares,
    this.tags = const [],
    this.pinned = false,
  });

  final String body;
  final String timestamp;
  final String likes;
  final String comments;
  final String shares;
  final List<String> tags;
  final bool pinned;
}

class ProfileMedia {
  ProfileMedia({
    required this.label,
    required this.gradient,
  });

  final String label;
  final List<Color> gradient;
}
