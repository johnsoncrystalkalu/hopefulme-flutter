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
  if (diff.inDays < 365) {
    return '${(diff.inDays / 30).floor()}mo ago';
  }
  return '${(diff.inDays / 365).floor()}y ago';
}
