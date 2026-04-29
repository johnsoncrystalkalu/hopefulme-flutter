// ignore_for_file: unused_element, unused_element_parameter

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:heroicons/heroicons.dart';
//import 'package:flutter/cupertino.dart';

import 'package:hopefulme_flutter/app/theme/app_theme.dart';
import 'package:hopefulme_flutter/app/theme/theme_controller.dart';
import 'package:hopefulme_flutter/core/utils/time_formatter.dart';
import 'package:hopefulme_flutter/core/config/app_config.dart';
import 'package:hopefulme_flutter/core/navigation/app_deep_link_navigator.dart';
import 'package:hopefulme_flutter/core/navigation/app_route_observer.dart';
import 'package:hopefulme_flutter/core/presentation/screens/web_page_screen.dart';
import 'package:hopefulme_flutter/core/widgets/app_avatar.dart';
import 'package:hopefulme_flutter/core/network/image_url_resolver.dart';
import 'package:hopefulme_flutter/core/widgets/verified_name_text.dart';
import 'package:hopefulme_flutter/core/widgets/app_network_image.dart';
import 'package:hopefulme_flutter/core/widgets/app_toast.dart';
import 'package:hopefulme_flutter/core/widgets/rich_display_text.dart';
import 'package:hopefulme_flutter/core/widgets/shimmer_widget.dart';
import 'package:hopefulme_flutter/features/auth/models/user.dart';
import 'package:hopefulme_flutter/features/auth/presentation/controllers/auth_controller.dart';
import 'package:hopefulme_flutter/features/community/presentation/screens/meet_new_friends_screen.dart';
import 'package:hopefulme_flutter/features/community/presentation/widgets/most_active_users_card.dart';
import 'package:hopefulme_flutter/features/content/data/content_repository.dart';
import 'package:hopefulme_flutter/features/content/presentation/content_navigation.dart';
import 'package:hopefulme_flutter/features/content/presentation/screens/blogs_feed_screen.dart';
import 'package:hopefulme_flutter/features/content/presentation/screens/inspiration_inbox_screen.dart';
import 'package:hopefulme_flutter/features/content/presentation/screens/posts_feed_screen.dart';
import 'package:hopefulme_flutter/features/feed/data/feed_repository.dart';
import 'package:hopefulme_flutter/features/feed/models/feed_dashboard.dart';
import 'package:hopefulme_flutter/features/feed/presentation/widgets/feed_special_cards.dart';
import 'package:hopefulme_flutter/features/feed/presentation/screens/settings_screen.dart';
import 'package:hopefulme_flutter/features/feed/presentation/screens/today_birthdays_screen.dart';
import 'package:hopefulme_flutter/features/groups/data/group_repository.dart';
import 'package:hopefulme_flutter/features/groups/models/group_models.dart';
import 'package:hopefulme_flutter/features/groups/presentation/screens/group_thread_screen.dart';
import 'package:hopefulme_flutter/features/groups/presentation/screens/groups_screen.dart';
import 'package:hopefulme_flutter/features/messages/data/message_repository.dart';
import 'package:hopefulme_flutter/features/messages/models/conversation_models.dart';
import 'package:hopefulme_flutter/features/messages/presentation/screens/message_thread_screen.dart';
import 'package:hopefulme_flutter/features/messages/presentation/screens/messages_screen.dart';
import 'package:hopefulme_flutter/features/notifications/data/notification_repository.dart';
import 'package:hopefulme_flutter/features/notifications/models/app_notification.dart';
import 'package:hopefulme_flutter/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:hopefulme_flutter/features/profile/data/profile_repository.dart';
import 'package:hopefulme_flutter/features/profile/presentation/profile_navigation.dart';
import 'package:hopefulme_flutter/features/profile/presentation/screens/edit_profile_media_screen.dart';
import 'package:hopefulme_flutter/features/search/data/search_repository.dart';
import 'package:hopefulme_flutter/features/search/presentation/screens/search_screen.dart';
import 'package:hopefulme_flutter/features/updates/data/update_repository.dart';
import 'package:hopefulme_flutter/features/updates/models/update_detail.dart';
import 'package:hopefulme_flutter/features/updates/presentation/screens/update_detail_screen.dart';
import 'package:hopefulme_flutter/features/updates/presentation/screens/updates_feed_screen.dart';
import 'package:hopefulme_flutter/features/updates/presentation/widgets/update_submission_modal.dart';
import 'package:hopefulme_flutter/features/updates/presentation/widgets/interactive_update_card.dart';
import 'package:hopefulme_flutter/features/library/data/library_repository.dart';
import 'package:hopefulme_flutter/features/library/presentation/screens/library_screen.dart';
import 'package:hopefulme_flutter/features/templates/data/flyer_template_repository.dart';
import 'package:hopefulme_flutter/features/templates/presentation/screens/flyer_templates_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

