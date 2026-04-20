import 'package:flutter/material.dart';
import 'package:hopefulme_flutter/app/theme/app_theme.dart';
import 'package:hopefulme_flutter/core/utils/app_error_text.dart';

class AppStatusState extends StatelessWidget {
  const AppStatusState({
    required this.title,
    required this.message,
    this.icon,
    this.actionLabel,
    this.onAction,
    this.isOffline = false,
    this.isTimeout = false,
    super.key,
  });

  AppStatusState.fromError({
    required Object error,
    this.actionLabel,
    this.onAction,
    super.key,
  }) : title = AppErrorText.title(error),
       message = AppErrorText.message(error),
       isOffline = AppErrorText.isOffline(error),
       isTimeout = AppErrorText.isTimeout(error),
       icon = AppErrorText.isOffline(error)
           ? Icons.cloud_off_rounded
           : AppErrorText.isTimeout(error)
           ? Icons.hourglass_bottom_rounded
           : Icons.error_outline_rounded;

  final String title;
  final String message;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool isOffline;
  final bool isTimeout;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final accentColor = isOffline
        ? const Color(0xFF2563EB)
        : isTimeout
        ? const Color(0xFFF59E0B)
        : colors.brand;
    final accentSurface = isOffline
        ? const Color(0xFFEAF2FF)
        : isTimeout
        ? const Color(0xFFFFF4DB)
        : colors.accentSoft;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: colors.borderStrong),
              boxShadow: [
                BoxShadow(
                  color: colors.shadow.withValues(alpha: 0.10),
                  blurRadius: 24,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        accentSurface,
                        accentSurface.withValues(alpha: 0.82),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withValues(alpha: 0.14),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Icon(
                    icon ?? Icons.info_outline_rounded,
                    color: accentColor,
                    size: 34,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.textMuted,
                    fontSize: 14,
                    height: 1.6,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (isOffline) ...[
                 //const SizedBox(height: 16),
                  // Container(
                  //   width: double.infinity,
                  //   padding: const EdgeInsets.all(14),
                  //   decoration: BoxDecoration(
                  //     color: accentSurface.withValues(alpha: 0.7),
                  //     borderRadius: BorderRadius.circular(18),
                  //     border: Border.all(
                  //       color: accentColor.withValues(alpha: 0.14),
                  //     ),
                  //   ),
                  //   child: const SizedBox.shrink(),
                  // ),
                ],
                if (onAction != null && actionLabel != null) ...[
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: onAction,
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(actionLabel!),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
