import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../../ui-system/background.dart';
import '../../../ui-system/colors.dart';
import '../../../ui-system/typography.dart';
import '../../../ui-system/feedback/prava_toast.dart';
import '../../../ui-system/feedback/toast_type.dart';

class StarredMessagesPage extends StatefulWidget {
  const StarredMessagesPage({super.key});

  @override
  State<StarredMessagesPage> createState() => _StarredMessagesPageState();
}

class _StarredMessagesPageState extends State<StarredMessagesPage> {
  final TextEditingController _searchController = TextEditingController();

  _StarFilter _filter = _StarFilter.all;
  List<_StarredMessage> _messages = List<_StarredMessage>.from(_seedMessages);

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _clearAll() {
    if (_messages.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() => _messages.clear());
    PravaToast.show(
      context,
      message: 'Starred messages cleared',
      type: PravaToastType.success,
    );
  }

  void _unstar(_StarredMessage message) {
    HapticFeedback.selectionClick();
    setState(() => _messages.removeWhere((item) => item.id == message.id));
    PravaToast.show(
      context,
      message: 'Removed from starred',
      type: PravaToastType.info,
    );
  }

  List<_StarredMessage> get _visibleMessages {
    final query = _searchController.text.trim().toLowerCase();
    final filtered = _filter == _StarFilter.all
        ? _messages
        : _messages
            .where((item) => item.type == _filter.type)
            .toList();

    if (query.isEmpty) return filtered;
    return filtered
        .where(
          (item) =>
              item.chatName.toLowerCase().contains(query) ||
              item.body.toLowerCase().contains(query),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary =
        isDark ? PravaColors.darkTextPrimary : PravaColors.lightTextPrimary;
    final secondary =
        isDark ? PravaColors.darkTextSecondary : PravaColors.lightTextSecondary;
    final border =
        isDark ? PravaColors.darkBorderSubtle : PravaColors.lightBorderSubtle;

    final messages = _visibleMessages;

    return Scaffold(
      body: Stack(
        children: [
          _PageBackdrop(isDark: isDark),
          SafeArea(
            child: Column(
              children: [
                _TopBar(
                  title: 'Starred',
                  onBack: () => Navigator.of(context).pop(),
                  onClear: _clearAll,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: _SearchField(
                    controller: _searchController,
                    border: border,
                    isDark: isDark,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: _FilterRow(
                    filter: _filter,
                    onChanged: (next) {
                      HapticFeedback.selectionClick();
                      setState(() => _filter = next);
                    },
                  ),
                ),
                Expanded(
                  child: messages.isEmpty
                      ? _EmptyState(
                          hasQuery: _searchController.text.trim().isNotEmpty,
                          primary: primary,
                          secondary: secondary,
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          physics: const BouncingScrollPhysics(
                            parent: AlwaysScrollableScrollPhysics(),
                          ),
                          itemCount: messages.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final message = messages[index];
                            return _StarredMessageCard(
                              message: message,
                              isDark: isDark,
                              primary: primary,
                              secondary: secondary,
                              onUnstar: () => _unstar(message),
                            );
                          },
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

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.onBack,
    required this.onClear,
  });

  final String title;
  final VoidCallback onBack;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary =
        isDark ? PravaColors.darkTextPrimary : PravaColors.lightTextPrimary;
    final surface =
        isDark ? Colors.black.withValues(alpha: 0.45) : Colors.white.withValues(alpha: 0.8);
    final border =
        isDark ? PravaColors.darkBorderSubtle : PravaColors.lightBorderSubtle;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: border),
            ),
            child: Row(
              children: [
                _IconPill(
                  icon: CupertinoIcons.back,
                  onTap: onBack,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: PravaTypography.h3.copyWith(
                      color: primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onClear,
                  icon: const Icon(CupertinoIcons.trash),
                  color: PravaColors.accentPrimary,
                  tooltip: 'Clear all',
                ),
              ],
            ),
          ),
        ),
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.white10 : Colors.white.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: border),
          ),
          child: CupertinoSearchTextField(
            controller: controller,
            placeholder: 'Search starred messages',
            backgroundColor: Colors.transparent,
          ),
        ),
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({required this.filter, required this.onChanged});

  final _StarFilter filter;
  final ValueChanged<_StarFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = PravaColors.accentPrimary;
    final surface =
        isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05);
    final textColor =
        isDark ? PravaColors.darkTextPrimary : PravaColors.lightTextPrimary;

    return Row(
      children: _StarFilter.values.map((item) {
        final selected = filter == item;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            label: Text(
              item.label,
              style: PravaTypography.caption.copyWith(
                color: selected ? Colors.white : textColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            selected: selected,
            selectedColor: activeColor,
            backgroundColor: surface,
            onSelected: (_) => onChanged(item),
          ),
        );
      }).toList(),
    );
  }
}

