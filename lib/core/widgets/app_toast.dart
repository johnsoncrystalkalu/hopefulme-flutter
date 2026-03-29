import 'package:flutter/material.dart';
import 'package:hopefulme_flutter/app/theme/app_theme.dart';

enum AppToastType { success, error, info }

class AppToast {
  static void success(BuildContext context, String message) {
    _show(context, message: message, type: AppToastType.success);
  }

  static void error(BuildContext context, Object error) {
    _show(
      context,
      message: _normalizeMessage(error),
      type: AppToastType.error,
      duration: const Duration(seconds: 5),
    );
  }

  static void info(BuildContext context, String message) {
    _show(context, message: message, type: AppToastType.info);
  }

  static void _show(
    BuildContext context, {
    required String message,
    required AppToastType type,
    Duration duration = const Duration(seconds: 3),
  }) {
    final colors = context.appColors;
    final messenger = ScaffoldMessenger.of(context);
    final palette = _ToastPalette.fromType(colors, type);

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: duration,
          elevation: 0,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          backgroundColor: Colors.transparent,
          padding: EdgeInsets.zero,
          content: Container(
            decoration: BoxDecoration(
              color: palette.background,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: palette.border),
              boxShadow: [
                BoxShadow(
                  color: colors.shadow.withValues(alpha: 0.12),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: palette.iconSurface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(palette.icon, color: palette.iconColor, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(
                      message,
                      style: TextStyle(
                        color: palette.text,
                        fontSize: 13.5,
                        height: 1.35,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
  }

  static String _normalizeMessage(Object error) {
    final raw = error.toString().trim();
    if (raw.isEmpty) {
      return 'Something went wrong. Please try again.';
    }

    final cleaned = raw.startsWith('Exception: ')
        ? raw.substring('Exception: '.length)
        : raw;

    return cleaned;
  }
}

class _ToastPalette {
  const _ToastPalette({
    required this.background,
    required this.border,
    required this.text,
    required this.iconSurface,
    required this.iconColor,
    required this.icon,
  });

  final Color background;
  final Color border;
  final Color text;
  final Color iconSurface;
  final Color iconColor;
  final IconData icon;

  factory _ToastPalette.fromType(AppThemeColors colors, AppToastType type) {
    switch (type) {
      case AppToastType.success:
        return _ToastPalette(
          background: colors.surface,
          border: colors.success.withValues(alpha: 0.18),
          text: colors.textPrimary,
          iconSurface: colors.success.withValues(alpha: 0.12),
          iconColor: colors.success,
          icon: Icons.check_rounded,
        );
      case AppToastType.error:
        return _ToastPalette(
          background: colors.surface,
          border: colors.dangerText.withValues(alpha: 0.18),
          text: colors.textPrimary,
          iconSurface: colors.dangerSoft,
          iconColor: colors.dangerText,
          icon: Icons.close_rounded,
        );
      case AppToastType.info:
        return _ToastPalette(
          background: colors.surface,
          border: colors.brand.withValues(alpha: 0.16),
          text: colors.textPrimary,
          iconSurface: colors.accentSoft,
          iconColor: colors.brand,
          icon: Icons.info_outline_rounded,
        );
    }
  }
}
