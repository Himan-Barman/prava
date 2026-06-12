import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/storage/secure_store.dart';
import '../../../navigation/prava_navigator.dart';
import '../../../services/chat_service.dart';
import '../../../services/user_search_service.dart';
import '../../../ui-system/background.dart';
import '../../../ui-system/colors.dart';
import '../../../ui-system/feedback/prava_toast.dart';
import '../../../ui-system/feedback/toast_type.dart';
import '../../../ui-system/typography.dart';
import '../tabs/chats/chat_thread_page.dart';
import '../tabs/chats/chats_page.dart';
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
  final ChatService _chatService = ChatService();
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

  Future<void> _handleAccountAction(UserSearchResult user) async {
    if (user.isFriend) {
      await _openChat(user);
      return;
    }
    await _setFollow(user);
  }

  Future<void> _setFollow(UserSearchResult user) async {
    if (_isPending(user.id)) return;
    HapticFeedback.selectionClick();
    setState(() => _pendingActions.add(user.id));

    try {
      final following = await _searchService.setFollow(user.id, true);
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

  Future<void> _openChat(UserSearchResult user) async {
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
      if (mounted) setState(() => _pendingActions.remove(user.id));
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
    final tokens = context.pravaColors;
    final primary = tokens.textPrimary;
    final secondary = tokens.textSecondary;
    final border = tokens.borderSubtle;
    final surface = tokens.backgroundSurface;
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
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Search',
                          style: PravaTypography.h2.copyWith(
                            color: primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _SearchField(controller: _controller),
                            ),
                            if (_loading) ...[
                              const SizedBox(width: 10),
                              const CupertinoActivityIndicator(radius: 9),
                            ],
                          ],
                        ),
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
                              isPending: _isPending,
                              onAccountTap: _openProfile,
                              onAccountAction: _handleAccountAction,
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
  const _SearchField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final tokens = context.pravaColors;
    return Container(
      height: 44,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tokens.borderDefault),
        color: tokens.backgroundSurfaceSubtle,
      ),
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, child) {
          return TextField(
            controller: controller,
            textInputAction: TextInputAction.search,
            cursorColor: tokens.brandPrimary,
            style: PravaTypography.body.copyWith(
              color: tokens.textPrimary,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              hintText: 'Search Prava',
              hintStyle: PravaTypography.body.copyWith(
                color: tokens.textTertiary,
              ),
              contentPadding: const EdgeInsets.fromLTRB(16, 11, 8, 11),
              suffixIcon: value.text.isEmpty
                  ? null
                  : IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      icon: Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: tokens.iconSecondary,
                      ),
                      onPressed: controller.clear,
                    ),
            ),
          );
        },
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
    final tokens = context.pravaColors;
    if (history.isEmpty) {
      return const SizedBox.expand();
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
                    color: tokens.brandContent,
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
  final bool Function(String userId) isPending;
  final ValueChanged<UserSearchResult> onAccountTap;
  final ValueChanged<UserSearchResult> onAccountAction;
  final ValueChanged<String> onHashtagTap;
  final ValueChanged<SmartPostAuthor> onAuthorTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.pravaColors;
    if (loading && result.isEmpty) {
      return Center(
        child: CupertinoActivityIndicator(color: tokens.brandPrimary),
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
          _AccountSection(
            title: 'Accounts',
            primary: primary,
            children: result.accounts
                .map(
                  (account) => _AccountResultRow(
                    user: account,
                    pending: isPending(account.id),
                    primary: primary,
                    secondary: secondary,
                    border: border,
                    surface: surface,
                    onTap: () => onAccountTap(account),
                    onAction: () => onAccountAction(account),
                  ),
                )
                .toList(),
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
    final tokens = context.pravaColors;
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
                Icon(item.$3, size: 15, color: tokens.brandContent),
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

class _AccountSection extends StatelessWidget {
  const _AccountSection({
    required this.title,
    required this.primary,
    required this.children,
  });

  final String title;
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
          ...children,
        ],
      ),
    );
  }
}

class _AccountResultRow extends StatelessWidget {
  const _AccountResultRow({
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

  String get _actionLabel {
    if (user.isFriend) return 'Message';
    if (user.isFollowedByOnly) return 'Accept request';
    if (user.isRequested) return 'Requested';
    return 'Add friend';
  }

  bool get _actionEnabled => !pending && !user.isRequested;

  @override
  Widget build(BuildContext context) {
    final tokens = context.pravaColors;
    final displayName = user.displayName.isNotEmpty
        ? user.displayName
        : user.username;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: border),
          ),
          child: Row(
            children: [
              _AccountAvatar(user: user),
              const SizedBox(width: 12),
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
              _AccountActionButton(
                label: _actionLabel,
                pending: pending,
                enabled: _actionEnabled,
                onTap: onAction,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountAvatar extends StatelessWidget {
  const _AccountAvatar({required this.user});

  final UserSearchResult user;

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

class _AccountActionButton extends StatelessWidget {
  const _AccountActionButton({
    required this.label,
    required this.pending,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool pending;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.pravaColors;
    final disabled = !enabled;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: disabled ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 34,
        constraints: const BoxConstraints(minWidth: 86, maxWidth: 126),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: disabled ? tokens.brandContainer : tokens.brandPrimary,
          borderRadius: BorderRadius.circular(999),
          border: disabled ? Border.all(color: tokens.brandPrimary) : null,
        ),
        child: pending
            ? const CupertinoActivityIndicator(radius: 8)
            : Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: PravaTypography.caption.copyWith(
                  color: disabled ? tokens.brandContent : tokens.textInverse,
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
    final tokens = context.pravaColors;
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
            Icon(
              CupertinoIcons.number_circle_fill,
              color: tokens.brandContent,
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
    final tokens = context.pravaColors;
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
                  backgroundColor: tokens.brandContainer,
                  child: Text(
                    post.author.username.isNotEmpty
                        ? post.author.username[0].toUpperCase()
                        : '@',
                    style: PravaTypography.caption.copyWith(
                      color: tokens.brandContent,
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
                      color: tokens.linkDefault,
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
