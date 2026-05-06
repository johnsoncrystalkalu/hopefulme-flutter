import 'package:flutter/material.dart';
import 'package:hopefulme_flutter/app/theme/app_theme.dart';
import 'package:hopefulme_flutter/core/utils/app_error_text.dart';

class AppStatusState extends StatelessWidget {
  static const String _offlineFlyerRoute = '/flyer-templates';

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

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon ?? Icons.info_outline_rounded,
                  color: accentColor,
                  size: 28,
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.textMuted,
                    fontSize: 13,
                    height: 1.45,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                if (isOffline) ...[
                  if (onAction == null || actionLabel == null) ...[
                    const SizedBox(height: 14),
                    _OfflineFlyerChip(
                      accentColor: accentColor,
                    ),
                  ],
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
                  if (isOffline) ...[
                    const SizedBox(height: 10),
                    _OfflineFlyerChip(
                      accentColor: accentColor,
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OfflineFlyerChip extends StatelessWidget {
  const _OfflineFlyerChip({
    required this.accentColor,
  });

  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: TextButton(
        style: TextButton.styleFrom(
          visualDensity: VisualDensity.compact,
          minimumSize: Size.zero,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          foregroundColor: accentColor.withValues(alpha: 0.8),
          textStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        onPressed: () =>
            Navigator.of(context).pushNamed(AppStatusState._offlineFlyerRoute),
        child: const Text('Explore our offline flyer templates'),
      ),
    );
  }
}
