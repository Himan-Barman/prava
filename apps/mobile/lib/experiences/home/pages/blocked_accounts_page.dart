import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

import '../../../services/privacy_service.dart';
import '../../../ui-system/colors.dart';
import '../../../ui-system/typography.dart';
import '../../../ui-system/feedback/prava_toast.dart';
import '../../../ui-system/feedback/toast_type.dart';
import 'settings_detail_shell.dart';

class BlockedAccountsPage extends StatefulWidget {
  const BlockedAccountsPage({super.key});

  @override
  State<BlockedAccountsPage> createState() => _BlockedAccountsPageState();
}

class _BlockedAccountsPageState extends State<BlockedAccountsPage> {
  final PrivacyService _service = PrivacyService();
  bool _loading = true;
  List<BlockedUser> _items = [];

  @override
  void initState() {
    super.initState();
    _loadBlocked();
  }

  Future<void> _loadBlocked() async {
    try {
      final items = await _service.fetchBlocked();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      PravaToast.show(
        context,
        message: 'Unable to load blocked accounts',
        type: PravaToastType.error,
      );
    }
  }

  Future<void> _unblock(BlockedUser user) async {
    try {
      await _service.unblockUser(user.id);
      if (!mounted) return;
      setState(() {
        _items = List<BlockedUser>.from(_items)
          ..removeWhere((item) => item.id == user.id);
      });
      PravaToast.show(
        context,
        message: 'Unblocked ${user.displayName}',
        type: PravaToastType.success,
      );
    } catch (_) {
      if (!mounted) return;
      PravaToast.show(
        context,
        message: 'Unable to unblock account',
        type: PravaToastType.error,
      );
    }
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
    final border =
        isDark ? PravaColors.darkBorderSubtle : PravaColors.lightBorderSubtle;

    return SettingsDetailShell(
      title: 'Blocked accounts',
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? Center(
                  child: Text(
                    'No blocked accounts',
                    style: PravaTypography.body.copyWith(color: secondary),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: _items.length,
                  itemBuilder: (context, index) {
                    final user = _items[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: BackdropFilter(
                          filter:
                              ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: surface,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: border),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor:
                                      PravaColors.accentPrimary.withValues(
                                    alpha: 0.15,
                                  ),
                                  child: Text(
                                    user.displayName.isNotEmpty
                                        ? user.displayName
                                            .substring(0, 1)
                                            .toUpperCase()
                                        : 'P',
                                    style: PravaTypography.body.copyWith(
                                      color: PravaColors.accentPrimary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              user.displayName,
                                              maxLines: 1,
                                              overflow:
                                                  TextOverflow.ellipsis,
                                              style: PravaTypography.body
                                                  .copyWith(
                                                color: primary,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          if (user.isVerified) ...[
                                            const SizedBox(width: 6),
                                            Icon(
                                              CupertinoIcons
                                                  .check_mark_circled_solid,
                                              size: 16,
                                              color: PravaColors.accentPrimary,
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '@${user.username}',
                                        style:
                                            PravaTypography.caption.copyWith(
                                          color: secondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => _unblock(user),
                                  child: Text(
                                    'Unblock',
                                    style: PravaTypography.button.copyWith(
                                      color: PravaColors.accentPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
