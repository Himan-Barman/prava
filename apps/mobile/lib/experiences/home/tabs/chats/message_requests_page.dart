import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../services/chat_service.dart';
import '../../../../services/e2ee_service.dart';
import '../../../../services/group_e2ee_service.dart';
import '../../../../ui-system/background.dart';
import '../../../../ui-system/colors.dart';
import '../../../../ui-system/feedback/prava_toast.dart';
import '../../../../ui-system/feedback/toast_type.dart';
import '../../../../ui-system/typography.dart';

class MessageRequestsPage extends StatefulWidget {
  const MessageRequestsPage({super.key});

  @override
  State<MessageRequestsPage> createState() => _MessageRequestsPageState();
}

class _MessageRequestsPageState extends State<MessageRequestsPage> {
  final ChatService _chatService = ChatService();

  List<ConversationSummary> _requests = [];
  final Set<String> _pending = <String>{};
  bool _loading = true;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() => _loading = true);
    try {
      final requests = await _chatService.listMessageRequests();
      if (!mounted) return;
      setState(() {
        _requests = requests;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      PravaToast.show(
        context,
        message: 'Unable to load message requests',
        type: PravaToastType.error,
      );
    }
  }

  bool _isPending(String id) => _pending.contains(id);

  Future<void> _accept(ConversationSummary request) async {
    if (_isPending(request.id)) return;
    HapticFeedback.selectionClick();
    setState(() => _pending.add(request.id));
    try {
      final ok = await _chatService.acceptMessageRequest(request.id);
      if (!mounted) return;
      if (ok) {
        setState(() {
          _changed = true;
          _pending.remove(request.id);
          _requests.removeWhere((item) => item.id == request.id);
        });
        PravaToast.show(
          context,
          message: 'Message request accepted',
          type: PravaToastType.success,
        );
      } else {
        setState(() => _pending.remove(request.id));
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _pending.remove(request.id));
      PravaToast.show(
        context,
        message: 'Unable to accept request',
        type: PravaToastType.error,
      );
    }
  }

  Future<void> _remove(ConversationSummary request) async {
    if (_isPending(request.id)) return;
    HapticFeedback.selectionClick();
    setState(() => _pending.add(request.id));
    try {
      final ok = await _chatService.declineMessageRequest(request.id);
      if (!mounted) return;
      if (ok) {
        setState(() {
          _changed = true;
          _pending.remove(request.id);
          _requests.removeWhere((item) => item.id == request.id);
        });
        PravaToast.show(
          context,
          message: 'Message request removed',
          type: PravaToastType.info,
        );
      } else {
        setState(() => _pending.remove(request.id));
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _pending.remove(request.id));
      PravaToast.show(
        context,
        message: 'Unable to remove request',
        type: PravaToastType.error,
      );
    }
  }

  String _preview(ConversationSummary request) {
    final body = request.lastMessageBody.trim();
    if (request.lastMessageDeletedForAllAt != null) return 'Message deleted';
    if (request.lastMessageType == ChatMessageType.media) {
      return 'Media message';
    }
    if (E2eeService.isEncrypted(body) ||
        GroupE2eeService.isGroupEncrypted(body)) {
      return 'Encrypted message';
    }
    return body.isEmpty ? 'New message' : body;
  }

  String _time(DateTime? value) {
    if (value == null) return '';
    final localValue = value.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(localValue.year, localValue.month, localValue.day);
    final diffDays = today.difference(target).inDays;
    if (diffDays == 0) {
      final hour = localValue.hour;
      final minute = localValue.minute.toString().padLeft(2, '0');
      final suffix = hour >= 12 ? 'PM' : 'AM';
      final hour12 = hour % 12 == 0 ? 12 : hour % 12;
      return '$hour12:$minute $suffix';
    }
    if (diffDays == 1) return 'Yesterday';
    return '${localValue.month}/${localValue.day}/${localValue.year}';
  }

  void _close() {
    Navigator.of(context).pop(_changed);
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
    final surface = isDark
        ? PravaColors.darkBgSurface
        : PravaColors.lightBgSurface;
    final border = isDark
        ? PravaColors.darkBorderSubtle
        : PravaColors.lightBorderSubtle;

    return Scaffold(
      body: Stack(
        children: [
          PravaBackground(isDark: isDark),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: _close,
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white10 : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: border),
                          ),
                          child: Icon(
                            CupertinoIcons.back,
                            color: primary,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Message requests',
                        style: PravaTypography.h3.copyWith(
                          color: primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _loading
                      ? const Center(child: CupertinoActivityIndicator())
                      : RefreshIndicator(
                          color: PravaColors.accentPrimary,
                          onRefresh: _loadRequests,
                          child: _requests.isEmpty
                              ? _EmptyRequests(
                                  primary: primary,
                                  secondary: secondary,
                                )
                              : ListView.separated(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    0,
                                    16,
                                    20,
                                  ),
                                  physics: const BouncingScrollPhysics(
                                    parent: AlwaysScrollableScrollPhysics(),
                                  ),
                                  itemCount: _requests.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 12),
                                  itemBuilder: (context, index) {
                                    final request = _requests[index];
                                    return _RequestCard(
                                      request: request,
                                      preview: _preview(request),
                                      time: _time(
                                        request.lastMessageAt ??
                                            request.updatedAt,
                                      ),
                                      pending: _isPending(request.id),
                                      primary: primary,
                                      secondary: secondary,
                                      surface: surface,
                                      border: border,
                                      onAccept: () => _accept(request),
                                      onRemove: () => _remove(request),
                                    );
                                  },
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

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.request,
    required this.preview,
    required this.time,
    required this.pending,
    required this.primary,
    required this.secondary,
    required this.surface,
    required this.border,
    required this.onAccept,
    required this.onRemove,
  });

  final ConversationSummary request;
  final String preview;
  final String time;
  final bool pending;
  final Color primary;
  final Color secondary;
  final Color surface;
  final Color border;
  final VoidCallback onAccept;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final name = request.title.isEmpty ? 'Conversation' : request.title;
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();

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
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor:
                    PravaColors.accentPrimary.withValues(alpha: 0.16),
                child: Text(
                  initial,
                  style: PravaTypography.h3.copyWith(
                    color: PravaColors.accentPrimary,
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
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: PravaTypography.body.copyWith(
                        color: primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: PravaTypography.caption.copyWith(
                        color: secondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (time.isNotEmpty)
                Text(
                  time,
                  style: PravaTypography.caption.copyWith(color: secondary),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _RequestButton(
                  label: 'Accept',
                  filled: true,
                  pending: pending,
                  onTap: onAccept,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _RequestButton(
                  label: 'Remove',
                  filled: false,
                  pending: pending,
                  onTap: onRemove,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RequestButton extends StatelessWidget {
  const _RequestButton({
    required this.label,
    required this.filled,
    required this.pending,
    required this.onTap,
  });

  final String label;
  final bool filled;
  final bool pending;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border = isDark
        ? PravaColors.darkBorderSubtle
        : PravaColors.lightBorderSubtle;

    return GestureDetector(
      onTap: pending ? null : onTap,
      child: Container(
        height: 42,
        decoration: BoxDecoration(
          color: filled ? PravaColors.accentPrimary : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: filled ? Colors.transparent : border,
          ),
        ),
        child: Center(
          child: pending
              ? const CupertinoActivityIndicator(radius: 8)
              : Text(
                  label,
                  style: PravaTypography.button.copyWith(
                    color: filled ? Colors.white : PravaColors.accentPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      ),
    );
  }
}

class _EmptyRequests extends StatelessWidget {
  const _EmptyRequests({
    required this.primary,
    required this.secondary,
  });

  final Color primary;
  final Color secondary;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 120, 24, 24),
      children: [
        Icon(CupertinoIcons.tray, size: 42, color: secondary),
        const SizedBox(height: 14),
        Text(
          'No message requests',
          textAlign: TextAlign.center,
          style: PravaTypography.h3.copyWith(
            color: primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Messages from people who are not friends appear here first.',
          textAlign: TextAlign.center,
          style: PravaTypography.body.copyWith(color: secondary),
        ),
      ],
    );
  }
}
