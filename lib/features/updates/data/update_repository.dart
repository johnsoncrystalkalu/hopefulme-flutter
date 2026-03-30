import 'package:image_picker/image_picker.dart';
import 'package:hopefulme_flutter/core/network/api_client.dart';
import 'package:hopefulme_flutter/features/auth/data/auth_repository.dart';
import 'package:hopefulme_flutter/features/updates/models/update_detail.dart';

class UpdateRepository {
  UpdateRepository(this._authRepository);

  final AuthRepository _authRepository;

  Future<UpdateDetail> fetchUpdate(int id) async {
    final response = await _authRepository.get('updates/$id');
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

  Future<LikeResult> toggleLike(int id) async {
    final response = await _authRepository.post('likes/update/$id');
    return LikeResult(
      liked: response['liked'] as bool? ?? false,
      count: response['count'] as int? ?? 0,
    );
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
    return UpdateDetail.fromJson(
      response['update'] as Map<String, dynamic>? ?? <String, dynamic>{},
    );
  }

  Future<void> deleteUpdate(int updateId) async {
    await _authRepository.delete('updates/$updateId');
  }
}

class LikeResult {
  const LikeResult({required this.liked, required this.count});

  final bool liked;
  final int count;
}
