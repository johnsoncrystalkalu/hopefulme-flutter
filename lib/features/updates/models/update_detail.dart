import 'package:hopefulme_flutter/core/network/image_url_resolver.dart';
import 'package:hopefulme_flutter/features/feed/models/feed_dashboard.dart';

class UpdateDetail {
  const UpdateDetail({
    required this.id,
    required this.status,
    required this.photoUrl,
    required this.originalPhotoUrl,
    required this.device,
    required this.views,
    required this.likesCount,
    required this.commentsCount,
    required this.createdAt,
    required this.user,
    required this.comments,
  });

  final int id;
  final String status;
  final String photoUrl;
  final String originalPhotoUrl;
  final String device;
  final int views;
  final int likesCount;
  final int commentsCount;
  final String createdAt;
  final FeedUser user;
  final List<UpdateComment> comments;

  factory UpdateDetail.fromJson(Map<String, dynamic> json) {
    final user = FeedUser.fromJson(
      json['user'] as Map<String, dynamic>? ?? <String, dynamic>{},
    );

    return UpdateDetail(
      id: json['id'] as int? ?? 0,
      status: _plainText(json['status']?.toString() ?? ''),
      photoUrl: ImageUrlResolver.resolve(
        json['photo_url']?.toString() ?? '',
        contextUrls: [user.photoUrl],
      ),
      originalPhotoUrl: ImageUrlResolver.resolveOriginal(
        json['photo_url']?.toString() ?? '',
        contextUrls: [user.photoUrl],
      ),
      device: json['device']?.toString() ?? '',
      views: json['views'] as int? ?? 0,
      likesCount: json['likes_count'] as int? ?? 0,
      commentsCount: json['comments_count'] as int? ?? 0,
      createdAt: json['created_at']?.toString() ?? '',
      user: user,
      comments: (json['comments'] as List<dynamic>? ?? <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(UpdateComment.fromJson)
          .toList(),
    );
  }
}

class UpdateComment {
  const UpdateComment({
    required this.id,
    required this.comment,
    required this.createdAt,
    required this.user,
  });

  final int id;
  final String comment;
  final String createdAt;
  final FeedUser user;

  factory UpdateComment.fromJson(Map<String, dynamic> json) {
    return UpdateComment(
      id: json['id'] as int? ?? 0,
      comment: _plainText(json['comment']?.toString() ?? ''),
      createdAt: json['created_at']?.toString() ?? '',
      user: FeedUser.fromJson(
        json['user'] as Map<String, dynamic>? ?? <String, dynamic>{},
      ),
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
