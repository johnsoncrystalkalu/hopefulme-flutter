import 'package:image_picker/image_picker.dart';
import 'package:hopefulme_flutter/core/network/api_client.dart';
import 'package:hopefulme_flutter/core/utils/json_parsing.dart';
import 'package:hopefulme_flutter/features/auth/data/auth_repository.dart';
import 'package:hopefulme_flutter/features/updates/models/update_detail.dart';
import 'package:hopefulme_flutter/features/updates/models/update_reaction.dart';

class UpdateRepository {
  UpdateRepository(this._authRepository);

  final AuthRepository _authRepository;

  Future<UpdateDetail> fetchUpdate(int id, {int commentPage = 1}) async {
    final response = await _authRepository.get(
      'updates/$id',
      queryParameters: commentPage > 1
          ? <String, dynamic>{'comment_page': commentPage}
          : null,
    );
    return UpdateDetail.fromJson(
      response['update'] as Map<String, dynamic>? ?? <String, dynamic>{},
    );
  }

  Future<UpdateDetail> createUpdate({
    required String status,
    XFile? photo,
  }) async {
    final response = photo == null
        ? await _authRepository.post('updates', body: {'status': status})
        : await _authRepository.postMultipart(
            'updates',
            fields: {'status': status},
            files: [
              ApiMultipartFile(
                field: 'photo',
                filename: photo.name,
                bytes: await photo.readAsBytes(),
              ),
            ],
          );

    final updateJson =
        (response['update'] as Map<String, dynamic>?) ??
        (response['data'] is Map<String, dynamic>
            ? (response['data'] as Map<String, dynamic>)['update']
                  as Map<String, dynamic>?
            : null) ??
        (response['data'] as Map<String, dynamic>?) ??
        response;

    return UpdateDetail.fromJson(
      updateJson as Map<String, dynamic>? ?? <String, dynamic>{},
    );
  }

  Future<List<MentionSuggestion>> fetchMentionSuggestions(
    String query, {
    int limit = 6,
  }) async {
    final normalizedLimit = limit.clamp(1, 8);
    final response = await _authRepository.get(
      'mentions/users',
      queryParameters: <String, dynamic>{
        'q': query.trim(),
        'limit': normalizedLimit,
      },
    );

    return (response['data'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(MentionSuggestion.fromJson)
        .toList();
  }

  Future<LikeResult> toggleLike(int id, {String? reaction}) async {
    final response = reaction == null
        ? await _authRepository.post('likes/update/$id')
        : await _authRepository.post(
            'likes/update/$id',
            body: {'reaction': reaction},
          );

    final previews =
        (response['reactions_preview'] as List<dynamic>? ?? const <dynamic>[])
            .map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .toList();

    return LikeResult(
      liked: parseBool(
        response['is_liked'],
        fallback: parseBool(response['liked']),
      ),
      count: parseInt(response['count']),
      myReaction: response['my_reaction']?.toString().trim().isNotEmpty == true
          ? response['my_reaction']?.toString().trim()
          : null,
      reactionsPreview: previews,
    );
  }

  Future<UpdateReactionPage> fetchUpdateReactions(
    int updateId, {
    int page = 1,
    int perPage = 25,
  }) async {
    final normalizedPage = page < 1 ? 1 : page;
    final normalizedPerPage = perPage.clamp(10, 60);
    final response = await _authRepository.get(
      'updates/$updateId/reactions',
      queryParameters: <String, dynamic>{
        'page': normalizedPage,
        'per_page': normalizedPerPage,
      },
    );
    return UpdateReactionPage.fromJson(response, requestedPage: normalizedPage);
  }

  Future<UpdateComment> addComment({
    required int updateId,
    required String comment,
  }) async {
    final response = await _authRepository.post(
      'comments',
      body: {
        'commentable_type': 'update',
        'commentable_id': updateId,
        'comment': comment,
      },
    );
    return UpdateComment.fromJson(
      response['comment'] as Map<String, dynamic>? ?? <String, dynamic>{},
    );
  }

  Future<UpdateCommentReply> addCommentReply({
    required int commentId,
    required String comment,
  }) async {
    final response = await _authRepository.post(
      'comments/$commentId/replies',
      body: {'comment': comment},
    );
    return UpdateCommentReply.fromJson(
      response['reply'] as Map<String, dynamic>? ?? <String, dynamic>{},
    );
  }

  Future<UpdateDetail> updateStatus({
    required int updateId,
    required String status,
  }) async {
    final response = await _authRepository.put(
      'updates/$updateId',
      body: {'status': status},
    );
    Map<String, dynamic>? updateJson;

    final rawUpdate = response['update'];
    if (rawUpdate is Map<String, dynamic>) {
      updateJson = rawUpdate;
    }

    final rawData = response['data'];
    if (updateJson == null && rawData is Map<String, dynamic>) {
      final nestedUpdate = rawData['update'];
      if (nestedUpdate is Map<String, dynamic>) {
        updateJson = nestedUpdate;
      } else {
        updateJson = rawData;
      }
    }

    updateJson ??= response;

    try {
      return UpdateDetail.fromJson(updateJson);
    } catch (_) {
      // Some API variants return a lightweight edit payload; fetch the canonical
      // update resource to avoid client-side parse crashes.
      return fetchUpdate(updateId);
    }
  }

  Future<void> deleteUpdate(int updateId) async {
    await _authRepository.delete('updates/$updateId');
  }

  Future<void> deleteComment(int commentId) async {
    await _authRepository.delete('comments/$commentId');
  }

  Future<UpdateComment> updateComment({
    required int commentId,
    required String comment,
  }) async {
    final response = await _authRepository.put(
      'comments/$commentId',
      body: {'comment': comment},
    );
    return UpdateComment.fromJson(
      response['comment'] as Map<String, dynamic>? ?? <String, dynamic>{},
    );
  }
}

class LikeResult {
  const LikeResult({
    required this.liked,
    required this.count,
    this.myReaction,
    this.reactionsPreview = const <String>[],
  });

  final bool liked;
  final int count;
  final String? myReaction;
  final List<String> reactionsPreview;
}

class MentionSuggestion {
  const MentionSuggestion({
    required this.id,
    required this.username,
    required this.fullname,
    required this.photoUrl,
    required this.verified,
  });

  final int id;
  final String username;
  final String fullname;
  final String photoUrl;
  final String verified;

  bool get isVerified => verified.trim().toLowerCase() == 'yes';

  factory MentionSuggestion.fromJson(Map<String, dynamic> json) {
    return MentionSuggestion(
      id: parseInt(json['id']),
      username: json['username']?.toString() ?? '',
      fullname: json['fullname']?.toString() ?? '',
      photoUrl: json['photo_url']?.toString() ?? '',
      verified: json['verified']?.toString() ?? '',
    );
  }
}
