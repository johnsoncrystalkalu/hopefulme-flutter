import 'dart:typed_data';

import 'package:hopefulme_flutter/core/network/image_url_resolver.dart';
import 'package:hopefulme_flutter/core/utils/json_parsing.dart';

class ConversationListItem {
  const ConversationListItem({
    required this.id,
    required this.status,
    required this.typingUserId,
    required this.typingAt,
    required this.typingUserName,
    required this.updatedAt,
    required this.unreadCount,
    required this.otherUser,
    required this.latestMessage,
  });

  final int id;
  final String status;
  final int typingUserId;
  final String typingAt;
  final String typingUserName;
  final String updatedAt;
  final int unreadCount;
  final ConversationUser otherUser;
  final ChatMessage? latestMessage;

  factory ConversationListItem.fromJson(Map<String, dynamic> json) {
    return ConversationListItem(
      id: parseInt(json['id']),
      status: json['status']?.toString() ?? '',
      typingUserId: parseInt(json['typing_user_id']),
      typingAt: json['typing_at']?.toString() ?? '',
      typingUserName: json['typing_user_name']?.toString() ?? '',
      updatedAt: json['updated_at']?.toString() ?? '',
      unreadCount: parseInt(json['unread_count']),
      otherUser: ConversationUser.fromJson(
        json['other_user'] as Map<String, dynamic>? ?? <String, dynamic>{},
      ),
      latestMessage: (json['latest_message'] as Map<String, dynamic>?)?.let(
        ChatMessage.fromJson,
      ),
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
    required this.isVerified,
  });

  final int id;
  final String username;
  final String fullname;
  final String photoUrl;
  final String lastSeen;
  final bool isOnline;
  final bool isVerified;

  String get displayName => fullname.isNotEmpty ? fullname : username;

  factory ConversationUser.fromJson(Map<String, dynamic> json) {
    return ConversationUser(
      id: parseInt(json['id']),
      username: json['username']?.toString() ?? '',
      fullname: json['fullname']?.toString() ?? '',
      photoUrl: ImageUrlResolver.resolve(json['photo_url']?.toString() ?? ''),
      lastSeen: json['last_seen']?.toString() ?? '',
      isOnline: parseBool(json['is_online']),
      isVerified: parseBool(json['verified']),
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
    required this.replyId,
    required this.status,
    required this.createdAt,
    required this.sender,
    required this.recipient,
    required this.replyTo,
    required this.reactions,
    this.localImageBytes,
  });

  final int id;
  final int conversationId;
  final int senderId;
  final int recipientId;
  final String message;
  final String photoUrl;
  final int replyId;
  final String status;
  final String createdAt;
  final ConversationUser? sender;
  final ConversationUser? recipient;
  final ChatMessageReply? replyTo;
  final List<ChatReactionSummary> reactions;
  final Uint8List? localImageBytes;

