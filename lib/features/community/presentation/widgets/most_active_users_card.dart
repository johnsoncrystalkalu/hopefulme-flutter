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
        if (users.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: colors.borderStrong),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 0, 12),
                      child: Text(
                        'Most Active users this month',
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.6,
                        ),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _openFullList,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Full List',
                      style: TextStyle(
                        color: colors.brand,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ],
              ),
              Divider(height: 1, color: colors.border),
              Padding(
                padding: const EdgeInsets.all(12),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: users.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: users.length < 4 ? users.length : 4,
                    childAspectRatio: 0.9,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemBuilder: (context, index) {
                    final user = users[index];
                    return InkWell(
                      onTap: () => widget.onOpenProfile(user.username),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: colors.surfaceRaised,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: colors.border),
                        ),
                        child: Column(
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                CircleAvatar(
                                  radius: 22,
                                  backgroundImage: user.photoUrl.isNotEmpty
                                      ? NetworkImage(
                                          ImageUrlResolver.thumbnail(
                                            user.photoUrl,
                                            size: 300,
                                          ),
                                        )
                                      : null,
                                  child: user.photoUrl.isEmpty
                                      ? const Icon(Icons.person_outline)
                                      : null,
                                ),
                                if (user.isOnline)
                                  Positioned(
                                    right: 2,
                                    bottom: 2,
                                    child: Container(
                                      width: 12,
                                      height: 12,
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
                            Text(
                              user.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                height: 1.05,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              user.city.trim().isNotEmpty
                                  ? user.city.trim()
                                  : (user.state.trim().isNotEmpty
                                        ? user.state.trim()
                                        : '@${user.username}'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colors.textMuted,
                                fontSize: 8,
                                fontWeight: FontWeight.w800,
                                height: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
