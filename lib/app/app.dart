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
import 'package:hopefulme_flutter/features/auth/presentation/screens/verify_email_screen.dart';
import 'package:hopefulme_flutter/features/content/data/content_repository.dart';
import 'package:hopefulme_flutter/features/feed/data/feed_repository.dart';
import 'package:hopefulme_flutter/features/feed/presentation/screens/home_screen.dart';
import 'package:hopefulme_flutter/features/groups/data/group_repository.dart';
import 'package:hopefulme_flutter/features/messages/data/message_repository.dart';
import 'package:hopefulme_flutter/features/messages/presentation/screens/messages_screen.dart';
import 'package:hopefulme_flutter/features/messages/presentation/screens/message_thread_screen.dart';
import 'package:hopefulme_flutter/features/notifications/data/notification_repository.dart';
import 'package:hopefulme_flutter/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:hopefulme_flutter/features/profile/data/profile_repository.dart';
import 'package:hopefulme_flutter/features/profile/presentation/screens/edit_profile_screen.dart';
import 'package:hopefulme_flutter/features/profile/presentation/screens/profile_screen.dart';
import 'package:hopefulme_flutter/features/search/data/search_repository.dart';
import 'package:hopefulme_flutter/features/updates/data/update_repository.dart';
import 'package:hopefulme_flutter/features/updates/presentation/screens/update_detail_screen.dart';
import 'package:hopefulme_flutter/features/library/data/library_repository.dart';
import 'package:hopefulme_flutter/features/templates/data/flyer_template_repository.dart';
import 'package:http/http.dart' as http;
import 'package:in_app_review/in_app_review.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class HopefulMeApp extends StatefulWidget {
  const HopefulMeApp({super.key});

  @override
  State<HopefulMeApp> createState() => _HopefulMeAppState();
}

