import 'package:hopefulme_flutter/core/network/image_url_resolver.dart';
import 'package:hopefulme_flutter/core/utils/json_parsing.dart';
import 'package:hopefulme_flutter/features/feed/models/feed_dashboard.dart';

class UpdateDetail {
  const UpdateDetail({
    required this.id,
    required this.type,
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
    this.commentsCurrentPage = 1,
    this.commentsLastPage = 1,
    this.commentsTotal = 0,
    this.isLiked = false,
    this.myReaction,
    this.reactionsPreview = const <String>[],
  });

  final int id;
  final String type;
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
  final int commentsCurrentPage;
  final int commentsLastPage;
  final int commentsTotal;
  final bool isLiked;
  final String? myReaction;
  final List<String> reactionsPreview;

  bool get hasMoreComments => commentsCurrentPage < commentsLastPage;

  factory UpdateDetail.fromJson(Map<String, dynamic> json) {
    final user = FeedUser.fromJson(
      json['user'] as Map<String, dynamic>? ?? <String, dynamic>{},
    );
    final commentsMeta =
        json['comments_meta'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final comments = (json['comments'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(UpdateComment.fromJson)
        .toList();

    return UpdateDetail(
      id: parseInt(json['id']),
      type: json['type']?.toString() ?? '',
      status: _plainText(json['status']?.toString() ?? ''),
      photoUrl: ImageUrlResolver.resolve(json['photo_url']?.toString() ?? ''),
      originalPhotoUrl: ImageUrlResolver.resolveOriginal(
        json['photo_url']?.toString() ?? '',
      ),
      device: json['device']?.toString() ?? '',
      views: parseInt(json['views']),
      likesCount: parseInt(json['likes_count']),
      commentsCount: parseInt(json['comments_count']),
      createdAt: json['created_at']?.toString() ?? '',
      user: user,
      comments: comments,
      commentsCurrentPage: parseInt(commentsMeta['current_page'], fallback: 1),
      commentsLastPage: parseInt(commentsMeta['last_page'], fallback: 1),
      commentsTotal: parseInt(
        commentsMeta['total'],
        fallback: parseInt(json['comments_count'], fallback: comments.length),
      ),
      isLiked: parseBool(json['is_liked']),
      myReaction: json['my_reaction']?.toString().trim().isNotEmpty == true
          ? json['my_reaction']?.toString().trim()
          : null,
      reactionsPreview:
          (json['reactions_preview'] as List<dynamic>? ?? const <dynamic>[])
              .map((item) => item.toString().trim())
              .where((item) => item.isNotEmpty)
              .toList(),
    );
  }

  UpdateDetail copyWith({
    int? id,
    String? type,
    String? status,
    String? photoUrl,
    String? originalPhotoUrl,
    String? device,
    int? views,
    int? likesCount,
    int? commentsCount,
    String? createdAt,
    FeedUser? user,
    List<UpdateComment>? comments,
    int? commentsCurrentPage,
    int? commentsLastPage,
    int? commentsTotal,
    bool? isLiked,
    String? myReaction,
    List<String>? reactionsPreview,
  }) {
    return UpdateDetail(
      id: id ?? this.id,
      type: type ?? this.type,
      status: status ?? this.status,
      photoUrl: photoUrl ?? this.photoUrl,
      originalPhotoUrl: originalPhotoUrl ?? this.originalPhotoUrl,
      device: device ?? this.device,
      views: views ?? this.views,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      createdAt: createdAt ?? this.createdAt,
      user: user ?? this.user,
      comments: comments ?? this.comments,
      commentsCurrentPage: commentsCurrentPage ?? this.commentsCurrentPage,
      commentsLastPage: commentsLastPage ?? this.commentsLastPage,
      commentsTotal: commentsTotal ?? this.commentsTotal,
      isLiked: isLiked ?? this.isLiked,
      myReaction: myReaction ?? this.myReaction,
      reactionsPreview: reactionsPreview ?? this.reactionsPreview,
    );
  }
}

class UpdateComment {
  const UpdateComment({
    required this.id,
    required this.comment,
    required this.createdAt,
    required this.user,
    required this.replies,
  });

  final int id;
  final String comment;
  final String createdAt;
  final FeedUser user;
  final List<UpdateCommentReply> replies;

  factory UpdateComment.fromJson(Map<String, dynamic> json) {
    return UpdateComment(
      id: json['id'] as int? ?? 0,
      comment: _plainText(json['comment']?.toString() ?? ''),
      createdAt: json['created_at']?.toString() ?? '',
      user: FeedUser.fromJson(
        json['user'] as Map<String, dynamic>? ?? <String, dynamic>{},
      ),
      replies: (json['replies'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(UpdateCommentReply.fromJson)
          .toList(),
    );
  }
}

class UpdateCommentReply {
  const UpdateCommentReply({
    required this.id,
    required this.comment,
    required this.createdAt,
    required this.user,
  });

  final int id;
  final String comment;
  final String createdAt;
  final FeedUser user;

  factory UpdateCommentReply.fromJson(Map<String, dynamic> json) {
    return UpdateCommentReply(
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
