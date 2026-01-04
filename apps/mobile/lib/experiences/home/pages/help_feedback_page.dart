import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../../ui-system/background.dart';
import '../../../ui-system/colors.dart';
import '../../../ui-system/typography.dart';
import '../../../ui-system/feedback/prava_toast.dart';
import '../../../ui-system/feedback/toast_type.dart';

enum HelpFeedbackSection { help, report, feedback }

class HelpFeedbackPage extends StatefulWidget {
  const HelpFeedbackPage({
    super.key,
    this.initialSection = HelpFeedbackSection.help,
  });

  final HelpFeedbackSection initialSection;

  @override
  State<HelpFeedbackPage> createState() => _HelpFeedbackPageState();
}

class _HelpFeedbackPageState extends State<HelpFeedbackPage> {
  final TextEditingController _reportController = TextEditingController();
  final TextEditingController _feedbackController = TextEditingController();

  HelpFeedbackSection _section = HelpFeedbackSection.help;
  String _reportCategory = 'Bug';
  bool _includeLogs = true;
  bool _allowContact = true;
  double _feedbackScore = 4;

  @override
  void initState() {
    super.initState();
    _section = widget.initialSection;
  }

  @override
  void dispose() {
    _reportController.dispose();
    _feedbackController.dispose();
    super.dispose();
  }

  void _sendReport() {
    if (_reportController.text.trim().isEmpty) {
      PravaToast.show(
        context,
        message: 'Add details to submit the report.',
        type: PravaToastType.warning,
      );
      return;
    }
    PravaToast.show(
      context,
      message: 'Report sent. We will follow up soon.',
      type: PravaToastType.success,
    );
    _reportController.clear();
  }

  void _sendFeedback() {
    if (_feedbackController.text.trim().isEmpty) {
      PravaToast.show(
        context,
        message: 'Tell us what you think before sending.',
        type: PravaToastType.warning,
      );
      return;
    }
    PravaToast.show(
      context,
      message: 'Thanks for the feedback.',
      type: PravaToastType.success,
    );
    _feedbackController.clear();
  }

