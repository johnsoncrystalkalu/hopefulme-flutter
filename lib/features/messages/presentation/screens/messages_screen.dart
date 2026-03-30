import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';
import 'package:hopefulme_flutter/app/theme/app_theme.dart';
import 'package:hopefulme_flutter/core/utils/time_formatter.dart';
import 'package:hopefulme_flutter/core/widgets/app_status_state.dart';
import 'package:hopefulme_flutter/features/auth/models/user.dart';
import 'package:hopefulme_flutter/features/groups/data/group_repository.dart';
import 'package:hopefulme_flutter/features/groups/presentation/screens/groups_screen.dart';
import 'package:hopefulme_flutter/features/messages/data/message_repository.dart';
import 'package:hopefulme_flutter/features/messages/models/conversation_models.dart';
import 'package:hopefulme_flutter/features/messages/presentation/screens/message_thread_screen.dart';
import 'package:hopefulme_flutter/features/profile/data/profile_repository.dart';
import 'package:hopefulme_flutter/features/profile/presentation/profile_navigation.dart';
import 'package:hopefulme_flutter/features/updates/data/update_repository.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({
    required this.repository,
    required this.profileRepository,
    required this.updateRepository,
    this.groupRepository,
    this.currentUser,
    super.key,
  });

  final MessageRepository repository;
  final ProfileRepository profileRepository;
  final UpdateRepository updateRepository;
  final GroupRepository? groupRepository;
  final User? currentUser;

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final ScrollController _scrollController = ScrollController();
  final List<ConversationListItem> _visibleItems = <ConversationListItem>[];
  List<ConversationListItem> _allItems = <ConversationListItem>[];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _error;
  int _page = 0;
  static const int _pageSize = 20;

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
    });

    try {
      final items = await widget.repository.fetchConversations();
      setState(() {
        _allItems = items;
        _visibleItems.clear();
        _page = 0;
      });
      _appendPage();
    } catch (error) {
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

  void _appendPage() {
    final start = _page * _pageSize;
    if (start >= _allItems.length) {
      return;
    }
    final end = start + _pageSize > _allItems.length
        ? _allItems.length
        : start + _pageSize;
    setState(() {
      _visibleItems.addAll(_allItems.sublist(start, end));
      _page += 1;
      _isLoadingMore = false;
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 220 &&
        !_isLoadingMore &&
        _visibleItems.length < _allItems.length) {
      setState(() {
        _isLoadingMore = true;
      });
      _appendPage();
    }
  }

  Future<void> _openConversation(ConversationListItem item) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => MessageThreadScreen(
          repository: widget.repository,
          profileRepository: widget.profileRepository,
          updateRepository: widget.updateRepository,
          currentUser: widget.currentUser,
          username: item.otherUser.username,
          title: item.otherUser.displayName,
        ),
      ),
    );
    _loadInitial();
  }

  Future<void> _openGroups() async {
    final groupRepository = widget.groupRepository;
    if (groupRepository == null) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => GroupsScreen(
          repository: groupRepository,
          currentUser: widget.currentUser,
          profileRepository: widget.profileRepository,
          messageRepository: widget.repository,
          updateRepository: widget.updateRepository,
        ),
      ),
    );
  }

  Future<void> _openProfile(String username) async {
    await openUserProfile(
      context,
      profileRepository: widget.profileRepository,
      messageRepository: widget.repository,
      updateRepository: widget.updateRepository,
      currentUser: widget.currentUser,
      username: username,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final onlineItems = _allItems
        .where((item) => item.otherUser.isOnline)
        .toList();
    final unreadTotal = _allItems.fold<int>(
      0,
      (sum, item) => sum + item.unreadCount,
    );

    return Scaffold(
      backgroundColor: colors.scaffold,
      appBar: AppBar(
        backgroundColor: colors.surface,
        surfaceTintColor: colors.surface,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Messages',
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              unreadTotal > 0 ? '$unreadTotal unread' : 'Inbox',
              style: TextStyle(
                color: colors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          if (widget.groupRepository != null)
            IconButton(
              tooltip: 'Groups',
              onPressed: _openGroups,
              icon: const HeroIcon(HeroIcons.users),
            ),
        ],
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
                  if (onlineItems.isNotEmpty) ...[
                    Text(
                      'Online Now',
                      style: TextStyle(
                        color: colors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 90,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: onlineItems.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(width: 14),
                        itemBuilder: (context, index) {
                          final item = onlineItems[index];
                          return GestureDetector(
                            onTap: () => _openProfile(item.otherUser.username),
                            child: SizedBox(
                              width: 64,
                              child: Column(
                                children: [
                                  Stack(
                                    children: [
                                      CircleAvatar(
                                        radius: 26,
                                        backgroundImage:
                                            item.otherUser.photoUrl.isNotEmpty
                                            ? NetworkImage(
                                                item.otherUser.photoUrl,
                                              )
                                            : null,
                                        child: item.otherUser.photoUrl.isEmpty
                                            ? const HeroIcon(HeroIcons.user)
                                            : null,
                                      ),
                                      const Positioned(
                                        right: 0,
                                        bottom: 0,
                                        child: CircleAvatar(
                                          radius: 6,
                                          backgroundColor: Colors.green,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    item.otherUser.displayName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: colors.textSecondary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],
                  ..._visibleItems.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _ConversationTile(
                        item: item,
                        onTap: () => _openConversation(item),
                        onProfileTap: () =>
                            _openProfile(item.otherUser.username),
                      ),
                    ),
                  ),
                  if (_isLoadingMore)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                ],
              ),
            ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.item,
    required this.onTap,
    required this.onProfileTap,
  });

  final ConversationListItem item;
  final VoidCallback onTap;
  final VoidCallback onProfileTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Material(
      color: item.unreadCount > 0 ? colors.unreadSurface : colors.surface,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: item.unreadCount > 0 ? colors.borderStrong : colors.border,
            ),
          ),
          child: Row(
            children: [
              Stack(
                children: [
                  InkWell(
                    onTap: onProfileTap,
                    borderRadius: BorderRadius.circular(999),
                    child: CircleAvatar(
                      radius: 27,
                      backgroundImage: item.otherUser.photoUrl.isNotEmpty
                          ? NetworkImage(item.otherUser.photoUrl)
                          : null,
                      child: item.otherUser.photoUrl.isEmpty
                          ? const HeroIcon(HeroIcons.user)
                          : null,
                    ),
                  ),
                  if (item.otherUser.isOnline)
                    const Positioned(
                      right: 0,
                      bottom: 0,
                      child: CircleAvatar(
                        radius: 6,
                        backgroundColor: Colors.green,
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: onProfileTap,
                            borderRadius: BorderRadius.circular(8),
                            child: Text(
                              item.otherUser.displayName,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: 14,
                                fontWeight: item.unreadCount > 0
                                    ? FontWeight.w800
                                    : FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        Text(
                          formatConversationListTimestamp(item.updatedAt),
                          style: TextStyle(
                            color: colors.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.latestMessage?.message.isNotEmpty == true
                          ? item.latestMessage!.message
                          : 'Say hello!',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: item.unreadCount > 0
                            ? colors.textSecondary
                            : colors.textMuted,
                        fontSize: 12.5,
                        fontWeight: item.unreadCount > 0
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.otherUser.isOnline
                          ? 'Online now'
                          : '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textMuted.withValues(alpha: 0.9),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (item.unreadCount > 0) ...[
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: colors.brand,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    item.unreadCount > 9 ? '9+' : '${item.unreadCount}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
