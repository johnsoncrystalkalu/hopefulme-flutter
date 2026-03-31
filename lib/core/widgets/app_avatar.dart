import 'package:flutter/material.dart';
import 'package:hopefulme_flutter/app/theme/app_theme.dart';
import 'package:hopefulme_flutter/core/network/image_url_resolver.dart';

class AppAvatar extends StatelessWidget {
  const AppAvatar({
    required this.imageUrl,
    required this.label,
    this.radius = 18,
    this.backgroundColor,
    this.size,
    super.key,
  });

  final String imageUrl;
  final String label;
  final double radius;
  final Color? backgroundColor;
  final int? size;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final bg = backgroundColor ?? colors.avatarPlaceholder;
    final initials = _initials(label);
    final resolved = ImageUrlResolver.avatar(
      imageUrl,
      size: size ?? (radius * 2 * 1.5).round(),
    );
    final hasImage = imageUrl.trim().isNotEmpty;

    return CircleAvatar(
      radius: radius,
      backgroundColor: bg,
      backgroundImage: hasImage ? NetworkImage(resolved) : null,
      onBackgroundImageError: (_, error) {},
      child: !hasImage
          ? Text(
              initials,
              style: TextStyle(
                color: colors.accentSoftText,
                fontSize: radius * 0.55,
                fontWeight: FontWeight.w800,
              ),
            )
          : null,
    );
  }

  static String _initials(String input) {
    final parts = input
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty);
    if (parts.isEmpty) {
      return 'U';
    }

    final letters = parts.take(2).map((part) => part[0].toUpperCase()).join();
    return letters.isEmpty ? 'U' : letters;
  }
}
