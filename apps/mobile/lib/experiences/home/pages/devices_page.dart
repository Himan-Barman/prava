import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../services/session_service.dart';
import '../../../ui-system/colors.dart';
import '../../../ui-system/typography.dart';
import '../../../ui-system/components/prava_button.dart';
import '../../../ui-system/feedback/prava_toast.dart';
import '../../../ui-system/feedback/toast_type.dart';
import 'settings_detail_shell.dart';

class DevicesPage extends StatefulWidget {
  const DevicesPage({super.key});

  @override
  State<DevicesPage> createState() => _DevicesPageState();
}

class _DevicesPageState extends State<DevicesPage> {
  final SessionService _service = SessionService();
  bool _loading = true;
  bool _revoking = false;
  List<DeviceSession> _sessions = [];
  String? _currentDeviceId;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    try {
      final current = await _service.currentDeviceId();
      final sessions = await _service.listSessions();
      if (!mounted) return;
      setState(() {
        _currentDeviceId = current;
        _sessions = sessions;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      PravaToast.show(
        context,
        message: 'Unable to load devices',
        type: PravaToastType.error,
      );
    }
  }

  Future<void> _revokeSession(DeviceSession session) async {
    if (_revoking) return;
    setState(() => _revoking = true);
    try {
      await _service.revokeSession(session.deviceId);
      if (!mounted) return;
      setState(() {
        _sessions = List<DeviceSession>.from(_sessions)
          ..removeWhere((item) => item.deviceId == session.deviceId);
        _revoking = false;
      });
      PravaToast.show(
        context,
        message: 'Signed out ${_deviceLabel(session)}',
        type: PravaToastType.success,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _revoking = false);
      PravaToast.show(
        context,
        message: 'Unable to sign out device',
        type: PravaToastType.error,
      );
    }
  }

  Future<void> _revokeOthers() async {
    final currentDeviceId = _currentDeviceId;
    if (currentDeviceId == null || _revoking) return;
    setState(() => _revoking = true);
    try {
      await _service.revokeOtherSessions(currentDeviceId);
      if (!mounted) return;
      setState(() {
        _sessions = _sessions
            .where((session) => session.deviceId == currentDeviceId)
            .toList();
        _revoking = false;
      });
      PravaToast.show(
        context,
        message: 'Signed out of other devices',
        type: PravaToastType.success,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _revoking = false);
      PravaToast.show(
        context,
        message: 'Unable to revoke other sessions',
        type: PravaToastType.error,
      );
    }
  }

  String _deviceLabel(DeviceSession session) {
    if (session.deviceName.isNotEmpty) return session.deviceName;
    if (session.platform.isNotEmpty) return session.platform;
    return session.deviceId.isNotEmpty
        ? 'Device ${session.deviceId.substring(0, 6)}'
        : 'Device';
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
      title: 'Devices',
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
                            'Sessions',
                            style: PravaTypography.h3.copyWith(
                              color: primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Sign out devices you no longer use.',
                            style: PravaTypography.bodySmall.copyWith(
                              color: secondary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          PravaButton(
                            label: 'Sign out of other devices',
                            loading: _revoking,
                            onPressed:
                                _sessions.length > 1 && !_revoking
                                    ? _revokeOthers
                                    : null,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (_sessions.isEmpty)
                  Text(
                    'No active sessions found.',
                    style: PravaTypography.body.copyWith(color: secondary),
                  )
                else
                  ..._sessions.map((session) {
                    final isCurrent =
                        session.deviceId == _currentDeviceId;
                    final subtitle =
                        'Last active ${_formatDate(session.lastSeenAt ?? session.createdAt)}';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Container(
                        padding: const EdgeInsets.all(14),
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
                                _deviceLabel(session)
                                    .substring(0, 1)
                                    .toUpperCase(),
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
                                  Text(
                                    _deviceLabel(session),
                                    style: PravaTypography.body.copyWith(
                                      color: primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    subtitle,
                                    style:
                                        PravaTypography.caption.copyWith(
                                      color: secondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isCurrent)
                              Text(
                                'This device',
                                style: PravaTypography.caption.copyWith(
                                  color: PravaColors.accentPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              )
                            else
                              TextButton(
                                onPressed: () =>
                                    _revokeSession(session),
                                child: Text(
                                  'Sign out',
                                  style: PravaTypography.button.copyWith(
                                    color: PravaColors.accentPrimary,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
              ],
            ),
    );
  }
}
