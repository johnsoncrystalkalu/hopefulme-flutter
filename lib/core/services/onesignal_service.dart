import 'package:flutter/material.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

typedef OneSignalNotificationOpenHandler =
    Future<void> Function(Map<String, dynamic> data);

class OneSignalService {
  OneSignalService._();
  static final OneSignalService instance = OneSignalService._();

  bool _isInitialized = false;
  GlobalKey<NavigatorState>? _navigatorKey;
  OneSignalNotificationOpenHandler? _onNotificationOpened;

  Future<void> initialize({
    required String appId,
    GlobalKey<NavigatorState>? navigatorKey,
    OneSignalNotificationOpenHandler? onNotificationOpened,
  }) async {
    if (_isInitialized) return;
    _navigatorKey = navigatorKey;
    _onNotificationOpened = onNotificationOpened;

    OneSignal.initialize(appId);

    await OneSignal.Notifications.requestPermission(true);

    OneSignal.Notifications.addForegroundWillDisplayListener((event) {
      final data = event.notification.additionalData;
      if (ActiveChat.matchesIncomingMessage(data)) {
        event.preventDefault();
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

  Future<void> _handleNotificationData(Map<String, dynamic> data) async {
    if (_navigatorKey?.currentContext == null) {
      return;
    }

    final handler = _onNotificationOpened;
    if (handler != null) {
      await handler(data);
    }
  }

  void addSubscriptionObserver(
    void Function(OSPushSubscriptionChangedState) onChanged,
  ) {
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
  static int? currentConversationId;

  static bool matchesIncomingMessage(Map<String, dynamic>? data) {
    if (data == null) {
      return false;
    }

    final type = data['type']?.toString().trim().toLowerCase() ?? '';
    if (type != 'message') {
      return false;
    }

    final incomingConversationId = int.tryParse(
      data['conversation_id']?.toString() ?? '',
    );
    if (currentConversationId != null &&
        incomingConversationId != null &&
        currentConversationId == incomingConversationId) {
      return true;
    }

    final incomingSender = data['sender_username']
        ?.toString()
        .trim()
        .toLowerCase()
        .replaceFirst('@', '');
    if (incomingSender == null || incomingSender.isEmpty) {
      return false;
    }

    final activeUsername = currentUsername?.trim().toLowerCase().replaceFirst(
      '@',
      '',
    );
    return activeUsername != null &&
        activeUsername.isNotEmpty &&
        incomingSender == activeUsername;
  }
}
