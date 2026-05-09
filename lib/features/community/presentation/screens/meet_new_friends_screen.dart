import 'package:flutter/material.dart';
import 'package:hopefulme_flutter/app/theme/app_theme.dart';
import 'package:hopefulme_flutter/core/network/image_url_resolver.dart';
import 'package:hopefulme_flutter/core/widgets/app_status_state.dart';
import 'package:hopefulme_flutter/core/widgets/major_bottom_nav.dart';
import 'package:hopefulme_flutter/core/widgets/verified_name_text.dart';
import 'package:hopefulme_flutter/features/auth/models/user.dart';
import 'package:hopefulme_flutter/features/community/presentation/widgets/most_active_users_card.dart';
import 'package:hopefulme_flutter/features/feed/data/feed_repository.dart';
import 'package:hopefulme_flutter/features/feed/models/feed_dashboard.dart';
import 'package:hopefulme_flutter/features/messages/data/message_repository.dart';
import 'package:hopefulme_flutter/features/messages/presentation/screens/message_thread_screen.dart';
import 'package:hopefulme_flutter/features/profile/data/profile_repository.dart';
import 'package:hopefulme_flutter/features/profile/presentation/profile_navigation.dart';
import 'package:hopefulme_flutter/features/updates/data/update_repository.dart';

class MeetNewFriendsScreen extends StatefulWidget {
  const MeetNewFriendsScreen({
    required this.feedRepository,
    required this.profileRepository,
    required this.messageRepository,
    required this.updateRepository,
    required this.currentUser,
    this.showMajorBottomNav = false,
    this.bottomNavIndex = 4,
    this.onMajorTabSelected,
    super.key,
  });

  final FeedRepository feedRepository;
  final ProfileRepository profileRepository;
  final MessageRepository messageRepository;
  final UpdateRepository updateRepository;
  final User? currentUser;
  final bool showMajorBottomNav;
  final int bottomNavIndex;
  final Future<void> Function(int index)? onMajorTabSelected;

  @override
  State<MeetNewFriendsScreen> createState() => _MeetNewFriendsScreenState();
}