class _StarredMessageCard extends StatelessWidget {
  const _StarredMessageCard({
    required this.message,
    required this.isDark,
    required this.primary,
    required this.secondary,
    required this.onUnstar,
  });

  final _StarredMessage message;
  final bool isDark;
  final Color primary;
  final Color secondary;
  final VoidCallback onUnstar;

  Color _avatarColor(String name) {
    const palette = [
      Color(0xFF5B8CFF),
      Color(0xFF2EC4B6),
      Color(0xFFFFB703),
      Color(0xFFFF6B6B),
      Color(0xFF845EC2),
    ];
    final hash = name.codeUnits.fold<int>(0, (acc, c) => acc + c);
    return palette[hash % palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final accent = _avatarColor(message.chatName);
    final surface = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.white.withValues(alpha: 0.9);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? PravaColors.darkBorderSubtle
              : PravaColors.lightBorderSubtle,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: accent.withValues(alpha: 0.18),
                child: Text(
                  message.initials,
                  style: PravaTypography.h3.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message.chatName,
                      style: PravaTypography.body.copyWith(
                        color: primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      message.timeLabel,
                      style: PravaTypography.caption.copyWith(color: secondary),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onUnstar,
                icon: const Icon(CupertinoIcons.star_slash),
                color: secondary,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              message.body,
              style: PravaTypography.body.copyWith(
                color: primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (message.type != _StarType.text) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: _TypeChip(type: message.type),
            ),
          ],
        ],
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.type});

  final _StarType type;

  @override
  Widget build(BuildContext context) {
    final label = type == _StarType.link
        ? 'Link'
        : type == _StarType.media
            ? 'Media'
            : 'Note';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: PravaColors.accentPrimary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: PravaTypography.caption.copyWith(
          color: PravaColors.accentPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.hasQuery,
    required this.primary,
    required this.secondary,
  });

  final bool hasQuery;
  final Color primary;
  final Color secondary;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 80, 16, 16),
      children: [
        Center(
          child: Icon(
            CupertinoIcons.star,
            size: 40,
            color: secondary,
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            hasQuery ? 'No results' : 'No starred messages',
            style: PravaTypography.bodyLarge.copyWith(
              color: primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            hasQuery
                ? 'Try another keyword.'
                : 'Star messages to keep them here.',
            textAlign: TextAlign.center,
            style: PravaTypography.body.copyWith(color: secondary),
          ),
        ),
      ],
    );
  }
}

class _IconPill extends StatelessWidget {
  const _IconPill({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDark ? Colors.white10 : Colors.black12,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(
          icon,
          size: 18,
          color: PravaColors.accentPrimary,
        ),
      ),
    );
  }
}

class _PageBackdrop extends StatelessWidget {
  const _PageBackdrop({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return PravaBackground(isDark: isDark);
  }
}

enum _StarType { text, link, media }

class _StarredMessage {
  const _StarredMessage({
    required this.id,
    required this.chatName,
    required this.body,
    required this.timeLabel,
    required this.type,
  });

  final String id;
  final String chatName;
  final String body;
  final String timeLabel;
  final _StarType type;

  String get initials {
    final parts = chatName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1))
        .toUpperCase();
  }
}

enum _StarFilter {
  all('All', null),
  text('Notes', _StarType.text),
  links('Links', _StarType.link),
  media('Media', _StarType.media);

  const _StarFilter(this.label, this.type);

  final String label;
  final _StarType? type;
}

const List<_StarredMessage> _seedMessages = [
  _StarredMessage(
    id: 's1',
    chatName: 'Prava Core',
    body: 'Launch checklist: encryption, rate limits, push.',
    timeLabel: 'Today, 9:18 AM',
    type: _StarType.text,
  ),
  _StarredMessage(
    id: 's2',
    chatName: 'Design Sprint',
    body: 'New moodboard: https://prava.app/design',
    timeLabel: 'Yesterday',
    type: _StarType.link,
  ),
  _StarredMessage(
    id: 's3',
    chatName: 'Creator Lab',
    body: 'Save the teaser clip from the studio session.',
    timeLabel: 'Mon',
    type: _StarType.media,
  ),
  _StarredMessage(
    id: 's4',
    chatName: 'Security Guild',
    body: 'Remember to rotate device keys this sprint.',
    timeLabel: 'Sun',
    type: _StarType.text,
  ),
];
