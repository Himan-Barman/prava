import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../../ui-system/background.dart';
import '../../../ui-system/colors.dart';
import '../../../ui-system/typography.dart';
import '../../../ui-system/feedback/prava_toast.dart';
import '../../../ui-system/feedback/toast_type.dart';
import '../../../services/support_service.dart';

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
  final SupportService _support = SupportService();

  HelpFeedbackSection _section = HelpFeedbackSection.help;
  String _reportCategory = 'Bug';
  bool _includeLogs = true;
  bool _allowContact = true;
  double _feedbackScore = 4;
  bool _sendingReport = false;
  bool _sendingFeedback = false;

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
    if (_sendingReport) return;
    setState(() => _sendingReport = true);
    () async {
      try {
        await _support.sendReport(
          category: _reportCategory,
          message: _reportController.text.trim(),
          includeLogs: _includeLogs,
        );
        if (!mounted) return;
        setState(() => _sendingReport = false);
        PravaToast.show(
          context,
          message: 'Report sent. We will follow up soon.',
          type: PravaToastType.success,
        );
        _reportController.clear();
      } catch (_) {
        if (!mounted) return;
        setState(() => _sendingReport = false);
        PravaToast.show(
          context,
          message: 'Unable to send report',
          type: PravaToastType.error,
        );
      }
    }();
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
    if (_sendingFeedback) return;
    setState(() => _sendingFeedback = true);
    () async {
      try {
        await _support.sendFeedback(
          score: _feedbackScore,
          message: _feedbackController.text.trim(),
          allowContact: _allowContact,
        );
        if (!mounted) return;
        setState(() => _sendingFeedback = false);
        PravaToast.show(
          context,
          message: 'Thanks for the feedback.',
          type: PravaToastType.success,
        );
        _feedbackController.clear();
      } catch (_) {
        if (!mounted) return;
        setState(() => _sendingFeedback = false);
        PravaToast.show(
          context,
          message: 'Unable to send feedback',
          type: PravaToastType.error,
        );
      }
    }();
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
    final primary = isDark
        ? PravaColors.darkTextPrimary
        : PravaColors.lightTextPrimary;
    final secondary = isDark
        ? PravaColors.darkTextSecondary
        : PravaColors.lightTextSecondary;

    return Scaffold(
      body: Stack(
        children: [
          _PageBackdrop(isDark: isDark),
          SafeArea(
            child: Column(
              children: [
                const _TopBar(title: 'Help & feedback'),
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
  const _TopBar({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark
        ? PravaColors.darkTextPrimary
        : PravaColors.lightTextPrimary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: PravaTypography.h2.copyWith(
                color: primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentedControl extends StatelessWidget {
  const _SegmentedControl({required this.value, required this.onChanged});

  final HelpFeedbackSection value;
  final ValueChanged<HelpFeedbackSection> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark
        ? Colors.white10
        : Colors.black.withValues(alpha: 0.08);
    final secondary = isDark
        ? PravaColors.darkTextSecondary
        : PravaColors.lightTextSecondary;

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
    required this.isDark,
  });

  final Color primary;
  final Color secondary;
  final bool isDark;

  void _showToast(BuildContext context, String message) {
    PravaToast.show(context, message: message, type: PravaToastType.info);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        _SectionCard(
          title: 'Get help fast',
          subtitle: 'Find answers or talk to the Prava team.',
          primary: primary,
          secondary: secondary,
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
                onPressed: () => _showToast(context, 'Status page coming soon'),
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
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    const categories = ['Bug', 'Abuse', 'Payments', 'Other'];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        _SectionCard(
          title: 'Report a problem',
          subtitle: 'Help us fix issues faster.',
          primary: primary,
          secondary: secondary,
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
              _PrimaryButton(label: 'Send report', onTap: onSend),
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
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        _SectionCard(
          title: 'Share feedback',
          subtitle: 'Tell us what to improve next.',
          primary: primary,
          secondary: secondary,
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
              _PrimaryButton(label: 'Send feedback', onTap: onSend),
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
    required this.child,
  });

  final String title;
  final String subtitle;
  final Color primary;
  final Color secondary;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
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
        width: 30,
        alignment: Alignment.centerLeft,
        child: Icon(icon, size: 21, color: PravaColors.accentPrimary),
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
        SizedBox(
          width: 30,
          child: Icon(icon, size: 21, color: PravaColors.accentPrimary),
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
          activeThumbColor: Colors.white,
          activeTrackColor: PravaColors.accentPrimary,
        ),
      ],
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onTap});

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
            colors: [PravaColors.accentPrimary, PravaColors.accentMuted],
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

class _PageBackdrop extends StatelessWidget {
  const _PageBackdrop({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return PravaBackground(isDark: isDark);
  }
}
