import 'dart:async';
import 'dart:math' as math;
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hopefulme_flutter/app/theme/app_theme.dart';
import 'package:hopefulme_flutter/core/network/api_exception.dart';
import 'package:hopefulme_flutter/core/network/image_url_resolver.dart';
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
import 'package:shared_preferences/shared_preferences.dart';
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
  bool _showJumpToBottom = false;
  bool _hasThreadChanges = false;
  XFile? _selectedPhoto;
  Uint8List? _selectedPhotoBytes;
  int _optimisticId = -1;
  int _lastReadMessageId = 0;
  bool _typingSent = false;
  DateTime? _lastTypingPingAt;
  Timer? _typingDebounce;
  bool _isRestoringDraft = false;
  Object? _error;
  GroupMessage? _editingMessage;

  String get _draftKey => 'group_draft_${widget.groupId}';

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleComposerChanged);
    _scrollController.addListener(_handleScroll);
    unawaited(_restoreDraft());
    _loadInitial();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _pollLatest(),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _typingDebounce?.cancel();
    if (_typingSent) {
      unawaited(_sendTypingStatus(false));
    }
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
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

  Future<void> _loadInitial() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      var group = await widget.repository.fetchGroup(widget.groupId);
      List<GroupMessage> messages = <GroupMessage>[];
      var hasMore = false;
      if (group.isMember) {
        final page = await widget.repository.fetchMessages(widget.groupId);
        messages = page.messages;
        hasMore = page.hasMore;
        _lastReadMessageId = page.lastReadMessageId;
        if (page.group != null) {
          group = page.group!;
        }
      }

      if (!mounted) return;

      setState(() {
        _group = group;
        _messages = messages;
        _hasMore = hasMore;
      });
      _scrollToBottom(jump: true);
    } catch (error) {
      if (!mounted) return;
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
    if (!mounted || group == null || !group.isMember) return;

    try {
      final latestId = _messages.isEmpty ? null : _messages.last.id;
      final response = await widget.repository.fetchMessages(
        widget.groupId,
        afterId: latestId,
      );
      if (!mounted) return;
      if (response.group != null ||
          _lastReadMessageId != response.lastReadMessageId) {
        setState(() {
          _group = response.group ?? _group;
          _lastReadMessageId = response.lastReadMessageId;
        });
      }
      if (response.messages.isEmpty) return;
      setState(() {
        _messages = _dedupeMessages([..._messages, ...response.messages]);
      });
      _scrollToBottom();
    } catch (_) {}
  }

  Future<void> _joinGroup() async {
    if (_isJoining) return;
    setState(() {
      _isJoining = true;
      _error = null;
    });

    try {
      await widget.repository.joinGroup(widget.groupId);
      _hasThreadChanges = true;
      await _loadInitial();
    } catch (error) {
      if (!mounted) return;
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
    if ((text.isEmpty && !hasPhoto && _editingMessage == null) || _isSending) {
      return;
    }

    if (_editingMessage != null) {
      if (text.isEmpty) {
        return;
      }
      final editingMessage = _editingMessage!;
      final originalText = editingMessage.message;
      final optimisticEdited = GroupMessage(
        id: editingMessage.id,
        groupId: editingMessage.groupId,
        userId: editingMessage.userId,
        message: text,
        photoUrl: editingMessage.photoUrl,
        status: 'sending',
        replyId: editingMessage.replyId,
        createdAt: editingMessage.createdAt,
        time: editingMessage.time,
        sender: editingMessage.sender,
        replyTo: editingMessage.replyTo,
        localImageBytes: editingMessage.localImageBytes,
      );

      setState(() {
        _error = null;
        _isSending = true;
        _messages = _messages
            .map((m) => m.id == editingMessage.id ? optimisticEdited : m)
            .toList();
        _showEmojiPicker = false;
        _typingSent = false;
      });
      _typingDebounce?.cancel();
      _controller.clear();
      unawaited(_sendTypingStatus(false));

      try {
        final edited = await widget.repository.editMessage(
          widget.groupId,
          editingMessage.id,
          message: text,
        );
        if (!mounted) {
          return;
        }
        setState(() {
          _hasThreadChanges = true;
          _messages = _messages
              .map((m) => m.id == editingMessage.id ? edited : m)
              .toList();
          _editingMessage = null;
        });
      } catch (error) {
        if (!mounted) {
          return;
        }
        final reverted = GroupMessage(
          id: editingMessage.id,
          groupId: editingMessage.groupId,
          userId: editingMessage.userId,
          message: originalText,
          photoUrl: editingMessage.photoUrl,
          status: editingMessage.status,
          replyId: editingMessage.replyId,
          createdAt: editingMessage.createdAt,
          time: editingMessage.time,
          sender: editingMessage.sender,
          replyTo: editingMessage.replyTo,
          localImageBytes: editingMessage.localImageBytes,
        );
        setState(() {
          _error = error.toString();
          _messages = _messages
              .map((m) => m.id == editingMessage.id ? reverted : m)
              .toList();
          _controller.text = text;
          _controller.selection = TextSelection.collapsed(
            offset: _controller.text.length,
          );
        });
        AppToast.error(
          context,
          _error?.toString() ?? 'Unable to edit group message.',
        );
      } finally {
        if (mounted) {
          setState(() {
            _isSending = false;
          });
        }
      }
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
              isVerified: widget.currentUser?.isVerified ?? false,
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
      _isSending = true;
      _messages = _dedupeMessages([..._messages, optimisticMessage]);
      _selectedPhoto = null;
      _selectedPhotoBytes = null;
      _showEmojiPicker = false;
      _replyingTo = null;
      _typingSent = false;
    });
    _typingDebounce?.cancel();
    _controller.clear();
    unawaited(_sendTypingStatus(false));
    unawaited(_clearDraft());
    _scrollToBottom();

    try {
      final sent = await widget.repository.sendMessage(
        widget.groupId,
        message: text,
        replyId: optimisticMessage.replyId,
        photo: selectedPhoto,
      );
      if (!mounted) return;
      setState(() {
        _hasThreadChanges = true;
        _messages = _messages
            .map((item) => item.id == optimisticId ? sent : item)
            .toList();
      });
      _scrollToBottom();
    } catch (error) {
      if (!mounted) return;
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
  void _openFullImage(BuildContext context, {String? url, Uint8List? bytes}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Center(
            child: InteractiveViewer(
              child: bytes != null
                  ? Image.memory(bytes, fit: BoxFit.contain)
                  : Image.network(url!, fit: BoxFit.contain),
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

  Future<void> _deleteMessage(GroupMessage message) async {
    final group = _group;
    if (group == null) return;

    try {
      await widget.repository.deleteMessage(group.id, message.id);
      if (!mounted) return;
      setState(() {
        _hasThreadChanges = true;
        _messages = _messages.where((item) => item.id != message.id).toList();
        if (_editingMessage?.id == message.id) {
          _editingMessage = null;
        }
      });
    } catch (error) {
      if (!mounted) return;
      AppToast.error(context, error);
    }
  }

  Future<void> _loadOlder() async {
    if (_isLoadingMore || !_hasMore || _messages.isEmpty) return;

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
      if (!mounted) return;
      setState(() {
        _messages = _dedupeMessages([...response.messages, ..._messages]);
        _hasMore = response.hasMore;
        _lastReadMessageId = response.lastReadMessageId;
        _group = response.group ?? _group;
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
    if (!_scrollController.hasClients || _isLoading) return;
    final distanceFromBottom =
        _scrollController.position.maxScrollExtent -
        _scrollController.position.pixels;
    final shouldShowJump = distanceFromBottom > 240;
    if (shouldShowJump != _showJumpToBottom) {
      setState(() {
        _showJumpToBottom = shouldShowJump;
      });
    }
    if (_scrollController.position.pixels <= 80) {
      unawaited(_loadOlder());
    }
  }

  void _scrollToBottom({bool jump = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
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

  void _handleComposerChanged() {
    final text = _controller.text.trim();
    unawaited(_persistDraft(_controller.text));
    if (_isRestoringDraft) return;
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

  Future<void> _sendTypingStatus(bool isTyping) async {
    final group = _group;
    if (group == null || !group.isMember || !mounted) return;

    try {
      final updatedGroup = await widget.repository.setTypingStatus(
        widget.groupId,
        isTyping: isTyping,
      );
      if (!mounted) return;
      setState(() {
        _typingSent = isTyping;
        _group = updatedGroup;
      });
    } catch (_) {}
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
    if (!processedUrl.startsWith('http://') &&
        !processedUrl.startsWith('https://')) {
      processedUrl = 'https://$processedUrl';
    }
    final uri = Uri.tryParse(processedUrl);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.platformDefault);
    }
  }

  Future<void> _showGroupInfo() async {
    final group = _group;
    if (group == null) return;

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
                          ? NetworkImage(
                              ImageUrlResolver.avatar(group.photoUrl, size: 72),
                            )
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

  void _closeThread() {
    Navigator.of(context).pop(_hasThreadChanges);
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

  bool _shouldShowDateDivider(int index) {
    if (index <= 0 || index >= _messages.length) return true;
    final current = DateTime.tryParse(_messages[index].createdAt);
    final previous = DateTime.tryParse(_messages[index - 1].createdAt);
    if (current == null || previous == null) return false;
    return !DateUtils.isSameDay(current, previous);
  }

  String _formatDateDivider(String createdAt) {
    final parsed = DateTime.tryParse(createdAt);
    if (parsed == null) return '';
    final local = parsed.toLocal();
    final now = DateTime.now();
    if (DateUtils.isSameDay(local, now)) return 'Today';
    final yesterday = now.subtract(const Duration(days: 1));
    if (DateUtils.isSameDay(local, yesterday)) return 'Yesterday';
    final localizations = MaterialLocalizations.of(context);
    return localizations.formatMediumDate(local);
  }

  int? _firstUnreadIndex() {
    if (_lastReadMessageId <= 0) return null;
    for (var index = 0; index < _messages.length; index++) {
      final message = _messages[index];
      if (message.userId != widget.currentUser?.id &&
          message.id > _lastReadMessageId) {
        return index;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final group = _group;
    final firstUnreadIndex = _firstUnreadIndex();
    final typingUserName = group?.typingUserName.trim() ?? '';
    final isSomeoneElseTyping =
        group != null &&
        typingUserName.isNotEmpty &&
        group.typingUserId != widget.currentUser?.id;

    return PopScope<bool>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _closeThread();
      },
      child: Scaffold(
        backgroundColor: colors.scaffold,
        appBar: AppBar(
          leading: IconButton(
            onPressed: _closeThread,
            icon: const Icon(Icons.arrow_back),
          ),
          titleSpacing: 8,
          title: group == null
              ? const Text('Group Chat')
              : Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundImage: group.photoUrl.isNotEmpty
                          ? NetworkImage(
                              ImageUrlResolver.avatar(group.photoUrl, size: 56),
                            )
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
                    child: Stack(
                      children: [
                        Positioned.fill(
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
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    16,
                                    16,
                                    20,
                                  ),
                                  itemCount:
                                      _messages.length +
                                      (_isLoadingMore ? 1 : 0),
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
                                        _messages[_isLoadingMore
                                            ? index - 1
                                            : index];
                                    final messageIndex = _isLoadingMore
                                        ? index - 1
                                        : index;
                                    final isMine =
                                        widget.currentUser?.id ==
                                        message.userId;
                                    final previousMessage = messageIndex > 0
                                        ? _messages[messageIndex - 1]
                                        : null;
                                    final groupedWithPrevious =
                                        previousMessage != null &&
                                        previousMessage.userId ==
                                            message.userId &&
                                        !_shouldShowDateDivider(messageIndex);

                                    return Column(
                                      children: [
                                        if (_shouldShowDateDivider(
                                          messageIndex,
                                        ))
                                          _ChatDateDivider(
                                            label: _formatDateDivider(
                                              message.createdAt,
                                            ),
                                          ),
                                        if (firstUnreadIndex != null &&
                                            messageIndex == firstUnreadIndex)
                                          const _ChatUnreadDivider(),
                                        _GroupMessageBubble(
                                          message: message,
                                          isMine: isMine,
                                          canEdit: isMine,
                                          canDelete: isMine || group.isOwner,
                                          showAvatar:
                                              !isMine && !groupedWithPrevious,
                                          showSenderName:
                                              !isMine && !groupedWithPrevious,
                                          compactTopSpacing:
                                              groupedWithPrevious,
                                          onProfileTap: message.sender == null
                                              ? null
                                              : () => _openProfile(
                                                  message.sender!.username,
                                                ),
                                          onReply: () {
                                            setState(() {
                                              _replyingTo = message;
                                              _editingMessage = null;
                                            });
                                          },
                                          onEdit: () {
                                            setState(() {
                                              _editingMessage = message;
                                              _controller.text =
                                                  message.message;
                                              _controller.selection =
                                                  TextSelection.collapsed(
                                                    offset:
                                                        message.message.length,
                                                  );
                                              _replyingTo = null;
                                              _showEmojiPicker = false;
                                              _selectedPhoto = null;
                                              _selectedPhotoBytes = null;
                                            });
                                          },
                                          onDelete: () =>
                                              _deleteMessage(message),
                                          onCopy: () async {
                                            await Clipboard.setData(
                                              ClipboardData(
                                                text: message.message,
                                              ),
                                            );
                                            if (!context.mounted) {
                                              return;
                                            }
                                            AppToast.info(
                                              context,
                                              'Text copied',
                                            );
                                          },
                                          onLinkTap: _handleLinkTap,
                                          onOpenFullImage: (url, bytes) =>
                                              _openFullImage(
                                                context,
                                                url: url,
                                                bytes: bytes,
                                              ), // 👈
                                          onMentionTap: _openProfile, // 👈
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
                              heroTag: 'group_jump_bottom',
                              backgroundColor: colors.surface,
                              foregroundColor: colors.textPrimary,
                              onPressed: () => _scrollToBottom(),
                              child: const Icon(
                                Icons.keyboard_arrow_down_rounded,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (group != null && group.isMember) ...[
                    if (isSomeoneElseTyping)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: _TypingIndicator(name: typingUserName),
                        ),
                      ),
                    if (_replyingTo != null)
                      _ReplyPreview(
                        message: _replyingTo!,
                        onClear: () {
                          setState(() {
                            _replyingTo = null;
                          });
                        },
                      ),
                    if (_editingMessage != null)
                      _GroupEditingBanner(
                        message: _editingMessage!,
                        onCancel: () {
                          setState(() {
                            _editingMessage = null;
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
                                        _selectedPhoto?.name ??
                                            'Selected image',
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
                                _ComposerIconButton(
                                  onPressed: _toggleEmojiPicker,
                                  icon: Icon(
                                    _showEmojiPicker
                                        ? Icons.keyboard_rounded
                                        : Icons.emoji_emotions_outlined,
                                    size: 20,
                                  ),
                                ),
                                if (_editingMessage == null) ...[
                                  const SizedBox(width: 4),
                                  _ComposerIconButton(
                                    onPressed: _openImagePicker,
                                    icon: const Icon(
                                      Icons.add_photo_alternate_outlined,
                                      size: 20,
                                    ),
                                  ),
                                ],
                                const SizedBox(width: 8),
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
                                      hintText: 'Message ...',
                                      filled: true,
                                      fillColor: colors.surfaceMuted,
                                      isDense: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 12,
                                          ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: BorderSide.none,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
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
                                    bottomActionBarConfig:
                                        const BottomActionBarConfig(
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
                ],
              ),
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
                    ? NetworkImage(
                        ImageUrlResolver.avatar(group.photoUrl, size: 100),
                      )
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

class _GroupEditingBanner extends StatelessWidget {
  const _GroupEditingBanner({required this.message, required this.onCancel});

  final GroupMessage message;
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

class _ChatUnreadDivider extends StatelessWidget {
  const _ChatUnreadDivider();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Expanded(child: Divider(color: colors.border)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              'New messages',
              style: TextStyle(
                color: colors.brand,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(child: Divider(color: colors.border)),
        ],
      ),
    );
  }
}

class _GroupMessageBubble extends StatelessWidget {
  const _GroupMessageBubble({
    required this.message,
    required this.isMine,
    required this.canEdit,
    required this.canDelete,
    required this.showAvatar,
    required this.showSenderName,
    required this.compactTopSpacing,
    required this.onProfileTap,
    required this.onReply,
    required this.onEdit,
    required this.onDelete,
    required this.onCopy,
    required this.onLinkTap,
    required this.onOpenFullImage, // 👈
    required this.onMentionTap, // 👈
  });

  final GroupMessage message;
  final bool isMine;
  final bool canEdit;
  final bool canDelete;
  final bool showAvatar;
  final bool showSenderName;
  final bool compactTopSpacing;
  final VoidCallback? onProfileTap;
  final VoidCallback onReply;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Future<void> Function() onCopy;
  final Future<void> Function(String url) onLinkTap;
  final void Function(String? url, Uint8List? bytes) onOpenFullImage; // 👈
  final Future<void> Function(String username) onMentionTap; // 👈

  // ✅ unified style for links, mentions, hashtags on bubbles
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

  Future<String?> _showBubbleActions(BuildContext context) {
    final canCopy = message.message.trim().isNotEmpty;
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
                    _GroupBubbleActionButton(
                      icon: Icons.share_outlined,
                      label: 'Reply',
                      color: colors.brand,
                      onTap: () => Navigator.of(sheetContext).pop('reply'),
                    ),
                    if (canCopy) ...[
                      const SizedBox(width: 10),
                      _GroupBubbleActionButton(
                        icon: Icons.content_copy_rounded,
                        label: 'Copy',
                        color: colors.textSecondary,
                        onTap: () => Navigator.of(sheetContext).pop('copy'),
                      ),
                    ],
                    if (canEdit) ...[
                      const SizedBox(width: 10),
                      _GroupBubbleActionButton(
                        icon: Icons.edit_rounded,
                        label: 'Edit',
                        color: colors.textSecondary,
                        onTap: () => Navigator.of(sheetContext).pop('edit'),
                      ),
                    ],
                    if (canDelete) ...[
                      const SizedBox(width: 10),
                      _GroupBubbleActionButton(
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

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Padding(
      padding: EdgeInsets.only(bottom: compactTopSpacing ? 6 : 12),
      child: Row(
        mainAxisAlignment: isMine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMine) ...[
            if (showAvatar)
              InkWell(
                onTap: onProfileTap,
                borderRadius: BorderRadius.circular(999),
                child: CircleAvatar(
                  radius: 14,
                  backgroundImage: message.sender?.photoUrl.isNotEmpty == true
                      ? NetworkImage(
                          ImageUrlResolver.avatar(
                            message.sender!.photoUrl,
                            size: 42,
                          ),
                        )
                      : null,
                  child: message.sender?.photoUrl.isEmpty ?? true
                      ? const Icon(Icons.person, size: 14)
                      : null,
                ),
              )
            else
              const SizedBox(width: 28),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMine
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (!isMine && showSenderName)
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
                  onLongPressStart: (_) async {
                    HapticFeedback.mediumImpact();
                    final value = await _showBubbleActions(context);
                    if (value == 'reply') onReply();
                    if (value == 'copy') await onCopy();
                    if (value == 'edit') onEdit();
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
                                  ? Colors.white.withValues(alpha: 0.16)
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
                        // ✅ network image with tap to fullscreen
                        if (message.photoUrl.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: GestureDetector(
                              onTap: () =>
                                  onOpenFullImage(message.photoUrl, null),
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
                          ),
                        // ✅ local image with tap to fullscreen
                        if (message.localImageBytes != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: GestureDetector(
                              onTap: () => onOpenFullImage(
                                null,
                                message.localImageBytes,
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Image.memory(
                                  message.localImageBytes!,
                                  fit: BoxFit.cover,
                                ),
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
                            // ✅ all three use the same visible style
                            linkStyle: _interactiveStyleForBubble(
                              colors,
                              isMine,
                            ),
                            mentionStyle: _interactiveStyleForBubble(
                              colors,
                              isMine,
                            ),
                            hashtagStyle: _interactiveStyleForBubble(
                              colors,
                              isMine,
                            ),
                            onMentionTap: onMentionTap,
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

class _GroupBubbleActionButton extends StatelessWidget {
  const _GroupBubbleActionButton({
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

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator({required this.name});

  final String name;

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
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

class _ComposerIconButton extends StatelessWidget {
  const _ComposerIconButton({required this.onPressed, required this.icon});

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
