import 'package:hopefulme_flutter/core/network/api_client.dart';
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
  }) async {
    final response = await _authRepository.get(
      'messages/$username',
      queryParameters: {'page': page},
    );
    return ConversationThread.fromJson(response);
  }

  Future<ChatMessage> sendMessage(
    String username, {
    required String message,
    int? replyId,
    XFile? photo,
  }) async {
    final trimmed = message.trim();
    final response = photo == null
        ? await _authRepository.post(
            'messages/$username',
            body: {
              if (trimmed.isNotEmpty) 'message': trimmed,
              if (replyId case final id?) 'reply_id': id,
            },
          )
        : await _authRepository.postMultipart(
            'messages/$username',
            fields: {
              if (trimmed.isNotEmpty) 'message': trimmed,
              if (replyId case final id?) 'reply_id': '$id',
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
}
