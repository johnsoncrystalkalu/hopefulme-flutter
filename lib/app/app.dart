import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:hopefulme_flutter/app/theme/app_theme.dart';
import 'package:hopefulme_flutter/app/theme/theme_controller.dart';
import 'package:hopefulme_flutter/core/config/app_config.dart';
import 'package:hopefulme_flutter/core/navigation/app_deep_link_navigator.dart';
import 'package:hopefulme_flutter/core/network/api_client.dart';
import 'package:hopefulme_flutter/core/storage/page_cache.dart';
import 'package:hopefulme_flutter/core/storage/token_storage.dart';
import 'package:hopefulme_flutter/features/auth/data/auth_repository.dart';
import 'package:hopefulme_flutter/features/auth/presentation/controllers/auth_controller.dart';
import 'package:hopefulme_flutter/features/auth/presentation/screens/auth_welcome_screen.dart';
import 'package:hopefulme_flutter/features/auth/presentation/screens/login_screen.dart';
import 'package:hopefulme_flutter/features/auth/presentation/screens/register_screen.dart';
import 'package:hopefulme_flutter/features/content/data/content_repository.dart';
import 'package:hopefulme_flutter/features/feed/data/feed_repository.dart';
import 'package:hopefulme_flutter/features/feed/presentation/screens/home_screen.dart';
import 'package:hopefulme_flutter/features/groups/data/group_repository.dart';
import 'package:hopefulme_flutter/features/messages/data/message_repository.dart';
import 'package:hopefulme_flutter/features/notifications/data/notification_repository.dart';
import 'package:hopefulme_flutter/features/profile/data/profile_repository.dart';
import 'package:hopefulme_flutter/features/profile/presentation/screens/profile_screen.dart';
import 'package:hopefulme_flutter/features/search/data/search_repository.dart';
import 'package:hopefulme_flutter/features/updates/data/update_repository.dart';
import 'package:hopefulme_flutter/features/library/data/library_repository.dart';

class HopefulMeApp extends StatefulWidget {
  const HopefulMeApp({super.key});

  @override
  State<HopefulMeApp> createState() => _HopefulMeAppState();
}

