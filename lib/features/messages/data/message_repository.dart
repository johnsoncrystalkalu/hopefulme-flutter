import 'package:hopefulme_flutter/features/auth/data/auth_repository.dart';
import 'package:hopefulme_flutter/core/storage/page_cache.dart';
import 'package:hopefulme_flutter/features/messages/models/conversation_models.dart';

class MessageRepository {
  MessageRepository(this._authRepository, {PageCache? cache})
    : _cache = cache ?? PageCache();

  final AuthRepository _authRepository;
  final PageCache _cache;

  Future<List<ConversationListItem>> fetchConversations() async {
    const key = 'messages';
    try {
      final response = await _authRepository.get('messages');
      await _cache.save(key, response);
      final data = response['data'] as List<dynamic>? ?? <dynamic>[];
      return data
          .whereType<Map<String, dynamic>>()
          .map(ConversationListItem.fromJson)
          .toList();
    } catch (error) {
      final cached = await _cache.read(key);
      if (cached != null) {
        final data = cached['data'] as List<dynamic>? ?? <dynamic>[];
        return data
            .whereType<Map<String, dynamic>>()
            .map(ConversationListItem.fromJson)
            .toList();
      }
      rethrow;
    }
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
  }) async {
    final response = await _authRepository.post(
      'messages/$username',
      body: {'message': message},
    );
    return ChatMessage.fromJson(
      response['data'] as Map<String, dynamic>? ?? <String, dynamic>{},
    );
  }
}
