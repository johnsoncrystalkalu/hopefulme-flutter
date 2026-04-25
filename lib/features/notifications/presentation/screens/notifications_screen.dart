import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hopefulme_flutter/app/theme/app_theme.dart';
import 'package:hopefulme_flutter/core/network/image_url_resolver.dart';
import 'package:hopefulme_flutter/core/utils/time_formatter.dart';
import 'package:hopefulme_flutter/core/widgets/app_status_state.dart';
import 'package:hopefulme_flutter/core/widgets/app_toast.dart';
import 'package:hopefulme_flutter/features/auth/models/user.dart';
import 'package:hopefulme_flutter/features/content/data/content_repository.dart';
import 'package:hopefulme_flutter/features/messages/data/message_repository.dart';
import 'package:hopefulme_flutter/features/notifications/data/notification_repository.dart';
import 'package:hopefulme_flutter/features/notifications/models/app_notification.dart';
import 'package:hopefulme_flutter/features/notifications/presentation/notification_navigation.dart';
import 'package:hopefulme_flutter/features/profile/data/profile_repository.dart';
import 'package:hopefulme_flutter/features/search/data/search_repository.dart';
import 'package:hopefulme_flutter/features/updates/data/update_repository.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({
    required this.repository,
    required this.profileRepository,
    required this.contentRepository,
    required this.messageRepository,
    required this.searchRepository,
    required this.updateRepository,
    required this.currentUser,
    super.key,
  });

  final NotificationRepository repository;
  final ProfileRepository profileRepository;
  final ContentRepository contentRepository;
  final MessageRepository messageRepository;
  final SearchRepository searchRepository;
  final UpdateRepository updateRepository;
  final User? currentUser;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final List<AppNotification> _items = <AppNotification>[];
  final ScrollController _scrollController = ScrollController();
  late final NotificationNavigator _notificationNavigator;
  Timer? _deferredMarkAllReadTimer;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  int _currentPage = 0;
  int _lastPage = 1;
  int _unreadCount = 0;
  bool _didAutoMarkAllRead = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _notificationNavigator = NotificationNavigator(
      profileRepository: widget.profileRepository,
      contentRepository: widget.contentRepository,
      messageRepository: widget.messageRepository,
      searchRepository: widget.searchRepository,
      updateRepository: widget.updateRepository,
      currentUser: widget.currentUser,
    );
    _scrollController.addListener(_onScroll);
    _loadInitial();
  }

  @override
  void dispose() {
    _deferredMarkAllReadTimer?.cancel();
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
      _autoMarkAllReadIfNeeded(pageUnreadCount: page.unreadCount);
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

  void _autoMarkAllReadIfNeeded({required int pageUnreadCount}) {
    if (_didAutoMarkAllRead || pageUnreadCount <= 0 || _items.isEmpty) {
      return;
    }
    _didAutoMarkAllRead = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _deferredMarkAllReadTimer?.cancel();
      _deferredMarkAllReadTimer = Timer(const Duration(milliseconds: 350), () {
        if (!mounted || _isLoading || _items.isEmpty) {
          return;
        }
        unawaited(_markAllRead(silent: true, applyLocalReadState: false));
      });
    });
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

  Future<void> _markAllRead({
    bool silent = false,
    bool applyLocalReadState = true,
  }) async {
    try {
      await widget.repository.markAllRead();
      if (!mounted) {
        return;
      }
      if (!applyLocalReadState) {
        return;
      }
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
    } catch (error) {
      if (!silent && mounted) {
        AppToast.error(context, error);
      }
    }
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
      AppToast.info(context, 'This notification can be viewed on our website.');
    }
  }

  Future<void> _handleTap(AppNotification item) async {
    try {
      await _markRead(item);
    } catch (error) {
      if (!mounted) {
        return;
      }
      AppToast.error(context, error);
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
        title: Text(
          'Notifications',
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          if (_unreadCount > 0)
            TextButton(
              onPressed: () => _markAllRead(),
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
  const _NotificationTile({required this.item, required this.onTap});

  final AppNotification item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: item.isRead ? colors.surface : colors.unreadSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: item.isRead ? colors.border : colors.borderStrong,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundImage: item.avatarUrl.isNotEmpty
                    ? NetworkImage(
                        ImageUrlResolver.avatar(item.avatarUrl, size: 66),
                      )
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
                        fontSize: 13.25,
                        height: 1.45,
                        fontWeight: item.isRead
                            ? FontWeight.w500
                            : FontWeight.w600,
                      ),
                    ),
                    if (item.preview.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        item.preview,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: colors.textMuted, fontSize: 12),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      formatDetailedTimestamp(item.createdAt),
                      style: TextStyle(color: colors.textMuted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              if (!item.isRead)
                Padding(
                  padding: const EdgeInsets.only(left: 10, top: 4),
                  child: CircleAvatar(radius: 4, backgroundColor: colors.brand),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
