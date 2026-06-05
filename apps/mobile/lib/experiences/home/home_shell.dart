import 'dart:async';

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
import '../../services/notification_permission_service.dart';
import '../../services/platform_bridge_service.dart';
import '../../services/settings_service.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with TickerProviderStateMixin {
  int _index = 0;
  bool _isAnimatingToIndex = false;
  bool _feedChromeVisible = true;
  int? _targetIndex;

  late final PageController _pageController;
  late final List<Widget> _pages;
  late final E2eeKeyRefreshScheduler _keyRefreshScheduler =
      E2eeKeyRefreshScheduler();
  late final PlatformBridgeService _platformBridge = PlatformBridgeService();
  late final NotificationPermissionService _notificationPermissions =
      NotificationPermissionService();
  late final SettingsService _settingsService = SettingsService();
  final ChatsPageController _chatsController = ChatsPageController();
  final ProfilePageController _profileController = ProfilePageController();

  final _keys = List.generate(4, (_) => GlobalKey<NavigatorState>());

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _index);
    _pages = _buildPages();
    _keyRefreshScheduler.start();
    unawaited(_requestStartupPermissions());
  }

  @override
  void dispose() {
    _keyRefreshScheduler.stop();
    _pageController.dispose();
    super.dispose();
  }

  // ------------------------------------------------
  // Bottom bar animated page switch
  // ------------------------------------------------
  void _onTabChange(int index) {
    if (index == _index) {
      _keys[index].currentState?.popUntil((route) => route.isFirst);
    } else {
      HapticFeedback.selectionClick();

      setState(() {
        _index = index;
        _feedChromeVisible = true;
        _isAnimatingToIndex = true;
        _targetIndex = index;
      });

      final target = index;
      _pageController
          .animateToPage(
            index,
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic, // WhatsApp-like
          )
          .whenComplete(() {
            if (!mounted) return;
            if (_targetIndex == target) {
              setState(() => _isAnimatingToIndex = false);
            }
          });
    }
  }

  void _setFeedChromeVisible(bool visible) {
    if (!mounted) return;
    if (_feedChromeVisible == visible) return;
    setState(() => _feedChromeVisible = visible);
  }

  Future<void> _requestStartupPermissions() async {
    await _platformBridge.requestLocationTimeAccess();
    final permission = await _notificationPermissions.requestPermission();
    if (!permission.canDeliver) return;

    try {
      final settings = await _settingsService.loadLocal();
      if (!settings.pushNotifications) {
        final next = settings.copyWith(pushNotifications: true);
        await _settingsService.saveLocal(next);
        await _settingsService.saveRemote(next);
      }
    } catch (_) {
      // Permission prompts should never block the home shell.
    }
  }

  void _handleChatMenu(ChatTopMenuAction action) {
    switch (action) {
      case ChatTopMenuAction.newGroup:
        _chatsController.openNewGroup();
        break;
      case ChatTopMenuAction.broadcasts:
        _chatsController.showBroadcasts();
        break;
      case ChatTopMenuAction.starred:
        _chatsController.showStarred();
        break;
      case ChatTopMenuAction.messageRequests:
        _chatsController.openMessageRequests();
        break;
    }
  }

  // ------------------------------------------------
  // Per-tab pages (kept alive)
  // ------------------------------------------------
  List<Widget> _buildPages() => [
    _KeepAliveTab(
      child: TabNavigator(
        navigatorKey: _keys[0],
        child: FeedPage(onChromeVisibilityChanged: _setFeedChromeVisible),
      ),
    ),
    _KeepAliveTab(
      child: TabNavigator(
        navigatorKey: _keys[1],
        child: ChatsPage(controller: _chatsController),
      ),
    ),
    _KeepAliveTab(
      child: TabNavigator(navigatorKey: _keys[2], child: const FriendsPage()),
    ),
    _KeepAliveTab(
      child: TabNavigator(
        navigatorKey: _keys[3],
        child: ProfilePage(controller: _profileController),
      ),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final chromeVisible = _index != 0 || _feedChromeVisible;

    return WillPopScope(
      onWillPop: () async {
        final canPop = await _keys[_index].currentState?.maybePop() ?? false;
        return !canPop;
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              /// Fixed top bar
              _ShellChromeVisibility(
                visible: chromeVisible,
                child: HomeTopBar(
                  tabIndex: _index,
                  onChatMenuSelected: _handleChatMenu,
                  onProfileEdit: _profileController.openEditor,
                ),
              ),

              /// Swipeable + animated content
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: 4,

                  // WhatsApp-style resistance
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
                          value = (1 - (value * 0.15)).clamp(0.9, 1.0);
                        }

                        return Opacity(
                          opacity: value,
                          child: Transform.translate(
                            offset: Offset((1 - value) * 30, 0),
                            child: child,
                          ),
                        );
                      },
                      child: _pages[i],
                    );
                  },
                ),
              ),
            ],
          ),
        ),

        /// Bottom bar
        bottomNavigationBar: _ShellChromeVisibility(
          visible: chromeVisible,
          child: HomeBottomBar(index: _index, onChanged: _onTabChange),
        ),
      ),
    );
  }
}

class _ShellChromeVisibility extends StatelessWidget {
  const _ShellChromeVisibility({required this.visible, required this.child});

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: ClipRect(
        child: Align(
          alignment: Alignment.topCenter,
          heightFactor: visible ? 1 : 0,
          child: AnimatedOpacity(
            opacity: visible ? 1 : 0,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOutCubic,
            child: child,
          ),
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
