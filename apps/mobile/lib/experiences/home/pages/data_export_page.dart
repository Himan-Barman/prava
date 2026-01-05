import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../services/data_export_service.dart';
import '../../../ui-system/colors.dart';
import '../../../ui-system/typography.dart';
import '../../../ui-system/components/prava_button.dart';
import '../../../ui-system/feedback/prava_toast.dart';
import '../../../ui-system/feedback/toast_type.dart';
import 'settings_detail_shell.dart';

class DataExportPage extends StatefulWidget {
  const DataExportPage({super.key});

  @override
  State<DataExportPage> createState() => _DataExportPageState();
}

class _DataExportPageState extends State<DataExportPage> {
  final DataExportService _service = DataExportService();
  DataExport? _latest;
  bool _loading = true;
  bool _requesting = false;

  @override
  void initState() {
    super.initState();
    _loadLatest();
  }

  Future<void> _loadLatest() async {
    try {
      final latest = await _service.fetchLatest();
      if (!mounted) return;
      setState(() {
        _latest = latest;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _requestExport() async {
    if (_requesting) return;
    setState(() => _requesting = true);
    try {
      final export = await _service.requestExport();
      if (!mounted) return;
      setState(() {
        _latest = export;
        _requesting = false;
      });
      PravaToast.show(
        context,
        message: 'Data export is ready',
        type: PravaToastType.success,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _requesting = false);
      PravaToast.show(
        context,
        message: 'Unable to request export',
        type: PravaToastType.error,
      );
    }
  }

  Future<void> _copyExport() async {
    final payload = _latest?.payload;
    if (payload == null || payload.isEmpty) return;
    final raw = const JsonEncoder.withIndent('  ').convert(payload);
    await Clipboard.setData(ClipboardData(text: raw));
    if (!mounted) return;
    PravaToast.show(
      context,
      message: 'Export copied to clipboard',
      type: PravaToastType.success,
    );
  }

  String _formatDate(DateTime? value) {
    if (value == null) return 'Unknown';
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
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
      title: 'Download your data',
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
                            'Export your data',
                            style: PravaTypography.h3.copyWith(
                              color: primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Generate a JSON export of your profile and settings.',
                            style: PravaTypography.bodySmall.copyWith(
                              color: secondary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          PravaButton(
                            label: 'Request export',
                            loading: _requesting,
                            onPressed:
                                _requesting ? null : _requestExport,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (_latest == null)
                  Text(
                    'No exports generated yet.',
                    style: PravaTypography.body.copyWith(color: secondary),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Latest export',
                          style: PravaTypography.body.copyWith(
                            color: primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Status: ${_latest?.status ?? 'unknown'}',
                          style: PravaTypography.caption.copyWith(
                            color: secondary,
                          ),
                        ),
                        Text(
                          'Created: ${_formatDate(_latest?.createdAt)}',
                          style: PravaTypography.caption.copyWith(
                            color: secondary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        PravaButton(
                          label: 'Copy export JSON',
                          onPressed: _copyExport,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}
