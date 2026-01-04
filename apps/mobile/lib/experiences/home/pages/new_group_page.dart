import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

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
  final TextEditingController _aboutController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  final Set<String> _selectedIds = <String>{};

  bool _privateGroup = true;
  bool _announcementOnly = false;
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_handleFormChange);
    _searchController.addListener(_handleFormChange);
  }

  @override
  void dispose() {
    _nameController.removeListener(_handleFormChange);
    _searchController.removeListener(_handleFormChange);
    _nameController.dispose();
    _aboutController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _handleFormChange() {
    if (mounted) setState(() {});
  }

  bool get _canCreate {
    return _nameController.text.trim().isNotEmpty && _selectedIds.isNotEmpty;
  }

  void _toggleMember(_Contact contact) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedIds.contains(contact.id)) {
        _selectedIds.remove(contact.id);
      } else {
        _selectedIds.add(contact.id);
      }
    });
  }

  Future<void> _createGroup() async {
    if (_creating) return;
    if (!_canCreate) {
      PravaToast.show(
        context,
        message: 'Add a group name and at least one member.',
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
      message: 'Group created',
      type: PravaToastType.success,
    );
    Navigator.of(context).pop();
  }

  List<_Contact> get _visibleContacts {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _seedContacts;
    return _seedContacts
        .where(
          (contact) =>
              contact.name.toLowerCase().contains(query) ||
              contact.handle.toLowerCase().contains(query),
        )
        .toList();
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

    final selectedContacts = _seedContacts
        .where((contact) => _selectedIds.contains(contact.id))
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
                    title: 'New group',
                    onBack: () => Navigator.of(context).pop(),
                    onAction: _createGroup,
                    enabled: _canCreate,
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                    child: _GroupDetailsCard(
                      nameController: _nameController,
                      aboutController: _aboutController,
                      isDark: isDark,
                      primary: primary,
                      secondary: secondary,
                      border: border,
                      surface: surface,
                      privateGroup: _privateGroup,
                      announcementOnly: _announcementOnly,
                      onPrivateChanged: (value) {
                        HapticFeedback.selectionClick();
                        setState(() => _privateGroup = value);
                      },
                      onAnnouncementChanged: (value) {
                        HapticFeedback.selectionClick();
                        setState(() => _announcementOnly = value);
                      },
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: _SectionHeader(
                      title: 'Members',
                      subtitle:
                          '${selectedContacts.length} selected • ${_seedContacts.length} available',
                      primary: primary,
                      secondary: secondary,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: _SelectedMembersRow(
                      contacts: selectedContacts,
                      primary: primary,
                      secondary: secondary,
                      onRemove: (contact) {
                        setState(() => _selectedIds.remove(contact.id));
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
                  itemCount: _visibleContacts.length,
                  itemBuilder: (context, index) {
                    final contact = _visibleContacts[index];
                    final selected = _selectedIds.contains(contact.id);
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                      child: _ContactTile(
                        contact: contact,
                        selected: selected,
                        isDark: isDark,
                        primary: primary,
                        secondary: secondary,
                        border: border,
                        accent: _avatarColor(contact.name),
                        onTap: () => _toggleMember(contact),
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
            label: _creating ? 'Creating...' : 'Create group',
            enabled: _canCreate && !_creating,
            onTap: _createGroup,
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

class _GroupDetailsCard extends StatelessWidget {
  const _GroupDetailsCard({
    required this.nameController,
    required this.aboutController,
    required this.isDark,
    required this.primary,
    required this.secondary,
    required this.border,
    required this.surface,
    required this.privateGroup,
    required this.announcementOnly,
    required this.onPrivateChanged,
    required this.onAnnouncementChanged,
  });

  final TextEditingController nameController;
  final TextEditingController aboutController;
  final bool isDark;
  final Color primary;
  final Color secondary;
  final Color border;
  final Color surface;
  final bool privateGroup;
  final bool announcementOnly;
  final ValueChanged<bool> onPrivateChanged;
  final ValueChanged<bool> onAnnouncementChanged;

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
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [
                      PravaColors.accentPrimary,
                      PravaColors.accentMuted,
                    ],
                  ),
                ),
                child: const Icon(
                  CupertinoIcons.camera_fill,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  children: [
                    _InputField(
                      controller: nameController,
                      label: 'Group name',
                      hint: 'Prava Design Squad',
                      primary: primary,
                      secondary: secondary,
                    ),
                    const SizedBox(height: 10),
                    _InputField(
                      controller: aboutController,
                      label: 'About',
                      hint: 'Share your mission',
                      primary: primary,
                      secondary: secondary,
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: border),
          const SizedBox(height: 10),
          _ToggleTile(
            icon: CupertinoIcons.lock_fill,
            title: 'Private group',
            subtitle: 'Members need approval to join',
            value: privateGroup,
            onChanged: onPrivateChanged,
            primary: primary,
            secondary: secondary,
          ),
          const SizedBox(height: 10),
          _ToggleTile(
            icon: CupertinoIcons.speaker_2_fill,
            title: 'Announcements only',
            subtitle: 'Only admins can post',
            value: announcementOnly,
            onChanged: onAnnouncementChanged,
            primary: primary,
            secondary: secondary,
          ),
        ],
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  const _InputField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.primary,
    required this.secondary,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final Color primary;
  final Color secondary;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: PravaTypography.body.copyWith(color: primary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: PravaTypography.caption.copyWith(color: secondary),
        hintText: hint,
        hintStyle: PravaTypography.body.copyWith(color: secondary),
        border: InputBorder.none,
        isDense: true,
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

class _SelectedMembersRow extends StatelessWidget {
  const _SelectedMembersRow({
    required this.contacts,
    required this.primary,
    required this.secondary,
    required this.onRemove,
  });

  final List<_Contact> contacts;
  final Color primary;
  final Color secondary;
  final ValueChanged<_Contact> onRemove;

  @override
  Widget build(BuildContext context) {
    if (contacts.isEmpty) {
      return Text(
        'No members selected yet.',
        style: PravaTypography.caption.copyWith(color: secondary),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: contacts
          .map(
            (contact) => Chip(
              label: Text(
                contact.name,
                style: PravaTypography.caption.copyWith(
                  color: primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              deleteIcon: const Icon(CupertinoIcons.xmark, size: 14),
              onDeleted: () => onRemove(contact),
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
            placeholder: 'Search members',
            backgroundColor: Colors.transparent,
          ),
        ),
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({
    required this.contact,
    required this.selected,
    required this.isDark,
    required this.primary,
    required this.secondary,
    required this.border,
    required this.accent,
    required this.onTap,
  });

  final _Contact contact;
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
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: accent.withValues(alpha: 0.18),
                      child: Text(
                        contact.initials,
                        style: PravaTypography.h3.copyWith(
                          color: accent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (contact.isOnline)
                      Positioned(
                        right: 2,
                        bottom: 2,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: PravaColors.success,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: baseColor,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        contact.name,
                        style: PravaTypography.body.copyWith(
                          color: primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${contact.handle} • ${contact.role}',
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

class _Contact {
  const _Contact({
    required this.id,
    required this.name,
    required this.handle,
    required this.role,
    required this.isOnline,
  });

  final String id;
  final String name;
  final String handle;
  final String role;
  final bool isOnline;

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

const List<_Contact> _seedContacts = [
  _Contact(
    id: 'u1',
    name: 'Aarav Sharma',
    handle: '@aarav',
    role: 'Product',
    isOnline: true,
  ),
  _Contact(
    id: 'u2',
    name: 'Meera Patel',
    handle: '@meera',
    role: 'Design',
    isOnline: false,
  ),
  _Contact(
    id: 'u3',
    name: 'Ishan Roy',
    handle: '@ishan',
    role: 'Engineering',
    isOnline: true,
  ),
  _Contact(
    id: 'u4',
    name: 'Riya Kapoor',
    handle: '@riya',
    role: 'Creator',
    isOnline: true,
  ),
  _Contact(
    id: 'u5',
    name: 'Neha Singh',
    handle: '@neha',
    role: 'Growth',
    isOnline: false,
  ),
  _Contact(
    id: 'u6',
    name: 'Aditya Rao',
    handle: '@aditya',
    role: 'Brand',
    isOnline: false,
  ),
  _Contact(
    id: 'u7',
    name: 'Lina Das',
    handle: '@lina',
    role: 'Ops',
    isOnline: true,
  ),
  _Contact(
    id: 'u8',
    name: 'Vikram Jain',
    handle: '@vikram',
    role: 'Security',
    isOnline: false,
  ),
];
