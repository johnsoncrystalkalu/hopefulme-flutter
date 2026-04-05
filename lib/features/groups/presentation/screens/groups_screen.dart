import 'package:flutter/material.dart';
import 'package:hopefulme_flutter/app/theme/app_theme.dart';
import 'package:hopefulme_flutter/core/network/image_url_resolver.dart';
import 'package:hopefulme_flutter/core/widgets/app_screen_app_bar.dart';
import 'package:hopefulme_flutter/core/widgets/app_status_state.dart';
import 'package:hopefulme_flutter/features/auth/models/user.dart';
import 'package:hopefulme_flutter/features/groups/data/group_repository.dart';
import 'package:hopefulme_flutter/features/groups/models/group_models.dart';
import 'package:hopefulme_flutter/features/groups/presentation/screens/group_thread_screen.dart';
import 'package:hopefulme_flutter/features/messages/data/message_repository.dart';
import 'package:hopefulme_flutter/features/profile/data/profile_repository.dart';
import 'package:hopefulme_flutter/features/updates/data/update_repository.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({
    required this.repository,
    required this.currentUser,
    required this.profileRepository,
    required this.messageRepository,
    required this.updateRepository,
    super.key,
  });

  final GroupRepository repository;
  final User? currentUser;
  final ProfileRepository profileRepository;
  final MessageRepository messageRepository;
  final UpdateRepository updateRepository;

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  final ScrollController _scrollController = ScrollController();
  final List<AppGroup> _groups = <AppGroup>[];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  Object? _error;
  int _page = 1;
  int _lastPage = 1;

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
      _lastPage = 1;
    });

    try {
      final page = await widget.repository.fetchGroups(page: 1);
      if (!mounted) {
        return;
      }
      setState(() {
        _groups
          ..clear()
          ..addAll(page.items);
        _page = page.currentPage;
        _lastPage = page.lastPage;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error;
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
    });

    try {
      final nextPage = _page + 1;
      final page = await widget.repository.fetchGroups(page: nextPage);
      if (!mounted) {
        return;
      }
      setState(() {
        _groups.addAll(page.items);
        _page = page.currentPage;
        _lastPage = page.lastPage;
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
            _scrollController.position.maxScrollExtent - 260 &&
        !_isLoadingMore) {
      _loadMore();
    }
  }

  Future<void> _openGroup(AppGroup group) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (context) => GroupThreadScreen(
          groupId: group.id,
          currentUser: widget.currentUser,
          repository: widget.repository,
          profileRepository: widget.profileRepository,
          messageRepository: widget.messageRepository,
          updateRepository: widget.updateRepository,
        ),
      ),
    );
    if (changed ?? false) {
      await _loadInitial();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final myGroups = _groups.where((group) => group.isMember).toList();
    final community = _groups.where((group) => group.id == 1).firstOrNull;
    final discover = _groups.where((group) => group.id != 1).toList();

    return Scaffold(
      backgroundColor: colors.scaffold,
      appBar: buildAppScreenAppBar(
        context,
        title: 'Groups',
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
                padding: const EdgeInsets.all(16),
                children: [
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        gradient: colors.heroGradient,
                        borderRadius: BorderRadius.circular(26),
                      ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Group Chats',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Join conversations, share ideas, build community.',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (myGroups.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _SectionTitle(
                      title: 'My Groups',
                      trailing: '${myGroups.length} groups',
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 156,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: myGroups.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final group = myGroups[index];
                          return _MyGroupCard(
                            group: group,
                            onTap: () => _openGroup(group),
                          );
                        },
                      ),
                    ),
                  ],
                  if (community != null) ...[
                    const SizedBox(height: 24),
                    _SectionTitle(title: 'Community', trailing: 'Official'),
                    const SizedBox(height: 12),
                    _CommunityCard(
                      group: community,
                      onTap: () => _openGroup(community),
                    ),
                  ],
                  const SizedBox(height: 24),
                  _SectionTitle(
                    title: 'Discover',
                    trailing: '${_groups.length} groups',
                  ),
                  const SizedBox(height: 12),
                  ...discover.map(
                    (group) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _DiscoverGroupCard(
                        group: group,
                        onTap: () => _openGroup(group),
                      ),
                    ),
                  ),
                  if (_isLoadingMore)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 18),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                ],
              ),
            ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.trailing});

  final String title;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const Spacer(),
        Text(
          trailing,
          style: TextStyle(
            color: colors.textMuted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _MyGroupCard extends StatelessWidget {
  const _MyGroupCard({required this.group, required this.onTap});

  final AppGroup group;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Ink(
        width: 148,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          image: group.photoUrl.isNotEmpty
              ? DecorationImage(
                  image: NetworkImage(
                    ImageUrlResolver.thumbnail(group.photoUrl, size: 300),
                  ),
                  fit: BoxFit.cover,
                )
              : null,
          gradient: group.photoUrl.isEmpty
              ? const LinearGradient(
                  colors: [Color(0xFF3D5AFE), Color(0xFF3D5AFE)],
                )
              : null,
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color.fromRGBO(15, 23, 42, 0.12),
                Color.fromRGBO(15, 23, 42, 0.82),
              ],
            ),
          ),
          padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(),
                Text(
                  group.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                group.latestMessage?.time ?? '',
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CommunityCard extends StatelessWidget {
  const _CommunityCard({required this.group, required this.onTap});

  final AppGroup group;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: colors.brand.withOpacity(0.18), width: 2),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundImage: group.photoUrl.isNotEmpty
                  ? NetworkImage(
                      ImageUrlResolver.avatar(group.photoUrl, size: 90),
                    )
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                        Expanded(
                          child: Text(
                            group.name,
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          gradient: colors.brandGradient,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Official',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    group.info,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: colors.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiscoverGroupCard extends StatelessWidget {
  const _DiscoverGroupCard({required this.group, required this.onTap});

  final AppGroup group;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundImage: group.photoUrl.isNotEmpty
                    ? NetworkImage(
                        ImageUrlResolver.avatar(group.photoUrl, size: 84),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                          Expanded(
                            child: Text(
                              group.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                            ),
                          ),
                          if (group.isPrivate)
                            Icon(
                              Icons.lock_outline,
                            size: 16,
                            color: colors.textMuted,
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      group.info.isNotEmpty ? group.info : 'No description',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: colors.textMuted, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          '${group.membersCount} members',
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (group.category.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: colors.surfaceMuted,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              group.category,
                              style: TextStyle(
                                color: colors.textMuted,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                        const Spacer(),
                        if (group.hasUnread)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              group.unreadCount > 9 ? '9+' : '${group.unreadCount}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(Icons.chevron_right, color: colors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
