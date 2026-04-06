import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:hopefulme_flutter/app/theme/app_theme.dart';
import 'package:hopefulme_flutter/app/theme/theme_controller.dart';
import 'package:hopefulme_flutter/core/config/app_config.dart';
import 'package:hopefulme_flutter/core/navigation/app_deep_link_navigator.dart';
import 'package:hopefulme_flutter/core/network/api_client.dart';
import 'package:hopefulme_flutter/core/services/onesignal_service.dart';
import 'package:hopefulme_flutter/core/storage/page_cache.dart';
import 'package:hopefulme_flutter/core/storage/token_storage.dart';
import 'package:hopefulme_flutter/features/auth/data/auth_repository.dart';
import 'package:hopefulme_flutter/features/auth/presentation/controllers/auth_controller.dart';
import 'package:hopefulme_flutter/features/auth/presentation/screens/auth_welcome_screen.dart';
import 'package:hopefulme_flutter/features/auth/presentation/screens/forgot_password_screen.dart';
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
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

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
    _profileRepository = ProfileRepository(
      _authController.authRepository,
      cache: pageCache,
    );
    _notificationRepository = NotificationRepository(
      _authController.authRepository,
      cache: pageCache,
    );
    _messageRepository = MessageRepository(_authController.authRepository);
    _groupRepository = GroupRepository(_authController.authRepository);
    _updateRepository = UpdateRepository(_authController.authRepository);
    _searchRepository = SearchRepository(_authController.authRepository);
    _libraryRepository = LibraryRepository(
      _authController.authRepository,
      cache: pageCache,
    );
    _authController.addListener(_syncPresenceTracking);
    _authController.addListener(_drainPendingDeepLink);
    _authController.addListener(_onAuthStateChanged);
    unawaited(_initDeepLinks());
    unawaited(_initOneSignal());

    // Check for app update after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_checkAppVersion());
    });
  }

  // ── Version Check ────────────────────────────────────────────────────────

  Future<void> _checkAppVersion() async {
    try {
      final response = await http
          .get(Uri.parse('${_config.baseUrl}/app/version'))
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final minimumVersion = data['minimum_version']?.toString() ?? '0.0.0';
      final forceUpdate = data['force_update'] == true;
      final storeUrl = data['store_url']?.toString() ?? '';
      final message = data['message']?.toString() ??
          'A new version of Hopeful Me is available. Please update to continue.';

      if (!forceUpdate) return;

      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      if (_isOutdated(currentVersion, minimumVersion)) {
        final context = _navigatorKey.currentContext;
        if (context != null && context.mounted) {
          _showForceUpdateDialog(context, storeUrl, message);
        }
      }
    } catch (e) {
      // Silently fail — never block the app over a version check
      if (kDebugMode) {
        debugPrint('Version check failed: $e');
      }
    }
  }

  bool _isOutdated(String current, String minimum) {
    try {
      final c = current.split('.').map(int.parse).toList();
      final m = minimum.split('.').map(int.parse).toList();

      // Pad to same length
      while (c.length < 3) c.add(0);
      while (m.length < 3) m.add(0);

      for (int i = 0; i < 3; i++) {
        if (c[i] < m[i]) return true;
        if (c[i] > m[i]) return false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  void _showForceUpdateDialog(
    BuildContext context,
    String storeUrl,
    String message,
  ) {
    final colors = context.appColors;
    showDialog<void>(
      context: context,
      barrierDismissible: false, // user cannot dismiss
      builder: (context) => PopScope(
        canPop: false, // blocks back button
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Row(
            children: [
              Icon(Icons.system_update_rounded, color: colors.brand),
              const SizedBox(width: 10),
              const Text('Update Required'),
            ],
          ),
          content: Text(
            message,
            style: TextStyle(color: colors.textMuted, height: 1.5),
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: colors.brand,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () async {
                  if (storeUrl.isNotEmpty) {
                    final uri = Uri.parse(storeUrl);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  }
                },
                child: const Text(
                  'Update Now',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── OneSignal ────────────────────────────────────────────────────────────

  Future<void> _initOneSignal() async {
    try {
      await OneSignalService.instance.initialize(
        appId: AppConfig.oneSignalAppId,
        navigatorKey: _navigatorKey,
      );

      OneSignalService.instance.addSubscriptionObserver((state) {
        if (state.current.id != null && state.current.optedIn == true) {
          _syncOneSignalPlayerId();
        }
      });

      if (_authController.isAuthenticated) {
        await _syncOneSignalPlayerId();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('OneSignal initialization failed: $e');
      }
    }
  }

  Future<void> _syncOneSignalPlayerId() async {
    if (!_authController.isAuthenticated) return;

    try {
      final user = _authController.currentUser;
      if (user != null) {
        await OneSignalService.instance.setExternalUserId(user.id.toString());
      }

      final playerId = await OneSignalService.instance.getPlayerId();
      if (playerId != null) {
        await _authController.authRepository.registerOneSignalPlayerId(playerId);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to sync OneSignal: $e');
      }
    }
  }

  // ── Lifecycle ────────────────────────────────────────────────────────────

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authController.removeListener(_syncPresenceTracking);
    _authController.removeListener(_drainPendingDeepLink);
    _authController.removeListener(_onAuthStateChanged);
    _presenceTimer?.cancel();
    _deepLinkSubscription?.cancel();
    _themeController.dispose();
    _authController.dispose();
    super.dispose();
  }

  void _onAuthStateChanged() {
    if (_authController.isAuthenticated) {
      _syncOneSignalPlayerId();
    } else {
      OneSignalService.instance.removeExternalUserId();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycleState = state;
    _syncPresenceTracking();

    // Re-check version when app comes back to foreground
    if (state == AppLifecycleState.resumed) {
      unawaited(_checkAppVersion());
    }
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
    if (!_authController.isAuthenticated) return;
    try {
      await _authController.authRepository.pingPresence();
    } catch (_) {}
  }

  // ── Deep Links ───────────────────────────────────────────────────────────

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
        if (mounted) _drainPendingDeepLink();
      });
      return;
    }

    final uri = _pendingDeepLink!;
    _pendingDeepLink = null;
    _isHandlingDeepLink = true;

    unawaited(
      _openDeepLink(context, uri).whenComplete(() {
        _isHandlingDeepLink = false;
        if (mounted) _drainPendingDeepLink();
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

  // ── Build ────────────────────────────────────────────────────────────────

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
            ForgotPasswordScreen.routeName: (context) => ForgotPasswordScreen(
              authRepository: _authController.authRepository,
            ),
            RegisterScreen.routeName: (context) => RegisterScreen(
              authController: _authController,
              profileRepository: _profileRepository,
            ),
            HomeScreen.routeName: (context) => HomeScreen(
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
            ),
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
      backgroundColor: colors.surface,
      body: Center(
        child: Container(
          width: 240,
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
          decoration: BoxDecoration(
            color: colors.surface.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: colors.border.withValues(alpha: 0.5),
              width: 0.5,
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
              Text(
                AppConfig.appName,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.2,
                ),
              ),
              const SizedBox(height: 32),
              const SizedBox(
                height: 28,
                width: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Color(0xFF2563EB),
                  ),
                  backgroundColor: Colors.transparent,
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'Inspire the world around you...',
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
