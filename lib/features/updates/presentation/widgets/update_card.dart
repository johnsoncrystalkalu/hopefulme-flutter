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
    this.isGeneratedActivity = false,
    this.activityBadgeLabel = '',
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
  final bool isGeneratedActivity;
  final String activityBadgeLabel;
}

class ReusableUpdateCard extends StatelessWidget {
  const ReusableUpdateCard({
    required this.data,
    this.onHeaderTap,
    this.onCardTap,
    this.onImageTap,
    this.onMentionTap,
    this.onHashtagTap,
    this.onLinkTap,
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
  final Future<void> Function(String url)? onLinkTap;
  final Widget? headerTrailing;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final String imageUrl = data.photoUrl;
    final bodyColor = data.isGeneratedActivity
        ? colors.textMuted.withValues(alpha: 0.82)
        : colors.textSecondary;
    final actionColor = data.isGeneratedActivity
        ? colors.textMuted.withValues(alpha: 0.9)
        : colors.brand;

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
            color: colors.shadow.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
            spreadRadius: -10,
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
                      child: _ExpandableUpdateBody(
                        text: data.body,
                        style: TextStyle(
                          color: bodyColor,
                          fontSize: data.isGeneratedActivity ? 13.25 : 14,
                          height: 1.55,
                          fontWeight: data.isGeneratedActivity
                              ? FontWeight.w400
                              : FontWeight.w500,
                        ),
                        onMentionTap: onMentionTap,
                        onHashtagTap: onHashtagTap,
                        onLinkTap: onLinkTap,
                        actionColor: actionColor,
                      ),
                    ),
                  if (data.photoUrl.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    InkWell(
                      onTap: onImageTap ?? onCardTap,
                      child: ClipRRect(
                        child: SizedBox(
                          width: double.infinity,
                          child: AppNetworkImage(
                            imageUrl: imageUrl,
                            width: double.infinity,
                            fit: BoxFit.cover, //check here
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

class _ExpandableUpdateBody extends StatefulWidget {
  const _ExpandableUpdateBody({
    required this.text,
    required this.style,
    required this.actionColor,
    this.onMentionTap,
    this.onHashtagTap,
    this.onLinkTap,
  });

  final String text;
  final TextStyle style;
  final Color actionColor;
  final Future<void> Function(String username)? onMentionTap;
  final Future<void> Function(String hashtag)? onHashtagTap;
  final Future<void> Function(String url)? onLinkTap;

  @override
  State<_ExpandableUpdateBody> createState() => _ExpandableUpdateBodyState();
}

class _ExpandableUpdateBodyState extends State<_ExpandableUpdateBody> {
  static const int _wordLimit = 60;
  bool _expanded = false;

  @override
  void didUpdateWidget(covariant _ExpandableUpdateBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _expanded = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final words = widget.text.trim().split(RegExp(r'\s+'));
    final hasOverflow = words.length > _wordLimit;
    final collapsedText = hasOverflow
        ? '${words.take(_wordLimit).join(' ')}...'
        : widget.text;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichDisplayText(
          text: _expanded ? widget.text : collapsedText,
          style: widget.style,
          onMentionTap: widget.onMentionTap,
          onHashtagTap: widget.onHashtagTap,
          onLinkTap: widget.onLinkTap,
        ),
        if (hasOverflow)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: InkWell(
              onTap: () {
                setState(() {
                  _expanded = !_expanded;
                });
              },
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                child: Text(
                  _expanded ? 'Show less' : 'Read more',
                  style: TextStyle(
                    color: widget.actionColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
      ],
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
