import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hopefulme_flutter/app/theme/app_theme.dart';
import 'package:hopefulme_flutter/core/network/api_exception.dart';
import 'package:hopefulme_flutter/core/widgets/app_status_state.dart';
import 'package:hopefulme_flutter/features/auth/models/user.dart';
import 'package:hopefulme_flutter/features/groups/data/group_repository.dart';
import 'package:hopefulme_flutter/features/groups/models/group_models.dart';
import 'package:hopefulme_flutter/features/messages/data/message_repository.dart';
import 'package:hopefulme_flutter/features/profile/data/profile_repository.dart';
import 'package:hopefulme_flutter/features/profile/presentation/profile_navigation.dart';
import 'package:hopefulme_flutter/features/updates/data/update_repository.dart';

class GroupThreadScreen extends StatefulWidget {
  const GroupThreadScreen({
    required this.groupId,
    required this.currentUser,
    required this.repository,
    required this.profileRepository,
    required this.messageRepository,
    required this.updateRepository,
    super.key,
  });

  final int groupId;
  final User? currentUser;
  final GroupRepository repository;
  final ProfileRepository profileRepository;
  final MessageRepository messageRepository;
  final UpdateRepository updateRepository;

  @override
  State<GroupThreadScreen> createState() => _GroupThreadScreenState();
}

