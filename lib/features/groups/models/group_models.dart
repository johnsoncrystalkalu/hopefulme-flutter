import 'dart:typed_data';

import 'package:hopefulme_flutter/core/network/image_url_resolver.dart';
import 'package:hopefulme_flutter/core/utils/json_parsing.dart';
import 'package:hopefulme_flutter/features/messages/models/conversation_models.dart';

class GroupPage {
  const GroupPage({
    required this.items,
    required this.currentPage,
    required this.lastPage,
  });

  final List<AppGroup> items;
  final int currentPage;
  final int lastPage;

  bool get hasMore => currentPage < lastPage;

  factory GroupPage.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as List<dynamic>? ?? <dynamic>[];
    final meta = json['meta'] as Map<String, dynamic>? ?? <String, dynamic>{};

    return GroupPage(
      items: data
          .whereType<Map<String, dynamic>>()
          .map(AppGroup.fromJson)
          .toList(),
      currentPage: parseInt(meta['current_page'], fallback: 1),
      lastPage: parseInt(meta['last_page'], fallback: 1),
    );
  }
}

class AppGroup {
  const AppGroup({
    required this.id,
    required this.name,
    required this.info,
    required this.category,
    required this.type,
    required this.status,
    required this.photoUrl,
    required this.isMember,
    required this.isOwner,
    required this.membersCount,
    required this.unreadCount,
    required this.updatedAt,
    required this.typingUserId,
    required this.typingAt,
    required this.typingUserName,
    required this.communityLabel,
    required this.owner,
    required this.latestMessage,
  });

  final int id;
  final String name;
  final String info;
  final String category;
  final String type;
  final String status;
  final String photoUrl;
  final bool isMember;
  final bool isOwner;
  final int membersCount;
  final int unreadCount;
  final String updatedAt;
  final int? typingUserId;
  final String typingAt;
  final String typingUserName;
  final String? communityLabel;
  final ConversationUser? owner;
  final GroupMessage? latestMessage;

  bool get isPrivate => type == 'private';
  bool get isCommunity => id == 1;
  bool get hasUnread => unreadCount > 0;

  AppGroup copyWith({
    int? id,
    String? name,
    String? info,
    String? category,
    String? type,
    String? status,
    String? photoUrl,
    bool? isMember,
    bool? isOwner,
    int? membersCount,
    int? unreadCount,
    String? updatedAt,
    int? typingUserId,
    bool clearTypingUserId = false,
    String? typingAt,
    String? typingUserName,
    String? communityLabel,
    bool clearCommunityLabel = false,
    ConversationUser? owner,
    bool clearOwner = false,
    GroupMessage? latestMessage,
    bool clearLatestMessage = false,
  }) {
    return AppGroup(
      id: id ?? this.id,
      name: name ?? this.name,
      info: info ?? this.info,
      category: category ?? this.category,
      type: type ?? this.type,
      status: status ?? this.status,
      photoUrl: photoUrl ?? this.photoUrl,
      isMember: isMember ?? this.isMember,
      isOwner: isOwner ?? this.isOwner,
      membersCount: membersCount ?? this.membersCount,
      unreadCount: unreadCount ?? this.unreadCount,
      updatedAt: updatedAt ?? this.updatedAt,
      typingUserId: clearTypingUserId
          ? null
          : (typingUserId ?? this.typingUserId),
      typingAt: typingAt ?? this.typingAt,
      typingUserName: typingUserName ?? this.typingUserName,
      communityLabel: clearCommunityLabel
          ? null
          : (communityLabel ?? this.communityLabel),
      owner: clearOwner ? null : (owner ?? this.owner),
      latestMessage: clearLatestMessage
          ? null
          : (latestMessage ?? this.latestMessage),
    );
  }

  factory AppGroup.fromJson(Map<String, dynamic> json) {
    return AppGroup(
      id: parseInt(json['id']),
      name: json['name']?.toString() ?? '',
      info: json['info']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      type: json['type']?.toString() ?? 'public',
      status: json['status']?.toString() ?? '',
      photoUrl: ImageUrlResolver.resolve(json['photo_url']?.toString() ?? ''),
      isMember: parseBool(json['is_member']),
      isOwner: parseBool(json['is_owner']),
      membersCount: parseInt(json['members_count']),
      unreadCount: parseInt(json['unread_count']),
      updatedAt: json['updated_at']?.toString() ?? '',
      typingUserId: json['typing_user_id'] == null
          ? null
          : parseInt(json['typing_user_id']),
      typingAt: json['typing_at']?.toString() ?? '',
      typingUserName: json['typing_user_name']?.toString() ?? '',
      communityLabel: json['community_label']?.toString(),
      owner: (json['owner'] as Map<String, dynamic>?)?.let(
        ConversationUser.fromJson,
      ),
      latestMessage: (json['latest_message'] as Map<String, dynamic>?)?.let(
        GroupMessage.fromJson,
      ),
    );
  }
}

