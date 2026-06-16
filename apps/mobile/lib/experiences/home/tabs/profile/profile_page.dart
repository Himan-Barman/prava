import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as image_lib;
import 'package:image_picker/image_picker.dart';

import '../../../../services/account_service.dart';
import '../../../../services/location_suggestion_service.dart';
import '../../../../services/media_service.dart';
import '../../../../services/profile_service.dart';
import '../../../../services/profile_visibility.dart';
import '../../../../ui-system/colors.dart';
import '../../../../ui-system/feedback/prava_toast.dart';
import '../../../../ui-system/feedback/toast_type.dart';
import '../../../../ui-system/components/prava_input.dart';
import '../../../../ui-system/skeleton/profile_skeleton.dart';
import '../../../../ui-system/typography.dart';
import '../../../../navigation/prava_navigator.dart';
import '../../pages/post_detail_page.dart';
import 'profile_content_pages.dart';
import 'public_profile_page.dart';

class ProfilePageController {
  VoidCallback? _openEditor;
  bool _pendingOpen = false;

  void openEditor() {
    final openEditor = _openEditor;
    if (openEditor == null) {
      _pendingOpen = true;
      return;
    }
    openEditor();
  }

  void _bind(VoidCallback openEditor) {
    _openEditor = openEditor;
    if (_pendingOpen) {
      _pendingOpen = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openEditor?.call();
      });
    }
  }

  void _unbind() {
    _openEditor = null;
  }
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, this.controller});

  final ProfilePageController? controller;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final ProfileService _profileService = ProfileService();

  ProfileSummary? _profile;
  bool _loading = true;
  _ProfileContentTab _contentTab = _ProfileContentTab.all;
  final Set<String> _collapsedSections = {};

  @override
  void initState() {
    super.initState();
    _bindController(widget.controller);
    _loadProfile();
  }

  @override
  void didUpdateWidget(covariant ProfilePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._unbind();
      _bindController(widget.controller);
    }
  }

  @override
  void dispose() {
    widget.controller?._unbind();
    super.dispose();
  }

  void _bindController(ProfilePageController? controller) {
    controller?._bind(_openEditProfile);
  }

  Future<void> _loadProfile() async {
    setState(() => _loading = true);
    try {
      final profile = await _profileService.fetchMyProfile(limit: 50);
      if (!mounted) return;
      setState(() {
        _profile = profile;
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

  Future<void> _openEditProfile() async {
    HapticFeedback.selectionClick();
    final changed = await Navigator.of(context, rootNavigator: true).push<bool>(
      PravaNavigator.route(const _ProfileEditPage(), fullscreenDialog: true),
    );
    if (changed == true) {
      _loadProfile();
    }
  }

  String _displayName(ProfileUser user) {
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

  ProfilePostContentItem _contentItem(ProfileFeedPost post) {
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

  void _openPostsPage({
    required String title,
    required List<ProfileFeedPost> posts,
    required String emptyTitle,
    required String emptySubtitle,
  }) {
    HapticFeedback.selectionClick();
    Navigator.of(context, rootNavigator: true).push(
      PravaNavigator.route(
        ProfilePostListPage(
          title: title,
          posts: posts.map(_contentItem).toList(),
          emptyTitle: emptyTitle,
          emptySubtitle: emptySubtitle,
        ),
        fullscreenDialog: true,
      ),
    );
  }

  void _openConnections(String userId, ProfileConnectionKind kind) {
    HapticFeedback.selectionClick();
    Navigator.of(context, rootNavigator: true).push(
      PravaNavigator.route(
        ProfileConnectionsPage(
          userId: userId,
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

  void _openPostDetail(ProfileFeedPost post) {
    if (post.id.trim().isEmpty) return;
    HapticFeedback.selectionClick();
    PravaNavigator.push(context, PostDetailPage(postId: post.id));
  }

  Future<void> _openProfilePreview(String mode) async {
    HapticFeedback.selectionClick();
    try {
      final preview = await _profileService.fetchProfilePreview(
        mode,
        limit: 24,
      );
      if (!mounted) return;
      await Navigator.of(context, rootNavigator: true).push(
        PravaNavigator.route(
          _ProfilePreviewPage(profile: preview, mode: mode),
          fullscreenDialog: true,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      PravaToast.show(
        context,
        message: 'Unable to open profile preview',
        type: PravaToastType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const ProfileSkeleton();

    final tokens = context.pravaColors;
    final primary = tokens.textPrimary;
    final secondary = tokens.textSecondary;
    final border = tokens.borderSubtle;
    final profile = _profile;

    if (profile == null) {
      return _ProfileErrorState(
        primary: primary,
        secondary: secondary,
        onRetry: _loadProfile,
      );
    }

    final user = profile.user;
    final displayName = _displayName(user);

    return RefreshIndicator(
      color: tokens.brandPrimary,
      onRefresh: _loadProfile,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          SliverToBoxAdapter(
            child: _ProfileHero(
              displayName: displayName,
              username: user.username,
              initials: _initials(displayName),
              avatarUrl: user.avatarUrl,
              coverUrl: user.coverUrl,
              verified: user.isVerified,
              posts: _formatCount(profile.stats.posts),
              followers: _formatCount(profile.stats.followers),
              following: _formatCount(profile.stats.following),
              primary: primary,
              secondary: secondary,
              border: border,
              onPostsTap: () => _openPostsPage(
                title: 'Posts',
                posts: profile.posts,
                emptyTitle: 'No posts yet',
                emptySubtitle:
                    'Text and emoji posts from your feed will show here.',
              ),
              onFollowersTap: () =>
                  _openConnections(user.id, ProfileConnectionKind.followers),
              onFollowingTap: () =>
                  _openConnections(user.id, ProfileConnectionKind.following),
            ),
          ),
          SliverToBoxAdapter(
            child: _OwnerProfileCommandCenter(
              tools: profile.ownerTools,
              stats: profile.stats,
              primary: primary,
              secondary: secondary,
              border: border,
              onPreviewAs: _openProfilePreview,
            ),
          ),
          SliverToBoxAdapter(
            child: _ProfileTabBar(
              value: _contentTab,
              primary: primary,
              secondary: secondary,
              border: border,
              onChanged: (value) {
                if (_contentTab == value) return;
                HapticFeedback.selectionClick();
                setState(() => _contentTab = value);
              },
            ),
          ),
          if (_contentTab == _ProfileContentTab.all) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: _ProfileSection(
                  title: 'Category',
                  primary: primary,
                  collapsed: _collapsedSections.contains('category'),
                  onToggle: () => _toggleSection('category'),
                  children: [
                    _ProfileInfoRow(
                      icon: Icons.category_rounded,
                      title: user.category.trim().isEmpty
                          ? 'Creator'
                          : user.category.trim(),
                      value: '',
                      primary: primary,
                      secondary: secondary,
                    ),
                    _ProfileInfoRow(
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
                child: _ProfileSection(
                  title: 'Personal details',
                  primary: primary,
                  collapsed: _collapsedSections.contains('personal'),
                  onToggle: () => _toggleSection('personal'),
                  children: [
                    _ProfileInfoRow(
                      icon: CupertinoIcons.location,
                      title: user.location.trim().isEmpty
                          ? 'Location'
                          : user.location.trim(),
                      value: user.location.trim().isEmpty ? '-' : '',
                      primary: primary,
                      secondary: secondary,
                    ),
                    _ProfileInfoRow(
                      icon: CupertinoIcons.house,
                      title: user.hometown.trim().isEmpty
                          ? 'Hometown'
                          : user.hometown.trim(),
                      value: user.hometown.trim().isEmpty ? '-' : '',
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
                child: _ProfileSection(
                  title: 'Links',
                  primary: primary,
                  collapsed: _collapsedSections.contains('links'),
                  onToggle: () => _toggleSection('links'),
                  children: [
                    _ProfileInfoRow(
                      icon: CupertinoIcons.link,
                      title: user.website.trim().isEmpty
                          ? 'Website'
                          : user.website.trim(),
                      value: user.website.trim().isEmpty ? '-' : '',
                      primary: primary,
                      secondary: secondary,
                    ),
                  ],
                ),
              ),
            ),
          ] else if (_contentTab == _ProfileContentTab.mentions)
            SliverToBoxAdapter(
              child: _ProfilePostsList(
                posts: profile.mentionedPosts,
                primary: primary,
                secondary: secondary,
                border: border,
                emptyTitle: 'No mention posts yet',
                emptySubtitle: 'Posts that mention you will show here.',
                onPostTap: _openPostDetail,
              ),
            )
          else
            SliverToBoxAdapter(
              child: _ProfilePostsList(
                posts: profile.posts,
                primary: primary,
                secondary: secondary,
                border: border,
                emptyTitle: 'No posts yet',
                emptySubtitle:
                    'Text and emoji posts from your feed will show here.',
                onPostTap: _openPostDetail,
              ),
            ),
        ],
      ),
    );
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
}

enum _ProfileContentTab { all, mentions, posts }

class _ProfilePreviewPage extends StatelessWidget {
  const _ProfilePreviewPage({required this.profile, required this.mode});

  final ProfileSummary profile;
  final String mode;

  String _displayName(ProfileUser user) {
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

  String _modeLabel() {
    switch (mode) {
      case 'closeFriend':
        return 'Close friend preview';
      case 'friend':
        return 'Friend preview';
      case 'follower':
        return 'Follower preview';
      default:
        return 'Public preview';
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.pravaColors;
    final primary = tokens.textPrimary;
    final secondary = tokens.textSecondary;
    final border = tokens.borderSubtle;
    final user = profile.user;
    final displayName = _displayName(user);
    final privatePreview = profile.profileState == 'private';

    return Scaffold(
      backgroundColor: tokens.backgroundCanvas,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _modeLabel(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: PravaTypography.titleSmall.copyWith(
                          color: primary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => Navigator.of(context).pop(),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        child: Text(
                          'Done',
                          style: PravaTypography.buttonMedium.copyWith(
                            color: tokens.brandPrimary,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: _ProfilePreviewHero(
                displayName: displayName,
                username: user.username,
                initials: _initials(displayName),
                avatarUrl: user.avatarUrl,
                coverUrl: user.coverUrl,
                bio: user.bio,
                verified: user.isVerified,
                modeLabel: _modeLabel(),
                posts: _formatCount(profile.stats.posts),
                followers: _formatCount(profile.stats.followers),
                following: _formatCount(profile.stats.following),
                primary: primary,
                secondary: secondary,
                border: border,
              ),
            ),
            if (privatePreview)
              SliverToBoxAdapter(
                child: _ProfilePreviewLockCard(
                  primary: primary,
                  secondary: secondary,
                  border: border,
                ),
              )
            else
              SliverToBoxAdapter(
                child: _ProfilePostsList(
                  posts: profile.posts,
                  primary: primary,
                  secondary: secondary,
                  border: border,
                  emptyTitle: 'No visible posts',
                  emptySubtitle:
                      'Posts visible to this audience will appear here.',
                  onPostTap: (post) {
                    if (post.id.trim().isEmpty) return;
                    PravaNavigator.push(
                      context,
                      PostDetailPage(postId: post.id),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ProfilePreviewHero extends StatelessWidget {
  const _ProfilePreviewHero({
    required this.displayName,
    required this.username,
    required this.initials,
    required this.avatarUrl,
    required this.coverUrl,
    required this.bio,
    required this.verified,
    required this.modeLabel,
    required this.posts,
    required this.followers,
    required this.following,
    required this.primary,
    required this.secondary,
    required this.border,
  });

  final String displayName;
  final String username;
  final String initials;
  final String avatarUrl;
  final String coverUrl;
  final String bio;
  final bool verified;
  final String modeLabel;
  final String posts;
  final String followers;
  final String following;
  final Color primary;
  final Color secondary;
  final Color border;

  @override
  Widget build(BuildContext context) {
    final tokens = context.pravaColors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _OwnerCoverBanner(
            coverUrl: coverUrl,
            initials: initials,
            border: border,
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _ProfileAvatar(
                initials: initials,
                url: avatarUrl,
                size: 88,
                borderColor: tokens.backgroundCanvas,
              ),
              const SizedBox(width: 15),
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
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        if (verified) ...[
                          const SizedBox(width: 6),
                          Icon(
                            CupertinoIcons.check_mark_circled_solid,
                            color: tokens.brandPrimary,
                            size: 17,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      username.isEmpty ? '' : '@$username',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: PravaTypography.bodyMedium.copyWith(
                        color: secondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      modeLabel,
                      style: PravaTypography.caption.copyWith(
                        color: tokens.brandPrimary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (bio.trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              bio.trim(),
              style: PravaTypography.bodyMedium.copyWith(
                color: primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              _ProfileCount(
                label: 'posts',
                value: posts,
                primary: primary,
                onTap: () {},
              ),
              _ProfileCount(
                label: 'followers',
                value: followers,
                primary: primary,
                onTap: () {},
              ),
              _ProfileCount(
                label: 'following',
                value: following,
                primary: primary,
                onTap: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfilePreviewLockCard extends StatelessWidget {
  const _ProfilePreviewLockCard({
    required this.primary,
    required this.secondary,
    required this.border,
  });

  final Color primary;
  final Color secondary;
  final Color border;

  @override
  Widget build(BuildContext context) {
    final tokens = context.pravaColors;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 24, 20, 28),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: tokens.backgroundSurfaceSubtle,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: tokens.brandContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(CupertinoIcons.lock_fill, color: tokens.brandContent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This account is private',
                  style: PravaTypography.titleSmall.copyWith(
                    color: primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'This is what people outside the allowed audience will see.',
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

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.displayName,
    required this.username,
    required this.initials,
    required this.avatarUrl,
    required this.coverUrl,
    required this.verified,
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

  final String displayName;
  final String username;
  final String initials;
  final String avatarUrl;
  final String coverUrl;
  final bool verified;
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
    final tokens = context.pravaColors;
    final surface = tokens.backgroundCanvas;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _OwnerCoverBanner(
            coverUrl: coverUrl,
            initials: initials,
            border: border,
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _ProfileAvatar(
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
                            style: PravaTypography.titleLarge.copyWith(
                              color: primary,
                              letterSpacing: 0,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (verified) ...[
                          const SizedBox(width: 6),
                          Icon(
                            CupertinoIcons.check_mark_circled_solid,
                            color: tokens.brandPrimary,
                            size: 17,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '@$username',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: PravaTypography.bodyMedium.copyWith(
                        color: secondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _ProfileCount(
                          label: 'posts',
                          value: posts,
                          primary: primary,
                          onTap: onPostsTap,
                        ),
                        _ProfileCount(
                          label: 'followers',
                          value: followers,
                          primary: primary,
                          onTap: onFollowersTap,
                        ),
                        _ProfileCount(
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
          const SizedBox(height: 18),
          _DashboardButton(primary: primary, border: border),
        ],
      ),
    );
  }
}

class _OwnerCoverBanner extends StatelessWidget {
  const _OwnerCoverBanner({
    required this.coverUrl,
    required this.initials,
    required this.border,
  });

  final String coverUrl;
  final String initials;
  final Color border;

  @override
  Widget build(BuildContext context) {
    final tokens = context.pravaColors;
    return Semantics(
      label: 'Your profile cover photo',
      image: true,
      child: Container(
        height: 132,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: border),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              tokens.brandPrimary.withValues(alpha: 0.34),
              tokens.backgroundSurfaceSubtle,
              tokens.brandContainer.withValues(alpha: 0.78),
            ],
          ),
          image: coverUrl.trim().isEmpty
              ? null
              : DecorationImage(
                  image: NetworkImage(coverUrl),
                  fit: BoxFit.cover,
                ),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                tokens.backgroundCanvas.withValues(alpha: 0.58),
              ],
            ),
          ),
          child: Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                initials,
                style: PravaTypography.displaySmall.copyWith(
                  color: tokens.textInverse.withValues(alpha: 0.86),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OwnerProfileCommandCenter extends StatelessWidget {
  const _OwnerProfileCommandCenter({
    required this.tools,
    required this.stats,
    required this.primary,
    required this.secondary,
    required this.border,
    required this.onPreviewAs,
  });

  final ProfileOwnerTools tools;
  final ProfileStats stats;
  final Color primary;
  final Color secondary;
  final Color border;
  final ValueChanged<String> onPreviewAs;

  @override
  Widget build(BuildContext context) {
    final tokens = context.pravaColors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 2, 18, 10),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: tokens.backgroundSurfaceSubtle,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Profile command center',
                        style: PravaTypography.titleSmall.copyWith(
                          color: primary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    _OwnerMetricPill(
                      label: '${tools.completionScore}%',
                      icon: CupertinoIcons.check_mark_circled_solid,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    minHeight: 8,
                    value: (tools.completionScore.clamp(0, 100)) / 100,
                    backgroundColor: tokens.borderSubtle,
                    color: tokens.brandPrimary,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _OwnerToolChip(
                      icon: CupertinoIcons.heart_fill,
                      label: tools.accountHealthLabel,
                      primary: primary,
                      border: border,
                    ),
                    _OwnerToolChip(
                      icon: tools.privateAccount
                          ? CupertinoIcons.lock_fill
                          : CupertinoIcons.globe,
                      label: tools.privateAccount ? 'Private' : 'Public',
                      primary: primary,
                      border: border,
                    ),
                    _OwnerToolChip(
                      icon: CupertinoIcons.checkmark_shield_fill,
                      label: tools.verified ? 'Verified' : 'Verification ready',
                      primary: primary,
                      border: border,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _OwnerMetricCard(
                  label: 'Views',
                  value: tools.profileViews,
                  icon: CupertinoIcons.eye_fill,
                  primary: primary,
                  secondary: secondary,
                  border: border,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _OwnerMetricCard(
                  label: 'Reach',
                  value: tools.postReach,
                  icon: CupertinoIcons.chart_bar_fill,
                  primary: primary,
                  secondary: secondary,
                  border: border,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _OwnerMetricCard(
                  label: 'New',
                  value: tools.newFollowers,
                  icon: CupertinoIcons.person_add_solid,
                  primary: primary,
                  secondary: secondary,
                  border: border,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _OwnerToolChip(
                  icon: CupertinoIcons.bookmark_fill,
                  label: 'Saved ${stats.saved}',
                  primary: primary,
                  border: border,
                ),
                _OwnerToolChip(
                  icon: CupertinoIcons.doc_text_fill,
                  label: 'Drafts ${stats.drafts}',
                  primary: primary,
                  border: border,
                ),
                _OwnerToolChip(
                  icon: CupertinoIcons.archivebox_fill,
                  label: 'Archive ${stats.archive}',
                  primary: primary,
                  border: border,
                ),
                _OwnerToolChip(
                  icon: CupertinoIcons.person_2_fill,
                  label: 'Close friends ${stats.closeFriends}',
                  primary: primary,
                  border: border,
                ),
                for (final mode
                    in tools.previewModes.isEmpty
                        ? const ['public', 'follower', 'friend', 'closeFriend']
                        : tools.previewModes)
                  _OwnerToolChip(
                    icon: CupertinoIcons.eye,
                    label: 'Preview ${_previewModeLabel(mode)}',
                    primary: primary,
                    border: border,
                    onTap: () => onPreviewAs(mode),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _previewModeLabel(String mode) {
    switch (mode) {
      case 'closeFriend':
        return 'close friend';
      case 'friend':
        return 'friend';
      case 'follower':
        return 'follower';
      default:
        return 'public';
    }
  }
}

class _OwnerMetricCard extends StatelessWidget {
  const _OwnerMetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.primary,
    required this.secondary,
    required this.border,
  });

  final String label;
  final int value;
  final IconData icon;
  final Color primary;
  final Color secondary;
  final Color border;

  @override
  Widget build(BuildContext context) {
    final tokens = context.pravaColors;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tokens.backgroundSurfaceSubtle,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: tokens.brandPrimary, size: 20),
          const SizedBox(height: 8),
          Text(
            value.toString(),
            style: PravaTypography.titleSmall.copyWith(
              color: primary,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            style: PravaTypography.caption.copyWith(color: secondary),
          ),
        ],
      ),
    );
  }
}

class _OwnerMetricPill extends StatelessWidget {
  const _OwnerMetricPill({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final tokens = context.pravaColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: tokens.brandContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: tokens.brandContent),
          const SizedBox(width: 5),
          Text(
            label,
            style: PravaTypography.caption.copyWith(
              color: tokens.brandContent,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _OwnerToolChip extends StatelessWidget {
  const _OwnerToolChip({
    required this.icon,
    required this.label,
    required this.primary,
    required this.border,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color primary;
  final Color border;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.pravaColors;
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: tokens.backgroundSurface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: tokens.brandPrimary),
          const SizedBox(width: 7),
          Text(
            label,
            style: PravaTypography.caption.copyWith(
              color: primary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return chip;
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: chip,
      ),
    );
  }
}

class _ProfileTabBar extends StatelessWidget {
  const _ProfileTabBar({
    required this.value,
    required this.primary,
    required this.secondary,
    required this.border,
    required this.onChanged,
  });

  final _ProfileContentTab value;
  final Color primary;
  final Color secondary;
  final Color border;
  final ValueChanged<_ProfileContentTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 8),
      child: Row(
        children: [
          _ProfileTabButton(
            label: 'All',
            selected: value == _ProfileContentTab.all,
            primary: primary,
            secondary: secondary,
            border: border,
            onTap: () => onChanged(_ProfileContentTab.all),
          ),
          const SizedBox(width: 10),
          _ProfileTabButton(
            label: 'Mentions',
            selected: value == _ProfileContentTab.mentions,
            primary: primary,
            secondary: secondary,
            border: border,
            onTap: () => onChanged(_ProfileContentTab.mentions),
          ),
          const SizedBox(width: 10),
          _ProfileTabButton(
            label: 'Posts',
            selected: value == _ProfileContentTab.posts,
            primary: primary,
            secondary: secondary,
            border: border,
            onTap: () => onChanged(_ProfileContentTab.posts),
          ),
        ],
      ),
    );
  }
}

class _ProfileTabButton extends StatelessWidget {
  const _ProfileTabButton({
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
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 40,
          decoration: BoxDecoration(
            color: selected ? tokens.brandContainer : Colors.transparent,
            border: Border.all(color: selected ? tokens.brandPrimary : border),
            borderRadius: BorderRadius.circular(12),
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
      ),
    );
  }
}

class _ProfilePostsList extends StatelessWidget {
  const _ProfilePostsList({
    required this.posts,
    required this.primary,
    required this.secondary,
    required this.border,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.onPostTap,
  });

  final List<ProfileFeedPost> posts;
  final Color primary;
  final Color secondary;
  final Color border;
  final String emptyTitle;
  final String emptySubtitle;
  final ValueChanged<ProfileFeedPost> onPostTap;

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
              (post) => _ProfilePostRow(
                post: post,
                primary: primary,
                secondary: secondary,
                border: border,
                onTap: () => onPostTap(post),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _ProfilePostRow extends StatelessWidget {
  const _ProfilePostRow({
    required this.post,
    required this.primary,
    required this.secondary,
    required this.border,
    required this.onTap,
  });

  final ProfileFeedPost post;
  final Color primary;
  final Color secondary;
  final Color border;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.pravaColors;
    final body = post.body.trim().isEmpty ? 'Text post' : post.body.trim();
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: tokens.brandContainer.withValues(alpha: 0.62),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tokens.brandContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                CupertinoIcons.at,
                color: tokens.brandContent,
                size: 19,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: PravaTypography.bodyMedium.copyWith(
                      color: primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${post.likeCount} likes - ${post.commentCount} comments',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PravaTypography.caption.copyWith(color: secondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              CupertinoIcons.chevron_right,
              size: 16,
              color: tokens.brandContent,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
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

class _DashboardButton extends StatelessWidget {
  const _DashboardButton({required this.primary, required this.border});

  final Color primary;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Center(
        child: Text(
          'Dashboard',
          style: PravaTypography.buttonMedium.copyWith(
            color: primary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _ProfileCount extends StatelessWidget {
  const _ProfileCount({
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
                style: PravaTypography.bodyMedium.copyWith(
                  color: primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              TextSpan(
                text: ' $label',
                style: PravaTypography.bodyMedium.copyWith(color: primary),
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

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({
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

class _ProfileInfoRow extends StatelessWidget {
  const _ProfileInfoRow({
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

class _ProfileEditPage extends StatefulWidget {
  const _ProfileEditPage();

  @override
  State<_ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<_ProfileEditPage> {
  final AccountService _accountService = AccountService();
  final MediaService _mediaService = MediaService();
  final ImagePicker _picker = ImagePicker();

  AccountInfo? _account;
  bool _loading = true;
  bool _uploadingAvatar = false;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _loadAccount();
  }

  Future<void> _loadAccount() async {
    setState(() => _loading = true);
    try {
      final account = await _accountService.fetchAccountInfo();
      if (!mounted) return;
      setState(() {
        _account = account;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      PravaToast.show(
        context,
        message: 'Unable to load profile details',
        type: PravaToastType.error,
      );
    }
  }

  void _close() {
    Navigator.of(context).pop(_changed);
  }

  Future<void> _pickAvatar() async {
    if (_uploadingAvatar) return;
    HapticFeedback.selectionClick();
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2400,
        imageQuality: 95,
        requestFullMetadata: false,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      final cropped = await Navigator.of(context, rootNavigator: true)
          .push<Uint8List>(
            PravaNavigator.route(
              _AvatarCropPage(imageBytes: bytes),
              fullscreenDialog: true,
            ),
          );
      if (cropped == null || cropped.isEmpty) return;

      setState(() => _uploadingAvatar = true);
      final dataUri = 'data:image/jpeg;base64,${base64Encode(cropped)}';
      final asset = await _mediaService.uploadProfileImage(dataUri: dataUri);
      if (asset.secureUrl.trim().isEmpty) {
        throw Exception('Missing uploaded image URL');
      }
      final updated = await _accountService.updateProfileMedia(
        avatarUrl: asset.secureUrl,
      );
      if (!mounted) return;
      setState(() {
        _account = updated;
        _changed = true;
        _uploadingAvatar = false;
      });
      PravaToast.show(
        context,
        message: 'Profile photo updated',
        type: PravaToastType.success,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _uploadingAvatar = false);
      PravaToast.show(
        context,
        message: 'Unable to update profile photo',
        type: PravaToastType.error,
      );
    }
  }

  Future<void> _openField(_ProfileEditField field) async {
    final account = _account;
    if (account == null) return;
    HapticFeedback.selectionClick();
    final changed = await Navigator.of(context, rootNavigator: true).push<bool>(
      PravaNavigator.route(
        _ProfileFieldEditPage(field: field, account: account),
        fullscreenDialog: true,
      ),
    );
    if (changed == true) {
      _changed = true;
      _loadAccount();
    }
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
    final surface = isDark ? PravaColors.darkBgMain : PravaColors.lightBgMain;
    final account = _account;

    return Scaffold(
      backgroundColor: surface,
      body: SafeArea(
        child: _loading
            ? const Center(child: CupertinoActivityIndicator())
            : account == null
            ? _ProfileErrorState(
                primary: primary,
                secondary: secondary,
                onRetry: _loadAccount,
              )
            : Column(
                children: [
                  _FullscreenHeader(
                    title: 'Edit profile',
                    leadingIcon: CupertinoIcons.xmark,
                    onClose: _close,
                    primary: primary,
                  ),
                  Expanded(
                    child: ListView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
                      children: [
                        _EditAvatarHeader(
                          account: account,
                          uploading: _uploadingAvatar,
                          primary: primary,
                          onAvatarTap: _pickAvatar,
                        ),
                        const SizedBox(height: 20),
                        _EditSection(
                          title: 'Intro',
                          primary: primary,
                          children: [
                            _EditableRow(
                              icon: CupertinoIcons.hand_raised_fill,
                              title: 'Bio',
                              value: account.bio,
                              placeholder: 'Add a bio',
                              primary: primary,
                              secondary: secondary,
                              onTap: () => _openField(_ProfileEditField.bio()),
                            ),
                          ],
                        ),
                        _EditSection(
                          title: 'Category',
                          primary: primary,
                          children: [
                            _EditableRow(
                              icon: Icons.category_rounded,
                              title: 'Category',
                              value: account.category,
                              placeholder: 'Digital creator',
                              primary: primary,
                              secondary: secondary,
                              onTap: () =>
                                  _openField(_ProfileEditField.category()),
                            ),
                            _EditableRow(
                              icon: CupertinoIcons.sparkles,
                              title: 'AI creator',
                              value: account.aiCreator ? 'Yes' : 'No',
                              placeholder: 'No',
                              primary: primary,
                              secondary: secondary,
                              onTap: () =>
                                  _openField(_ProfileEditField.aiCreator()),
                            ),
                          ],
                        ),
                        _EditSection(
                          title: 'Personal details',
                          primary: primary,
                          children: [
                            _EditableRow(
                              icon: CupertinoIcons.location,
                              title: 'Location',
                              value: account.location,
                              placeholder: 'Add current city',
                              primary: primary,
                              secondary: secondary,
                              onTap: () =>
                                  _openField(_ProfileEditField.location()),
                            ),
                            _EditableRow(
                              icon: CupertinoIcons.house,
                              title: 'Hometown',
                              value: account.hometown,
                              placeholder: 'Add hometown',
                              primary: primary,
                              secondary: secondary,
                              onTap: () =>
                                  _openField(_ProfileEditField.hometown()),
                            ),
                            _EditableRow(
                              icon: CupertinoIcons.phone,
                              title: 'Phone',
                              value: [
                                account.phoneCountryCode,
                                account.phoneNumber,
                              ].where((v) => v.trim().isNotEmpty).join(' '),
                              placeholder: 'Add phone number',
                              primary: primary,
                              secondary: secondary,
                              onTap: () =>
                                  _openField(_ProfileEditField.phone()),
                            ),
                          ],
                        ),
                        _EditSection(
                          title: 'Links',
                          primary: primary,
                          children: [
                            _EditableRow(
                              icon: CupertinoIcons.link,
                              title: 'Website',
                              value: account.website,
                              placeholder: 'Add website',
                              primary: primary,
                              secondary: secondary,
                              onTap: () =>
                                  _openField(_ProfileEditField.website()),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _FullscreenHeader extends StatelessWidget {
  const _FullscreenHeader({
    required this.title,
    required this.leadingIcon,
    required this.onClose,
    required this.primary,
  });

  final String title;
  final IconData leadingIcon;
  final VoidCallback onClose;
  final Color primary;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: IconButton(
              icon: Icon(leadingIcon, color: primary, size: 28),
              onPressed: onClose,
            ),
          ),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: PravaTypography.titleLarge.copyWith(
                color: primary,
                letterSpacing: 0,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 56),
        ],
      ),
    );
  }
}

class _EditAvatarHeader extends StatelessWidget {
  const _EditAvatarHeader({
    required this.account,
    required this.uploading,
    required this.primary,
    required this.onAvatarTap,
  });

  final AccountInfo account;
  final bool uploading;
  final Color primary;
  final VoidCallback onAvatarTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? PravaColors.darkBgMain : PravaColors.lightBgMain;
    final name = account.displayName.isNotEmpty
        ? account.displayName
        : account.username;
    final initials = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();

    return Center(
      child: GestureDetector(
        onTap: uploading ? null : onAvatarTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            _ProfileAvatar(
              initials: initials,
              url: account.avatarUrl,
              size: 112,
              borderColor: surface,
            ),
            Positioned(
              right: 2,
              bottom: 4,
              child: _CameraBadge(uploading: uploading),
            ),
            if (uploading)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CameraBadge extends StatelessWidget {
  const _CameraBadge({required this.uploading});

  final bool uploading;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: PravaColors.darkBgElevated,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black.withValues(alpha: 0.18)),
      ),
      child: Center(
        child: uploading
            ? const CupertinoActivityIndicator(radius: 8)
            : const Icon(
                CupertinoIcons.camera_fill,
                color: Colors.white,
                size: 21,
              ),
      ),
    );
  }
}

class _EditSection extends StatefulWidget {
  const _EditSection({
    required this.title,
    required this.children,
    required this.primary,
  });

  final String title;
  final List<Widget> children;
  final Color primary;

  @override
  State<_EditSection> createState() => _EditSectionState();
}

class _EditSectionState extends State<_EditSection> {
  bool _collapsed = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _collapsed = !_collapsed);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: PravaTypography.titleSmall.copyWith(
                        color: widget.primary,
                        letterSpacing: 0,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _collapsed ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: Icon(
                      CupertinoIcons.chevron_up,
                      color: widget.primary,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: Column(children: widget.children),
            secondChild: const SizedBox.shrink(),
            crossFadeState: _collapsed
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 180),
          ),
        ],
      ),
    );
  }
}

class _EditableRow extends StatelessWidget {
  const _EditableRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.placeholder,
    required this.primary,
    required this.secondary,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final String placeholder;
  final Color primary;
  final Color secondary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shown = value.trim().isEmpty ? placeholder : value.trim();
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 38, child: Icon(icon, color: primary, size: 24)),
            const SizedBox(width: 10),
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
                  const SizedBox(height: 2),
                  Text(
                    shown,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: PravaTypography.bodyMedium.copyWith(
                      color: value.trim().isEmpty ? secondary : primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(CupertinoIcons.pencil, color: secondary, size: 22),
          ],
        ),
      ),
    );
  }
}

class _ProfileEditField {
  const _ProfileEditField({
    required this.id,
    required this.sectionTitle,
    required this.heading,
    required this.placeholder,
    required this.maxLength,
    this.visibilityKey,
    this.multiline = false,
    this.boolean = false,
    this.phone = false,
  });

  final String id;
  final String sectionTitle;
  final String heading;
  final String placeholder;
  final int maxLength;
  final String? visibilityKey;
  final bool multiline;
  final bool boolean;
  final bool phone;

  factory _ProfileEditField.bio() => const _ProfileEditField(
    id: 'bio',
    sectionTitle: 'Intro',
    heading: 'Add a bio',
    placeholder: 'Introduce yourself',
    maxLength: 101,
    visibilityKey: 'bio',
    multiline: true,
  );

  factory _ProfileEditField.category() => const _ProfileEditField(
    id: 'category',
    sectionTitle: 'Category',
    heading: 'Category',
    placeholder: 'Digital creator',
    maxLength: 80,
  );

  factory _ProfileEditField.aiCreator() => const _ProfileEditField(
    id: 'aiCreator',
    sectionTitle: 'Category',
    heading: 'AI creator',
    placeholder: 'No',
    maxLength: 3,
    boolean: true,
  );

  factory _ProfileEditField.location() => const _ProfileEditField(
    id: 'location',
    sectionTitle: 'Personal details',
    heading: 'Location',
    placeholder: 'Search city, state or country',
    maxLength: 120,
    visibilityKey: 'location',
  );

  factory _ProfileEditField.hometown() => const _ProfileEditField(
    id: 'hometown',
    sectionTitle: 'Personal details',
    heading: 'Hometown',
    placeholder: 'Search hometown',
    maxLength: 120,
    visibilityKey: 'location',
  );

  factory _ProfileEditField.website() => const _ProfileEditField(
    id: 'website',
    sectionTitle: 'Personal details',
    heading: 'Website',
    placeholder: 'Add website',
    maxLength: 240,
    visibilityKey: 'website',
  );

  factory _ProfileEditField.phone() => const _ProfileEditField(
    id: 'phone',
    sectionTitle: 'Personal details',
    heading: 'Phone number',
    placeholder: 'Add phone number',
    maxLength: 32,
    phone: true,
  );
}

class _ProfileFieldEditPage extends StatefulWidget {
  const _ProfileFieldEditPage({required this.field, required this.account});

  final _ProfileEditField field;
  final AccountInfo account;

  @override
  State<_ProfileFieldEditPage> createState() => _ProfileFieldEditPageState();
}

class _ProfileFieldEditPageState extends State<_ProfileFieldEditPage> {
  final AccountService _accountService = AccountService();
  final LocationSuggestionService _locationService =
      LocationSuggestionService();
  final ProfileService _profileService = ProfileService();
  late final TextEditingController _controller;
  late final TextEditingController _countryController;
  late final TextEditingController _phoneController;
  late bool _booleanValue;
  ProfileVisibility? _visibility;
  String? _visibilityLevel;
  Timer? _locationDebounce;
  List<LocationSuggestion> _locationSuggestions = [];
  bool _loadingLocationSuggestions = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _initialText());
    _countryController = TextEditingController(
      text: widget.account.phoneCountryCode.isEmpty
          ? '+91'
          : widget.account.phoneCountryCode,
    );
    _phoneController = TextEditingController(text: widget.account.phoneNumber);
    _booleanValue = widget.account.aiCreator;
    _controller.addListener(_onChanged);
    _countryController.addListener(_onChanged);
    _phoneController.addListener(_onChanged);
    _loadVisibility();
    if (_usesLocationSuggestions) {
      _loadLocationSuggestions();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _countryController.dispose();
    _phoneController.dispose();
    _locationDebounce?.cancel();
    super.dispose();
  }

  bool get _usesLocationSuggestions {
    return widget.field.id == 'location' || widget.field.id == 'hometown';
  }

  String _initialText() {
    switch (widget.field.id) {
      case 'bio':
        return widget.account.bio;
      case 'category':
        return widget.account.category;
      case 'location':
        return widget.account.location;
      case 'hometown':
        return widget.account.hometown;
      case 'website':
        return widget.account.website;
      default:
        return '';
    }
  }

  bool get _hasChanges {
    if (widget.field.boolean) return _booleanValue != widget.account.aiCreator;
    if (widget.field.phone) {
      return _countryController.text.trim() !=
              widget.account.phoneCountryCode ||
          _phoneController.text.trim() != widget.account.phoneNumber;
    }
    final textChanged = _controller.text.trim() != _initialText().trim();
    final visibilityChanged =
        widget.field.visibilityKey != null &&
        _visibilityLevel != null &&
        _visibilityLevel !=
            (_visibility ?? ProfileVisibility.defaultsForOwner()).levelFor(
              widget.field.visibilityKey!,
            );
    return textChanged || visibilityChanged;
  }

  void _onChanged() {
    if (mounted) setState(() {});
    if (!_usesLocationSuggestions) return;
    _locationDebounce?.cancel();
    _locationDebounce = Timer(
      const Duration(milliseconds: 280),
      _loadLocationSuggestions,
    );
  }

  Future<void> _loadLocationSuggestions() async {
    if (!_usesLocationSuggestions) return;
    final query = _controller.text.trim();
    setState(() => _loadingLocationSuggestions = true);
    try {
      final suggestions = await _locationService.search(query);
      if (!mounted) return;
      setState(() {
        _locationSuggestions = suggestions;
        _loadingLocationSuggestions = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _locationSuggestions = [];
        _loadingLocationSuggestions = false;
      });
    }
  }

  void _selectLocation(LocationSuggestion suggestion) {
    HapticFeedback.selectionClick();
    _controller.text = suggestion.label;
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: _controller.text.length),
    );
    setState(() => _locationSuggestions = [suggestion]);
  }

  Future<void> _loadVisibility() async {
    if (widget.field.visibilityKey == null) return;
    try {
      final visibility = await _profileService.fetchProfileVisibility();
      if (!mounted) return;
      setState(() {
        _visibility = visibility;
        _visibilityLevel = visibility.levelFor(widget.field.visibilityKey!);
      });
    } catch (_) {}
  }

  Future<void> _chooseVisibility() async {
    final key = widget.field.visibilityKey;
    if (key == null) return;
    final currentLevel =
        _visibilityLevel ??
        (_visibility ?? ProfileVisibility.defaultsForOwner()).levelFor(key);
    final next = await showCupertinoModalPopup<String>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text('Who can see ${ProfileVisibility.fieldLabel(key)}?'),
        actions: ProfileVisibility.levels
            .map(
              (level) => CupertinoActionSheetAction(
                onPressed: () => Navigator.of(context).pop(level),
                child: Text(ProfileVisibility.levelLabel(level)),
              ),
            )
            .toList(),
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
    if (next == null || next == currentLevel) return;
    setState(() => _visibilityLevel = next);
  }

  Future<void> _save() async {
    if (!_hasChanges || _saving) return;
    HapticFeedback.selectionClick();
    setState(() => _saving = true);
    try {
      switch (widget.field.id) {
        case 'bio':
          await _accountService.updateProfileDetails(
            bio: _controller.text.trim(),
          );
          break;
        case 'category':
          await _accountService.updateProfileDetails(
            category: _controller.text.trim(),
          );
          break;
        case 'aiCreator':
          await _accountService.updateProfileDetails(aiCreator: _booleanValue);
          break;
        case 'location':
          await _accountService.updateProfileDetails(
            location: _controller.text.trim(),
          );
          break;
        case 'hometown':
          await _accountService.updateProfileDetails(
            hometown: _controller.text.trim(),
          );
          break;
        case 'website':
          await _accountService.updateProfileDetails(
            website: _controller.text.trim(),
          );
          break;
        case 'phone':
          await _accountService.updateProfileDetails(
            phoneCountryCode: _countryController.text.trim(),
            phoneNumber: _phoneController.text.trim(),
          );
          break;
      }
      final key = widget.field.visibilityKey;
      if (key != null && _visibilityLevel != null && _visibility != null) {
        await _profileService.saveProfileVisibility(
          _visibility!.copyWithField(key, _visibilityLevel!),
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      PravaToast.show(
        context,
        message: 'Unable to save profile detail',
        type: PravaToastType.error,
      );
    }
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
    final surface = isDark ? PravaColors.darkBgMain : PravaColors.lightBgMain;
    final enabled = _hasChanges && !_saving;

    return Scaffold(
      backgroundColor: surface,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            _FullscreenHeader(
              title: widget.field.sectionTitle,
              leadingIcon: CupertinoIcons.xmark,
              onClose: () => Navigator.of(context).pop(false),
              primary: primary,
            ),
            Expanded(
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                children: [
                  Text(
                    widget.field.heading,
                    style: PravaTypography.titleLarge.copyWith(
                      color: primary,
                      letterSpacing: 0,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 22),
                  if (widget.field.boolean)
                    _BooleanEditor(
                      value: _booleanValue,
                      primary: primary,
                      secondary: secondary,
                      border: border,
                      onChanged: (value) =>
                          setState(() => _booleanValue = value),
                    )
                  else if (widget.field.phone)
                    _PhoneEditor(
                      countryController: _countryController,
                      phoneController: _phoneController,
                      border: border,
                    )
                  else if (_usesLocationSuggestions)
                    _LocationEditor(
                      controller: _controller,
                      placeholder: widget.field.placeholder,
                      maxLength: widget.field.maxLength,
                      suggestions: _locationSuggestions,
                      loading: _loadingLocationSuggestions,
                      primary: primary,
                      secondary: secondary,
                      border: border,
                      onSelect: _selectLocation,
                    )
                  else
                    _TextEditorBox(
                      controller: _controller,
                      placeholder: widget.field.placeholder,
                      maxLength: widget.field.maxLength,
                      multiline: widget.field.multiline,
                      border: border,
                    ),
                  if (widget.field.visibilityKey != null) ...[
                    const SizedBox(height: 14),
                    GestureDetector(
                      onTap: _chooseVisibility,
                      child: Text(
                        '${_visibilityLabel()} - ${_counterText()}',
                        style: PravaTypography.titleSmall.copyWith(
                          color: secondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
              child: GestureDetector(
                onTap: enabled ? _save : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 58,
                  decoration: BoxDecoration(
                    color: enabled
                        ? PravaColors.accentPrimary
                        : (isDark ? Colors.white12 : Colors.black12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: _saving
                        ? const CupertinoActivityIndicator(radius: 10)
                        : Text(
                            'Save',
                            style: PravaTypography.titleSmall.copyWith(
                              color: enabled ? Colors.white : secondary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _visibilityLabel() {
    final level = _visibilityLevel ?? 'everyone';
    return ProfileVisibility.levelLabel(level);
  }

  String _counterText() {
    if (widget.field.boolean) return '';
    if (widget.field.phone) {
      return _phoneController.text.trim().length.toString();
    }
    return '${_controller.text.trim().length}/${widget.field.maxLength}';
  }
}

class _LocationEditor extends StatelessWidget {
  const _LocationEditor({
    required this.controller,
    required this.placeholder,
    required this.maxLength,
    required this.suggestions,
    required this.loading,
    required this.primary,
    required this.secondary,
    required this.border,
    required this.onSelect,
  });

  final TextEditingController controller;
  final String placeholder;
  final int maxLength;
  final List<LocationSuggestion> suggestions;
  final bool loading;
  final Color primary;
  final Color secondary;
  final Color border;
  final ValueChanged<LocationSuggestion> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TextEditorBox(
          controller: controller,
          placeholder: placeholder,
          maxLength: maxLength,
          multiline: false,
          border: border,
        ),
        const SizedBox(height: 14),
        if (loading)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                const CupertinoActivityIndicator(radius: 8),
                const SizedBox(width: 10),
                Text(
                  'Searching locations',
                  style: PravaTypography.bodyMedium.copyWith(color: secondary),
                ),
              ],
            ),
          )
        else if (suggestions.isNotEmpty)
          Column(
            children: suggestions
                .map(
                  (suggestion) => _LocationSuggestionRow(
                    suggestion: suggestion,
                    primary: primary,
                    secondary: secondary,
                    border: border,
                    onTap: () => onSelect(suggestion),
                  ),
                )
                .toList(),
          ),
      ],
    );
  }
}

class _LocationSuggestionRow extends StatelessWidget {
  const _LocationSuggestionRow({
    required this.suggestion,
    required this.primary,
    required this.secondary,
    required this.border,
    required this.onTap,
  });

  final LocationSuggestion suggestion;
  final Color primary;
  final Color secondary;
  final Color border;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final meta = [
      suggestion.city,
      suggestion.state,
      suggestion.country,
    ].where((value) => value.trim().isNotEmpty).join(' - ');

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: border)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(CupertinoIcons.location, color: primary, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    suggestion.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: PravaTypography.bodyLarge.copyWith(
                      color: primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (meta.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: PravaTypography.bodySmall.copyWith(
                        color: secondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TextEditorBox extends StatelessWidget {
  const _TextEditorBox({
    required this.controller,
    required this.placeholder,
    required this.maxLength,
    required this.multiline,
    required this.border,
  });

  final TextEditingController controller;
  final String placeholder;
  final int maxLength;
  final bool multiline;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: border, width: 1.4),
        borderRadius: BorderRadius.circular(22),
      ),
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
      child: PravaInput(
        controller: controller,
        hint: placeholder,
        fieldType: multiline
            ? PravaInputFieldType.bio
            : PravaInputFieldType.text,
        variant: PravaInputVariant.borderless,
        size: PravaInputSize.medium,
        maxLength: maxLength,
        showCounter: false,
        maxLines: multiline ? 5 : 1,
        minLines: multiline ? 4 : 1,
      ),
    );
  }
}

class _BooleanEditor extends StatelessWidget {
  const _BooleanEditor({
    required this.value,
    required this.primary,
    required this.secondary,
    required this.border,
    required this.onChanged,
  });

  final bool value;
  final Color primary;
  final Color secondary;
  final Color border;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        border: Border.all(color: border, width: 1.4),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value ? 'Yes' : 'No',
                  style: PravaTypography.bodyLarge.copyWith(
                    color: primary,
                    letterSpacing: 0,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Show whether you create with AI tools.',
                  style: PravaTypography.bodyMedium.copyWith(color: secondary),
                ),
              ],
            ),
          ),
          CupertinoSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _PhoneEditor extends StatelessWidget {
  const _PhoneEditor({
    required this.countryController,
    required this.phoneController,
    required this.border,
  });

  final TextEditingController countryController;
  final TextEditingController phoneController;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 96,
          child: _PlainField(
            controller: countryController,
            placeholder: '+91',
            keyboardType: TextInputType.phone,
            border: border,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _PlainField(
            controller: phoneController,
            placeholder: 'Phone number',
            keyboardType: TextInputType.phone,
            border: border,
          ),
        ),
      ],
    );
  }
}

class _PlainField extends StatelessWidget {
  const _PlainField({
    required this.controller,
    required this.placeholder,
    required this.keyboardType,
    required this.border,
  });

  final TextEditingController controller;
  final String placeholder;
  final TextInputType keyboardType;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      decoration: BoxDecoration(
        border: Border.all(color: border, width: 1.4),
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: PravaInput(
        controller: controller,
        hint: placeholder,
        fieldType: PravaInputFieldType.phone,
        variant: PravaInputVariant.borderless,
        size: PravaInputSize.small,
        keyboardType: keyboardType,
      ),
    );
  }
}

class _AvatarCropPage extends StatefulWidget {
  const _AvatarCropPage({required this.imageBytes});

  final Uint8List imageBytes;

  @override
  State<_AvatarCropPage> createState() => _AvatarCropPageState();
}

class _AvatarCropPageState extends State<_AvatarCropPage> {
  double _scale = 1;
  Offset _offset = Offset.zero;
  double _startScale = 1;
  Offset _startOffset = Offset.zero;
  Offset _startFocal = Offset.zero;

  void _onScaleStart(ScaleStartDetails details) {
    _startScale = _scale;
    _startOffset = _offset;
    _startFocal = details.focalPoint;
  }

  void _onScaleUpdate(ScaleUpdateDetails details, double previewSize) {
    final nextScale = ((_startScale * details.scale).clamp(1.0, 4.0) as num)
        .toDouble();
    final rawOffset = _startOffset + details.focalPoint - _startFocal;
    setState(() {
      _scale = nextScale;
      _offset = _clampOffset(rawOffset, previewSize, nextScale);
    });
  }

  Offset _clampOffset(Offset offset, double previewSize, double scale) {
    final source = image_lib.decodeImage(widget.imageBytes);
    if (source == null) return Offset.zero;
    final aspect = source.width / source.height;
    final baseW = aspect >= 1 ? previewSize * aspect : previewSize;
    final baseH = aspect >= 1 ? previewSize : previewSize / aspect;
    final maxX = math.max(0, (baseW * scale - previewSize) / 2);
    final maxY = math.max(0, (baseH * scale - previewSize) / 2);
    return Offset(
      offset.dx.clamp(-maxX, maxX).toDouble(),
      offset.dy.clamp(-maxY, maxY).toDouble(),
    );
  }

  Uint8List? _crop(double previewSize) {
    final source = image_lib.decodeImage(widget.imageBytes);
    if (source == null) return null;
    final sourceW = source.width.toDouble();
    final sourceH = source.height.toDouble();
    final aspect = sourceW / sourceH;
    final baseW = aspect >= 1 ? previewSize * aspect : previewSize;
    final baseH = aspect >= 1 ? previewSize : previewSize / aspect;
    final displayW = baseW * _scale;
    final displayH = baseH * _scale;
    final centerDisplayX = displayW / 2 - _offset.dx;
    final centerDisplayY = displayH / 2 - _offset.dy;
    final centerX = centerDisplayX / displayW * sourceW;
    final centerY = centerDisplayY / displayH * sourceH;
    final cropSize = math.min(
      sourceW * previewSize / displayW,
      sourceH * previewSize / displayH,
    );
    final left = (centerX - cropSize / 2).clamp(0, sourceW - cropSize);
    final top = (centerY - cropSize / 2).clamp(0, sourceH - cropSize);
    final cropped = image_lib.copyCrop(
      source,
      x: left.round(),
      y: top.round(),
      width: cropSize.round(),
      height: cropSize.round(),
    );
    final resized = image_lib.copyResize(cropped, width: 512, height: 512);
    return Uint8List.fromList(image_lib.encodeJpg(resized, quality: 92));
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
    final bg = isDark ? PravaColors.darkBgMain : PravaColors.lightBgMain;
    final previewSize = math.min(MediaQuery.of(context).size.width - 56, 340.0);
    final decoded = image_lib.decodeImage(widget.imageBytes);
    final aspect = decoded == null ? 1.0 : decoded.width / decoded.height;
    final baseW = aspect >= 1 ? previewSize * aspect : previewSize;
    final baseH = aspect >= 1 ? previewSize : previewSize / aspect;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            _FullscreenHeader(
              title: 'Adjust photo',
              leadingIcon: CupertinoIcons.xmark,
              onClose: () => Navigator.of(context).pop(),
              primary: primary,
            ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onScaleStart: _onScaleStart,
                    onScaleUpdate: (details) =>
                        _onScaleUpdate(details, previewSize),
                    child: Container(
                      width: previewSize,
                      height: previewSize,
                      color: Colors.transparent,
                      child: ClipOval(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Transform.translate(
                              offset: _offset,
                              child: Transform.scale(
                                scale: _scale,
                                child: Image.memory(
                                  widget.imageBytes,
                                  width: baseW,
                                  height: baseH,
                                  fit: BoxFit.fill,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 34),
                    child: Row(
                      children: [
                        Icon(CupertinoIcons.minus, color: secondary),
                        Expanded(
                          child: Slider(
                            value: _scale,
                            min: 1,
                            max: 4,
                            onChanged: (value) {
                              setState(() {
                                _scale = value;
                                _offset = _clampOffset(
                                  _offset,
                                  previewSize,
                                  value,
                                );
                              });
                            },
                          ),
                        ),
                        Icon(CupertinoIcons.plus, color: secondary),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
              child: GestureDetector(
                onTap: () {
                  final cropped = _crop(previewSize);
                  Navigator.of(context).pop(cropped);
                },
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: PravaColors.accentPrimary,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      'Use photo',
                      style: PravaTypography.titleSmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
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
            GestureDetector(
              onTap: onRetry,
              child: Text(
                'Try again',
                style: PravaTypography.bodyMedium.copyWith(
                  color: PravaColors.accentPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