  ChatMessage copyWith({
    String? message,
    String? photoUrl,
    String? status,
    List<ChatReactionSummary>? reactions,
    Uint8List? localImageBytes,
    bool clearLocalImageBytes = false,
  }) {
    return ChatMessage(
      id: id,
      conversationId: conversationId,
      senderId: senderId,
      recipientId: recipientId,
      message: message ?? this.message,
      photoUrl: photoUrl ?? this.photoUrl,
      replyId: replyId,
      status: status ?? this.status,
      createdAt: createdAt,
      sender: sender,
      recipient: recipient,
      replyTo: replyTo,
      reactions: reactions ?? this.reactions,
      localImageBytes: clearLocalImageBytes
          ? null
          : (localImageBytes ?? this.localImageBytes),
    );
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final parsedReactions =
        (json['reactions'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(ChatReactionSummary.fromJson)
            .toList();

    return ChatMessage(
      id: parseInt(json['id']),
      conversationId: parseInt(json['conversation_id']),
      senderId: parseInt(json['sender_id']),
      recipientId: parseInt(json['recipient_id']),
      message: json['message']?.toString() ?? '',
      photoUrl: ImageUrlResolver.resolve(json['photo_url']?.toString() ?? ''),
      replyId: parseInt(json['reply_id']),
      status: json['status']?.toString() ?? '',
      createdAt: json['created_at']?.toString() ?? '',
      sender: (json['sender'] as Map<String, dynamic>?)?.let(
        ConversationUser.fromJson,
      ),
      recipient: (json['recipient'] as Map<String, dynamic>?)?.let(
        ConversationUser.fromJson,
      ),
      replyTo: (json['reply_to'] as Map<String, dynamic>?)?.let(
        ChatMessageReply.fromJson,
      ),
      reactions: _mergeChatReactionSummaries(parsedReactions),
    );
  }
}

class ConversationListPage {
  const ConversationListPage({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.perPage,
    required this.total,
    required this.unreadTotal,
  });

  final List<ConversationListItem> items;
  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;
  final int unreadTotal;

  bool get hasMore => currentPage < lastPage;

  factory ConversationListPage.fromJson(Map<String, dynamic> json) {
    final meta = json['meta'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final data = json['data'] as List<dynamic>? ?? <dynamic>[];

    return ConversationListPage(
      items: data
          .whereType<Map<String, dynamic>>()
          .map(ConversationListItem.fromJson)
          .toList(),
      currentPage: parseInt(meta['current_page'], fallback: 1),
      lastPage: parseInt(meta['last_page'], fallback: 1),
      perPage: parseInt(meta['per_page'], fallback: 10),
      total: parseInt(meta['total']),
      unreadTotal: parseInt(meta['unread_total']),
    );
  }
}

class ChatReactionSummary {
  const ChatReactionSummary({
    required this.emoji,
    required this.count,
    required this.reactedByMe,
  });

  final String emoji;
  final int count;
  final bool reactedByMe;

  ChatReactionSummary copyWith({String? emoji, int? count, bool? reactedByMe}) {
    return ChatReactionSummary(
      emoji: emoji ?? this.emoji,
      count: count ?? this.count,
      reactedByMe: reactedByMe ?? this.reactedByMe,
    );
  }

  factory ChatReactionSummary.fromJson(Map<String, dynamic> json) {
    return ChatReactionSummary(
      emoji: json['emoji']?.toString() ?? '',
      count: parseInt(json['count']),
      reactedByMe: parseBool(json['reacted_by_me']),
    );
  }
}

List<ChatReactionSummary> _mergeChatReactionSummaries(
  List<ChatReactionSummary> input,
) {
  if (input.isEmpty) {
    return const <ChatReactionSummary>[];
  }

  final merged = <String, ChatReactionSummary>{};
  for (final reaction in input) {
    final key = _normalizedChatReactionKey(reaction.emoji);
    final existing = merged[key];
    if (existing == null) {
      merged[key] = reaction;
      continue;
    }
    merged[key] = ChatReactionSummary(
      emoji: existing.emoji.isNotEmpty ? existing.emoji : reaction.emoji,
      count: existing.count + reaction.count,
      reactedByMe: existing.reactedByMe || reaction.reactedByMe,
    );
  }

  final items = merged.values.toList()
    ..sort((a, b) => b.count.compareTo(a.count));
  return items;
}

String _normalizedChatReactionKey(String emoji) {
  return emoji.replaceAll('\uFE0F', '').replaceAll('\uFE0E', '').trim();
}

class ChatMessageReply {
  const ChatMessageReply({
    required this.id,
    required this.message,
    required this.sender,
  });

  final int id;
  final String message;
  final ConversationUser? sender;

  factory ChatMessageReply.fromJson(Map<String, dynamic> json) {
    return ChatMessageReply(
      id: parseInt(json['id']),
      message: json['message']?.toString() ?? '',
      sender: (json['sender'] as Map<String, dynamic>?)?.let(
        ConversationUser.fromJson,
      ),
    );
  }
}

extension<T> on T {
  R let<R>(R Function(T value) mapper) => mapper(this);
}
