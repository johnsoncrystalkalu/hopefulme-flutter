import 'package:hopefulme_flutter/features/auth/data/auth_repository.dart';
import 'package:hopefulme_flutter/features/groups/models/group_models.dart';

class GroupRepository {
  GroupRepository(this._authRepository);

  final AuthRepository _authRepository;

  Future<GroupPage> fetchGroups({int page = 1}) async {
    final response = await _authRepository.get(
      'groups',
      queryParameters: {'page': page},
    );
    return GroupPage.fromJson(response);
  }

  Future<AppGroup> fetchGroup(int groupId) async {
    final response = await _authRepository.get('groups/$groupId');
    return AppGroup.fromJson(
      response['data'] as Map<String, dynamic>? ?? <String, dynamic>{},
    );
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
    final query = <String, dynamic>{};
    if (beforeId != null) {
      query['before_id'] = beforeId;
    }
    if (afterId != null) {
      query['after_id'] = afterId;
    }
    final response = await _authRepository.get(
      'groups/$groupId/messages',
      queryParameters: query,
    );
    return GroupMessagePage.fromJson(response);
  }

  Future<GroupMessage> sendMessage(
    int groupId, {
    required String message,
    int? replyId,
  }) async {
    final response = await _authRepository.post(
      'groups/$groupId/messages',
      body: {
        'message': message,
        if (replyId != null) 'reply_id': replyId,
      },
    );
    return GroupMessage.fromJson(
      response['data'] as Map<String, dynamic>? ?? <String, dynamic>{},
    );
  }

  Future<void> deleteMessage(int groupId, int messageId) async {
    await _authRepository.delete('groups/$groupId/messages/$messageId');
  }
}
