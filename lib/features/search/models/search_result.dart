import 'package:hopefulme_flutter/core/network/image_url_resolver.dart';
import 'package:hopefulme_flutter/core/utils/json_parsing.dart';
import 'package:hopefulme_flutter/features/feed/models/feed_dashboard.dart';

class SearchResult {
  const SearchResult({
    required this.query,
    required this.type,
    required this.isSuggestion,
    required this.users,
    required this.posts,
    required this.blogs,
    required this.updates,
    required this.currentPage,
    required this.lastPage,
    required this.total,
  });

  final String query;
  final String type;
  final bool isSuggestion;
  final List<SearchUser> users;
  final List<SearchContentItem> posts;
  final List<SearchContentItem> blogs;
  final List<SearchContentItem> updates;
  final int currentPage;
  final int lastPage;
  final int total;

  bool get hasMore => currentPage < lastPage;

  factory SearchResult.fromJson(Map<String, dynamic> json) {
    final meta = json['meta'] as Map<String, dynamic>? ?? <String, dynamic>{};
    return SearchResult(
      query: json['query']?.toString() ?? '',
      type: json['type']?.toString() ?? 'all',
      isSuggestion: parseBool(json['is_suggestion']),
      users: (json['users'] as List<dynamic>? ?? <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(SearchUser.fromJson)
          .toList(),
      posts: (json['posts'] as List<dynamic>? ?? <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(SearchContentItem.fromJson)
          .toList(),
      blogs: (json['blogs'] as List<dynamic>? ?? <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(SearchContentItem.fromJson)
          .toList(),
      updates: (json['updates'] as List<dynamic>? ?? <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(SearchContentItem.fromJson)
          .toList(),
      currentPage: parseInt(meta['current_page'], fallback: 1),
      lastPage: parseInt(meta['last_page'], fallback: 1),
      total: parseInt(meta['total']),
    );
  }
}

class SearchUser {
  const SearchUser({
    required this.id,
    required this.username,
    required this.fullname,
    required this.email,
    required this.photoUrl,
    required this.isOnline,
    required this.lastSeen,
    required this.isVerified,
  });

  final int id;
  final String username;
  final String fullname;
  final String email;
  final String photoUrl;
  final bool isOnline;
  final String lastSeen;
  final bool isVerified;

  String get displayName => fullname.isNotEmpty ? fullname : username;

  factory SearchUser.fromJson(Map<String, dynamic> json) {
    return SearchUser(
      id: parseInt(json['id']),
      username: json['username']?.toString() ?? '',
      fullname: json['fullname']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      photoUrl: ImageUrlResolver.resolve(json['photo_url']?.toString() ?? ''),
      isOnline: parseBool(json['is_online']),
      lastSeen: json['last_seen']?.toString() ?? '',
      isVerified: parseBool(json['verified']),
    );
  }
}

class SearchContentItem {
  const SearchContentItem({
    required this.id,
    required this.title,
    required this.body,
    required this.photoUrl,
    required this.category,
    required this.createdAt,
    required this.user,
  });

  final int id;
  final String title;
  final String body;
  final String photoUrl;
  final String category;
  final String createdAt;
  final FeedUser? user;

  factory SearchContentItem.fromJson(Map<String, dynamic> json) {
    final user = (json['user'] as Map<String, dynamic>?)?.let(
      FeedUser.fromJson,
    );
    return SearchContentItem(
      id: parseInt(json['id']),
      title: _plainText(json['title']?.toString() ?? ''),
      body: _plainText(
        json['content']?.toString() ?? json['status']?.toString() ?? '',
      ),
      photoUrl: ImageUrlResolver.resolve(json['photo_url']?.toString() ?? ''),
      category: json['category']?.toString() ?? '',
      createdAt: json['created_at']?.toString() ?? '',
      user: user,
    );
  }
}

String _plainText(String input) {
  return input
      .replaceAll(RegExp(r'<[^>]*>'), ' ')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

extension<T> on T {
  R let<R>(R Function(T value) mapper) => mapper(this);
}