class GroupMessagePage {
  const GroupMessagePage({
    required this.messages,
    required this.hasMore,
    required this.lastReadMessageId,
    required this.group,
  });

  final List<GroupMessage> messages;
  final bool hasMore;
  final int lastReadMessageId;
  final AppGroup? group;

  factory GroupMessagePage.fromJson(Map<String, dynamic> json) {
    final payload = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;
    final rawMessages =
        (payload['messages'] as List<dynamic>?) ??
        (payload['data'] as List<dynamic>?) ??
        (json['messages'] as List<dynamic>?) ??
        (json['data'] as List<dynamic>?) ??
        <dynamic>[];

    return GroupMessagePage(
      messages: rawMessages
          .whereType<Map<String, dynamic>>()
          .map(GroupMessage.fromJson)
          .toList(),
      hasMore: parseBool(payload['has_more'] ?? json['has_more']),
      lastReadMessageId: parseInt(
        payload['last_read_message_id'] ?? json['last_read_message_id'],
      ),
      group: ((payload['group'] ?? json['group']) as Map<String, dynamic>?)
          ?.let(AppGroup.fromJson),
    );
  }
}

class GroupMessage {
  const GroupMessage({
    required this.id,
    required this.groupId,
    required this.userId,
    required this.message,
    required this.photoUrl,
    required this.status,
    required this.replyId,
    required this.createdAt,
    required this.time,
    required this.sender,
    required this.replyTo,
    required this.reactions,
    this.localImageBytes,
  });

  final int id;
  final int groupId;
  final int userId;
  final String message;
  final String photoUrl;
  final String status;
  final int? replyId;
  final String createdAt;
  final String time;
  final ConversationUser? sender;
  final GroupReply? replyTo;
  final List<ChatReactionSummary> reactions;
  final Uint8List? localImageBytes;

  GroupMessage copyWith({
    String? message,
    String? photoUrl,
    String? status,
    List<ChatReactionSummary>? reactions,
    Uint8List? localImageBytes,
    bool clearLocalImageBytes = false,
  }) {
    return GroupMessage(
      id: id,
      groupId: groupId,
      userId: userId,
      message: message ?? this.message,
      photoUrl: photoUrl ?? this.photoUrl,
      status: status ?? this.status,
      replyId: replyId,
      createdAt: createdAt,
      time: time,
      sender: sender,
      replyTo: replyTo,
      reactions: reactions ?? this.reactions,
      localImageBytes: clearLocalImageBytes
          ? null
          : (localImageBytes ?? this.localImageBytes),
    );
  }

  factory GroupMessage.fromJson(Map<String, dynamic> json) {
    final parsedReactions =
        (json['reactions'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(ChatReactionSummary.fromJson)
            .toList();

    return GroupMessage(
      id: parseInt(json['id']),
      groupId: parseInt(json['group_id']),
      userId: parseInt(json['user_id']),
      message: json['message']?.toString() ?? '',
      photoUrl: ImageUrlResolver.resolve(json['photo_url']?.toString() ?? ''),
      status: json['status']?.toString() ?? '',
      replyId: json['reply_id'] == null ? null : parseInt(json['reply_id']),
      createdAt: json['created_at']?.toString() ?? '',
      time: json['time']?.toString() ?? '',
      sender: (json['sender'] as Map<String, dynamic>?)?.let(
        ConversationUser.fromJson,
      ),
      replyTo: (json['reply_to'] as Map<String, dynamic>?)?.let(
        GroupReply.fromJson,
      ),
      reactions: _mergeReactionSummaries(parsedReactions),
    );
  }
}

List<ChatReactionSummary> _mergeReactionSummaries(
  List<ChatReactionSummary> input,
) {
  if (input.isEmpty) {
    return const <ChatReactionSummary>[];
  }

  final merged = <String, ChatReactionSummary>{};
  for (final reaction in input) {
    final key = _normalizedReactionKey(reaction.emoji);
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

String _normalizedReactionKey(String emoji) {
  return emoji.replaceAll('\uFE0F', '').replaceAll('\uFE0E', '').trim();
}

class GroupReply {
  const GroupReply({
    required this.id,
    required this.message,
    required this.sender,
  });

  final int id;
  final String message;
  final ConversationUser? sender;

  factory GroupReply.fromJson(Map<String, dynamic> json) {
    return GroupReply(
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
