import 'package:hopefulme_flutter/core/network/image_url_resolver.dart';
import 'package:hopefulme_flutter/core/utils/json_parsing.dart';
import 'package:hopefulme_flutter/features/feed/models/feed_dashboard.dart';

class ContentDetail {
  const ContentDetail({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.videoUrl,
    required this.photoUrl,
    required this.originalPhotoUrl,
    required this.secondaryPhotoUrl,
    required this.originalSecondaryPhotoUrl,
    required this.tag,
    required this.category,
    required this.label,
    required this.views,
    required this.likesCount,
    required this.commentsCount,
    required this.createdAt,
    required this.user,
    required this.comments,
  });

  final int id;
  final String kind;
  final String title;
  final String body;
  final String videoUrl;
  final String photoUrl;
  final String originalPhotoUrl;
  final String secondaryPhotoUrl;
  final String originalSecondaryPhotoUrl;
  final String tag;
  final String category;
  final String label;
  final int views;
  final int likesCount;
  final int commentsCount;
  final String createdAt;
  final FeedUser? user;
  final List<ContentComment> comments;

  factory ContentDetail.fromApi(
    Map<String, dynamic> json, {
    required String kind,
  }) {
    final user = (json['user'] as Map<String, dynamic>?)?.let(
      FeedUser.fromJson,
    );
    return ContentDetail(
      id: parseInt(json['id']),
      kind: kind,
      title: _plainText(json['title']?.toString() ?? ''),
      body: _plainText(
        json['content']?.toString() ??
            json['status']?.toString() ??
            json['message']?.toString() ??
            '',
      ),
      videoUrl: json['video_url']?.toString() ?? '',
      photoUrl: ImageUrlResolver.resolve(json['photo_url']?.toString() ?? ''),
      originalPhotoUrl: ImageUrlResolver.resolveOriginal(
        json['photo_url']?.toString() ?? '',
      ),
      secondaryPhotoUrl: ImageUrlResolver.resolve(
        json['photo2_url']?.toString() ?? '',
      ),
      originalSecondaryPhotoUrl: ImageUrlResolver.resolveOriginal(
        json['photo2_url']?.toString() ?? '',
      ),
      tag: json['tag']?.toString() ?? json['preset']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      views: parseInt(json['views']),
      likesCount: parseInt(json['likes_count']),
      commentsCount: parseInt(json['comments_count']),
      createdAt: json['created_at']?.toString() ?? '',
      user: user,
      comments: (json['comments'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(ContentComment.fromJson)
          .toList(),
    );
  }

  FeedEntry toFeedEntry() {
    return FeedEntry(
      id: id,
      type: kind,
      updateType: '',
      title: title,
      body: body,
      photoUrl: photoUrl,
      originalPhotoUrl: originalPhotoUrl,
      device: '',
      user: user,
      likesCount: likesCount,
      commentsCount: commentsCount,
      views: views,
      createdAt: createdAt,
    );
  }
}

class BlogActionResult {
  const BlogActionResult.updated(this.detail)
    : deletedBlogId = null,
      isDeleted = false;

  const BlogActionResult.deleted(this.deletedBlogId)
    : detail = null,
      isDeleted = true;

  final ContentDetail? detail;
  final int? deletedBlogId;
  final bool isDeleted;
}

class ContentComment {
  const ContentComment({
    required this.id,
    required this.body,
    required this.createdAt,
    required this.user,
    required this.replies,
  });

  final int id;
  final String body;
  final String createdAt;
  final FeedUser? user;
  final List<ContentCommentReply> replies;

  factory ContentComment.fromJson(Map<String, dynamic> json) {
    return ContentComment(
      id: parseInt(json['id']),
      body: _plainText(json['comment']?.toString() ?? ''),
      createdAt: json['created_at']?.toString() ?? '',
      user: (json['user'] as Map<String, dynamic>?)?.let(FeedUser.fromJson),
      replies: (json['replies'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(ContentCommentReply.fromJson)
          .toList(),
    );
  }
}

class ContentCommentReply {
  const ContentCommentReply({
    required this.id,
    required this.body,
    required this.createdAt,
    required this.user,
  });

  final int id;
  final String body;
  final String createdAt;
  final FeedUser? user;

  factory ContentCommentReply.fromJson(Map<String, dynamic> json) {
    return ContentCommentReply(
      id: parseInt(json['id']),
      body: _plainText(json['comment']?.toString() ?? ''),
      createdAt: json['created_at']?.toString() ?? '',
      user: (json['user'] as Map<String, dynamic>?)?.let(FeedUser.fromJson),
    );
  }
}

class InspirationDetail {
  const InspirationDetail({
    required this.id,
    required this.message,
    required this.senderName,
    required this.createdAt,
    required this.isAnonymous,
    required this.isPublic,
    required this.sender,
    required this.receiver,
  });

  final int id;
  final String message;
  final String senderName;
  final String createdAt;
  final bool isAnonymous;
  final bool isPublic;
  final FeedUser? sender;
  final FeedUser? receiver;

  factory InspirationDetail.fromApi(Map<String, dynamic> json) {
    return InspirationDetail(
      id: parseInt(json['id']),
      message: _plainText(json['message']?.toString() ?? ''),
      senderName: json['sender_name']?.toString() ?? 'Someone',
      createdAt: json['created_at']?.toString() ?? '',
      isAnonymous: parseBool(json['is_anonymous']),
      isPublic: parseBool(json['is_public']),
      sender: (json['sender'] as Map<String, dynamic>?)?.let(FeedUser.fromJson),
      receiver: (json['receiver'] as Map<String, dynamic>?)?.let(
        FeedUser.fromJson,
      ),
    );
  }
}

class InspirationPage {
  const InspirationPage({
    required this.items,
    required this.currentPage,
    required this.lastPage,
  });

  final List<InspirationDetail> items;
  final int currentPage;
  final int lastPage;

  bool get hasMore => currentPage < lastPage;

  factory InspirationPage.fromApi(Map<String, dynamic> json) {
    final meta = json['meta'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final data = json['data'] as List<dynamic>? ?? const <dynamic>[];

    return InspirationPage(
      items: data
          .whereType<Map<String, dynamic>>()
          .map(InspirationDetail.fromApi)
          .toList(),
      currentPage: parseInt(meta['current_page'], fallback: 1),
      lastPage: parseInt(meta['last_page'], fallback: 1),
    );
  }
}

String _plainText(String input) {
  return input
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</p\s*>', caseSensitive: false), '\n\n')
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&#039;', "'")
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .replaceAll(RegExp(r'[ \t\f\v]+'), ' ')
      .replaceAll(RegExp(r' *\n *'), '\n')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
}

extension<T> on T {
  R let<R>(R Function(T value) mapper) => mapper(this);
}
