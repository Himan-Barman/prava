import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../services/privacy_service.dart';
import '../../../ui-system/colors.dart';
import '../../../ui-system/typography.dart';
import '../../../ui-system/components/prava_button.dart';
import '../../../ui-system/components/prava_input.dart';
import '../../../ui-system/feedback/prava_toast.dart';
import '../../../ui-system/feedback/toast_type.dart';
import 'settings_detail_shell.dart';

class MutedWordsPage extends StatefulWidget {
  const MutedWordsPage({super.key});

  @override
  State<MutedWordsPage> createState() => _MutedWordsPageState();
}

class _MutedWordsPageState extends State<MutedWordsPage> {
  final PrivacyService _service = PrivacyService();
  final TextEditingController _phraseController = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  List<MutedWord> _items = [];

  @override
  void initState() {
    super.initState();
    _loadMuted();
  }

  @override
  void dispose() {
    _phraseController.dispose();
    super.dispose();
  }

  Future<void> _loadMuted() async {
    try {
      final items = await _service.fetchMutedWords();
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
        message: 'Unable to load muted words',
        type: PravaToastType.error,
      );
    }
  }

  Future<void> _addPhrase() async {
    if (_saving) return;
    final phrase = _phraseController.text.trim();
    if (phrase.isEmpty) {
      PravaToast.show(
        context,
        message: 'Enter a word or phrase to mute',
        type: PravaToastType.warning,
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final added = await _service.addMutedWord(phrase);
      if (!mounted) return;
      setState(() {
        _saving = false;
        _phraseController.clear();
        if (added != null) {
          _items = [added, ..._items];
        }
      });
      PravaToast.show(
        context,
        message: added == null
            ? '"$phrase" is already muted'
            : 'Muted "$phrase"',
        type: added == null
            ? PravaToastType.info
            : PravaToastType.success,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      PravaToast.show(
        context,
        message: 'Unable to mute phrase',
        type: PravaToastType.error,
      );
    }
  }

  Future<void> _removePhrase(MutedWord word) async {
    try {
      await _service.removeMutedWord(word.id);
      if (!mounted) return;
      setState(() {
        _items = List<MutedWord>.from(_items)
          ..removeWhere((item) => item.id == word.id);
      });
      PravaToast.show(
        context,
        message: 'Removed "${word.phrase}"',
        type: PravaToastType.info,
      );
    } catch (_) {
      if (!mounted) return;
      PravaToast.show(
        context,
        message: 'Unable to remove phrase',
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
      title: 'Muted words',
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: BackdropFilter(
                    filter:
                        ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: Container(
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
                            'Add muted word',
                            style: PravaTypography.h3.copyWith(
                              color: primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Hide posts that contain these words.',
                            style: PravaTypography.bodySmall.copyWith(
                              color: secondary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          PravaInput(
                            controller: _phraseController,
                            hint: 'Word or phrase',
                            inputFormatters: [
                              LengthLimitingTextInputFormatter(120),
                            ],
                          ),
                          const SizedBox(height: 12),
                          PravaButton(
                            label: 'Mute phrase',
                            loading: _saving,
                            onPressed: _saving ? null : _addPhrase,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (_items.isEmpty)
                  Text(
                    'No muted words yet.',
                    style: PravaTypography.body.copyWith(color: secondary),
                  )
                else
                  ..._items.map((word) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: surface,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: border),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  word.phrase,
                                  style: PravaTypography.body.copyWith(
                                    color: primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () => _removePhrase(word),
                                child: Text(
                                  'Remove',
                                  style: PravaTypography.button.copyWith(
                                    color: PravaColors.accentPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )),
              ],
            ),
    );
  }
}
