import 'package:hopefulme_flutter/core/network/api_client.dart';
import 'package:hopefulme_flutter/core/network/api_exception.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hopefulme_flutter/features/auth/data/auth_repository.dart';
import 'package:hopefulme_flutter/features/messages/models/conversation_models.dart';

class MessageRepository {
  MessageRepository(this._authRepository);

  final AuthRepository _authRepository;

  Future<List<ConversationListItem>> fetchConversations() async {
    final response = await _authRepository.get('messages');
    final data = response['data'] as List<dynamic>? ?? <dynamic>[];
    return data
        .whereType<Map<String, dynamic>>()
        .map(ConversationListItem.fromJson)
        .toList();
  }

  Future<ConversationThread> fetchThread(
    String username, {
    int page = 1,
    int? beforeId,
    int? afterId,
  }) async {
    final query = <String, dynamic>{'page': page};
    if (beforeId != null) {
      query['before_id'] = beforeId;
    }
    if (afterId != null) {
      query['after_id'] = afterId;
    }
    final response = await _authRepository.get(
      'messages/$username',
      queryParameters: query,
    );
    return ConversationThread.fromJson(response);
  }

  Future<ConversationThread> fetchThreadUpdates(
    String username, {
    required int afterId,
  }) {
    return fetchThread(username, afterId: afterId);
  }

  Future<ChatMessage> sendMessage(
    String username, {
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
            'messages/$username',
            body: {
              if (effectiveMessage.isNotEmpty) 'message': effectiveMessage,
              ...?switch (replyId) {
                final id? => {'reply_id': id},
                null => null,
              },
            },
          )
        : await _authRepository.postMultipart(
            'messages/$username',
            fields: {
              'message': effectiveMessage,
              ...?switch (replyId) {
                final id? => {'reply_id': '$id'},
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
    return ChatMessage.fromJson(
      response['data'] as Map<String, dynamic>? ?? <String, dynamic>{},
    );
  }

  Future<ConversationListItem> setTypingStatus(
    String username, {
    required bool isTyping,
  }) async {
    final response = await _authRepository.post(
      'messages/$username/typing',
      body: {'is_typing': isTyping},
    );
    return ConversationListItem.fromJson(
      response['conversation'] as Map<String, dynamic>? ?? <String, dynamic>{},
    );
  }

  Future<void> deleteMessage(int messageId) async {
    await _authRepository.delete('messages/item/$messageId');
  }

  Future<ChatMessage> editMessage(
    int messageId, {
    required String message,
  }) async {
    final payload = {'message': message.trim()};
    Map<String, dynamic> response;
    try {
      response = await _authRepository.put(
        'messages/item/$messageId',
        body: payload,
      );
    } on ApiException catch (error) {
      if (error.statusCode != 404 && error.statusCode != 405) {
        rethrow;
      }
      response = await _authRepository.patch(
        'messages/item/$messageId',
        body: payload,
      );
    }
    return ChatMessage.fromJson(
      response['data'] as Map<String, dynamic>? ?? <String, dynamic>{},
    );
  }

  Future<ChatMessage> toggleReaction(
    int messageId, {
    required String emoji,
  }) async {
    final response = await _authRepository.post(
      'messages/item/$messageId/reactions',
      body: {'emoji': emoji},
    );
    return ChatMessage.fromJson(
      response['data'] as Map<String, dynamic>? ?? <String, dynamic>{},
    );
  }
}
