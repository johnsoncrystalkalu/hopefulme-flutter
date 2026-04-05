import 'package:flutter/material.dart';
import 'package:hopefulme_flutter/app/theme/app_theme.dart';
import 'package:hopefulme_flutter/core/network/image_url_resolver.dart';
import 'package:hopefulme_flutter/core/widgets/app_screen_app_bar.dart';
import 'package:hopefulme_flutter/core/widgets/app_status_state.dart';
import 'package:hopefulme_flutter/core/widgets/verified_name_text.dart';
import 'package:hopefulme_flutter/features/feed/data/feed_repository.dart';
import 'package:hopefulme_flutter/features/feed/models/feed_dashboard.dart';

class CommunityLeaderboardScreen extends StatefulWidget {
  const CommunityLeaderboardScreen({
    required this.feedRepository,
    required this.onOpenProfile,
    super.key,
  });

  final FeedRepository feedRepository;
  final Future<void> Function(String username) onOpenProfile;

  @override
  State<CommunityLeaderboardScreen> createState() =>
      _CommunityLeaderboardScreenState();
}

class _CommunityLeaderboardScreenState
    extends State<CommunityLeaderboardScreen> {
  late Future<CommunityLeaderboard> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.feedRepository.fetchCommunityLeaderboard();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = widget.feedRepository.fetchCommunityLeaderboard();
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Scaffold(
      backgroundColor: colors.scaffold,
      appBar: buildAppScreenAppBar(
        context,
        title: 'Leaderboard',
        subtitle: 'COMMUNITY',
      ),
      body: FutureBuilder<CommunityLeaderboard>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return AppStatusState.fromError(
              error: snapshot.error.toString(),
              actionLabel: 'Try again',
              onAction: _refresh,
            );
          }

          final data = snapshot.data!;
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
              children: [
                Text(
                  'Community Rankings',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Recognizing our most active members on the website and app.',
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                _LeaderboardPanel(
                  title: 'Most active in ${_monthName(DateTime.now().month)}',
                  users: data.monthlyTop,
                  valueBuilder: (user) => user.monthlyActivity.toStringAsFixed(
                    user.monthlyActivity.truncateToDouble() ==
                            user.monthlyActivity
                        ? 0
                        : 1,
                  ),
                  valueLabel: 'Monthly Pts',
                  onOpenProfile: widget.onOpenProfile,
                ),
                const SizedBox(height: 18),
                _LeaderboardPanel(
                  title: 'All-Time Most Active',
                  users: data.allTimeTop,
                  valueBuilder: (user) => user.loginActivity.toStringAsFixed(
                    user.loginActivity.truncateToDouble() == user.loginActivity
                        ? 0
                        : 1,
                  ),
                  valueLabel: 'Total Pts',
                  onOpenProfile: widget.onOpenProfile,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

String _monthName(int month) {
  const months = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  final safeMonth = month < 1 ? 1 : (month > 12 ? 12 : month);
  return months[safeMonth - 1];
}

class _LeaderboardPanel extends StatelessWidget {
  const _LeaderboardPanel({
    required this.title,
    required this.users,
    required this.valueBuilder,
    required this.valueLabel,
    required this.onOpenProfile,
  });

  final String title;
  final List<FeedUser> users;
  final String Function(FeedUser user) valueBuilder;
  final String valueLabel;
  final Future<void> Function(String username) onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: colors.borderStrong),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (users.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'No activity yet.',
                style: TextStyle(color: colors.textMuted),
              ),
            )
          else
            ...users.asMap().entries.map((entry) {
              final index = entry.key;
              final user = entry.value;
              return InkWell(
                onTap: () => onOpenProfile(user.username),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 30,
                        child: Text(
                          '#${index + 1}',
                          style: TextStyle(
                            color: colors.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
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
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            VerifiedNameText(
                              name: user.displayName,
                              verified: user.isVerified,
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '@${user.username}',
                              style: TextStyle(
                                color: colors.textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            valueBuilder(user),
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            valueLabel,
                            style: TextStyle(
                              color: colors.textMuted,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
