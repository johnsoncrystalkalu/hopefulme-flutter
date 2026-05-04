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
  final List<ConversationListItem> _items = <ConversationListItem>[];
  final List<ConversationListItem> _activeSourceItems =
      <ConversationListItem>[];
  List<ConversationListItem> _activeTodayItems = <ConversationListItem>[];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  Object? _error;
  int _page = 1;
  int _unreadTotal = 0;
  static const int _pageSize = 10;

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
      _isLoadingMore = false;
    });

    try {
      final page = await widget.repository.fetchConversationsPage(
        page: 1,
        perPage: _pageSize,
      );

      List<ConversationListItem> activeSource = page.items;
      try {
        activeSource = await widget.repository.fetchActiveTodayConversations();
      } catch (_) {
        // Fall back to page-1 items if active endpoint fetch fails.
      }

      if (!mounted) {
        return;
      }
      setState(() {
        _items
          ..clear()
          ..addAll(page.items);
        _activeSourceItems
          ..clear()
          ..addAll(activeSource);
        _page = page.currentPage;
        _hasMore = page.hasMore;
        _unreadTotal = page.unreadTotal;
        _recomputeActiveTodayItems();
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error;
        _isLoading = false;
      });
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
      final page = await widget.repository.fetchConversationsPage(
        page: nextPage,
        perPage: _pageSize,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _items.addAll(page.items);
        _page = page.currentPage;
        _hasMore = page.hasMore;
        _unreadTotal = page.unreadTotal;
        _recomputeActiveTodayItems();
        _isLoadingMore = false;
      });
    } catch (_) {
      // Ignore transient pagination failures; users can keep scrolling/retrying.
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 220 &&
        !_isLoadingMore &&
        _hasMore) {
      _loadMore();
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
    if (changed ?? false) {
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

  bool _wasSeenToday(ConversationListItem item) {
    final raw = item.otherUser.lastSeen.trim().toLowerCase();
    if (raw.isEmpty) return false;
    return raw == 'online' || raw.startsWith('today');
  }

  DateTime _activityTimestamp(ConversationListItem item) {
    final raw = item.otherUser.lastSeen.trim().toLowerCase();

    // Try to extract time from "Today at 9:52 am" for better sorting
    if (raw.startsWith('today at ')) {
      final timePart = item.otherUser.lastSeen.trim().substring(
        'Today at '.length,
      );
      final today = DateTime.now();
      final parsed = DateTime.tryParse(
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')} $timePart',
      );
      if (parsed != null) return parsed;
    }

    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  List<ConversationListItem> _buildActiveTodayItems() {
    final users = <ConversationListItem>[];
    final seenUserIds = <int>{};
    final source = _activeSourceItems.isNotEmpty ? _activeSourceItems : _items;
    for (final item in source) {
      final isActiveToday = item.otherUser.isOnline || _wasSeenToday(item);
      if (!isActiveToday) {
        continue;
      }
      if (!seenUserIds.add(item.otherUser.id)) {
        continue;
      }
      users.add(item);
    }
    users.sort((a, b) {
      if (a.otherUser.isOnline != b.otherUser.isOnline) {
        return a.otherUser.isOnline ? -1 : 1;
      }
      return _activityTimestamp(b).compareTo(_activityTimestamp(a));
    });
    return users;
  }

  void _recomputeActiveTodayItems() {
    _activeTodayItems = _buildActiveTodayItems();
  }

  int get _listItemCount => _items.length + (_activeTodayItems.isNotEmpty ? 1 : 0) + (_isLoadingMore ? 1 : 0);

  Widget _buildListItem(BuildContext context, int index) {
    if (_activeTodayItems.isNotEmpty && index == 0) {
      return _ActiveTodaySection(
        items: _activeTodayItems,
        onOpenConversation: _openConversation,
      );
    }

    final headerOffset = _activeTodayItems.isNotEmpty ? 1 : 0;
    final conversationIndex = index - headerOffset;
    if (conversationIndex < _items.length) {
      final item = _items[conversationIndex];
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _ConversationTile(
          item: item,
          onTap: () => _openConversation(item),
        ),
      );
    }

    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Center(child: CircularProgressIndicator()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final unreadTotal = _unreadTotal;

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
          : _items.isEmpty && _activeTodayItems.isEmpty
          ? const AppStatusState(
              title: 'No conversations yet',
              message:
                  'Your inbox is empty for now. Start a conversation to see messages here.',
              icon: Icons.chat_bubble_outline_rounded,
            )
          : RefreshIndicator(
              onRefresh: _loadInitial,
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _listItemCount,
                itemBuilder: _buildListItem,
              ),
            ),
    );
  }
}

class _ActiveTodaySection extends StatelessWidget {
  const _ActiveTodaySection({
    required this.items,
    required this.onOpenConversation,
  });

  final List<ConversationListItem> items;
  final ValueChanged<ConversationListItem> onOpenConversation;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Active Today',
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
              itemCount: items.length,
              separatorBuilder: (context, index) => const SizedBox(width: 14),
              itemBuilder: (context, index) {
                final item = items[index];
                return GestureDetector(
                  onTap: () => onOpenConversation(item),
                  child: SizedBox(
                    width: 64,
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            CircleAvatar(
                              radius: 26,
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
        ],
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.item, required this.onTap});

  final ConversationListItem item;
  final VoidCallback onTap;

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
                  CircleAvatar(
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
                          _ConversationDeliveryStatus(status: latest.status),
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