class _MeetNewFriendsScreenState extends State<MeetNewFriendsScreen> {
  final ScrollController _scrollController = ScrollController();
  final List<FeedUser> _items = <FeedUser>[];
  List<FeedUser> _onlineUsers = const <FeedUser>[];
  List<FeedUser> _newMembers = const <FeedUser>[];
  List<FeedUser> _mentors = const <FeedUser>[];
  List<FeedUser> _todayBirthdays = const <FeedUser>[];
  FeedUser? _friendOfTheDay;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadInitial();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _page = 1;
      _hasMore = true;
      _items.clear();
      _friendOfTheDay = null;
    });

    try {
      final results = await Future.wait<Object>([
        widget.feedRepository.fetchMeetNewFriends(page: 1),
        widget.feedRepository.fetchFriendOfTheDay(),
        widget.feedRepository.fetchTodayBirthdays(page: 1),
      ]);
      final page = results[0] as FeedUserPage;
      final dailyFriendResponse = results[1] as FriendOfTheDayResponse;
      final birthdaysPage = results[2] as FeedUserPage;
      if (!mounted) return;
      setState(() {
        _items.addAll(page.items);
        _onlineUsers = page.onlineUsers;
        _newMembers = page.newMembers;
        _mentors = page.mentors;
        _todayBirthdays = birthdaysPage.items;
        _friendOfTheDay = dailyFriendResponse.friend;
        _hasMore = page.hasMore;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) {
      return;
    }
    setState(() {
      _isLoadingMore = true;
    });
    try {
      final nextPage = _page + 1;
      final page = await widget.feedRepository.fetchMeetNewFriends(
        page: nextPage,
      );
      if (!mounted) return;
      setState(() {
        _page = nextPage;
        _items.addAll(page.items);
        _hasMore = page.hasMore;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 240) {
      _loadMore();
    }
  }

  Future<void> _openProfile(String username) {
    return openUserProfile(
      context,
      profileRepository: widget.profileRepository,
      messageRepository: widget.messageRepository,
      updateRepository: widget.updateRepository,
      currentUser: widget.currentUser,
      username: username,
    );
  }

  Future<void> _openChat(FeedUser user) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => MessageThreadScreen(
          repository: widget.messageRepository,
          profileRepository: widget.profileRepository,
          updateRepository: widget.updateRepository,
          currentUser: widget.currentUser,
          username: user.username,
          title: user.displayName,
        ),
      ),
    );
  }

  Future<void> _openAllMentors() {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => _AllMentorsScreen(
          feedRepository: widget.feedRepository,
          profileRepository: widget.profileRepository,
          messageRepository: widget.messageRepository,
          updateRepository: widget.updateRepository,
          currentUser: widget.currentUser,
          initialMentors: _mentors,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final width = MediaQuery.of(context).size.width;
    final showRail = width >= 1100;
    final featured = _friendOfTheDay;
    final featuredUsername = featured?.username.trim().toLowerCase();
    final suggestedItems = featuredUsername == null
        ? _items
        : _items
              .where(
                (user) =>
                    user.username.trim().toLowerCase() != featuredUsername,
              )
              .toList(growable: false);
    return Scaffold(
      backgroundColor: colors.scaffold,
      bottomNavigationBar: widget.showMajorBottomNav
          ? MajorBottomNav(
              selectedIndex: widget.bottomNavIndex,
              onSelected: (index) async {
                if (index == widget.bottomNavIndex) {
                  return;
                }
                if (widget.onMajorTabSelected != null) {
                  await widget.onMajorTabSelected!(index);
                  return;
                }
                if (!context.mounted) return;
                Navigator.of(context).pop(index);
              },
            )
          : null,
      appBar: AppBar(
        backgroundColor: colors.surface,
        surfaceTintColor: colors.surface,
        title: const Text('Connect'),
        actions: const [],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? AppStatusState.fromError(
              error: _error!,
              actionLabel: 'Try again',
              onAction: _loadInitial,
            )
          : RefreshIndicator(
              onRefresh: _loadInitial,
              child: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                children: [
                  _MeetHeader(newMembers: _newMembers, onTap: _openProfile),
                  const SizedBox(height: 24),
                  Column(
                    children: [
                      if (featured != null) ...[
                        _FriendOfDayCard(
                          user: featured,
                          onProfileTap: () => _openProfile(featured.username),
                          onHelloTap: () => showRail
                              ? _openProfile(featured.username)
                              : _openChat(featured),
                        ),
                        SizedBox(height: showRail ? 22 : 18),
                      ],
                      MostActiveUsersCard(
                        feedRepository: widget.feedRepository,
                        onOpenProfile: _openProfile,
                      ),
                      SizedBox(height: showRail ? 22 : 20),
                      if (_onlineUsers.isNotEmpty) ...[
                        _OnlinePanel(users: _onlineUsers, onTap: _openProfile),
                        SizedBox(height: showRail ? 22 : 18),
                      ],
                      if (_newMembers.isNotEmpty) ...[
                        _NewestHeartsPanel(
                          users: _newMembers,
                          onTap: _openProfile,
                        ),
                        SizedBox(height: showRail ? 22 : 18),
                      ],
                      _MentorshipDiscoveryPanel(
                        mentors: _mentors,
                        onTapProfile: _openProfile,
                        onSeeAllTap: _openAllMentors,
                      ),
                      SizedBox(height: showRail ? 22 : 18),
                      // Temporarily hidden for future redesign:
                      // if (_todayBirthdays.isNotEmpty) ...[
                      //   _BirthdaysPanel(
                      //     users: _todayBirthdays,
                      //     onTap: _openProfile,
                      //   ),
                      //   SizedBox(height: showRail ? 22 : 18),
                      // ],
                      _MeetMainColumn(
                        featured: featured,
                        items: suggestedItems,
                        isLoadingMore: _isLoadingMore,
                        onProfileTap: _openProfile,
                        onHelloTap: (user) => _openProfile(user.username),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}

class _BirthdaysPanel extends StatelessWidget {
  const _BirthdaysPanel({required this.users, required this.onTap});

  final List<FeedUser> users;
  final Future<void> Function(String username) onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final previewUsers = users.take(10).toList(growable: false);
    final leadName = users.first.displayName;
    final othersCount = users.length - 1;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.borderStrong),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('🎈', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Text(
                  "Today's Birthdays",
                  style: TextStyle(
                    color: colors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 48,
              child: Stack(
                children: [
                  for (var index = 0; index < previewUsers.length; index++)
                    Positioned(
                      left: index * 32,
                      child: InkWell(
                        onTap: () => onTap(previewUsers[index].username),
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: colors.surface, width: 4),
                            boxShadow: [
                              BoxShadow(
                                color: colors.shadow.withValues(alpha: 0.04),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                            color: colors.surfaceMuted,
                          ),
                          child: ClipOval(
                            child: CircleAvatar(
                              radius: 22,
                              backgroundImage:
                                  previewUsers[index].photoUrl.isNotEmpty
                                  ? NetworkImage(
                                      ImageUrlResolver.avatar(
                                        previewUsers[index].photoUrl,
                                        size: 66,
                                      ),
                                    )
                                  : null,
                              child: previewUsers[index].photoUrl.isEmpty
                                  ? const Icon(Icons.person, size: 16)
                                  : null,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (users.length >= 5)
                    Positioned(
                      left: previewUsers.length * 32,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: colors.surfaceMuted,
                          shape: BoxShape.circle,
                          border: Border.all(color: colors.surface, width: 4),
                        ),
                        child: Center(
                          child: Text(
                            '+',
                            style: TextStyle(
                              color: colors.textMuted,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            RichText(
              text: TextSpan(
                style: TextStyle(
                  color: colors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
                children: [
                  const TextSpan(text: "It's "),
                  TextSpan(
                    text: leadName,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (othersCount > 0)
                    TextSpan(text: ' and $othersCount others'),
                  const TextSpan(text: "' birthday! 🎉"),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MeetMainColumn extends StatelessWidget {
  const _MeetMainColumn({
    required this.featured,
    required this.items,
    required this.isLoadingMore,
    required this.onProfileTap,
    required this.onHelloTap,
  });

  final FeedUser? featured;
  final List<FeedUser> items;
  final bool isLoadingMore;
  final Future<void> Function(String username) onProfileTap;
  final Future<void> Function(FeedUser user) onHelloTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final width = MediaQuery.of(context).size.width;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'SUGGESTED FOR YOU',
              style: TextStyle(
                color: colors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 2.4,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Divider(color: colors.border, thickness: 1, height: 1),
            ),
          ],
        ),
        const SizedBox(height: 18),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: width >= 760 ? 3 : 2,
            childAspectRatio: 0.78,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
          ),
          itemBuilder: (context, index) {
            final user = items[index];
            return _FriendSuggestionCard(
              user: user,
              onProfileTap: () => onProfileTap(user.username),
              onHelloTap: () => onHelloTap(user),
            );
          },
        ),
        if (isLoadingMore)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }
}

class _MeetHeader extends StatelessWidget {
  const _MeetHeader({required this.newMembers, required this.onTap});

  final List<FeedUser> newMembers;
  final Future<void> Function(String username) onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Text(
      // 'Expand your circle and find people who inspire you.',
      'A safe space to connect, grow, and find people who inspire you.',
      style: TextStyle(
        color: colors.textSecondary,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _FriendOfDayCard extends StatelessWidget {
  const _FriendOfDayCard({
    required this.user,
    required this.onProfileTap,
    required this.onHelloTap,
  });

  final FeedUser user;
  final VoidCallback onProfileTap;
  final VoidCallback onHelloTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final friendImageUrl = user.mainPhotoUrl.isNotEmpty
        ? user.mainPhotoUrl
        : user.photoUrl;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: colors.borderStrong),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  stops: const [0.0, 0.52, 1.0],
                  colors: isDark
                      ? <Color>[
                          colors.surfaceRaised.withValues(alpha: 0.95),
                          colors.surface.withValues(alpha: 0.97),
                          colors.surfaceMuted.withValues(alpha: 0.93),
                        ]
                      : <Color>[
                          const Color(0xFFD5E6FF),
                          const Color(0xFFF3F8FF),
                          const Color(0xFFFFE8D2),
                        ],
                ),
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
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: colors.brandGradient,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(
                        Icons.auto_awesome,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Friend of the Day',
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'A gentle nudge to connect with someone new today',
                            style: TextStyle(
                              color: colors.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: isDark
                        ? colors.surfaceRaised.withValues(alpha: 0.82)
                        : colors.surfaceMuted,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: colors.border.withValues(alpha: 0.8),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          InkWell(
                            onTap: onProfileTap,
                            borderRadius: BorderRadius.circular(24),
                            child: Container(
                              width: 108,
                              height: 108,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: colors.brand.withValues(alpha: 0.12),
                                    blurRadius: 18,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                                image: friendImageUrl.isNotEmpty
                                    ? DecorationImage(
                                        image: NetworkImage(friendImageUrl),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                                color: colors.avatarPlaceholder,
                              ),
                              child: friendImageUrl.isEmpty
                                  ? Icon(
                                      Icons.person,
                                      size: 44,
                                      color: colors.accentSoftText,
                                    )
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                VerifiedNameText(
                                  name: user.displayName,
                                  verified: user.isVerified,
                                  style: TextStyle(
                                    color: colors.textPrimary,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '@${user.username}',
                                  style: TextStyle(
                                    color: colors.textSecondary,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _TagPill(
                                      label: user.isOnline
                                          ? 'ONLINE'
                                          : 'COMMUNITY',
                                      bright: true,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  'Say hello, check in, or send a little encouragement.',
                                  style: TextStyle(
                                    color: colors.textSecondary,
                                    fontSize: 14,
                                    height: 1.45,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton(
                              onPressed: onHelloTap,
                              style: FilledButton.styleFrom(
                                backgroundColor: colors.brand,
                                foregroundColor: Colors.white,
                                minimumSize: const Size.fromHeight(46),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              child: const Text('Send a hello  👋'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          OutlinedButton(
                            onPressed: onProfileTap,
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(126, 46),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            child: const Text('View profile'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FriendSuggestionCard extends StatelessWidget {
  const _FriendSuggestionCard({
    required this.user,
    required this.onProfileTap,
    required this.onHelloTap,
  });

  final FeedUser user;
  final VoidCallback onProfileTap;
  final VoidCallback onHelloTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final suggestionImageUrl = user.mainPhotoUrl.isNotEmpty
        ? user.mainPhotoUrl
        : user.photoUrl;

    return InkWell(
      onTap: onProfileTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              children: [
                Container(
                  width: 92,
                  height: 92,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.surface, width: 3),
                    image: suggestionImageUrl.isNotEmpty
                        ? DecorationImage(
                            image: NetworkImage(suggestionImageUrl),
                            fit: BoxFit.cover,
                          )
                        : null,
                    color: colors.avatarPlaceholder,
                  ),
                  child: suggestionImageUrl.isEmpty
                      ? Icon(
                          Icons.person,
                          size: 34,
                          color: colors.accentSoftText,
                        )
                      : null,
                ),
                if (user.isOnline)
                  Positioned(
                    right: 4,
                    bottom: 4,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: colors.success,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 10),

            VerifiedNameText(
              name: user.displayName,
              verified: user.isVerified,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),

            const SizedBox(height: 4),

            Text(
              user.cityState.isEmpty ? '@${user.username}' : user.cityState,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 10),

            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onHelloTap,
                style: FilledButton.styleFrom(
                  backgroundColor: colors.brand,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(36), // ↓ smaller button
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Connect',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnlinePanel extends StatelessWidget {
  const _OnlinePanel({required this.users, required this.onTap});

  final List<FeedUser> users;
  final Future<void> Function(String username) onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final previewUsers = users.take(10).toList(growable: false);
    final remaining = users.length - previewUsers.length;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          // ── Header ──────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: colors.success,
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Text(
                    'Recently active in your space',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Divider(height: 1, thickness: 0.5, color: colors.border),

          // ── Two-column grid ─────────────────────────────────────────────────
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: previewUsers.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 2.8,
            ),
            itemBuilder: (context, index) {
              final user = previewUsers[index];
              final isRightColumn = index.isOdd;
              final isLastRow =
                  index >=
                  previewUsers.length - (previewUsers.length.isOdd ? 1 : 2);

              return GestureDetector(
                onTap: () => onTap(user.username),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(
                      right: isRightColumn
                          ? BorderSide.none
                          : BorderSide(color: colors.border, width: 0.5),
                      bottom: isLastRow
                          ? BorderSide.none
                          : BorderSide(color: colors.border, width: 0.5),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      // Avatar + online dot
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 19,
                            backgroundColor: colors.avatarPlaceholder,
                            backgroundImage: user.photoUrl.isNotEmpty
                                ? NetworkImage(
                                    ImageUrlResolver.avatar(
                                      user.photoUrl,
                                      size: 56,
                                    ),
                                  )
                                : null,
                            child: user.photoUrl.isEmpty
                                ? Icon(
                                    Icons.person_outline_rounded,
                                    size: 16,
                                    color: colors.brand,
                                  )
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              width: 9,
                              height: 9,
                              decoration: BoxDecoration(
                                color: user.isOnline
                                    ? colors.success
                                    : colors.borderStrong,
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
                      const SizedBox(width: 10),
                      // Name + last seen
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              user.displayName.split(' ').first,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              user.lastSeen.isEmpty
                                  ? 'Active recently'
                                  : user.lastSeen,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colors.textMuted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // ── "View more" footer ──────────────────────────────────────────────
          if (remaining > 0) ...[
            Divider(height: 1, thickness: 0.5, color: colors.border),
            GestureDetector(
              onTap: () => onTap(users.first.username),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'View $remaining more',
                  style: TextStyle(
                    color: colors.brand,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NewestHeartsPanel extends StatelessWidget {
  const _NewestHeartsPanel({required this.users, required this.onTap});

  final List<FeedUser> users;
  final Future<void> Function(String username) onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1120),
        borderRadius: BorderRadius.circular(36),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -18,
            top: -10,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.brand.withValues(alpha: 0.16),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Just Joined',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'MEET NEW MEMBERS',
                style: TextStyle(
                  color: Color.fromRGBO(255, 255, 255, 0.62),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.8,
                ),
              ),
              const SizedBox(height: 18),
              ...users.map(
                (user) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: InkWell(
                    onTap: () => onTap(user.username),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundImage: user.photoUrl.isNotEmpty
                              ? NetworkImage(
                                  ImageUrlResolver.avatar(
                                    user.photoUrl,
                                    size: 56,
                                  ),
                                )
                              : null,
                          child: user.photoUrl.isEmpty
                              ? const Icon(Icons.person, size: 18)
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
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                user.role1.trim().isEmpty
                                    ? 'Member'
                                    : user.role1.trim(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color.fromRGBO(255, 255, 255, 0.7),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.arrow_circle_right_outlined,
                          color: Color(0xFF5B72FF),
                        ),
                      ],
                    ),
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

class _MentorshipDiscoveryPanel extends StatelessWidget {
  const _MentorshipDiscoveryPanel({
    required this.mentors,
    required this.onTapProfile,
    required this.onSeeAllTap,
  });

  final List<FeedUser> mentors;
  final Future<void> Function(String username) onTapProfile;
  final Future<void> Function() onSeeAllTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Mentorship',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: onSeeAllTap,
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
            const SizedBox(height: 4),
            Text(
              'Discover available mentors and connect with them',
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 10),
            _MentorshipUserRow(
              users: mentors,
              emptyLabel: 'No mentors available right now.',
              actionLabel: 'View profile',
              onTapProfile: onTapProfile,
              onAction: (user) => onTapProfile(user.username),
            ),
          ],
        ),
      ),
    );
  }
}

class _MentorshipUserRow extends StatelessWidget {
  const _MentorshipUserRow({
    required this.users,
    required this.emptyLabel,
    required this.actionLabel,
    required this.onTapProfile,
    required this.onAction,
  });

  final List<FeedUser> users;
  final String emptyLabel;
  final String actionLabel;
  final Future<void> Function(String username) onTapProfile;
  final Future<void> Function(FeedUser user) onAction;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (users.isEmpty)
          Text(
            emptyLabel,
            style: TextStyle(color: colors.textMuted, fontSize: 12),
          )
        else
          ...users.take(12).map((user) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.border),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: colors.accentSoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.school_rounded,
                        size: 18,
                        color: colors.accentSoftText,
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => onTapProfile(user.username),
                      child: CircleAvatar(
                        radius: 16,
                        backgroundImage: user.photoUrl.isNotEmpty
                            ? NetworkImage(user.photoUrl)
                            : null,
                        child: user.photoUrl.isEmpty
                            ? const Icon(Icons.person, size: 16)
                            : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: () => onTapProfile(user.username),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            VerifiedNameText(
                              name: user.displayName,
                              verified: user.isVerified,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    user.role1.trim().isEmpty
                                        ? 'Mentor'
                                        : user.role1.trim(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: colors.textMuted,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    FilledButton(
                      onPressed: () => onAction(user),
                      style: FilledButton.styleFrom(
                        backgroundColor: colors.brand,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 7,
                        ),
                        minimumSize: const Size(0, 30),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.person_add_alt_1_rounded, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            actionLabel,
                            style: const TextStyle(fontSize: 10.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}

class _TagPill extends StatelessWidget {
  const _TagPill({required this.label, this.bright = false});

  final String label;
  final bool bright;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: bright ? colors.accentSoft : colors.surfaceRaised,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: bright ? colors.accentSoftText : colors.textMuted,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class _AllMentorsScreen extends StatefulWidget {
  const _AllMentorsScreen({
    required this.feedRepository,
    required this.profileRepository,
    required this.messageRepository,
    required this.updateRepository,
    required this.currentUser,
    required this.initialMentors,
  });

  final FeedRepository feedRepository;
  final ProfileRepository profileRepository;
  final MessageRepository messageRepository;
  final UpdateRepository updateRepository;
  final User? currentUser;
  final List<FeedUser> initialMentors;

  @override
  State<_AllMentorsScreen> createState() => _AllMentorsScreenState();
}

class _AllMentorsScreenState extends State<_AllMentorsScreen> {
  final List<FeedUser> _mentors = <FeedUser>[];
  final Set<int> _mentorIds = <int>{};
  int _page = 1;
  int _lastPage = 1;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _addMentors(widget.initialMentors);
    _loadInitial();
  }

  void _addMentors(List<FeedUser> users) {
    for (final user in users) {
      if (_mentorIds.add(user.id)) {
        _mentors.add(user);
      }
    }
  }

  Future<void> _loadInitial() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final page = await widget.feedRepository.fetchMeetNewFriends(page: 1);
      if (!mounted) return;
      setState(() {
        _page = page.currentPage;
        _lastPage = page.lastPage;
        _addMentors(page.mentors);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || _page >= _lastPage) {
      return;
    }
    setState(() {
      _isLoadingMore = true;
      _error = null;
    });
    try {
      final nextPage = _page + 1;
      final page = await widget.feedRepository.fetchMeetNewFriends(page: nextPage);
      if (!mounted) return;
      setState(() {
        _page = page.currentPage;
        _lastPage = page.lastPage;
        _addMentors(page.mentors);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _openProfile(String username) {
    return openUserProfile(
      context,
      profileRepository: widget.profileRepository,
      messageRepository: widget.messageRepository,
      updateRepository: widget.updateRepository,
      currentUser: widget.currentUser,
      username: username,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Scaffold(
      backgroundColor: colors.scaffold,
      appBar: AppBar(
        title: const Text('All mentors'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 14),
            child: Icon(Icons.school_rounded),
          ),
        ],
        backgroundColor: colors.surface,
        surfaceTintColor: colors.surface,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _mentors.isEmpty
          ? AppStatusState.fromError(
              error: _error!,
              actionLabel: 'Try again',
              onAction: _loadInitial,
            )
          : RefreshIndicator(
              onRefresh: _loadInitial,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                itemCount: _mentors.length + 1,
                separatorBuilder: (_, separatorIndex) =>
                    const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  if (index == _mentors.length) {
                    if (_page >= _lastPage) {
                      return const SizedBox.shrink();
                    }
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: FilledButton(
                          onPressed: _isLoadingMore ? null : _loadMore,
                          child: _isLoadingMore
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Load more'),
                        ),
                      ),
                    );
                  }
                  final user = _mentors[index];
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: colors.border.withValues(alpha: 0.75),
                      ),
                    ),
                    child: Row(
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            InkWell(
                              onTap: () => _openProfile(user.username),
                              child: CircleAvatar(
                                radius: 20,
                                backgroundImage: user.photoUrl.isNotEmpty
                                    ? NetworkImage(user.photoUrl)
                                    : null,
                                child: user.photoUrl.isEmpty
                                    ? const Icon(Icons.person, size: 18)
                                    : null,
                              ),
                            ),
                            Positioned(
                              right: -2,
                              bottom: -2,
                              child: Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: colors.brand,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: colors.surfaceRaised,
                                    width: 1.5,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.school_rounded,
                                  color: Colors.white,
                                  size: 10,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: InkWell(
                            onTap: () => _openProfile(user.username),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                VerifiedNameText(
                                  name: user.displayName,
                                  verified: user.isVerified,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: colors.textPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      user.role1.trim().isEmpty
                                          ? 'Mentor'
                                          : user.role1.trim(),
                                      style: TextStyle(
                                        color: colors.textMuted,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        FilledButton(
                          onPressed: () => _openProfile(user.username),
                          style: FilledButton.styleFrom(
                            backgroundColor: colors.brand,
                            foregroundColor: Colors.white,
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.person_add_alt_1_rounded, size: 14),
                              SizedBox(width: 4),
                              Text('Connect'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }
}