class _HopefulMeAppState extends State<HopefulMeApp>
    with WidgetsBindingObserver {
  static const String _iosAppStoreId = String.fromEnvironment(
    'IOS_APP_STORE_ID',
  );
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
  late final FlyerTemplateRepository _flyerTemplateRepository;
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
  bool _isRatingPromptInFlight = false;
  bool _isHandlingForcedUnauthorizedLogout = false;
  bool _hasTrackedRatingLaunchThisSession = false;
  bool _isHandlingNotificationOpen = false;
  DateTime? _lastNotificationOpenAt;
  String? _lastNotificationOpenFingerprint;

  // Keep the version check responsive without hitting the endpoint too often.
  DateTime? _lastVersionCheck;
  static const Duration _versionCheckCooldown = Duration(minutes: 5);
  static const int _minimumLaunchesForRatingPrompt = 12;
  static const Duration _ratingPromptCooldown = Duration(days: 120);
  static const String _ratingLaunchCountKey = 'rating_prompt_launch_count';
  static const String _ratingLastPromptAtKey = 'rating_prompt_last_prompt_at';
  static const String _ratingCompletedKey = 'rating_prompt_completed';

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
    apiClient.setUnauthorizedHandler(_handleUnauthorizedSession);

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
    _flyerTemplateRepository = FlyerTemplateRepository(
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
      unawaited(_trackRatingLaunchIfNeeded());
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
      // Always ask Play Core for available Android updates first so users can
      // get the native Play Store update flow even when backend minimum version
      // has not been bumped yet.
      final handledByNativeAndroidSoftUpdate = await _tryNativeAndroidUpdate(
        forceUpdate: false,
        allowImmediateFallback: false,
      );
      if (handledByNativeAndroidSoftUpdate) {
        return;
      }
      final apiBaseUrl = _config.baseUrl.replaceFirst(RegExp(r'/+$'), '');
      final versionUri = Uri.parse('$apiBaseUrl/app/version')
          .replace(
            queryParameters: <String, String>{
              'platform': _versionCheckPlatform(),
            },
          );
      final response = await http
          .get(versionUri)
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) {
        if (kDebugMode) {
          debugPrint(
            'Version check non-200: status=${response.statusCode}, uri=$versionUri, body=${response.body}',
          );
        }
        return;
      }
      _lastVersionCheck = now;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final minimumVersion = _resolveMinimumVersion(data);
      final forceUpdate = _resolveForceUpdate(data);
      final storeUrl = _resolveStoreUrl(data);
      final message =
          data['message']?.toString() ??
          'A new version of Hopeful Me is available. Please update to continue.';

      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      if (_isOutdated(currentVersion, minimumVersion)) {
        final handledByNativeAndroidUpdate = await _tryNativeAndroidUpdate(
          forceUpdate: forceUpdate,
          allowImmediateFallback: forceUpdate,
        );
        if (handledByNativeAndroidUpdate) {
          return;
        }

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

  String _versionCheckPlatform() {
    if (kIsWeb) {
      return 'web';
    }
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      _ => 'other',
    };
  }

  String _resolveStoreUrl(Map<String, dynamic> data) {
    String readValue(String key) => data[key]?.toString().trim() ?? '';

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      final iosUrl = readValue('ios_store_url').isNotEmpty
          ? readValue('ios_store_url')
          : readValue('app_store_url').isNotEmpty
          ? readValue('app_store_url')
          : readValue('appstore_url');
      if (iosUrl.isNotEmpty) {
        return iosUrl;
      }
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      final androidUrl = readValue('android_store_url').isNotEmpty
          ? readValue('android_store_url')
          : readValue('play_store_url');
      if (androidUrl.isNotEmpty) {
        return androidUrl;
      }
    }

    return readValue('store_url');
  }

  String _resolveMinimumVersion(Map<String, dynamic> data) {
    String readValue(String key) => data[key]?.toString().trim() ?? '';

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      final iosVersion = readValue('minimum_version_ios');
      if (iosVersion.isNotEmpty) {
        return iosVersion;
      }
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      final androidVersion = readValue('minimum_version_android');
      if (androidVersion.isNotEmpty) {
        return androidVersion;
      }
    }

    final sharedVersion = readValue('minimum_version');
    return sharedVersion.isEmpty ? '0.0.0' : sharedVersion;
  }

  bool _resolveForceUpdate(Map<String, dynamic> data) {
    bool parseBool(dynamic value) => value == true || value?.toString() == '1';

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      final iosFlag = data['force_update_ios'];
      if (iosFlag != null) {
        return parseBool(iosFlag);
      }
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      final androidFlag = data['force_update_android'];
      if (androidFlag != null) {
        return parseBool(androidFlag);
      }
    }

    return parseBool(data['force_update']);
  }

  Future<bool> _tryNativeAndroidUpdate({
    required bool forceUpdate,
    bool allowImmediateFallback = true,
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }

    try {
      final updateInfo = await InAppUpdate.checkForUpdate();
      if (updateInfo.updateAvailability != UpdateAvailability.updateAvailable) {
        return false;
      }

      if (forceUpdate && updateInfo.immediateUpdateAllowed) {
        final result = await InAppUpdate.performImmediateUpdate();
        return result == AppUpdateResult.success;
      }

      if (!forceUpdate && updateInfo.flexibleUpdateAllowed) {
        final result = await InAppUpdate.startFlexibleUpdate();
        if (result == AppUpdateResult.success) {
          await InAppUpdate.completeFlexibleUpdate();
          return true;
        }
      }

      if (allowImmediateFallback && updateInfo.immediateUpdateAllowed) {
        final result = await InAppUpdate.performImmediateUpdate();
        return result == AppUpdateResult.success;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Native Android update failed: $e');
      }
    }

    return false;
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
                      await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                    }
                  }
                },
                child: const Text(
                  'Update Now',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
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
        await _authController.authRepository.registerOneSignalPlayerId(
          playerId,
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to sync OneSignal: $e');
      }
    }
  }

  Future<void> _trackRatingLaunchIfNeeded() async {
    if (_hasTrackedRatingLaunchThisSession ||
        !_authController.isAuthenticated) {
      return;
    }
    _hasTrackedRatingLaunchThisSession = true;
    await _maybePromptForRating(incrementLaunchCount: true);
  }

  bool get _supportsInAppRatingPrompt =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> _maybePromptForRating({
    bool incrementLaunchCount = false,
  }) async {
    if (!_supportsInAppRatingPrompt ||
        !_authController.isAuthenticated ||
        _isRatingPromptInFlight) {
      return;
    }

    _isRatingPromptInFlight = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final alreadyCompleted = prefs.getBool(_ratingCompletedKey) ?? false;
      if (alreadyCompleted) {
        return;
      }

      var launchCount = prefs.getInt(_ratingLaunchCountKey) ?? 0;
      if (incrementLaunchCount) {
        launchCount += 1;
        await prefs.setInt(_ratingLaunchCountKey, launchCount);
      }
      if (launchCount < _minimumLaunchesForRatingPrompt) {
        return;
      }

      final lastPromptAtRaw = prefs.getString(_ratingLastPromptAtKey);
      if (lastPromptAtRaw != null && lastPromptAtRaw.trim().isNotEmpty) {
        final lastPromptAt = DateTime.tryParse(lastPromptAtRaw);
        if (lastPromptAt != null &&
            DateTime.now().difference(lastPromptAt) < _ratingPromptCooldown) {
          return;
        }
      }

      final inAppReview = InAppReview.instance;

      final context = _navigatorKey.currentContext;
      if (context == null || !context.mounted) {
        return;
      }

      final accepted = await _showRatingPromptDialog(context);
      await prefs.setString(
        _ratingLastPromptAtKey,
        DateTime.now().toIso8601String(),
      );
      if (accepted != true) {
        return;
      }

      await _launchRatingFlow(inAppReview);
      await prefs.setBool(_ratingCompletedKey, true);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Rating prompt failed: $e');
      }
    } finally {
      _isRatingPromptInFlight = false;
    }
  }

  Future<void> _launchRatingFlow(InAppReview inAppReview) async {
    if (kIsWeb) {
      return;
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      await inAppReview.openStoreListing();
      return;
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final appStoreId = _iosAppStoreId.trim();
      if (appStoreId.isNotEmpty) {
        await inAppReview.openStoreListing(appStoreId: appStoreId);
        return;
      }

      await inAppReview.openStoreListing();
    }
  }

  Future<bool?> _showRatingPromptDialog(BuildContext context) {
    final colors = context.appColors;
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Icon(Icons.star_rounded, color: colors.warningText),
            const SizedBox(width: 10),
            const Text('Enjoying HopefulMe?'),
          ],
        ),
        content: Text(
          'Would you like to rate the app? Your feedback helps us improve.',
          style: TextStyle(color: colors.textMuted, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Not now'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: colors.brand,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Rate now'),
          ),
        ],
      ),
    );
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
      unawaited(_trackRatingLaunchIfNeeded());
    } else {
      _hasTrackedRatingLaunchThisSession = false;
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
    final now = DateTime.now();
    final fingerprint = _notificationPayloadFingerprint(data);
    if (_isHandlingNotificationOpen) {
      return;
    }
    if (_lastNotificationOpenFingerprint == fingerprint &&
        _lastNotificationOpenAt != null &&
        now.difference(_lastNotificationOpenAt!) < const Duration(seconds: 2)) {
      return;
    }
    _isHandlingNotificationOpen = true;
    _lastNotificationOpenFingerprint = fingerprint;
    _lastNotificationOpenAt = now;

    final context = _navigatorKey.currentContext;
    if (context == null || !_authController.isAuthenticated) {
      _isHandlingNotificationOpen = false;
      return;
    }

    try {
      final type = data['type']?.toString().trim().toLowerCase() ?? '';
      final senderUsername =
          data['sender_username']?.toString().trim().replaceFirst('@', '') ??
          '';
      final senderName = data['sender_name']?.toString().trim() ?? '';
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
            if (ActiveChat.currentUsername == senderUsername) {
              return;
            }
            await _openNotificationMessageThread(
              context,
              username: senderUsername,
              title: senderName.isNotEmpty ? senderName : 'Conversation',
            );
            return;
          }
          break;
        case 'comment':
        case 'like':
        case 'mention':
          if (contentType == 'update' && contentId > 0) {
            await _openNotificationUpdateDetail(context, updateId: contentId);
            return;
          }
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
    } finally {
      _isHandlingNotificationOpen = false;
    }
  }

  String _notificationPayloadFingerprint(Map<String, dynamic> data) {
    final keys = data.keys.toList()..sort();
    final normalized = <String, dynamic>{};
    for (final key in keys) {
      normalized[key] = data[key];
    }
    return jsonEncode(normalized);
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

  bool _isNotificationRoute(String? routeName, {required String prefix}) {
    if (routeName == null || routeName.isEmpty) {
      return false;
    }
    return routeName.startsWith(prefix);
  }

  Future<void> _openNotificationMessageThread(
    BuildContext context, {
    required String username,
    required String title,
  }) async {
    final normalized = username.trim().toLowerCase().replaceFirst('@', '');
    if (normalized.isEmpty) {
      return;
    }
    final routeName = '/notification/message/$normalized';
    final route = MaterialPageRoute<void>(
      settings: RouteSettings(name: routeName),
      builder: (context) => MessageThreadScreen(
        repository: _messageRepository,
        profileRepository: _profileRepository,
        updateRepository: _updateRepository,
        currentUser: _authController.currentUser,
        username: normalized,
        title: title,
        onBackToInbox: (threadContext) async {
          if (!threadContext.mounted) {
            return;
          }
          final navigator = Navigator.of(threadContext);
          navigator.popUntil((route) => route.isFirst);
          await navigator.push(
            MaterialPageRoute<void>(
              builder: (context) => MessagesScreen(
                repository: _messageRepository,
                profileRepository: _profileRepository,
                updateRepository: _updateRepository,
                groupRepository: _groupRepository,
                currentUser: _authController.currentUser,
              ),
            ),
          );
        },
      ),
    );

    if (_isNotificationRoute(
      appRouteObserver.currentRouteName,
      prefix: '/notification/message/',
    )) {
      await Navigator.of(context).pushReplacement(route);
      return;
    }
    await Navigator.of(context).push(route);
  }

  Future<void> _openNotificationUpdateDetail(
    BuildContext context, {
    required int updateId,
  }) async {
    final routeName = '/notification/update/$updateId';
    final route = MaterialPageRoute<void>(
      settings: RouteSettings(name: routeName),
      builder: (context) => UpdateDetailScreen(
        updateId: updateId,
        currentUser: _authController.currentUser,
        repository: _updateRepository,
        contentRepository: _contentRepository,
        profileRepository: _profileRepository,
        messageRepository: _messageRepository,
        searchRepository: _searchRepository,
      ),
    );

    if (_isNotificationRoute(
      appRouteObserver.currentRouteName,
      prefix: '/notification/update/',
    )) {
      await Navigator.of(context).pushReplacement(route);
      return;
    }
    await Navigator.of(context).push(route);
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
      final bridgedUrl = await _authController.authRepository
          .createWebSessionUrl(targetUrl);
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
        builder: (context) => WebPageScreen(
          title: title,
          url: targetUrl,
          onInternalLinkTap: (uri) async {
            if (!WebPageScreen.shouldUseNativeRouting(
              uri,
              originUrl: _config.webBaseUrl,
            )) {
              return false;
            }
            if (!context.mounted) {
              return false;
            }
            await _openDeepLink(context, uri);
            return true;
          },
        ),
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
    final normalized = _normalizeSupportedDeepLinkUri(uri);
    if (normalized != null && _isVerifyEmailUri(normalized)) {
      await _openVerifyEmailScreen(context, normalized);
      return;
    }

    final navigator = AppDeepLinkNavigator(
      feedRepository: _feedRepository,
      contentRepository: _contentRepository,
      profileRepository: _profileRepository,
      messageRepository: _messageRepository,
      groupRepository: _groupRepository,
      updateRepository: _updateRepository,
      searchRepository: _searchRepository,
      libraryRepository: _libraryRepository,
      flyerTemplateRepository: _flyerTemplateRepository,
      currentUser: _authController.currentUser,
      webBaseUrl: _config.webBaseUrl,
      signWebUrl: _authController.authRepository.createWebSessionUrl,
    );
    await navigator.open(context, uri);
  }

  bool _canOpenDeepLinkWhileLoggedOut(Uri uri) {
    final normalized = _normalizeSupportedDeepLinkUri(uri);
    if (normalized == null) {
      return false;
    }

    return _isResetPasswordUri(normalized) || _isVerifyEmailUri(normalized);
  }

  Future<void> _openLoggedOutDeepLink(BuildContext context, Uri uri) async {
    final normalized = _normalizeSupportedDeepLinkUri(uri);
    if (normalized == null) {
      return;
    }

    if (_isResetPasswordUri(normalized)) {
      await _openResetPasswordScreen(context, normalized);
      return;
    }

    if (_isVerifyEmailUri(normalized)) {
      await _openVerifyEmailScreen(context, normalized);
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

  bool _isVerifyEmailUri(Uri uri) {
    final segments = uri.pathSegments.where((segment) => segment.isNotEmpty);
    return segments.length >= 3 &&
        segments.first.toLowerCase() == 'verify-email';
  }

  Future<void> _openResetPasswordScreen(BuildContext context, Uri uri) {
    final segments = uri.pathSegments.where((segment) => segment.isNotEmpty);
    final token = segments.length >= 2
        ? Uri.decodeComponent(segments.elementAt(1))
        : '';
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

  Future<void> _openVerifyEmailScreen(BuildContext context, Uri uri) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => VerifyEmailScreen(
          authRepository: _authController.authRepository,
          verificationUri: uri,
        ),
      ),
    );
  }

  Future<void> _handleUnauthorizedSession() async {
    if (_isHandlingForcedUnauthorizedLogout) {
      return;
    }
    _isHandlingForcedUnauthorizedLogout = true;
    try {
      await _authController.forceLocalLogout();
      if (!mounted) {
        return;
      }
      final navigator = _navigatorKey.currentState;
      if (navigator == null) {
        return;
      }
      navigator.pushNamedAndRemoveUntil(
        LoginScreen.routeName,
        (route) => false,
      );
    } finally {
      _isHandlingForcedUnauthorizedLogout = false;
    }
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
      flyerTemplateRepository: _flyerTemplateRepository,
      onCheckForUpdates: () => _checkAppVersion(force: true),
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
                      // 'Inspire the world around you',
                      '',
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

