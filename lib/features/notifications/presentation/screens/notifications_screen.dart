import 'package:flutter/material.dart';
import 'package:hopefulme_flutter/app/theme/app_theme.dart';
import 'package:hopefulme_flutter/core/widgets/app_status_state.dart';
import 'package:hopefulme_flutter/features/auth/models/user.dart';
import 'package:hopefulme_flutter/features/content/data/content_repository.dart';
import 'package:hopefulme_flutter/features/messages/data/message_repository.dart';
import 'package:hopefulme_flutter/features/notifications/data/notification_repository.dart';
import 'package:hopefulme_flutter/features/notifications/models/app_notification.dart';
import 'package:hopefulme_flutter/features/notifications/presentation/notification_navigation.dart';
import 'package:hopefulme_flutter/features/profile/data/profile_repository.dart';
import 'package:hopefulme_flutter/features/updates/data/update_repository.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({
    required this.repository,
    required this.profileRepository,
    required this.contentRepository,
    required this.messageRepository,
    required this.updateRepository,
    required this.currentUser,
    super.key,
  });

  final NotificationRepository repository;
  final ProfileRepository profileRepository;
  final ContentRepository contentRepository;
  final MessageRepository messageRepository;
  final UpdateRepository updateRepository;
  final User? currentUser;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final List<AppNotification> _items = <AppNotification>[];
  final ScrollController _scrollController = ScrollController();
  late final NotificationNavigator _notificationNavigator;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  int _currentPage = 0;
  int _lastPage = 1;
  int _unreadCount = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _notificationNavigator = NotificationNavigator(
      profileRepository: widget.profileRepository,
      contentRepository: widget.contentRepository,
      messageRepository: widget.messageRepository,
      updateRepository: widget.updateRepository,
      currentUser: widget.currentUser,
    );
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
      final page = await widget.repository.fetchPage(page: 1);
      setState(() {
        _items
          ..clear()
          ..addAll(page.items);
        _currentPage = page.currentPage;
        _lastPage = page.lastPage;
        _unreadCount = page.unreadCount;
      });
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

  Future<void> _loadMore() async {
    if (_isLoadingMore || _currentPage >= _lastPage) {
      return;
    }

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final page = await widget.repository.fetchPage(page: _currentPage + 1);
      setState(() {
        _items.addAll(page.items);
        _currentPage = page.currentPage;
        _lastPage = page.lastPage;
        _unreadCount = page.unreadCount;
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
        _scrollController.position.maxScrollExtent - 220) {
      _loadMore();
    }
  }

  Future<void> _markAllRead() async {
    await widget.repository.markAllRead();
    setState(() {
      _unreadCount = 0;
      for (var index = 0; index < _items.length; index++) {
        final item = _items[index];
        _items[index] = AppNotification(
          id: item.id,
          type: item.type,
          message: item.message,
          preview: item.preview,
          url: item.url,
          contentType: item.contentType,
          contentId: item.contentId,
          inspirationId: item.inspirationId,
          icon: item.icon,
          avatarUrl: item.avatarUrl,
          isRead: true,
          createdAt: item.createdAt,
        );
      }
    });
  }

  Future<void> _markRead(AppNotification item) async {
    if (!item.isRead) {
      await widget.repository.markRead(item.id);
      final index = _items.indexWhere((entry) => entry.id == item.id);
      if (index == -1) {
        return;
      }
      setState(() {
        _items[index] = AppNotification(
          id: item.id,
          type: item.type,
          message: item.message,
          preview: item.preview,
          url: item.url,
          contentType: item.contentType,
          contentId: item.contentId,
          inspirationId: item.inspirationId,
          icon: item.icon,
          avatarUrl: item.avatarUrl,
          isRead: true,
          createdAt: item.createdAt,
        );
        if (_unreadCount > 0) {
          _unreadCount -= 1;
        }
      });
    }

    if (!mounted) {
      return;
    }

    final opened = await _notificationNavigator.open(context, item);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This notification still points to a web-only page.'),
        ),
      );
    }
  }

  Future<void> _handleTap(AppNotification item) async {
    try {
      await _markRead(item);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Scaffold(
      backgroundColor: colors.scaffold,
      appBar: AppBar(
        backgroundColor: colors.surface,
        surfaceTintColor: colors.surface,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Notifications',
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              _unreadCount > 0
                  ? '$_unreadCount unread notifications'
                  : 'You are all caught up',
              style: TextStyle(
                color: colors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          if (_unreadCount > 0)
            TextButton(
              onPressed: _markAllRead,
              child: const Text('Mark all read'),
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
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _items.length + (_isLoadingMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index >= _items.length) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final item = _items[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _NotificationTile(
                      item: item,
                      onTap: () => _handleTap(item),
                    ),
                  );
                },
              ),
            ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.item,
    required this.onTap,
  });

  final AppNotification item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Material(
      color: item.isRead ? colors.surface : colors.unreadSurface,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: item.isRead ? colors.border : colors.borderStrong,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundImage: item.avatarUrl.isNotEmpty
                    ? NetworkImage(item.avatarUrl)
                    : null,
                child: item.avatarUrl.isEmpty ? const Icon(Icons.person) : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.message,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 13.5,
                        height: 1.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (item.preview.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          item.preview,
                          style: TextStyle(
                            color: colors.textMuted,
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Text(
                      item.createdAt,
                      style: TextStyle(
                        color: colors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (!item.isRead)
                Padding(
                  padding: EdgeInsets.only(left: 10, top: 4),
                  child: CircleAvatar(
                    radius: 4,
                    backgroundColor: colors.brand,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
