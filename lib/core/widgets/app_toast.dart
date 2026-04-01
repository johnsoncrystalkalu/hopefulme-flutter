import 'package:flutter/material.dart';
import 'package:hopefulme_flutter/app/theme/app_theme.dart';

enum AppToastType { success, error, info, warning, loading }

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
    final colors = context.appColors;
    final messenger = ScaffoldMessenger.of(context);
    final palette = _ToastPalette.fromType(colors, type);

    messenger.hideCurrentSnackBar();

    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: duration,
        elevation: 0,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 18),
        backgroundColor: Colors.transparent,
        padding: EdgeInsets.zero,
        dismissDirection: type == AppToastType.loading
            ? DismissDirection.none
            : DismissDirection.horizontal,
        animation: CurvedAnimation(
          parent: kAlwaysDismissedAnimation,
          curve: Curves.easeOutCubic,
        ),
        content: _ToastContent(
          message: message,
          palette: palette,
          type: type,
          duration: duration,
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

class _ToastContent extends StatefulWidget {
  const _ToastContent({
    required this.message,
    required this.palette,
    required this.type,
    required this.duration,
  });

  final String message;
  final _ToastPalette palette;
  final AppToastType type;
  final Duration duration;

  @override
  State<_ToastContent> createState() => _ToastContentState();
}

class _ToastContentState extends State<_ToastContent>
    with SingleTickerProviderStateMixin {
  late AnimationController _progressController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _progressController,
        curve: const Interval(0.0, 0.2, curve: Curves.easeOut),
        reverseCurve: const Interval(0.8, 1.0, curve: Curves.easeIn),
      ),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _progressController,
            curve: Curves.easeOutCubic,
          ),
        );

    if (widget.type != AppToastType.loading) {
      _progressController.forward();
    }
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isLoading = widget.type == AppToastType.loading;

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          decoration: BoxDecoration(
            color: widget.palette.background,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: widget.palette.border),
            boxShadow: [
              BoxShadow(
                color: colors.shadow.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    _AnimatedIcon(
                      palette: widget.palette,
                      isLoading: isLoading,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.message,
                        style: TextStyle(
                          color: widget.palette.text,
                          fontSize: 14,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (!isLoading)
                      IconButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        },
                        icon: Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: widget.palette.iconColor,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 28,
                          minHeight: 28,
                        ),
                      ),
                  ],
                ),
              ),
              if (!isLoading)
                AnimatedBuilder(
                  animation: _progressController,
                  builder: (context, child) {
                    return ClipRRect(
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(16),
                        bottomRight: Radius.circular(16),
                      ),
                      child: LinearProgressIndicator(
                        value: 1 - _progressController.value,
                        backgroundColor: Colors.transparent,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          widget.palette.progress,
                        ),
                        minHeight: 3,
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnimatedIcon extends StatefulWidget {
  const _AnimatedIcon({required this.palette, required this.isLoading});

  final _ToastPalette palette;
  final bool isLoading;

  @override
  State<_AnimatedIcon> createState() => _AnimatedIconState();
}

class _AnimatedIconState extends State<_AnimatedIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (widget.isLoading) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: widget.palette.iconSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: widget.isLoading
          ? ScaleTransition(
              scale: _pulseAnimation,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    widget.palette.iconColor,
                  ),
                ),
              ),
            )
          : Icon(
              widget.palette.icon,
              color: widget.palette.iconColor,
              size: 20,
            ),
    );
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
    required this.progress,
  });

  final Color background;
  final Color border;
  final Color text;
  final Color iconSurface;
  final Color iconColor;
  final IconData icon;
  final Color progress;

  factory _ToastPalette.fromType(AppThemeColors colors, AppToastType type) {
    switch (type) {
      case AppToastType.success:
        return _ToastPalette(
          background: colors.surface,
          border: colors.success.withValues(alpha: 0.2),
          text: colors.textPrimary,
          iconSurface: colors.success.withValues(alpha: 0.12),
          iconColor: colors.success,
          icon: Icons.check_rounded,
          progress: colors.success,
        );
      case AppToastType.error:
        return _ToastPalette(
          background: colors.surface,
          border: colors.dangerText.withValues(alpha: 0.2),
          text: colors.textPrimary,
          iconSurface: colors.dangerSoft,
          iconColor: colors.dangerText,
          icon: Icons.error_outline_rounded,
          progress: colors.dangerText,
        );
      case AppToastType.info:
        return _ToastPalette(
          background: colors.surface,
          border: colors.brand.withValues(alpha: 0.18),
          text: colors.textPrimary,
          iconSurface: colors.accentSoft,
          iconColor: colors.brand,
          icon: Icons.info_outline_rounded,
          progress: colors.brand,
        );
      case AppToastType.warning:
        return _ToastPalette(
          background: colors.surface,
          border: const Color(0xFFF59E0B).withValues(alpha: 0.25),
          text: colors.textPrimary,
          iconSurface: const Color(0xFFFEF3C7),
          iconColor: const Color(0xFFF59E0B),
          icon: Icons.warning_amber_rounded,
          progress: const Color(0xFFF59E0B),
        );
      case AppToastType.loading:
        return _ToastPalette(
          background: colors.surface,
          border: colors.brand.withValues(alpha: 0.15),
          text: colors.textPrimary,
          iconSurface: colors.accentSoft,
          iconColor: colors.brand,
          icon: Icons.sync_rounded,
          progress: colors.brand,
        );
    }
  }
}
