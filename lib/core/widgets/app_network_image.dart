import 'package:flutter/material.dart';
import 'package:hopefulme_flutter/app/theme/app_theme.dart';
import 'package:hopefulme_flutter/core/widgets/shimmer_widget.dart';

class AppNetworkImage extends StatelessWidget {
  const AppNetworkImage({
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.backgroundColor,
    this.placeholderLabel,
    this.placeholderIcon = Icons.image_outlined,
    this.showShimmer = true,
    super.key,
  });

  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadiusGeometry? borderRadius;
  final Color? backgroundColor;
  final String? placeholderLabel;
  final IconData placeholderIcon;
  final bool showShimmer;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final bg = backgroundColor ?? colors.surfaceMuted;

    Widget child;

    if (imageUrl.trim().isEmpty) {
      child = _FallbackImage(
        label: placeholderLabel,
        icon: placeholderIcon,
        backgroundColor: bg,
      );
    } else {
      child = Image.network(
        imageUrl,
        width: width,
        height: height,
        fit: fit,
        loadingBuilder: showShimmer
            ? (context, child, loadingProgress) {
                if (loadingProgress == null) {
                  return child;
                }
                return _ShimmerLoading(
                  width: width,
                  height: height,
                  backgroundColor: bg,
                );
              }
            : null,
        errorBuilder: (context, error, stackTrace) => _FallbackImage(
          label: placeholderLabel,
          icon: placeholderIcon,
          backgroundColor: bg,
        ),
      );
    }

    if (borderRadius == null) {
      return child;
    }

    return ClipRRect(borderRadius: borderRadius!, child: child);
  }
}

class _ShimmerLoading extends StatelessWidget {
  const _ShimmerLoading({
    this.width,
    this.height,
    required this.backgroundColor,
  });

  final double? width;
  final double? height;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width ?? double.infinity,
      height: height ?? 200,
      color: backgroundColor,
      child: const Center(
        child: ShimmerBox(
          width: double.infinity,
          height: double.infinity,
          borderRadius: 0,
        ),
      ),
    );
  }
}

class _FallbackImage extends StatelessWidget {
  const _FallbackImage({
    required this.label,
    required this.icon,
    required this.backgroundColor,
  });

  final String? label;
  final IconData icon;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final initials = _initials(label ?? '');
    final bg = backgroundColor;

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: bg,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: colors.textMuted, size: 26),
          if (initials.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              initials,
              style: TextStyle(
                color: colors.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _initials(String value) {
    final parts = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();
    return parts;
  }
}
