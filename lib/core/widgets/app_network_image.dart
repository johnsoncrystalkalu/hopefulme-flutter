import 'package:flutter/material.dart';
import 'package:hopefulme_flutter/app/theme/app_theme.dart';

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
    this.showLoader = true,
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
  final bool showLoader;

  @override
  Widget build(BuildContext context) {
    final child = imageUrl.trim().isEmpty
        ? _FallbackImage(
            label: placeholderLabel,
            icon: placeholderIcon,
            backgroundColor: backgroundColor,
          )
        : Image.network(
            imageUrl,
            width: width,
            height: height,
            fit: fit,
            loadingBuilder: showLoader
                ? (context, child, loadingProgress) {
                    if (loadingProgress == null) {
                      return child;
                    }
                    return _FallbackImage(
                      label: placeholderLabel,
                      icon: placeholderIcon,
                      backgroundColor: backgroundColor,
                      isLoading: true,
                    );
                  }
                : null,
            errorBuilder: (context, error, stackTrace) => _FallbackImage(
              label: placeholderLabel,
              icon: placeholderIcon,
              backgroundColor: backgroundColor,
            ),
          );

    if (borderRadius == null) {
      return child;
    }

    return ClipRRect(borderRadius: borderRadius!, child: child);
  }
}

class _FallbackImage extends StatelessWidget {
  const _FallbackImage({
    required this.label,
    required this.icon,
    required this.backgroundColor,
    this.isLoading = false,
  });

  final String? label;
  final IconData icon;
  final Color? backgroundColor;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final initials = _initials(label ?? '');
    final bg = backgroundColor ?? colors.surfaceMuted;

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: bg,
      alignment: Alignment.center,
      child: isLoading
          ? SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colors.brand,
              ),
            )
          : Column(
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