class _GroupThreadScreenState extends State<GroupThreadScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  AppGroup? _group;
  List<GroupMessage> _messages = <GroupMessage>[];
  GroupMessage? _replyingTo;
  Timer? _pollTimer;
  bool _isLoading = true;
  bool _isSending = false;
  bool _isJoining = false;
  bool _isLoadingMore = false;
  bool _hasMore = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    _loadInitial();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _pollLatest());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final group = await widget.repository.fetchGroup(widget.groupId);
      List<GroupMessage> messages = <GroupMessage>[];
      var hasMore = false;
      if (group.isMember) {
        final page = await widget.repository.fetchMessages(widget.groupId);
        messages = page.messages;
        hasMore = page.hasMore;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _group = group;
        _messages = messages;
        _hasMore = hasMore;
      });
      _scrollToBottom(jump: true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pollLatest() async {
    final group = _group;
    if (!mounted || group == null || !group.isMember) {
      return;
    }

    try {
      final latestId = _messages.isEmpty ? null : _messages.last.id;
      final response = await widget.repository.fetchMessages(
        widget.groupId,
        afterId: latestId,
      );
      if (!mounted || response.messages.isEmpty) {
        return;
      }
      setState(() {
        _messages = _dedupeMessages([..._messages, ...response.messages]);
      });
      _scrollToBottom();
    } catch (_) {}
  }

  Future<void> _joinGroup() async {
    if (_isJoining) {
      return;
    }

    setState(() {
      _isJoining = true;
      _error = null;
    });

    try {
      await widget.repository.joinGroup(widget.groupId);
      await _loadInitial();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isJoining = false;
        });
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) {
      return;
    }

    setState(() {
      _isSending = true;
      _error = null;
    });

    try {
      final sent = await widget.repository.sendMessage(
        widget.groupId,
        message: text,
        replyId: _replyingTo?.id,
      );
      _controller.clear();
      if (!mounted) {
        return;
      }
      setState(() {
        _messages = _dedupeMessages([..._messages, sent]);
        _replyingTo = null;
      });
      _scrollToBottom();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_error?.toString() ?? 'Unable to send group message.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  Future<void> _deleteMessage(GroupMessage message) async {
    final group = _group;
    if (group == null) {
      return;
    }

    try {
      await widget.repository.deleteMessage(group.id, message.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _messages = _messages.where((item) => item.id != message.id).toList();
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _loadOlder() async {
    if (_isLoadingMore || !_hasMore || _messages.isEmpty) {
      return;
    }

    final firstId = _messages.first.id;
    final previousOffset = _scrollController.hasClients
        ? _scrollController.position.maxScrollExtent -
              _scrollController.position.pixels
        : 0.0;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final response = await widget.repository.fetchMessages(
        widget.groupId,
        beforeId: firstId,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _messages = _dedupeMessages([...response.messages, ..._messages]);
        _hasMore = response.hasMore;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(
            _scrollController.position.maxScrollExtent - previousOffset,
          );
        }
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  void _handleScroll() {
    if (!_scrollController.hasClients || _isLoading) {
      return;
    }
    if (_scrollController.position.pixels <= 80) {
      unawaited(_loadOlder());
    }
  }

  void _scrollToBottom({bool jump = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }
      final offset = _scrollController.position.maxScrollExtent;
      if (jump) {
        _scrollController.jumpTo(offset);
        return;
      }
      _scrollController.animateTo(
        offset,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  List<GroupMessage> _dedupeMessages(List<GroupMessage> items) {
    final seen = <int>{};
    return items.where((item) => seen.add(item.id)).toList();
  }

  Future<void> _openProfile(String username) async {
    await openUserProfile(
      context,
      profileRepository: widget.profileRepository,
      messageRepository: widget.messageRepository,
      updateRepository: widget.updateRepository,
      currentUser: widget.currentUser,
      username: username,
    );
  }

  String _initialLoadErrorMessage(Object error) {
    if (error is ApiException) {
      final code = error.statusCode;
      final message = error.message.trim().isEmpty
          ? 'Request failed'
          : error.message.trim();
      return code == null ? message : '[$code] $message';
    }

    final message = error.toString().trim();
    return message.isEmpty ? 'Unknown error' : message;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final group = _group;

    return Scaffold(
      backgroundColor: colors.scaffold,
      appBar: AppBar(
        titleSpacing: 8,
        title: group == null
            ? const Text('Group Chat')
            : Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundImage: group.photoUrl.isNotEmpty
                        ? NetworkImage(group.photoUrl)
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          group.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          group.communityLabel ??
                              '${group.membersCount} members'
                                  '${group.category.isNotEmpty ? ' · ${group.category}' : ''}',
                          style: TextStyle(
                            color: colors.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && group == null
          ? AppStatusState(
              title: 'Unable to open group',
              message: _initialLoadErrorMessage(_error!),
              actionLabel: 'Try again',
              onAction: _loadInitial,
            )
          : Column(
              children: [
                if (_error != null && group != null)
                  Container(
                    width: double.infinity,
                    color: colors.dangerSoft,
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      _error!.toString(),
                      style: TextStyle(color: colors.dangerText),
                    ),
                  ),
                Expanded(
                  child: group == null
                      ? const SizedBox.shrink()
                      : !group.isMember
                      ? _LockedGroupState(
                          group: group,
                          isJoining: _isJoining,
                          onJoin: _joinGroup,
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                          itemCount: _messages.length + (_isLoadingMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (_isLoadingMore && index == 0) {
                              return const Padding(
                                padding: EdgeInsets.only(bottom: 16),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }

                            final message = _messages[
                                _isLoadingMore ? index - 1 : index];
                            final isMine =
                                widget.currentUser?.id == message.userId;
                            return _GroupMessageBubble(
                              message: message,
                              isMine: isMine,
                              canDelete: isMine || group.isOwner,
                              onProfileTap: message.sender == null
                                  ? null
                                  : () => _openProfile(message.sender!.username),
                              onReply: () {
                                setState(() {
                                  _replyingTo = message;
                                });
                              },
                              onDelete: () => _deleteMessage(message),
                            );
                          },
                        ),
                ),
                if (group != null && group.isMember) ...[
                  if (_replyingTo != null)
                    _ReplyPreview(
                      message: _replyingTo!,
                      onClear: () {
                        setState(() {
                          _replyingTo = null;
                        });
                      },
                    ),
                  SafeArea(
                    top: false,
                    child: Container(
                      color: colors.surface,
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              minLines: 1,
                              maxLines: 5,
                              onSubmitted: (_) => _sendMessage(),
                              decoration: InputDecoration(
                                hintText: 'Message ${group.name}...',
                                filled: true,
                                fillColor: colors.surfaceMuted,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          IconButton.filled(
                            onPressed: _isSending ? null : _sendMessage,
                            icon: _isSending
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.send),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

class _LockedGroupState extends StatelessWidget {
  const _LockedGroupState({
    required this.group,
    required this.isJoining,
    required this.onJoin,
  });

  final AppGroup group;
  final bool isJoining;
  final Future<void> Function() onJoin;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 34,
                backgroundImage: group.photoUrl.isNotEmpty
                    ? NetworkImage(group.photoUrl)
                    : null,
              ),
              const SizedBox(height: 14),
              Text(
                group.name,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                group.isPrivate
                    ? 'This is a private group. Contact the admin to join.'
                    : 'Join this group to start chatting with the community.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              if (!group.isPrivate) ...[
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: isJoining ? null : onJoin,
                  child: isJoining
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Join Group'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ReplyPreview extends StatelessWidget {
  const _ReplyPreview({
    required this.message,
    required this.onClear,
  });

  final GroupMessage message;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: colors.accentSoft,
        border: Border(
          top: BorderSide(color: colors.border),
          bottom: BorderSide(color: colors.border),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Replying to ${message.sender?.displayName ?? 'member'}',
                  style: TextStyle(
                    color: colors.brand,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message.message,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onClear,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}

class _GroupMessageBubble extends StatelessWidget {
  const _GroupMessageBubble({
    required this.message,
    required this.isMine,
    required this.canDelete,
    required this.onProfileTap,
    required this.onReply,
    required this.onDelete,
  });

  final GroupMessage message;
  final bool isMine;
  final bool canDelete;
  final VoidCallback? onProfileTap;
  final VoidCallback onReply;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isMine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMine) ...[
            InkWell(
              onTap: onProfileTap,
              borderRadius: BorderRadius.circular(999),
              child: CircleAvatar(
                radius: 14,
                backgroundImage: message.sender?.photoUrl.isNotEmpty == true
                    ? NetworkImage(message.sender!.photoUrl)
                    : null,
                child: message.sender?.photoUrl.isEmpty ?? true
                    ? const Icon(Icons.person, size: 14)
                    : null,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMine
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (!isMine)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 4),
                    child: InkWell(
                      onTap: onProfileTap,
                      borderRadius: BorderRadius.circular(8),
                      child: Text(
                        message.sender?.displayName ?? 'Member',
                        style: TextStyle(
                          color: colors.brand,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  onSelected: (value) {
                    if (value == 'reply') {
                      onReply();
                    }
                    if (value == 'delete') {
                      onDelete();
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'reply', child: Text('Reply')),
                    if (canDelete)
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete'),
                      ),
                  ],
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 320),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isMine ? colors.brand : colors.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: isMine ? null : Border.all(color: colors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (message.replyTo != null)
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isMine
                                  ? Colors.white.withOpacity(0.16)
                                  : colors.surfaceMuted,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  message.replyTo?.sender?.displayName ??
                                      'Member',
                                  style: TextStyle(
                                    color: isMine
                                        ? Colors.white
                                        : colors.textPrimary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  message.replyTo?.message ?? '',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: isMine
                                        ? Colors.white70
                                        : colors.textMuted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (message.photoUrl.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Image.network(
                                message.photoUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    const SizedBox.shrink(),
                              ),
                            ),
                          ),
                        if (message.message.isNotEmpty)
                          Text(
                            message.message,
                            style: TextStyle(
                              color: isMine ? Colors.white : colors.textPrimary,
                              fontSize: 14,
                              height: 1.45,
                            ),
                          ),
                        const SizedBox(height: 6),
                        Text(
                          message.time,
                          style: TextStyle(
                            color: isMine ? Colors.white70 : colors.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
