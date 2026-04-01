import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

class OneSignalService {
  OneSignalService._();
  static final OneSignalService instance = OneSignalService._();

  bool _isInitialized = false;
  GlobalKey<NavigatorState>? _navigatorKey;

  Future<void> initialize({required String appId, GlobalKey<NavigatorState>? navigatorKey}) async {
    if (_isInitialized) return;
    _navigatorKey = navigatorKey;

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
  final context = _navigatorKey?.currentContext;
  if (context == null) return;

  final type = data['type']?.toString();
  final senderUsername = data['sender_username']?.toString();
  final contentType = data['content_type']?.toString();
  final contentId = data['content_id']?.toString();
  final orderId = data['order_id']?.toString();
  final inspirationId = data['inspiration_id']?.toString();
  final conversationId = data['conversation_id']?.toString();

  debugPrint('Notification type: $type');

  switch (type) {

    case 'follow':
    case 'referral_joined':
      // Go to the sender's profile
      if (senderUsername != null) {
        Navigator.pushNamed(context, '/profile', arguments: senderUsername);
      }
      break;

    case 'message':
      // Go to the chat screen with that user
      if (senderUsername != null) {
        Navigator.pushNamed(context, '/chat', arguments: senderUsername);
      }
      break;

    case 'comment':
    case 'like':
    case 'mention':
      // Go to the content that was liked/commented/mentioned
      if (contentType != null && contentId != null) {
        Navigator.pushNamed(context, '/content', arguments: {
          'content_type': contentType,
          'content_id': contentId,
        });
      }
      break;

    case 'inspiration':
      // Go to the inspiration inbox or specific inspiration
      if (inspirationId != null) {
        Navigator.pushNamed(context, '/inspiration', arguments: inspirationId);
      } else {
        Navigator.pushNamed(context, '/inspiration/inbox');
      }
      break;

    case 'store_order':
    case 'store_order_placed':
      // Go to the order page
      if (orderId != null) {
        Navigator.pushNamed(context, '/order', arguments: orderId);
      }
      break;

    case 'welcome':
      // Go to profile edit screen
      Navigator.pushNamed(context, '/profile/edit');
      break;

    default:
      debugPrint('Unknown notification type: $type');
      // Optionally navigate to home/notifications screen
      Navigator.pushNamed(context, '/notifications');
      break;
  }
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