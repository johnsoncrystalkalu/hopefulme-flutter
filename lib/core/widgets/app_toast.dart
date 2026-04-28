import 'package:flutter/material.dart';
import 'package:hopefulme_flutter/app/theme/app_theme.dart';
import 'package:hopefulme_flutter/core/utils/app_error_text.dart';

enum AppToastType { success, error, info, warning, loading, offline }

class AppToast {
  static void success(BuildContext context, String message) {
    _show(context, message: message, type: AppToastType.success);
  }

  static void error(BuildContext context, Object error) {
    if (AppErrorText.isOffline(error)) {
      _show(
        context,
        message: AppErrorText.message(error),
        type: AppToastType.offline,
        duration: const Duration(seconds: 5),
      );
      return;
    }

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

  static void warning(BuildContext context, String message) {
    _show(context, message: message, type: AppToastType.warning);
  }

  static void loading(
    BuildContext context, {
    String message = 'Loading...',
    bool persistent = false,
  }) {
    _show(
      context,
      message: message,
      type: AppToastType.loading,
      duration: persistent
          ? const Duration(hours: 1)
          : const Duration(seconds: 30),
    );
  }

  static void dismiss(BuildContext context) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
  }

  static void _show(
    BuildContext context, {
    required String message,
    required AppToastType type,
    Duration duration = const Duration(seconds: 3),
  }) {
    final messenger = ScaffoldMessenger.of(context);
    final colors = context.appColors;
    final palette = _ToastPalette.fromType(colors, type);

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: duration,
        elevation: 0,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 18),
        backgroundColor: palette.background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: palette.border),
        ),
        dismissDirection: type == AppToastType.loading
            ? DismissDirection.none
            : DismissDirection.horizontal,
        animation: kAlwaysCompleteAnimation,
        content: Row(
          children: [
            if (type == AppToastType.loading)
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  valueColor: AlwaysStoppedAnimation<Color>(palette.iconColor),
                ),
              )
            else
              Icon(
                palette.icon,
                color: palette.iconColor,
                size: 18,
              ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: palette.text,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _normalizeMessage(Object error) {
    final raw = error.toString().trim();
    if (raw.isEmpty) {
      return 'Something went wrong. Please try again.';
    }

    return raw.startsWith('Exception: ')
        ? raw.substring('Exception: '.length)
        : raw;
  }
}

class _ToastPalette {
  const _ToastPalette({
    required this.background,
    required this.border,
    required this.text,
    required this.iconColor,
    required this.icon,
  });

  final Color background;
  final Color border;
  final Color text;
  final Color iconColor;
  final IconData icon;

  factory _ToastPalette.fromType(AppThemeColors colors, AppToastType type) {
    return switch (type) {
      AppToastType.success => _ToastPalette(
          background: colors.surface,
          border: colors.success.withValues(alpha: 0.22),
          text: colors.textPrimary,
          iconColor: colors.success,
          icon: Icons.check_circle_outline_rounded,
        ),
      AppToastType.error => _ToastPalette(
          background: colors.surface,
          border: colors.dangerText.withValues(alpha: 0.22),
          text: colors.textPrimary,
          iconColor: colors.dangerText,
          icon: Icons.error_outline_rounded,
        ),
      AppToastType.info => _ToastPalette(
          background: colors.surface,
          border: colors.brand.withValues(alpha: 0.2),
          text: colors.textPrimary,
          iconColor: colors.brand,
          icon: Icons.info_outline_rounded,
        ),
      AppToastType.warning => _ToastPalette(
          background: colors.surface,
          border: colors.warningText.withValues(alpha: 0.24),
          text: colors.textPrimary,
          iconColor: colors.warningText,
          icon: Icons.warning_amber_rounded,
        ),
      AppToastType.loading => _ToastPalette(
          background: colors.surface,
          border: colors.brand.withValues(alpha: 0.2),
          text: colors.textPrimary,
          iconColor: colors.brand,
          icon: Icons.sync_rounded,
        ),
      AppToastType.offline => _ToastPalette(
          background: colors.surface,
          border: colors.borderStrong,
          text: colors.textPrimary,
          iconColor: colors.textMuted,
          icon: Icons.wifi_off_rounded,
        ),
    };
  }
}
