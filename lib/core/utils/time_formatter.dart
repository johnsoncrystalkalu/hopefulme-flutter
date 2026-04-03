String formatRelativeTimestamp(String input) {
  if (input.trim().isEmpty) {
    return '';
  }

  final parsed = DateTime.tryParse(input)?.toLocal();
  if (parsed == null) {
    return input;
  }

  final now = DateTime.now();
  final diff = now.difference(parsed);

  if (diff.inSeconds < 45) {
    return 'Just now';
  }
  if (diff.inMinutes < 60) {
    return '${diff.inMinutes}m ago';
  }
  if (diff.inHours < 24) {
    return '${diff.inHours}h ago';
  }
  if (diff.inDays < 7) {
    return '${diff.inDays}d ago';
  }
  if (diff.inDays < 30) {
    return '${(diff.inDays / 7).floor()}w ago';
  }
  if (diff.inDays < 180) {
    return '${(diff.inDays / 30).floor()}mo ago';
  }
  return _formatShortDate(parsed);
}

String formatDetailedTimestamp(String input) {
  if (input.trim().isEmpty) {
    return '';
  }

  final parsed = DateTime.tryParse(input)?.toLocal();
  if (parsed == null) {
    return input;
  }

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final date = DateTime(parsed.year, parsed.month, parsed.day);
  final dayDiff = today.difference(date).inDays;

  final timePart = _formatTime(parsed);
  if (dayDiff == 0) {
    return 'Today at $timePart';
  }
  if (dayDiff == 1) {
    return 'Yesterday at $timePart';
  }
  return '${_monthName(parsed.month)} ${parsed.day} at $timePart';
}

String formatConversationListTimestamp(String input) {
  if (input.trim().isEmpty) {
    return '';
  }

  final parsed = DateTime.tryParse(input)?.toLocal();
  if (parsed == null) {
    return input;
  }

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final date = DateTime(parsed.year, parsed.month, parsed.day);
  final dayDiff = today.difference(date).inDays;

  if (dayDiff == 0) {
    return _formatTime(parsed);
  }
  if (dayDiff == 1) {
    return 'Yesterday';
  }
  if (dayDiff < 7) {
    return _weekdayName(parsed.weekday);
  }
  return '${_monthName(parsed.month)} ${parsed.day}';
}

String _formatTime(DateTime value) {
  final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
  final minute = value.minute.toString().padLeft(2, '0');
  final period = value.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $period';
}

String _formatShortDate(DateTime value) {
  return '${value.day} ${_monthName(value.month)} ${value.year}';
}

String _monthName(int month) {
  const months = <String>[
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
  return months[month - 1];
}

String _weekdayName(int weekday) {
  const weekdays = <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return weekdays[weekday - 1];
}
