import 'package:hopefulme_flutter/core/network/image_url_resolver.dart';
import 'package:hopefulme_flutter/core/utils/json_parsing.dart';

class FeedDashboard {
  const FeedDashboard({
    required this.feed,
    required this.following,
    required this.suggested,
    required this.onlineUsers,
    required this.todayBirthdays,
    required this.trendingQuotes,
  });

  final List<FeedEntry> feed;
  final List<FeedUser> following;
  final List<FeedUser> suggested;
  final List<FeedUser> onlineUsers;
  final List<FeedUser> todayBirthdays;
  final List<QuoteCard> trendingQuotes;

  factory FeedDashboard.fromJson(Map<String, dynamic> json) {
    return FeedDashboard(
      feed: _mapList(json['feed'], FeedEntry.fromJson),
      following: _mapList(json['following'], FeedUser.fromJson),
      suggested: _mapList(json['suggested'], FeedUser.fromJson),
      onlineUsers: _mapList(json['online_users'], FeedUser.fromJson),
      todayBirthdays: _mapList(
        json['today_birthdays'] ??
            json['todays_birthdays'] ??
            json['birthdays_today'] ??
            json['todays_birthdays_users'],
        FeedUser.fromJson,
      ),
      trendingQuotes: _mapList(json['trending_quotes'], QuoteCard.fromJson),
    );
  }

  static List<T> _mapList<T>(
    dynamic value,
    T Function(Map<String, dynamic> json) mapper,
  ) {
    final items = value as List<dynamic>? ?? <dynamic>[];
    return items.whereType<Map<String, dynamic>>().map(mapper).toList();
  }
}

class FeedEntryPage {
  const FeedEntryPage({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.total,
  });

  final List<FeedEntry> items;
  final int currentPage;
  final int lastPage;
  final int total;

  bool get hasMore => currentPage < lastPage;

  factory FeedEntryPage.fromJson(Map<String, dynamic> json) {
    final meta = json['meta'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final items = (json['data'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(FeedEntry.fromJson)
        .toList();

    return FeedEntryPage(
      items: items,
      currentPage: parseInt(meta['current_page'], fallback: 1),
      lastPage: parseInt(meta['last_page'], fallback: 1),
      total: parseInt(meta['total']),
    );
  }
}

class FeedUserPage {
  const FeedUserPage({
    required this.items,
    required this.onlineUsers,
    required this.newMembers,
    required this.currentPage,
    required this.lastPage,
    required this.total,
  });

  final List<FeedUser> items;
  final List<FeedUser> onlineUsers;
  final List<FeedUser> newMembers;
  final int currentPage;
  final int lastPage;
  final int total;

  bool get hasMore => currentPage < lastPage;

  factory FeedUserPage.fromJson(Map<String, dynamic> json) {
    final meta = json['meta'] as Map<String, dynamic>? ?? <String, dynamic>{};
    return FeedUserPage(
      items: _mapUsers(json['data']),
      onlineUsers: _mapUsers(json['online_users']),
      newMembers: _mapUsers(json['new_members']),
      currentPage: parseInt(meta['current_page'], fallback: 1),
      lastPage: parseInt(meta['last_page'], fallback: 1),
      total: parseInt(meta['total']),
    );
  }

  static List<FeedUser> _mapUsers(dynamic value) {
    final items = value as List<dynamic>? ?? const <dynamic>[];
    return items
        .whereType<Map<String, dynamic>>()
        .map(FeedUser.fromJson)
        .toList();
  }
}

class FeedEntry {
  const FeedEntry({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.photoUrl,
    required this.originalPhotoUrl,
    required this.device,
    required this.user,
    required this.likesCount,
    required this.commentsCount,
    required this.views,
    required this.createdAt,
  });

  final int id;
  final String type;
  final String title;
  final String body;
  final String photoUrl;
  final String originalPhotoUrl;
  final String device;
  final FeedUser? user;
  final int likesCount;
  final int commentsCount;
  final int views;
  final String createdAt;

  factory FeedEntry.fromJson(Map<String, dynamic> json) {
    final userJson = json['user'] as Map<String, dynamic>?;
    final user = userJson == null ? null : FeedUser.fromJson(userJson);

    return FeedEntry(
      id: parseInt(json['id']),
      type: json['type']?.toString() ?? 'post',
      title:
          json['title']?.toString() ??
          userJson?['fullname']?.toString() ??
          'Untitled',
      body: _plainText(
        json['content']?.toString() ?? json['status']?.toString() ?? '',
      ),
      photoUrl: ImageUrlResolver.resolve(
        json['photo_url']?.toString() ?? '',
        contextUrls: [if (user != null) user.photoUrl],
      ),
      originalPhotoUrl: ImageUrlResolver.resolveOriginal(
        json['photo_url']?.toString() ?? '',
        contextUrls: [if (user != null) user.photoUrl],
      ),
      device: json['device']?.toString() ?? '',
      user: user,
      likesCount: parseInt(json['likes_count']),
      commentsCount: parseInt(json['comments_count']),
      views: parseInt(json['views']),
      createdAt: json['created_at']?.toString() ?? '',
    );
  }

  static String _plainText(String input) {
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

class FeedUser {
  const FeedUser({
    required this.id,
    required this.username,
    required this.fullname,
    required this.photoUrl,
    required this.verified,
    required this.isOnline,
    required this.lastSeen,
    required this.city,
    required this.state,
  });

  final int id;
  final String username;
  final String fullname;
  final String photoUrl;
  final String verified;
  final bool isOnline;
  final String lastSeen;
  final String city;
  final String state;

  String get displayName => fullname.isNotEmpty ? fullname : username;
  bool get isVerified => verified.toLowerCase() == 'yes';
  String get cityState {
    final parts = <String>[
      if (city.trim().isNotEmpty) city.trim(),
      if (state.trim().isNotEmpty) state.trim(),
    ];
    return parts.join(', ');
  }

  factory FeedUser.fromJson(Map<String, dynamic> json) {
    return FeedUser(
      id: parseInt(json['id']),
      username: json['username']?.toString() ?? '',
      fullname: json['fullname']?.toString() ?? '',
      photoUrl: ImageUrlResolver.resolve(json['photo_url']?.toString() ?? ''),
      verified: json['verified']?.toString() ?? '',
      isOnline: parseBool(json['is_online']),
      lastSeen: json['last_seen']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      state: json['state']?.toString() ?? '',
    );
  }
}

class QuoteCard {
  const QuoteCard({
    required this.id,
    required this.title,
    required this.photoUrl,
    required this.user,
  });

  final int id;
  final String title;
  final String photoUrl;
  final FeedUser? user;

  factory QuoteCard.fromJson(Map<String, dynamic> json) {
    final userJson = json['user'] as Map<String, dynamic>?;
    final user = userJson == null ? null : FeedUser.fromJson(userJson);

    return QuoteCard(
      id: parseInt(json['id']),
      title: json['title']?.toString() ?? '',
      photoUrl: ImageUrlResolver.resolve(
        json['photo_url']?.toString() ?? '',
        contextUrls: [if (user != null) user.photoUrl],
      ),
      user: user,
    );
  }
}
