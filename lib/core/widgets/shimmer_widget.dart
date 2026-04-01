import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:hopefulme_flutter/app/theme/app_theme.dart';

class AppShimmer extends StatelessWidget {
  const AppShimmer._({
    required this.child,
    required this.baseColor,
    required this.highlightColor,
    super.key,
  });

  final Widget child;
  final Color baseColor;
  final Color highlightColor;

  factory AppShimmer.rectangular({
    required double width,
    required double height,
    double borderRadius = 8,
    Color? baseColor,
    Color? highlightColor,
  }) {
    return AppShimmer._(
      baseColor: baseColor ?? Colors.grey[300]!,
      highlightColor: highlightColor ?? Colors.grey[100]!,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }

  factory AppShimmer.circular({
    required double size,
    Color? baseColor,
    Color? highlightColor,
  }) {
    return AppShimmer._(
      baseColor: baseColor ?? Colors.grey[300]!,
      highlightColor: highlightColor ?? Colors.grey[100]!,
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: child,
    );
  }
}

class ShimmerBox extends StatelessWidget {
  const ShimmerBox({
    super.key,
    this.width = double.infinity,
    this.height = 16,
    this.borderRadius = 8,
  });

  final double width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return AppShimmer.rectangular(
      width: width,
      height: height,
      borderRadius: borderRadius,
      baseColor: colors.surfaceMuted,
      highlightColor: colors.surface,
    );
  }
}

class ShimmerCircle extends StatelessWidget {
  const ShimmerCircle({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return AppShimmer.circular(
      size: size,
      baseColor: colors.surfaceMuted,
      highlightColor: colors.surface,
    );
  }
}

class ShimmerCard extends StatelessWidget {
  const ShimmerCard({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const ShimmerCircle(size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerBox(width: 120, height: 14),
                    const SizedBox(height: 6),
                    ShimmerBox(width: 80, height: 12),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const ShimmerBox(height: 12),
          const SizedBox(height: 8),
          const ShimmerBox(height: 12),
          const SizedBox(height: 8),
          ShimmerBox(width: 180, height: 12),
        ],
      ),
    );
  }
}
