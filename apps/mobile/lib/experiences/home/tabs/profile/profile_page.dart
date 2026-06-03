import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../services/profile_service.dart';
import '../../../../services/profile_visibility.dart';
import '../../../../ui-system/colors.dart';
import '../../../../ui-system/feedback/prava_toast.dart';
import '../../../../ui-system/feedback/toast_type.dart';
import '../../../../ui-system/skeleton/profile_skeleton.dart';
import '../../../../ui-system/typography.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final ProfileService _profileService = ProfileService();

  ProfileSummary? _profile;
  ProfileVisibility? _visibility;
  bool _loading = true;
  bool _savingVisibility = false;
  int _segmentIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _loading = true);
    try {
      final profile = await _profileService.fetchMyProfile(limit: 24);
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _visibility = profile.visibility;
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

  Future<void> _chooseVisibility(String key) async {
    final current = _visibility ?? ProfileVisibility.defaultsForOwner();
    HapticFeedback.selectionClick();
    final next = await showCupertinoModalPopup<String>(
      context: context,
      builder: (context) {
        return CupertinoActionSheet(
          title: Text('Who can see ${ProfileVisibility.fieldLabel(key)}?'),
          actions: ProfileVisibility.levels
              .map(
                (level) => CupertinoActionSheetAction(
                  onPressed: () => Navigator.of(context).pop(level),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(ProfileVisibility.levelLabel(level)),
                      if (current.levelFor(key) == level) ...[
                        const SizedBox(width: 8),
                        const Icon(
                          CupertinoIcons.check_mark,
                          size: 16,
                          color: PravaColors.accentPrimary,
                        ),
                      ],
                    ],
                  ),
                ),
              )
              .toList(),
          cancelButton: CupertinoActionSheetAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        );
      },
    );

    if (next == null || next == current.levelFor(key)) return;
    await _saveVisibility(current.copyWithField(key, next));
  }

  Future<void> _saveVisibility(ProfileVisibility next) async {
    final previous = _visibility;
    setState(() {
      _visibility = next;
      _savingVisibility = true;
    });

    try {
      final saved = await _profileService.saveProfileVisibility(next);
      if (!mounted) return;
      setState(() {
        _visibility = saved;
        _savingVisibility = false;
      });
      PravaToast.show(
        context,
        message: 'Profile privacy updated',
        type: PravaToastType.success,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _visibility = previous;
        _savingVisibility = false;
      });
      PravaToast.show(
        context,
        message: 'Unable to update privacy',
        type: PravaToastType.error,
      );
    }
  }

  void _setSegment(int index) {
    if (_segmentIndex == index) return;
    HapticFeedback.selectionClick();
    setState(() => _segmentIndex = index);
  }

  String _displayName(ProfileUser user) {
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

  List<_ProfileStat> _stats(ProfileStats stats) {
    return [
      _ProfileStat(label: 'Posts', value: _formatCount(stats.posts)),
      _ProfileStat(label: 'Followers', value: _formatCount(stats.followers)),
      _ProfileStat(label: 'Following', value: _formatCount(stats.following)),
      _ProfileStat(label: 'Likes', value: _formatCount(stats.likes)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const ProfileSkeleton();

    final profile = _profile;
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

    if (profile == null) {
      return _ProfileErrorState(
        primary: primary,
        secondary: secondary,
        onRetry: _loadProfile,
      );
    }

    final user = profile.user;
    final displayName = _displayName(user);
    final visibility = _visibility ?? profile.visibility;
    final activePosts = _segmentIndex == 0 ? profile.posts : profile.liked;

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
              child: _OwnProfileHeader(
                displayName: displayName,
                username: user.username,
                initials: _initials(displayName),
                bio: user.bio,
                verified: user.isVerified,
                privateAccount: visibility.privateAccount,
                primary: primary,
                secondary: secondary,
                surface: elevated,
                border: border,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: _StatGrid(
                stats: _stats(profile.stats),
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
                location: user.location,
                website: user.website,
                joined: _formatJoined(user.createdAt),
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
              child: _PrivacyCard(
                visibility: visibility,
                saving: _savingVisibility,
                primary: primary,
                secondary: secondary,
                surface: surface,
                border: border,
                onChange: _chooseVisibility,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: _ProfileSegments(
                value: _segmentIndex,
                onChanged: _setSegment,
                surface: surface,
                secondary: secondary,
              ),
            ),
          ),
          if (activePosts.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: _EmptyState(
                  title: _segmentIndex == 0 ? 'No posts yet' : 'No liked posts',
                  subtitle: _segmentIndex == 0
                      ? 'Posts you publish will appear here.'
                      : 'Posts you like will appear here.',
                  primary: primary,
                  secondary: secondary,
                  surface: surface,
                  border: border,
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverList.builder(
                itemCount: activePosts.isEmpty ? 0 : activePosts.length * 2 - 1,
                itemBuilder: (context, index) {
                  if (index.isOdd) return const SizedBox(height: 12);
                  final postIndex = index ~/ 2;
                  final post = activePosts[postIndex];
                  return _PostCard(
                    post: post,
                    timestamp: _formatRelativeTime(post.createdAt),
                    primary: primary,
                    secondary: secondary,
                    surface: elevated,
                    border: border,
                    liked: _segmentIndex == 1,
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

class _OwnProfileHeader extends StatelessWidget {
  const _OwnProfileHeader({
    required this.displayName,
    required this.username,
    required this.initials,
    required this.bio,
    required this.verified,
    required this.privateAccount,
    required this.primary,
    required this.secondary,
    required this.surface,
    required this.border,
  });

  final String displayName;
  final String username;
  final String initials;
  final String bio;
  final bool verified;
  final bool privateAccount;
  final Color primary;
  final Color secondary;
  final Color surface;
  final Color border;

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
                  ],
                ),
              ),
              if (privateAccount)
                _PrivacyPill(
                  label: 'Private',
                  icon: CupertinoIcons.lock_fill,
                  color: secondary,
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            bio.trim().isEmpty ? 'No bio added yet.' : bio.trim(),
            style: PravaTypography.body.copyWith(color: primary),
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

class _StatGrid extends StatelessWidget {
  const _StatGrid({
    required this.stats,
    required this.primary,
    required this.secondary,
    required this.surface,
    required this.border,
  });

  final List<_ProfileStat> stats;
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

class _AboutCard extends StatelessWidget {
  const _AboutCard({
    required this.location,
    required this.website,
    required this.joined,
    required this.primary,
    required this.secondary,
    required this.surface,
    required this.border,
  });

  final String location;
  final String website;
  final String joined;
  final Color primary;
  final Color secondary;
  final Color surface;
  final Color border;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    void add(IconData icon, String label) {
      if (label.trim().isEmpty) return;
      rows.add(_DetailRow(icon: icon, label: label, primary: primary, secondary: secondary));
      rows.add(const SizedBox(height: 10));
    }

    add(CupertinoIcons.location_solid, location);
    add(CupertinoIcons.link, website);
    add(CupertinoIcons.calendar, joined);
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
            'Personal Profile',
            style: PravaTypography.h3.copyWith(
              color: primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          if (rows.isEmpty)
            Text(
              'No profile details added yet.',
              style: PravaTypography.bodySmall.copyWith(color: secondary),
            )
          else
            ...rows,
        ],
      ),
    );
  }
}

class _PrivacyCard extends StatelessWidget {
  const _PrivacyCard({
    required this.visibility,
    required this.saving,
    required this.primary,
    required this.secondary,
    required this.surface,
    required this.border,
    required this.onChange,
  });

  final ProfileVisibility visibility;
  final bool saving;
  final Color primary;
  final Color secondary;
  final Color surface;
  final Color border;
  final ValueChanged<String> onChange;

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
                'Public Profile Privacy',
                style: PravaTypography.h3.copyWith(
                  color: primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (saving) const CupertinoActivityIndicator(radius: 8),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Choose who can see each detail on your public profile.',
            style: PravaTypography.bodySmall.copyWith(color: secondary),
          ),
          const SizedBox(height: 12),
          for (final key in ProfileVisibility.fieldKeys)
            _VisibilityRow(
              keyName: key,
              level: visibility.levelFor(key),
              primary: primary,
              secondary: secondary,
              onTap: () => onChange(key),
            ),
        ],
      ),
    );
  }
}

class _VisibilityRow extends StatelessWidget {
  const _VisibilityRow({
    required this.keyName,
    required this.level,
    required this.primary,
    required this.secondary,
    required this.onTap,
  });

  final String keyName;
  final String level;
  final Color primary;
  final Color secondary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              ProfileVisibility.fieldLabel(keyName),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: PravaTypography.body.copyWith(
                color: primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: onTap,
            child: Container(
              constraints: const BoxConstraints(minWidth: 108),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: PravaColors.accentPrimary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    ProfileVisibility.levelLabel(level),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PravaTypography.caption.copyWith(
                      color: PravaColors.accentPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 5),
                  const Icon(
                    CupertinoIcons.chevron_down,
                    size: 12,
                    color: PravaColors.accentPrimary,
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

class _ProfileSegments extends StatelessWidget {
  const _ProfileSegments({
    required this.value,
    required this.onChanged,
    required this.surface,
    required this.secondary,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final Color surface;
  final Color secondary;

  @override
  Widget build(BuildContext context) {
    return CupertinoSlidingSegmentedControl<int>(
      groupValue: value,
      backgroundColor: surface,
      thumbColor: PravaColors.accentPrimary,
      children: {
        0: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Text(
            'Posts',
            style: PravaTypography.label.copyWith(
              color: value == 0 ? Colors.white : secondary,
            ),
          ),
        ),
        1: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Text(
            'Likes',
            style: PravaTypography.label.copyWith(
              color: value == 1 ? Colors.white : secondary,
            ),
          ),
        ),
      },
      onValueChanged: (next) {
        if (next != null) onChanged(next);
      },
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({
    required this.post,
    required this.timestamp,
    required this.primary,
    required this.secondary,
    required this.surface,
    required this.border,
    required this.liked,
    required this.formatCount,
  });

  final ProfileFeedPost post;
  final String timestamp;
  final Color primary;
  final Color secondary;
  final Color surface;
  final Color border;
  final bool liked;
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
          Row(
            children: [
              if (liked)
                const Icon(
                  CupertinoIcons.heart_fill,
                  size: 14,
                  color: PravaColors.accentPrimary,
                ),
              if (liked) const SizedBox(width: 6),
              Text(
                timestamp,
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

class _PrivacyPill extends StatelessWidget {
  const _PrivacyPill({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: PravaTypography.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.title,
    required this.subtitle,
    required this.primary,
    required this.secondary,
    required this.surface,
    required this.border,
  });

  final String title;
  final String subtitle;
  final Color primary;
  final Color secondary;
  final Color surface;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
            style: PravaTypography.bodySmall.copyWith(color: secondary),
          ),
        ],
      ),
    );
  }
}

class _ProfileErrorState extends StatelessWidget {
  const _ProfileErrorState({
    required this.primary,
    required this.secondary,
    required this.onRetry,
  });

  final Color primary;
  final Color secondary;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
              'Refresh to try loading your profile again.',
              textAlign: TextAlign.center,
              style: PravaTypography.bodySmall.copyWith(color: secondary),
            ),
            const SizedBox(height: 14),
            CupertinoButton(
              color: PravaColors.accentPrimary,
              onPressed: onRetry,
              child: const Text('Refresh'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileStat {
  const _ProfileStat({required this.label, required this.value});

  final String label;
  final String value;
}
