import 'package:flutter/material.dart';
import 'package:hopefulme_flutter/app/theme/app_theme.dart';
import 'package:hopefulme_flutter/core/utils/time_formatter.dart';
import 'package:hopefulme_flutter/core/widgets/app_avatar.dart';
import 'package:hopefulme_flutter/core/widgets/app_status_state.dart';
import 'package:hopefulme_flutter/core/widgets/verified_name_text.dart';
import 'package:hopefulme_flutter/features/content/data/content_repository.dart';
import 'package:hopefulme_flutter/features/content/models/content_detail.dart';

class InspirationDetailScreen extends StatefulWidget {
  const InspirationDetailScreen({
    required this.inspirationId,
    required this.repository,
    super.key,
  });

  final int inspirationId;
  final ContentRepository repository;

  @override
  State<InspirationDetailScreen> createState() =>
      _InspirationDetailScreenState();
}

class _InspirationDetailScreenState extends State<InspirationDetailScreen> {
  late Future<InspirationDetail> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.fetchInspiration(widget.inspirationId);
  }

  Future<void> _refresh() async {
    setState(() {
      _future = widget.repository.fetchInspiration(widget.inspirationId);
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Scaffold(
      backgroundColor: colors.scaffold,
      body: SafeArea(
        child: FutureBuilder<InspirationDetail>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError && !snapshot.hasData) {
              return AppStatusState.fromError(
                error: snapshot.error ?? 'Unable to load this inspiration.',
                actionLabel: 'Try again',
                onAction: _refresh,
              );
            }
            final detail = snapshot.data;
            if (detail == null) {
              return const Center(child: Text('Unable to load inspiration.'));
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
              children: [
                InkWell(
                  onTap: () => Navigator.of(context).maybePop(),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 6,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.arrow_back_rounded,
                          size: 18,
                          color: colors.textMuted,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Back to inbox',
                          style: TextStyle(
                            color: colors.textMuted,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: colors.brand.withValues(alpha: 0.22),
                        blurRadius: 36,
                        offset: const Offset(0, 18),
                        spreadRadius: -16,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _InspirationHero(detail: detail),
                        Transform.translate(
                          offset: const Offset(0, -6),
                          child: Container(
                            decoration: BoxDecoration(
                              color: colors.surface,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(28),
                              ),
                              border: Border.all(color: colors.border),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _SenderRow(detail: detail),
                                  const SizedBox(height: 22),
                                  _MessageCard(detail: detail),
                                  const SizedBox(height: 20),
                                  _ToFromRow(detail: detail),
                                  const SizedBox(height: 22),
                                  const _ActionRow(),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _InspirationHero extends StatelessWidget {
  const _InspirationHero({required this.detail});

  final InspirationDetail detail;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 30, 24, 40),
      decoration: BoxDecoration(gradient: colors.brandGradient),
      child: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.06,
              child: CustomPaint(painter: _DotPatternPainter()),
            ),
          ),
          Positioned.fill(
            child: Center(
              child: Container(
                width: 236,
                height: 236,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF7C3AED).withValues(alpha: 0.28),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Align(
                alignment: Alignment.center,
                child: Container(
                  width: 66,
                  height: 66,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.18),
                    ),
                  ),
                  child: const Icon(
                    Icons.favorite_rounded,
                    color: Colors.white,
                    size: 34,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Align(
                alignment: Alignment.center,
                child: Text(
                  'A Gift of Hope',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.center,
                child: Text(
                  'Someone took a moment for you',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.58),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SenderRow extends StatelessWidget {
  const _SenderRow({required this.detail});

  final InspirationDetail detail;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final sender = detail.sender;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppAvatar(
              imageUrl: sender?.photoUrl ?? '',
              label: detail.senderName,
              radius: 24,
              backgroundColor: colors.avatarPlaceholder,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  VerifiedNameText(
                    name: detail.senderName,
                    verified: sender?.isVerified ?? false,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatDetailedTimestamp(detail.createdAt),
                    style: TextStyle(
                      color: colors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (detail.isAnonymous || detail.isPublic) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (detail.isAnonymous)
                const _InspirationBadge(label: 'Anonymous'),
              if (detail.isPublic)
                const _InspirationBadge(
                  label: 'Public',
                  background: Color(0xFFECFDF3),
                  foreground: Color(0xFF16A34A),
                  border: Color(0xFFD1FADF),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.detail});

  final InspirationDetail detail;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          top: -30,
          left: -4,
          child: Text(
            '"',
            style: TextStyle(
              color: colors.brand.withValues(alpha: 0.08),
              fontSize: 88,
              height: 1,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(18, 22, 18, 22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? colors.borderStrong : const Color(0xFFE0E8FF),
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [const Color(0xFF111827), const Color(0xFF0F172A)]
                  : [const Color(0xFFF0F4FF), const Color(0xFFF5F0FF)],
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.18)
                    : const Color(0xFF3D5AFE).withValues(alpha: 0.06),
                blurRadius: 24,
                offset: const Offset(0, 10),
                spreadRadius: -18,
              ),
            ],
          ),
          child: Text(
            detail.message,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 17,
              height: 1.8,
              fontWeight: FontWeight.w500,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }
}

class _ToFromRow extends StatelessWidget {
  const _ToFromRow({required this.detail});

  final InspirationDetail detail;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final receiver = detail.receiver;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          if (receiver != null) ...[
            AppAvatar(
              imageUrl: receiver.photoUrl,
              label: receiver.displayName,
              radius: 16,
              backgroundColor: colors.avatarPlaceholder,
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  color: colors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                children: [
                  const TextSpan(text: 'To '),
                  TextSpan(
                    text: receiver?.displayName ?? 'you',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'from ${detail.senderName}',
            style: TextStyle(
              color: colors.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => Navigator.of(context).maybePop(),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              side: BorderSide(color: colors.brand, width: 1.6),
            ),
            icon: Icon(Icons.arrow_back_rounded, color: colors.brand),
            label: Text(
              'Back to inbox',
              style: TextStyle(
                color: colors.brand,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: colors.surfaceMuted,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.border),
          ),
          child: IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: Icon(Icons.chevron_left_rounded, color: colors.textMuted),
            tooltip: 'Back',
          ),
        ),
      ],
    );
  }
}

class _InspirationBadge extends StatelessWidget {
  const _InspirationBadge({
    required this.label,
    this.background = const Color(0xFFF8FAFC),
    this.foreground = const Color(0xFF64748B),
    this.border = const Color(0xFFE2E8F0),
  });

  final String label;
  final Color background;
  final Color foreground;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _DotPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const spacing = 20.0;
    final paint = Paint()..color = Colors.white;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.0, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
