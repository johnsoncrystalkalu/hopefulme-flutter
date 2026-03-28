import 'package:flutter/material.dart';
import 'package:hopefulme_flutter/app/theme/app_theme.dart';
import 'package:hopefulme_flutter/core/network/image_url_resolver.dart';
import 'package:hopefulme_flutter/core/utils/time_formatter.dart';
import 'package:hopefulme_flutter/core/widgets/fullscreen_network_image_screen.dart';
import 'package:hopefulme_flutter/features/auth/models/user.dart';
import 'package:hopefulme_flutter/features/messages/data/message_repository.dart';
import 'package:hopefulme_flutter/features/messages/presentation/screens/message_thread_screen.dart';
import 'package:hopefulme_flutter/features/profile/data/profile_repository.dart';
import 'package:hopefulme_flutter/features/profile/models/profile_dashboard.dart';
import 'package:hopefulme_flutter/features/profile/presentation/screens/edit_profile_screen.dart';
import 'package:hopefulme_flutter/features/profile/presentation/screens/edit_profile_media_screen.dart';
import 'package:hopefulme_flutter/features/profile/presentation/screens/inspire_composer_screen.dart';
import 'package:hopefulme_flutter/features/profile/presentation/screens/profile_articles_screen.dart';
import 'package:hopefulme_flutter/features/profile/presentation/screens/profile_connections_screen.dart';
import 'package:hopefulme_flutter/features/profile/presentation/screens/profile_updates_screen.dart';
import 'package:hopefulme_flutter/features/updates/data/update_repository.dart';
import 'package:hopefulme_flutter/features/updates/presentation/screens/update_detail_screen.dart';
import 'package:hopefulme_flutter/features/updates/presentation/widgets/interactive_update_card.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    required this.currentUser,
    required this.profileRepository,
    required this.messageRepository,
    required this.updateRepository,
    this.username,
    super.key,
  });

  final User? currentUser;
  final ProfileRepository profileRepository;
  final MessageRepository messageRepository;
  final UpdateRepository updateRepository;
  final String? username;

  static const routeName = '/profile';

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<ProfileDashboard> _profileFuture;
  _ProfileTab _selectedTab = _ProfileTab.timeline;
  bool _isTogglingFollow = false;

  String get _targetUsername =>
      widget.username?.trim().replaceFirst('@', '') ??
      widget.currentUser?.username ??
      '';

  @override
  void initState() {
    super.initState();
    _profileFuture = widget.profileRepository.fetchProfile(_targetUsername);
  }

  Future<void> _refresh() async {
    setState(() {
      _profileFuture = widget.profileRepository.fetchProfile(_targetUsername);
    });

    await _profileFuture;
  }

  Future<void> _openEditProfile() async {
    final username = widget.currentUser?.username;
    if (username == null || username.isEmpty) {
      return;
    }

    final updated = await Navigator.of(context).push<ProfileSummary>(
      MaterialPageRoute<ProfileSummary>(
        builder: (context) => EditProfileScreen(
          username: username,
          repository: widget.profileRepository,
        ),
      ),
    );

    if (updated != null) {
      await _refresh();
    }
  }

  Future<void> _openEditMedia() async {
    final username = widget.currentUser?.username;
    if (username == null || username.isEmpty) {
      return;
    }

    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (context) => EditProfileMediaScreen(
          username: username,
          repository: widget.profileRepository,
        ),
      ),
    );
    await _refresh();
  }

  Future<void> _toggleFollow(ProfileDashboard dashboard) async {
    if (_isTogglingFollow) {
      return;
    }

    setState(() {
      _isTogglingFollow = true;
    });

    try {
      final result = await widget.profileRepository.toggleFollow(
        dashboard.profile.username,
      );
      if (!mounted) return;
      setState(() {
        _profileFuture = Future.value(
          ProfileDashboard(
            profile: ProfileSummary(
              id: dashboard.profile.id,
              username: dashboard.profile.username,
              fullname: dashboard.profile.fullname,
              email: dashboard.profile.email,
              gender: dashboard.profile.gender,
              quote: dashboard.profile.quote,
              hobby: dashboard.profile.hobby,
              role1: dashboard.profile.role1,
              city: dashboard.profile.city,
              state: dashboard.profile.state,
              phoneNumber: dashboard.profile.phoneNumber,
              theme: dashboard.profile.theme,
              verified: dashboard.profile.verified,
              photoUrl: dashboard.profile.photoUrl,
              coverUrl: dashboard.profile.coverUrl,
              followersCount: result.$2,
              followingCount: dashboard.profile.followingCount,
              views: dashboard.profile.views,
              lastSeen: dashboard.profile.lastSeen,
            ),
            posts: dashboard.posts,
            updates: dashboard.updates,
            blogs: dashboard.blogs,
            isFollowing: result.$1,
            totalPosts: dashboard.totalPosts,
            updatesCount: dashboard.updatesCount,
            photosCount: dashboard.photosCount,
          ),
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _isTogglingFollow = false;
        });
      }
    }
  }

  Future<void> _openChat(ProfileSummary profile) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => MessageThreadScreen(
          repository: widget.messageRepository,
          username: profile.username,
          title: profile.displayName,
        ),
      ),
    );
  }

  Future<void> _openInspire(ProfileSummary profile) async {
    await Navigator.of(context).push(
      MaterialPageRoute<bool>(
        builder: (context) => InspireComposerScreen(
          profile: profile,
          repository: widget.profileRepository,
        ),
      ),
    );
  }

  Future<void> _openConnections(ProfileConnectionsType type) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ProfileConnectionsScreen(
          username: _targetUsername,
          type: type,
          repository: widget.profileRepository,
          messageRepository: widget.messageRepository,
          updateRepository: widget.updateRepository,
          currentUser: widget.currentUser,
        ),
      ),
    );
  }

  Future<void> _openUpdatesFeed() async {
    final snapshot = await _profileFuture;
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ProfileUpdatesScreen(
          profile: snapshot.profile,
          repository: widget.profileRepository,
          messageRepository: widget.messageRepository,
          updateRepository: widget.updateRepository,
          currentUser: widget.currentUser,
        ),
      ),
    );
  }

  Future<void> _openArticlesFeed() async {
    final snapshot = await _profileFuture;
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ProfileArticlesScreen(
          profile: snapshot.profile,
          repository: widget.profileRepository,
        ),
      ),
    );
  }

  Future<void> _openUpdate(ProfileContentItem item) async {
    final result = await Navigator.of(context).push<UpdateDetailResult>(
      MaterialPageRoute<UpdateDetailResult>(
        builder: (context) => UpdateDetailScreen(
          updateId: item.id,
          currentUser: widget.currentUser,
          repository: widget.updateRepository,
          profileRepository: widget.profileRepository,
          messageRepository: widget.messageRepository,
        ),
      ),
    );
    if (result?.shouldRefresh == true) {
      await _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Scaffold(
      backgroundColor: colors.scaffold,
      body: FutureBuilder<ProfileDashboard>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError && !snapshot.hasData) {
            return _ProfileErrorState(
              message: snapshot.error.toString(),
              onRetry: _refresh,
            );
          }

          final dashboard = snapshot.data;
          if (dashboard == null) {
            return _ProfileErrorState(
              message: 'Unable to load profile right now.',
              onRetry: _refresh,
            );
          }

          final isDesktop = MediaQuery.of(context).size.width >= 1180;

          return RefreshIndicator(
            onRefresh: _refresh,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  _ProfileHero(profile: dashboard.profile),
                  Transform.translate(
                    offset: const Offset(0, -56),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isDesktop ? 32 : 16,
                      ),
                      child: Column(
                        children: [
                          _ProfileHeaderCard(
                            profile: dashboard.profile,
                            isFollowing: dashboard.isFollowing,
                            updatesCount: dashboard.updatesCount,
                            isCurrentUser: widget.currentUser?.username ==
                                dashboard.profile.username,
                            onEditProfile: _openEditProfile,
                            onEditMedia: _openEditMedia,
                            isTogglingFollow: _isTogglingFollow,
                            onToggleFollow: () => _toggleFollow(dashboard),
                            onMessage: () => _openChat(dashboard.profile),
                            onInspire: () => _openInspire(dashboard.profile),
                            onFollowers: () => _openConnections(
                              ProfileConnectionsType.followers,
                            ),
                            onFollowing: () => _openConnections(
                              ProfileConnectionsType.following,
                            ),
                            onPosts: _openUpdatesFeed,
                          ),
                          const SizedBox(height: 16),
                          _ProfileTabs(
                            selectedTab: _selectedTab,
                            onSelected: (tab) {
                              setState(() {
                                _selectedTab = tab;
                              });
                            },
                            photosCount: dashboard.photosCount,
                            articleCount: dashboard.blogs.length,
                          ),
                          const SizedBox(height: 18),
                          _ProfileBody(
                            selectedTab: _selectedTab,
                            dashboard: dashboard,
                            onSeeAllUpdates: _openUpdatesFeed,
                            onSeeAllArticles: _openArticlesFeed,
                            onOpenUpdate: _openUpdate,
                            currentUser: widget.currentUser,
                            updateRepository: widget.updateRepository,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

enum _ProfileTab { timeline, about, photos, articles }

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({required this.profile});

  final ProfileSummary profile;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final imageUrl = profile.coverUrl.isNotEmpty
        ? profile.coverUrl
        : profile.photoUrl;

    return SizedBox(
      height: 260,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (imageUrl.isNotEmpty)
            Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  ColoredBox(color: colors.heroFallback),
            )
          else
            ColoredBox(color: colors.heroFallback),
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color.fromRGBO(15, 23, 42, 0.18),
                  Color.fromRGBO(15, 23, 42, 0.78),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: IconButton(
                  style: IconButton.styleFrom(
                    backgroundColor: const Color.fromRGBO(255, 255, 255, 0.18),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileHeaderCard extends StatelessWidget {
  const _ProfileHeaderCard({
    required this.profile,
    required this.isFollowing,
    required this.updatesCount,
    required this.isCurrentUser,
    required this.onEditProfile,
    required this.onEditMedia,
    required this.isTogglingFollow,
    required this.onToggleFollow,
    required this.onMessage,
    required this.onInspire,
    required this.onFollowers,
    required this.onFollowing,
    required this.onPosts,
  });

  final ProfileSummary profile;
  final bool isFollowing;
  final int updatesCount;
  final bool isCurrentUser;
  final Future<void> Function() onEditProfile;
  final Future<void> Function() onEditMedia;
  final bool isTogglingFollow;
  final Future<void> Function() onToggleFollow;
  final Future<void> Function() onMessage;
  final Future<void> Function() onInspire;
  final Future<void> Function() onFollowers;
  final Future<void> Function() onFollowing;
  final Future<void> Function() onPosts;

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 940;
    final identityBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 10,
          runSpacing: 8,
          children: [
            Text(
              profile.displayName,
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.8,
              ),
            ),
            if (profile.isVerified)
              const Icon(
                Icons.verified,
                color: Color(0xFF2563EB),
                size: 26,
              ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              '@${profile.username}',
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (profile.role1.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3D5AFE), Color(0xFF7C3AED)],
                  ),
                ),
                child: Text(
                  profile.role1,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 14,
          runSpacing: 10,
          children: [
            if (profile.locationLabel.isNotEmpty)
              _MetaInline(
                icon: Icons.location_on_outlined,
                label: profile.locationLabel,
              ),
            if (profile.lastSeen.isNotEmpty)
              _MetaInline(
                icon: Icons.schedule_outlined,
                label: 'Last seen ${profile.lastSeen}',
              ),
          ],
        ),
      ],
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: context.appColors.surface,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: context.appColors.borderStrong),
        boxShadow: [
          BoxShadow(
            color: context.appColors.shadow,
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flex(
            direction: isWide ? Axis.horizontal : Axis.vertical,
            crossAxisAlignment: isWide
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              _LargeAvatar(
                imageUrl: profile.photoUrl,
                label: profile.displayName,
                isEditable: isCurrentUser,
                onEditMedia: isCurrentUser ? onEditMedia : null,
              ),
              SizedBox(width: isWide ? 20 : 0, height: isWide ? 0 : 18),
              if (isWide) Expanded(child: identityBlock) else identityBlock,
              SizedBox(width: isWide ? 16 : 0, height: isWide ? 0 : 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: isCurrentUser
                    ? [
                        _ActionButton(
                          icon: Icons.photo_camera_outlined,
                          label: 'Change Photo',
                          onTap: onEditMedia,
                        ),
                        _ActionButton(
                          icon: Icons.edit_outlined,
                          label: 'Edit Profile',
                          onTap: onEditProfile,
                        ),
                      ]
                    : [
                        _ActionButton(
                          icon: isTogglingFollow
                              ? Icons.hourglass_top
                              : isFollowing
                              ? Icons.check
                              : Icons.add,
                          label: isTogglingFollow
                              ? 'Please wait'
                              : isFollowing
                              ? 'Following'
                              : 'Follow',
                          highlighted: !isFollowing,
                          onTap: onToggleFollow,
                        ),
                        _ActionButton(
                          icon: Icons.chat_bubble_outline,
                          label: 'Message',
                          onTap: onMessage,
                        ),
                        _ActionButton(
                          icon: Icons.auto_awesome_outlined,
                          label: 'Inspire',
                          onTap: onInspire,
                        ),
                      ],
              ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  value: _formatCount(profile.followersCount),
                  label: 'Followers',
                  onTap: onFollowers,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatCard(
                  value: _formatCount(profile.followingCount),
                  label: 'Following',
                  onTap: onFollowing,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatCard(
                  value: _formatCount(updatesCount),
                  label: 'Updates',
                  onTap: onPosts,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileTabs extends StatelessWidget {
  const _ProfileTabs({
    required this.selectedTab,
    required this.onSelected,
    required this.photosCount,
    required this.articleCount,
  });

  final _ProfileTab selectedTab;
  final ValueChanged<_ProfileTab> onSelected;
  final int photosCount;
  final int articleCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: context.appColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.appColors.borderStrong),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _TabButton(
            label: 'Timeline',
            selected: selectedTab == _ProfileTab.timeline,
            onTap: () => onSelected(_ProfileTab.timeline),
          ),
          _TabButton(
            label: 'About',
            selected: selectedTab == _ProfileTab.about,
            onTap: () => onSelected(_ProfileTab.about),
          ),
          _TabButton(
            label: 'Photos',
            badge: '$photosCount',
            selected: selectedTab == _ProfileTab.photos,
            onTap: () => onSelected(_ProfileTab.photos),
          ),
          _TabButton(
            label: 'Articles',
            badge: '$articleCount',
            selected: selectedTab == _ProfileTab.articles,
            onTap: () => onSelected(_ProfileTab.articles),
          ),
        ],
      ),
    );
  }
}

class _ProfileBody extends StatelessWidget {
  const _ProfileBody({
    required this.selectedTab,
    required this.dashboard,
    required this.onSeeAllUpdates,
    required this.onSeeAllArticles,
    required this.onOpenUpdate,
    required this.currentUser,
    required this.updateRepository,
  });

  final _ProfileTab selectedTab;
  final ProfileDashboard dashboard;
  final Future<void> Function() onSeeAllUpdates;
  final Future<void> Function() onSeeAllArticles;
  final Future<void> Function(ProfileContentItem item) onOpenUpdate;
  final User? currentUser;
  final UpdateRepository updateRepository;

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 1240;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _buildPrimaryContent()),
        if (isWide) ...[
          const SizedBox(width: 18),
          SizedBox(
            width: 300,
            child: _ProfileRail(profile: dashboard.profile),
          ),
        ],
      ],
    );
  }

  Widget _buildPrimaryContent() {
    switch (selectedTab) {
      case _ProfileTab.timeline:
        return _ProfileTimeline(
          dashboard: dashboard,
          onSeeAllUpdates: onSeeAllUpdates,
          onOpenUpdate: onOpenUpdate,
          isCurrentUser: currentUser?.username == dashboard.profile.username,
          currentUser: currentUser,
          updateRepository: updateRepository,
        );
      case _ProfileTab.about:
        return _AboutTab(
          profile: dashboard.profile,
          isCurrentUser: currentUser?.username == dashboard.profile.username,
        );
      case _ProfileTab.photos:
        return _PhotosTab(
          items: _latestUpdatePhotos(dashboard),
          totalCount: dashboard.photosCount,
        );
      case _ProfileTab.articles:
        return _ArticlesTab(
          items: dashboard.blogs.take(2).toList(),
          onSeeAll: onSeeAllArticles,
        );
    }
  }
}

class _ProfileTimeline extends StatelessWidget {
  const _ProfileTimeline({
    required this.dashboard,
    required this.onSeeAllUpdates,
    required this.onOpenUpdate,
    required this.isCurrentUser,
    required this.currentUser,
    required this.updateRepository,
  });

  final ProfileDashboard dashboard;
  final Future<void> Function() onSeeAllUpdates;
  final Future<void> Function(ProfileContentItem item) onOpenUpdate;
  final bool isCurrentUser;
  final User? currentUser;
  final UpdateRepository updateRepository;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _PanelCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Profile Overview',
                style: TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              if (isCurrentUser && dashboard.profile.email.trim().isNotEmpty)
                _OverviewRow(
                  icon: Icons.email_outlined,
                  label: dashboard.profile.email,
                ),
              if (dashboard.profile.gender.isNotEmpty)
                _OverviewRow(
                  icon: Icons.person_outline,
                  label: _capitalized(dashboard.profile.gender),
                ),
              if (dashboard.profile.hobby.isNotEmpty)
                _OverviewRow(
                  icon: Icons.favorite_outline,
                  label: dashboard.profile.hobby,
                ),
              if (dashboard.profile.quote.isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    '"${dashboard.profile.quote}"',
                    style: const TextStyle(
                      color: Color(0xFF334155),
                      fontSize: 14,
                      height: 1.6,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 2, bottom: 14),
              child: Text(
                'Updates',
                style: TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (dashboard.updates.isEmpty)
              const _PanelCard(
                child: _EmptyState(label: 'No updates yet'),
              )
            else
                ...dashboard.updates.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _UpdateCard(
                      item: item,
                      profile: dashboard.profile,
                      currentUser: currentUser,
                      updateRepository: updateRepository,
                      onOpenUpdate: () => onOpenUpdate(item),
                    ),
                  ),
                ),
            if (dashboard.updates.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: OutlinedButton.icon(
                    onPressed: () => onSeeAllUpdates(),
                    icon: const Icon(Icons.expand_more),
                    label: const Text('See all updates'),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _AboutTab extends StatelessWidget {
  const _AboutTab({
    required this.profile,
    required this.isCurrentUser,
  });

  final ProfileSummary profile;
  final bool isCurrentUser;

  @override
  Widget build(BuildContext context) {
    final entries = <MapEntry<String, String>>[
      if (isCurrentUser) MapEntry('Email', profile.email),
      MapEntry('Gender', _capitalized(profile.gender)),
      MapEntry('Role', profile.role1),
      MapEntry('Location', profile.locationLabel),
      MapEntry('Hobbies', profile.hobby),
      if (isCurrentUser) MapEntry('Phone', profile.phoneNumber),
      MapEntry('Theme', _capitalized(profile.theme)),
      MapEntry('Quote', profile.quote),
    ].where((entry) => entry.value.trim().isNotEmpty).toList();

    return _PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'About ${profile.displayName}',
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: entries
                .map(
                  (entry) => SizedBox(
                    width: 260,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.key,
                            style: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            entry.value,
                            style: const TextStyle(
                              color: Color(0xFF1E293B),
                              fontSize: 14,
                              height: 1.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _PhotosTab extends StatelessWidget {
  const _PhotosTab({
    required this.items,
    required this.totalCount,
  });

  final List<ProfileContentItem> items;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    final photos = items.where((item) => item.photoUrl.isNotEmpty).toList();

    return _PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Photos',
            style: TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '$totalCount photos',
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          if (photos.isEmpty)
            const _EmptyState(label: 'No photos yet')
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: photos.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1,
              ),
              itemBuilder: (context, index) {
                final item = photos[index];
                return InkWell(
                  onTap: () => FullscreenNetworkImageScreen.show(
                    context,
                    imageUrl: ImageUrlResolver.resolveOriginal(item.photoUrl),
                  ),
                  borderRadius: BorderRadius.circular(18),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Image.network(
                      item.photoUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const ColoredBox(
                            color: Color(0xFFF1F5F9),
                            child: Icon(Icons.broken_image_outlined),
                          ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _ArticlesTab extends StatelessWidget {
  const _ArticlesTab({
    required this.items,
    required this.onSeeAll,
  });

  final List<ProfileContentItem> items;
  final Future<void> Function() onSeeAll;

  @override
  Widget build(BuildContext context) {
    return _PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Articles',
            style: TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          if (items.isEmpty)
            const _EmptyState(label: 'No articles yet')
          else
            ...[
              ...items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _BlogCard(item: item),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () => onSeeAll(),
                  icon: const Icon(Icons.menu_book_outlined),
                  label: const Text('Read all articles'),
                ),
              ),
            ],
        ],
      ),
    );
  }
}

List<ProfileContentItem> _latestUpdatePhotos(ProfileDashboard dashboard) {
  final updates = dashboard.updates
      .where((item) => item.photoUrl.isNotEmpty)
      .toList();
  updates.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return updates.take(4).toList();
}

class _ProfileRail extends StatelessWidget {
  const _ProfileRail({required this.profile});

  final ProfileSummary profile;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _PanelCard(
          child: Column(
            children: [
              _LargeAvatar(
                imageUrl: profile.photoUrl,
                label: profile.displayName,
                size: 64,
                borderRadius: 18,
              ),
              const SizedBox(height: 12),
              Text(
                profile.displayName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '@${profile.username}',
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (profile.locationLabel.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  profile.locationLabel,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        _PanelCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Quick Details',
                style: TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              _OverviewRow(
                icon: Icons.visibility_outlined,
                label: '${profile.views} views',
              ),
              _OverviewRow(
                icon: Icons.people_outline,
                label: '${profile.followersCount} followers',
              ),
              if (profile.theme.isNotEmpty)
                _OverviewRow(
                  icon: Icons.palette_outlined,
                  label: '${_capitalized(profile.theme)} theme',
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _UpdateCard extends StatelessWidget {
  const _UpdateCard({
    required this.item,
    required this.profile,
    required this.currentUser,
    required this.updateRepository,
    required this.onOpenUpdate,
  });

  final ProfileContentItem item;
  final ProfileSummary profile;
  final User? currentUser;
  final UpdateRepository updateRepository;
  final Future<void> Function() onOpenUpdate;

  @override
  Widget build(BuildContext context) {
    return InteractiveUpdateCard(
      updateId: item.id,
      title: profile.displayName,
      body: item.body,
      photoUrl: item.photoUrl,
      avatarUrl: profile.photoUrl,
      fallbackLabel: profile.displayName,
      device: item.device,
      createdAt: item.createdAt,
      likesCount: item.likesCount,
      commentsCount: item.commentsCount,
      views: item.views,
      updateRepository: updateRepository,
      onOpenUpdate: onOpenUpdate,
      currentUser: currentUser,
      ownerUsername: profile.username,
      onOpenProfile: null,
    );
  }
}

class _BlogCard extends StatelessWidget {
  const _BlogCard({required this.item});

  final ProfileContentItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.appColors.surfaceMuted,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.appColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (item.photoUrl.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              child: AspectRatio(
                aspectRatio: 16 / 8.5,
                child: Image.network(
                  item.photoUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const Center(child: Icon(Icons.broken_image_outlined)),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF1FF),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'ARTICLE',
                    style: TextStyle(
                      color: Color(0xFF3D5AFE),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  item.title.isNotEmpty ? item.title : 'Untitled article',
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (item.body.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    item.body,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF475569),
                      fontSize: 14,
                      height: 1.6,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  formatRelativeTimestamp(item.createdAt),
                  style: TextStyle(
                    color: context.appColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
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

class _ProfileErrorState extends StatelessWidget {
  const _ProfileErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.person_off_outlined,
              size: 44,
              color: Color(0xFF94A3B8),
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF475569),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: () => onRetry(),
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PanelCard extends StatelessWidget {
  const _PanelCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.appColors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: context.appColors.borderStrong),
        boxShadow: [
          BoxShadow(
            color: context.appColors.shadow.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _LargeAvatar extends StatelessWidget {
  const _LargeAvatar({
    required this.imageUrl,
    required this.label,
    this.size = 72,
    this.borderRadius = 26,
    this.isEditable = false,
    this.onEditMedia,
  });

  final String imageUrl;
  final String label;
  final double size;
  final double borderRadius;
  final bool isEditable;
  final Future<void> Function()? onEditMedia;

  @override
  Widget build(BuildContext context) {
    final initials = label
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();
    final avatar = SizedBox(
      width: size * 2,
      height: size * 2,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size * 2,
            height: size * 2,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(color: context.appColors.surface, width: 4),
              color: context.appColors.avatarPlaceholder,
            ),
            clipBehavior: Clip.antiAlias,
            child: imageUrl.isNotEmpty
                ? Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Center(
                      child: Text(
                        initials.isEmpty ? 'U' : initials,
                        style: TextStyle(
                          color: context.appColors.accentSoftText,
                          fontSize: size * 0.44,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  )
                : Center(
                    child: Text(
                      initials.isEmpty ? 'U' : initials,
                      style: TextStyle(
                        color: context.appColors.accentSoftText,
                        fontSize: size * 0.44,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
          ),
          if (isEditable && onEditMedia != null)
            Positioned(
              right: -2,
              bottom: -2,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => onEditMedia!(),
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF3D5AFE), Color(0xFF7C3AED)],
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: context.appColors.surface,
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: context.appColors.shadow.withOpacity(0.18),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.photo_camera_outlined,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    if (imageUrl.isEmpty) {
      return avatar;
    }

    return InkWell(
      onTap: () =>
          FullscreenNetworkImageScreen.show(
            context,
            imageUrl: ImageUrlResolver.resolveOriginal(imageUrl),
          ),
      borderRadius: BorderRadius.circular(borderRadius),
      child: avatar,
    );
  }
}

class _MetaInline extends StatelessWidget {
  const _MetaInline({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: context.appColors.icon),
        const SizedBox(width: 7),
        Text(
          label,
          style: TextStyle(
            color: context.appColors.textSecondary,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    this.highlighted = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool highlighted;
  final Future<void> Function()? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap == null ? null : () => onTap!.call(),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: highlighted
              ? context.appColors.brandGradient
              : null,
          color: highlighted ? null : context.appColors.surfaceMuted,
          border: highlighted
              ? null
              : Border.all(color: context.appColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: highlighted ? Colors.white : context.appColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: highlighted ? Colors.white : context.appColors.textPrimary,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.value,
    required this.label,
    this.onTap,
  });

  final String value;
  final String label;
  final Future<void> Function()? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap == null ? null : () => onTap!.call(),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          color: context.appColors.surfaceMuted,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: context.appColors.border),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                color: context.appColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: context.appColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? context.appColors.brand : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : context.appColors.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: selected
                      ? const Color.fromRGBO(255, 255, 255, 0.18)
                      : context.appColors.surfaceRaised,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  badge!,
                  style: TextStyle(
                    color: selected ? Colors.white : context.appColors.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _OverviewRow extends StatelessWidget {
  const _OverviewRow({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: context.appColors.accentSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 17,
              color: context.appColors.accentSoftText,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: context.appColors.textSecondary,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.appColors.surfaceMuted,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: context.appColors.border),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: context.appColors.textMuted,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

String _capitalized(String value) {
  if (value.trim().isEmpty) {
    return '';
  }

  final normalized = value.trim();
  return normalized[0].toUpperCase() + normalized.substring(1);
}

String _formatCount(int value) {
  if (value >= 1000000) {
    return '${(value / 1000000).toStringAsFixed(1)}M';
  }
  if (value >= 1000) {
    return '${(value / 1000).toStringAsFixed(1)}K';
  }
  return '$value';
}


