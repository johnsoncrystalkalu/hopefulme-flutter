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
        // ── Loading ──────────────────────────────────────────────────────────
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: colors.border),
            ),
            child: Center(
              child: CircularProgressIndicator(
                color: colors.brand,
                strokeWidth: 2,
              ),
            ),
          );
        }

        // ── Error ────────────────────────────────────────────────────────────
        if (snapshot.hasError) {
          return AppStatusState.fromError(
            error: snapshot.error.toString(),
            actionLabel: 'Try again',
            onAction: _refresh,
          );
        }

        final users = snapshot.data ?? const <FeedUser>[];
        if (users.isEmpty) return const SizedBox.shrink();

        // ── Content ──────────────────────────────────────────────────────────
        return Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Header strip ───────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: colors.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Most active this month',
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: _openFullList,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: colors.accentSoft,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'See all',
                          style: TextStyle(
                            color: colors.brand,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Divider(height: 1, thickness: 0.5, color: colors.border),

              // ── User row ───────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 14, 8, 14),
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
                            // ── Avatar ──────────────────────────────────────
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: colors.brand.withValues(alpha: 0.30),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: CircleAvatar(
                                    radius: 22,
                                    backgroundColor: colors.avatarPlaceholder,
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
                                            Icons.person_outline_rounded,
                                            size: 18,
                                            color: colors.brand,
                                          )
                                        : null,
                                  ),
                                ),
                                // Online dot
                                if (user.isOnline)
                                  Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color: colors.success,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: colors.surface,
                                          width: 1.5,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),

                            const SizedBox(height: 8),

                            // ── First name ──────────────────────────────────
                            Text(
                              user.displayName.split(' ').first,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                height: 1.2,
                              ),
                            ),

                            const SizedBox(height: 2),

                            // ── Location / username ─────────────────────────
                            Text(
                              user.city.trim().isNotEmpty
                                  ? user.city.trim()
                                  : user.state.trim().isNotEmpty
                                      ? user.state.trim()
                                      : '@${user.username}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: colors.textMuted,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                height: 1.2,
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