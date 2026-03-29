import 'package:flutter/material.dart';
import 'package:hopefulme_flutter/app/theme/app_theme.dart';

class AppSendActionButton extends StatelessWidget {
  const AppSendActionButton({
    required this.onPressed,
    this.isBusy = false,
    this.icon = Icons.send_rounded,
    this.size = 52,
    super.key,
  });

  final VoidCallback? onPressed;
  final bool isBusy;
  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final enabled = onPressed != null && !isBusy;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: enabled ? 1 : 0.72,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: enabled
              ? colors.brandGradient
              : LinearGradient(
                  colors: [
                    colors.textMuted.withOpacity(0.32),
                    colors.textMuted.withOpacity(0.22),
                  ],
                ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: colors.brand.withOpacity(0.18),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                    spreadRadius: -8,
                  ),
                ]
              : const <BoxShadow>[],
        ),
        child: SizedBox(
          width: size,
          height: size,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: enabled ? onPressed : null,
              child: Center(
                child: isBusy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(icon, color: Colors.white, size: 22),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
