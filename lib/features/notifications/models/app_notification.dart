import 'package:hopefulme_flutter/core/network/image_url_resolver.dart';
import 'package:hopefulme_flutter/core/utils/json_parsing.dart';

class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.message,
    required this.preview,
    required this.url,
    required this.contentType,
    required this.contentId,
    required this.inspirationId,
    required this.icon,
    required this.avatarUrl,
    required this.isRead,
    required this.createdAt,
  });

  final String id;
  final String type;
  final String message;
  final String preview;
  final String url;
  final String contentType;
  final int contentId;
  final int inspirationId;
  final String icon;
  final String avatarUrl;
  final bool isRead;
  final String createdAt;

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? <String, dynamic>{};

    return AppNotification(
      id: json['id']?.toString() ?? '',
      type: data['type']?.toString() ?? json['type']?.toString() ?? 'general',
      message: _stripHtml(data['message']?.toString() ?? 'New notification'),
      preview: data['preview']?.toString() ?? '',
      url: data['url']?.toString() ?? '',
      contentType: data['content_type']?.toString() ?? '',
      contentId: parseInt(data['content_id']),
      inspirationId: parseInt(data['inspiration_id']),
      icon: data['icon']?.toString() ?? _defaultIcon(data['type']?.toString()),
      avatarUrl: ImageUrlResolver.resolve(data['avatar']?.toString() ?? ''),
      isRead: json['read_at'] != null,
      createdAt: json['created_at']?.toString() ?? '',
    );
  }

  static String _defaultIcon(String? type) {
    return switch (type) {
      'follow' => 'person_add',
      'like' => 'favorite',
      'comment' => 'comment',
      'mention' => 'alternate_email',
      'mention_comment' => 'alternate_email',
      'message' => 'mail',
      'welcome' => 'waving_hand',
      'inspiration' => 'auto_awesome',
      'referral_joined' => 'group_add',
      'store_order' => 'shopping_bag',
      'store_order_placed' => 'shopping_cart_checkout',
      _ => 'notifications',
    };
  }

  static String _stripHtml(String input) {
    return input
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}

class NotificationPage {
  const NotificationPage({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.unreadCount,
  });

  final List<AppNotification> items;
  final int currentPage;
  final int lastPage;
  final int unreadCount;

  bool get hasMore => currentPage < lastPage;

  factory NotificationPage.fromJson(Map<String, dynamic> json) {
    final meta = json['meta'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final data = json['data'] as List<dynamic>? ?? <dynamic>[];

    return NotificationPage(
      items: data
          .whereType<Map<String, dynamic>>()
          .map(AppNotification.fromJson)
          .toList(),
      currentPage: parseInt(meta['current_page'], fallback: 1),
      lastPage: parseInt(meta['last_page'], fallback: 1),
      unreadCount: parseInt(meta['unread_count']),
    );
  }
}
