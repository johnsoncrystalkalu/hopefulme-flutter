import 'package:flutter/material.dart';
import 'package:hopefulme_flutter/app/theme/app_theme.dart';
import 'package:hopefulme_flutter/core/network/image_url_resolver.dart';
import 'package:hopefulme_flutter/core/widgets/app_status_state.dart';
import 'package:hopefulme_flutter/features/community/presentation/screens/community_leaderboard_screen.dart';
import 'package:hopefulme_flutter/features/feed/data/feed_repository.dart';
import 'package:hopefulme_flutter/features/feed/models/feed_dashboard.dart';

class MostActiveUsersCard extends StatefulWidget {
  const MostActiveUsersCard({
    required this.feedRepository,
    required this.onOpenProfile,
    this.limit = 4,
    super.key,
  });

  final FeedRepository feedRepository;
  final Future<void> Function(String username) onOpenProfile;
  final int limit;

  @override
  State<MostActiveUsersCard> createState() => _MostActiveUsersCardState();
}

class _MostActiveUsersCardState extends State<MostActiveUsersCard> {
  late Future<List<FeedUser>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.feedRepository.fetchMostActiveUsers(limit: widget.limit);
  }

  Future<void> _refresh() async {
    setState(() {
      _future = widget.feedRepository.fetchMostActiveUsers(limit: widget.limit);
    });
    await _future;
  }

  Future<void> _openFullList() {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => CommunityLeaderboardScreen(
          feedRepository: widget.feedRepository,
          onOpenProfile: widget.onOpenProfile,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return FutureBuilder<List<FeedUser>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: colors.borderStrong),
            ),
            child: const Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return AppStatusState.fromError(
            error: snapshot.error.toString(),
            actionLabel: 'Try again',
            onAction: _refresh,
          );
        }

        final users = snapshot.data ?? const <FeedUser>[];
        if (users.isEmpty) return const SizedBox.shrink();

        return Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: colors.borderStrong),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Header ──────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 5, 8, 5),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'MOST ACTIVE THIS MONTH',
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _openFullList,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        backgroundColor:
                            colors.brand.withValues(alpha: 0.08),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: Text(
                        'Full List',
                        style: TextStyle(
                          color: colors.brand,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Divider(height: 1, color: colors.border),

              // ── User Grid ────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: List.generate(users.length, (index) {
                    final user = users[index];
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => widget.onOpenProfile(user.username),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // ── Avatar + online dot ──────────────
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: colors.brand
                                          .withValues(alpha: 0.25),
                                      width: 2,
                                    ),
                                  ),
                                  child: CircleAvatar(
                                    radius: 24,
                                    backgroundColor:
                                        colors.brand.withValues(alpha: 0.08),
                                    backgroundImage: user.photoUrl.isNotEmpty
                                        ? NetworkImage(
                                            ImageUrlResolver.thumbnail(
                                              user.photoUrl,
                                              size: 80,
                                            ),
                                          )
                                        : null,
                                    child: user.photoUrl.isEmpty
                                        ? Icon(
                                            Icons.person_outline,
                                            size: 20,
                                            color: colors.brand,
                                          )
                                        : null,
                                  ),
                                ),
                                if (user.isOnline)
                                  Positioned(
                                    right: 1,
                                    bottom: 1,
                                    child: Container(
                                      width: 11,
                                      height: 11,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF22C55E),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: colors.surface,
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),

                            const SizedBox(height: 6),

                            // ── Name ─────────────────────────────
                            Text(
                              user.displayName.split(' ').first,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                height: 1.1,
                              ),
                            ),

                            const SizedBox(height: 2),

                            // ── Location / username ───────────────
                            Text(
                              user.city.trim().isNotEmpty
                                  ? user.city.trim()
                                  : (user.state.trim().isNotEmpty
                                      ? user.state.trim()
                                      : '@${user.username}'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: colors.textMuted,
                                fontSize: 8,
                                fontWeight: FontWeight.w600,
                                height: 1.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}