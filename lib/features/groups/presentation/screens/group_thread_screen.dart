import 'dart:async';
import 'dart:typed_data';

import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hopefulme_flutter/app/theme/app_theme.dart';
import 'package:hopefulme_flutter/core/network/api_exception.dart';
import 'package:hopefulme_flutter/core/widgets/app_send_action_button.dart';
import 'package:hopefulme_flutter/core/widgets/app_status_state.dart';
import 'package:hopefulme_flutter/core/widgets/app_toast.dart';
import 'package:hopefulme_flutter/core/widgets/rich_display_text.dart';
import 'package:hopefulme_flutter/features/auth/models/user.dart';
import 'package:hopefulme_flutter/features/groups/data/group_repository.dart';
import 'package:hopefulme_flutter/features/groups/models/group_models.dart';
import 'package:hopefulme_flutter/features/messages/models/conversation_models.dart';
import 'package:hopefulme_flutter/features/messages/data/message_repository.dart';
import 'package:hopefulme_flutter/features/profile/data/profile_repository.dart';
import 'package:hopefulme_flutter/features/profile/presentation/profile_navigation.dart';
import 'package:hopefulme_flutter/features/updates/data/update_repository.dart';
import 'package:url_launcher/url_launcher.dart';

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
  final ImagePicker _imagePicker = ImagePicker();
  AppGroup? _group;
  List<GroupMessage> _messages = <GroupMessage>[];
  GroupMessage? _replyingTo;
  Timer? _pollTimer;
  bool _isLoading = true;
  bool _isSending = false;
  bool _isJoining = false;
  bool _isLoadingMore = false;
  bool _hasMore = false;
  bool _showEmojiPicker = false;
  XFile? _selectedPhoto;
  Uint8List? _selectedPhotoBytes;
  int _optimisticId = -1;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    _loadInitial();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _pollLatest(),
    );
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
    final hasPhoto = _selectedPhoto != null;
    if (text.isEmpty && !hasPhoto) {
      return;
    }

    final selectedPhoto = _selectedPhoto;
    final localPhotoBytes = _selectedPhotoBytes;
    final optimisticId = _optimisticId--;
    final optimisticMessage = GroupMessage(
      id: optimisticId,
      groupId: widget.groupId,
      userId: widget.currentUser?.id ?? 0,
      message: text,
      photoUrl: '',
      status: 'sending',
      replyId: _replyingTo?.id,
      createdAt: DateTime.now().toIso8601String(),
      time: 'Now',
      sender: _group?.owner?.id == widget.currentUser?.id
          ? _group?.owner
          : ConversationUser(
              id: widget.currentUser?.id ?? 0,
              username: widget.currentUser?.username ?? '',
              fullname: widget.currentUser?.fullname ?? '',
              photoUrl: widget.currentUser?.photoUrl ?? '',
              lastSeen: '',
              isOnline: true,
            ),
      replyTo: _replyingTo == null
          ? null
          : GroupReply(
              id: _replyingTo!.id,
              message: _replyingTo!.message,
              sender: _replyingTo!.sender,
            ),
      localImageBytes: localPhotoBytes,
    );

    setState(() {
      _error = null;
      _messages = _dedupeMessages([..._messages, optimisticMessage]);
      _selectedPhoto = null;
      _selectedPhotoBytes = null;
      _showEmojiPicker = false;
      _replyingTo = null;
    });
    _controller.clear();
    _scrollToBottom();

    try {
      final sent = await widget.repository.sendMessage(
        widget.groupId,
        message: text,
        replyId: optimisticMessage.replyId,
        photo: selectedPhoto,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _messages = _messages
            .map((item) => item.id == optimisticId ? sent : item)
            .toList();
      });
      _scrollToBottom();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
        _messages = _messages.where((item) => item.id != optimisticId).toList();
        if (selectedPhoto != null && _selectedPhoto == null) {
          _selectedPhoto = selectedPhoto;
          _selectedPhotoBytes = localPhotoBytes;
        }
        if (text.isNotEmpty && _controller.text.trim().isEmpty) {
          _controller.text = text;
        }
        if (_replyingTo == null && optimisticMessage.replyTo != null) {
          _replyingTo = GroupMessage(
            id: optimisticMessage.replyTo!.id,
            groupId: widget.groupId,
            userId: optimisticMessage.replyTo!.sender?.id ?? 0,
            message: optimisticMessage.replyTo!.message,
            photoUrl: '',
            status: '',
            replyId: null,
            createdAt: '',
            time: '',
            sender: optimisticMessage.replyTo!.sender,
            replyTo: null,
          );
        }
      });
      AppToast.error(
        context,
        _error?.toString() ?? 'Unable to send group message.',
      );
    } finally {
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final photo = await _imagePicker.pickImage(
      source: source,
      imageQuality: 88,
      maxWidth: 1800,
    );
    if (photo == null || !mounted) {
      return;
    }
    final bytes = await photo.readAsBytes();
    setState(() {
      _selectedPhoto = photo;
      _selectedPhotoBytes = bytes;
      _showEmojiPicker = false;
    });
  }

  Future<void> _openImagePicker() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from gallery'),
                onTap: () {
                  Navigator.of(context).pop();
                  unawaited(_pickImage(ImageSource.gallery));
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Take photo'),
                onTap: () {
                  Navigator.of(context).pop();
                  unawaited(_pickImage(ImageSource.camera));
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _toggleEmojiPicker() {
    FocusScope.of(context).unfocus();
    setState(() {
      _showEmojiPicker = !_showEmojiPicker;
    });
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
      AppToast.error(context, error);
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

  Future<void> _handleLinkTap(String url) async {
    String processedUrl = url.trim();
    if (!processedUrl.startsWith('http://') && !processedUrl.startsWith('https://')) {
      processedUrl = 'https://$processedUrl';
    }
    final uri = Uri.tryParse(processedUrl);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.platformDefault);
    }
  }

  Future<void> _showGroupInfo() async {
    final group = _group;
    if (group == null) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final colors = context.appColors;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: colors.borderStrong),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundImage: group.photoUrl.isNotEmpty
                          ? NetworkImage(group.photoUrl)
                          : null,
                      child: group.photoUrl.isEmpty
                          ? const Icon(Icons.groups_rounded)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            group.name,
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${group.membersCount} members',
                            style: TextStyle(
                              color: colors.textMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                if (group.category.isNotEmpty) ...[
                  Text(
                    'Category',
                    style: TextStyle(
                      color: colors.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surfaceMuted,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      group.category,
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (group.info.isNotEmpty) ...[
                  Text(
                    'Description',
                    style: TextStyle(
                      color: colors.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    group.info,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 14,
                      height: 1.55,
                    ),
                  ),
                ] else
                  Text(
                    'No group description yet.',
                    style: TextStyle(color: colors.textMuted, fontSize: 13),
                  ),
              ],
            ),
          ),
        );
      },
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
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'info') {
                unawaited(_showGroupInfo());
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'info', child: Text('Group info')),
            ],
          ),
        ],
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
                          itemCount:
                              _messages.length + (_isLoadingMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (_isLoadingMore && index == 0) {
                              return const Padding(
                                padding: EdgeInsets.only(bottom: 16),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }

                            final message =
                                _messages[_isLoadingMore ? index - 1 : index];
                            final isMine =
                                widget.currentUser?.id == message.userId;
                            return _GroupMessageBubble(
                              message: message,
                              isMine: isMine,
                              canDelete: isMine || group.isOwner,
                              onProfileTap: message.sender == null
                                  ? null
                                  : () =>
                                        _openProfile(message.sender!.username),
                              onReply: () {
                                setState(() {
                                  _replyingTo = message;
                                });
                              },
                              onDelete: () => _deleteMessage(message),
                              onLinkTap: _handleLinkTap,
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
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_selectedPhotoBytes != null)
                            Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: colors.surfaceMuted,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: colors.border),
                              ),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: SizedBox(
                                      width: 56,
                                      height: 56,
                                      child: Image.memory(
                                        _selectedPhotoBytes!,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _selectedPhoto?.name ?? 'Selected image',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: colors.textPrimary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () {
                                      setState(() {
                                        _selectedPhoto = null;
                                        _selectedPhotoBytes = null;
                                      });
                                    },
                                    icon: const Icon(Icons.close),
                                  ),
                                ],
                              ),
                            ),
                          Row(
                            children: [
                              IconButton(
                                onPressed: _toggleEmojiPicker,
                                icon: Icon(
                                  _showEmojiPicker
                                      ? Icons.keyboard_rounded
                                      : Icons.emoji_emotions_outlined,
                                ),
                              ),
                              IconButton(
                                onPressed: _openImagePicker,
                                icon: const Icon(
                                  Icons.add_photo_alternate_outlined,
                                ),
                              ),
                              Expanded(
                                child: TextField(
                                  controller: _controller,
                                  minLines: 1,
                                  maxLines: 5,
                                  onSubmitted: (_) => _sendMessage(),
                                  onTap: () {
                                    if (_showEmojiPicker) {
                                      setState(() {
                                        _showEmojiPicker = false;
                                      });
                                    }
                                  },
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
                              AppSendActionButton(
                                onPressed: _sendMessage,
                                isBusy: false,
                              ),
                            ],
                          ),
                          if (_showEmojiPicker)
                            SizedBox(
                              height: 320,
                              child: EmojiPicker(
                                textEditingController: _controller,
                                onBackspacePressed: () {},
                                config: Config(
                                  height: 320,
                                  checkPlatformCompatibility: true,
                                  emojiViewConfig: const EmojiViewConfig(
                                    emojiSizeMax: 26,
                                  ),
                                  categoryViewConfig: CategoryViewConfig(
                                    iconColor: colors.textMuted,
                                    iconColorSelected: colors.brand,
                                    backspaceColor: colors.brand,
                                  ),
                                  bottomActionBarConfig:
                                      const BottomActionBarConfig(
                                        enabled: false,
                                      ),
                                  searchViewConfig: SearchViewConfig(
                                    backgroundColor: colors.surface,
                                    buttonIconColor: colors.textMuted,
                                  ),
                                ),
                              ),
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
  const _ReplyPreview({required this.message, required this.onClear});

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
                  style: TextStyle(color: colors.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
          IconButton(onPressed: onClear, icon: const Icon(Icons.close)),
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
    required this.onLinkTap,
  });

  final GroupMessage message;
  final bool isMine;
  final bool canDelete;
  final VoidCallback? onProfileTap;
  final VoidCallback onReply;
  final VoidCallback onDelete;
  final Future<void> Function(String url) onLinkTap;

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
                GestureDetector(
                  onLongPressStart: (details) async {
                    HapticFeedback.mediumImpact();
                    final RenderBox overlay = Overlay.of(context)
                        .context
                        .findRenderObject() as RenderBox;
                    final value = await showMenu<String>(
                      context: context,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      position: RelativeRect.fromRect(
                        details.globalPosition & const Size(40, 40),
                        Offset.zero & overlay.size,
                      ),
                      items: [
                        PopupMenuItem(
                          value: 'reply',
                          child: Row(
                            children: [
                              Icon(Icons.reply_rounded,
                                  size: 20, color: colors.brand),
                              const SizedBox(width: 12),
                              const Text('Reply'),
                            ],
                          ),
                        ),
                        if (canDelete)
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline_rounded,
                                    size: 20, color: colors.dangerText),
                                const SizedBox(width: 12),
                                Text(
                                  'Delete',
                                  style: TextStyle(color: colors.dangerText),
                                ),
                              ],
                            ),
                          ),
                      ],
                    );
                    if (value == 'reply') onReply();
                    if (value == 'delete') onDelete();
                  },
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
                        if (message.localImageBytes != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Image.memory(
                                message.localImageBytes!,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        if (message.message.isNotEmpty)
                          RichDisplayText(
                            text: message.message,
                            style: TextStyle(
                              color: isMine ? Colors.white : colors.textPrimary,
                              fontSize: 14,
                              height: 1.45,
                            ),
                            onMentionTap: (username) async {
                              onProfileTap?.call();
                            },
                            onLinkTap: onLinkTap,
                          ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              message.time,
                              style: TextStyle(
                                color: isMine
                                    ? Colors.white70
                                    : colors.textMuted,
                                fontSize: 11,
                              ),
                            ),
                            if (isMine) ...[
                              const SizedBox(width: 6),
                              _MessageDeliveryStatus(status: message.status),
                            ],
                          ],
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

class _MessageDeliveryStatus extends StatelessWidget {
  const _MessageDeliveryStatus({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final normalized = status.trim().toLowerCase();
    final isRead = normalized == 'read' || normalized == 'seen';
    final iconColor = isRead
        ? const Color(0xFFBFE0FF)
        : Colors.white.withOpacity(0.82);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.done_rounded, size: 14, color: iconColor),
        if (isRead)
          Transform.translate(
            offset: const Offset(-4, 0),
            child: Icon(Icons.done_rounded, size: 14, color: iconColor),
          ),
      ],
    );
  }
}
