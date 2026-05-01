import 'package:flutter/material.dart';
import 'package:hopefulme_flutter/app/theme/app_theme.dart';
import 'package:hopefulme_flutter/core/network/image_url_resolver.dart';
import 'package:hopefulme_flutter/core/widgets/app_screen_app_bar.dart';
import 'package:hopefulme_flutter/core/widgets/app_status_state.dart';
import 'package:hopefulme_flutter/core/widgets/verified_name_text.dart';
import 'package:hopefulme_flutter/features/auth/models/user.dart';
import 'package:hopefulme_flutter/features/community/presentation/widgets/most_active_users_card.dart';
import 'package:hopefulme_flutter/features/feed/data/feed_repository.dart';
import 'package:hopefulme_flutter/features/feed/models/feed_dashboard.dart';
import 'package:hopefulme_flutter/features/messages/data/message_repository.dart';
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
    super.key,
  });

  final FeedRepository feedRepository;
  final ProfileRepository profileRepository;
  final MessageRepository messageRepository;
  final UpdateRepository updateRepository;
  final User? currentUser;

  @override
  State<MeetNewFriendsScreen> createState() => _MeetNewFriendsScreenState();
}

class _MeetNewFriendsScreenState extends State<MeetNewFriendsScreen> {
  final ScrollController _scrollController = ScrollController();
  final List<FeedUser> _items = <FeedUser>[];
  List<FeedUser> _onlineUsers = const <FeedUser>[];
  List<FeedUser> _newMembers = const <FeedUser>[];
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
      ]);
      final page = results[0] as FeedUserPage;
      final dailyFriendResponse = results[1] as FriendOfTheDayResponse;
      if (!mounted) return;
      setState(() {
        _items.addAll(page.items);
        _onlineUsers = page.onlineUsers;
        _newMembers = page.newMembers;
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
      appBar: buildAppScreenAppBar(
        context,
        title: 'Meet New Friends',
        subtitle: 'COMMUNITY',
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
                  if (showRail)
                    Column(
                      children: [
                        if (featured != null) ...[
                          _FriendOfDayCard(
                            user: featured,
                            onProfileTap: () => _openProfile(featured.username),
                            onHelloTap: () => _openProfile(featured.username),
                          ),
                          const SizedBox(height: 22),
                        ],
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_onlineUsers.isNotEmpty)
                              Expanded(
                                child: _OnlinePanel(
                                  users: _onlineUsers,
                                  onTap: _openProfile,
                                ),
                              ),
                            if (_onlineUsers.isNotEmpty &&
                                _newMembers.isNotEmpty)
                              const SizedBox(width: 18),
                            if (_newMembers.isNotEmpty)
                              Expanded(
                                child: _NewestHeartsPanel(
                                  users: _newMembers,
                                  onTap: _openProfile,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 22),
                        MostActiveUsersCard(
                          feedRepository: widget.feedRepository,
                          onOpenProfile: _openProfile,
                        ),
                        const SizedBox(height: 22),
                        _MeetMainColumn(
                          featured: featured,
                          items: suggestedItems,
                          isLoadingMore: _isLoadingMore,
                          onProfileTap: _openProfile,
                          onHelloTap: (user) => _openProfile(user.username),
                        ),
                      ],
                    )
                  else
                    Column(
                      children: [
                        if (featured != null) ...[
                          _FriendOfDayCard(
                            user: featured,
                            onProfileTap: () => _openProfile(featured.username),
                            onHelloTap: () => _openProfile(featured.username),
                          ),
                          const SizedBox(height: 18),
                        ],
                        if (_onlineUsers.isNotEmpty)
                          _OnlinePanel(
                            users: _onlineUsers,
                            onTap: _openProfile,
                          ),
                        if (_onlineUsers.isNotEmpty && _newMembers.isNotEmpty)
                          const SizedBox(height: 18),
                        if (_newMembers.isNotEmpty)
                          _NewestHeartsPanel(
                            users: _newMembers,
                            onTap: _openProfile,
                          ),
                        const SizedBox(height: 20),
                        MostActiveUsersCard(
                          feedRepository: widget.feedRepository,
                          onOpenProfile: _openProfile,
                        ),
                        const SizedBox(height: 20),
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
            childAspectRatio: 0.66,
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
      'Expand your circle and find people who inspire you.',
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
                  end: Alignment.topRight,
                  colors: [
                    colors.brand.withValues(alpha: 0.12),
                    colors.surface,
                    colors.accent.withValues(alpha: 0.10),
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
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: colors.border),
                      ),
                      child: IconButton(
                        onPressed: onProfileTap,
                        icon: Icon(Icons.sync_rounded, color: colors.textMuted),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: colors.surfaceMuted,
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
                                        image: NetworkImage(
                                          friendImageUrl,
                                        ),
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
    borderRadius: BorderRadius.circular(30),
    child: Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: colors.borderStrong),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            children: [
              Container(
                width: 120,
                height: 120,
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
                        size: 44,
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

          const SizedBox(height: 12),

          VerifiedNameText(
            name: user.displayName,
            verified: user.isVerified,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w900,
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
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),

          const Spacer(), // ✅ pushes button down properly

          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onHelloTap,
              style: FilledButton.styleFrom(
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
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: colors.success,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Recently Active',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
          const SizedBox(height: 10),
                // Text(
                //   'See All',
                //   style: TextStyle(
                //     color: colors.brand,
                //     fontSize: 13,
                //     fontWeight: FontWeight.w800,
                //   ),
                // ),
              ],
            ),
          ),
          Divider(height: 1, color: colors.border),
          ...users
              .take(10)
              .map(
                (user) => InkWell(
                  onTap: () => onTap(user.username),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                    child: Row(
                      children: [
                        Stack(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundImage: user.photoUrl.isNotEmpty
                                  ? NetworkImage(
                                      ImageUrlResolver.avatar(
                                        user.photoUrl,
                                        size: 72,
                                      ),
                                    )
                                  : null,
                              child: user.photoUrl.isEmpty
                                  ? const Icon(Icons.person)
                                  : null,
                            ),
                            // Positioned(
                            //   right: 1,
                            //   bottom: 1,
                            //   child: Container(
                            //     width: 12,
                            //     height: 12,
                            //     decoration: BoxDecoration(
                            //       color: colors.success,
                            //       shape: BoxShape.circle,
                            //       border: Border.all(
                            //         color: Colors.white,
                            //         width: 2,
                            //       ),
                            //     ),
                            //   ),
                            // ),
                          ],
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              VerifiedNameText(
                                name: user.displayName,
                                verified: user.isVerified,
                                style: TextStyle(
                                  color: colors.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                user.lastSeen.isEmpty
                                    ? 'Active recently'
                                    : user.lastSeen,
                                style: TextStyle(
                                  color: colors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
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
                'Newest Hearts',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'JOINED RECENTLY',
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
                                '@${user.username}',
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

