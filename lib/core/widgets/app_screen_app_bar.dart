import 'package:flutter/material.dart';
import 'package:hopefulme_flutter/app/theme/app_theme.dart';

PreferredSizeWidget buildAppScreenAppBar(
  BuildContext context, {
  required String title,
  String? subtitle,
  List<Widget>? actions,
}) {
  final colors = context.appColors;

  return AppBar(
    backgroundColor: colors.scaffold,
    surfaceTintColor: colors.scaffold,
    scrolledUnderElevation: 0,
    elevation: 0,
    leadingWidth: 46,
    titleSpacing: 4,
    title: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (subtitle != null && subtitle.trim().isNotEmpty)
          Text(
            subtitle,
            style: TextStyle(
              color: colors.textMuted,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
            ),
          ),
        Text(
          title,
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            height: subtitle == null ? 1.0 : 1.08,
          ),
        ),
      ],
    ),
    actions: actions,
    bottom: PreferredSize(
      preferredSize: const Size.fromHeight(1),
      child: Divider(height: 1, thickness: 1, color: colors.border),
    ),
  );
}
