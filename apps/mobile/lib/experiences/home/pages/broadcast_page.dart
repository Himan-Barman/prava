import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../../ui-system/background.dart';
import '../../../ui-system/colors.dart';
import '../../../ui-system/typography.dart';
import '../../../ui-system/feedback/prava_toast.dart';
import '../../../ui-system/feedback/toast_type.dart';

class BroadcastPage extends StatefulWidget {
  const BroadcastPage({super.key});

  @override
  State<BroadcastPage> createState() => _BroadcastPageState();
}

class _BroadcastPageState extends State<BroadcastPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  final Set<String> _selectedIds = <String>{};

  bool _allowReplies = true;
  bool _silentMode = false;
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    _titleController.addListener(_handleFormChange);
    _searchController.addListener(_handleFormChange);
  }

  @override
  void dispose() {
    _titleController.removeListener(_handleFormChange);
    _searchController.removeListener(_handleFormChange);
    _titleController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _handleFormChange() {
    if (mounted) setState(() {});
  }

  bool get _canCreate {
    return _titleController.text.trim().isNotEmpty && _selectedIds.isNotEmpty;
  }

  List<_Recipient> get _visibleRecipients {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _seedRecipients;
    return _seedRecipients
        .where(
          (person) =>
              person.name.toLowerCase().contains(query) ||
              person.handle.toLowerCase().contains(query),
        )
        .toList();
  }

  void _toggleRecipient(_Recipient person) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedIds.contains(person.id)) {
        _selectedIds.remove(person.id);
      } else {
        _selectedIds.add(person.id);
      }
    });
  }

  Future<void> _createBroadcast() async {
    if (_creating) return;
    if (!_canCreate) {
      PravaToast.show(
        context,
        message: 'Add a name and at least one recipient.',
        type: PravaToastType.warning,
      );
      return;
    }

    setState(() => _creating = true);
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    setState(() => _creating = false);
    PravaToast.show(
      context,
      message: 'Broadcast list created',
      type: PravaToastType.success,
    );
    Navigator.of(context).pop();
  }

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary =
        isDark ? PravaColors.darkTextPrimary : PravaColors.lightTextPrimary;
    final secondary =
        isDark ? PravaColors.darkTextSecondary : PravaColors.lightTextSecondary;
    final surface =
        isDark ? PravaColors.darkBgSurface : PravaColors.lightBgSurface;
    final border =
        isDark ? PravaColors.darkBorderSubtle : PravaColors.lightBorderSubtle;

    final selectedRecipients = _seedRecipients
        .where((person) => _selectedIds.contains(person.id))
        .toList();

    return Scaffold(
      body: Stack(
        children: [
          _PageBackdrop(isDark: isDark),
          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                SliverToBoxAdapter(
                  child: _TopBar(
                    title: 'New broadcast',
                    onBack: () => Navigator.of(context).pop(),
                    onAction: _createBroadcast,
                    enabled: _canCreate,
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                    child: _BroadcastDetailsCard(
                      titleController: _titleController,
                      isDark: isDark,
                      primary: primary,
                      secondary: secondary,
                      surface: surface,
                      border: border,
                      allowReplies: _allowReplies,
                      silentMode: _silentMode,
                      onRepliesChanged: (value) {
                        HapticFeedback.selectionClick();
                        setState(() => _allowReplies = value);
                      },
                      onSilentChanged: (value) {
                        HapticFeedback.selectionClick();
                        setState(() => _silentMode = value);
                      },
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: _SectionHeader(
                      title: 'Recipients',
                      subtitle:
                          '${selectedRecipients.length} selected • ${_seedRecipients.length} contacts',
                      primary: primary,
                      secondary: secondary,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: _SelectedRecipientsRow(
                      recipients: selectedRecipients,
                      primary: primary,
                      secondary: secondary,
                      onRemove: (person) {
                        setState(() => _selectedIds.remove(person.id));
                      },
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: _SearchField(
                      controller: _searchController,
                      border: border,
                      isDark: isDark,
                    ),
                  ),
                ),
                SliverList.builder(
                  itemCount: _visibleRecipients.length,
                  itemBuilder: (context, index) {
                    final person = _visibleRecipients[index];
                    final selected = _selectedIds.contains(person.id);
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                      child: _RecipientTile(
                        recipient: person,
                        selected: selected,
                        isDark: isDark,
                        primary: primary,
                        secondary: secondary,
                        border: border,
                        accent: _avatarColor(person.name),
                        onTap: () => _toggleRecipient(person),
                      ),
                    );
                  },
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: _PrimaryButton(
            label: _creating ? 'Creating...' : 'Create broadcast',
            enabled: _canCreate && !_creating,
            onTap: _createBroadcast,
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.onBack,
    required this.onAction,
    required this.enabled,
  });

  final String title;
  final VoidCallback onBack;
  final VoidCallback onAction;
  final bool enabled;

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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
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
                TextButton(
                  onPressed: enabled ? onAction : null,
                  child: Text(
                    'Create',
                    style: PravaTypography.button.copyWith(
                      color: enabled ? PravaColors.accentPrimary : primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BroadcastDetailsCard extends StatelessWidget {
  const _BroadcastDetailsCard({
    required this.titleController,
    required this.isDark,
    required this.primary,
    required this.secondary,
    required this.surface,
    required this.border,
    required this.allowReplies,
    required this.silentMode,
    required this.onRepliesChanged,
    required this.onSilentChanged,
  });

  final TextEditingController titleController;
  final bool isDark;
  final Color primary;
  final Color secondary;
  final Color surface;
  final Color border;
  final bool allowReplies;
  final bool silentMode;
  final ValueChanged<bool> onRepliesChanged;
  final ValueChanged<bool> onSilentChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Broadcast details',
            style: PravaTypography.h3.copyWith(color: primary),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: titleController,
            style: PravaTypography.body.copyWith(color: primary),
            decoration: InputDecoration(
              labelText: 'Broadcast name',
              hintText: 'Weekly updates',
              labelStyle: PravaTypography.caption.copyWith(color: secondary),
              hintStyle: PravaTypography.body.copyWith(color: secondary),
              border: InputBorder.none,
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: border),
          const SizedBox(height: 12),
          _ToggleTile(
            icon: CupertinoIcons.reply_all,
            title: 'Allow replies',
            subtitle: 'Recipients can reply to you',
            value: allowReplies,
            onChanged: onRepliesChanged,
            primary: primary,
            secondary: secondary,
          ),
          const SizedBox(height: 10),
          _ToggleTile(
            icon: CupertinoIcons.bell_slash_fill,
            title: 'Silent delivery',
            subtitle: 'Send without notifications',
            value: silentMode,
            onChanged: onSilentChanged,
            primary: primary,
            secondary: secondary,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(
                  CupertinoIcons.info,
                  size: 16,
                  color: secondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Broadcasts are one-way by default. Your recipients stay private.',
                    style: PravaTypography.caption.copyWith(color: secondary),
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

class _ToggleTile extends StatelessWidget {
  const _ToggleTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    required this.primary,
    required this.secondary,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color primary;
  final Color secondary;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: PravaColors.accentPrimary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 18, color: PravaColors.accentPrimary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: PravaTypography.body.copyWith(
                  color: primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: PravaTypography.caption.copyWith(color: secondary),
              ),
            ],
          ),
        ),
        Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeColor: PravaColors.accentPrimary,
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.primary,
    required this.secondary,
  });

  final String title;
  final String subtitle;
  final Color primary;
  final Color secondary;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: PravaTypography.h3.copyWith(
            color: primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        Text(
          subtitle,
          style: PravaTypography.caption.copyWith(color: secondary),
        ),
      ],
    );
  }
}

class _SelectedRecipientsRow extends StatelessWidget {
  const _SelectedRecipientsRow({
    required this.recipients,
    required this.primary,
    required this.secondary,
    required this.onRemove,
  });

  final List<_Recipient> recipients;
  final Color primary;
  final Color secondary;
  final ValueChanged<_Recipient> onRemove;

  @override
  Widget build(BuildContext context) {
    if (recipients.isEmpty) {
      return Text(
        'No recipients selected yet.',
        style: PravaTypography.caption.copyWith(color: secondary),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: recipients
          .map(
            (person) => Chip(
              label: Text(
                person.name,
                style: PravaTypography.caption.copyWith(
                  color: primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              deleteIcon: const Icon(CupertinoIcons.xmark, size: 14),
              onDeleted: () => onRemove(person),
              backgroundColor: Colors.black.withValues(alpha: 0.05),
            ),
          )
          .toList(),
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
            placeholder: 'Search recipients',
            backgroundColor: Colors.transparent,
          ),
        ),
      ),
    );
  }
}

class _RecipientTile extends StatelessWidget {
  const _RecipientTile({
    required this.recipient,
    required this.selected,
    required this.isDark,
    required this.primary,
    required this.secondary,
    required this.border,
    required this.accent,
    required this.onTap,
  });

  final _Recipient recipient;
  final bool selected;
  final bool isDark;
  final Color primary;
  final Color secondary;
  final Color border;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final baseColor = isDark
        ? (selected ? Colors.white12 : Colors.white10)
        : (selected ? Colors.white : Colors.white.withValues(alpha: 0.85));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: baseColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? PravaColors.accentPrimary.withValues(alpha: 0.4)
                  : border,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: accent.withValues(alpha: 0.18),
                  child: Text(
                    recipient.initials,
                    style: PravaTypography.h3.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        recipient.name,
                        style: PravaTypography.body.copyWith(
                          color: primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        recipient.handle,
                        style: PravaTypography.caption.copyWith(color: secondary),
                      ),
                    ],
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: selected
                        ? PravaColors.accentPrimary
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected ? PravaColors.accentPrimary : border,
                    ),
                  ),
                  child: Icon(
                    selected
                        ? CupertinoIcons.checkmark_alt
                        : CupertinoIcons.plus,
                    size: 16,
                    color: selected ? Colors.white : secondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: enabled
              ? const LinearGradient(
                  colors: [
                    PravaColors.accentPrimary,
                    PravaColors.accentMuted,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: enabled ? null : Colors.grey.shade400,
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: PravaColors.accentPrimary.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: PravaTypography.button.copyWith(color: Colors.white),
        ),
      ),
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

class _Recipient {
  const _Recipient({
    required this.id,
    required this.name,
    required this.handle,
  });

  final String id;
  final String name;
  final String handle;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1))
        .toUpperCase();
  }
}

const List<_Recipient> _seedRecipients = [
  _Recipient(id: 'r1', name: 'Aarav Sharma', handle: '@aarav'),
  _Recipient(id: 'r2', name: 'Meera Patel', handle: '@meera'),
  _Recipient(id: 'r3', name: 'Ishan Roy', handle: '@ishan'),
  _Recipient(id: 'r4', name: 'Riya Kapoor', handle: '@riya'),
  _Recipient(id: 'r5', name: 'Neha Singh', handle: '@neha'),
  _Recipient(id: 'r6', name: 'Aditya Rao', handle: '@aditya'),
  _Recipient(id: 'r7', name: 'Lina Das', handle: '@lina'),
  _Recipient(id: 'r8', name: 'Vikram Jain', handle: '@vikram'),
];
