import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../../ui-system/colors.dart';
import '../../../ui-system/typography.dart';
import '../../../navigation/prava_navigator.dart';

import '../pages/new_group_page.dart';
import '../pages/broadcast_page.dart';
import '../pages/starred_messages_page.dart';
import '../pages/archived_chats_page.dart';
import '../pages/settings_page.dart';
import '../../auth/login_screen.dart';

const _menuWidth = 232.0;

class HomeOverflowMenu {
  static void show(BuildContext context) {
    final tokens = context.pravaColors;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final size = overlay.size;
    final menuLeft = size.width - _menuWidth - 16;
    final menuColor = tokens.backgroundSurfaceRaised;
    final borderColor = tokens.borderSubtle;

    showMenu<void>(
      context: context,
      position: RelativeRect.fromLTRB(menuLeft, kToolbarHeight + 24, 16, 0),
      color: menuColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: borderColor),
      ),
      elevation: 12,
      items: <PopupMenuEntry<void>>[
        _menuItem(
          context,
          icon: CupertinoIcons.group,
          label: "New group",
          page: const NewGroupPage(),
        ),
        _menuItem(
          context,
          icon: CupertinoIcons.speaker_2,
          label: "New broadcast",
          page: const BroadcastPage(),
        ),
        const PopupMenuDivider(),

        _menuItem(
          context,
          icon: CupertinoIcons.star,
          label: "Starred messages",
          page: const StarredMessagesPage(),
        ),
        _menuItem(
          context,
          icon: CupertinoIcons.archivebox,
          label: "Archived chats",
          page: const ArchivedChatsPage(),
        ),
        const PopupMenuDivider(),

        _menuItem(
          context,
          icon: CupertinoIcons.settings,
          label: "Settings",
          page: const SettingsPage(),
        ),
        const PopupMenuDivider(),

        _menuItem(
          context,
          icon: CupertinoIcons.square_arrow_right,
          label: "Log out",
          destructive: true,
          onTap: () {
            PravaNavigator.pushAndRemoveUntil(
              context,
              const LoginScreen(),
              (_) => false,
            );
          },
        ),
      ],
    );
  }

  static PopupMenuItem<void> _menuItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    Widget? page,
    VoidCallback? onTap,
    bool destructive = false,
  }) {
    final tokens = context.pravaColors;
    final iconBackground = destructive
        ? tokens.statusErrorContainer
        : tokens.brandContainer;
    final iconBorder = tokens.borderSubtle;
    final labelColor = destructive ? tokens.statusError : tokens.textPrimary;
    final captionColor = tokens.textTertiary;

    final navigator = Navigator.of(context);

    return PopupMenuItem<void>(
      height: 54,
      onTap: () {
        HapticFeedback.selectionClick();
        Future.microtask(() {
          if (onTap != null) {
            onTap();
          } else if (page != null) {
            navigator.push(PravaNavigator.route(page));
          }
        });
      },
      child: SizedBox(
        width: _menuWidth,
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: iconBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: iconBorder),
              ),
              child: Icon(
                icon,
                size: 18,
                color: destructive ? tokens.statusError : tokens.brandContent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: PravaTypography.body.copyWith(
                  color: labelColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(CupertinoIcons.chevron_right, size: 14, color: captionColor),
          ],
        ),
      ),
    );
  }
}
