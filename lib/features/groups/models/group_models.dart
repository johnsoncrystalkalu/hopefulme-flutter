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
    required this.updatedAt,
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
  final String updatedAt;
  final String? communityLabel;
  final ConversationUser? owner;
  final GroupMessage? latestMessage;

  bool get isPrivate => type == 'private';
  bool get isCommunity => id == 1;

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
      updatedAt: json['updated_at']?.toString() ?? '',
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
  const GroupMessagePage({required this.messages, required this.hasMore});

  final List<GroupMessage> messages;
  final bool hasMore;

  factory GroupMessagePage.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as List<dynamic>? ?? <dynamic>[];
    return GroupMessagePage(
      messages: data
          .whereType<Map<String, dynamic>>()
          .map(GroupMessage.fromJson)
          .toList(),
      hasMore: parseBool(json['has_more']),
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
  final Uint8List? localImageBytes;

  factory GroupMessage.fromJson(Map<String, dynamic> json) {
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
    );
  }
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
