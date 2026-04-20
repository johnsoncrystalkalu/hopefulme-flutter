import 'dart:async';
import 'dart:math' as math;
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
import 'package:hopefulme_flutter/core/widgets/fullscreen_network_image_screen.dart';
import 'package:hopefulme_flutter/core/widgets/rich_display_text.dart';
import 'package:hopefulme_flutter/features/auth/models/user.dart';
import 'package:hopefulme_flutter/features/messages/data/message_repository.dart';
import 'package:hopefulme_flutter/features/messages/models/conversation_models.dart';
import 'package:hopefulme_flutter/features/profile/data/profile_repository.dart';
import 'package:hopefulme_flutter/features/profile/presentation/profile_navigation.dart';
import 'package:hopefulme_flutter/features/profile/presentation/screens/profile_updates_screen.dart';
import 'package:hopefulme_flutter/features/updates/data/update_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hopefulme_flutter/core/services/onesignal_service.dart';
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

class _MessageThreadScreenState extends State<MessageThreadScreen>
    with WidgetsBindingObserver {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  ConversationListItem? _conversation;
  List<ChatMessage> _messages = <ChatMessage>[];
  ChatMessage? _replyingTo;
  Timer? _pollTimer;
  bool _isPollInFlight = false;
  bool _isAppForeground = true;
  int _realtimeBurstTicksRemaining = 0;
  bool _isLoading = true;
  bool _isSending = false;
  bool _showEmojiPicker = false;
  bool _showJumpToBottom = false;
  bool _hasThreadChanges = false;
  XFile? _selectedPhoto;
  Uint8List? _selectedPhotoBytes;
  int _optimisticId = -1;
  bool _isRestoringDraft = false;
  bool _typingSent = false;
  DateTime? _lastTypingPingAt;
  Timer? _typingDebounce;
  Object? _error;
  ChatMessage? _editingMessage;

  String get _draftKey => 'message_draft_${widget.username}';

  String _selectedPhotoLabel() {
    final name = _selectedPhoto?.name.trim() ?? '';
    if (name.isEmpty) {
      return 'Selected image';
    }
    final normalized = name.toLowerCase();
    if (normalized.startsWith('scaled_') ||
        normalized.startsWith('image_picker') ||
        normalized.startsWith('resized_')) {
      return 'Selected image';
    }
    return name;
  }

  ConversationUser? _displaySenderForMessage(ChatMessage message) {
    return message.sender ??
        (message.senderId == widget.currentUser?.id
            ? widget.currentUser?.toConversationUser()
            : _conversation?.otherUser);
  }

  String _displaySenderNameForMessage(ChatMessage message) {
    return _displaySenderForMessage(message)?.displayName ??
        _threadTitleFallback;
  }

  String get _threadTitleFallback {
    final seededTitle = widget.title.trim();
    final normalizedSeed = seededTitle.toLowerCase().replaceFirst('@', '');
    final normalizedUsername = widget.username
        .trim()
        .toLowerCase()
        .replaceFirst('@', '');
    if (seededTitle.isEmpty || normalizedSeed == normalizedUsername) {
      return 'Conversation';
    }
    return seededTitle;
  }

  TextStyle _interactiveStyleForBubble(AppThemeColors colors, bool isMine) {
    final color = isMine ? const Color(0xFFE0F2FE) : colors.brand;
    return TextStyle(
      color: color,
      fontSize: 14,
      height: 1.45,
      fontWeight: FontWeight.w700,
      decoration: TextDecoration.underline,
      decorationColor: color,
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ActiveChat.currentUsername = widget.username
        .trim()
        .toLowerCase()
        .replaceFirst('@', '');
    ActiveChat.currentConversationId = null;
    _controller.addListener(_handleComposerChanged);
    _scrollController.addListener(_handleScroll);
    unawaited(_restoreDraft());
    _loadThread();
    _primeRealtimeBurst();
    _scheduleNextPoll();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final normalizedUsername = widget.username
        .trim()
        .toLowerCase()
        .replaceFirst('@', '');
    if (ActiveChat.currentUsername == normalizedUsername) {
      ActiveChat.currentUsername = null;
      ActiveChat.currentConversationId = null;
    }
    _pollTimer?.cancel();
    _typingDebounce?.cancel();
    if (_typingSent) {
      unawaited(_sendTypingStatus(false));
    }
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isAppForeground = state == AppLifecycleState.resumed;
    if (_isAppForeground) {
      _primeRealtimeBurst();
      _scheduleNextPoll(immediate: true);
      return;
    }
    _pollTimer?.cancel();
  }

  Future<void> _restoreDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final savedDraft = prefs.getString(_draftKey)?.trimRight() ?? '';
    if (!mounted || savedDraft.isEmpty) return;
    _isRestoringDraft = true;
    _controller.text = savedDraft;
    _controller.selection = TextSelection.collapsed(
      offset: _controller.text.length,
    );
    _isRestoringDraft = false;
  }

  Future<void> _persistDraft(String text) async {
    final prefs = await SharedPreferences.getInstance();
    final draft = text.trimRight();
    if (draft.isEmpty) {
      await prefs.remove(_draftKey);
      return;
    }
    await prefs.setString(_draftKey, draft);
  }

  Future<void> _clearDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_draftKey);
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
      if (!mounted) return;
      final mergedMessages = silent
          ? _mergeMessages(_messages, thread.messages)
          : thread.messages;
      final shouldStickToBottom =
          !silent || _isNearBottom() || _messages.isEmpty;
      setState(() {
        _conversation = thread.conversation;
        _messages = mergedMessages;
      });
      ActiveChat.currentConversationId = thread.conversation.id;
      if (shouldStickToBottom) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(
              _scrollController.position.maxScrollExtent,
            );
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
      if (mounted && _isAppForeground) {
        _scheduleNextPoll();
      }
    }
  }

  void _primeRealtimeBurst({int ticks = 10}) {
    if (ticks > _realtimeBurstTicksRemaining) {
      _realtimeBurstTicksRemaining = ticks;
    }
  }

  Duration _nextPollInterval() {
    if (!_isAppForeground) {
      return const Duration(seconds: 15);
    }
    if (_realtimeBurstTicksRemaining > 0) {
      _realtimeBurstTicksRemaining -= 1;
      return const Duration(seconds: 1);
    }
    if (_showJumpToBottom) {
      return const Duration(seconds: 4);
    }
    return const Duration(seconds: 2);
  }

  void _scheduleNextPoll({bool immediate = false}) {
    _pollTimer?.cancel();
    if (!mounted || !_isAppForeground) {
      return;
    }
    final delay = immediate ? Duration.zero : _nextPollInterval();
    _pollTimer = Timer(delay, () async {
      await _pollLatestMessages();
      if (!mounted) {
        return;
      }
      _scheduleNextPoll();
    });
  }

  Future<void> _pollLatestMessages() async {
    if (_isPollInFlight || !mounted) {
      return;
    }
    _isPollInFlight = true;
    try {
      final currentMessages = _messages.where((message) => message.id > 0);
      final latestMessageId = currentMessages.isEmpty
          ? null
          : currentMessages.last.id;
      if (latestMessageId == null) {
        await _loadThread(silent: true);
        return;
      }

      final thread = await widget.repository.fetchThreadUpdates(
        widget.username,
        afterId: latestMessageId,
      );
      if (!mounted) {
        return;
      }

      final shouldStickToBottom = _isNearBottom() || _messages.isEmpty;
      final mergedMessages = _mergeMessages(_messages, thread.messages);
      setState(() {
        _conversation = thread.conversation;
        _messages = mergedMessages;
      });
      if (thread.messages.isNotEmpty) {
        _primeRealtimeBurst(ticks: 6);
      }
      if (shouldStickToBottom && thread.messages.isNotEmpty) {
        _scrollToBottomAnimated();
      }
    } catch (_) {
      // Keep chat resilient; polling fallback continues on next cycle.
    } finally {
      _isPollInFlight = false;
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    final hasPhoto = _selectedPhoto != null;
    final effectiveText = text.isEmpty && hasPhoto ? 'Shared a photo' : text;
    if ((text.isEmpty && !hasPhoto && _editingMessage == null) || _isSending) {
      return;
    }

    if (_editingMessage != null) {
      final editingMessage = _editingMessage!;
      final originalText = editingMessage.message;
      final updated = ChatMessage(
        id: editingMessage.id,
        conversationId: editingMessage.conversationId,
        senderId: editingMessage.senderId,
        recipientId: editingMessage.recipientId,
        message: text,
        photoUrl: editingMessage.photoUrl,
        replyId: editingMessage.replyId,
        status: 'sending',
        createdAt: editingMessage.createdAt,
        sender: editingMessage.sender,
        recipient: editingMessage.recipient,
        replyTo: editingMessage.replyTo,
        localImageBytes: editingMessage.localImageBytes,
      );
      setState(() {
        _isSending = true;
        _error = null;
        _messages = _messages
            .map((m) => m.id == editingMessage.id ? updated : m)
            .toList();
        _showEmojiPicker = false;
        _typingSent = false;
      });
      _typingDebounce?.cancel();
      _controller.clear();
      unawaited(_sendTypingStatus(false));

      try {
        final edited = await widget.repository.editMessage(
          editingMessage.id,
          message: text,
        );
        if (!mounted) return;
        setState(() {
          _hasThreadChanges = true;
          _messages = _messages
              .map((m) => m.id == editingMessage.id ? edited : m)
              .toList();
          _editingMessage = null;
        });
        _primeRealtimeBurst();
        _scheduleNextPoll(immediate: true);
      } catch (error) {
        if (!mounted) return;
        final reverted = ChatMessage(
          id: editingMessage.id,
          conversationId: editingMessage.conversationId,
          senderId: editingMessage.senderId,
          recipientId: editingMessage.recipientId,
          message: originalText,
          photoUrl: editingMessage.photoUrl,
          replyId: editingMessage.replyId,
          status: 'sent',
          createdAt: editingMessage.createdAt,
          sender: editingMessage.sender,
          recipient: editingMessage.recipient,
          replyTo: editingMessage.replyTo,
          localImageBytes: editingMessage.localImageBytes,
        );
        setState(() {
          _error = error;
          _messages = _messages
              .map((m) => m.id == editingMessage.id ? reverted : m)
              .toList();
          _controller.text = text;
        });
        AppToast.error(
          context,
          _error?.toString() ?? 'Unable to edit message.',
        );
      } finally {
        if (mounted) {
          setState(() {
            _isSending = false;
          });
        }
      }
    } else {
      final localPhotoBytes = _selectedPhotoBytes;
      final selectedPhoto = _selectedPhoto;
      final optimisticId = _optimisticId--;
      final optimisticMessage = ChatMessage(
        id: optimisticId,
        conversationId: _conversation?.id ?? 0,
        senderId: widget.currentUser?.id ?? 0,
        recipientId: _conversation?.otherUser.id ?? 0,
        message: effectiveText,
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
                sender: _displaySenderForMessage(_replyingTo!),
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
        _typingSent = false;
      });
      _typingDebounce?.cancel();
      _controller.clear();
      unawaited(_clearDraft());
      unawaited(_sendTypingStatus(false));
      _scrollToBottomAnimated();

      try {
        final sent = await widget.repository.sendMessage(
          widget.username,
          message: effectiveText,
          replyId: optimisticMessage.replyId == 0
              ? null
              : optimisticMessage.replyId,
          photo: selectedPhoto,
        );
        if (!mounted) return;
        setState(() {
          _hasThreadChanges = true;
          _messages = _messages
              .map((item) => item.id == optimisticId ? sent : item)
              .toList();
        });
        _scrollToBottomAnimated();
        _primeRealtimeBurst();
        _scheduleNextPoll(immediate: true);
        unawaited(_pollLatestMessages());
      } catch (error) {
        if (!mounted) return;
        setState(() {
          _error = error;
          _messages = _messages
              .where((item) => item.id != optimisticId)
              .toList();
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
  }

  Future<void> _pickImage(ImageSource source) async {
    final photo = await _imagePicker.pickImage(
      source: source,
      imageQuality: 88,
      maxWidth: 1800,
    );
    if (photo == null || !mounted) return;
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

  // ✅ open image fullscreen with pinch-to-zoom
  Future<void> _openFullImage(
    BuildContext context, {
    String? url,
    Uint8List? bytes,
  }) async {
    final resolvedUrl = url?.trim() ?? '';
    if (resolvedUrl.isNotEmpty) {
      await FullscreenNetworkImageScreen.show(context, imageUrl: resolvedUrl);
      return;
    }
    if (bytes == null) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Center(
            child: InteractiveViewer(
              child: Image.memory(bytes, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
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

  void _handleComposerChanged() {
    unawaited(_persistDraft(_controller.text));
    if (_isRestoringDraft) return;
    final text = _controller.text.trim();
    if (text.isEmpty) {
      _typingDebounce?.cancel();
      if (_typingSent) {
        unawaited(_sendTypingStatus(false));
      }
      return;
    }

    final now = DateTime.now();
    if (!_typingSent ||
        _lastTypingPingAt == null ||
        now.difference(_lastTypingPingAt!) >= const Duration(seconds: 2)) {
      _lastTypingPingAt = now;
      unawaited(_sendTypingStatus(true));
    }

    _typingDebounce?.cancel();
    _typingDebounce = Timer(const Duration(seconds: 3), () {
      if (_typingSent) {
        unawaited(_sendTypingStatus(false));
      }
    });
  }

  void _handleScroll() {
    if (!_scrollController.hasClients || _isLoading) return;
    final distanceFromBottom =
        _scrollController.position.maxScrollExtent -
        _scrollController.position.pixels;
    final shouldShow = distanceFromBottom > 220;
    if (shouldShow != _showJumpToBottom) {
      setState(() {
        _showJumpToBottom = shouldShow;
      });
    }
  }

  Future<void> _sendTypingStatus(bool isTyping) async {
    final conversation = _conversation;
    if (conversation == null || !mounted) return;

    try {
      final updatedConversation = await widget.repository.setTypingStatus(
        widget.username,
        isTyping: isTyping,
      );
      if (!mounted) return;
      setState(() {
        _typingSent = isTyping;
        _conversation = updatedConversation;
      });
    } catch (_) {}
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
      if (!mounted) return;
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
      if (!mounted) return;
      AppToast.error(context, error);
    }
  }

  Future<void> _deleteMessage(ChatMessage message) async {
    try {
      await widget.repository.deleteMessage(message.id);
      if (!mounted) return;
      setState(() {
        _hasThreadChanges = true;
        _messages = _messages.where((m) => m.id != message.id).toList();
      });
      _primeRealtimeBurst();
      _scheduleNextPoll(immediate: true);
    } catch (error) {
      if (!mounted) return;
      AppToast.error(
        context,
        error.toString().replaceAll('Exception:', '').trim(),
      );
    }
  }

  Future<String?> _showBubbleActions({
    required bool isMine,
    required bool hasText,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: false,
      builder: (sheetContext) {
        final colors = sheetContext.appColors;
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: colors.borderStrong),
                boxShadow: [
                  BoxShadow(
                    color: colors.shadow.withValues(alpha: 0.12),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                    spreadRadius: -12,
                  ),
                ],
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _BubbleActionButton(
                      icon: Icons.reply_outlined,
                      label: 'Reply',
                      color: colors.brand,
                      onTap: () => Navigator.of(sheetContext).pop('reply'),
                    ),
                    if (hasText) ...[
                      const SizedBox(width: 10),
                      _BubbleActionButton(
                        icon: Icons.content_copy_rounded,
                        label: 'Copy',
                        color: colors.textSecondary,
                        onTap: () => Navigator.of(sheetContext).pop('copy'),
                      ),
                    ],
                    if (isMine) ...[
                      const SizedBox(width: 10),
                      _BubbleActionButton(
                        icon: Icons.edit_rounded,
                        label: 'Edit',
                        color: colors.textSecondary,
                        onTap: () => Navigator.of(sheetContext).pop('edit'),
                      ),
                      const SizedBox(width: 10),
                      _BubbleActionButton(
                        icon: Icons.delete_outline_rounded,
                        label: 'Delete',
                        color: colors.dangerText,
                        onTap: () => Navigator.of(sheetContext).pop('delete'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
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

  void _closeThread() {
    Navigator.of(context).pop(_hasThreadChanges);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final conversation = _conversation;
    final otherUser = conversation?.otherUser;
    final typingUserName = conversation?.typingUserName.trim() ?? '';
    final isSomeoneElseTyping =
        conversation != null &&
        typingUserName.isNotEmpty &&
        conversation.typingUserId != widget.currentUser?.id;

    return PopScope<bool>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _closeThread();
      },
      child: Scaffold(
        backgroundColor: colors.scaffold,
        appBar: AppBar(
          backgroundColor: colors.surface,
          surfaceTintColor: colors.surface,
          leading: IconButton(
            onPressed: _closeThread,
            icon: const Icon(Icons.arrow_back),
          ),
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
                child: InkWell(
                  onTap: _openProfile,
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        VerifiedNameText(
                          name: otherUser?.displayName ?? _threadTitleFallback,
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
              child: Stack(
                children: [
                  Positioned.fill(
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
                              final previous = index > 0
                                  ? _messages[index - 1]
                                  : null;
                              final isMine = widget.currentUser != null
                                  ? item.senderId == widget.currentUser!.id
                                  : item.sender?.username != widget.username;
                              final groupedWithPrevious =
                                  previous != null &&
                                  previous.senderId == item.senderId &&
                                  !_shouldShowDateDivider(index);

                              return Column(
                                children: [
                                  if (_shouldShowDateDivider(index))
                                    _ChatDateDivider(
                                      label: _dateLabelForIndex(index),
                                    ),
                                  Padding(
                                    padding: EdgeInsets.only(
                                      bottom: groupedWithPrevious ? 6 : 12,
                                    ),
                                    child: Row(
                                      mainAxisAlignment: isMine
                                          ? MainAxisAlignment.end
                                          : MainAxisAlignment.start,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Flexible(
                                          child: GestureDetector(
                                            onLongPressStart: (_) async {
                                              HapticFeedback.mediumImpact();
                                              final hasText = item.message
                                                  .trim()
                                                  .isNotEmpty;
                                              final value =
                                                  await _showBubbleActions(
                                                    isMine: isMine,
                                                    hasText: hasText,
                                                  );
                                              if (!context.mounted) {
                                                return;
                                              }

                                              if (value == 'reply') {
                                                setState(() {
                                                  _replyingTo = item;
                                                });
                                              } else if (value == 'copy') {
                                                await Clipboard.setData(
                                                  ClipboardData(
                                                    text: item.message,
                                                  ),
                                                );
                                                if (context.mounted) {
                                                  AppToast.info(
                                                    context,
                                                    'Text copied',
                                                  );
                                                }
                                              } else if (value == 'edit') {
                                                setState(() {
                                                  _editingMessage = item;
                                                  _controller.text =
                                                      item.message;
                                                  _controller.selection =
                                                      TextSelection.collapsed(
                                                        offset:
                                                            item.message.length,
                                                      );
                                                  _replyingTo = null;
                                                  _showEmojiPicker = false;
                                                  _selectedPhoto = null;
                                                  _selectedPhotoBytes = null;
                                                });
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
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 14,
                                                    vertical: 11,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: isMine
                                                    ? colors.brand
                                                    : colors.surface,
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                                border: isMine
                                                    ? null
                                                    : Border.all(
                                                        color: colors.border,
                                                      ),
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
                                                  // ✅ image with tap to fullscreen
                                                  if (item
                                                          .photoUrl
                                                          .isNotEmpty ||
                                                      item.localImageBytes !=
                                                          null) ...[
                                                    GestureDetector(
                                                      onTap: () => _openFullImage(
                                                        context,
                                                        url:
                                                            item.localImageBytes ==
                                                                null
                                                            ? item.photoUrl
                                                            : null,
                                                        bytes: item
                                                            .localImageBytes,
                                                      ),
                                                      child: ClipRRect(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              14,
                                                            ),
                                                        child:
                                                            item.localImageBytes !=
                                                                null
                                                            ? Image.memory(
                                                                item.localImageBytes!,
                                                                fit: BoxFit
                                                                    .cover,
                                                              )
                                                            : Image.network(
                                                                item.photoUrl,
                                                                fit: BoxFit
                                                                    .cover,
                                                                errorBuilder:
                                                                    (
                                                                      context,
                                                                      error,
                                                                      stackTrace,
                                                                    ) =>
                                                                        const SizedBox.shrink(),
                                                              ),
                                                      ),
                                                    ),
                                                    if (item.message.isNotEmpty)
                                                      const SizedBox(
                                                        height: 10,
                                                      ),
                                                  ],
                                                  if (item.message.isNotEmpty)
                                                    RichDisplayText(
                                                      text: item.message,
                                                      style: TextStyle(
                                                        color: isMine
                                                            ? Colors.white
                                                            : colors
                                                                  .textPrimary,
                                                        fontSize: 14,
                                                        height: 1.45,
                                                      ),
                                                      linkStyle:
                                                          _interactiveStyleForBubble(
                                                            colors,
                                                            isMine,
                                                          ),
                                                      mentionStyle:
                                                          _interactiveStyleForBubble(
                                                            colors,
                                                            isMine,
                                                          ), // 👈
                                                      hashtagStyle:
                                                          _interactiveStyleForBubble(
                                                            colors,
                                                            isMine,
                                                          ), // 👈
                                                      onMentionTap:
                                                          (
                                                            username,
                                                          ) => openUserProfile(
                                                            context,
                                                            profileRepository:
                                                                widget
                                                                    .profileRepository,
                                                            messageRepository:
                                                                widget
                                                                    .repository,
                                                            updateRepository: widget
                                                                .updateRepository,
                                                            currentUser: widget
                                                                .currentUser,
                                                            username: username,
                                                          ),
                                                      onLinkTap: _handleLinkTap,
                                                    ),

                                                  SizedBox(
                                                    height:
                                                        item.message.isNotEmpty
                                                        ? 8
                                                        : 2,
                                                  ),
                                                  Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Text(
                                                        formatConversationListTimestamp(
                                                          item.createdAt,
                                                        ),
                                                        style: TextStyle(
                                                          color: isMine
                                                              ? Colors.white70
                                                              : colors
                                                                    .textMuted,
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                      ),
                                                      if (isMine) ...[
                                                        const SizedBox(
                                                          width: 6,
                                                        ),
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
                                  ),
                                ],
                              );
                            },
                          ),
                  ),
                  if (_showJumpToBottom)
                    Positioned(
                      right: 18,
                      bottom: 16,
                      child: FloatingActionButton.small(
                        heroTag: 'message_jump_bottom',
                        backgroundColor: colors.surface,
                        foregroundColor: colors.textPrimary,
                        onPressed: _scrollToBottomAnimated,
                        child: const Icon(Icons.keyboard_arrow_down_rounded),
                      ),
                    ),
                ],
              ),
            ),
            if (_replyingTo != null)
              _ReplyPreview(
                message: _replyingTo!,
                senderLabel: _displaySenderNameForMessage(_replyingTo!),
                onClear: () => setState(() => _replyingTo = null),
              ),
            if (isSomeoneElseTyping)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _ThreadTypingIndicator(name: typingUserName),
                ),
              ),
            if (_editingMessage != null)
              _EditingBanner(
                message: _editingMessage!,
                onCancel: () {
                  setState(() => _editingMessage = null);
                  _controller.clear();
                  unawaited(_clearDraft());
                },
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
                                _selectedPhotoLabel(),
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
                        _ThreadComposerIconButton(
                          onPressed: _toggleEmojiPicker,
                          icon: Icon(
                            _showEmojiPicker
                                ? Icons.keyboard_rounded
                                : Icons.emoji_emotions_outlined,
                            size: 18,
                          ),
                        ),
                        if (_editingMessage == null) ...[
                          const SizedBox(width: 8),
                          _ThreadComposerIconButton(
                            onPressed: _openImagePicker,
                            icon: const Icon(
                              Icons.add_photo_alternate_outlined,
                              size: 18,
                            ),
                          ),
                        ],
                        const SizedBox(width: 10),
                        Expanded(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 120),
                            child: TextField(
                              controller: _controller,
                              minLines: 1,
                              maxLines: null,
                              onTap: () {
                                if (_showEmojiPicker) {
                                  setState(() {
                                    _showEmojiPicker = false;
                                  });
                                }
                              },
                              decoration: InputDecoration(
                                hintText: 'Message..',
                                hintStyle: TextStyle(color: colors.textMuted),
                                filled: true,
                                fillColor: colors.surfaceMuted,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(color: colors.border),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(color: colors.border),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(color: colors.brand),
                                ),
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
                            emojiViewConfig: EmojiViewConfig(
                              emojiSizeMax: 26,
                              backgroundColor: colors.surfaceMuted,
                            ),
                            categoryViewConfig: CategoryViewConfig(
                              backgroundColor: colors.surface,
                              indicatorColor: colors.brand,
                              iconColor: colors.textMuted,
                              iconColorSelected: colors.brand,
                              backspaceColor: colors.brand,
                              dividerColor: colors.border,
                            ),
                            bottomActionBarConfig: const BottomActionBarConfig(
                              enabled: false,
                            ),
                            searchViewConfig: SearchViewConfig(
                              backgroundColor: colors.surfaceMuted,
                              buttonIconColor: colors.textMuted,
                              inputTextStyle: TextStyle(
                                color: colors.textPrimary,
                                fontSize: 14,
                              ),
                              hintTextStyle: TextStyle(
                                color: colors.textMuted,
                                fontSize: 14,
                              ),
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
      ),
    );
  }
}

class _BubbleActionButton extends StatelessWidget {
  const _BubbleActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: colors.surfaceMuted,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
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
  bool _shouldShowDateDivider(int index) {
    if (index < 0 || index >= _messages.length) return false;
    if (index == 0) return true;
    final current = DateTime.tryParse(_messages[index].createdAt);
    final previous = DateTime.tryParse(_messages[index - 1].createdAt);
    if (current == null || previous == null) return false;
    return current.year != previous.year ||
        current.month != previous.month ||
        current.day != previous.day;
  }

  String _dateLabelForIndex(int index) {
    if (index < 0 || index >= _messages.length) return '';
    final current = DateTime.tryParse(_messages[index].createdAt);
    if (current == null) return '';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDay = DateTime(current.year, current.month, current.day);
    final diff = today.difference(messageDay).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return '${current.day}/${current.month}/${current.year}';
  }

  bool _isNearBottom() {
    if (!_scrollController.hasClients) return true;
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
          if (timeCompare != 0) return timeCompare;
        }
        return a.id.compareTo(b.id);
      });
    return items;
  }
}

class _ReplyPreview extends StatelessWidget {
  const _ReplyPreview({
    required this.message,
    required this.senderLabel,
    required this.onClear,
  });

  final ChatMessage message;
  final String senderLabel;
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
                  'Replying to $senderLabel',
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

class _ChatDateDivider extends StatelessWidget {
  const _ChatDateDivider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    if (label.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: colors.surfaceRaised,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: colors.border),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: colors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
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

class _ThreadTypingIndicator extends StatefulWidget {
  const _ThreadTypingIndicator({required this.name});

  final String name;

  @override
  State<_ThreadTypingIndicator> createState() => _ThreadTypingIndicatorState();
}

class _ThreadTypingIndicatorState extends State<_ThreadTypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
  }

  @override
  void dispose() {
    ActiveChat.currentUsername = null;
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${widget.name} is typing',
          style: TextStyle(
            color: colors.brand,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 6),
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (index) {
                final phase = (_controller.value - (index * 0.16)) % 1.0;
                final wave =
                    (math.sin((phase * math.pi * 2) - (math.pi / 2)) + 1) / 2;
                final opacity = 0.25 + (wave * 0.75);
                final yOffset = 1.5 - (wave * 1.5);

                return Padding(
                  padding: EdgeInsets.only(right: index == 2 ? 0 : 3),
                  child: Transform.translate(
                    offset: Offset(0, yOffset),
                    child: Opacity(
                      opacity: opacity,
                      child: Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: colors.brand,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            );
          },
        ),
      ],
    );
  }
}

class _ThreadComposerIconButton extends StatelessWidget {
  const _ThreadComposerIconButton({
    required this.onPressed,
    required this.icon,
  });

  final VoidCallback onPressed;
  final Widget icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Material(
      color: colors.surfaceMuted,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 34,
          height: 34,
          child: IconTheme(
            data: IconThemeData(color: colors.textSecondary),
            child: icon,
          ),
        ),
      ),
    );
  }
}

class _EditingBanner extends StatelessWidget {
  const _EditingBanner({required this.message, required this.onCancel});

  final ChatMessage message;
  final VoidCallback onCancel;

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
                  'Editing message',
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
          IconButton(onPressed: onCancel, icon: const Icon(Icons.close)),
        ],
      ),
    );
  }
}
