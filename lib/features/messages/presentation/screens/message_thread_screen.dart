import 'dart:async';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hopefulme_flutter/app/theme/app_theme.dart';
import 'package:hopefulme_flutter/core/network/image_url_resolver.dart';
import 'package:hopefulme_flutter/core/widgets/verified_name_text.dart';
import 'package:hopefulme_flutter/core/utils/time_formatter.dart';
import 'package:hopefulme_flutter/core/widgets/app_send_action_button.dart';
import 'package:hopefulme_flutter/core/widgets/app_status_state.dart';
import 'package:hopefulme_flutter/core/widgets/app_toast.dart';
import 'package:hopefulme_flutter/core/widgets/rich_display_text.dart';
import 'package:hopefulme_flutter/features/auth/models/user.dart';
import 'package:hopefulme_flutter/features/messages/data/message_repository.dart';
import 'package:hopefulme_flutter/features/messages/models/conversation_models.dart';
import 'package:hopefulme_flutter/features/profile/data/profile_repository.dart';
import 'package:hopefulme_flutter/features/profile/presentation/profile_navigation.dart';
import 'package:hopefulme_flutter/features/profile/presentation/screens/profile_updates_screen.dart';
import 'package:hopefulme_flutter/features/updates/data/update_repository.dart';
import 'package:url_launcher/url_launcher.dart';

class MessageThreadScreen extends StatefulWidget {
  const MessageThreadScreen({
    required this.repository,
    required this.profileRepository,
    required this.updateRepository,
    required this.currentUser,
    required this.username,
    required this.title,
    super.key,
  });

  final MessageRepository repository;
  final ProfileRepository profileRepository;
  final UpdateRepository updateRepository;
  final User? currentUser;
  final String username;
  final String title;

  @override
  State<MessageThreadScreen> createState() => _MessageThreadScreenState();
}

