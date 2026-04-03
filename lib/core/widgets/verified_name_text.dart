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

    return Wrap(
      alignment: _wrapAlignmentFor(textAlign),
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      children: [
        Text(
          name,
          style: resolvedStyle,
          textAlign: textAlign,
          maxLines: maxLines,
          overflow: overflow,
        ),
        Icon(
          Icons.verified_rounded,
          size: badgeSize,
          color: const Color(0xFF2563EB),
        ),
      ],
    );
  }

  WrapAlignment _wrapAlignmentFor(TextAlign? align) {
    return switch (align) {
      TextAlign.center => WrapAlignment.center,
      TextAlign.right || TextAlign.end => WrapAlignment.end,
      TextAlign.justify => WrapAlignment.spaceBetween,
      _ => WrapAlignment.start,
    };
  }
}
