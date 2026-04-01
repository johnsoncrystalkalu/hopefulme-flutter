import 'package:flutter/material.dart';
import 'package:hopefulme_flutter/app/theme/app_theme.dart';
import 'package:hopefulme_flutter/core/network/image_url_resolver.dart';
import 'package:hopefulme_flutter/core/widgets/shimmer_widget.dart';

class AppAvatar extends StatelessWidget {
  const AppAvatar({
    required this.imageUrl,
    required this.label,
    this.radius = 18,
    this.backgroundColor,
    this.size,
    this.showShimmer = true,
    super.key,
  });

  final String imageUrl;
  final String label;
  final double radius;
  final Color? backgroundColor;
  final int? size;
  final bool showShimmer;

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

    return SizedBox(
      width: radius * 2,
      height: radius * 2,
      child: hasImage
          ? _AvatarWithLoading(
              imageUrl: resolved,
              radius: radius,
              bg: bg,
              initials: initials,
              colors: colors,
              showShimmer: showShimmer,
            )
          : CircleAvatar(
              radius: radius,
              backgroundColor: bg,
              child: Text(
                initials,
                style: TextStyle(
                  color: colors.accentSoftText,
                  fontSize: radius * 0.55,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
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

class _AvatarWithLoading extends StatelessWidget {
  const _AvatarWithLoading({
    required this.imageUrl,
    required this.radius,
    required this.bg,
    required this.initials,
    required this.colors,
    required this.showShimmer,
  });

  final String imageUrl;
  final double radius;
  final Color bg;
  final String initials;
  final AppThemeColors colors;
  final bool showShimmer;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: bg,
      child: ClipOval(
        child: Image.network(
          imageUrl,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          loadingBuilder: showShimmer
              ? (context, child, loadingProgress) {
                  if (loadingProgress == null) {
                    return child;
                  }
                  return AppShimmer.circular(
                    size: radius * 2,
                    baseColor: bg,
                    highlightColor: colors.surface,
                  );
                }
              : null,
          errorBuilder: (context, error, stackTrace) => Center(
            child: Text(
              initials,
              style: TextStyle(
                color: colors.accentSoftText,
                fontSize: radius * 0.55,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
