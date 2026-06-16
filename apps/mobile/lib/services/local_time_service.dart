class LocalTimeService {
  const LocalTimeService();

  DateTime local(DateTime value) => value.toLocal();

  String shortRelative(DateTime value) {
    final localValue = value.toLocal();
    final diff = DateTime.now().difference(localValue);

    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';

    final month = localValue.month.toString().padLeft(2, '0');
    final day = localValue.day.toString().padLeft(2, '0');
    return '$month/$day/${localValue.year}';
  }

  String chatClock(DateTime value) {
    final localValue = value.toLocal();
    final hour = localValue.hour;
    final minute = localValue.minute.toString().padLeft(2, '0');
    final suffix = hour >= 12 ? 'PM' : 'AM';
    final hour12 = hour % 12 == 0 ? 12 : hour % 12;
    return '$hour12:$minute $suffix';
  }

  String chatDate(DateTime value) {
    final localValue = value.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(localValue.year, localValue.month, localValue.day);
    final diff = today.difference(target).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${months[localValue.month - 1]} ${localValue.day}';
  }
}