class _HopefulMeAppState extends State<HopefulMeApp>
    with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  late final AuthController _authController;
  late final ThemeController _themeController;
  late final FeedRepository _feedRepository;
  late final ContentRepository _contentRepository;
  late final ProfileRepository _profileRepository;
  late final NotificationRepository _notificationRepository;
  late final MessageRepository _messageRepository;
  late final GroupRepository _groupRepository;
  late final UpdateRepository _updateRepository;
  late final SearchRepository _searchRepository;
  late final LibraryRepository _libraryRepository;
  late final AppConfig _config;
  Timer? _presenceTimer;
  StreamSubscription<Uri>? _deepLinkSubscription;
  AppLifecycleState? _lifecycleState;
  Uri? _pendingDeepLink;
  bool _isHandlingDeepLink = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _themeController = ThemeController()..restore();
    _config = AppConfig.fromEnvironment();
    final tokenStorage = TokenStorage();
    final pageCache = PageCache();
    final apiClient = ApiClient(
      baseUrl: _config.baseUrl,
      tokenStorage: tokenStorage,
    );

    _authController = AuthController(authRepository: AuthRepository(apiClient))
      ..restoreSession();
    _feedRepository = FeedRepository(
      _authController.authRepository,
      cache: pageCache,
    );
    _contentRepository = ContentRepository(
      _authController.authRepository,
      cache: pageCache,
    );
    _profileRepository = ProfileRepository(_authController.authRepository);
    _notificationRepository = NotificationRepository(
      _authController.authRepository,
      cache: pageCache,
    );
    _messageRepository = MessageRepository(
      _authController.authRepository,
      cache: pageCache,
    );
    _groupRepository = GroupRepository(_authController.authRepository);
    _updateRepository = UpdateRepository(_authController.authRepository);
    _searchRepository = SearchRepository(_authController.authRepository);
    _libraryRepository = LibraryRepository(
      _authController.authRepository,
      cache: pageCache,
    );
    _authController.addListener(_syncPresenceTracking);
    _authController.addListener(_drainPendingDeepLink);
    unawaited(_initDeepLinks());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authController.removeListener(_syncPresenceTracking);
    _authController.removeListener(_drainPendingDeepLink);
    _presenceTimer?.cancel();
    _deepLinkSubscription?.cancel();
    _themeController.dispose();
    _authController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycleState = state;
    _syncPresenceTracking();
  }

  void _syncPresenceTracking() {
    final isForeground =
        _lifecycleState == null || _lifecycleState == AppLifecycleState.resumed;
    final shouldTrack = _authController.isAuthenticated && isForeground;

    if (!shouldTrack) {
      _presenceTimer?.cancel();
      _presenceTimer = null;
      return;
    }

    _presenceTimer ??= Timer.periodic(
      const Duration(seconds: 90),
      (_) => unawaited(_pingPresence()),
    );

    unawaited(_pingPresence());
  }

  Future<void> _pingPresence() async {
    if (!_authController.isAuthenticated) {
      return;
    }

    try {
      await _authController.authRepository.pingPresence();
    } catch (_) {}
  }

  Future<void> _initDeepLinks() async {
    final appLinks = AppLinks();

    try {
      final initialUri = await appLinks.getInitialLink();
      if (initialUri != null) {
        _queueDeepLink(initialUri);
      }
    } catch (_) {}

    _deepLinkSubscription = appLinks.uriLinkStream.listen(
      _queueDeepLink,
      onError: (_) {},
    );
  }

  void _queueDeepLink(Uri uri) {
    _pendingDeepLink = uri;
    _drainPendingDeepLink();
  }

  void _drainPendingDeepLink() {
    if (_pendingDeepLink == null ||
        _isHandlingDeepLink ||
        !_authController.isAuthenticated) {
      return;
    }

    final context = _navigatorKey.currentContext;
    if (context == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _drainPendingDeepLink();
        }
      });
      return;
    }

    final uri = _pendingDeepLink!;
    _pendingDeepLink = null;
    _isHandlingDeepLink = true;

    unawaited(
      _openDeepLink(context, uri).whenComplete(() {
        _isHandlingDeepLink = false;
        if (mounted) {
          _drainPendingDeepLink();
        }
      }),
    );
  }

  Future<void> _openDeepLink(BuildContext context, Uri uri) async {
    final navigator = AppDeepLinkNavigator(
      feedRepository: _feedRepository,
      contentRepository: _contentRepository,
      profileRepository: _profileRepository,
      messageRepository: _messageRepository,
      groupRepository: _groupRepository,
      updateRepository: _updateRepository,
      searchRepository: _searchRepository,
      libraryRepository: _libraryRepository,
      currentUser: _authController.currentUser,
      webBaseUrl: _config.webBaseUrl,
    );

    await navigator.open(context, uri);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_authController, _themeController]),
      builder: (context, _) {
        return MaterialApp(
          navigatorKey: _navigatorKey,
          title: AppConfig.appName,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: _themeController.themeMode,
          routes: {
            AuthWelcomeScreen.routeName: (context) =>
                AuthWelcomeScreen(authController: _authController),
            LoginScreen.routeName: (context) =>
                LoginScreen(authController: _authController),
            RegisterScreen.routeName: (context) =>
                RegisterScreen(authController: _authController),
            ProfileScreen.routeName: (context) => ProfileScreen(
              currentUser: _authController.currentUser,
              profileRepository: _profileRepository,
              messageRepository: _messageRepository,
              updateRepository: _updateRepository,
            ),
          },
          home: _authController.isBootstrapping
              ? const _AppLoadingScreen()
              : _authController.isAuthenticated
              ? HomeScreen(
                  authController: _authController,
                  themeController: _themeController,
                  feedRepository: _feedRepository,
                  contentRepository: _contentRepository,
                  notificationRepository: _notificationRepository,
                  messageRepository: _messageRepository,
                  groupRepository: _groupRepository,
                  profileRepository: _profileRepository,
                  searchRepository: _searchRepository,
                  updateRepository: _updateRepository,
                  libraryRepository: _libraryRepository,
                )
              : AuthWelcomeScreen(authController: _authController),
        );
      },
    );
  }
}

class _AppLoadingScreen extends StatelessWidget {
  const _AppLoadingScreen();

  @override
  Widget build(BuildContext context) {
  final colors = context.appColors;
  
  return Scaffold(
    backgroundColor: colors.surface, // Clean background
    body: Center(
      child: Container(
        width: 240, // Slightly wider for better text breathing room
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        decoration: BoxDecoration(
          color: colors.surface.withValues(alpha: 0.8), // Slight transparency
          borderRadius: BorderRadius.circular(32), // More rounded "Apple" corners
          border: Border.all(
            color: colors.border.withValues(alpha: 0.5), 
            width: 0.5, // Ultra-thin border for a refined look
          ),
          boxShadow: [
            BoxShadow(
              color: colors.shadow.withValues(alpha: 0.08),
              blurRadius: 40,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // App Name with Apple-style tight tracking
            Text(
              AppConfig.appName,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.2, // The "Secret Sauce" for high-end UI
              ),
            ),
            
            const SizedBox(height: 32),
            
            // HeroIcon as a custom loader
            const SizedBox(
              height: 28,
              width: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)), // Your brand blue
                backgroundColor: Colors.transparent,
              ),
            ),
            
            const SizedBox(height: 28),
            
            // Refined subtext
            Text(
              'Loading your space...',
              style: TextStyle(
                color: colors.textMuted,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
}
