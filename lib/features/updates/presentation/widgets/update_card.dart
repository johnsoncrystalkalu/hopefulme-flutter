import 'package:flutter/material.dart';
import 'package:hopefulme_flutter/app/theme/app_theme.dart';
import 'package:hopefulme_flutter/core/widgets/app_avatar.dart';
import 'package:hopefulme_flutter/core/widgets/app_network_image.dart';
import 'package:hopefulme_flutter/core/widgets/rich_display_text.dart';
import 'package:hopefulme_flutter/core/widgets/verified_name_text.dart';

class UpdateCardData {
  const UpdateCardData({
    required this.title,
    required this.subtitle,
    this.metaLeading = '',
    this.metaTrailing = '',
    required this.body,
    required this.photoUrl,
    required this.avatarUrl,
    required this.fallbackLabel,
    this.isVerified = false,
  });

  final String title;
  final String subtitle;
  final String metaLeading;
  final String metaTrailing;
  final String body;
  final String photoUrl;
  final String avatarUrl;
  final String fallbackLabel;
  final bool isVerified;
}

class ReusableUpdateCard extends StatelessWidget {
  const ReusableUpdateCard({
    required this.data,
    this.onHeaderTap,
    this.onCardTap,
    this.onImageTap,
    this.onMentionTap,
    this.onHashtagTap,
    this.headerTrailing,
    this.footer,
    super.key,
  });

  final UpdateCardData data;
  final VoidCallback? onHeaderTap;
  final VoidCallback? onCardTap;
  final VoidCallback? onImageTap;
  final Future<void> Function(String username)? onMentionTap;
  final Future<void> Function(String hashtag)? onHashtagTap;
  final Widget? headerTrailing;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final String imageUrl = data.photoUrl;

    final header = Row(
      children: [
        _CardAvatar(
          imageUrl: data.avatarUrl,
          label: data.fallbackLabel,
          radius: 22,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              VerifiedNameText(
                name: data.title,
                verified: data.isVerified,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              if (data.metaLeading.isNotEmpty || data.metaTrailing.isNotEmpty)
                Row(
                  children: [
                    if (data.metaLeading.isNotEmpty)
                      Flexible(
                        child: Text(
                          data.metaLeading,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    if (data.metaLeading.isNotEmpty &&
                        data.metaTrailing.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: colors.textMuted,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    if (data.metaTrailing.isNotEmpty)
                      Flexible(
                        child: Text(
                          data.metaTrailing,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                )
              else
                Text(
                  data.subtitle,
                  style: TextStyle(
                    color: colors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
        if (headerTrailing != null) ...[headerTrailing!],
      ],
    );

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: colors.borderStrong),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: 0.035),
            blurRadius: 14,
            offset: const Offset(0, 4),
            spreadRadius: -6,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
            child: onHeaderTap == null
                ? header
                : InkWell(
                    onTap: onHeaderTap,
                    borderRadius: BorderRadius.circular(16),
                    child: header,
                  ),
          ),
          if (data.body.isNotEmpty || data.photoUrl.isNotEmpty)
            InkWell(
              onTap: onCardTap,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (data.body.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
                      child: RichDisplayText(
                        text: data.body,
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 14,
                          height: 1.55,
                        ),
                        onMentionTap: onMentionTap,
                        onHashtagTap: onHashtagTap,
                      ),
                    ),
                  if (data.photoUrl.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    InkWell(
                      onTap: onImageTap,
                      child: ClipRRect(
                        child: SizedBox(
                          width: double.infinity,
                          child: AppNetworkImage(
                            imageUrl: imageUrl,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            backgroundColor: colors.surfaceMuted,
                            placeholderLabel: data.fallbackLabel,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          if (footer != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: colors.border)),
              ),
              child: footer,
            ),
          ] else
            const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _CardAvatar extends StatelessWidget {
  const _CardAvatar({
    required this.imageUrl,
    required this.label,
    required this.radius,
  });

  final String imageUrl;
  final String label;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final parts = label
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty);
    final initials = parts.take(2).map((part) => part[0].toUpperCase()).join();

    return AppAvatar(
      imageUrl: imageUrl,
      label: initials.isEmpty ? label : initials,
      radius: radius,
      backgroundColor: colors.avatarPlaceholder,
    );
  }
}
