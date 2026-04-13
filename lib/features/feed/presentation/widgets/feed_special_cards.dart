import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:hopefulme_flutter/app/theme/app_theme.dart';
import 'package:hopefulme_flutter/core/widgets/app_network_image.dart';
import 'package:hopefulme_flutter/core/widgets/rich_display_text.dart';
import 'package:hopefulme_flutter/features/feed/models/feed_dashboard.dart';

class FeedNoticeCard extends StatelessWidget {
  const FeedNoticeCard({
    required this.notice,
    required this.onOpenLink,
    super.key,
  });

  final FeedNotice notice;
  final Future<void> Function(String url) onOpenLink;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final hasImage = notice.imageUrl.trim().isNotEmpty;
    final hasText =
        notice.title.trim().isNotEmpty || notice.message.trim().isNotEmpty;
    final hasCta =
        notice.ctaUrl.trim().isNotEmpty && notice.ctaText.trim().isNotEmpty;

    if (hasImage) {
      final banner = ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: AspectRatio(
          aspectRatio: 16 / 6.2,
          child: Stack(
            fit: StackFit.expand,
            children: [
              AppNetworkImage(
                imageUrl: notice.imageUrl,
                fit: BoxFit.cover,
                placeholderLabel:
                    notice.title.isEmpty ? 'Feed notice' : notice.title,
              ),
              if (hasText)
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.04),
                        Colors.black.withValues(alpha: 0.34),
                      ],
                    ),
                  ),
                ),
              if (hasText)
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (notice.title.trim().isNotEmpty)
                        Text(
                          notice.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      if (notice.message.trim().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          notice.message,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.92),
                            fontSize: 12.8,
                            height: 1.35,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      );

      return hasCta
          ? InkWell(
              onTap: () => onOpenLink(notice.ctaUrl),
              borderRadius: BorderRadius.circular(20),
              child: banner,
            )
          : banner;
    }

    if (!hasText) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (notice.title.trim().isNotEmpty)
            Text(
              notice.title,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          if (notice.message.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              notice.message,
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 13,
                height: 1.45,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class FeedAdvertCard extends StatelessWidget {
  const FeedAdvertCard({required this.entry, super.key});

  final FeedEntry entry;

  Future<void> _openLink() async {
    final url = entry.linkUrl.trim();
    if (url.isEmpty) {
      return;
    }
    final normalized = url.startsWith('http://') || url.startsWith('https://')
        ? url
        : 'https://$url';
    final uri = Uri.tryParse(normalized);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.platformDefault);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return InkWell(
      onTap: entry.linkUrl.trim().isEmpty ? null : _openLink,
      borderRadius: BorderRadius.circular(26),
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: colors.borderStrong),
          boxShadow: [
            BoxShadow(
              color: colors.shadow.withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, 8),
              spreadRadius: -10,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (entry.photoUrl.isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                child: AspectRatio(
                  aspectRatio: 16 / 10,
                  child: AppNetworkImage(
                    imageUrl: entry.photoUrl,
                    fit: BoxFit.cover,
                    placeholderLabel: entry.title,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF1CC),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Sponsored',
                          style: TextStyle(
                            color: Color(0xFFB45309),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Visit page',
                        style: TextStyle(
                          color: colors.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    entry.title,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (entry.body.trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    RichDisplayText(
                      text: entry.body,
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textMuted,
                        fontSize: 14,
                        height: 1.6,
                      ),
                    ),
                  ],
                  // if (entry.linkUrl.trim().isNotEmpty) ...[
                  //   const SizedBox(height: 14),
                  //   Row(
                  //     mainAxisSize: MainAxisSize.min,
                  //     children: [
                  //       Text(
                  //         'View post',
                  //         style: TextStyle(
                  //           color: colors.brand,
                  //           fontSize: 14,
                  //           fontWeight: FontWeight.w700,
                  //         ),
                  //       ),
                  //       const SizedBox(width: 6),
                  //       Icon(
                  //         Icons.open_in_new_rounded,
                  //         size: 16,
                  //         color: colors.brand,
                  //       ),
                  //     ],
                  //   ),
                  //],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
