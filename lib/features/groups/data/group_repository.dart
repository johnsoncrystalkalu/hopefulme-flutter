import 'package:image_picker/image_picker.dart';
import 'package:hopefulme_flutter/core/network/api_client.dart';
import 'package:hopefulme_flutter/core/network/api_exception.dart';
import 'package:hopefulme_flutter/core/storage/page_cache.dart';
import 'package:hopefulme_flutter/features/auth/data/auth_repository.dart';
import 'package:hopefulme_flutter/features/groups/models/group_models.dart';

class GroupRepository {
  GroupRepository(this._authRepository, {PageCache? cache})
    : _cache = cache ?? PageCache();

  final AuthRepository _authRepository;
  final PageCache _cache;

  Future<GroupPage> fetchGroups({int page = 1}) async {
    final response = await _authRepository.get(
      'groups',
      queryParameters: {'page': page},
    );
    return GroupPage.fromJson(response);
  }

  Future<AppGroup> fetchGroup(int groupId) async {
    final key = 'group:$groupId';
    try {
      final response = await _authRepository.get('groups/$groupId');
      await _cache.save(key, response);
      return AppGroup.fromJson(
        response['data'] as Map<String, dynamic>? ?? <String, dynamic>{},
      );
    } catch (error) {
      final cached = await _cache.read(key);
      if (cached != null) {
        return AppGroup.fromJson(
          cached['data'] as Map<String, dynamic>? ?? <String, dynamic>{},
        );
      }
      rethrow;
    }
  }

  Future<AppGroup> joinGroup(int groupId) async {
    final response = await _authRepository.post('groups/$groupId/join');
    return AppGroup.fromJson(
      response['data'] as Map<String, dynamic>? ?? <String, dynamic>{},
    );
  }

  Future<GroupMessagePage> fetchMessages(
    int groupId, {
    int? beforeId,
    int? afterId,
  }) async {
    final key = 'group-messages:$groupId';
    final query = <String, dynamic>{};
    if (beforeId != null) {
      query['before_id'] = beforeId;
    }
    if (afterId != null) {
      query['after_id'] = afterId;
    }
    try {
      final response = await _authRepository.get(
        'groups/$groupId/messages',
        queryParameters: query,
      );
      if (beforeId == null && afterId == null) {
        await _cache.save(key, response);
      }
      return GroupMessagePage.fromJson(response);
    } catch (error) {
      if (beforeId == null && afterId == null) {
        final cached = await _cache.read(key);
        if (cached != null) {
          return GroupMessagePage.fromJson(cached);
        }
      }
      rethrow;
    }
  }

  Future<AppGroup> setTypingStatus(
    int groupId, {
    required bool isTyping,
  }) async {
    final response = await _authRepository.post(
      'groups/$groupId/typing',
      body: {'is_typing': isTyping},
    );
    return AppGroup.fromJson(
      response['data'] as Map<String, dynamic>? ?? <String, dynamic>{},
    );
  }

  Future<GroupMessage> sendMessage(
    int groupId, {
    required String message,
    int? replyId,
    XFile? photo,
  }) async {
    final trimmed = message.trim();
    final effectiveMessage = trimmed.isEmpty && photo != null
        ? 'Shared a photo'
        : trimmed;
    final response = photo == null
        ? await _authRepository.post(
            'groups/$groupId/messages',
            body: {
              'message': effectiveMessage,
              ...?switch (replyId) {
                final value? => {'reply_id': value},
                null => null,
              },
            },
          )
        : await _authRepository.postMultipart(
            'groups/$groupId/messages',
            fields: {
              'message': effectiveMessage,
              ...?switch (replyId) {
                final value? => {'reply_id': '$value'},
                null => null,
              },
            },
            files: [
              ApiMultipartFile(
                field: 'photo',
                filename: photo.name,
                bytes: await photo.readAsBytes(),
              ),
            ],
          );
    return GroupMessage.fromJson(
      response['data'] as Map<String, dynamic>? ?? <String, dynamic>{},
    );
  }

  Future<void> deleteMessage(int groupId, int messageId) async {
    await _authRepository.delete('groups/$groupId/messages/$messageId');
  }

  Future<GroupMessage> editMessage(
    int groupId,
    int messageId, {
    required String message,
  }) async {
    final payload = {'message': message.trim()};
    Map<String, dynamic> response;
    try {
      response = await _authRepository.put(
        'groups/$groupId/messages/$messageId',
        body: payload,
      );
    } on ApiException catch (error) {
      if (error.statusCode != 404 && error.statusCode != 405) {
        rethrow;
      }
      response = await _authRepository.patch(
        'groups/$groupId/messages/$messageId',
        body: payload,
      );
    }
    return GroupMessage.fromJson(
      response['data'] as Map<String, dynamic>? ?? <String, dynamic>{},
    );
  }
}
