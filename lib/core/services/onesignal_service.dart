import 'package:flutter/foundation.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

class OneSignalService {
  OneSignalService._();
  static final OneSignalService instance = OneSignalService._();

  bool _isInitialized = false;

  Future<void> initialize({required String appId}) async {
    if (_isInitialized) return;

    // 1. Set Debugging before init if you're troubleshooting
    if (kDebugMode) {
      OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
    }

    // 2. Initialize
    OneSignal.initialize(appId);
    
    // 3. Request permissions (Best to do this after a user logs in, but fine here)
    await OneSignal.Notifications.requestPermission(true);

    // 4. Foreground Listener
    OneSignal.Notifications.addForegroundWillDisplayListener((event) {
      debugPrint('Notification received in foreground: ${event.notification.title}');
      
      // By default, OneSignal WILL display the notification. 
      // You only call event.notification.display() if you want to force it 
      // after some custom logic or if you called event.preventDefault().
      
      final data = event.notification.additionalData;
      if (data != null) {
        _handleNotificationData(data);
      }
    });

    // 5. Click Listener
    OneSignal.Notifications.addClickListener((event) {
      debugPrint('Notification clicked: ${event.notification.body}');
      final data = event.notification.additionalData;
      if (data != null) {
        _handleNotificationData(data);
      }
    });

    _isInitialized = true;
  }

  void _handleNotificationData(Map<String, dynamic> data) {
    // Standardize key access
    final type = data['type']?.toString();
    final url = data['url']?.toString();

    debugPrint('Processing Notification Data: type=$type, url=$url');
    
    // TODO: Add your navigation logic here (e.g., Navigator.push)
  }

  void addSubscriptionObserver(void Function(OSPushSubscriptionChangedState) onChanged) {
    OneSignal.User.pushSubscription.addObserver(onChanged);
  }

  // Improved Player ID (Subscription ID) fetch
  Future<String?> getPlayerId() async {
    // In v5, the Player ID is specifically the pushSubscriptionId
    return OneSignal.User.pushSubscription.id;
  }

  Future<void> setExternalUserId(String userId) async {
    // This links your Laravel User ID to OneSignal
    await OneSignal.login(userId);
  }

  Future<void> removeExternalUserId() async {
    await OneSignal.logout();
  }

  Future<void> addTrigger(String key, String value) async {
    OneSignal.InAppMessages.addTrigger(key, value);
  }

  Future<void> sendTag(String key, String value) async {
    // In v5, tags are part of the User namespace
    await OneSignal.User.addTagWithKey(key, value);
  }

  Future<void> deleteTag(String key) async {
    await OneSignal.User.removeTag(key);
  }
}