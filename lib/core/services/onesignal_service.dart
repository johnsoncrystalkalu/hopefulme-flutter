import 'package:flutter/material.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

class OneSignalService {
  OneSignalService._();
  static final OneSignalService instance = OneSignalService._();

  bool _isInitialized = false;
  GlobalKey<NavigatorState>? _navigatorKey;

  Future<void> initialize({required String appId, GlobalKey<NavigatorState>? navigatorKey}) async {
    if (_isInitialized) return;
    _navigatorKey = navigatorKey;

    OneSignal.initialize(appId);

    await OneSignal.Notifications.requestPermission(true);

  OneSignal.Notifications.addForegroundWillDisplayListener((event) {
  final data = event.notification.additionalData;
  final type = data?['type']?.toString();
  final senderUsername = data?['sender_username']?.toString();

  // Suppress chat notification if user is already in that conversation
  if (type == 'message' &&
      senderUsername != null &&
      senderUsername == ActiveChat.currentUsername) {
    event.preventDefault(); // don't show
    return;
  }

  event.preventDefault();
  event.notification.display();
});

    OneSignal.Notifications.addClickListener((event) {
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
      Navigator.pushNamed(context, '/notifications');
      break;
  }
}

  void addSubscriptionObserver(void Function(OSPushSubscriptionChangedState) onChanged) {
    OneSignal.User.pushSubscription.addObserver(onChanged);
  }

  Future<String?> getPlayerId() async {
    return OneSignal.User.pushSubscription.id;
  }

  Future<void> setExternalUserId(String userId) async {
    await OneSignal.login(_normalizeExternalUserId(userId));
  }

  Future<void> removeExternalUserId() async {
    await OneSignal.logout();
  }

  Future<void> addTrigger(String key, String value) async {
    OneSignal.InAppMessages.addTrigger(key, value);
  }

  Future<void> sendTag(String key, String value) async {
    await OneSignal.User.addTagWithKey(key, value);
  }

  Future<void> deleteTag(String key) async {
    await OneSignal.User.removeTag(key);
  }

  String normalizeExternalUserId(String userId) {
    return _normalizeExternalUserId(userId);
  }

  String _normalizeExternalUserId(String userId) {
    final trimmed = userId.trim();
    if (trimmed.isEmpty) {
      return trimmed;
    }

    return trimmed.startsWith('user_') ? trimmed : 'user_$trimmed';
  }
  
}

class ActiveChat {
  static String? currentUsername;
}