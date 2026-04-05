import 'package:flutter/material.dart';
import 'package:hopefulme_flutter/app/theme/app_theme.dart';
import 'package:hopefulme_flutter/core/network/image_url_resolver.dart';
import 'package:hopefulme_flutter/core/utils/time_formatter.dart';
import 'package:hopefulme_flutter/core/widgets/app_network_image.dart';
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
import 'package:hopefulme_flutter/features/profile/presentation/screens/profile_photos_screen.dart';
import 'package:hopefulme_flutter/features/profile/presentation/screens/profile_updates_screen.dart';
import 'package:hopefulme_flutter/core/widgets/verified_name_text.dart';
import 'package:hopefulme_flutter/features/updates/data/update_repository.dart';
import 'package:flutter/services.dart';
import 'package:hopefulme_flutter/features/updates/presentation/screens/update_detail_screen.dart';
import 'package:hopefulme_flutter/features/updates/presentation/widgets/interactive_update_card.dart';
import 'package:hopefulme_flutter/core/widgets/app_toast.dart';

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
  final GlobalKey _avatarMenuKey = GlobalKey();

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
              role2: dashboard.profile.role2,
              location: dashboard.profile.location,
              city: dashboard.profile.city,
                state: dashboard.profile.state,
                birthday: dashboard.profile.birthday,
                phoneNumber: dashboard.profile.phoneNumber,
                emailNotifications: dashboard.profile.emailNotifications,
                theme: dashboard.profile.theme,
                device: dashboard.profile.device,
              verified: dashboard.profile.verified,
              photoUrl: dashboard.profile.photoUrl,
              coverUrl: dashboard.profile.coverUrl,
              followersCount: result.$2,
              followingCount: dashboard.profile.followingCount,
              views: dashboard.profile.views,
              lastSeen: dashboard.profile.lastSeen,
              isOnline: dashboard.profile.isOnline,
              activityLevel: dashboard.profile.activityLevel,
            ),
            posts: dashboard.posts,
            updates: dashboard.updates,
            blogs: dashboard.blogs,
            isFollowing: result.$1,
            totalPosts: dashboard.totalPosts,
            updatesCount: dashboard.updatesCount,
            photosCount: dashboard.photosCount,
            mutualFollowers: dashboard.mutualFollowers,
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
          profileRepository: widget.profileRepository,
          updateRepository: widget.updateRepository,
          currentUser: widget.currentUser,
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

  Future<void> _copyProfileUrl(String username) async {
    await Clipboard.setData(
      ClipboardData(text: 'https://ahopefulme.com/$username'),
    );
    if (mounted) AppToast.success(context, 'Profile link copied!');
  }

  Future<void> _reportUser(String username) async {
    try {
      final reasons = await widget.profileRepository.getReportReasons();
      if (!mounted) return;
      if (reasons.isEmpty) {
        AppToast.error(context, 'Could not load report reasons. Try again.');
        return;
      }
      final selectedReason = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Report User'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: reasons.length,
              itemBuilder: (context, index) => ListTile(
                title: Text(reasons[index]),
                onTap: () => Navigator.pop(context, reasons[index]),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );
      if (selectedReason == null || !mounted) {
        return;
      }
      await widget.profileRepository.reportUser(username, selectedReason);
      if (mounted) {
        AppToast.success(context, 'Report submitted. Thank you!');
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(
          context,
          'Failed to submit report. You have reported this user before',
        );
      }
    }
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

  Future<void> _openPhotosFeed() async {
    final snapshot = await _profileFuture;
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ProfilePhotosScreen(
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
                            isCurrentUser:
                                widget.currentUser?.username ==
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
                            mutualFollowers: dashboard.mutualFollowers,
                            onCopyProfileUrl: (username) =>
                                _copyProfileUrl(username),
                            onReportUser: (username) => _reportUser(username),
                            menuKey: _avatarMenuKey,
                          ),
                          const SizedBox(height: 16),
                          if (_isBirthdayToday(dashboard.profile.birthday))
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: _BirthdayBanner(
                                profile: dashboard.profile,
                              ),
                            ),
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
                            isCurrentUser:
                                widget.currentUser?.username ==
                                dashboard.profile.username,
                            onSeeAllPhotos: _openPhotosFeed,
                            onSeeAllArticles: _openArticlesFeed,
                          ),
                          const SizedBox(height: 18),
                          _ProfileUpdatesTab(
                            key: ValueKey<String>(
                              'updates:${dashboard.profile.username}',
                            ),
                            profile: dashboard.profile,
                            repository: widget.profileRepository,
                            updateRepository: widget.updateRepository,
                            currentUser: widget.currentUser,
                            onOpenUpdate: _openUpdate,
                            onSeeAllUpdates: _openUpdatesFeed,
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

bool _isBirthdayToday(String birthday) {
  final parts = birthday
      .split('-')
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.length < 2) {
    return false;
  }

  final day = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  if (day == null || month == null) {
    return false;
  }

  final now = DateTime.now();
  return now.day == day && now.month == month;
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
            AppNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              backgroundColor: colors.heroFallback,
              placeholderLabel: profile.displayName,
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

class _BirthdayBanner extends StatelessWidget {
  const _BirthdayBanner({required this.profile});

  final ProfileSummary profile;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final firstName = profile.displayName.trim().split(RegExp(r'\s+')).first;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: const BoxDecoration(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: colors.surface.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFFDA4AF).withValues(alpha: 0.25),
              ),
            ),
            child: const Icon(
              Icons.cake_outlined,
              color: Color(0xFFE11D48),
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Happy Birthday',
                        style: TextStyle(
                          color: Color(0xFFE11D48),
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFE4E6),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'TODAY',
                        style: TextStyle(
                          color: Color(0xFFE11D48),
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'It\'s $firstName\'s birthday. Here\'s to a year filled with joy and good things ahead! 🎂',
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 13,
                    height: 1.5,
                    fontWeight: FontWeight.w500,
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
    required this.mutualFollowers,
    this.onReportUser,
    this.onCopyProfileUrl,
    this.menuKey,
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
  final List<ProfileMutualFollower> mutualFollowers;
  final Future<void> Function(String username)? onReportUser;
  final Future<void> Function(String username)? onCopyProfileUrl;
  final GlobalKey? menuKey;

  Future<void> _showProfileMenu(
    BuildContext ctx,
    String username,
    GlobalKey menuKey,
  ) async {
    final RenderBox? renderBox =
        menuKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return;
    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    final value = await showMenu<String>(
      context: ctx,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy + size.height,
        position.dx + size.width,
        position.dy,
      ),
      items: [
        const PopupMenuItem(
          value: 'copy_url',
          child: Row(
            children: [
              Icon(Icons.link, size: 20),
              SizedBox(width: 12),
              Text('Copy Profile URL'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'report',
          child: Row(
            children: [
              Icon(Icons.flag_outlined, size: 20, color: Colors.orange),
              SizedBox(width: 12),
              Text('Report User'),
            ],
          ),
        ),
      ],
    );
    if (value == 'copy_url') {
      onCopyProfileUrl?.call(username);
    } else if (value == 'report') {
      onReportUser?.call(username);
    }
  }

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
            VerifiedNameText(
              name: profile.displayName,
              verified: profile.isVerified,
              style: TextStyle(
                color: context.appColors.textPrimary,
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.8,
              ),
              badgeSize: 22,
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
              style: TextStyle(
                color: context.appColors.textMuted,
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
                    colors: [Color(0xFF3D5AFE), Color(0xFF3D5AFE)],
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
          ],
        ),
        const SizedBox(height: 12),
        _ProfileStatusRow(profile: profile),
        if (mutualFollowers.isNotEmpty) ...[
          const SizedBox(height: 10),
          _MutualFollowersRow(mutualFollowers: mutualFollowers),
        ],
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
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        // <--- 1. Add Stack here
        children: [
          Column(
            // Your existing content
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
                    showMenu: null,
                  ),
                  SizedBox(width: isWide ? 20 : 0, height: isWide ? 0 : 18),
                  if (isWide) Expanded(child: identityBlock) else identityBlock,
                  SizedBox(width: isWide ? 16 : 0, height: isWide ? 0 : 18),
                  isCurrentUser
                      ? Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _ActionButton(
                              icon: Icons.photo_camera_outlined,
                              label: 'Change Photo',
                              compact: true,
                              onTap: onEditMedia,
                            ),
                            _ActionButton(
                              icon: Icons.edit_outlined,
                              label: 'Edit Profile',
                              compact: true,
                              onTap: onEditProfile,
                            ),
                          ],
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Expanded(
                              child: _ActionButton(
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
                              compact: true,
                              onTap: onToggleFollow,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _ActionButton(
                              icon: Icons.chat_bubble_outline,
                              label: 'Chat',
                              compact: true,
                              onTap: onMessage,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _ActionButton(
                              icon: Icons.auto_awesome_outlined,
                              label: 'Inspire',
                              compact: true,
                              onTap: onInspire,
                            ),
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

          // 3. Add the Menu Button at the Top Right
          if (!isCurrentUser)
            Positioned(
              top: 0,
              right: 0,
              child: IconButton(
                key: menuKey,
                icon: const Icon(Icons.more_vert),
                onPressed: () =>
                    _showProfileMenu(context, profile.username, menuKey!),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProfileStatusRow extends StatelessWidget {
  const _ProfileStatusRow({required this.profile});

  final ProfileSummary profile;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final onlineColor = profile.isOnline
        ? const Color(0xFF22C55E)
        : const Color(0xFFFBBF24);
    final deviceLabel = switch (profile.device.toLowerCase()) {
      'app' => 'App',
      'desktop' => 'Desktop',
      'mobile' => 'Mobile',
      _ => profile.device.trim().isEmpty ? 'Mobile' : profile.device,
    };
    final deviceIcon = switch (profile.device.toLowerCase()) {
      'desktop' => Icons.desktop_windows_outlined,
      _ => Icons.phone_android_outlined,
    };

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: onlineColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: onlineColor.withValues(alpha: 0.45),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              profile.isOnline ? 'Online' : 'Last seen: ${profile.lastSeen}',
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        Text(
          '|',
          style: TextStyle(
            color: colors.textMuted.withValues(alpha: 0.5),
            fontWeight: FontWeight.w700,
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(deviceIcon, size: 15, color: colors.brand),
            const SizedBox(width: 6),
            Text(
              deviceLabel,
              style: TextStyle(
                color: colors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MutualFollowersRow extends StatelessWidget {
  const _MutualFollowersRow({required this.mutualFollowers});

  final List<ProfileMutualFollower> mutualFollowers;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    if (mutualFollowers.isEmpty) {
      return const SizedBox.shrink();
    }

    final first = mutualFollowers.first;
    final suffix = mutualFollowers.length > 1
        ? ' & ${mutualFollowers.length - 1} others'
        : '';

    return Row(
      children: [
        SizedBox(
          width: 50,
          height: 22,
          child: Stack(
            children: [
              for (var i = 0; i < mutualFollowers.length && i < 3; i++)
                Positioned(
                  left: i * 14,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: colors.surface, width: 2),
                    ),
                    child: ClipOval(
                      child: AppNetworkImage(
                        imageUrl: mutualFollowers[i].photoUrl,
                        fit: BoxFit.cover,
                        backgroundColor: colors.avatarPlaceholder,
                        placeholderLabel: mutualFollowers[i].displayName,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Followed by ${first.displayName}$suffix',
            style: TextStyle(
              color: colors.textMuted,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _ActivityLevelCard extends StatelessWidget {
  const _ActivityLevelCard({required this.level, required this.showProgress});

  final ProfileActivityLevel level;
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final levelColor = _colorFromHex(level.color);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: levelColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: Text(level.icon, style: const TextStyle(fontSize: 22)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Activity Rank',
                      style: TextStyle(
                        color: colors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      level.name,
                      style: TextStyle(
                        color: levelColor,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              if (showProgress)
                Text(
                  '${level.percent.round()}%',
                  style: TextStyle(
                    color: levelColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
          if (showProgress) ...[
            const SizedBox(height: 14),
            Container(
              height: 10,
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: colors.border),
              ),
              child: FractionallySizedBox(
                widthFactor: (level.percent.clamp(0, 100)) / 100,
                alignment: Alignment.centerLeft,
                child: Container(
                  decoration: BoxDecoration(
                    color: levelColor,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Progress to next level is visible only to you.',
              style: TextStyle(
                color: colors.textMuted,
                fontSize: 10.5,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

Color _colorFromHex(String value) {
  final hex = value.replaceFirst('#', '').trim();
  final normalized = hex.length == 6 ? 'FF$hex' : hex;
  return Color(int.tryParse(normalized, radix: 16) ?? 0xFF94A3B8);
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
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
             // badge: '$photosCount',
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
      ),
    );
  }
}

class _ProfileBody extends StatelessWidget {
  const _ProfileBody({
    required this.selectedTab,
    required this.dashboard,
    required this.isCurrentUser,
    required this.onSeeAllPhotos,
    required this.onSeeAllArticles,
  });

  final _ProfileTab selectedTab;
  final ProfileDashboard dashboard;
  final bool isCurrentUser;
  final Future<void> Function() onSeeAllPhotos;
  final Future<void> Function() onSeeAllArticles;

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 1240;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _buildPrimaryContent()),
        if (isWide) ...[
          const SizedBox(width: 18),
          SizedBox(width: 300, child: _ProfileRail(profile: dashboard.profile)),
        ],
      ],
    );
  }

  Widget _buildPrimaryContent() {
    switch (selectedTab) {
      case _ProfileTab.timeline:
        return _ProfileTimeline(
          dashboard: dashboard,
          isCurrentUser: isCurrentUser,
        );
      case _ProfileTab.about:
        return _AboutTab(
          profile: dashboard.profile,
          isCurrentUser: isCurrentUser,
        );
      case _ProfileTab.photos:
        return _PhotosPreviewTab(
          items: _latestUpdatePhotos(dashboard),
          onViewAll: onSeeAllPhotos,
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
    required this.isCurrentUser,
  });

  final ProfileDashboard dashboard;
  final bool isCurrentUser;

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
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              if (isCurrentUser && dashboard.profile.email.trim().isNotEmpty)
                _OverviewRow(
                  icon: Icons.email_outlined,
                  label: dashboard.profile.email,
                ),
              if (dashboard.profile.role2.isNotEmpty)
                _OverviewRow(
                  icon: Icons.person_outline,
                  label: dashboard.profile.role2,
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
                    color: context.appColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: context.appColors.border),
                  ),
                  child: Text(
                    '"${dashboard.profile.quote}"',
                    style: TextStyle(
                      color: context.appColors.textSecondary,
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
      ],
    );
  }
}

class _ProfileUpdatesTab extends StatefulWidget {
  const _ProfileUpdatesTab({
    required this.profile,
    required this.repository,
    required this.updateRepository,
    required this.currentUser,
    required this.onOpenUpdate,
    required this.onSeeAllUpdates,
    super.key,
  });

  final ProfileSummary profile;
  final ProfileRepository repository;
  final UpdateRepository updateRepository;
  final User? currentUser;
  final Future<void> Function(ProfileContentItem item) onOpenUpdate;
  final Future<void> Function() onSeeAllUpdates;

  @override
  State<_ProfileUpdatesTab> createState() => _ProfileUpdatesTabState();
}

class _ProfileUpdatesTabState extends State<_ProfileUpdatesTab> {
  final List<ProfileContentItem> _items = <ProfileContentItem>[];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  @override
  void didUpdateWidget(covariant _ProfileUpdatesTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile.username != widget.profile.username) {
      _loadInitial();
    }
  }

  Future<void> _loadInitial() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _page = 1;
      _hasMore = true;
      _items.clear();
    });

    try {
      final page = await widget.repository.fetchUserUpdates(
        widget.profile.username,
        page: 1,
      );
      if (!mounted) return;
      setState(() {
        _items.addAll(page.items);
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
    if (_isLoading || _isLoadingMore || !_hasMore) {
      return;
    }

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final nextPage = _page + 1;
      final page = await widget.repository.fetchUserUpdates(
        widget.profile.username,
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const _PanelCard(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_error != null) {
      return _PanelCard(
        child: _EmptyState(label: 'Could not load updates right now'),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.pixels >=
            notification.metrics.maxScrollExtent - 240) {
          _loadMore();
        }
        return false;
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ActivityLevelCard(
            level: widget.profile.activityLevel,
            showProgress:
                widget.currentUser?.username == widget.profile.username,
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 14),
            child: Text(
              'Updates',
              style: TextStyle(
                color: context.appColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (_items.isEmpty)
            const _PanelCard(child: _EmptyState(label: 'No updates yet'))
          else
            ..._items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _UpdateCard(
                  item: item,
                  profile: widget.profile,
                  currentUser: widget.currentUser,
                  updateRepository: widget.updateRepository,
                  onOpenUpdate: () => widget.onOpenUpdate(item),
                ),
              ),
            ),
          if (_items.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: OutlinedButton.icon(
                  onPressed: () => widget.onSeeAllUpdates(),
                  icon: const Icon(Icons.expand_more),
                  label: const Text('View all updates'),
                ),
              ),
            ),
          if (_isLoadingMore)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}

class _AboutTab extends StatelessWidget {
  const _AboutTab({required this.profile, required this.isCurrentUser});

  final ProfileSummary profile;
  final bool isCurrentUser;

  @override
  Widget build(BuildContext context) {
    final entries = <MapEntry<String, String>>[
      if (isCurrentUser) MapEntry('Email', profile.email),
      MapEntry('Identity', profile.role2),
      MapEntry('Role', profile.role1),
      MapEntry('Location', profile.locationLabel),
      MapEntry('Hobbies', profile.hobby),
      if (isCurrentUser) MapEntry('Phone', profile.phoneNumber),
      MapEntry(
        'Last seen',
        profile.device.trim().isNotEmpty
            ? '${profile.lastSeen} | on ${profile.device}'
            : profile.lastSeen,
      ),
      MapEntry('Quote', profile.quote),
    ].where((entry) => entry.value.trim().isNotEmpty).toList();

    return _PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'About ${profile.displayName}',
            style: TextStyle(
              color: context.appColors.textPrimary,
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
                        color: context.appColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: context.appColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.key,
                            style: TextStyle(
                              color: context.appColors.textMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            entry.value,
                            style: TextStyle(
                              color: context.appColors.textPrimary,
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

class _PhotosPreviewTab extends StatelessWidget {
  const _PhotosPreviewTab({required this.items, required this.onViewAll});

  final List<ProfileContentItem> items;
  final Future<void> Function() onViewAll;

  @override
  Widget build(BuildContext context) {
    final photos = items
        .where((item) => item.photoUrl.trim().isNotEmpty)
        .take(4)
        .toList();
    final galleryUrls = photos
        .map((item) => ImageUrlResolver.resolveOriginal(item.photoUrl))
        .where((url) => url.trim().isNotEmpty)
        .toList();

    return _PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Photos',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
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
                mainAxisSpacing: 5,
                crossAxisSpacing: 5,
                childAspectRatio: 1,
              ),
              itemBuilder: (context, index) {
                final item = photos[index];
                return InkWell(
                  onTap: () => FullscreenNetworkImageScreen.showGallery(
                    context,
                    imageUrls: galleryUrls,
                    initialIndex: index,
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
          if (photos.isNotEmpty) ...[
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => onViewAll(),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('View gallery'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ArticlesTab extends StatelessWidget {
  const _ArticlesTab({required this.items, required this.onSeeAll});

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
          else ...[
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
              Align(
                child: VerifiedNameText(
                  name: profile.displayName,
                  verified: profile.isVerified,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: context.appColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '@${profile.username}',
                style: TextStyle(
                  color: context.appColors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (profile.locationLabel.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  profile.locationLabel,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: context.appColors.textMuted,
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
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
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
              if (profile.role2.isNotEmpty)
                _OverviewRow(icon: Icons.badge_outlined, label: profile.role2),
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
      updateType: item.updateType,
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
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
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
  const _ProfileErrorState({required this.message, required this.onRetry});

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
              style: const TextStyle(color: Color(0xFF475569), fontSize: 14),
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
    this.showMenu,
    this.menuKey,
  });

  final String imageUrl;
  final String label;
  final double size;
  final double borderRadius;
  final bool isEditable;
  final Future<void> Function()? onEditMedia;
  final Future<void> Function()? showMenu;
  final GlobalKey? menuKey;

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
                ? AppNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    backgroundColor: context.appColors.avatarPlaceholder,
                    placeholderLabel: label,
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
                        colors: [Color(0xFF3D5AFE), Color(0xFF3D5AFE)],
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
          if (showMenu != null)
            Positioned(
              right: -2,
              top: (size * 2 - 32) / 2,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => showMenu!(),
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: context.appColors.surface,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: context.appColors.borderStrong,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: context.appColors.shadow.withOpacity(0.12),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.more_vert,
                      color: context.appColors.textMuted,
                      size: 16,
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
      onTap: () => FullscreenNetworkImageScreen.show(
        context,
        imageUrl: ImageUrlResolver.resolveOriginal(imageUrl),
      ),
      borderRadius: BorderRadius.circular(borderRadius),
      child: avatar,
    );
  }
}

class _MetaInline extends StatelessWidget {
  const _MetaInline({required this.icon, required this.label});

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
    this.compact = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool highlighted;
  final bool compact;
  final Future<void> Function()? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap == null ? null : () => onTap!.call(),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 16,
          vertical: compact ? 10 : 11,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: highlighted
              ? const Color(0xFF1F2937)
              : context.appColors.surfaceMuted,
          border: highlighted
              ? null
              : Border.all(color: context.appColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: compact ? 15 : 16,
              color: highlighted
                  ? Colors.white
                  : context.appColors.textSecondary,
            ),
            SizedBox(width: compact ? 6 : 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.fade,
                softWrap: false,
                style: TextStyle(
                  color: highlighted
                      ? Colors.white
                      : context.appColors.textPrimary,
                  fontSize: compact ? 12 : 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.value, required this.label, this.onTap});

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
                    color: selected
                        ? Colors.white
                        : context.appColors.textMuted,
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
  const _OverviewRow({required this.icon, required this.label});

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

String _formatCount(int value) {
  if (value >= 1000000) {
    return '${(value / 1000000).toStringAsFixed(1)}M';
  }
  if (value >= 1000) {
    return '${(value / 1000).toStringAsFixed(1)}K';
  }
  return '$value';
}
