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
    final dpr = MediaQuery.maybeOf(context)?.devicePixelRatio ?? 1;
    final cacheWidth = _resolveCacheDimension(width, dpr);
    final cacheHeight = _resolveCacheDimension(height, dpr);

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
        cacheWidth: cacheWidth,
        cacheHeight: cacheHeight,
        fit: fit,
        filterQuality: FilterQuality.low,
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final resolvedWidth = _resolveDimension(
          explicitValue: width,
          maxConstraint: constraints.maxWidth,
        );
        final resolvedHeight = _resolveDimension(
          explicitValue: height,
          maxConstraint: constraints.maxHeight,
          fallbackValue: 200,
        );

        return SizedBox(
          width: resolvedWidth,
          height: resolvedHeight,
          child: ColoredBox(
            color: backgroundColor,
            child: const Center(
              child: ShimmerBox(
                width: double.infinity,
                height: double.infinity,
                borderRadius: 0,
              ),
            ),
          ),
        );
      },
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final resolvedWidth = _resolveDimension(
          maxConstraint: constraints.maxWidth,
        );
        final resolvedHeight = _resolveDimension(
          maxConstraint: constraints.maxHeight,
          fallbackValue: 200,
        );

        return SizedBox(
          width: resolvedWidth,
          height: resolvedHeight,
          child: ColoredBox(
            color: bg,
            child: Center(
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
            ),
          ),
        );
      },
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

double? _resolveDimension({
  double? explicitValue,
  required double maxConstraint,
  double? fallbackValue,
}) {
  if (explicitValue != null) {
    return explicitValue;
  }

  if (maxConstraint.isFinite) {
    return maxConstraint;
  }

  return fallbackValue;
}

int? _resolveCacheDimension(double? dimension, double dpr) {
  if (dimension == null || !dimension.isFinite || dimension <= 0) {
    return null;
  }

  return (dimension * dpr).round();
}
