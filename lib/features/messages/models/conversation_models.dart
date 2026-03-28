import 'package:hopefulme_flutter/core/network/image_url_resolver.dart';
import 'package:hopefulme_flutter/core/utils/json_parsing.dart';

class ConversationListItem {
  const ConversationListItem({
    required this.id,
    required this.status,
    required this.updatedAt,
    required this.unreadCount,
    required this.otherUser,
    required this.latestMessage,
  });

  final int id;
  final String status;
  final String updatedAt;
  final int unreadCount;
  final ConversationUser otherUser;
  final ChatMessage? latestMessage;

  factory ConversationListItem.fromJson(Map<String, dynamic> json) {
    return ConversationListItem(
      id: parseInt(json['id']),
      status: json['status']?.toString() ?? '',
      updatedAt: json['updated_at']?.toString() ?? '',
      unreadCount: parseInt(json['unread_count']),
      otherUser: ConversationUser.fromJson(
        json['other_user'] as Map<String, dynamic>? ?? <String, dynamic>{},
      ),
      latestMessage: (json['latest_message'] as Map<String, dynamic>?)
          ?.let(ChatMessage.fromJson),
    );
  }
}

class ConversationUser {
  const ConversationUser({
    required this.id,
    required this.username,
    required this.fullname,
    required this.photoUrl,
    required this.lastSeen,
    required this.isOnline,
  });

  final int id;
  final String username;
  final String fullname;
  final String photoUrl;
  final String lastSeen;
  final bool isOnline;

  String get displayName => fullname.isNotEmpty ? fullname : username;

  factory ConversationUser.fromJson(Map<String, dynamic> json) {
    return ConversationUser(
      id: parseInt(json['id']),
      username: json['username']?.toString() ?? '',
      fullname: json['fullname']?.toString() ?? '',
      photoUrl: ImageUrlResolver.resolve(json['photo_url']?.toString() ?? ''),
      lastSeen: json['last_seen']?.toString() ?? '',
      isOnline: parseBool(json['is_online']),
    );
  }
}

class ConversationThread {
  const ConversationThread({
    required this.conversation,
    required this.messages,
    required this.currentPage,
    required this.lastPage,
  });

  final ConversationListItem conversation;
  final List<ChatMessage> messages;
  final int currentPage;
  final int lastPage;

  bool get hasMore => currentPage < lastPage;

  factory ConversationThread.fromJson(Map<String, dynamic> json) {
    final meta = json['meta'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final messages = json['messages'] as List<dynamic>? ?? <dynamic>[];

    return ConversationThread(
      conversation: ConversationListItem.fromJson(
        json['conversation'] as Map<String, dynamic>? ?? <String, dynamic>{},
      ),
      messages: messages
          .whereType<Map<String, dynamic>>()
          .map(ChatMessage.fromJson)
          .toList(),
      currentPage: parseInt(meta['current_page'], fallback: 1),
      lastPage: parseInt(meta['last_page'], fallback: 1),
    );
  }
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.recipientId,
    required this.message,
    required this.photoUrl,
    required this.status,
    required this.createdAt,
    required this.sender,
    required this.recipient,
  });

  final int id;
  final int conversationId;
  final int senderId;
  final int recipientId;
  final String message;
  final String photoUrl;
  final String status;
  final String createdAt;
  final ConversationUser? sender;
  final ConversationUser? recipient;

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: parseInt(json['id']),
      conversationId: parseInt(json['conversation_id']),
      senderId: parseInt(json['sender_id']),
      recipientId: parseInt(json['recipient_id']),
      message: json['message']?.toString() ?? '',
      photoUrl: ImageUrlResolver.resolve(json['photo_url']?.toString() ?? ''),
      status: json['status']?.toString() ?? '',
      createdAt: json['created_at']?.toString() ?? '',
      sender: (json['sender'] as Map<String, dynamic>?)
          ?.let(ConversationUser.fromJson),
      recipient: (json['recipient'] as Map<String, dynamic>?)
          ?.let(ConversationUser.fromJson),
    );
  }
}

extension<T> on T {
  R let<R>(R Function(T value) mapper) => mapper(this);
}
