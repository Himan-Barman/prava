import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../services/chat_service.dart';
import '../../../services/user_search_service.dart';
import '../../../ui-system/background.dart';
import '../../../ui-system/colors.dart';
import '../../../ui-system/typography.dart';
import '../../../ui-system/feedback/prava_toast.dart';
import '../../../ui-system/feedback/toast_type.dart';

class NewGroupPage extends StatefulWidget {
  const NewGroupPage({super.key});

  @override
  State<NewGroupPage> createState() => _NewGroupPageState();
}

class _NewGroupPageState extends State<NewGroupPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final UserSearchService _userSearchService = UserSearchService();
  final ChatService _chatService = ChatService();

  final Map<String, UserSearchResult> _selectedById =
      <String, UserSearchResult>{};
  List<UserSearchResult> _results = <UserSearchResult>[];
  Timer? _searchDebounce;
  bool _searching = false;
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _nameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    _searchDebounce?.cancel();

    if (query.length < 2) {
      if (mounted) {
        setState(() {
          _results = <UserSearchResult>[];
          _searching = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() => _searching = true);
    }

    _searchDebounce = Timer(const Duration(milliseconds: 280), () async {
      try {
        final results = await _userSearchService.searchUsers(query, limit: 20);
        if (!mounted) return;
        setState(() {
          _results = results;
          _searching = false;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() => _searching = false);
      }
    });
  }

  bool get _canCreate =>
      _nameController.text.trim().isNotEmpty &&
      _selectedById.isNotEmpty &&
      !_creating;

  void _toggleMember(UserSearchResult user) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedById.containsKey(user.id)) {
        _selectedById.remove(user.id);
      } else {
        _selectedById[user.id] = user;
      }
    });
  }

  Future<void> _createGroup() async {
    if (!_canCreate) {
      PravaToast.show(
        context,
        message: 'Add a group name and at least one member.',
        type: PravaToastType.warning,
      );
      return;
    }

    setState(() => _creating = true);
    try {
      final conversationId = await _chatService.createGroup(
        title: _nameController.text.trim(),
        memberIds: _selectedById.keys.toList(),
      );

      if (!mounted) return;
      if (conversationId == null || conversationId.isEmpty) {
        throw StateError('Missing conversation id');
      }

      PravaToast.show(
        context,
        message: 'Group created',
        type: PravaToastType.success,
      );
      Navigator.of(context).pop(conversationId);
    } catch (_) {
      if (!mounted) return;
      PravaToast.show(
        context,
        message: 'Failed to create group',
        type: PravaToastType.error,
      );
      setState(() => _creating = false);
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
    final surface = isDark
        ? PravaColors.darkBgSurface
        : PravaColors.lightBgSurface;

    return Scaffold(
      body: Stack(
        children: [
          PravaBackground(isDark: isDark),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(CupertinoIcons.back),
                        color: PravaColors.accentPrimary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'New group',
                          style: PravaTypography.h2.copyWith(
                            color: primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: border),
                    ),
                    child: TextField(
                      controller: _nameController,
                      style: PravaTypography.body.copyWith(color: primary),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Group name',
                        hintStyle: PravaTypography.body.copyWith(
                          color: secondary,
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: border),
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: PravaTypography.body.copyWith(color: primary),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Search members',
                        hintStyle: PravaTypography.body.copyWith(
                          color: secondary,
                        ),
                        prefixIcon: const Icon(CupertinoIcons.search),
                      ),
                    ),
                  ),
                ),
                if (_selectedById.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _selectedById.values.map((user) {
                        return Chip(
                          label: Text(user.displayName),
                          deleteIcon: const Icon(
                            CupertinoIcons.xmark,
                            size: 14,
                          ),
                          onDeleted: () => _toggleMember(user),
                        );
                      }).toList(),
                    ),
                  ),
                Expanded(
                  child: _searching
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: PravaColors.accentPrimary,
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          itemCount: _results.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final user = _results[index];
                            final selected = _selectedById.containsKey(user.id);
                            return ListTile(
                              tileColor: surface,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: BorderSide(color: border),
                              ),
                              onTap: () => _toggleMember(user),
                              leading: CircleAvatar(
                                backgroundColor: PravaColors.accentPrimary
                                    .withValues(alpha: 0.14),
                                child: Text(
                                  user.displayName.isNotEmpty
                                      ? user.displayName[0].toUpperCase()
                                      : '?',
                                  style: PravaTypography.body.copyWith(
                                    color: PravaColors.accentPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              title: Text(
                                user.displayName,
                                style: PravaTypography.body.copyWith(
                                  color: primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                '@${user.username}',
                                style: PravaTypography.caption.copyWith(
                                  color: secondary,
                                ),
                              ),
                              trailing: Icon(
                                selected
                                    ? CupertinoIcons.checkmark_circle_fill
                                    : CupertinoIcons.add_circled,
                                color: selected
                                    ? PravaColors.accentPrimary
                                    : secondary,
                              ),
                            );
                          },
                        ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _canCreate ? _createGroup : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: PravaColors.accentPrimary,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey.shade500,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(_creating ? 'Creating...' : 'Create group'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
