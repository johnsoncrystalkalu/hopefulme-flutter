import 'package:hopefulme_flutter/core/network/image_url_resolver.dart';
import 'package:hopefulme_flutter/core/utils/json_parsing.dart';

class UpdateReactionPage {
  const UpdateReactionPage({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.total,
  });

  final List<UpdateReactionItem> items;
  final int currentPage;
  final int lastPage;
  final int total;

  bool get hasMore => currentPage < lastPage;

  factory UpdateReactionPage.fromJson(
    Map<String, dynamic> json, {
    int requestedPage = 1,
  }) {
    final payload = _pickPayload(json);
    final meta = _pickMeta(json, payload);
    final listSource = _pickListSource(json, payload);
    final items = listSource
        .whereType<Map<String, dynamic>>()
        .map(UpdateReactionItem.fromJson)
        .toList();

    final currentPage = parseInt(
      payload['current_page'] ?? meta['current_page'],
      fallback: requestedPage,
    );
    final lastPage = parseInt(
      payload['last_page'] ?? meta['last_page'],
      fallback: currentPage,
    );

    return UpdateReactionPage(
      items: items,
      currentPage: currentPage < 1 ? 1 : currentPage,
      lastPage: lastPage < 1 ? 1 : lastPage,
      total: parseInt(
        payload['total'] ?? meta['total'],
        fallback: items.length,
      ),
    );
  }

  static Map<String, dynamic> _pickPayload(Map<String, dynamic> root) {
    final reactions = root['reactions'];
    if (reactions is Map<String, dynamic>) {
      return reactions;
    }

    final data = root['data'];
    if (data is Map<String, dynamic>) {
      return data;
    }

    return root;
  }

  static Map<String, dynamic> _pickMeta(
    Map<String, dynamic> root,
    Map<String, dynamic> payload,
  ) {
    final payloadMeta = payload['meta'];
    if (payloadMeta is Map<String, dynamic>) {
      return payloadMeta;
    }

    final rootMeta = root['meta'];
    if (rootMeta is Map<String, dynamic>) {
      return rootMeta;
    }

    return const <String, dynamic>{};
  }

  static List<dynamic> _pickListSource(
    Map<String, dynamic> root,
    Map<String, dynamic> payload,
  ) {
    final payloadData = payload['data'];
    if (payloadData is List<dynamic>) {
      return payloadData;
    }

    final rootData = root['data'];
    if (rootData is List<dynamic>) {
      return rootData;
    }

    final rootReactions = root['reactions'];
    if (rootReactions is List<dynamic>) {
      return rootReactions;
    }

    return const <dynamic>[];
  }
}

class UpdateReactionItem {
  const UpdateReactionItem({
    required this.id,
    required this.reaction,
    required this.createdAt,
    required this.user,
  });

  final int id;
  final String reaction;
  final String createdAt;
  final UpdateReactionUser user;

  factory UpdateReactionItem.fromJson(Map<String, dynamic> json) {
    return UpdateReactionItem(
      id: parseInt(json['id']),
      reaction: json['reaction']?.toString().trim().isNotEmpty == true
          ? json['reaction']!.toString().trim()
          : json['emoji']?.toString().trim().isNotEmpty == true
          ? json['emoji']!.toString().trim()
          : json['reaction_emoji']?.toString().trim().isNotEmpty == true
          ? json['reaction_emoji']!.toString().trim()
          : '',
      createdAt: json['created_at']?.toString() ?? '',
      user: UpdateReactionUser.fromJson(
        json['user'] as Map<String, dynamic>? ?? <String, dynamic>{},
      ),
    );
  }
}

class UpdateReactionUser {
  const UpdateReactionUser({
    required this.id,
    required this.username,
    required this.displayName,
    required this.photoUrl,
    required this.isVerified,
  });

  final int id;
  final String username;
  final String displayName;
  final String photoUrl;
  final bool isVerified;

  factory UpdateReactionUser.fromJson(Map<String, dynamic> json) {
    final displayName = _firstNonEmpty(
      json['display_name'],
      json['fullname'],
      json['full_name'],
      json['name'],
      json['username'],
    );
    return UpdateReactionUser(
      id: parseInt(json['id']),
      username: json['username']?.toString().trim() ?? '',
      displayName: displayName,
      photoUrl: ImageUrlResolver.avatar(json['photo_url']?.toString() ?? ''),
      isVerified: parseBool(
        json['is_verified'],
        fallback: (json['verified']?.toString().trim().toLowerCase() == 'yes'),
      ),
    );
  }

  static String _firstNonEmpty(
    Object? a,
    Object? b,
    Object? c,
    Object? d,
    Object? e,
  ) {
    final values = <Object?>[a, b, c, d, e];
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) {
        return text;
      }
    }
    return 'User';
  }
}
