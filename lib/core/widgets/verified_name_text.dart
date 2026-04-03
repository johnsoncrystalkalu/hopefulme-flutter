import 'package:flutter/material.dart';

class VerifiedNameText extends StatelessWidget {
  const VerifiedNameText({
    required this.name,
    required this.verified,
    this.style,
    this.textAlign,
    this.maxLines = 1,
    this.overflow = TextOverflow.ellipsis,
    this.badgeSize = 16,
    super.key,
  });

  final String name;
  final bool verified;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int maxLines;
  final TextOverflow overflow;
  final double badgeSize;

  @override
  Widget build(BuildContext context) {
    final resolvedStyle = style ?? DefaultTextStyle.of(context).style;

    if (!verified) {
      return Text(
        name,
        style: resolvedStyle,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
      );
    }

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: name),
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(start: 6),
              child: Icon(
                Icons.verified_rounded,
                size: badgeSize,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
      style: resolvedStyle,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}
