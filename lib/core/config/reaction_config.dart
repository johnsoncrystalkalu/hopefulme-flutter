class ReactionConfig {
  const ReactionConfig._();

  // Fast conversational reactions for message and group threads.
  static const List<String> chatQuick = <String>[
    '\u2764\uFE0F',
    '\u{1F44D}',
    '\u{1F602}',
    '\u{1F64F}',
  ];

  // Broader expressive reactions for updates/feed content.
  static const List<String> updateQuick = <String>[
    '\u2764\uFE0F',
    '\u{1F917}',
    '\u{1F525}',
    '\u{1F602}',
    '\u{1F973}',
    '\u{1F64F}',
    '\u{1F4AA}',
  ];

  static const int updatePreviewMax = 4;
}