class _MessageThreadScreenState extends State<MessageThreadScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  ConversationListItem? _conversation;
  List<ChatMessage> _messages = <ChatMessage>[];
  ChatMessage? _replyingTo;
  Timer? _pollTimer;
  bool _isLoading = true;
  bool _isSending = false;
  bool _showEmojiPicker = false;
  XFile? _selectedPhoto;
  Uint8List? _selectedPhotoBytes;
  int _optimisticId = -1;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _loadThread();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _loadThread(silent: true),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadThread({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final thread = await widget.repository.fetchThread(widget.username);
      if (!mounted) {
        return;
      }
      final mergedMessages = silent
          ? _mergeMessages(_messages, thread.messages)
          : thread.messages;
      final shouldStickToBottom =
          !silent || _isNearBottom() || _messages.isEmpty;
      setState(() {
        _conversation = thread.conversation;
        _messages = mergedMessages;
      });
      if (shouldStickToBottom) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
          }
        });
      }
    } catch (error) {
      if (!silent && mounted) {
        setState(() {
          _error = error;
        });
      }
    } finally {
      if (!silent && mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    final hasPhoto = _selectedPhoto != null;
    if ((text.isEmpty && !hasPhoto) || _isSending) {
      return;
    }

    final localPhotoBytes = _selectedPhotoBytes;
    final selectedPhoto = _selectedPhoto;
    final optimisticId = _optimisticId--;
    final optimisticMessage = ChatMessage(
      id: optimisticId,
      conversationId: _conversation?.id ?? 0,
      senderId: widget.currentUser?.id ?? 0,
      recipientId: _conversation?.otherUser.id ?? 0,
      message: text,
      photoUrl: '',
      replyId: _replyingTo?.id ?? 0,
      status: 'sending',
      createdAt: DateTime.now().toIso8601String(),
      sender:
          _conversation?.latestMessage?.sender ??
          widget.currentUser?.toConversationUser(),
      recipient: _conversation?.otherUser,
      replyTo: _replyingTo == null
          ? null
          : ChatMessageReply(
              id: _replyingTo!.id,
              message: _replyingTo!.message,
              sender: _replyingTo!.sender,
            ),
      localImageBytes: localPhotoBytes,
    );

    setState(() {
      _isSending = true;
      _error = null;
      _messages = [..._messages, optimisticMessage];
      _selectedPhoto = null;
      _selectedPhotoBytes = null;
      _showEmojiPicker = false;
      _replyingTo = null;
    });
    _controller.clear();
    _scrollToBottomAnimated();

    try {
      final sent = await widget.repository.sendMessage(
        widget.username,
        message: text,
        replyId: _replyingTo?.id,
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
      _scrollToBottomAnimated();
      unawaited(_loadThread(silent: true));
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error;
        _messages = _messages.where((item) => item.id != optimisticId).toList();
        if (selectedPhoto != null && _selectedPhoto == null) {
          _selectedPhoto = selectedPhoto;
          _selectedPhotoBytes = localPhotoBytes;
        }
        if (text.isNotEmpty && _controller.text.trim().isEmpty) {
          _controller.text = text;
        }
      });
      AppToast.error(
        context,
        _error?.toString() ?? 'Unable to send message right now.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
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

  void _scrollToBottomAnimated() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _openProfile() async {
    await openUserProfile(
      context,
      profileRepository: widget.profileRepository,
      messageRepository: widget.repository,
      updateRepository: widget.updateRepository,
      currentUser: widget.currentUser,
      username: widget.username,
    );
  }

  Future<void> _openUserPosts() async {
    try {
      final dashboard = await widget.profileRepository.fetchProfile(
        widget.username,
      );
      if (!mounted) {
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => ProfileUpdatesScreen(
            profile: dashboard.profile,
            repository: widget.profileRepository,
            messageRepository: widget.repository,
            updateRepository: widget.updateRepository,
            currentUser: widget.currentUser,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      AppToast.error(context, error);
    }
  }

  Future<void> _deleteMessage(ChatMessage message) async {
    try {
      await widget.repository.deleteMessage(message.id);
      if (!mounted) return;
      setState(() {
        _messages = _messages.where((m) => m.id != message.id).toList();
      });
    } catch (error) {
      if (!mounted) return;
      AppToast.error(
        context,
        error.toString().replaceAll('Exception:', '').trim(),
      );
    }
  }

  Future<void> _handleLinkTap(String url) async {
    String processedUrl = url.trim();
    if (!processedUrl.startsWith('http://') &&
        !processedUrl.startsWith('https://')) {
      processedUrl = 'https://$processedUrl';
    }
    final uri = Uri.tryParse(processedUrl);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.platformDefault);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final conversation = _conversation;
    final otherUser = conversation?.otherUser;

    return Scaffold(
      backgroundColor: colors.scaffold,
      appBar: AppBar(
        backgroundColor: colors.surface,
        surfaceTintColor: colors.surface,
        titleSpacing: 8,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundImage: otherUser?.photoUrl.isNotEmpty == true
                  ? NetworkImage(
                      ImageUrlResolver.avatar(otherUser!.photoUrl, size: 56),
                    )
                  : null,
              child: otherUser?.photoUrl.isEmpty ?? true
                  ? const Icon(Icons.person, size: 18)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  VerifiedNameText(
                    name: otherUser?.displayName ?? widget.title,
                    verified: otherUser?.isVerified ?? false,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    otherUser == null
                        ? 'Conversation'
                        : otherUser.isOnline
                        ? 'Online now'
                        : otherUser.lastSeen.isNotEmpty
                        ? 'Last seen ${formatRelativeTimestamp(otherUser.lastSeen)}'
                        : 'Offline',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
              switch (value) {
                case 'profile':
                  unawaited(_openProfile());
                case 'posts':
                  unawaited(_openUserPosts());
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'profile', child: Text('View profile')),
              PopupMenuItem(value: 'posts', child: Text('View posts')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? AppStatusState.fromError(
                    error: _error!,
                    actionLabel: 'Try again',
                    onAction: _loadThread,
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final item = _messages[index];
                      final isMine = widget.currentUser != null
                          ? item.senderId == widget.currentUser!.id
                          : item.sender?.username != widget.username;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          mainAxisAlignment: isMine
                              ? MainAxisAlignment.end
                              : MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Flexible(
                              child: GestureDetector(
                                onLongPressStart: (details) async {
                                  HapticFeedback.mediumImpact();
                                  final RenderBox overlay =
                                      Overlay.of(
                                            context,
                                          ).context.findRenderObject()
                                          as RenderBox;
                                  final value = await showMenu<String>(
                                    context: context,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    position: RelativeRect.fromRect(
                                      details.globalPosition &
                                          const Size(40, 40),
                                      Offset.zero & overlay.size,
                                    ),
                                    items: [
                                      PopupMenuItem(
                                        value: 'reply',
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.reply_rounded,
                                              size: 20,
                                              color: colors.brand,
                                            ),
                                            const SizedBox(width: 12),
                                            const Text('Reply'),
                                          ],
                                        ),
                                      ),
                                      PopupMenuItem(
                                        value: 'copy',
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.content_copy_rounded,
                                              size: 20,
                                              color: colors.textSecondary,
                                            ),
                                            const SizedBox(width: 12),
                                            const Text('Copy Text'),
                                          ],
                                        ),
                                      ),
                                      if (isMine)
                                        PopupMenuItem(
                                          value: 'delete',
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.delete_outline_rounded,
                                                size: 20,
                                                color: colors.dangerText,
                                              ),
                                              const SizedBox(width: 12),
                                              Text(
                                                'Delete',
                                                style: TextStyle(
                                                  color: colors.dangerText,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  );

                                  if (value == 'reply') {
                                    setState(() {
                                      _replyingTo = item;
                                    });
                                  } else if (value == 'copy') {
                                    await Clipboard.setData(
                                      ClipboardData(text: item.message),
                                    );
                                    if (mounted) {
                                      AppToast.info(context, 'Text copied');
                                    }
                                  } else if (value == 'delete') {
                                    await _deleteMessage(item);
                                  }
                                },
                                child: Container(
                                  constraints: const BoxConstraints(
                                    maxWidth: 300,
                                  ),
                                  margin: EdgeInsets.only(
                                    left: isMine ? 48 : 0,
                                    right: isMine ? 0 : 24,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 11,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isMine
                                        ? colors.brand
                                        : colors.surface,
                                    borderRadius: BorderRadius.circular(20),
                                    border: isMine
                                        ? null
                                        : Border.all(color: colors.border),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (item.replyTo != null) ...[
                                        _ThreadReplyQuote(
                                          reply: item.replyTo!,
                                          isMine: isMine,
                                        ),
                                        const SizedBox(height: 8),
                                      ],
                                      if (item.photoUrl.isNotEmpty ||
                                          item.localImageBytes != null) ...[
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          child: item.localImageBytes != null
                                              ? Image.memory(
                                                  item.localImageBytes!,
                                                  fit: BoxFit.cover,
                                                )
                                              : Image.network(
                                                  item.photoUrl,
                                                  fit: BoxFit.cover,
                                                  errorBuilder:
                                                      (
                                                        context,
                                                        error,
                                                        stackTrace,
                                                      ) =>
                                                          const SizedBox.shrink(),
                                                ),
                                        ),
                                        if (item.message.isNotEmpty)
                                          const SizedBox(height: 10),
                                      ],
                                      if (item.message.isNotEmpty)
                                        RichDisplayText(
                                          text: item.message,
                                          style: TextStyle(
                                            color: isMine
                                                ? Colors.white
                                                : colors.textPrimary,
                                            fontSize: 14,
                                            height: 1.45,
                                          ),
                                          onMentionTap: (username) =>
                                              openUserProfile(
                                                context,
                                                profileRepository:
                                                    widget.profileRepository,
                                                messageRepository:
                                                    widget.repository,
                                                updateRepository:
                                                    widget.updateRepository,
                                                currentUser: widget.currentUser,
                                                username: username,
                                              ),
                                          onLinkTap: _handleLinkTap,
                                        ),
                                      SizedBox(
                                        height: item.message.isNotEmpty ? 8 : 2,
                                      ),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            formatConversationListTimestamp(
                                              item.createdAt,
                                            ),
                                            style: TextStyle(
                                              color: isMine
                                                  ? Colors.white70
                                                  : colors.textMuted,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          if (isMine) ...[
                                            const SizedBox(width: 6),
                                            _MessageDeliveryStatus(
                                              status: item.status,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          if (_replyingTo != null)
            _ReplyPreview(
              message: _replyingTo!,
              onClear: () => setState(() => _replyingTo = null),
            ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              color: colors.surface,
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
                    crossAxisAlignment: CrossAxisAlignment.center,
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
                        icon: const Icon(Icons.add_photo_alternate_outlined),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          minLines: 1,
                          maxLines: 4,
                          onTap: () {
                            if (_showEmojiPicker) {
                              setState(() {
                                _showEmojiPicker = false;
                              });
                            }
                          },
                          decoration: InputDecoration(
                            hintText:
                                'Message ${otherUser?.displayName ?? widget.title}...',
                            filled: true,
                            fillColor: colors.surfaceMuted,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      AppSendActionButton(
                        onPressed: _sendMessage,
                        isBusy: _isSending,
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
                          bottomActionBarConfig: const BottomActionBarConfig(
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
      ),
    );
  }
}

extension on User {
  ConversationUser toConversationUser() {
    return ConversationUser(
      id: id,
      username: username,
      fullname: fullname,
      photoUrl: ImageUrlResolver.resolve(photoUrl),
      lastSeen: '',
      isOnline: false,
      isVerified: isVerified,
    );
  }
}

extension on _MessageThreadScreenState {
  bool _isNearBottom() {
    if (!_scrollController.hasClients) {
      return true;
    }
    final position = _scrollController.position;
    return (position.maxScrollExtent - position.pixels) < 140;
  }

  List<ChatMessage> _mergeMessages(
    List<ChatMessage> existing,
    List<ChatMessage> incoming,
  ) {
    final merged = <int, ChatMessage>{};
    for (final message in existing) {
      merged[message.id] = message;
    }
    for (final message in incoming) {
      merged[message.id] = message;
    }
    final pending = existing.where((message) => message.id < 0);
    for (final message in pending) {
      merged.putIfAbsent(message.id, () => message);
    }
    final items = merged.values.toList()
      ..sort((a, b) {
        final aTime = DateTime.tryParse(a.createdAt);
        final bTime = DateTime.tryParse(b.createdAt);
        if (aTime != null && bTime != null) {
          final timeCompare = aTime.compareTo(bTime);
          if (timeCompare != 0) {
            return timeCompare;
          }
        }
        return a.id.compareTo(b.id);
      });
    return items;
  }
}

class _ReplyPreview extends StatelessWidget {
  const _ReplyPreview({required this.message, required this.onClear});

  final ChatMessage message;
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
                  'Replying to ${message.sender?.displayName ?? 'User'}',
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

class _ThreadReplyQuote extends StatelessWidget {
  const _ThreadReplyQuote({required this.reply, required this.isMine});

  final ChatMessageReply reply;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: isMine
            ? Colors.white.withValues(alpha: 0.12)
            : colors.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isMine
              ? Colors.white.withValues(alpha: 0.18)
              : colors.borderStrong,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            reply.sender?.displayName ?? 'User',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isMine ? Colors.white : colors.textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (reply.message.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              reply.message,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isMine ? Colors.white70 : colors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
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
        : Colors.white.withValues(alpha: 0.82);

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
