import 'dart:async';
import 'dart:typed_data';

import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hopefulme_flutter/app/theme/app_theme.dart';
import 'package:hopefulme_flutter/core/utils/time_formatter.dart';
import 'package:hopefulme_flutter/core/widgets/app_send_action_button.dart';
import 'package:hopefulme_flutter/core/widgets/app_status_state.dart';
import 'package:hopefulme_flutter/core/widgets/app_toast.dart';
import 'package:hopefulme_flutter/features/auth/models/user.dart';
import 'package:hopefulme_flutter/features/messages/data/message_repository.dart';
import 'package:hopefulme_flutter/features/messages/models/conversation_models.dart';
import 'package:hopefulme_flutter/features/profile/data/profile_repository.dart';
import 'package:hopefulme_flutter/features/profile/presentation/profile_navigation.dart';
import 'package:hopefulme_flutter/features/profile/presentation/screens/profile_updates_screen.dart';
import 'package:hopefulme_flutter/features/updates/data/update_repository.dart';

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
      const Duration(seconds: 2),
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
      setState(() {
        _conversation = thread.conversation;
        _messages = thread.messages;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      });
    } catch (error) {
      if (!silent && mounted) {
        setState(() {
          _error = error.toString();
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
    if (text.isEmpty && !hasPhoto) {
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
      status: 'sending',
      createdAt: DateTime.now().toIso8601String(),
      sender: _conversation?.latestMessage?.sender,
      recipient: _conversation?.latestMessage?.recipient,
      localImageBytes: localPhotoBytes,
    );

    setState(() {
      _error = null;
      _messages = [..._messages, optimisticMessage];
      _selectedPhoto = null;
      _selectedPhotoBytes = null;
      _showEmojiPicker = false;
    });
    _controller.clear();
    _scrollToBottomAnimated();

    try {
      final sent = await widget.repository.sendMessage(
        widget.username,
        message: text,
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
                  ? NetworkImage(otherUser!.photoUrl)
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
                  Text(
                    otherUser?.displayName ?? widget.title,
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
                      final isMine =
                          item.senderId != item.recipientId &&
                          item.sender?.username != widget.username;
                      final showAvatar =
                          !isMine &&
                          (index == 0 ||
                              _messages[index - 1].sender?.username !=
                                  item.sender?.username);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          mainAxisAlignment: isMine
                              ? MainAxisAlignment.end
                              : MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (!isMine) ...[
                              SizedBox(
                                width: 30,
                                child: showAvatar
                                    ? CircleAvatar(
                                        radius: 14,
                                        backgroundImage:
                                            item.sender?.photoUrl.isNotEmpty ==
                                                true
                                            ? NetworkImage(
                                                item.sender!.photoUrl,
                                              )
                                            : null,
                                        child:
                                            item.sender?.photoUrl.isEmpty ??
                                                true
                                            ? const Icon(Icons.person, size: 14)
                                            : null,
                                      )
                                    : const SizedBox.shrink(),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Flexible(
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
                                  color: isMine ? colors.brand : colors.surface,
                                  borderRadius: BorderRadius.circular(20),
                                  border: isMine
                                      ? null
                                      : Border.all(color: colors.border),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (item.photoUrl.isNotEmpty ||
                                        item.localImageBytes != null) ...[
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(14),
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
                                      Text(
                                        item.message,
                                        style: TextStyle(
                                          color: isMine
                                              ? Colors.white
                                              : colors.textPrimary,
                                          fontSize: 14,
                                          height: 1.45,
                                        ),
                                      ),
                                    SizedBox(
                                      height: item.message.isNotEmpty ? 8 : 2,
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          formatRelativeTimestamp(
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
                          ],
                        ),
                      );
                    },
                  ),
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
                    crossAxisAlignment: CrossAxisAlignment.end,
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
