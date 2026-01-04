import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'widgets/home_top_bar.dart';
import 'widgets/home_bottom_bar.dart';
import 'widgets/tab_navigator.dart';

import 'tabs/feed/feed_page.dart';
import 'tabs/chats/chats_page.dart';
import 'tabs/friends/friends_page.dart';
import 'tabs/profile/profile_page.dart';
import '../../services/e2ee_scheduler.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell>
    with TickerProviderStateMixin {
  int _index = 0;
  bool _isAnimatingToIndex = false;
  int? _targetIndex;

  late final PageController _pageController;
  late final E2eeKeyRefreshScheduler _keyRefreshScheduler =
      E2eeKeyRefreshScheduler();

  final _keys = List.generate(
    4,
    (_) => GlobalKey<NavigatorState>(),
  );

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _index);
    _keyRefreshScheduler.start();
  }

  @override
  void dispose() {
    _keyRefreshScheduler.stop();
    _pageController.dispose();
    super.dispose();
  }

  // ------------------------------------------------
  // Bottom bar → animated page switch
  // ------------------------------------------------
  void _onTabChange(int index) {
    if (index == _index) {
      _keys[index]
          .currentState
          ?.popUntil((route) => route.isFirst);
    } else {
      HapticFeedback.selectionClick();

      setState(() {
        _index = index;
        _isAnimatingToIndex = true;
        _targetIndex = index;
      });

      final target = index;
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic, // WhatsApp-like
      ).whenComplete(() {
        if (!mounted) return;
        if (_targetIndex == target) {
          setState(() => _isAnimatingToIndex = false);
        }
      });
    }
  }

  // ------------------------------------------------
  // Per-tab pages (kept alive)
  // ------------------------------------------------
  List<Widget> _buildPages() => [
        _KeepAliveTab(
          child: TabNavigator(
            navigatorKey: _keys[0],
            child: const FeedPage(),
          ),
        ),
        _KeepAliveTab(
          child: TabNavigator(
            navigatorKey: _keys[1],
            child: const ChatsPage(),
          ),
        ),
        _KeepAliveTab(
          child: TabNavigator(
            navigatorKey: _keys[2],
            child: const FriendsPage(),
          ),
        ),
        _KeepAliveTab(
          child: TabNavigator(
            navigatorKey: _keys[3],
            child: const ProfilePage(),
          ),
        ),
      ];

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        final canPop =
            await _keys[_index].currentState?.maybePop() ?? false;
        return !canPop;
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              /// 🔝 Fixed top bar
              const HomeTopBar(),

              /// 📄 Swipeable + animated content
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: 4,

                  // ✅ WhatsApp-style resistance
                  physics: const PageScrollPhysics().applyTo(
                    const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                  ),

                  onPageChanged: (i) {
                    if (_isAnimatingToIndex) {
                      if (i == _targetIndex) {
                        setState(() {
                          _isAnimatingToIndex = false;
                          _index = i;
                        });
                      }
                      return;
                    }

                    HapticFeedback.selectionClick();
                    setState(() => _index = i);
                  },

                  itemBuilder: (context, i) {
                    return AnimatedBuilder(
                      animation: _pageController,
                      builder: (context, child) {
                        double value = 1.0;

                        if (_pageController.position.haveDimensions) {
                          value = (_pageController.page! - i).abs();
                          value = (1 - (value * 0.15))
                              .clamp(0.9, 1.0);
                        }

                        return Opacity(
                          opacity: value,
                          child: Transform.translate(
                            offset: Offset(
                              (1 - value) * 30,
                              0,
                            ),
                            child: child,
                          ),
                        );
                      },
                      child: _buildPages()[i],
                    );
                  },
                ),
              ),
            ],
          ),
        ),

        /// ⬇️ Bottom bar
        bottomNavigationBar: HomeBottomBar(
          index: _index,
          onChanged: _onTabChange,
        ),
      ),
    );
  }
}

/// ------------------------------------------------
/// Keeps each tab alive (state restoration)
/// ------------------------------------------------
class _KeepAliveTab extends StatefulWidget {
  final Widget child;
  const _KeepAliveTab({required this.child});

  @override
  State<_KeepAliveTab> createState() => _KeepAliveTabState();
}

class _KeepAliveTabState extends State<_KeepAliveTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
