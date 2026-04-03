import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';
import 'package:hopefulme_flutter/app/theme/app_theme.dart';
import 'package:hopefulme_flutter/core/network/image_url_resolver.dart';
import 'package:hopefulme_flutter/core/widgets/verified_name_text.dart';
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
  Object? _error;
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
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
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
    if ((changed ?? false) || item.unreadCount > 0) {
      await _loadInitial();
    }
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
                  _InboxHeroCard(
                    unreadTotal: unreadTotal,
                    totalChats: _allItems.length,
                    onlineItems: onlineItems,
                    onOpenConversation: _openConversation,
                  ),
                  const SizedBox(height: 18),
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
                            onTap: () => _openConversation(item),
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
                                                ImageUrlResolver.avatar(
                                                  item.otherUser.photoUrl,
                                                  size: 80,
                                                ),
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
                                  VerifiedNameText(
                                    name: item.otherUser.displayName,
                                    verified: item.otherUser.isVerified,
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
    final latest = item.latestMessage;
    final isSentByMe = latest != null && latest.senderId != item.otherUser.id;
    final showsPhotoOnly =
        latest != null &&
        latest.photoUrl.isNotEmpty &&
        latest.message.trim().isEmpty;

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
                          ? NetworkImage(
                              ImageUrlResolver.avatar(
                                item.otherUser.photoUrl,
                                size: 80,
                              ),
                            )
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
                            child: VerifiedNameText(
                              name: item.otherUser.displayName,
                              verified: item.otherUser.isVerified,
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
                            color: item.unreadCount > 0
                                ? colors.brand
                                : colors.textMuted,
                            fontSize: 11,
                            fontWeight: item.unreadCount > 0
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (isSentByMe) ...[
                          _ConversationDeliveryStatus(
                            status: latest.status,
                          ),
                          const SizedBox(width: 6),
                        ],
                        Expanded(
                          child: Text(
                            showsPhotoOnly
                                ? 'Photo'
                                : latest?.message.isNotEmpty == true
                                ? latest!.message
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
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.otherUser.isOnline ? 'Online now' : '',
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

class _InboxHeroCard extends StatelessWidget {
  const _InboxHeroCard({
    required this.unreadTotal,
    required this.totalChats,
    required this.onlineItems,
    required this.onOpenConversation,
  });

  final int unreadTotal;
  final int totalChats;
  final List<ConversationListItem> onlineItems;
  final Future<void> Function(ConversationListItem item) onOpenConversation;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF171E34), Color(0xFF3D5AFE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Inbox',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.6,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Messages',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  unreadTotal > 0
                      ? '$unreadTotal unread · $totalChats chats'
                      : '$totalChats chats',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (onlineItems.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                SizedBox(
                  width: 96,
                  height: 36,
                  child: Stack(
                    children: [
                      for (var i = 0; i < onlineItems.take(3).length; i++)
                        Positioned(
                          right: i * 22,
                          child: GestureDetector(
                            onTap: () => onOpenConversation(onlineItems[i]),
                            child: CircleAvatar(
                              radius: 18,
                              backgroundColor: colors.surface,
                              backgroundImage:
                                  onlineItems[i].otherUser.photoUrl.isNotEmpty
                                  ? NetworkImage(
                                      ImageUrlResolver.avatar(
                                        onlineItems[i].otherUser.photoUrl,
                                        size: 64,
                                      ),
                                    )
                                  : null,
                              child: onlineItems[i].otherUser.photoUrl.isEmpty
                                  ? const HeroIcon(HeroIcons.user, size: 16)
                                  : null,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${onlineItems.length} online now',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.66),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ConversationDeliveryStatus extends StatelessWidget {
  const _ConversationDeliveryStatus({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isRead = status.trim().toLowerCase() == 'read';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.done_rounded,
          size: 14,
          color: isRead ? colors.brand : colors.textMuted,
        ),
        if (isRead)
          Transform.translate(
            offset: const Offset(-4, 0),
            child: Icon(Icons.done_rounded, size: 14, color: colors.brand),
          ),
      ],
    );
  }
}
