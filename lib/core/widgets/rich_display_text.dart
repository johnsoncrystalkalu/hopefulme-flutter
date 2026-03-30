import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class RichDisplayText extends StatefulWidget {
  const RichDisplayText({
    required this.text,
    required this.style,
    this.mentionStyle,
    this.hashtagStyle,
    this.linkStyle,
    this.maxLines,
    this.overflow = TextOverflow.clip,
    this.onMentionTap,
    this.onHashtagTap,
    this.onLinkTap,
    super.key,
  });

  final String text;
  final TextStyle style;
  final TextStyle? mentionStyle;
  final TextStyle? hashtagStyle;
  final TextStyle? linkStyle;
  final int? maxLines;
  final TextOverflow overflow;
  final Future<void> Function(String username)? onMentionTap;
  final Future<void> Function(String hashtag)? onHashtagTap;
  final Future<void> Function(String url)? onLinkTap;

  @override
  State<RichDisplayText> createState() => _RichDisplayTextState();
}

class _RichDisplayTextState extends State<RichDisplayText> {
  static final RegExp _pattern = RegExp(r'(@[A-Za-z0-9_]+|#[A-Za-z0-9_]+|(?:https?|ftp):\/\/[^\s/$.?#].[^\s]*)');
  final List<TapGestureRecognizer> _recognizers = <TapGestureRecognizer>[];
  List<InlineSpan>? _cachedSpans;
  String? _lastProcessedText;

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.text.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    if (_lastProcessedText != widget.text) {
      _disposeRecognizers();
      _lastProcessedText = widget.text;
      _cachedSpans = _buildSpans(context);
    }

    return Text.rich(
      TextSpan(children: _cachedSpans ?? [], style: widget.style),
      maxLines: widget.maxLines,
      overflow: widget.overflow,
    );
  }

  List<InlineSpan> _buildSpans(BuildContext context) {
    final spans = <InlineSpan>[];
    var start = 0;

    for (final match in _pattern.allMatches(widget.text)) {
      if (match.start > start) {
        spans.add(
          TextSpan(
            text: widget.text.substring(start, match.start),
            style: widget.style,
          ),
        );
      }

      final token = match.group(0)!;
      final isMention = token.startsWith('@');
      final isHashtag = token.startsWith('#');
      final isUrl = !isMention && !isHashtag;

      final value = isUrl ? token : token.substring(1);
      
      final Function(String)? onTap = isUrl 
          ? widget.onLinkTap 
          : (isMention ? widget.onMentionTap : widget.onHashtagTap);

      final tokenStyle = isUrl
          ? widget.linkStyle ?? _defaultInteractiveStyle(context)
          : (isMention
              ? widget.mentionStyle ?? _defaultInteractiveStyle(context)
              : widget.hashtagStyle ?? _defaultInteractiveStyle(context));

      if (onTap != null) {
        final recognizer = TapGestureRecognizer()..onTap = () {
          onTap(value);
        };
        _recognizers.add(recognizer);
        spans.add(
          TextSpan(text: token, style: tokenStyle, recognizer: recognizer),
        );
      } else {
        spans.add(TextSpan(text: token, style: tokenStyle));
      }

      start = match.end;
    }

    if (start < widget.text.length) {
      spans.add(
        TextSpan(text: widget.text.substring(start), style: widget.style),
      );
    }

    return spans;
  }

  TextStyle _defaultInteractiveStyle(BuildContext context) {
    return widget.style.copyWith(
      color: Theme.of(context).colorScheme.primary,
      fontWeight: FontWeight.w700,
    );
  }

  void _disposeRecognizers() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }
}
