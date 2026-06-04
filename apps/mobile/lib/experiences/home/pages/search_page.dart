import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/storage/secure_store.dart';
import '../../../navigation/prava_navigator.dart';
import '../../../services/user_search_service.dart';
import '../../../ui-system/background.dart';
import '../../../ui-system/colors.dart';
import '../../../ui-system/feedback/prava_toast.dart';
import '../../../ui-system/feedback/toast_type.dart';
import '../../../ui-system/typography.dart';
import '../tabs/feed/feed_page.dart';
import '../tabs/profile/public_profile_page.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _controller = TextEditingController();
  final UserSearchService _searchService = UserSearchService();
  final SecureStore _store = SecureStore();
  final Set<String> _pendingActions = <String>{};

  Timer? _debounce;
  int _searchToken = 0;
  bool _loading = false;
  String _query = '';
  SmartSearchResult _results = SmartSearchResult.empty();
  List<String> _history = <String>[];

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onQueryChanged);
    _loadHistory();
  }

  @override
  void dispose() {
    _controller.removeListener(_onQueryChanged);
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final raw = await _store.getSearchHistoryJson();
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List && mounted) {
        setState(() {
          _history = decoded
              .map((item) => item.toString())
              .where((item) => item.trim().isNotEmpty)
              .take(12)
              .toList();
        });
      }
    } catch (_) {}
  }

  Future<void> _saveHistory() async {
    await _store.setSearchHistoryJson(jsonEncode(_history.take(12).toList()));
  }

  String _normalizeQuery(String raw) {
    return raw.trim().toLowerCase().replaceFirst(RegExp(r'^[@#]+'), '');
  }

  void _onQueryChanged() {
    final normalized = _normalizeQuery(_controller.text);
    if (normalized == _query) return;

    setState(() => _query = normalized);

    if (normalized.length < 2) {
      _debounce?.cancel();
      setState(() {
        _results = SmartSearchResult.empty();
        _loading = false;
      });
      return;
    }

    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 260),
      () => _runSearch(normalized),
    );
  }

  Future<void> _runSearch(String query) async {
    final token = ++_searchToken;
    setState(() => _loading = true);

    try {
      final results = await _searchService.smartSearch(query);
      if (!mounted || token != _searchToken) return;
      setState(() {
        _results = results;
        _loading = false;
        _history = [
          query,
          ..._history.where((item) => item != query),
        ].take(12).toList();
      });
      unawaited(_saveHistory());
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

  void _applyQuery(String value) {
    final cleaned = value.trim();
    _controller.text = cleaned;
    _controller.selection = TextSelection.collapsed(offset: cleaned.length);
  }

  Future<void> _removeHistory(String value) async {
    HapticFeedback.selectionClick();
    setState(() => _history = _history.where((item) => item != value).toList());
    await _saveHistory();
  }

  Future<void> _clearHistory() async {
    HapticFeedback.selectionClick();
    setState(() => _history = <String>[]);
    await _saveHistory();
  }

  Future<void> _toggleFollow(UserSearchResult user) async {
    if (_isPending(user.id)) return;
    HapticFeedback.selectionClick();
    setState(() => _pendingActions.add(user.id));

    try {
      final following = await _searchService.toggleFollow(user.id);
      if (!mounted) return;
      setState(() {
        _pendingActions.remove(user.id);
        _results = SmartSearchResult(
          accounts: _results.accounts.map((item) {
            return item.id == user.id
                ? item.copyWith(isFollowing: following)
                : item;
          }).toList(),
          hashtags: _results.hashtags,
          posts: _results.posts,
        );
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _pendingActions.remove(user.id));
      PravaToast.show(
        context,
        message: 'Unable to update follow status',
        type: PravaToastType.error,
      );
    }
  }

  void _openProfile(UserSearchResult user) {
    PravaNavigator.push(
      context,
      PublicProfilePage(
        userId: user.id,
        initialIsFollowing: user.isFollowing,
        initialIsFollowedBy: user.isFollowedBy,
      ),
    );
  }

  void _openAuthor(SmartPostAuthor author) {
    if (author.id.isEmpty) return;
    PravaNavigator.push(context, PublicProfilePage(userId: author.id));
  }

  void _openHashtag(String tag) {
    final normalized = tag.trim().replaceFirst('#', '');
    if (normalized.isEmpty) return;
    PravaNavigator.push(
      context,
      HashtagFeedPage(tag: normalized),
      fullscreenDialog: true,
    );
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
    final surface = isDark
        ? PravaColors.darkBgSurface
        : PravaColors.lightBgSurface;
    final hasQuery = _query.length >= 2;

    return Scaffold(
      body: Stack(
        children: [
          PravaBackground(isDark: isDark),
          SafeArea(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => FocusScope.of(context).unfocus(),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
                    child: Row(
                      children: [
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          constraints: const BoxConstraints.tightFor(
                            width: 38,
                            height: 38,
                          ),
                          padding: EdgeInsets.zero,
                          icon: Icon(
                            CupertinoIcons.chevron_left,
                            color: primary,
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        Expanded(
                          child: _SearchField(
                            controller: _controller,
                            border: border,
                            isDark: isDark,
                          ),
                        ),
                        if (_loading) ...[
                          const SizedBox(width: 10),
                          const CupertinoActivityIndicator(radius: 9),
                        ],
                      ],
                    ),
                  ),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: hasQuery
                          ? _SearchResultsView(
                              key: const ValueKey('results'),
                              result: _results,
                              query: _query,
                              loading: _loading,
                              primary: primary,
                              secondary: secondary,
                              border: border,
                              surface: surface,
                              isDark: isDark,
                              isPending: _isPending,
                              onAccountTap: _openProfile,
                              onAccountAction: _toggleFollow,
                              onHashtagTap: _openHashtag,
                              onAuthorTap: _openAuthor,
                            )
                          : _HistoryView(
                              key: const ValueKey('history'),
                              history: _history,
                              primary: primary,
                              secondary: secondary,
                              border: border,
                              surface: surface,
                              onTap: _applyQuery,
                              onRemove: _removeHistory,
                              onClear: _clearHistory,
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
    return Container(
      height: 42,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
        color: isDark ? Colors.white10 : Colors.white,
      ),
      child: CupertinoSearchTextField(
        controller: controller,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        prefixInsets: const EdgeInsetsDirectional.only(start: 12),
        suffixInsets: const EdgeInsetsDirectional.only(end: 10),
        placeholder: 'Search Prava',
        style: PravaTypography.body.copyWith(
          color: isDark
              ? PravaColors.darkTextPrimary
              : PravaColors.lightTextPrimary,
        ),
      ),
    );
  }
}

class _HistoryView extends StatelessWidget {
  const _HistoryView({
    super.key,
    required this.history,
    required this.primary,
    required this.secondary,
    required this.border,
    required this.surface,
    required this.onTap,
    required this.onRemove,
    required this.onClear,
  });

  final List<String> history;
  final Color primary;
  final Color secondary;
  final Color border;
  final Color surface;
  final ValueChanged<String> onTap;
  final ValueChanged<String> onRemove;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return Center(
        child: Icon(CupertinoIcons.search, color: secondary, size: 34),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 22),
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      children: [
        Row(
          children: [
            Text(
              'Recent',
              style: PravaTypography.h3.copyWith(
                color: primary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onClear,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: Text(
                  'Clear',
                  style: PravaTypography.caption.copyWith(
                    color: PravaColors.accentPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...history.map((item) {
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: border),
            ),
            child: ListTile(
              dense: true,
              leading: Icon(CupertinoIcons.clock, color: secondary, size: 19),
              title: Text(
                item,
                style: PravaTypography.body.copyWith(
                  color: primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              trailing: IconButton(
                icon: Icon(CupertinoIcons.xmark, color: secondary, size: 16),
                onPressed: () => onRemove(item),
              ),
              onTap: () => onTap(item),
            ),
          );
        }),
      ],
    );
  }
}

class _SearchResultsView extends StatelessWidget {
  const _SearchResultsView({
    super.key,
    required this.result,
    required this.query,
    required this.loading,
    required this.primary,
    required this.secondary,
    required this.border,
    required this.surface,
    required this.isDark,
    required this.isPending,
    required this.onAccountTap,
    required this.onAccountAction,
    required this.onHashtagTap,
    required this.onAuthorTap,
  });

  final SmartSearchResult result;
  final String query;
  final bool loading;
  final Color primary;
  final Color secondary;
  final Color border;
  final Color surface;
  final bool isDark;
  final bool Function(String userId) isPending;
  final ValueChanged<UserSearchResult> onAccountTap;
  final ValueChanged<UserSearchResult> onAccountAction;
  final ValueChanged<String> onHashtagTap;
  final ValueChanged<SmartPostAuthor> onAuthorTap;

  @override
  Widget build(BuildContext context) {
    if (loading && result.isEmpty) {
      return const Center(
        child: CupertinoActivityIndicator(color: PravaColors.accentPrimary),
      );
    }
    if (result.isEmpty) {
      return Center(
        child: Text(
          'No results for "$query"',
          style: PravaTypography.body.copyWith(color: secondary),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      children: [
        _CategoryStrip(
          accounts: result.accounts.length,
          hashtags: result.hashtags.length,
          posts: result.posts.length,
          primary: primary,
          secondary: secondary,
          border: border,
        ),
        if (result.accounts.isNotEmpty)
          _HorizontalSection(
            title: 'Accounts',
            height: 132,
            primary: primary,
            children: result.accounts.map((account) {
              return _AccountCard(
                user: account,
                pending: isPending(account.id),
                primary: primary,
                secondary: secondary,
                border: border,
                surface: surface,
                onTap: () => onAccountTap(account),
                onAction: () => onAccountAction(account),
              );
            }).toList(),
          ),
        if (result.hashtags.isNotEmpty)
          _HorizontalSection(
            title: 'Hashtags',
            height: 88,
            primary: primary,
            children: result.hashtags.map((tag) {
              return _HashtagCard(
                tag: tag,
                primary: primary,
                secondary: secondary,
                border: border,
                surface: surface,
                onTap: () => onHashtagTap(tag.tag),
              );
            }).toList(),
          ),
        if (result.posts.isNotEmpty)
          _HorizontalSection(
            title: 'Posts',
            height: 164,
            primary: primary,
            children: result.posts.map((post) {
              return _PostResultCard(
                post: post,
                primary: primary,
                secondary: secondary,
                border: border,
                surface: surface,
                onAuthorTap: () => onAuthorTap(post.author),
                onHashtagTap: onHashtagTap,
              );
            }).toList(),
          ),
      ],
    );
  }
}

class _CategoryStrip extends StatelessWidget {
  const _CategoryStrip({
    required this.accounts,
    required this.hashtags,
    required this.posts,
    required this.primary,
    required this.secondary,
    required this.border,
  });

  final int accounts;
  final int hashtags;
  final int posts;
  final Color primary;
  final Color secondary;
  final Color border;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Accounts', accounts, CupertinoIcons.person_2_fill),
      ('Hashtags', hashtags, CupertinoIcons.number_circle_fill),
      ('Posts', posts, CupertinoIcons.news_solid),
    ];
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = items[index];
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: border),
            ),
            child: Row(
              children: [
                Icon(item.$3, size: 15, color: PravaColors.accentPrimary),
                const SizedBox(width: 6),
                Text(
                  '${item.$1} ${item.$2}',
                  style: PravaTypography.caption.copyWith(
                    color: item.$2 > 0 ? primary : secondary,
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

class _HorizontalSection extends StatelessWidget {
  const _HorizontalSection({
    required this.title,
    required this.height,
    required this.primary,
    required this.children,
  });

  final String title;
  final double height;
  final Color primary;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: PravaTypography.h3.copyWith(
              color: primary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: height,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: children.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) => children[index],
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.user,
    required this.pending,
    required this.primary,
    required this.secondary,
    required this.border,
    required this.surface,
    required this.onTap,
    required this.onAction,
  });

  final UserSearchResult user;
  final bool pending;
  final Color primary;
  final Color secondary;
  final Color border;
  final Color surface;
  final VoidCallback onTap;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 172,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 19,
              backgroundColor: PravaColors.accentPrimary.withValues(
                alpha: 0.14,
              ),
              child: Text(
                user.username.isNotEmpty ? user.username[0].toUpperCase() : '@',
                style: PravaTypography.body.copyWith(
                  color: PravaColors.accentPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              user.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: PravaTypography.body.copyWith(
                color: primary,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              '@${user.username}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: PravaTypography.caption.copyWith(color: secondary),
            ),
            const Spacer(),
            _FollowMiniButton(
              following: user.isFollowing,
              pending: pending,
              onTap: onAction,
            ),
          ],
        ),
      ),
    );
  }
}

class _FollowMiniButton extends StatelessWidget {
  const _FollowMiniButton({
    required this.following,
    required this.pending,
    required this.onTap,
  });

  final bool following;
  final bool pending;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: pending ? null : onTap,
      child: Container(
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: following ? Colors.transparent : PravaColors.accentPrimary,
          borderRadius: BorderRadius.circular(999),
          border: following
              ? Border.all(color: PravaColors.accentPrimary)
              : null,
        ),
        child: pending
            ? const CupertinoActivityIndicator(radius: 8)
            : Text(
                following ? 'Following' : 'Follow',
                style: PravaTypography.caption.copyWith(
                  color: following ? PravaColors.accentPrimary : Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
      ),
    );
  }
}

class _HashtagCard extends StatelessWidget {
  const _HashtagCard({
    required this.tag,
    required this.primary,
    required this.secondary,
    required this.border,
    required this.surface,
    required this.onTap,
  });

  final SmartHashtagResult tag;
  final Color primary;
  final Color secondary;
  final Color border;
  final Color surface;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 160,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            const Icon(
              CupertinoIcons.number_circle_fill,
              color: PravaColors.accentPrimary,
              size: 26,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '#${tag.tag}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PravaTypography.body.copyWith(
                      color: primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    '${tag.postCount} posts',
                    style: PravaTypography.caption.copyWith(color: secondary),
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

class _PostResultCard extends StatelessWidget {
  const _PostResultCard({
    required this.post,
    required this.primary,
    required this.secondary,
    required this.border,
    required this.surface,
    required this.onAuthorTap,
    required this.onHashtagTap,
  });

  final SmartPostResult post;
  final Color primary;
  final Color secondary;
  final Color border;
  final Color surface;
  final VoidCallback onAuthorTap;
  final ValueChanged<String> onHashtagTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 244,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onAuthorTap,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 13,
                  backgroundColor: PravaColors.accentPrimary.withValues(
                    alpha: 0.14,
                  ),
                  child: Text(
                    post.author.username.isNotEmpty
                        ? post.author.username[0].toUpperCase()
                        : '@',
                    style: PravaTypography.caption.copyWith(
                      color: PravaColors.accentPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '@${post.author.username}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PravaTypography.caption.copyWith(
                      color: secondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            post.body,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: PravaTypography.body.copyWith(
              color: primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          if (post.hashtags.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: post.hashtags.take(2).map((tag) {
                return GestureDetector(
                  onTap: () => onHashtagTap(tag),
                  child: Text(
                    '#$tag',
                    style: PravaTypography.caption.copyWith(
                      color: PravaColors.accentPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 8),
          Text(
            '${post.likeCount} likes - ${post.commentCount} comments',
            style: PravaTypography.caption.copyWith(color: secondary),
          ),
        ],
      ),
    );
  }
}