  String _feedbackLabel(double value) {
    if (value <= 1.5) return 'Needs work';
    if (value <= 2.5) return 'Okay';
    if (value <= 3.5) return 'Good';
    if (value <= 4.5) return 'Great';
    return 'Excellent';
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

    return Scaffold(
      body: Stack(
        children: [
          _PageBackdrop(isDark: isDark),
          SafeArea(
            child: Column(
              children: [
                _TopBar(
                  title: 'Help & feedback',
                  onBack: () => Navigator.of(context).pop(),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: _SegmentedControl(
                    value: _section,
                    onChanged: (next) {
                      HapticFeedback.selectionClick();
                      setState(() => _section = next);
                    },
                  ),
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: _section == HelpFeedbackSection.help
                        ? _HelpSection(
                            key: const ValueKey('help'),
                            primary: primary,
                            secondary: secondary,
                            border: border,
                            isDark: isDark,
                          )
                        : _section == HelpFeedbackSection.report
                            ? _ReportSection(
                                key: const ValueKey('report'),
                                reportController: _reportController,
                                category: _reportCategory,
                                includeLogs: _includeLogs,
                                onCategoryChanged: (value) {
                                  HapticFeedback.selectionClick();
                                  setState(() => _reportCategory = value);
                                },
                                onLogsChanged: (value) {
                                  HapticFeedback.selectionClick();
                                  setState(() => _includeLogs = value);
                                },
                                onSend: _sendReport,
                                primary: primary,
                                secondary: secondary,
                                border: border,
                                isDark: isDark,
                              )
                            : _FeedbackSection(
                                key: const ValueKey('feedback'),
                                feedbackController: _feedbackController,
                                score: _feedbackScore,
                                allowContact: _allowContact,
                                onScoreChanged: (value) {
                                  setState(() => _feedbackScore = value);
                                },
                                onAllowContactChanged: (value) {
                                  HapticFeedback.selectionClick();
                                  setState(() => _allowContact = value);
                                },
                                onSend: _sendFeedback,
                                label: _feedbackLabel(_feedbackScore),
                                primary: primary,
                                secondary: secondary,
                                border: border,
                                isDark: isDark,
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

class _TopBar extends StatelessWidget {
  const _TopBar({required this.title, required this.onBack});

  final String title;
  final VoidCallback onBack;

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
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SegmentedControl extends StatelessWidget {
  const _SegmentedControl({
    required this.value,
    required this.onChanged,
  });

  final HelpFeedbackSection value;
  final ValueChanged<HelpFeedbackSection> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface =
        isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.08);
    final secondary =
        isDark ? PravaColors.darkTextSecondary : PravaColors.lightTextSecondary;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: CupertinoSlidingSegmentedControl<HelpFeedbackSection>(
        groupValue: value,
        backgroundColor: Colors.transparent,
        thumbColor: PravaColors.accentPrimary,
        children: {
          HelpFeedbackSection.help: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'Help',
              style: PravaTypography.caption.copyWith(
                color: value == HelpFeedbackSection.help
                    ? Colors.white
                    : secondary,
              ),
            ),
          ),
          HelpFeedbackSection.report: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'Report',
              style: PravaTypography.caption.copyWith(
                color: value == HelpFeedbackSection.report
                    ? Colors.white
                    : secondary,
              ),
            ),
          ),
          HelpFeedbackSection.feedback: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'Feedback',
              style: PravaTypography.caption.copyWith(
                color: value == HelpFeedbackSection.feedback
                    ? Colors.white
                    : secondary,
              ),
            ),
          ),
        },
        onValueChanged: (next) {
          if (next == null) return;
          onChanged(next);
        },
      ),
    );
  }
}

class _HelpSection extends StatelessWidget {
  const _HelpSection({
    super.key,
    required this.primary,
    required this.secondary,
    required this.border,
    required this.isDark,
  });

  final Color primary;
  final Color secondary;
  final Color border;
  final bool isDark;

  void _showToast(BuildContext context, String message) {
    PravaToast.show(
      context,
      message: message,
      type: PravaToastType.info,
    );
  }

  @override
  Widget build(BuildContext context) {
    final surface =
        isDark ? PravaColors.darkBgSurface : PravaColors.lightBgSurface;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        _SectionCard(
          title: 'Get help fast',
          subtitle: 'Find answers or talk to the Prava team.',
          primary: primary,
          secondary: secondary,
          border: border,
          surface: surface,
          child: Column(
            children: [
              _ActionTile(
                icon: CupertinoIcons.book,
                title: 'Help center',
                subtitle: 'Guides, FAQs, and tips',
                onTap: () => _showToast(context, 'Help center coming soon'),
                primary: primary,
                secondary: secondary,
              ),
              _ActionTile(
                icon: CupertinoIcons.chat_bubble_2,
                title: 'Contact support',
                subtitle: 'Chat with the team',
                onTap: () => _showToast(context, 'Support chat coming soon'),
                primary: primary,
                secondary: secondary,
              ),
              _ActionTile(
                icon: CupertinoIcons.shield,
                title: 'Safety center',
                subtitle: 'Privacy and safety guidance',
                onTap: () => _showToast(context, 'Safety center coming soon'),
                primary: primary,
                secondary: secondary,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'System status',
          subtitle: 'Realtime platform health',
          primary: primary,
          secondary: secondary,
          border: border,
          surface: surface,
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: PravaColors.success,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'All systems operational',
                  style: PravaTypography.body.copyWith(
                    color: primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: () =>
                    _showToast(context, 'Status page coming soon'),
                child: Text(
                  'Details',
                  style: PravaTypography.button.copyWith(
                    color: PravaColors.accentPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReportSection extends StatelessWidget {
  const _ReportSection({
    super.key,
    required this.reportController,
    required this.category,
    required this.includeLogs,
    required this.onCategoryChanged,
    required this.onLogsChanged,
    required this.onSend,
    required this.primary,
    required this.secondary,
    required this.border,
    required this.isDark,
  });

  final TextEditingController reportController;
  final String category;
  final bool includeLogs;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<bool> onLogsChanged;
  final VoidCallback onSend;
  final Color primary;
  final Color secondary;
  final Color border;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final surface =
        isDark ? PravaColors.darkBgSurface : PravaColors.lightBgSurface;
    const categories = ['Bug', 'Abuse', 'Payments', 'Other'];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        _SectionCard(
          title: 'Report a problem',
          subtitle: 'Help us fix issues faster.',
          primary: primary,
          secondary: secondary,
          border: border,
          surface: surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: categories.map((item) {
                  final selected = category == item;
                  return ChoiceChip(
                    label: Text(
                      item,
                      style: PravaTypography.caption.copyWith(
                        color: selected ? Colors.white : primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    selected: selected,
                    selectedColor: PravaColors.accentPrimary,
                    backgroundColor: isDark
                        ? Colors.white10
                        : Colors.black.withValues(alpha: 0.05),
                    onSelected: (_) => onCategoryChanged(item),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reportController,
                maxLines: 5,
                style: PravaTypography.body.copyWith(color: primary),
                decoration: InputDecoration(
                  hintText: 'Describe what happened...',
                  hintStyle: PravaTypography.body.copyWith(color: secondary),
                  border: InputBorder.none,
                  filled: true,
                  fillColor: isDark ? Colors.white10 : Colors.black12,
                ),
              ),
              const SizedBox(height: 12),
              _ToggleRow(
                icon: CupertinoIcons.doc_text,
                title: 'Include logs',
                subtitle: 'Attach diagnostics to speed up fixes',
                value: includeLogs,
                onChanged: onLogsChanged,
                primary: primary,
                secondary: secondary,
              ),
              const SizedBox(height: 12),
              _PrimaryButton(
                label: 'Send report',
                onTap: onSend,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FeedbackSection extends StatelessWidget {
  const _FeedbackSection({
    super.key,
    required this.feedbackController,
    required this.score,
    required this.allowContact,
    required this.onScoreChanged,
    required this.onAllowContactChanged,
    required this.onSend,
    required this.label,
    required this.primary,
    required this.secondary,
    required this.border,
    required this.isDark,
  });

  final TextEditingController feedbackController;
  final double score;
  final bool allowContact;
  final ValueChanged<double> onScoreChanged;
  final ValueChanged<bool> onAllowContactChanged;
  final VoidCallback onSend;
  final String label;
  final Color primary;
  final Color secondary;
  final Color border;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final surface =
        isDark ? PravaColors.darkBgSurface : PravaColors.lightBgSurface;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        _SectionCard(
          title: 'Share feedback',
          subtitle: 'Tell us what to improve next.',
          primary: primary,
          secondary: secondary,
          border: border,
          surface: surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'How is Prava today?',
                style: PravaTypography.body.copyWith(
                  color: primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: PravaTypography.caption.copyWith(color: secondary),
              ),
              Slider(
                value: score,
                min: 1,
                max: 5,
                divisions: 4,
                onChanged: onScoreChanged,
                activeColor: PravaColors.accentPrimary,
              ),
              const SizedBox(height: 6),
              TextField(
                controller: feedbackController,
                maxLines: 4,
                style: PravaTypography.body.copyWith(color: primary),
                decoration: InputDecoration(
                  hintText: 'Share your ideas or feedback...',
                  hintStyle: PravaTypography.body.copyWith(color: secondary),
                  border: InputBorder.none,
                  filled: true,
                  fillColor: isDark ? Colors.white10 : Colors.black12,
                ),
              ),
              const SizedBox(height: 12),
              _ToggleRow(
                icon: CupertinoIcons.mail_solid,
                title: 'Allow contact',
                subtitle: 'We can follow up if needed',
                value: allowContact,
                onChanged: onAllowContactChanged,
                primary: primary,
                secondary: secondary,
              ),
              const SizedBox(height: 12),
              _PrimaryButton(
                label: 'Send feedback',
                onTap: onSend,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.primary,
    required this.secondary,
    required this.border,
    required this.surface,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Color primary;
  final Color secondary;
  final Color border;
  final Color surface;
  final Widget child;

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
            title,
            style: PravaTypography.h3.copyWith(
              color: primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: PravaTypography.bodySmall.copyWith(color: secondary),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.primary,
    required this.secondary,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color primary;
  final Color secondary;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: PravaColors.accentPrimary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 18, color: PravaColors.accentPrimary),
      ),
      title: Text(
        title,
        style: PravaTypography.body.copyWith(
          color: primary,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: PravaTypography.caption.copyWith(color: secondary),
      ),
      trailing: Icon(
        CupertinoIcons.chevron_right,
        size: 16,
        color: secondary,
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
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

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            colors: [
              PravaColors.accentPrimary,
              PravaColors.accentMuted,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: PravaColors.accentPrimary.withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
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