bool _looksLikeDefaultProfilePhoto(String photoUrl) {
  final trimmed = photoUrl.trim();
  if (trimmed.isEmpty) {
    return true;
  }

  final normalized = trimmed.toLowerCase();
  return trimmed.length < 32 ||
      normalized.contains('default') ||
      (normalized.contains('avatar') &&
          (normalized.contains('male') || normalized.contains('female')));
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    required this.authController,
    required this.themeController,
    required this.feedRepository,
    required this.contentRepository,
    required this.notificationRepository,
    required this.messageRepository,
    required this.groupRepository,
    required this.profileRepository,
    required this.searchRepository,
    required this.updateRepository,
    required this.libraryRepository,
    required this.flyerTemplateRepository,
    required this.onCheckForUpdates,
    super.key,
  });

  static const routeName = '/home';

  final AuthController authController;
  final ThemeController themeController;
  final FeedRepository feedRepository;
  final ContentRepository contentRepository;
  final NotificationRepository notificationRepository;
  final MessageRepository messageRepository;
  final GroupRepository groupRepository;
  final ProfileRepository profileRepository;
  final SearchRepository searchRepository;
  final UpdateRepository updateRepository;
  final LibraryRepository libraryRepository;
  final FlyerTemplateRepository flyerTemplateRepository;
  final Future<void> Function() onCheckForUpdates;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with WidgetsBindingObserver, RouteAware {
  static const _inAppNotificationsPrefKey = 'in_app_notifications_enabled';
  static const _topbarRefreshInterval = Duration(seconds: 60);
  static const _maxHomeUpdatesRetained = 30;
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final ScrollController _homeScrollController = ScrollController();
  final ValueNotifier<_TopBarSnapshot> _topBarSnapshot = ValueNotifier(
    const _TopBarSnapshot(),
  );
  late Future<FeedDashboard> _dashboardFuture;
  late Future<List<AppGroup>> _homeGroupsPreviewFuture;
  late final String _webBaseUrl;
  Timer? _pollingTimer;
  int _selectedBottomNav = 0;
  bool _inAppNotificationsEnabled = true;
  List<FeedEntry> _homeUpdates = const <FeedEntry>[];
  bool _isLoadingMoreHomeUpdates = false;
  bool _hasLoadMoreHomeUpdatesError = false;
  bool _hasMoreHomeUpdates = true;
  int _homeUpdatesPage = 1;
  bool _homePaginationInFlight = false;
  double _lastHomePaginationTriggerPixels = -1;
  bool _isTopbarRefreshInFlight = false;
  int? _highlightedUpdateId;
  Timer? _highlightedUpdateTimer;
  String _activeSidebarItemLabel = 'Home';
  AppLifecycleState? _appLifecycleState;
  ModalRoute<dynamic>? _subscribedRoute;
  bool _isHomeRouteVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _homeScrollController.addListener(_handleHomeScroll);
    _dashboardFuture = _createDashboardFuture();
    _homeGroupsPreviewFuture = _createHomeGroupsPreviewFuture();
    _webBaseUrl = AppConfig.fromEnvironment().webBaseUrl;
    _loadShellPreferences();
    _refreshTopbarData();
    _refreshUnreadGroups();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route == null || route == _subscribedRoute) {
      return;
    }
    if (_subscribedRoute is PageRoute<dynamic>) {
      appRouteObserver.unsubscribe(this);
    }
    _subscribedRoute = route;
    if (route is PageRoute<dynamic>) {
      appRouteObserver.subscribe(this, route);
      _isHomeRouteVisible = route.isCurrent;
      _syncTopbarPolling();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_subscribedRoute is PageRoute<dynamic>) {
      appRouteObserver.unsubscribe(this);
    }
    _stopTopbarPolling();
    _highlightedUpdateTimer?.cancel();
    _pollingTimer?.cancel();
    _homeScrollController.dispose();
    _topBarSnapshot.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appLifecycleState = state;
    _syncTopbarPolling();
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshTopbarData(silent: true));
    }
  }

  @override
  void didPush() {
    _isHomeRouteVisible = true;
    _syncTopbarPolling();
  }

  @override
  void didPopNext() {
    _isHomeRouteVisible = true;
    _syncTopbarPolling();
    unawaited(_refreshTopbarData(silent: true));
  }

  @override
  void didPushNext() {
    _isHomeRouteVisible = false;
    _syncTopbarPolling();
  }

  @override
  void didPop() {
    _isHomeRouteVisible = false;
    _syncTopbarPolling();
  }

  bool get _isAppInForeground =>
      _appLifecycleState == null ||
      _appLifecycleState == AppLifecycleState.resumed;

  bool get _shouldPollTopbar => _isHomeRouteVisible && _isAppInForeground;

  void _syncTopbarPolling() {
    if (_shouldPollTopbar) {
      _startTopbarPolling();
      return;
    }
    _stopTopbarPolling();
  }

  void _startTopbarPolling() {
    if (!_shouldPollTopbar) {
      return;
    }
    if (_pollingTimer != null) {
      return;
    }
    _pollingTimer = Timer.periodic(
      _topbarRefreshInterval,
      (_) => unawaited(_refreshTopbarData(silent: true)),
    );
  }

  void _stopTopbarPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  Future<FeedDashboard> _createDashboardFuture() {
    final future = widget.feedRepository.fetchDashboard();
    future.then(_seedHomeUpdatesFromDashboard).catchError((_) {});
    return future;
  }

  Future<List<AppGroup>> _createHomeGroupsPreviewFuture() async {
    try {
      final page = await widget.groupRepository.fetchGroups(page: 1);
      return _buildHomeGroupsPreview(page.items);
    } catch (_) {
      return const <AppGroup>[];
    }
  }

  Future<void> _refreshDashboard() async {
    setState(() {
      _homeUpdatesPage = 1;
      _hasMoreHomeUpdates = true;
      _hasLoadMoreHomeUpdatesError = false;
      _isLoadingMoreHomeUpdates = false;
      _dashboardFuture = _createDashboardFuture();
    });

    await _dashboardFuture;
  }

  void _seedHomeUpdatesFromDashboard(FeedDashboard dashboard) {
    final updates = dashboard.feed
        .where((entry) => entry.type == 'update' || entry.type == 'advert')
        .take(_maxHomeUpdatesRetained)
        .toList(growable: false);
    if (!mounted) {
      _homeUpdates = updates;
      _homeUpdatesPage = 1;
      _hasMoreHomeUpdates = true;
      _hasLoadMoreHomeUpdatesError = false;
      _isLoadingMoreHomeUpdates = false;
      return;
    }
    setState(() {
      _homeUpdates = updates;
      _homeUpdatesPage = 1;
      _hasMoreHomeUpdates = true;
      _isLoadingMoreHomeUpdates = false;
    });
  }

  void _handleHomeScroll() {
    if (!_homeScrollController.hasClients ||
        _homePaginationInFlight ||
        _hasLoadMoreHomeUpdatesError ||
        _isLoadingMoreHomeUpdates ||
        !_hasMoreHomeUpdates) {
      return;
    }
    final position = _homeScrollController.position;
    if (position.extentAfter <= 320) {
      final delta = (position.pixels - _lastHomePaginationTriggerPixels).abs();
      if (delta < 80) {
        return;
      }
      _lastHomePaginationTriggerPixels = position.pixels;
      _homePaginationInFlight = true;
      unawaited(
        _loadMoreHomeUpdates().whenComplete(() {
          _homePaginationInFlight = false;
        }),
      );
    }
  }

  Future<void> _loadMoreHomeUpdates() async {
    if (_isLoadingMoreHomeUpdates || !_hasMoreHomeUpdates) {
      return;
    }

    setState(() {
      _isLoadingMoreHomeUpdates = true;
      _hasLoadMoreHomeUpdatesError = false;
    });

    var nextHomeUpdatesPage = _homeUpdatesPage;
    var nextHasMoreHomeUpdates = _hasMoreHomeUpdates;
    var nextHomeUpdates = _homeUpdates;
    var nextHasLoadMoreError = false;

    try {
      final nextPage = _homeUpdatesPage + 1;
      final page = await widget.feedRepository.fetchUpdatesPage(page: nextPage);
      if (!mounted) {
        return;
      }

      nextHomeUpdatesPage = page.currentPage;
      nextHasMoreHomeUpdates = page.hasMore;
      nextHomeUpdates = _mergeFeedEntries(_homeUpdates, page.items);
    } catch (_) {
      nextHasLoadMoreError = true;
    } finally {
      if (mounted) {
        setState(() {
          _homeUpdatesPage = nextHomeUpdatesPage;
          _hasMoreHomeUpdates = nextHasMoreHomeUpdates;
          _hasLoadMoreHomeUpdatesError = nextHasLoadMoreError;
          _homeUpdates = nextHomeUpdates;
          _isLoadingMoreHomeUpdates = false;
        });
      }
    }
  }

  Future<void> _retryLoadMoreHomeUpdates() => _loadMoreHomeUpdates();

  void _highlightPostedUpdate(int updateId) {
    _highlightedUpdateTimer?.cancel();
    setState(() {
      _highlightedUpdateId = updateId;
    });
    _highlightedUpdateTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted) {
        return;
      }
      setState(() {
        if (_highlightedUpdateId == updateId) {
          _highlightedUpdateId = null;
        }
      });
    });
  }

  Future<void> _openUpdateDetailById(int updateId) async {
    final result = await Navigator.of(context).push<UpdateDetailResult>(
      MaterialPageRoute<UpdateDetailResult>(
        builder: (context) => UpdateDetailScreen(
          updateId: updateId,
          currentUser: widget.authController.currentUser,
          repository: widget.updateRepository,
          contentRepository: widget.contentRepository,
          profileRepository: widget.profileRepository,
          messageRepository: widget.messageRepository,
          searchRepository: widget.searchRepository,
        ),
      ),
    );
    if (result?.shouldRefresh == true) {
      await _refreshDashboard();
    }
  }

  List<FeedEntry> _mergeFeedEntries(
    List<FeedEntry> existing,
    List<FeedEntry> next,
  ) {
    final merged = <FeedEntry>[...existing];
    final seenIds = merged
        .map((entry) => '${entry.type}:${entry.id}')
        .toSet();
    for (final entry in next) {
      if (seenIds.add('${entry.type}:${entry.id}')) {
        merged.add(entry);
      }
    }
    return List<FeedEntry>.unmodifiable(merged);
  }

  Future<void> _refreshTopbarData({bool silent = false}) async {
    if (_isTopbarRefreshInFlight) {
      return;
    }
    _isTopbarRefreshInFlight = true;

    try {
      final results = await Future.wait<_TopbarFetchResult>([
        (() async {
          try {
            final notifications = await widget.notificationRepository.fetchPage(
              page: 1,
            );
            return _TopbarFetchResult.notifications(
              _inAppNotificationsEnabled ? notifications.unreadCount : 0,
            );
          } catch (error) {
            return _TopbarFetchResult.notificationError(error);
          }
        })(),
        (() async {
          try {
            final conversations = await widget.messageRepository
                .fetchConversations();
            final unreadMessages = conversations.fold<int>(
              0,
              (sum, item) => sum + item.unreadCount,
            );
            return _TopbarFetchResult.messages(unreadMessages);
          } catch (error) {
            return _TopbarFetchResult.messageError(error);
          }
        })(),
      ]);

      if (!mounted) {
        return;
      }

      final notificationResult = results[0];
      final messageResult = results[1];
      final notificationsError = notificationResult.error;
      final conversationsError = messageResult.error;
      final unreadNotifications = notificationResult.unreadNotifications;
      final unreadMessages = messageResult.unreadMessages;

      if (notificationsError != null && conversationsError != null) {
        if (!silent) {
          throw conversationsError;
        }
        return;
      }

      final nextSnapshot = _TopBarSnapshot(
        unreadNotifications:
            unreadNotifications ?? _topBarSnapshot.value.unreadNotifications,
        unreadMessages: unreadMessages ?? _topBarSnapshot.value.unreadMessages,
        unreadGroups: _topBarSnapshot.value.unreadGroups,
      );

      if (_topBarSnapshot.value != nextSnapshot) {
        _topBarSnapshot.value = nextSnapshot;
      }
    } finally {
      _isTopbarRefreshInFlight = false;
    }
  }

  Future<void> _refreshUnreadGroups({bool silent = false}) async {
    try {
      final groups = await widget.groupRepository.fetchGroups(page: 1);
      if (!mounted) {
        return;
      }
      final unreadGroups = groups.items.fold<int>(
        0,
        (sum, item) => sum + item.unreadCount,
      );
      final current = _topBarSnapshot.value;
      final next = current.copyWith(unreadGroups: unreadGroups);
      if (current != next) {
        _topBarSnapshot.value = next;
      }
    } catch (error) {
      if (!silent && mounted) {
        AppToast.error(context, error);
      }
    }
  }

  Future<void> _loadShellPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_inAppNotificationsPrefKey) ?? true;
    if (!mounted) {
      return;
    }
    if (_inAppNotificationsEnabled == enabled) {
      return;
    }
    setState(() {
      _inAppNotificationsEnabled = enabled;
    });
  }

  Future<void> _setInAppNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_inAppNotificationsPrefKey, enabled);
    if (!mounted) {
      return;
    }
    if (_inAppNotificationsEnabled == enabled) {
      return;
    }
    setState(() {
      _inAppNotificationsEnabled = enabled;
    });
    if (!enabled) {
      _topBarSnapshot.value = _topBarSnapshot.value.copyWith(
        unreadNotifications: 0,
      );
    }
    if (enabled) {
      await _refreshTopbarData(silent: true);
      if (mounted) {
        AppToast.success(context, 'In-app notifications enabled.');
      }
    } else {
      AppToast.info(context, 'In-app notifications muted.');
    }
  }

  Future<void> _openProfile() async {
    _setActiveSidebarItem('Profile');
    await openUserProfile(
      context,
      profileRepository: widget.profileRepository,
      messageRepository: widget.messageRepository,
      updateRepository: widget.updateRepository,
      currentUser: widget.authController.currentUser,
      username: widget.authController.currentUser?.username ?? '',
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedBottomNav = 0;
    });
  }

  Future<void> _goHome() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _activeSidebarItemLabel = 'Home';
      _selectedBottomNav = 0;
      _homeUpdates = const <FeedEntry>[];
      _homeUpdatesPage = 1;
      _hasMoreHomeUpdates = true;
      _hasLoadMoreHomeUpdatesError = false;
      _isLoadingMoreHomeUpdates = false;
      _dashboardFuture = _createDashboardFuture();
      _homeGroupsPreviewFuture = _createHomeGroupsPreviewFuture();
    });
  }

  Future<void> _openNotifications() async {
    if (!mounted) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => NotificationsScreen(
          repository: widget.notificationRepository,
          profileRepository: widget.profileRepository,
          contentRepository: widget.contentRepository,
          messageRepository: widget.messageRepository,
          searchRepository: widget.searchRepository,
          updateRepository: widget.updateRepository,
          currentUser: widget.authController.currentUser,
        ),
      ),
    );
    await _refreshTopbarData(silent: true);
  }

  Future<void> _openMessages() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => MessagesScreen(
          repository: widget.messageRepository,
          profileRepository: widget.profileRepository,
          updateRepository: widget.updateRepository,
          groupRepository: widget.groupRepository,
          currentUser: widget.authController.currentUser,
        ),
      ),
    );
    await _refreshTopbarData(silent: true);
  }

  Future<void> _openGroups() async {
    _setActiveSidebarItem('Group Chats');
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => GroupsScreen(
          repository: widget.groupRepository,
          currentUser: widget.authController.currentUser,
          profileRepository: widget.profileRepository,
          messageRepository: widget.messageRepository,
          updateRepository: widget.updateRepository,
        ),
      ),
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _activeSidebarItemLabel = 'Home';
      _selectedBottomNav = 0;
    });
  }

  Future<void> _openGroupPreview(AppGroup group) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (context) => GroupThreadScreen(
          groupId: group.id,
          currentUser: widget.authController.currentUser,
          repository: widget.groupRepository,
          profileRepository: widget.profileRepository,
          messageRepository: widget.messageRepository,
          updateRepository: widget.updateRepository,
        ),
      ),
    );

    if (changed ?? false) {
      await _refreshUnreadGroups(silent: true);
    }
  }

  Future<void> _openConversation(ConversationListItem item) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => MessageThreadScreen(
          repository: widget.messageRepository,
          profileRepository: widget.profileRepository,
          updateRepository: widget.updateRepository,
          currentUser: widget.authController.currentUser,
          username: item.otherUser.username,
          title: item.otherUser.displayName,
        ),
      ),
    );
    await _refreshUnreadGroups(silent: true);
  }

  Future<void> _openSettings() async {
    final username = widget.authController.currentUser?.username ?? '';
    if (username.trim().isEmpty) {
      AppToast.error(context, 'Unable to open settings right now.');
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => SettingsScreen(
          username: username,
          isVerified: widget.authController.currentUser?.isVerified ?? false,
          currentUser: widget.authController.currentUser,
          authRepository: widget.authController.authRepository,
          profileRepository: widget.profileRepository,
          themeController: widget.themeController,
          onLogout: _handleLogout,
          onCheckForUpdates: widget.onCheckForUpdates,
          onInternalLinkTap: (uri) async {
            if (!context.mounted) {
              return false;
            }
            final navigator = AppDeepLinkNavigator(
              feedRepository: widget.feedRepository,
              contentRepository: widget.contentRepository,
              profileRepository: widget.profileRepository,
              messageRepository: widget.messageRepository,
              groupRepository: widget.groupRepository,
              updateRepository: widget.updateRepository,
              searchRepository: widget.searchRepository,
              libraryRepository: widget.libraryRepository,
              flyerTemplateRepository: widget.flyerTemplateRepository,
              currentUser: widget.authController.currentUser,
              webBaseUrl: _webBaseUrl,
              signWebUrl:
                  widget.authController.authRepository.createWebSessionUrl,
            );
            return navigator.open(context, uri);
          },
        ),
      ),
    );
  }

  Future<void> _openEditMedia() async {
    final username = widget.authController.currentUser?.username ?? '';
    if (username.trim().isEmpty) {
      AppToast.error(context, 'Unable to open photo upload right now.');
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => EditProfileMediaScreen(
          username: username,
          repository: widget.profileRepository,
        ),
      ),
    );
  }

  Future<void> _handleLinkTap(String url) async {
    String processedUrl = url.trim();
    if (!processedUrl.startsWith('http://') &&
        !processedUrl.startsWith('https://')) {
      processedUrl = 'https://$processedUrl';
    }
    final uri = Uri.tryParse(processedUrl);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.platformDefault);
    }
  }

  Future<void> _openUserProfile(String username) async {
    await openUserProfile(
      context,
      profileRepository: widget.profileRepository,
      messageRepository: widget.messageRepository,
      updateRepository: widget.updateRepository,
      currentUser: widget.authController.currentUser,
      username: username,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedBottomNav = 0;
    });
  }

  Future<void> _openUpdateDetail(
    FeedEntry entry, {
    bool autofocusComment = false,
  }) async {
    final result = await Navigator.of(context).push<UpdateDetailResult>(
      MaterialPageRoute<UpdateDetailResult>(
        builder: (context) => UpdateDetailScreen(
          updateId: entry.id,
          initialDetail: UpdateDetail(
            id: entry.id,
            type: entry.updateType,
            status: entry.body,
            photoUrl: entry.photoUrl,
            originalPhotoUrl: entry.originalPhotoUrl,
            device: entry.device,
            views: entry.views,
            likesCount: entry.likesCount,
            commentsCount: entry.commentsCount,
            createdAt: entry.createdAt,
            user: entry.user!,
            comments: const [],
            isLiked: entry.isLiked,
            myReaction: entry.myReaction,
            reactionsPreview: entry.reactionsPreview,
          ),
          currentUser: widget.authController.currentUser,
          repository: widget.updateRepository,
          contentRepository: widget.contentRepository,
          profileRepository: widget.profileRepository,
          messageRepository: widget.messageRepository,
          searchRepository: widget.searchRepository,
          autofocusComment: autofocusComment,
        ),
      ),
    );
    if (result?.shouldRefresh == true) {
      await _refreshDashboard();
    }
  }

  Future<void> _openPostDetail(FeedEntry entry) async {
    await openPostDetail(
      context,
      contentRepository: widget.contentRepository,
      profileRepository: widget.profileRepository,
      messageRepository: widget.messageRepository,
      searchRepository: widget.searchRepository,
      updateRepository: widget.updateRepository,
      postId: entry.id,
      currentUsername: widget.authController.currentUser?.username,
    );
  }

  Future<void> _openBlogDetail(FeedEntry entry) async {
    await openBlogDetail(
      context,
      contentRepository: widget.contentRepository,
      profileRepository: widget.profileRepository,
      messageRepository: widget.messageRepository,
      searchRepository: widget.searchRepository,
      updateRepository: widget.updateRepository,
      blogId: entry.id,
      currentUsername: widget.authController.currentUser?.username,
    );
  }

  Future<void> _openSearch() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => SearchScreen(
          repository: widget.searchRepository,
          contentRepository: widget.contentRepository,
          messageRepository: widget.messageRepository,
          profileRepository: widget.profileRepository,
          updateRepository: widget.updateRepository,
          currentUser: widget.authController.currentUser,
        ),
      ),
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedBottomNav = 0;
    });
  }

  Future<void> _openSearchQuery(String query) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => SearchScreen(
          repository: widget.searchRepository,
          contentRepository: widget.contentRepository,
          messageRepository: widget.messageRepository,
          profileRepository: widget.profileRepository,
          updateRepository: widget.updateRepository,
          currentUser: widget.authController.currentUser,
          initialQuery: query,
        ),
      ),
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedBottomNav = 0;
    });
  }

  Future<void> _openActivities() async {
    _setActiveSidebarItem('Activities');
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => UpdatesFeedScreen(
          feedRepository: widget.feedRepository,
          contentRepository: widget.contentRepository,
          updateRepository: widget.updateRepository,
          profileRepository: widget.profileRepository,
          messageRepository: widget.messageRepository,
          searchRepository: widget.searchRepository,
          currentUser: widget.authController.currentUser,
        ),
      ),
    );
  }

  Future<void> _openPostsFeed({String initialCategory = 'All'}) async {
    _setActiveSidebarItem('Post & News');
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => PostsFeedScreen(
          feedRepository: widget.feedRepository,
          contentRepository: widget.contentRepository,
          profileRepository: widget.profileRepository,
          messageRepository: widget.messageRepository,
          updateRepository: widget.updateRepository,
          searchRepository: widget.searchRepository,
          currentUser: widget.authController.currentUser,
          currentUsername: widget.authController.currentUser?.username,
          initialCategory: initialCategory,
        ),
      ),
    );
  }

  Future<void> _openPostById(int postId) {
    return openPostDetail(
      context,
      contentRepository: widget.contentRepository,
      profileRepository: widget.profileRepository,
      messageRepository: widget.messageRepository,
      searchRepository: widget.searchRepository,
      updateRepository: widget.updateRepository,
      postId: postId,
      currentUsername: widget.authController.currentUser?.username,
    );
  }

  Future<void> _openQuotePreview(QuoteCard quote) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => _QuoteFullscreenViewer(
          quote: quote,
          onViewPost: () => _openPostById(quote.id),
        ),
        fullscreenDialog: true,
      ),
    );
  }

  Future<void> _openBlogsFeed() async {
    _setActiveSidebarItem('Blog');
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => BlogsFeedScreen(
          feedRepository: widget.feedRepository,
          contentRepository: widget.contentRepository,
          profileRepository: widget.profileRepository,
          messageRepository: widget.messageRepository,
          updateRepository: widget.updateRepository,
          searchRepository: widget.searchRepository,
          currentUsername: widget.authController.currentUser?.username,
        ),
      ),
    );
  }

  Future<void> _openInspirations() async {
    _setActiveSidebarItem('Inspiration Inbox');
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => InspirationInboxScreen(
          repository: widget.contentRepository,
          profileRepository: widget.profileRepository,
          messageRepository: widget.messageRepository,
          updateRepository: widget.updateRepository,
          currentUser: widget.authController.currentUser,
        ),
      ),
    );
  }

  Future<void> _openLibrary() async {
    _setActiveSidebarItem('Library');
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) =>
            LibraryScreen(repository: widget.libraryRepository),
      ),
    );
  }

  Future<void> _openFlyerTemplates() async {
    _setActiveSidebarItem('Flyer Templates');
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => FlyerTemplatesScreen(
          repository: widget.flyerTemplateRepository,
          webBaseUrl: _webBaseUrl,
        ),
      ),
    );
    await widget.authController.refreshCurrentUser();
  }

  Future<void> _openWebPage(String title, String path) async {
    _setActiveSidebarItem(title);
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    var targetUrl = '$_webBaseUrl$normalizedPath';

    try {
      final bridgedUrl = await widget.authController.authRepository
          .createWebSessionUrl(targetUrl);
      if (bridgedUrl.trim().isNotEmpty) {
        targetUrl = bridgedUrl.trim();
      }
    } catch (_) {
      // Fall back to the direct web URL if the bridge request fails.
    }

    if (!mounted) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => WebPageScreen(
          title: title,
          url: targetUrl,
          onInternalLinkTap: (uri) async {
            if (!WebPageScreen.shouldUseNativeRouting(
              uri,
              originUrl: _webBaseUrl,
            )) {
              return false;
            }
            if (!context.mounted) {
              return false;
            }
            final navigator = AppDeepLinkNavigator(
              feedRepository: widget.feedRepository,
              contentRepository: widget.contentRepository,
              profileRepository: widget.profileRepository,
              messageRepository: widget.messageRepository,
              groupRepository: widget.groupRepository,
              updateRepository: widget.updateRepository,
              searchRepository: widget.searchRepository,
              libraryRepository: widget.libraryRepository,
              flyerTemplateRepository: widget.flyerTemplateRepository,
              currentUser: widget.authController.currentUser,
              webBaseUrl: _webBaseUrl,
              signWebUrl:
                  widget.authController.authRepository.createWebSessionUrl,
            );
            return navigator.open(context, uri);
          },
        ),
      ),
    );
  }

  Future<void> _openStorePage() => _openWebPage('Marketplace', '/store/home');

  Future<void> _openGamesPage() => _openWebPage('Games & Contests', '/games');

  Future<void> _openAdvertisePage() =>
      _openWebPage('Advert & Partnership', '/adverts');

  Future<void> _openVolunteerPage() =>
      _openWebPage('Volunteer & Support', '/volunteer');

  Future<void> _openTvPage() => _openWebPage('HopefulMe TV', '/tv');

  Future<void> _openOutreachPage() => _openWebPage('Outreach', '/outreach');

  Future<void> _openOtherMenusPage() =>
      _openWebPage('More Features', '/more-menu');

  Future<void> _openAdminPage() => _openWebPage('Admin', '/admin');

  Future<void> _openPrivacyPolicyPage() =>
      _openWebPage('Privacy Policy', '/privacy');

  Future<void> _openTermsPage() => _openWebPage('Terms', '/terms');

  Future<void> _openMeetNewFriends() async {
    _setActiveSidebarItem('Meet New Friends');
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => MeetNewFriendsScreen(
          feedRepository: widget.feedRepository,
          profileRepository: widget.profileRepository,
          messageRepository: widget.messageRepository,
          updateRepository: widget.updateRepository,
          currentUser: widget.authController.currentUser,
        ),
      ),
    );
  }

  Future<void> _openTodayBirthdays(List<FeedUser> users) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => TodayBirthdaysScreen(
          feedRepository: widget.feedRepository,
          initialUsers: users,
          profileRepository: widget.profileRepository,
          messageRepository: widget.messageRepository,
          updateRepository: widget.updateRepository,
          currentUser: widget.authController.currentUser,
        ),
      ),
    );
  }

  Future<void> _openCreateUpdate() async {
    final createdUpdate = await UpdateSubmissionModal.show(
      context,
      updateRepository: widget.updateRepository,
      currentUser: widget.authController.currentUser,
    );

    if (createdUpdate is UpdateDetail) {
      try {
        await _refreshDashboard();
      } catch (_) {
        // Ignore refresh failures to avoid crash; user already knows post succeed.
      }

      if (!mounted) {
        return;
      }
      _highlightPostedUpdate(createdUpdate.id);
      if (_homeScrollController.hasClients) {
        unawaited(
          _homeScrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOut,
          ),
        );
      }
      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Update posted'),
          duration: const Duration(seconds: 4),
          dismissDirection: DismissDirection.horizontal,
          showCloseIcon: true,
          action: SnackBarAction(
            label: 'View',
            onPressed: () {
              unawaited(_openUpdateDetailById(createdUpdate.id));
            },
          ),
        ),
      );
    }
  }

  String _friendlyComposerError(Object error) {
    final message = error.toString();
    if (message.contains('Asset') || message.contains('asset')) {
      return 'Photo upload failed. Please try a smaller image or restart the app.';
    }
    if (message.length > 180) {
      return 'Unable to post that update right now.';
    }
    return message;
  }

  Future<bool> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You will need to sign in again to continue.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) {
      return false;
    }

    try {
      // Avoid trapping the user behind a slow/broken backend logout.
      await widget.authController.logout().timeout(const Duration(seconds: 8));
    } on TimeoutException {
      await widget.authController.forceLocalLogout();
      if (mounted) {
        AppToast.info(context, 'Network timeout. You were signed out locally.');
      }
    } catch (_) {
      await widget.authController.forceLocalLogout();
      if (mounted) {
        AppToast.info(
          context,
          'Server logout failed. You were signed out locally.',
        );
      }
    }

    if (widget.authController.isAuthenticated) {
      await widget.authController.forceLocalLogout();
    }

    return !widget.authController.isAuthenticated;
  }

  void _setActiveSidebarItem(String label) {
    if (!mounted || _activeSidebarItemLabel == label) {
      return;
    }
    setState(() {
      _activeSidebarItemLabel = label;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.authController.currentUser;
    final colors = context.appColors;
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 1180;
    final showBottomNav = width < 960;
    final sidebar = RepaintBoundary(
      child: _HomeSidebar(
        user: user,
        activeItemLabel: _activeSidebarItemLabel,
        onSearchTap: _openSearch,
        onHomeTap: _goHome,
        onProfileTap: _openProfile,
        onPostsTap: _openPostsFeed,
        onBlogsTap: _openBlogsFeed,
        onActivitiesTap: _openActivities,
        onGroupsTap: _openGroups,
        onLibraryTap: _openLibrary,
        onFlyerTemplatesTap: _openFlyerTemplates,
        onInspirationsTap: _openInspirations,
        onPlayGamesTap: _openGamesPage,
        onStoreTap: _openStorePage,
        onOtherMenusTap: _openOtherMenusPage,
        onAdvertiseTap: _openAdvertisePage,
        onVolunteerTap: _openVolunteerPage,
        onTvTap: _openTvPage,
        onOutreachTap: _openOutreachPage,
        onAdminTap: _openAdminPage,
        onMeetNewFriendsTap: _openMeetNewFriends,
        onLogoutTap: _handleLogout,
      ),
    );

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: colors.scaffold,
      bottomNavigationBar: showBottomNav ? _buildBottomNav() : null,
      drawer: isDesktop ? null : Drawer(width: 256, child: sidebar),
      body: Row(
        children: [
          if (isDesktop) sidebar,
          Expanded(
            child: Column(
              children: [
                RepaintBoundary(
                  child: ValueListenableBuilder<_TopBarSnapshot>(
                    valueListenable: _topBarSnapshot,
                    builder: (context, topBar, _) => _HomeTopBar(
                      user: user,
                      themeController: widget.themeController,
                      unreadNotifications: topBar.unreadNotifications,
                      unreadMessages: topBar.unreadMessages,
                      onMessageCenterTap: _openMessages,
                      onNotificationCenterTap: _openNotifications,
                      onHomeTap: _goHome,
                      onProfileTap: _openProfile,
                      onSettingsTap: _openSettings,
                      onMenuTap: isDesktop
                          ? null
                          : () {
                              _scaffoldKey.currentState?.openDrawer();
                            },
                    ),
                  ),
                ),
                Expanded(
                  child: FutureBuilder<FeedDashboard>(
                    future: _dashboardFuture,
                    builder: (context, snapshot) {
                      final dashboard = snapshot.data;
                      return RefreshIndicator(
                        onRefresh: _refreshDashboard,
                        child: CustomScrollView(
                          controller: _homeScrollController,
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          cacheExtent: 420,
                          slivers: [
                            SliverPadding(
                              padding: EdgeInsets.fromLTRB(
                                16,
                                8,
                                16,
                                showBottomNav ? 28 : 24,
                              ),
                              sliver: SliverToBoxAdapter(
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    final fitsRail =
                                        constraints.maxWidth >= 1380;
                                    if (fitsRail) {
                                      return Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: ConstrainedBox(
                                              constraints: const BoxConstraints(
                                                maxWidth: 900,
                                              ),
                                              child: _HomeContent(
                                                user: user,
                                                dashboard: dashboard,
                                                homeUpdates: _homeUpdates,
                                                isLoadingMoreUpdates:
                                                    _isLoadingMoreHomeUpdates,
                                                hasLoadMoreUpdatesError:
                                                    _hasLoadMoreHomeUpdatesError,
                                                feedRepository:
                                                    widget.feedRepository,
                                                homeGroupsPreviewFuture:
                                                    _homeGroupsPreviewFuture,
                                                highlightedUpdateId:
                                                    _highlightedUpdateId,
                                                onRetryLoadMore:
                                                    _retryLoadMoreHomeUpdates,
                                                onOpenEditMedia: _openEditMedia,
                                                onCreateUpdate:
                                                    _openCreateUpdate,
                                                onMeetNewFriendsTap:
                                                    _openMeetNewFriends,
                                                onOpenProfile: _openUserProfile,
                                                onOpenUpdate: _openUpdateDetail,
                                                onOpenUpdateComment: (entry) =>
                                                    _openUpdateDetail(
                                                      entry,
                                                      autofocusComment: true,
                                                    ),
                                                onOpenPost: _openPostDetail,
                                                onOpenPostById: _openQuotePreview,
                                                onOpenBlog: _openBlogDetail,
                                                onOpenPostsFeed: _openPostsFeed,
                                                onOpenHashtag: _openSearchQuery,
                                                onOpenLink: _handleLinkTap,
                                                onOpenTodayBirthdays:
                                                    _openTodayBirthdays,
                                                onOpenGroups: _openGroups,
                                                onOpenGroupPreview:
                                                    _openGroupPreview,
                                                updateRepository:
                                                    widget.updateRepository,
                                                isLoading:
                                                    snapshot.connectionState ==
                                                        ConnectionState
                                                            .waiting &&
                                                    dashboard == null,
                                                error: snapshot.error
                                                    ?.toString(),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 24),
                                          SizedBox(
                                            width: 360,
                                            child: RepaintBoundary(
                                              child: _RightRail(
                                                user: user,
                                                dashboard: dashboard,
                                                onOpenProfile: _openUserProfile,
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    }
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _HomeContent(
                                          user: user,
                                          dashboard: dashboard,
                                          homeUpdates: _homeUpdates,
                                          isLoadingMoreUpdates:
                                              _isLoadingMoreHomeUpdates,
                                          hasLoadMoreUpdatesError:
                                              _hasLoadMoreHomeUpdatesError,
                                          feedRepository: widget.feedRepository,
                                          homeGroupsPreviewFuture:
                                              _homeGroupsPreviewFuture,
                                          highlightedUpdateId:
                                              _highlightedUpdateId,
                                          onRetryLoadMore:
                                              _retryLoadMoreHomeUpdates,
                                          onOpenEditMedia: _openEditMedia,
                                          onCreateUpdate: _openCreateUpdate,
                                          onMeetNewFriendsTap:
                                              _openMeetNewFriends,
                                          onOpenProfile: _openUserProfile,
                                          onOpenUpdate: _openUpdateDetail,
                                          onOpenUpdateComment: (entry) =>
                                              _openUpdateDetail(
                                                entry,
                                                autofocusComment: true,
                                              ),
                                          onOpenPost: _openPostDetail,
                                          onOpenPostById: _openQuotePreview,
                                          onOpenBlog: _openBlogDetail,
                                          onOpenPostsFeed: _openPostsFeed,
                                          onOpenHashtag: _openSearchQuery,
                                          onOpenLink: _handleLinkTap,
                                          onOpenTodayBirthdays:
                                              _openTodayBirthdays,
                                          onOpenGroups: _openGroups,
                                          onOpenGroupPreview: _openGroupPreview,
                                          updateRepository:
                                              widget.updateRepository,
                                          isLoading:
                                              snapshot.connectionState ==
                                                  ConnectionState.waiting &&
                                              dashboard == null,
                                          error: snapshot.error?.toString(),
                                        ),
                                        const SizedBox(height: 16),
                                        RepaintBoundary(
                                          child: _RightRail(
                                            user: user,
                                            dashboard: dashboard,
                                            onOpenProfile: _openUserProfile,
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    final colors = context.appColors;
    final isCompactBottomNav = MediaQuery.sizeOf(context).width < 360;
    final navIconSize = isCompactBottomNav ? 22.0 : 24.0;
    final createButtonSize = isCompactBottomNav ? 48.0 : 52.0;
    final createIconSize = isCompactBottomNav ? 26.0 : 28.0;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(0, 0, 0, 0),
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border(
            top: BorderSide(color: colors.border.withValues(alpha: 0.95)),
          ),
          boxShadow: [
            BoxShadow(
              color: colors.shadow.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, -1),
            ),
          ],
        ),
        child: NavigationBar(
          height: isCompactBottomNav ? 70 : 76,
          backgroundColor: Colors.transparent,
          indicatorColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          selectedIndex: _selectedBottomNav,
          onDestinationSelected: (index) {
            setState(() {
              _selectedBottomNav = index;
            });
            if (index == 0) {
              _goHome();
            }
            if (index == 1) {
              _openSearch();
            }
            if (index == 2) {
              _openCreateUpdate();
            }
            if (index == 3) {
              _openGroups();
            }
            if (index == 4) {
              _openProfile();
            }
          },
          destinations: [
            NavigationDestination(
              icon: HeroIcon(HeroIcons.home, size: navIconSize),
              selectedIcon: HeroIcon(
                HeroIcons.home,
                size: navIconSize,
                style: HeroIconStyle.solid,
              ),
              label: 'Home',
            ),
            NavigationDestination(
              icon: HeroIcon(HeroIcons.magnifyingGlass, size: navIconSize),
              selectedIcon: HeroIcon(
                HeroIcons.magnifyingGlass,
                size: navIconSize,
                style: HeroIconStyle.solid,
              ),
              label: 'Search',
            ),
            NavigationDestination(
              icon: Container(
                width: createButtonSize,
                height: createButtonSize,
                decoration: BoxDecoration(
                  color: colors.brand,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.add_rounded,
                  color: Colors.white,
                  size: createIconSize,
                ),
              ),
              label: '',
            ),
            NavigationDestination(
              icon: _BadgeTopBarIcon(
                icon: HeroIcons.users,
                count: _topBarSnapshot.value.unreadGroups,
                dotOnly: true,
                iconSize: navIconSize,
                boxSize: isCompactBottomNav ? 28 : 30,
              ),
              selectedIcon: _BadgeTopBarIcon(
                icon: HeroIcons.users,
                count: _topBarSnapshot.value.unreadGroups,
                dotOnly: true,
                solid: true,
                iconSize: navIconSize,
                boxSize: isCompactBottomNav ? 28 : 30,
              ),
              label: 'Groups',
            ),
            NavigationDestination(
              icon: HeroIcon(HeroIcons.user, size: navIconSize),
              selectedIcon: HeroIcon(
                HeroIcons.user,
                size: navIconSize,
                style: HeroIconStyle.solid,
              ),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

class _TopbarFetchResult {
  const _TopbarFetchResult._({
    this.unreadNotifications,
    this.unreadMessages,
    this.error,
  });

  factory _TopbarFetchResult.notifications(int count) =>
      _TopbarFetchResult._(unreadNotifications: count);

  factory _TopbarFetchResult.messages(int count) =>
      _TopbarFetchResult._(unreadMessages: count);

  factory _TopbarFetchResult.notificationError(Object error) =>
      _TopbarFetchResult._(error: error);

  factory _TopbarFetchResult.messageError(Object error) =>
      _TopbarFetchResult._(error: error);

  final int? unreadNotifications;
  final int? unreadMessages;
  final Object? error;
}

class _TopBarSnapshot {
  const _TopBarSnapshot({
    this.unreadNotifications = 0,
    this.unreadMessages = 0,
    this.unreadGroups = 0,
  });

  final int unreadNotifications;
  final int unreadMessages;
  final int unreadGroups;

  _TopBarSnapshot copyWith({
    int? unreadNotifications,
    int? unreadMessages,
    int? unreadGroups,
  }) {
    return _TopBarSnapshot(
      unreadNotifications: unreadNotifications ?? this.unreadNotifications,
      unreadMessages: unreadMessages ?? this.unreadMessages,
      unreadGroups: unreadGroups ?? this.unreadGroups,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is _TopBarSnapshot &&
        unreadNotifications == other.unreadNotifications &&
        unreadMessages == other.unreadMessages &&
        unreadGroups == other.unreadGroups;
  }

  @override
  int get hashCode =>
      Object.hash(unreadNotifications, unreadMessages, unreadGroups);
}

class _HomeTopBar extends StatelessWidget {
  const _HomeTopBar({
    required this.user,
    required this.themeController,
    required this.unreadNotifications,
    required this.unreadMessages,
    required this.onMessageCenterTap,
    required this.onNotificationCenterTap,
    required this.onHomeTap,
    required this.onProfileTap,
    required this.onSettingsTap,
    required this.onMenuTap,
  });

  final User? user;
  final ThemeController themeController;
  final int unreadNotifications;
  final int unreadMessages;
  final Future<void> Function() onMessageCenterTap;
  final Future<void> Function() onNotificationCenterTap;
  final Future<void> Function() onHomeTap;
  final Future<void> Function() onProfileTap;
  final Future<void> Function() onSettingsTap;
  final VoidCallback? onMenuTap;
  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final iconColor = Theme.of(context).brightness == Brightness.dark
        ? colors.textSecondary
        : colors.icon;
    final isCompactTopBar = MediaQuery.sizeOf(context).width < 360;
    return SafeArea(
      bottom: false,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isCompactTopBar ? 12 : 16,
          vertical: isCompactTopBar ? 10 : 12,
        ),
        decoration: BoxDecoration(
          color: colors.surface.withValues(alpha: 0.96),
          border: Border(bottom: BorderSide(color: colors.borderStrong)),
        ),
        child: Row(
          children: [
            if (onMenuTap != null) ...[
              IconButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  onMenuTap?.call();
                },
                icon: HeroIcon(
                  HeroIcons.bars3,
                  size: isCompactTopBar ? 24 : 26,
                  color: iconColor,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              SizedBox(width: isCompactTopBar ? 8 : 12),
            ],
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: 'Hopeful',
                    style: TextStyle(
                      color: colors.brand,
                      fontSize: isCompactTopBar ? 23 : 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.1,
                    ),
                  ),
                  TextSpan(
                    text: 'Me',
                    style: TextStyle(
                      color: Color(0xFFe08016),
                      fontSize: isCompactTopBar ? 23 : 26,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1.1,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            _TopBarIconButton(
              icon: HeroIcons.chatBubbleOvalLeftEllipsis,
              // icon: HeroIcons.chatBubbleLeftEllipsis,
              unreadCount: unreadMessages,
              onTap: onMessageCenterTap,
              iconSize: isCompactTopBar ? 22 : 24,
              boxSize: isCompactTopBar ? 28 : 30,
            ),
            SizedBox(width: isCompactTopBar ? 10 : 16),
            _TopBarIconButton(
              icon: HeroIcons.bell,
              unreadCount: unreadNotifications,
              onTap: onNotificationCenterTap,
              iconSize: isCompactTopBar ? 22 : 24,
              boxSize: isCompactTopBar ? 28 : 30,
            ),
            SizedBox(width: isCompactTopBar ? 10 : 16),
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'profile') {
                  await onProfileTap();
                }
                if (value == 'theme') {
                  await themeController.cycleThemeMode();
                }
                if (value == 'settings') {
                  await onSettingsTap();
                }
                if (value == 'home') {
                  await onHomeTap();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'profile',
                  child: Text('View Profile'),
                ),
                PopupMenuItem(
                  value: 'theme',
                  child: Text(
                    themeController.isDarkMode
                        ? 'Switch to Light Mode'
                        : 'Switch to Dark Mode',
                  ),
                ),
                const PopupMenuItem(value: 'settings', child: Text('Settings')),
                // const PopupMenuItem(value: 'home', child: Text('Go Home')),
              ],
              child: AppAvatar(
                imageUrl: user?.photoUrl ?? '',
                label: user?.displayName ?? 'User',
                radius: isCompactTopBar ? 15 : 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBarIconButton extends StatelessWidget {
  const _TopBarIconButton({
    required this.icon,
    required this.unreadCount,
    required this.onTap,
    this.iconSize = 24,
    this.boxSize = 30,
  });

  final HeroIcons icon;
  final int unreadCount;
  final Future<void> Function() onTap;
  final double iconSize;
  final double boxSize;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(999),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: _BadgeTopBarIcon(
          icon: icon,
          count: unreadCount,
          iconSize: iconSize,
          boxSize: boxSize,
        ),
      ),
    );
  }
}

class _BadgeTopBarIcon extends StatelessWidget {
  const _BadgeTopBarIcon({
    required this.icon,
    required this.count,
    this.dotOnly = false,
    this.solid = false,
    this.iconSize = 24,
    this.boxSize = 30,
  });

  final HeroIcons icon;
  final int count;
  final bool dotOnly;
  final bool solid;
  final double iconSize;
  final double boxSize;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final iconColor = Theme.of(context).brightness == Brightness.dark
        ? colors.textSecondary
        : colors.icon;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        SizedBox(
          width: boxSize,
          height: boxSize,
          child: HeroIcon(
            icon,
            size: iconSize,
            color: iconColor,
            style: solid ? HeroIconStyle.solid : HeroIconStyle.outline,
          ),
        ),
        if (count > 0)
          Positioned(
            top: -2,
            right: -2,
            child: Container(
              padding: dotOnly
                  ? EdgeInsets.zero
                  : const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              width: dotOnly ? 10 : null,
              height: dotOnly ? 10 : null,
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444),
                borderRadius: BorderRadius.circular(999),
                border: dotOnly
                    ? Border.all(color: colors.surface, width: 1.4)
                    : null,
              ),
              child: dotOnly
                  ? null
                  : Text(
                      count > 9 ? '9+' : '$count',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
          ),
      ],
    );
  }
}

class _DropdownShell extends StatelessWidget {
  const _DropdownShell({
    required this.title,
    required this.count,
    required this.child,
    required this.footerLabel,
    required this.onFooterTap,
    this.actionLabel,
    this.onActionTap,
  });

  final String title;
  final int count;
  final String? actionLabel;
  final Future<void> Function()? onActionTap;
  final Widget child;
  final String footerLabel;
  final Future<void> Function() onFooterTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        decoration: BoxDecoration(
          color: isDark
              ? colors.surfaceRaised.withValues(alpha: 0.98)
              : colors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: colors.borderStrong),
          boxShadow: [
            BoxShadow(
              color: colors.shadow.withValues(alpha: isDark ? 0.28 : 0.08),
              blurRadius: isDark ? 24 : 28,
              offset: const Offset(0, 16),
              spreadRadius: -20,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (count > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3D5AFE),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        count > 9 ? '9+' : '$count',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (actionLabel != null)
                    TextButton(
                      onPressed: () => onActionTap?.call(),
                      child: Text(actionLabel!),
                    ),
                ],
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: SingleChildScrollView(child: child),
            ),
            Divider(height: 1, color: colors.border),
            InkWell(
              onTap: () => onFooterTap(),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(22),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Center(
                  child: Text(
                    footerLabel,
                    style: TextStyle(
                      color: colors.brand,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationDropdownRow extends StatelessWidget {
  const _NotificationDropdownRow({required this.item, required this.onTap});

  final AppNotification item;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final avatarUrl = item.avatarUrl.isNotEmpty
        ? ImageUrlResolver.avatar(item.avatarUrl, size: 56)
        : '';
    return InkWell(
      onTap: () => onTap(),
      child: Container(
        color: item.isRead
            ? (isDark ? colors.surfaceRaised : colors.surface)
            : (isDark
                  ? colors.accentSoft.withValues(alpha: 0.42)
                  : colors.accentSoft.withValues(alpha: 0.2)),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 36,
              height: 36,
              child: ClipOval(
                child: AppNetworkImage(
                  imageUrl: avatarUrl,
                  width: 36,
                  height: 36,
                  placeholderLabel: item.message,
                  placeholderIcon: Icons.person,
                  showShimmer: false,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 12.5,
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatConversationListTimestamp(item.createdAt),
                    style: TextStyle(color: colors.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
            if (!item.isRead)
              const Padding(
                padding: EdgeInsets.only(left: 8, top: 4),
                child: CircleAvatar(
                  radius: 4,
                  backgroundColor: Color(0xFF3D5AFE),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MessageDropdownRow extends StatelessWidget {
  const _MessageDropdownRow({required this.item, required this.onTap});

  final ConversationListItem item;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final avatarUrl = item.otherUser.photoUrl.isNotEmpty
        ? ImageUrlResolver.avatar(item.otherUser.photoUrl, size: 60)
        : '';
    return InkWell(
      onTap: () => onTap(),
      child: Container(
        color: item.unreadCount > 0
            ? (isDark
                  ? colors.accentSoft.withValues(alpha: 0.42)
                  : colors.accentSoft.withValues(alpha: 0.2))
            : (isDark ? colors.surfaceRaised : colors.surface),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Stack(
              children: [
                SizedBox(
                  width: 40,
                  height: 40,
                  child: ClipOval(
                    child: AppNetworkImage(
                      imageUrl: avatarUrl,
                      width: 40,
                      height: 40,
                      placeholderLabel: item.otherUser.displayName,
                      placeholderIcon: Icons.person,
                      showShimmer: false,
                    ),
                  ),
                ),
                if (item.otherUser.isOnline)
                  const Positioned(
                    right: 0,
                    bottom: 0,
                    child: CircleAvatar(
                      radius: 5,
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
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        formatConversationListTimestamp(
                          item.latestMessage?.createdAt.isNotEmpty == true
                              ? item.latestMessage!.createdAt
                              : item.updatedAt,
                        ),
                        style: TextStyle(
                          color: colors.textMuted,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.latestMessage?.message.isNotEmpty == true
                        ? item.latestMessage!.message
                        : 'Open conversation',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: colors.textMuted, fontSize: 11.5),
                  ),
                ],
              ),
            ),
            if (item.unreadCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF3D5AFE),
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
        ),
      ),
    );
  }
}

class _DropdownEmptyState extends StatelessWidget {
  const _DropdownEmptyState({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: context.appColors.textMuted,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _HomeSidebar extends StatelessWidget {
  const _HomeSidebar({
    required this.user,
    required this.activeItemLabel,
    required this.onSearchTap,
    required this.onHomeTap,
    required this.onProfileTap,
    required this.onPostsTap,
    required this.onBlogsTap,
    required this.onActivitiesTap,
    required this.onGroupsTap,
    required this.onLibraryTap,
    required this.onFlyerTemplatesTap,
    required this.onInspirationsTap,
    required this.onPlayGamesTap,
    required this.onStoreTap,
    required this.onOtherMenusTap,
    required this.onAdvertiseTap,
    required this.onVolunteerTap,
    required this.onTvTap,
    required this.onOutreachTap,
    required this.onAdminTap,
    required this.onMeetNewFriendsTap,
    required this.onLogoutTap,
  });

  final User? user;
  final String activeItemLabel;
  final Future<void> Function() onSearchTap;
  final Future<void> Function() onHomeTap;
  final Future<void> Function() onProfileTap;
  final Future<void> Function() onPostsTap;
  final Future<void> Function() onBlogsTap;
  final Future<void> Function() onActivitiesTap;
  final Future<void> Function() onGroupsTap;
  final Future<void> Function() onLibraryTap;
  final Future<void> Function() onFlyerTemplatesTap;
  final Future<void> Function() onInspirationsTap;
  final Future<void> Function() onPlayGamesTap;
  final Future<void> Function() onStoreTap;
  final Future<void> Function() onOtherMenusTap;
  final Future<void> Function() onAdvertiseTap;
  final Future<void> Function() onVolunteerTap;
  final Future<void> Function() onTvTap;
  final Future<void> Function() onOutreachTap;
  final Future<void> Function() onAdminTap;
  final Future<void> Function() onMeetNewFriendsTap;
  final Future<bool> Function() onLogoutTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final showAdminPanel = user?.rank.trim().isNotEmpty ?? false;
    return Container(
      width: 256,
      decoration: BoxDecoration(color: colors.sidebar),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(0, 12, 0, 16),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                    child: Text(
                      'Menu',
                      style: TextStyle(
                        color: colors.sidebarText,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: InkWell(
                      onTap: () => onSearchTap(),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        height: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 13),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.045),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.06),
                          ),
                        ),
                        child: Row(
                          children: [
                            HeroIcon(
                              HeroIcons.magnifyingGlass,
                              size: 16,
                              color: colors.sidebarMuted,
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                'Search',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                softWrap: false,
                                style: TextStyle(
                                  color: colors.sidebarMuted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  _SidebarSection(
                    title: 'Community',
                    items: [
                      _SidebarItemData(
                        HeroIcons.home,
                        'Home',
                        activeItemLabel == 'Home',
                        onTap: onHomeTap,
                      ),

                      _SidebarItemData(
                        HeroIcons.newspaper,
                        'Post & News',
                        activeItemLabel == 'Post & News',
                        onTap: onPostsTap,
                      ),

                      _SidebarItemData(
                        HeroIcons.rectangleGroup,
                        'Activities',
                        activeItemLabel == 'Activities',
                        onTap: onActivitiesTap,
                      ),
                      _SidebarItemData(
                        HeroIcons.users,
                        'Group Chats',
                        activeItemLabel == 'Group Chats',
                        onTap: onGroupsTap,
                      ),
                      _SidebarItemData(
                        HeroIcons.userPlus,
                        'Meet New Friends',
                        activeItemLabel == 'Meet New Friends',
                        onTap: onMeetNewFriendsTap,
                      ),
                    ],
                  ),
                  _SidebarSection(
                    title: 'Resources',
                    items: [
                      _SidebarItemData(
                        HeroIcons.pencilSquare,
                        'Blog & Articles',
                        activeItemLabel == 'Blog & Articles',
                        onTap: onBlogsTap,
                      ),

                      _SidebarItemData(
                        HeroIcons.inboxStack,
                        'Inspiration Inbox',
                        activeItemLabel == 'Inspiration Inbox',
                        onTap: onInspirationsTap,
                      ),
                      _SidebarItemData(
                        HeroIcons.bookOpen,
                        'Library',
                        activeItemLabel == 'Library',
                        onTap: onLibraryTap,
                      ),
                      _SidebarItemData(
                        HeroIcons.photo,
                        'Flyer Templates',
                        activeItemLabel == 'Flyer Templates',
                        onTap: onFlyerTemplatesTap,
                      ),
                    ],
                  ),
                  _SidebarSection(
                    title: 'Explore',
                    items: [
                      _SidebarItemData(
                        HeroIcons.shoppingBag,
                        'Marketplace',
                        activeItemLabel == 'Marketplace',
                        onTap: onStoreTap,
                      ),
                      _SidebarItemData(
                        HeroIcons.tv,
                        'HopefulMe TV',
                        activeItemLabel == 'HopefulMe TV',
                        onTap: onTvTap,
                      ),
                      _SidebarItemData(
                        HeroIcons.puzzlePiece,
                        'Games & Contests',
                        activeItemLabel == 'Games & Contests',
                        onTap: onPlayGamesTap,
                      ),
                      _SidebarItemData(
                        HeroIcons.cube,
                        'More Features',
                        activeItemLabel == 'More Features',
                        onTap: onOtherMenusTap,
                      ),
                    ],
                  ),
                  _SidebarSection(
                    title: 'Get Involved',
                    items: [
                      _SidebarItemData(
                        HeroIcons.heart,
                        'Outreaches',
                        activeItemLabel == 'Outreaches',
                        onTap: onOutreachTap,
                      ),
                      _SidebarItemData(
                        HeroIcons.megaphone,
                        'Advert & Partnership',
                        activeItemLabel == 'Advert & Partnership',
                        onTap: onAdvertiseTap,
                      ),
                      _SidebarItemData(
                        HeroIcons.briefcase,
                        'Volunteer & Support',
                        activeItemLabel == 'Volunteer & Support',
                        onTap: onVolunteerTap,
                      ),
                    ],
                  ),

                  if (showAdminPanel)
                    _SidebarSection(
                      title: 'Admin',
                      items: [
                        _SidebarItemData(
                          HeroIcons.shieldCheck,
                          'Admin',
                          activeItemLabel == 'Admin',
                          onTap: onAdminTap,
                        ),
                      ],
                    ),
                ],
              ),
            ),
            _SidebarFooter(
              user: user,
              onProfileTap: onProfileTap,
              onLogoutTap: onLogoutTap,
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarSection extends StatelessWidget {
  const _SidebarSection({required this.title, required this.items});

  final String title;
  final List<_SidebarItemData> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
            child: Text(
              title,
              style: const TextStyle(
                color: Color(0xFF7A8FA8),
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ),
          ...items.map(_SidebarItem.new),
        ],
      ),
    );
  }
}

class _SidebarItemData {
  const _SidebarItemData(this.icon, this.label, this.active, {this.onTap});

  final HeroIcons icon;
  final String label;
  final bool active;
  final Future<void> Function()? onTap;
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem(this.item);

  final _SidebarItemData item;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    const activeColor = Color(0xFF3D5AFE);
    const inactiveColor = Color(0xFF90A3BD);
    final textColor = colors.sidebarText.withValues(alpha: 0.9);

    final isActive = item.active;

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: item.onTap == null ? null : () => item.onTap!(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            decoration: BoxDecoration(
              color: isActive
                  ? activeColor.withValues(alpha: 0.14)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  width: 3,
                  height: 18,
                  decoration: BoxDecoration(
                    color: isActive ? activeColor : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(width: 10),
                HeroIcon(
                  item.icon,
                  style: isActive ? HeroIconStyle.solid : HeroIconStyle.outline,
                  color: isActive ? activeColor : inactiveColor,
                  size: 17,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    style: TextStyle(
                      color: isActive ? Colors.white : textColor,
                      fontSize: 13,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                ),
                if (isActive)
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 11,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SidebarFooter extends StatelessWidget {
  const _SidebarFooter({
    required this.user,
    required this.onProfileTap,
    required this.onLogoutTap,
  });

  final User? user;
  final Future<void> Function() onProfileTap;
  final Future<bool> Function() onLogoutTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final displayName = user?.displayName.trim().isNotEmpty == true
        ? user!.displayName
        : 'HopefulMe User';
    final username = user?.username.trim().isNotEmpty == true
        ? '@${user!.username}'
        : '@hopefulme';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
      decoration: BoxDecoration(
        color: colors.sidebar,
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.045),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => onProfileTap(),
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        _Avatar(
                          imageUrl: user?.photoUrl ?? '',
                          label: displayName,
                          radius: 18,
                          backgroundColor: colors.avatarPlaceholder,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: colors.sidebarText,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                username,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: colors.sidebarMuted,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
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
            ),
            const SizedBox(width: 8),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => onLogoutTap(),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: colors.sidebar,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: HeroIcon(
                    HeroIcons.arrowRightOnRectangle,
                    size: 18,
                    color: colors.sidebarText,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeContent extends StatelessWidget {
  const _HomeContent({
    required this.user,
    required this.dashboard,
    required this.homeUpdates,
    required this.isLoadingMoreUpdates,
    required this.hasLoadMoreUpdatesError,
    required this.feedRepository,
    required this.homeGroupsPreviewFuture,
    required this.highlightedUpdateId,
    required this.onRetryLoadMore,
    required this.onOpenEditMedia,
    required this.onCreateUpdate,
    required this.onMeetNewFriendsTap,
    required this.onOpenProfile,
    required this.onOpenUpdate,
    required this.onOpenUpdateComment,
    required this.onOpenPost,
    required this.onOpenPostById,
    required this.onOpenBlog,
    required this.onOpenPostsFeed,
    required this.onOpenHashtag,
    required this.onOpenLink,
    required this.onOpenTodayBirthdays,
    required this.onOpenGroups,
    required this.onOpenGroupPreview,
    required this.updateRepository,
    required this.isLoading,
    required this.error,
  });

  final User? user;
  final FeedDashboard? dashboard;
  final List<FeedEntry> homeUpdates;
  final bool isLoadingMoreUpdates;
  final bool hasLoadMoreUpdatesError;
  final FeedRepository feedRepository;
  final Future<List<AppGroup>> homeGroupsPreviewFuture;
  final int? highlightedUpdateId;
  final Future<void> Function() onRetryLoadMore;
  final Future<void> Function() onOpenEditMedia;
  final Future<void> Function() onCreateUpdate;
  final Future<void> Function() onMeetNewFriendsTap;
  final Future<void> Function(String username) onOpenProfile;
  final Future<void> Function(FeedEntry entry) onOpenUpdate;
  final Future<void> Function(FeedEntry entry) onOpenUpdateComment;
  final Future<void> Function(FeedEntry entry) onOpenPost;
  final Future<void> Function(QuoteCard quote) onOpenPostById;
  final Future<void> Function(FeedEntry entry) onOpenBlog;
  final Future<void> Function({String initialCategory}) onOpenPostsFeed;
  final Future<void> Function(String hashtag) onOpenHashtag;
  final Future<void> Function(String url) onOpenLink;
  final Future<void> Function(List<FeedUser> users) onOpenTodayBirthdays;
  final Future<void> Function() onOpenGroups;
  final Future<void> Function(AppGroup group) onOpenGroupPreview;
  final UpdateRepository updateRepository;
  final bool isLoading;
  final String? error;

  List<Widget> _buildFeedSections(BuildContext context, FeedDashboard data) {
    final widgets = <Widget>[];
    final postsBlock = data.feed
        .where(
          (entry) =>
              entry.type != 'update' &&
              entry.type != 'blog' &&
              entry.type != 'advert',
        )
        .toList(growable: false);

    if (postsBlock.isNotEmpty) {
      if (data.postCategories.isNotEmpty) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _PostCategoryStrip(
              categories: data.postCategories,
              onSelectCategory: (category) =>
                  onOpenPostsFeed(initialCategory: category),
            ),
          ),
        );
      }
      widgets.addAll(
        postsBlock.map((entry) {
          final isHighlighted =
              entry.type == 'update' && entry.id == highlightedUpdateId;
          return Padding(
            key: ValueKey('home-feed-${entry.type}-${entry.id}'),
            padding: const EdgeInsets.only(bottom: 16),
            child: RepaintBoundary(
              child: _HighlightFrame(
                isHighlighted: isHighlighted,
                child: _FeedEntryCard(
                  entry: entry,
                  currentUser: user,
                  onOpenProfile: onOpenProfile,
                  onOpenUpdate: onOpenUpdate,
                  onOpenComment: onOpenUpdateComment,
                  onOpenPost: onOpenPost,
                  onOpenBlog: onOpenBlog,
                  onOpenHashtag: onOpenHashtag,
                  onOpenLink: onOpenLink,
                  updateRepository: updateRepository,
                ),
              ),
            ),
          );
        }),
      );
      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
          child: _FeedExploreChip(
            icon: Icons.article_outlined,
            label: 'View more posts',
            onTap: () => onOpenPostsFeed(initialCategory: 'All'),
          ),
        ),
      );
      widgets.add(
        FutureBuilder<List<AppGroup>>(
          future: homeGroupsPreviewFuture,
          builder: (context, snapshot) {
            final groups = snapshot.data ?? const <AppGroup>[];
            if (groups.isEmpty) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 8, top: 12),
              child: _HomeGroupsPreviewCard(
                groups: groups,
                onOpenGroups: onOpenGroups,
                onOpenGroup: onOpenGroupPreview,
              ),
            );
          },
        ),
      );
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8, top: 12),
          child: MostActiveUsersCard(
            feedRepository: feedRepository,
            onOpenProfile: onOpenProfile,
          ),
        ),
      );
      widgets.add(const SizedBox(height: 16));
    }

    if (homeUpdates.isNotEmpty) {
      widgets.addAll(
        homeUpdates.map((entry) {
          final isHighlighted =
              entry.type == 'update' && entry.id == highlightedUpdateId;
          return Padding(
            key: ValueKey('home-update-${entry.type}-${entry.id}'),
            padding: const EdgeInsets.only(bottom: 16),
            child: RepaintBoundary(
              child: _HighlightFrame(
                isHighlighted: isHighlighted,
                child: _FeedEntryCard(
                  entry: entry,
                  currentUser: user,
                  onOpenProfile: onOpenProfile,
                  onOpenUpdate: onOpenUpdate,
                  onOpenComment: onOpenUpdateComment,
                  onOpenPost: onOpenPost,
                  onOpenBlog: onOpenBlog,
                  onOpenHashtag: onOpenHashtag,
                  onOpenLink: onOpenLink,
                  updateRepository: updateRepository,
                ),
              ),
            ),
          );
        }),
      );
      widgets.add(const SizedBox(height: 28));
    }

    if (isLoadingMoreUpdates) {
      widgets.add(
        const Padding(
          padding: EdgeInsets.only(bottom: 28),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (hasLoadMoreUpdatesError) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Center(
            child: TextButton.icon(
              onPressed: onRetryLoadMore,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Tap to retry loading more'),
            ),
          ),
        ),
      );
    }

    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const _HomeLoadingSkeleton();
    }

    if (error != null && dashboard == null) {
      return _SurfaceCard(
        padding: const EdgeInsets.all(20),
        child: Text(error!),
      );
    }

    final data = dashboard;
    if (data == null) {
      return const SizedBox.shrink();
    }
    final currentUser = user;
    final shouldPromptForPhoto =
        currentUser != null &&
        _looksLikeDefaultProfilePhoto(currentUser.photoUrl);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 9),
        _StoriesRow(
          users: data.onlineUsers,
          onUserTap: onOpenProfile,
          onCreateUpdate: onMeetNewFriendsTap,
        ),
        const SizedBox(height: 12),
        if (data.feedNotice != null) ...[
          FeedNoticeCard(notice: data.feedNotice!, onOpenLink: onOpenLink),
          const SizedBox(height: 14),
        ],
        _ComposerCard(user: user, onCreateUpdate: onCreateUpdate),
        const SizedBox(height: 14),
        if (data.todayBirthdays.isNotEmpty) ...[
          _BirthdayCelebrationStrip(
            users: data.todayBirthdays,
            onOpenProfile: onOpenProfile,
            onViewAll: () => onOpenTodayBirthdays(data.todayBirthdays),
          ),
          const SizedBox(height: 8),
        ],
        if (shouldPromptForPhoto) ...[
          _ProfilePhotoReminderCard(user: currentUser, onTap: onOpenEditMedia),
          const SizedBox(height: 12),
        ],
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: _SectionHeader(
            title: 'Quotes for you',
            leading: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: context.appColors.brand.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.format_quote_rounded,
                color: context.appColors.brand,
                size: 15,
              ),
            ),
          ),
        ),
        Transform.translate(
          offset: const Offset(0, -25),
          child: _QuoteGrid(
            quotes: data.trendingQuotes,
            onOpenQuote: onOpenPostById,
          ),
        ),
        const SizedBox(height: 6),
        ..._buildFeedSections(context, data),
      ],
    );
  }
}

List<AppGroup> _buildHomeGroupsPreview(List<AppGroup> groups) {
  final activeGroups = groups
      .where((group) => group.status == 'active')
      .toList(growable: false);
  if (activeGroups.isEmpty) {
    return const <AppGroup>[];
  }

  AppGroup? communityGroup;
  for (final group in activeGroups) {
    if (group.id == 1) {
      communityGroup = group;
      break;
    }
  }
  final otherGroups = activeGroups
      .where((group) => group.id != 1)
      .toList(growable: true);

  final preview = <AppGroup>[];
  if (communityGroup != null) {
    preview.add(communityGroup);
  }
  if (otherGroups.isNotEmpty) {
    otherGroups.shuffle(Random());
    preview.add(otherGroups.first);
  }

  if (preview.isEmpty) {
    otherGroups.shuffle(Random());
    return otherGroups.take(2).toList(growable: false);
  }

  return preview.take(2).toList(growable: false);
}

class _HomeLoadingSkeleton extends StatelessWidget {
  const _HomeLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 16),
        _StoriesRowSkeleton(),
        SizedBox(height: 18),
        _ComposerCardSkeleton(),
        SizedBox(height: 18),
        _BirthdayStripSkeleton(),
        SizedBox(height: 18),
        _QuotesSectionSkeleton(),
        SizedBox(height: 20),
        _FeedCardSkeleton(),
        SizedBox(height: 16),
        _FeedCardSkeleton(),
        SizedBox(height: 16),
        _FeedCardSkeleton(),
      ],
    );
  }
}

class _StoriesRowSkeleton extends StatelessWidget {
  const _StoriesRowSkeleton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 6,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          return const SizedBox(
            width: 70,
            child: Column(
              children: [
                ShimmerCircle(size: 60),
                SizedBox(height: 8),
                ShimmerBox(width: 54, height: 10, borderRadius: 999),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ComposerCardSkeleton extends StatelessWidget {
  const _ComposerCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Row(
            children: [
              ShimmerCircle(size: 44),
              SizedBox(width: 12),
              Expanded(child: ShimmerBox(height: 44, borderRadius: 18)),
            ],
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: ShimmerBox(height: 12, borderRadius: 999)),
              SizedBox(width: 12),
              Expanded(child: ShimmerBox(height: 12, borderRadius: 999)),
              SizedBox(width: 12),
              Expanded(child: ShimmerBox(height: 12, borderRadius: 999)),
            ],
          ),
        ],
      ),
    );
  }
}

class _BirthdayStripSkeleton extends StatelessWidget {
  const _BirthdayStripSkeleton();

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      padding: const EdgeInsets.all(18),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ShimmerCircle(size: 34),
              SizedBox(width: 10),
              Expanded(child: ShimmerBox(width: 180, height: 16)),
              SizedBox(width: 16),
              ShimmerBox(width: 56, height: 12, borderRadius: 999),
            ],
          ),
          SizedBox(height: 16),
          Row(
            children: [
              ShimmerCircle(size: 42),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerBox(width: 140, height: 12),
                    SizedBox(height: 8),
                    ShimmerBox(width: 90, height: 10),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuotesSectionSkeleton extends StatelessWidget {
  const _QuotesSectionSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Row(
          children: [
            ShimmerBox(width: 34, height: 34, borderRadius: 12),
            SizedBox(width: 10),
            Expanded(child: ShimmerBox(width: 180, height: 16)),
            SizedBox(width: 12),
            ShimmerBox(width: 58, height: 12, borderRadius: 999),
          ],
        ),
        SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: _QuoteCardSkeleton()),
            SizedBox(width: 12),
            Expanded(child: _QuoteCardSkeleton()),
          ],
        ),
      ],
    );
  }
}

class _PostCategoryStrip extends StatelessWidget {
  const _PostCategoryStrip({
    required this.categories,
    required this.onSelectCategory,
  });

  final List<String> categories;
  final Future<void> Function(String category) onSelectCategory;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = categories[index];
          final isAll = category.toLowerCase() == 'all';
          return FilterChip(
            label: Text(category),
            selected: isAll,
            showCheckmark: false,
            onSelected: (_) => onSelectCategory(category),
            labelStyle: TextStyle(
              color: isAll ? Colors.white : colors.textSecondary,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
            side: BorderSide(color: isAll ? colors.brand : colors.borderStrong),
            backgroundColor: colors.surface,
            selectedColor: colors.brand,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          );
        },
      ),
    );
  }
}

class _QuoteCardSkeleton extends StatelessWidget {
  const _QuoteCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      padding: const EdgeInsets.all(12),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShimmerBox(height: 150, borderRadius: 18),
          SizedBox(height: 12),
          ShimmerBox(width: 110, height: 12),
          SizedBox(height: 8),
          ShimmerBox(width: 90, height: 10),
        ],
      ),
    );
  }
}

class _FeedCardSkeleton extends StatelessWidget {
  const _FeedCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      padding: const EdgeInsets.all(18),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ShimmerCircle(size: 44),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerBox(width: 132, height: 13),
                    SizedBox(height: 8),
                    ShimmerBox(width: 96, height: 10),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          ShimmerBox(height: 12),
          SizedBox(height: 8),
          ShimmerBox(height: 12),
          SizedBox(height: 8),
          ShimmerBox(width: 180, height: 12),
          SizedBox(height: 16),
          ShimmerBox(height: 220, borderRadius: 22),
          SizedBox(height: 16),
          Row(
            children: [
              ShimmerBox(width: 64, height: 12, borderRadius: 999),
              SizedBox(width: 12),
              ShimmerBox(width: 64, height: 12, borderRadius: 999),
              SizedBox(width: 12),
              ShimmerBox(width: 64, height: 12, borderRadius: 999),
            ],
          ),
        ],
      ),
    );
  }
}

class _StoriesRow extends StatelessWidget {
  const _StoriesRow({
    required this.users,
    required this.onUserTap,
    required this.onCreateUpdate,
  });

  final List<FeedUser> users;
  final Future<void> Function(String username) onUserTap;
  final Future<void> Function() onCreateUpdate;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: users.length + 1,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          if (index == 0) {
            return InkWell(
              onTap: () => onCreateUpdate(),
              borderRadius: BorderRadius.circular(999),
              child: const SizedBox(
                width: 70,
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      child: Icon(
                        Icons.arrow_outward,
                        color: Color(0xFF3D5AFE),
                        size: 18,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Connect',
                      style: TextStyle(
                        color: Color(0xFF3D5AFE),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final user = users[index - 1];
          return InkWell(
            onTap: () => onUserTap(user.username),
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              width: 70,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(2.5),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF3D5AFE),
                    ),
                    child: _Avatar(
                      imageUrl: user.photoUrl,
                      label: user.displayName,
                      radius: 28,
                      backgroundColor: colors.avatarPlaceholder,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    user.username,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 10.5,
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

class _ComposerCard extends StatelessWidget {
  const _ComposerCard({required this.user, required this.onCreateUpdate});

  final User? user;
  final Future<void> Function() onCreateUpdate;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Top Row: Avatar and Text Input Field
            Row(
              crossAxisAlignment: CrossAxisAlignment
                  .center, // Centered for better vertical alignment
              children: [
                _Avatar(
                  imageUrl: user?.photoUrl ?? '',
                  label: user?.displayName ?? 'U',
                  backgroundColor: context.appColors.avatarPlaceholder,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () => onCreateUpdate(),
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: context.appColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(
                        "Share your thoughts...",
                        style: TextStyle(
                          color: context.appColors.textMuted,
                          fontSize: 14, // Slightly increased for readability
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16), // Increased spacing for a cleaner look
            // Bottom Row: Chips and Publish Button
            Row(
              children: [
                // --- Photo Trigger ---
                InkWell(
                  onTap: () => onCreateUpdate(),
                  borderRadius: BorderRadius.circular(12),
                  child: _ComposerChip(
                    icon: Icons.image_outlined,
                    label: 'Photo',
                    background: context.appColors.accentSoft.withValues(
                      alpha: 0.5,
                    ),
                    color: context.appColors.accentSoftText,
                  ),
                ),

                const SizedBox(width: 8),

                // --- Feeling Trigger ---
                InkWell(
                  onTap: () => onCreateUpdate(),
                  borderRadius: BorderRadius.circular(12),
                  child: _ComposerChip(
                    icon: Icons.sentiment_satisfied_alt_outlined,
                    label: 'Feeling',
                    background: context.appColors.warningSoft.withValues(
                      alpha: 0.5,
                    ),
                    color: context.appColors.warningText,
                  ),
                ),

                const Spacer(),

                // --- The "Publish" Button ---
                SizedBox(
                  height: 28,
                  child: FilledButton(
                    onPressed: null,
                    style: FilledButton.styleFrom(
                      backgroundColor: context.appColors.brand,
                      disabledBackgroundColor: context.appColors.brand
                          .withValues(alpha: 0.55),
                      foregroundColor: Colors.white,
                      disabledForegroundColor: Colors.white.withValues(
                        alpha: 0.92,
                      ),
                      elevation: 0,
                      side: BorderSide(
                        color: context.appColors.brand.withValues(alpha: 0.2),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Post',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(width: 6),
                        Icon(Icons.arrow_forward_rounded, size: 14),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ComposerChip extends StatelessWidget {
  const _ComposerChip({
    required this.icon,
    required this.label,
    required this.background,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color background;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuoteGrid extends StatelessWidget {
  const _QuoteGrid({required this.quotes, required this.onOpenQuote});

  final List<QuoteCard> quotes;
  final Future<void> Function(QuoteCard quote) onOpenQuote;

  @override
  Widget build(BuildContext context) {
    if (quotes.isEmpty) {
      return const SizedBox.shrink();
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: quotes.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1,
      ),
      itemBuilder: (context, index) {
        final quote = quotes[index];

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => onOpenQuote(quote),
            borderRadius: BorderRadius.circular(18),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (quote.photoUrl.isNotEmpty)
                    AppNetworkImage(
                      imageUrl: quote.photoUrl,
                      fit: BoxFit.cover,
                      backgroundColor: context.appColors.surfaceMuted,
                      // placeholderLabel: quote.title,
                    )
                  else
                    Container(color: const Color(0xFF3D5AFE)),
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Color.fromRGBO(0, 0, 0, 0.82),
                          Color.fromRGBO(0, 0, 0, 0.12),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 12,
                    child: Text(
                      quote.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _QuoteFullscreenViewer extends StatelessWidget {
  const _QuoteFullscreenViewer({
    required this.quote,
    required this.onViewPost,
  });

  final QuoteCard quote;
  final Future<void> Function() onViewPost;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (quote.photoUrl.isNotEmpty)
              AppNetworkImage(
                imageUrl: quote.photoUrl,
                fit: BoxFit.contain,
                backgroundColor: colors.surfaceMuted,
              )
            else
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF273469), Color(0xFF3D5AFE)],
                  ),
                ),
              ),
            Positioned(
              top: 8,
              left: 0,
              right: 0,
              child: Center(
                child: FilledButton.tonalIcon(
                  onPressed: () async {
                    await onViewPost();
                  },
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: const Text('View Post'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.22),
                    foregroundColor: Colors.white,
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.28),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              left: 10,
              child: IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withValues(alpha: 0.35),
                ),
                icon: const Icon(Icons.close_rounded, color: Colors.white),
              ),
            ),
            Positioned(
              left: 18,
              right: 18,
              bottom: 30,
              child: Text(
                quote.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  height: 1.35,
                  shadows: [
                    Shadow(
                      color: Color.fromRGBO(0, 0, 0, 0.55),
                      blurRadius: 10,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BirthdayCelebrationCard extends StatelessWidget {
  const _BirthdayCelebrationCard({
    required this.users,
    required this.onOpenProfile,
    required this.onViewAll,
  });

  final List<FeedUser> users;
  final Future<void> Function(String username) onOpenProfile;
  final Future<void> Function() onViewAll;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final previewUsers = users.take(5).toList();
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header remains consistent with your padding
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: _SectionHeader(
              title: 'Today\'s Birthdays',
              accent: '🎂',
              action: 'View all',
              onActionTap: () => onViewAll(),
            ),
          ),

          // Community Text - Slightly tighter padding
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              users.length == 1
                  ? 'Someone in the HopefulMe community is celebrating today.'
                  : '${users.length} people are celebrating their big day!',
              style: TextStyle(
                color: colors.textSecondary.withValues(alpha: 0.7),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Horizontal Scroll for a "Story" feel
          SizedBox(
            height: 130, // Fixed height for the scroll area
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: previewUsers.length,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final user = previewUsers[index];
                return InkWell(
                  onTap: () => onOpenProfile(user.username),
                  borderRadius: BorderRadius.circular(16),
                  child: Column(
                    children: [
                      // Avatar with a "Celebration Ring"
                      Container(
                        padding: const EdgeInsets.all(
                          2.5,
                        ), // The "Ring" thickness
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFFFF4D6D), // Your Like Red
                              context.appColors.brand, // Your Brand Blue
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            shape: BoxShape.circle,
                          ),
                          child: CircleAvatar(
                            radius: 28,
                            backgroundImage: user.photoUrl.isNotEmpty
                                ? NetworkImage(
                                    ImageUrlResolver.avatar(
                                      user.photoUrl,
                                      size: 80,
                                    ),
                                  )
                                : null,
                            child: user.photoUrl.isEmpty
                                ? const Icon(Icons.person)
                                : null,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Name - Using your established w800 weight
                      VerifiedNameText(
                        name: user.displayName.split(
                          ' ',
                        )[0], // Only first name for space
                        verified: user.isVerified,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),

                      // Subtext
                      Text(
                        user.cityState.isNotEmpty
                            ? user.cityState
                            : '@${user.username}',
                        maxLines: 1,
                        style: TextStyle(
                          color: colors.textMuted.withValues(alpha: 0.8),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _BirthdayCelebrationStrip extends StatelessWidget {
  const _BirthdayCelebrationStrip({
    required this.users,
    required this.onOpenProfile,
    required this.onViewAll,
  });

  final List<FeedUser> users;
  final Future<void> Function(String username) onOpenProfile;
  final Future<void> Function() onViewAll;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final previewUsers = users.take(10).toList();
    final leadName = users.first.displayName;
    final othersCount = users.length - 1;

    return _SurfaceCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Row(
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
                ),
                InkWell(
                  onTap: () => onViewAll(),
                  borderRadius: BorderRadius.circular(999),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Text(
                      'View All',
                      style: TextStyle(
                        color: Color(0xFF3D5AFE),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
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
                        onTap: () =>
                            onOpenProfile(previewUsers[index].username),
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
                            child: AppNetworkImage(
                              imageUrl: previewUsers[index].photoUrl.isNotEmpty
                                  ? ImageUrlResolver.avatar(
                                      previewUsers[index].photoUrl,
                                      size: 60,
                                    )
                                  : '',
                              width: 44,
                              height: 44,
                              backgroundColor: colors.surfaceMuted,
                              placeholderLabel: previewUsers[index].displayName,
                              placeholderIcon: Icons.person,
                              showShimmer: false,
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

class _FeedEntryCard extends StatelessWidget {
  const _FeedEntryCard({
    required this.entry,
    required this.currentUser,
    required this.onOpenProfile,
    required this.onOpenUpdate,
    required this.onOpenComment,
    required this.onOpenPost,
    required this.onOpenBlog,
    required this.onOpenHashtag,
    required this.onOpenLink,
    required this.updateRepository,
  });

  final FeedEntry entry;
  final User? currentUser;
  final Future<void> Function(String username) onOpenProfile;
  final Future<void> Function(FeedEntry entry) onOpenUpdate;
  final Future<void> Function(FeedEntry entry) onOpenComment;
  final Future<void> Function(FeedEntry entry) onOpenPost;
  final Future<void> Function(FeedEntry entry) onOpenBlog;
  final Future<void> Function(String hashtag) onOpenHashtag;
  final Future<void> Function(String url) onOpenLink;
  final UpdateRepository updateRepository;

  @override
  Widget build(BuildContext context) {
    if (entry.type == 'advert') {
      return FeedAdvertCard(entry: entry);
    }

    if (entry.type == 'post' || entry.type == 'blog') {
      return _PostFeedCard(
        entry: entry,
        onOpenPost: onOpenPost,
        onOpenProfile: onOpenProfile,
        onOpenHashtag: onOpenHashtag,
        onOpenLink: onOpenLink,
      );
    }

    return _UpdateFeedCard(
      entry: entry,
      currentUser: currentUser,
      onOpenProfile: onOpenProfile,
      onOpenUpdate: onOpenUpdate,
      onOpenComment: onOpenComment,
      onOpenHashtag: onOpenHashtag,
      onOpenLink: onOpenLink,
      updateRepository: updateRepository,
    );
  }
}

class _HighlightFrame extends StatelessWidget {
  const _HighlightFrame({required this.isHighlighted, required this.child});

  final bool isHighlighted;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final decoration = BoxDecoration(
      color: isHighlighted
          ? colors.brand.withValues(alpha: 0.08)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(
        color: isHighlighted
            ? colors.brand.withValues(alpha: 0.35)
            : Colors.transparent,
      ),
    );

    if (!isHighlighted) {
      return Container(
        padding: const EdgeInsets.all(4),
        decoration: decoration,
        child: child,
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
      padding: const EdgeInsets.all(4),
      decoration: decoration,
      child: child,
    );
  }
}

class _PostFeedCard extends StatelessWidget {
  const _PostFeedCard({
    required this.entry,
    required this.onOpenPost,
    required this.onOpenProfile,
    required this.onOpenHashtag,
    required this.onOpenLink,
  });

  final FeedEntry entry;
  final Future<void> Function(FeedEntry entry) onOpenPost;
  final Future<void> Function(String username) onOpenProfile;
  final Future<void> Function(String hashtag) onOpenHashtag;
  final Future<void> Function(String url) onOpenLink;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (entry.photoUrl.isNotEmpty)
            InkWell(
              onTap: () => onOpenPost(entry),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(26),
                ),
                child: AppNetworkImage(
                  imageUrl: entry.photoUrl,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholderLabel: entry.title,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (entry.body.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  RichDisplayText(
                    text: entry.body,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.textMuted,
                      fontSize: 14,
                      height: 1.55,
                    ),
                    onMentionTap: onOpenProfile,
                    onHashtagTap: onOpenHashtag,
                    onLinkTap: onOpenLink,
                  ),
                ],
                const SizedBox(height: 18),
                InkWell(
                  onTap: () => onOpenPost(entry),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3D5AFE),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'View Post',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
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

class _UpdateFeedCard extends StatelessWidget {
  const _UpdateFeedCard({
    required this.entry,
    required this.currentUser,
    required this.onOpenProfile,
    required this.onOpenUpdate,
    required this.onOpenComment,
    required this.onOpenHashtag,
    required this.onOpenLink,
    required this.updateRepository,
  });

  final FeedEntry entry;
  final User? currentUser;
  final Future<void> Function(String username) onOpenProfile;
  final Future<void> Function(FeedEntry entry) onOpenUpdate;
  final Future<void> Function(FeedEntry entry) onOpenComment;
  final Future<void> Function(String hashtag) onOpenHashtag;
  final Future<void> Function(String url) onOpenLink;
  final UpdateRepository updateRepository;

  @override
  Widget build(BuildContext context) {
    final entry = this.entry;
    return RepaintBoundary(
      child: InteractiveUpdateCard(
        key: ValueKey('home-update-${entry.id}-${entry.createdAt}'),
        updateId: entry.id,
        updateType: entry.updateType,
        title: entry.user?.displayName ?? entry.title,
        body: entry.body,
        photoUrl: entry.photoUrl,
        avatarUrl: entry.user?.photoUrl ?? '',
        fallbackLabel: entry.user?.displayName ?? entry.title,
        isVerified: entry.user?.isVerified ?? false,
        device: entry.device,
        createdAt: entry.createdAt,
        likesCount: entry.likesCount,
        commentsCount: entry.commentsCount,
        views: entry.views,
        updateRepository: updateRepository,
        onOpenUpdate: () => onOpenUpdate(entry),
        onOpenComment: () => onOpenComment(entry),
        currentUser: currentUser,
        ownerUsername: entry.user?.username,
        onOpenProfile: onOpenProfile,
        onOpenHashtag: onOpenHashtag,
        onOpenLink: onOpenLink,
        isLiked: entry.isLiked,
        myReaction: entry.myReaction,
        reactionsPreview: entry.reactionsPreview,
      ),
    );
  }
}

// Reserved for potential future dedicated blog card styling on Home.
class _BlogFeedCard extends StatelessWidget {
  const _BlogFeedCard({
    required this.entry,
    required this.onOpenProfile,
    required this.onOpenBlog,
    required this.onOpenHashtag,
  });

  final FeedEntry entry;
  final Future<void> Function(String username) onOpenProfile;
  final Future<void> Function(FeedEntry entry) onOpenBlog;
  final Future<void> Function(String hashtag) onOpenHashtag;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return InkWell(
      onTap: () => onOpenBlog(entry),
      borderRadius: BorderRadius.circular(26),
      child: _SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (entry.photoUrl.isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(26),
                ),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: AppNetworkImage(
                    imageUrl: entry.photoUrl,
                    fit: BoxFit.cover,
                    placeholderLabel: entry.title,
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF1FF),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'BLOG',
                          style: TextStyle(
                            color: Color(0xFF3D5AFE),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        formatRelativeTimestamp(entry.createdAt).isEmpty
                            ? 'Article'
                            : 'Article · ${formatRelativeTimestamp(entry.createdAt)}',
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    entry.title,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (entry.body.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    RichDisplayText(
                      text: entry.body,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textMuted,
                        fontSize: 14,
                        height: 1.55,
                      ),
                      onMentionTap: onOpenProfile,
                      onHashtagTap: onOpenHashtag,
                      // onLinkTap removed to avoid mismatch with InteractiveUpdateCard
                    ),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      InkWell(
                        onTap: entry.user == null
                            ? null
                            : () => onOpenProfile(entry.user!.username),
                        borderRadius: BorderRadius.circular(999),
                        child: _Avatar(
                          imageUrl: entry.user?.photoUrl ?? '',
                          label: entry.user?.displayName ?? entry.title,
                          radius: 14,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: InkWell(
                          onTap: entry.user == null
                              ? null
                              : () => onOpenProfile(entry.user!.username),
                          borderRadius: BorderRadius.circular(10),
                          child: VerifiedNameText(
                            name: entry.user?.displayName ?? 'HopefulMe',
                            verified: entry.user?.isVerified ?? false,
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(
                            Icons.remove_red_eye_outlined,
                            size: 14,
                            color: Color(0xFF94A3B8),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${entry.views}',
                            style: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
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

// Kept for possible future grouped feed navigation UI.
class _FeedExploreMoreCard extends StatelessWidget {
  const _FeedExploreMoreCard({
    required this.onOpenUpdatesFeed,
    required this.onOpenPostsFeed,
    required this.onOpenBlogsFeed,
  });

  final Future<void> Function() onOpenUpdatesFeed;
  final Future<void> Function({String initialCategory}) onOpenPostsFeed;
  final Future<void> Function() onOpenBlogsFeed;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return _SurfaceCard(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Explore more',
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Open the full pages for activities, posts and blogs from here.',
              style: TextStyle(
                color: colors.textMuted,
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _FeedExploreChip(
                  icon: Icons.dynamic_feed_rounded,
                  label: 'More updates',
                  onTap: onOpenUpdatesFeed,
                ),
                _FeedExploreChip(
                  icon: Icons.article_outlined,
                  label: 'More posts',
                  onTap: () => onOpenPostsFeed(initialCategory: 'All'),
                ),
                _FeedExploreChip(
                  icon: Icons.auto_stories_outlined,
                  label: 'More blogs',
                  onTap: onOpenBlogsFeed,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedExploreChip extends StatelessWidget {
  const _FeedExploreChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return InkWell(
      onTap: () => onTap(),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: colors.borderStrong),
          boxShadow: [
            BoxShadow(
              color: colors.shadow.withValues(alpha: 0.025),
              blurRadius: 8,
              offset: const Offset(0, 3),
              spreadRadius: -6,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: colors.brand),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: colors.textPrimary,
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

class _HomeGroupsPreviewCard extends StatelessWidget {
  const _HomeGroupsPreviewCard({
    required this.groups,
    required this.onOpenGroups,
    required this.onOpenGroup,
  });

  final List<AppGroup> groups;
  final Future<void> Function() onOpenGroups;
  final Future<void> Function(AppGroup group) onOpenGroup;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return _SurfaceCard(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Group Chats',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                InkWell(
                  onTap: () => onOpenGroups(),
                  borderRadius: BorderRadius.circular(999),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 4,
                    ),
                    child: Text(
                      'See All',
                      style: TextStyle(
                        color: colors.brand,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...groups.map(
              (group) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  onTap: () => onOpenGroup(group),
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        if (group.photoUrl.isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(11),
                            child: SizedBox(
                              width: 40,
                              height: 40,
                              child: AppNetworkImage(
                                imageUrl: group.photoUrl,
                                fit: BoxFit.cover,
                                placeholderLabel: group.name,
                              ),
                            ),
                          )
                        else
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              gradient: colors.brandGradient,
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: const Icon(
                              Icons.groups_2_outlined,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                group.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: colors.textPrimary,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                group.info.trim().isNotEmpty
                                    ? group.info
                                    : 'Join the conversation',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: colors.textMuted,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: colors.accentSoft,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            group.isMember ? 'Open' : 'Join',
                            style: TextStyle(
                              color: colors.brand,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfilePhotoReminderCard extends StatelessWidget {
  const _ProfilePhotoReminderCard({required this.user, required this.onTap});

  final User user;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return _SurfaceCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add a profile photo to complete your profile, get more followers, and make it easier for people to find you in the community',
                  style: TextStyle(
                    color: colors.textMuted,
                    fontSize: 12,
                    height: 1.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    onPressed: () => onTap(),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      minimumSize: const Size(0, 34),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    icon: const Icon(Icons.photo_camera_outlined, size: 15),
                    label: const Text('Upload Photo'),
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

class _RightRail extends StatelessWidget {
  const _RightRail({
    required this.user,
    required this.dashboard,
    required this.onOpenProfile,
  });

  final User? user;
  final FeedDashboard? dashboard;
  final Future<void> Function(String username) onOpenProfile;

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.action,
    this.actionAsText = false,
    this.accent,
    this.eyebrow,
    this.leading,
    this.icon,
    this.onActionTap,
  });

  final String title;
  final String? action;
  final bool actionAsText;
  final String? accent;
  final String? eyebrow;
  final Widget? leading;
  final IconData? icon;
  final VoidCallback? onActionTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (eyebrow != null && eyebrow!.trim().isNotEmpty) ...[
          Text(
            eyebrow!,
            style: TextStyle(
              color: colors.textMuted,
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 6),
        ],
        Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 10)],
            if (icon != null && leading == null) ...[
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: colors.brand.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colors.brand.withValues(alpha: 0.08),
                  ),
                ),
                child: Icon(icon, color: colors.brand, size: 18),
              ),
              const SizedBox(width: 10),
            ],
            if (accent != null) ...[
              Text(accent!, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  height: 1.05,
                ),
              ),
            ),
            if (action != null)
              InkWell(
                onTap: onActionTap,
                borderRadius: BorderRadius.circular(999),
                child: actionAsText
                    ? Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 2,
                          vertical: 6,
                        ),
                        child: Text(
                          action!,
                          style: TextStyle(
                            color: colors.brand,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      )
                    : Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: colors.borderStrong),
                        ),
                        child: Text(
                          action!,
                          style: TextStyle(
                            color: colors.brand,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
              ),
          ],
        ),
      ],
    );
  }
}

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: colors.borderStrong),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
            spreadRadius: -6,
          ),
        ],
      ),
      child: child,
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.imageUrl,
    required this.label,
    this.radius = 18,
    this.backgroundColor,
  });

  final String imageUrl;
  final String label;
  final double radius;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final initials = _initials(label);

    return AppAvatar(
      imageUrl: imageUrl,
      label: initials,
      radius: radius,
      backgroundColor: backgroundColor ?? context.appColors.avatarPlaceholder,
    );
  }

  static String _initials(String input) {
    final parts = input
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty);
    if (parts.isEmpty) {
      return 'U';
    }

    final letters = parts.take(2).map((part) => part[0].toUpperCase()).join();
    return letters.isEmpty ? 'U' : letters;
  }
}
