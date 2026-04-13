import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:hopefulme_flutter/app/theme/app_theme.dart';
import 'package:hopefulme_flutter/app/theme/theme_controller.dart';
import 'package:hopefulme_flutter/core/config/app_config.dart';
import 'package:hopefulme_flutter/core/navigation/app_deep_link_navigator.dart';
import 'package:hopefulme_flutter/core/navigation/app_route_observer.dart';
import 'package:hopefulme_flutter/core/network/api_client.dart';
import 'package:hopefulme_flutter/core/presentation/screens/web_page_screen.dart';
import 'package:hopefulme_flutter/core/services/onesignal_service.dart';
import 'package:hopefulme_flutter/core/storage/page_cache.dart';
import 'package:hopefulme_flutter/core/storage/token_storage.dart';
import 'package:hopefulme_flutter/features/auth/data/auth_repository.dart';
import 'package:hopefulme_flutter/features/auth/presentation/controllers/auth_controller.dart';
import 'package:hopefulme_flutter/features/auth/presentation/screens/auth_welcome_screen.dart';
import 'package:hopefulme_flutter/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:hopefulme_flutter/features/auth/presentation/screens/login_screen.dart';
import 'package:hopefulme_flutter/features/auth/presentation/screens/reset_password_screen.dart';
import 'package:hopefulme_flutter/features/auth/presentation/screens/register_screen.dart';
import 'package:hopefulme_flutter/features/content/data/content_repository.dart';
import 'package:hopefulme_flutter/features/feed/data/feed_repository.dart';
import 'package:hopefulme_flutter/features/feed/presentation/screens/home_screen.dart';
import 'package:hopefulme_flutter/features/groups/data/group_repository.dart';
import 'package:hopefulme_flutter/features/messages/data/message_repository.dart';
import 'package:hopefulme_flutter/features/messages/presentation/screens/message_thread_screen.dart';
import 'package:hopefulme_flutter/features/notifications/data/notification_repository.dart';
import 'package:hopefulme_flutter/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:hopefulme_flutter/features/profile/data/profile_repository.dart';
import 'package:hopefulme_flutter/features/profile/presentation/screens/edit_profile_screen.dart';
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
  bool _isPresenceTrackingActive = false;
  bool _isPresencePingInFlight = false;
  bool _hasShownSoftUpdatePromptThisSession = false;
  bool _isVersionCheckInFlight = false;

  // Keep the version check responsive without hitting the endpoint too often.
  DateTime? _lastVersionCheck;
  static const Duration _versionCheckCooldown = Duration(minutes: 5);

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
      unawaited(_checkAppVersion(force: true));
    });
  }

  // ── Version Check ────────────────────────────────────────────────────────

  Future<void> _checkAppVersion({bool force = false}) async {
    if (_isVersionCheckInFlight) return;

    final now = DateTime.now();
    if (!force &&
        _lastVersionCheck != null &&
        now.difference(_lastVersionCheck!) < _versionCheckCooldown) {
      return;
    }
    _isVersionCheckInFlight = true;

    try {
      _lastVersionCheck = now;
      final response = await http
          .get(Uri.parse('${_config.baseUrl}/api/app/version'))
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final minimumVersion = data['minimum_version']?.toString() ?? '0.0.0';
      final forceUpdate = data['force_update'] == true;
      final storeUrl = data['store_url']?.toString() ?? '';
      final message = data['message']?.toString() ??
          'A new version of Hopeful Me is available. Please update to continue.';

      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      if (_isOutdated(currentVersion, minimumVersion)) {
        final context = _navigatorKey.currentContext;
        if (context != null && context.mounted) {
          if (forceUpdate) {
            _showForceUpdateDialog(context, storeUrl, message);
          } else if (!_hasShownSoftUpdatePromptThisSession) {
            _hasShownSoftUpdatePromptThisSession = true;
            _showSoftUpdateDialog(context, storeUrl, message);
          }
        }
      }
    } catch (e) {
      // Silently fail — never block the app over a version check
      if (kDebugMode) {
        debugPrint('Version check failed: $e');
      }
    } finally {
      _isVersionCheckInFlight = false;
    }
  }

  bool _isOutdated(String current, String minimum) {
    try {
      final c = current.split('.').map(int.parse).toList();
      final m = minimum.split('.').map(int.parse).toList();

      // Pad to same length
      while (c.length < 3) {
        c.add(0);
      }
      while (m.length < 3) {
        m.add(0);
      }

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
        onNotificationOpened: _handleOneSignalNotificationTap,
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
      unawaited(_checkAppVersion(force: true));
    } else {
      OneSignalService.instance.removeExternalUserId();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycleState = state;
    _syncPresenceTracking();

    if (state == AppLifecycleState.resumed) {
      unawaited(_checkAppVersion());
    }
  }

  void _syncPresenceTracking() {
    final isForeground =
        _lifecycleState == null || _lifecycleState == AppLifecycleState.resumed;
    final shouldTrack = _authController.isAuthenticated && isForeground;

    if (_isPresenceTrackingActive == shouldTrack) {
      return;
    }
    _isPresenceTrackingActive = shouldTrack;

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
    if (!_authController.isAuthenticated || _isPresencePingInFlight) return;
    _isPresencePingInFlight = true;
    try {
      await _authController.authRepository.pingPresence();
    } catch (_) {
    } finally {
      _isPresencePingInFlight = false;
    }
  }

  Future<void> _handleOneSignalNotificationTap(
    Map<String, dynamic> data,
  ) async {
    final context = _navigatorKey.currentContext;
    if (context == null || !_authController.isAuthenticated) {
      return;
    }

    final type = data['type']?.toString().trim().toLowerCase() ?? '';
    final senderUsername =
        data['sender_username']?.toString().trim().replaceFirst('@', '') ?? '';
    final contentType =
        data['content_type']?.toString().trim().toLowerCase() ?? '';
    final contentId = int.tryParse(data['content_id']?.toString() ?? '') ?? 0;
    final inspirationId =
        int.tryParse(data['inspiration_id']?.toString() ?? '') ?? 0;
    final orderId = int.tryParse(data['order_id']?.toString() ?? '') ?? 0;

    switch (type) {
      case 'follow':
      case 'referral_joined':
        if (senderUsername.isNotEmpty) {
          await _openDeepLink(context, Uri(path: '/$senderUsername'));
          return;
        }
        break;
      case 'message':
        if (senderUsername.isNotEmpty) {
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (context) => MessageThreadScreen(
                repository: _messageRepository,
                profileRepository: _profileRepository,
                updateRepository: _updateRepository,
                currentUser: _authController.currentUser,
                username: senderUsername,
                title: senderUsername,
              ),
            ),
          );
          return;
        }
        break;
      case 'comment':
      case 'like':
      case 'mention':
        final targetUri = _contentNotificationUri(
          contentType: contentType,
          contentId: contentId,
        );
        if (targetUri != null) {
          await _openDeepLink(context, targetUri);
          return;
        }
        break;
      case 'inspiration':
        await _openDeepLink(
          context,
          inspirationId > 0
              ? Uri(path: '/inspire/$inspirationId')
              : Uri(path: '/inspire/inbox'),
        );
        return;
      case 'welcome':
        final user = _authController.currentUser;
        if (user != null) {
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (context) => EditProfileScreen(
                username: user.username,
                repository: _profileRepository,
              ),
            ),
          );
          return;
        }
        break;
      case 'account_verified':
        final username = _authController.currentUser?.username ?? '';
        if (username.isNotEmpty) {
          await _openDeepLink(context, Uri(path: '/$username'));
          return;
        }
        break;
      case 'store_order':
      case 'store_order_placed':
        if (orderId > 0) {
          await _openSignedWebPage(
            context,
            title: 'Order Details',
            path: '/store/order-page/$orderId',
          );
          return;
        }
        break;
    }

    await _openNotificationsScreen();
  }

  Uri? _contentNotificationUri({
    required String contentType,
    required int contentId,
  }) {
    if (contentId <= 0) {
      return null;
    }

    return switch (contentType) {
      'update' => Uri(path: '/social/$contentId'),
      'post' => Uri(path: '/post/$contentId'),
      'blog' => Uri(path: '/blog/$contentId'),
      _ => null,
    };
  }

  Future<void> _openNotificationsScreen() {
    final context = _navigatorKey.currentContext;
    if (context == null) {
      return Future<void>.value();
    }
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => NotificationsScreen(
          repository: _notificationRepository,
          profileRepository: _profileRepository,
          contentRepository: _contentRepository,
          messageRepository: _messageRepository,
          searchRepository: _searchRepository,
          updateRepository: _updateRepository,
          currentUser: _authController.currentUser,
        ),
      ),
    );
  }

  void _showSoftUpdateDialog(
    BuildContext context,
    String storeUrl,
    String message,
  ) {
    final colors = context.appColors;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Icon(Icons.system_update_alt_rounded, color: colors.brand),
            const SizedBox(width: 10),
            const Text('Update Available'),
          ],
        ),
        content: Text(
          message,
          style: TextStyle(color: colors.textMuted, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Later'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: colors.brand,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: () async {
              Navigator.of(context).pop();
              if (storeUrl.isEmpty) return;
              final uri = Uri.parse(storeUrl);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            child: const Text(
              'Update',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openSignedWebPage(
    BuildContext context, {
    required String title,
    required String path,
  }) async {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    var targetUrl = '${_config.webBaseUrl}$normalizedPath';

    try {
      final bridgedUrl = await _authController.authRepository.createWebSessionUrl(
        targetUrl,
      );
      if (bridgedUrl.trim().isNotEmpty) {
        targetUrl = bridgedUrl.trim();
      }
    } catch (_) {
      // Fall back to the direct web URL if the bridge request fails.
    }

    if (!context.mounted) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => WebPageScreen(title: title, url: targetUrl),
      ),
    );
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
    if (_pendingDeepLink == null || _isHandlingDeepLink) {
      return;
    }

    final uri = _pendingDeepLink!;
    final allowsLoggedOut = _canOpenDeepLinkWhileLoggedOut(uri);
    if (!_authController.isAuthenticated && !allowsLoggedOut) {
      return;
    }

    final context = _navigatorKey.currentContext;
    if (context == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _drainPendingDeepLink();
      });
      return;
    }

    _pendingDeepLink = null;
    _isHandlingDeepLink = true;

    unawaited(
      (_authController.isAuthenticated
              ? _openDeepLink(context, uri)
              : _openLoggedOutDeepLink(context, uri))
          .whenComplete(() {
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

  bool _canOpenDeepLinkWhileLoggedOut(Uri uri) {
    final normalized = _normalizeSupportedDeepLinkUri(uri);
    if (normalized == null) {
      return false;
    }

    return _isResetPasswordUri(normalized);
  }

  Future<void> _openLoggedOutDeepLink(BuildContext context, Uri uri) async {
    final normalized = _normalizeSupportedDeepLinkUri(uri);
    if (normalized == null) {
      return;
    }

    if (_isResetPasswordUri(normalized)) {
      await _openResetPasswordScreen(context, normalized);
    }
  }

  Uri? _normalizeSupportedDeepLinkUri(Uri uri) {
    if (!uri.hasScheme) {
      return uri;
    }

    final configuredHost = Uri.tryParse(_config.webBaseUrl)?.host.toLowerCase();
    final host = uri.host.toLowerCase();
    final allowedHosts = <String>{
      if (configuredHost != null && configuredHost.isNotEmpty) configuredHost,
      'ahopefulme.com',
      'www.ahopefulme.com',
    };

    if (host.isNotEmpty && !allowedHosts.contains(host)) {
      return null;
    }

    return uri;
  }

  bool _isResetPasswordUri(Uri uri) {
    final segments = uri.pathSegments.where((segment) => segment.isNotEmpty);
    return segments.length >= 2 &&
        segments.first.toLowerCase() == 'reset-password';
  }

  Future<void> _openResetPasswordScreen(BuildContext context, Uri uri) {
    final segments = uri.pathSegments.where((segment) => segment.isNotEmpty);
    final token = segments.length >= 2 ? Uri.decodeComponent(segments.elementAt(1)) : '';
    final email = uri.queryParameters['email']?.trim() ?? '';

    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ResetPasswordScreen(
          authRepository: _authController.authRepository,
          resetToken: token,
          initialEmail: email,
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  // FIX 2: Single builder method for HomeScreen so dependencies are only
  // listed once. Previously HomeScreen was constructed in two places (routes
  // map + home property), meaning two instances were created on every
  // MaterialApp rebuild and any new dependency had to be added in two spots.
  HomeScreen _buildHomeScreen() {
    return HomeScreen(
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
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // FIX 3: Split the AnimatedBuilder so that theme changes only rebuild the
    // MaterialApp shell (which must react to themeMode), while auth-state
    // changes only rebuild the minimal _AppRouter widget that switches between
    // the loading screen, home, and welcome screens.
    //
    // Previously a single AnimatedBuilder wrapped the entire MaterialApp,
    // meaning every authController.notifyListeners() call (including the
    // presence ping every 90 s) caused the whole app — routes, themes,
    // everything — to rebuild from scratch.
    return AnimatedBuilder(
      // Only theme changes need to rebuild MaterialApp.
      animation: _themeController,
      builder: (context, _) {
        return MaterialApp(
          navigatorKey: _navigatorKey,
          navigatorObservers: [appRouteObserver],
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
            // FIX 2: Use the single builder method — no duplication.
            HomeScreen.routeName: (context) => _buildHomeScreen(),
            ProfileScreen.routeName: (context) => ProfileScreen(
                  currentUser: _authController.currentUser,
                  profileRepository: _profileRepository,
                  messageRepository: _messageRepository,
                  updateRepository: _updateRepository,
                ),
          },
          // FIX 3: Auth-state changes now only rebuild this lightweight
          // _AppRouter widget, not the entire MaterialApp.
          home: _AppRouter(
            authController: _authController,
            buildHomeScreen: _buildHomeScreen,
            buildWelcomeScreen: () =>
                AuthWelcomeScreen(authController: _authController),
          ),
        );
      },
    );
  }
}

// FIX 3: Dedicated router widget that listens to authController and switches
// between the loading/home/welcome screens. Its rebuilds are completely
// isolated from the MaterialApp and from theme changes.
class _AppRouter extends StatelessWidget {
  const _AppRouter({
    required this.authController,
    required this.buildHomeScreen,
    required this.buildWelcomeScreen,
  });

  final AuthController authController;
  final HomeScreen Function() buildHomeScreen;
  final Widget Function() buildWelcomeScreen;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: authController,
      builder: (context, _) {
        if (authController.isBootstrapping) {
          return const _AppLoadingScreen();
        }
        if (authController.isAuthenticated) {
          return buildHomeScreen();
        }
        return buildWelcomeScreen();
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
      body: Stack(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/images/app-icon.png',
                    width: 108,
                    height: 108,
                    fit: BoxFit.contain,
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 26),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      AppConfig.appName,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colors.brand,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.8,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Inspire the world around you',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.orange,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
