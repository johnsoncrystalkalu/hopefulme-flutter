import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hopefulme_flutter/app/theme/app_theme.dart';
import 'package:hopefulme_flutter/core/config/reaction_config.dart';
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
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hopefulme_flutter/core/services/onesignal_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;

class MessageThreadScreen extends StatefulWidget {
  const MessageThreadScreen({
    required this.repository,
    required this.profileRepository,
    required this.updateRepository,
    required this.currentUser,
    required this.username,
    required this.title,
    this.onBackToInbox,
    super.key,
  });

  final MessageRepository repository;
  final ProfileRepository profileRepository;
  final UpdateRepository updateRepository;
  final User? currentUser;
  final String username;
  final String title;
  final Future<void> Function(BuildContext context)? onBackToInbox;

  @override
  State<MessageThreadScreen> createState() => _MessageThreadScreenState();
}

class _MessageThreadScreenState extends State<MessageThreadScreen>
    with WidgetsBindingObserver {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _composerFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  ConversationListItem? _conversation;
  List<ChatMessage> _messages = <ChatMessage>[];
  ChatMessage? _replyingTo;
  Timer? _pollTimer;
  bool _isPollInFlight = false;
  int _pollFailureCount = 0;
  bool _isAppForeground = true;
  int _realtimeBurstTicksRemaining = 0;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = false;
  bool _isSending = false;
  bool _showEmojiPicker = false;
  bool _showJumpToBottom = false;
  bool _showJumpToUnread = false;
  bool _hasThreadChanges = false;
  XFile? _selectedPhoto;
  Uint8List? _selectedPhotoBytes;
  PlatformFile? _selectedAudio;
  int? _selectedAudioDurationSeconds;
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _voicePlayer = AudioPlayer();
  Timer? _recordTimer;
  Timer? _recordMeterTimer;
  Duration _recordDuration = Duration.zero;
  bool _isRecordingVoice = false;
  bool _isRecordingLocked = false;
  String? _playingAudioUrl;
  String? _loadingAudioUrl;
  String? _playingPreviewPath;
  String? _loadingPreviewPath;
  StreamSubscription<PlayerState>? _voicePlayerStateSub;
  StreamSubscription<Duration>? _voicePositionSub;
  StreamSubscription<Duration?>? _voiceDurationSub;
  final ValueNotifier<_VoiceTickerState> _voiceTicker = ValueNotifier(
    const _VoiceTickerState(),
  );
  double _recordLevel = 0;
  double _voiceUploadProgress = 0;
  bool _voiceUploadFailed = false;
  int _optimisticId = -1;
  bool _isRestoringDraft = false;
  bool _typingSent = false;
  DateTime? _lastTypingPingAt;
  Timer? _typingDebounce;
  Timer? _draftPersistDebounce;
  String _lastPersistedDraft = '';
  Duration _lastRenderedVoicePosition = Duration.zero;
  String? _lastSendSignature;
  DateTime? _lastSendAt;
  bool _isKeyboardVisible = false;
  Object? _error;
  ChatMessage? _editingMessage;
  ChatMessage? _activeBubbleActionsMessage;
  bool _activeBubbleActionsIsMine = false;
  bool _activeBubbleActionsHasText = false;

  String get _draftKey => 'message_draft_${widget.username}';

  String _selectedPhotoLabel() {
    final name = _selectedPhoto?.name.trim() ?? '';
    if (name.isEmpty) {
      return 'image';
    }
    final normalized = name.toLowerCase();
    if (normalized.startsWith('scaled_') ||
        normalized.startsWith('image_picker') ||
        normalized.startsWith('resized_')) {
      return 'image';
    }
    return name;
  }

  String _selectedAudioLabel() {
    return 'Preview';
  }

  String get _recordDurationLabel {
    final mins = _recordDuration.inMinutes;
    final secs = _recordDuration.inSeconds % 60;
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }

  String _formatAudioDuration(int seconds) {
    if (seconds <= 0) {
      return '--:--';
    }
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }

  String _formatAudioSize(int bytes) {
    if (bytes <= 0) {
      return '';
    }
    const kb = 1024;
    const mb = 1024 * 1024;
    if (bytes >= mb) {
      return '${(bytes / mb).toStringAsFixed(1)} MB';
    }
    return '${(bytes / kb).toStringAsFixed(1)} KB';
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
    _composerFocusNode.addListener(_handleComposerFocusChanged);
    _scrollController.addListener(_handleScroll);
    _voicePlayerStateSub = _voicePlayer.playerStateStream.listen((state) {
      if (!mounted) return;
      if (state.processingState == ProcessingState.completed ||
          (!state.playing && state.processingState == ProcessingState.ready)) {
        setState(() {
          _playingAudioUrl = null;
          _playingPreviewPath = null;
        });
        _voiceTicker.value = _voiceTicker.value.copyWith(
          position: Duration.zero,
        );
      }
    });
    _voicePositionSub = _voicePlayer.positionStream.listen((position) {
      if (!mounted) return;
      final deltaMs =
          (position - _lastRenderedVoicePosition).inMilliseconds.abs();
      if (deltaMs < 120 && position != Duration.zero) {
        return;
      }
      _lastRenderedVoicePosition = position;
      _voiceTicker.value = _voiceTicker.value.copyWith(position: position);
    });
    _voiceDurationSub = _voicePlayer.durationStream.listen((duration) {
      if (!mounted) return;
      final nextDuration = duration ?? Duration.zero;
      if (nextDuration == _voiceTicker.value.totalDuration) {
        return;
      }
      _voiceTicker.value = _voiceTicker.value.copyWith(
        totalDuration: nextDuration,
      );
    });
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
    _draftPersistDebounce?.cancel();
    _recordTimer?.cancel();
    _recordMeterTimer?.cancel();
    _voicePlayerStateSub?.cancel();
    _voicePositionSub?.cancel();
    _voiceDurationSub?.cancel();
    _voiceTicker.dispose();
    unawaited(_audioRecorder.dispose());
    unawaited(_voicePlayer.dispose());
    if (_typingSent) {
      unawaited(_sendTypingStatus(false));
    }
    _composerFocusNode.dispose();
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

  @override
  void didChangeMetrics() {
    final views = WidgetsBinding.instance.platformDispatcher.views;
    if (views.isEmpty) {
      return;
    }
    final view = views.first;
    final bottomInset = view.viewInsets.bottom / view.devicePixelRatio;
    final keyboardVisible = bottomInset > 0;

    final shouldStickToBottom =
        _composerFocusNode.hasFocus || _isNearBottom() || _messages.isEmpty;
    if (keyboardVisible && shouldStickToBottom) {
      _scrollToBottomAnimated();
    }
    _isKeyboardVisible = keyboardVisible;
  }

  Future<void> _restoreDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final savedDraft = prefs.getString(_draftKey)?.trimRight() ?? '';
    _lastPersistedDraft = savedDraft;
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
        _hasMore = thread.hasMore;
        _showJumpToUnread =
            _firstUnreadIndexFor(mergedMessages, thread.conversation) != null;
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
    if (_isSending ||
        _isRecordingVoice ||
        (_voiceUploadProgress > 0 && _voiceUploadProgress < 1)) {
      return const Duration(seconds: 1);
    }
    if (_realtimeBurstTicksRemaining > 0) {
      _realtimeBurstTicksRemaining -= 1;
      return const Duration(seconds: 1);
    }
    if (_pollFailureCount >= 3) {
      return const Duration(seconds: 8);
    }
    if (_showJumpToBottom) {
      return const Duration(seconds: 5);
    }
    if (!_composerFocusNode.hasFocus && !_isNearBottom()) {
      return const Duration(seconds: 6);
    }
    if (_isKeyboardVisible || _composerFocusNode.hasFocus) {
      return const Duration(seconds: 2);
    }
    return const Duration(seconds: 3);
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

      final hasNewMessages = thread.messages.isNotEmpty;
      final conversationChanged = _hasConversationDelta(
        _conversation,
        thread.conversation,
      );
      if (!hasNewMessages && !conversationChanged) {
        _pollFailureCount = 0;
        return;
      }

      final shouldStickToBottom = _isNearBottom() || _messages.isEmpty;
      final nextMessages = hasNewMessages
          ? _mergeMessages(_messages, thread.messages)
          : _messages;
      setState(() {
        _conversation = thread.conversation;
        _messages = nextMessages;
        _showJumpToUnread =
            _firstUnreadIndexFor(nextMessages, thread.conversation) != null;
      });
      if (hasNewMessages) {
        _primeRealtimeBurst(ticks: 6);
      }
      _pollFailureCount = 0;
      if (shouldStickToBottom && hasNewMessages) {
        _scrollToBottomAnimated();
      }
    } catch (_) {
      _pollFailureCount += 1;
      // Keep chat resilient; polling fallback continues on next cycle.
    } finally {
      _isPollInFlight = false;
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    final hasPhoto = _selectedPhoto != null;
    final hasAudio = _selectedAudio != null;
    final replyTargetId = _replyingTo?.id ?? 0;
    final effectiveText = text.isEmpty && (hasPhoto || hasAudio)
        ? (hasAudio ? 'sent a voice note' : 'Shared a photo')
        : text;
    if ((text.isEmpty && !hasPhoto && !hasAudio && _editingMessage == null) ||
        _isSending) {
      return;
    }
    final sendSignature = [
      text,
      hasPhoto ? '1' : '0',
      hasAudio ? '1' : '0',
      replyTargetId.toString(),
      _editingMessage?.id.toString() ?? '0',
    ].join('|');
    final now = DateTime.now();
    if (_lastSendSignature == sendSignature &&
        _lastSendAt != null &&
        now.difference(_lastSendAt!) < const Duration(milliseconds: 900)) {
      return;
    }
    _lastSendSignature = sendSignature;
    _lastSendAt = now;

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
        audioUrl: editingMessage.audioUrl,
        isVoiceNote: editingMessage.isVoiceNote,
        voiceNoteExpired: editingMessage.voiceNoteExpired,
        audioDurationSeconds: editingMessage.audioDurationSeconds,
        audioMimeType: editingMessage.audioMimeType,
        audioSizeBytes: editingMessage.audioSizeBytes,
        replyId: editingMessage.replyId,
        status: 'sending',
        createdAt: editingMessage.createdAt,
        sender: editingMessage.sender,
        recipient: editingMessage.recipient,
        replyTo: editingMessage.replyTo,
        reactions: editingMessage.reactions,
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
        audioUrl: editingMessage.audioUrl,
        isVoiceNote: editingMessage.isVoiceNote,
        voiceNoteExpired: editingMessage.voiceNoteExpired,
        audioDurationSeconds: editingMessage.audioDurationSeconds,
        audioMimeType: editingMessage.audioMimeType,
        audioSizeBytes: editingMessage.audioSizeBytes,
        replyId: editingMessage.replyId,
          status: 'sent',
          createdAt: editingMessage.createdAt,
          sender: editingMessage.sender,
          recipient: editingMessage.recipient,
          replyTo: editingMessage.replyTo,
          reactions: editingMessage.reactions,
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
      final selectedAudio = _selectedAudio;
      final selectedAudioDurationSeconds = _selectedAudioDurationSeconds;
      final optimisticId = _optimisticId--;
      final optimisticMessage = ChatMessage(
        id: optimisticId,
        conversationId: _conversation?.id ?? 0,
        senderId: widget.currentUser?.id ?? 0,
        recipientId: _conversation?.otherUser.id ?? 0,
        message: effectiveText.isEmpty ? 'sent a voice note' : effectiveText,
        photoUrl: '',
        audioUrl: '',
        isVoiceNote: selectedAudio != null,
        voiceNoteExpired: false,
        audioDurationSeconds: selectedAudioDurationSeconds ?? 0,
        audioMimeType: selectedAudio?.extension ?? '',
        audioSizeBytes: selectedAudio?.size ?? 0,
        replyId: replyTargetId,
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
        reactions: const <ChatReactionSummary>[],
        localImageBytes: localPhotoBytes,
      );

      setState(() {
        _isSending = true;
        _error = null;
        _messages = [..._messages, optimisticMessage];
        _selectedPhoto = null;
        _selectedPhotoBytes = null;
        _selectedAudio = null;
        _selectedAudioDurationSeconds = null;
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
        setState(() {
          _voiceUploadFailed = false;
          _voiceUploadProgress = 0;
        });
        final sent = await widget.repository.sendMessage(
          widget.username,
          message: effectiveText,
          replyId: optimisticMessage.replyId == 0
              ? null
              : optimisticMessage.replyId,
          photo: selectedPhoto,
          audio: selectedAudio,
          audioDurationSeconds: selectedAudioDurationSeconds,
          onUploadProgress: (sentBytes, totalBytes) {
            if (!mounted || selectedAudio == null || totalBytes <= 0) {
              return;
            }
            final ratio = (sentBytes / totalBytes).clamp(0.0, 1.0);
            if ((ratio - _voiceUploadProgress).abs() < 0.02 &&
                ratio < 1.0) {
              return;
            }
            setState(() {
              _voiceUploadProgress = ratio;
            });
          },
        );
        if (!mounted) return;
        final resolvedSent =
            sent.replyTo != null ||
                optimisticMessage.replyTo == null ||
                optimisticMessage.replyId == 0
            ? sent
            : ChatMessage(
                id: sent.id,
                conversationId: sent.conversationId,
                senderId: sent.senderId,
                recipientId: sent.recipientId,
                message: sent.message,
                photoUrl: sent.photoUrl,
                audioUrl: sent.audioUrl,
                isVoiceNote: sent.isVoiceNote,
                voiceNoteExpired: sent.voiceNoteExpired,
                audioDurationSeconds: sent.audioDurationSeconds,
                audioMimeType: sent.audioMimeType,
                audioSizeBytes: sent.audioSizeBytes,
                replyId: sent.replyId == 0
                    ? optimisticMessage.replyId
                    : sent.replyId,
                status: sent.status,
                createdAt: sent.createdAt,
                sender: sent.sender,
                recipient: sent.recipient,
                replyTo: optimisticMessage.replyTo,
                reactions: sent.reactions,
                localImageBytes: sent.localImageBytes,
              );
        setState(() {
          _hasThreadChanges = true;
          _voiceUploadProgress = 0;
          _voiceUploadFailed = false;
          final replaced = _messages
              .map((item) => item.id == optimisticId ? resolvedSent : item)
              .toList();
          _messages = _dedupeById(replaced);
        });
        _scrollToBottomAnimated();
        _primeRealtimeBurst();
        _scheduleNextPoll(immediate: true);
      //  unawaited(_pollLatestMessages()); jck check
      } catch (error) {
        if (!mounted) return;
        setState(() {
          _error = error;
          _voiceUploadProgress = 0;
          _voiceUploadFailed = selectedAudio != null;
          _messages = _messages
              .where((item) => item.id != optimisticId)
              .toList();
          if (selectedPhoto != null && _selectedPhoto == null) {
            _selectedPhoto = selectedPhoto;
            _selectedPhotoBytes = localPhotoBytes;
          }
          if (selectedAudio != null && _selectedAudio == null) {
            _selectedAudio = selectedAudio;
            _selectedAudioDurationSeconds = selectedAudioDurationSeconds;
          }
          if (text.isNotEmpty && _controller.text.trim().isEmpty) {
            _controller.text = text;
          }
          if (_replyingTo == null && optimisticMessage.replyTo != null) {
            _replyingTo = ChatMessage(
              id: optimisticMessage.replyTo!.id,
              conversationId: _conversation?.id ?? 0,
              senderId: optimisticMessage.replyTo!.sender?.id ?? 0,
              recipientId: widget.currentUser?.id ?? 0,
              message: optimisticMessage.replyTo!.message,
              photoUrl: '',
              audioUrl: '',
              isVoiceNote: false,
              voiceNoteExpired: false,
              audioDurationSeconds: 0,
              audioMimeType: '',
              audioSizeBytes: 0,
              replyId: 0,
              status: 'sent',
              createdAt: '',
              sender: optimisticMessage.replyTo!.sender,
              recipient: widget.currentUser?.toConversationUser(),
              replyTo: null,
              reactions: const <ChatReactionSummary>[],
            );
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

  Future<void> _startVoiceRecordingLocked() async {
    await _beginVoiceRecording(locked: true);
  }

  Future<void> _beginVoiceRecording({required bool locked}) async {
    if (_isSending || _isRecordingVoice || _editingMessage != null) return;
    try {
      final hasPermission = await _audioRecorder.hasPermission();
      if (!hasPermission) {
        if (mounted) AppToast.error(context, 'Microphone permission is required.');
        return;
      }
      _recordDuration = Duration.zero;
      final outputPath =
          '${Directory.systemTemp.path}${Platform.pathSeparator}voice-note-${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          sampleRate: 16000,
          bitRate: 32000,
          numChannels: 1,
        ),
        path: outputPath,
      );
      _recordTimer?.cancel();
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {
          _recordDuration += const Duration(seconds: 1);
        });
        if (_recordDuration.inSeconds >= 300) {
          unawaited(_stopVoiceRecording());
          AppToast.info(context, 'Voice note reached 5-minute limit.');
        }
      });
      _recordMeterTimer?.cancel();
      _recordMeterTimer = Timer.periodic(const Duration(milliseconds: 220), (_) async {
        try {
          final amp = await _audioRecorder.getAmplitude();
          if (!mounted) return;
          final db = amp.current;
          final normalized = ((db + 60) / 60).clamp(0.0, 1.0);
          if ((normalized - _recordLevel).abs() < 0.08) {
            return;
          }
          setState(() {
            _recordLevel = normalized;
          });
        } catch (_) {}
      });
      if (!mounted) return;
      setState(() {
        _isRecordingVoice = true;
        _isRecordingLocked = locked;
        _showEmojiPicker = false;
        _selectedAudio = null;
        _selectedAudioDurationSeconds = null;
      });
    } catch (_) {
      if (mounted) AppToast.error(context, 'Unable to start recording right now.');
    }
  }

  Future<void> _cancelVoiceRecording() async {
    try {
      await _audioRecorder.stop();
    } catch (_) {}
    _recordTimer?.cancel();
    _recordMeterTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _isRecordingVoice = false;
      _isRecordingLocked = false;
      _recordDuration = Duration.zero;
      _selectedAudio = null;
      _selectedAudioDurationSeconds = null;
      _recordLevel = 0;
    });
  }

  Future<void> _stopVoiceRecording() async {
    String? path;
    try {
      path = await _audioRecorder.stop();
    } catch (_) {}
    _recordTimer?.cancel();
    _recordMeterTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _isRecordingVoice = false;
      _isRecordingLocked = false;
    });
    if (path == null || path.trim().isEmpty) {
      setState(() {
        _recordDuration = Duration.zero;
        _recordLevel = 0;
      });
      return;
    }
    final file = File(path);
    var exists = await file.exists();
    var attempts = 0;
    var length = 0;
    while (attempts < 6) {
      if (exists) {
        length = await file.length();
        if (length > 0) {
          break;
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 120));
      exists = await file.exists();
      attempts += 1;
    }
    if (!exists) {
      if (mounted) AppToast.error(context, 'Recorded audio not found.');
      return;
    }
    if (length <= 0) {
      if (mounted) AppToast.error(context, 'Voice note was empty. Please try again.');
      return;
    }
    final filename = file.uri.pathSegments.isNotEmpty
        ? file.uri.pathSegments.last
        : 'voice-note.m4a';
    setState(() {
      _selectedAudio = PlatformFile(
        name: filename,
        path: path,
        size: length,
      );
      _selectedAudioDurationSeconds = _recordDuration.inSeconds;
    });
    if (mounted) {
      setState(() {
        _recordDuration = Duration.zero;
        _recordLevel = 0;
      });
    }
  }

  Future<void> _openAudioUrl(String audioUrl) async {
    final trimmed = _normalizedAudioUrl(audioUrl);
    if (trimmed.isEmpty) return;
    if (_playingAudioUrl == trimmed) {
      await _voicePlayer.pause();
      if (!mounted) return;
      setState(() {
        _playingAudioUrl = null;
        _playingPreviewPath = null;
      });
      _voiceTicker.value = _voiceTicker.value.copyWith(position: Duration.zero);
      return;
    }

    try {
      if (mounted) {
      setState(() {
        _loadingAudioUrl = trimmed;
        _loadingPreviewPath = null;
      });
      }
      _voiceTicker.value = _voiceTicker.value.copyWith(position: Duration.zero);
      await _voicePlayer.stop();
      await _voicePlayer.setUrl(
        trimmed,
        headers: const {
          'X-App-Client': 'hopefulme_flutter',
          'User-Agent': 'Mozilla/5.0 (Flutter HopefulMe)',
        },
      );
      if (!mounted) return;
      setState(() {
        _loadingAudioUrl = null;
        _playingAudioUrl = trimmed;
        _playingPreviewPath = null;
      });
      _voiceTicker.value = _voiceTicker.value.copyWith(
        totalDuration: _voicePlayer.duration ?? Duration.zero,
      );
      await _voicePlayer.play();
    } catch (_) {
      try {
        final response = await http.get(
          Uri.parse(trimmed),
          headers: const {
            'X-App-Client': 'hopefulme_flutter',
            'User-Agent': 'Mozilla/5.0 (Flutter HopefulMe)',
          },
        );
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw Exception('download failed (HTTP ${response.statusCode})');
        }
        final ext = trimmed.toLowerCase().contains('.mp3')
            ? 'mp3'
            : trimmed.toLowerCase().contains('.wav')
            ? 'wav'
            : 'm4a';
        final localPath =
            '${Directory.systemTemp.path}${Platform.pathSeparator}voice-play-${DateTime.now().millisecondsSinceEpoch}.$ext';
        final file = File(localPath);
        await file.writeAsBytes(response.bodyBytes, flush: true);

        await _voicePlayer.stop();
        await _voicePlayer.setFilePath(localPath);
        if (!mounted) return;
        setState(() {
          _loadingAudioUrl = null;
          _playingAudioUrl = trimmed;
        });
        await _voicePlayer.play();
      } catch (downloadError) {
        if (!mounted) return;
        setState(() {
          _loadingAudioUrl = null;
          _loadingPreviewPath = null;
          if (_playingAudioUrl == trimmed) {
            _playingAudioUrl = null;
          }
        });
        _voiceTicker.value = _voiceTicker.value.copyWith(
          position: Duration.zero,
        );
        AppToast.error(context, 'Voice note not found');
      }
    }
  }

  String _normalizedAudioUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    final uri = Uri.tryParse(trimmed);
    if (uri == null) {
      return trimmed;
    }
    final shouldUpgradeToHttps =
        uri.scheme == 'http' &&
        (uri.host == 'ahopefulme.com' || uri.host.endsWith('.ahopefulme.com'));
    if (!shouldUpgradeToHttps) {
      return uri.toString();
    }
    return uri.replace(scheme: 'https', port: 443).toString();
  }

  Future<void> _toggleSelectedAudioPreview() async {
    final path = _selectedAudio?.path?.trim() ?? '';
    if (path.isEmpty) {
      AppToast.error(context, 'No recorded voice note to preview yet.');
      return;
    }
    if (_playingPreviewPath == path) {
      await _voicePlayer.pause();
      if (!mounted) return;
      setState(() {
        _playingPreviewPath = null;
      });
      return;
    }
    try {
      if (mounted) {
      setState(() {
        _loadingPreviewPath = path;
        _loadingAudioUrl = null;
      });
      }
      _voiceTicker.value = _voiceTicker.value.copyWith(position: Duration.zero);
      await _voicePlayer.stop();
      await _voicePlayer.setFilePath(path);
      if (!mounted) return;
      setState(() {
        _loadingPreviewPath = null;
        _playingPreviewPath = path;
        _playingAudioUrl = null;
      });
      _voiceTicker.value = _voiceTicker.value.copyWith(
        totalDuration: _voicePlayer.duration ?? Duration.zero,
      );
      await _voicePlayer.play();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingPreviewPath = null;
        _playingPreviewPath = null;
      });
      _voiceTicker.value = _voiceTicker.value.copyWith(position: Duration.zero);
      AppToast.error(context, 'Unable to preview this voice note.');
    }
  }

  Future<void> _seekVoice(double ratio) async {
    final totalMs = _voiceTicker.value.totalDuration.inMilliseconds;
    if (totalMs <= 0) return;
    final targetMs = (ratio.clamp(0.0, 1.0) * totalMs).round();
    await _voicePlayer.seek(Duration(milliseconds: targetMs));
  }

  Future<void> _cycleVoiceSpeed() async {
    const speeds = <double>[1.0, 1.25, 1.5, 2.0];
    final currentIndex = speeds.indexOf(_voiceTicker.value.playbackSpeed);
    final next = speeds[(currentIndex + 1) % speeds.length];
    await _voicePlayer.setSpeed(next);
    _voiceTicker.value = _voiceTicker.value.copyWith(playbackSpeed: next);
  }

  // âœ… open image fullscreen with pinch-to-zoom
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

  void _jumpToFirstUnread(int firstUnreadIndex) {
    if (!_scrollController.hasClients || _messages.isEmpty) return;
    final maxExtent = _scrollController.position.maxScrollExtent;
    if (maxExtent <= 0) {
      setState(() {
        _showJumpToUnread = false;
      });
      return;
    }
    final ratio = _messages.length <= 1
        ? 0.0
        : firstUnreadIndex / (_messages.length - 1);
    final target = (maxExtent * ratio).clamp(0.0, maxExtent);
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
    setState(() {
      _showJumpToUnread = false;
    });
  }

  void _handleComposerChanged() {
    _scheduleDraftPersist(_controller.text);
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

  void _handleComposerFocusChanged() {
    if (_composerFocusNode.hasFocus) {
      _scrollToBottomAnimated();
    } else if (_isKeyboardVisible) {
      _isKeyboardVisible = false;
    }
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
    if (_scrollController.position.pixels <= 80) {
      unawaited(_loadOlder());
    }
  }

  Future<void> _loadOlder() async {
    if (_isLoadingMore || !_hasMore || _messages.isEmpty || !mounted) {
      return;
    }

    final firstPersistedMessage = _messages.firstWhere(
      (message) => message.id > 0,
      orElse: () => _messages.first,
    );
    if (firstPersistedMessage.id <= 0) {
      return;
    }

    final previousPixels = _scrollController.hasClients
        ? _scrollController.position.pixels
        : 0.0;
    final previousMaxExtent = _scrollController.hasClients
        ? _scrollController.position.maxScrollExtent
        : 0.0;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final response = await widget.repository.fetchThread(
        widget.username,
        beforeId: firstPersistedMessage.id,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _conversation = response.conversation;
        _messages = _mergeMessages(response.messages, _messages);
        _hasMore = response.hasMore;
        _showJumpToUnread =
            _firstUnreadIndexFor(_messages, response.conversation) != null;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollController.hasClients) {
          return;
        }
        final newMaxExtent = _scrollController.position.maxScrollExtent;
        final delta = newMaxExtent - previousMaxExtent;
        final target = previousPixels + delta;
        _scrollController.jumpTo(target.clamp(0.0, newMaxExtent));
      });
    } catch (_) {
      // Keep pagination resilient and retry on next top reach.
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
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

  void _showInlineBubbleActions({
    required ChatMessage message,
    required bool isMine,
    required bool hasText,
  }) {
    setState(() {
      _activeBubbleActionsMessage = message;
      _activeBubbleActionsIsMine = isMine;
      _activeBubbleActionsHasText = hasText;
    });
  }

  Future<void> _handleInlineBubbleAction(String value) async {
    final message = _activeBubbleActionsMessage;
    if (message == null) {
      return;
    }

    if (value == 'reply') {
      setState(() {
        _replyingTo = message;
        _activeBubbleActionsMessage = null;
      });
      return;
    }

    if (value.startsWith('react:')) {
      await _toggleReaction(message, value.substring(6));
      if (!mounted) {
        return;
      }
      setState(() {
        _activeBubbleActionsMessage = null;
      });
      return;
    }

    if (value == 'copy') {
      await Clipboard.setData(ClipboardData(text: message.message));
      if (mounted) {
        AppToast.info(context, 'Text copied');
      }
      setState(() {
        _activeBubbleActionsMessage = null;
      });
      return;
    }

    if (value == 'edit') {
      setState(() {
        _editingMessage = message;
        _controller.text = message.message;
        _controller.selection = TextSelection.collapsed(
          offset: message.message.length,
        );
        _replyingTo = null;
        _showEmojiPicker = false;
        _selectedPhoto = null;
        _selectedPhotoBytes = null;
        _selectedAudio = null;
        _selectedAudioDurationSeconds = null;
        _activeBubbleActionsMessage = null;
      });
      return;
    }

    if (value == 'delete') {
      await _deleteMessage(message);
      if (!mounted) {
        return;
      }
      setState(() {
        _activeBubbleActionsMessage = null;
      });
    }
  }

  List<ChatReactionSummary> _optimisticToggleReactions(
    List<ChatReactionSummary> current,
    String emoji,
  ) {
    final targetKey = _normalizedReactionKey(emoji);
    final items = <ChatReactionSummary>[...current];
    int? myReactionIndex;
    for (var i = 0; i < items.length; i++) {
      if (items[i].reactedByMe) {
        myReactionIndex = i;
        break;
      }
    }

    if (myReactionIndex != null &&
        _normalizedReactionKey(items[myReactionIndex].emoji) == targetKey) {
      final mine = items[myReactionIndex];
      final nextCount = mine.count - 1;
      if (nextCount <= 0) {
        items.removeAt(myReactionIndex);
      } else {
        items[myReactionIndex] = mine.copyWith(
          count: nextCount,
          reactedByMe: false,
        );
      }
    } else {
      if (myReactionIndex != null) {
        final mine = items[myReactionIndex];
        final nextCount = mine.count - 1;
        if (nextCount <= 0) {
          items.removeAt(myReactionIndex);
        } else {
          items[myReactionIndex] = mine.copyWith(
            count: nextCount,
            reactedByMe: false,
          );
        }
      }

      final targetIndex = items.indexWhere(
        (item) => _normalizedReactionKey(item.emoji) == targetKey,
      );
      if (targetIndex == -1) {
        items.add(
          ChatReactionSummary(emoji: emoji, count: 1, reactedByMe: true),
        );
      } else {
        final target = items[targetIndex];
        items[targetIndex] = target.copyWith(
          count: target.count + 1,
          reactedByMe: true,
        );
      }
    }

    final deduped = <String, ChatReactionSummary>{};
    for (final item in items) {
      final key = _normalizedReactionKey(item.emoji);
      final existing = deduped[key];
      if (existing == null) {
        deduped[key] = item;
      } else {
        deduped[key] = ChatReactionSummary(
          emoji: existing.emoji.isNotEmpty ? existing.emoji : item.emoji,
          count: existing.count + item.count,
          reactedByMe: existing.reactedByMe || item.reactedByMe,
        );
      }
    }

    final normalizedItems = deduped.values.toList();
    normalizedItems.sort((a, b) => b.count.compareTo(a.count));
    return normalizedItems;
  }

  String _normalizedReactionKey(String emoji) {
    return emoji.replaceAll('\uFE0F', '').replaceAll('\uFE0E', '').trim();
  }

  Future<void> _toggleReaction(ChatMessage message, String emoji) async {
    final previous = message;
    final optimistic = message.copyWith(
      reactions: _optimisticToggleReactions(message.reactions, emoji),
    );

    setState(() {
      _messages = _messages
          .map((item) => item.id == message.id ? optimistic : item)
          .toList();
    });

    try {
      final updated = await widget.repository.toggleReaction(
        message.id,
        emoji: emoji,
      );
      if (!mounted) return;
      setState(() {
        _messages = _messages
            .map((item) => item.id == message.id ? updated : item)
            .toList();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _messages = _messages
            .map((item) => item.id == message.id ? previous : item)
            .toList();
      });
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

  Future<void> _closeThread() async {
    final onBackToInbox = widget.onBackToInbox;
    if (onBackToInbox != null) {
      await onBackToInbox(context);
      return;
    }
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(_hasThreadChanges);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final conversation = _conversation;
    final otherUser = conversation?.otherUser;
    final firstUnreadIndex = _firstUnreadIndexFor(_messages, conversation);
    final typingUserName = conversation?.typingUserName.trim() ?? '';
    final isSomeoneElseTyping =
        conversation != null &&
        typingUserName.isNotEmpty &&
        conversation.typingUserId != widget.currentUser?.id;

    return PopScope<bool>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        unawaited(_closeThread());
      },
      child: Scaffold(
        backgroundColor: colors.scaffold,
        appBar: AppBar(
          backgroundColor: colors.surface,
          surfaceTintColor: colors.surface,
          leading: IconButton(
            onPressed: () => unawaited(_closeThread()),
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
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () {
                  if (_activeBubbleActionsMessage == null && _replyingTo == null) {
                    return;
                  }
                  setState(() {
                    _activeBubbleActionsMessage = null;
                    _replyingTo = null;
                  });
                },
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
                        : _messages.isEmpty
                        ? const _ThreadEmptyState(
                            title: 'No messages yet',
                            subtitle: 'Start the conversation...',
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            keyboardDismissBehavior:
                                ScrollViewKeyboardDismissBehavior.onDrag,
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                            itemCount:
                                _messages.length + (_isLoadingMore ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (_isLoadingMore && index == 0) {
                                return const Padding(
                                  padding: EdgeInsets.only(bottom: 10),
                                  child: Center(
                                    child: SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  ),
                                );
                              }
                              final messageIndex = _isLoadingMore
                                  ? index - 1
                                  : index;
                              final item = _messages[messageIndex];
                              final previous = messageIndex > 0
                                  ? _messages[messageIndex - 1]
                                  : null;
                              final isMine = widget.currentUser != null
                                  ? item.senderId == widget.currentUser!.id
                                  : item.sender?.username != widget.username;
                              final groupedWithPrevious =
                                  previous != null &&
                                  previous.senderId == item.senderId &&
                                  !_shouldShowDateDivider(messageIndex);
                              final screenWidth = MediaQuery.sizeOf(
                                context,
                              ).width;
                              final maxBubbleWidth = math.min(
                                360.0,
                                screenWidth * 0.76,
                              );
                              final mediaBubbleImageSize = math.min(
                                224.0,
                                maxBubbleWidth - 28,
                              );
                              void startReply() {
                                setState(() {
                                  _replyingTo = item;
                                });
                              }

                              return Column(
                                children: [
                                  if (_shouldShowDateDivider(messageIndex))
                                    _ChatDateDivider(
                                      label: _dateLabelForIndex(messageIndex),
                                    ),
                                  if (firstUnreadIndex != null &&
                                      messageIndex == firstUnreadIndex)
                                    const _ChatUnreadDivider(),
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
                                          child: Column(
                                            crossAxisAlignment: isMine
                                                ? CrossAxisAlignment.end
                                                : CrossAxisAlignment.start,
                                            children: [
                                              _SwipeReplyWrapper(
                                                onReply: startReply,
                                                child: GestureDetector(
                                                  onLongPressStart: (_) {
                                                    HapticFeedback.mediumImpact();
                                                    final isPendingVoiceNote =
                                                        item.isVoiceNote &&
                                                        item.audioUrl.isEmpty &&
                                                        item.status.trim().toLowerCase() ==
                                                            'sending';
                                                    final hasText = !isPendingVoiceNote &&
                                                        item.message
                                                            .trim()
                                                            .isNotEmpty;
                                                    _showInlineBubbleActions(
                                                      message: item,
                                                      isMine: isMine,
                                                      hasText: hasText,
                                                    );
                                                  },
                                                  child: Container(
                                                    constraints: BoxConstraints(
                                                      maxWidth: maxBubbleWidth,
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
                                                          BorderRadius.circular(
                                                            20,
                                                          ),
                                                      border: isMine
                                                          ? null
                                                          : Border.all(
                                                              color:
                                                                  colors.border,
                                                            ),
                                                    ),
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        if (item.replyTo !=
                                                            null) ...[
                                                          _ThreadReplyQuote(
                                                            reply:
                                                                item.replyTo!,
                                                            isMine: isMine,
                                                          ),
                                                          const SizedBox(
                                                            height: 8,
                                                          ),
                                                        ],
                                                        // âœ… image with tap to fullscreen
                                                        if (item.isVoiceNote &&
                                                            item.audioUrl.isEmpty &&
                                                            item.status.trim().toLowerCase() ==
                                                                'sending') ...[
                                                          Container(
                                                            padding: const EdgeInsets.symmetric(
                                                              horizontal: 12,
                                                              vertical: 10,
                                                            ),
                                                            decoration: BoxDecoration(
                                                              color: isMine
                                                                  ? Colors.white.withValues(alpha: 0.12)
                                                                  : colors.surfaceMuted,
                                                              borderRadius: BorderRadius.circular(14),
                                                              border: Border.all(
                                                                color: isMine
                                                                    ? Colors.white.withValues(alpha: 0.18)
                                                                    : colors.borderStrong,
                                                              ),
                                                            ),
                                                            child: Row(
                                                              mainAxisSize: MainAxisSize.min,
                                                              children: [
                                                                SizedBox(
                                                                  width: 16,
                                                                  height: 16,
                                                                  child: CircularProgressIndicator(
                                                                    strokeWidth: 2,
                                                                    color: isMine ? Colors.white : colors.brand,
                                                                  ),
                                                                ),
                                                                const SizedBox(width: 8),
                                                                Text(
                                                                  'Sending voice note...',
                                                                  style: TextStyle(
                                                                    color: isMine ? Colors.white : colors.textPrimary,
                                                                    fontSize: 13,
                                                                    fontWeight: FontWeight.w700,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ] else if (item.audioUrl.isNotEmpty) ...[
                                                          SizedBox(
                                                            width: maxBubbleWidth * 0.92,
                                                            child:
                                                          GestureDetector(
                                                            onTap: () => _openAudioUrl(item.audioUrl),
                                                            child: Container(
                                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                                              decoration: BoxDecoration(
                                                                color: isMine
                                                                    ? Colors.white.withValues(alpha: 0.12)
                                                                    : colors.surfaceMuted,
                                                                borderRadius: BorderRadius.circular(14),
                                                                border: Border.all(
                                                                  color: isMine
                                                                      ? Colors.white.withValues(alpha: 0.18)
                                                                      : colors.borderStrong,
                                                                ),
                                                              ),
                                                              child: Column(
                                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                                mainAxisSize: MainAxisSize.min,
                                                                children: [
                                                                  Row(
                                                                    mainAxisSize: MainAxisSize.min,
                                                                    children: [
                                                                      Builder(
                                                                        builder: (context) {
                                                                          final isLoading = _loadingAudioUrl == item.audioUrl;
                                                                          final isPlaying = _playingAudioUrl == item.audioUrl;
                                                                          if (isLoading) {
                                                                            return SizedBox(
                                                                              width: 18,
                                                                              height: 18,
                                                                              child: CircularProgressIndicator(
                                                                                strokeWidth: 2,
                                                                                color: isMine ? Colors.white : colors.brand,
                                                                              ),
                                                                            );
                                                                          }
                                                                          return Icon(
                                                                            isPlaying
                                                                                ? Icons.pause_circle_filled_rounded
                                                                                : Icons.play_circle_fill_rounded,
                                                                            size: 18,
                                                                            color: isMine ? Colors.white : colors.brand,
                                                                          );
                                                                        },
                                                                      ),
                                                                      const SizedBox(width: 8),
                                                                      Flexible(
                                                                        child: Text(
                                                                          'Voice note ${_formatAudioDuration(item.audioDurationSeconds)}',
                                                                          style: TextStyle(
                                                                            color: isMine ? Colors.white : colors.textPrimary,
                                                                            fontSize: 13,
                                                                            fontWeight: FontWeight.w700,
                                                                          ),
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                  if (_playingAudioUrl == item.audioUrl)
                                                                    ValueListenableBuilder<_VoiceTickerState>(
                                                                      valueListenable: _voiceTicker,
                                                                      builder: (context, ticker, _) {
                                                                        return Column(
                                                                          crossAxisAlignment:
                                                                              CrossAxisAlignment.start,
                                                                          children: [
                                                                            const SizedBox(height: 6),
                                                                            SizedBox(
                                                                              width: maxBubbleWidth * 0.78,
                                                                              child: SliderTheme(
                                                                                data: SliderTheme.of(context).copyWith(
                                                                                  trackHeight: 2.0,
                                                                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4),
                                                                                ),
                                                                                child: Slider(
                                                                                  value: ticker.totalDuration.inMilliseconds <= 0
                                                                                      ? 0
                                                                                      : (ticker.position.inMilliseconds /
                                                                                            ticker.totalDuration.inMilliseconds)
                                                                                          .clamp(0.0, 1.0),
                                                                                  onChanged: _seekVoice,
                                                                                ),
                                                                              ),
                                                                            ),
                                                                            Row(
                                                                              mainAxisSize: MainAxisSize.min,
                                                                              children: [
                                                                                Text(
                                                                                  _formatAudioDuration(ticker.position.inSeconds),
                                                                                  style: TextStyle(
                                                                                    color: isMine ? Colors.white70 : colors.textMuted,
                                                                                    fontSize: 10,
                                                                                    fontWeight: FontWeight.w600,
                                                                                  ),
                                                                                ),
                                                                                const SizedBox(width: 6),
                                                                                TextButton(
                                                                                  onPressed: _cycleVoiceSpeed,
                                                                                  style: TextButton.styleFrom(
                                                                                    minimumSize: const Size(0, 20),
                                                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                                                                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                                                  ),
                                                                                  child: Text(
                                                                                    '${ticker.playbackSpeed.toStringAsFixed(ticker.playbackSpeed == ticker.playbackSpeed.roundToDouble() ? 0 : 2)}x',
                                                                                    style: TextStyle(
                                                                                      color: isMine ? Colors.white : colors.brand,
                                                                                      fontSize: 10,
                                                                                      fontWeight: FontWeight.w800,
                                                                                    ),
                                                                                  ),
                                                                                ),
                                                                              ],
                                                                            ),
                                                                          ],
                                                                        );
                                                                      },
                                                                    ),
                                                                ],
                                                              ),
                                                            ),
                                                          ),
                                                          ),
                                                          if (item.message.isNotEmpty &&
                                                              !(item.isVoiceNote &&
                                                                  item.audioUrl.isEmpty &&
                                                                  item.status.trim().toLowerCase() ==
                                                                      'sending'))
                                                            const SizedBox(height: 10),
                                                        ] else if (item.isVoiceNote &&
                                                            item.voiceNoteExpired) ...[
                                                          Container(
                                                            padding: const EdgeInsets.symmetric(
                                                              horizontal: 12,
                                                              vertical: 10,
                                                            ),
                                                            decoration: BoxDecoration(
                                                              color: isMine
                                                                  ? Colors.white.withValues(alpha: 0.12)
                                                                  : colors.surfaceMuted,
                                                              borderRadius: BorderRadius.circular(14),
                                                              border: Border.all(
                                                                color: isMine
                                                                    ? Colors.white.withValues(alpha: 0.18)
                                                                    : colors.borderStrong,
                                                              ),
                                                            ),
                                                            child: Row(
                                                              mainAxisSize: MainAxisSize.min,
                                                              children: [
                                                                Icon(
                                                                  Icons.timer_off_outlined,
                                                                  size: 16,
                                                                  color: isMine ? Colors.white : colors.textMuted,
                                                                ),
                                                                const SizedBox(width: 8),
                                                                Text(
                                                                  'Voice note expired',
                                                                  style: TextStyle(
                                                                    color: isMine ? Colors.white : colors.textMuted,
                                                                    fontSize: 13,
                                                                    fontWeight: FontWeight.w700,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ],
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
                                                              child: SizedBox(
                                                                width:
                                                                    mediaBubbleImageSize,
                                                                height:
                                                                    mediaBubbleImageSize,
                                                                child:
                                                                    item.localImageBytes !=
                                                                        null
                                                                    ? Image.memory(
                                                                        item.localImageBytes!,
                                                                        fit: BoxFit
                                                                            .cover,
                                                                        filterQuality:
                                                                            FilterQuality.low,
                                                                      )
                                                                    : Image.network(
                                                                        item.photoUrl,
                                                                        fit: BoxFit
                                                                            .cover,
                                                                        filterQuality:
                                                                            FilterQuality.low,
                                                                        cacheWidth:
                                                                            900,
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
                                                          ),
                                                          if (item
                                                                  .message
                                                                  .isNotEmpty &&
                                                              (!item.isVoiceNote ||
                                                                  (item.audioUrl.isEmpty &&
                                                                      item.status.trim().toLowerCase() !=
                                                                          'sending')))
                                                            const SizedBox(
                                                              height: 10,
                                                            ),
                                                        ],
                                                        if (item
                                                                .message
                                                                .isNotEmpty &&
                                                            (!item.isVoiceNote ||
                                                                (item.audioUrl.isEmpty &&
                                                                    item.status.trim().toLowerCase() !=
                                                                        'sending')))
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
                                                                ), // ðŸ‘ˆ
                                                            hashtagStyle:
                                                                _interactiveStyleForBubble(
                                                                  colors,
                                                                  isMine,
                                                                ), // ðŸ‘ˆ
                                                            onMentionTap: (username) => openUserProfile(
                                                              context,
                                                              profileRepository:
                                                                  widget
                                                                      .profileRepository,
                                                              messageRepository:
                                                                  widget
                                                                      .repository,
                                                              updateRepository:
                                                                  widget
                                                                      .updateRepository,
                                                              currentUser: widget
                                                                  .currentUser,
                                                              username:
                                                                  username,
                                                            ),
                                                            onLinkTap:
                                                                _handleLinkTap,
                                                          ),
                                                        SizedBox(
                                                          height:
                                                              item
                                                                  .message
                                                                  .isNotEmpty
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
                                                                    ? Colors
                                                                          .white70
                                                                    : colors
                                                                          .textMuted,
                                                                fontSize: 11,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                              ),
                                                            ),
                                                            if (isMine) ...[
                                                              const SizedBox(
                                                                width: 6,
                                                              ),
                                                              _MessageDeliveryStatus(
                                                                status:
                                                                    item.status,
                                                              ),
                                                            ],
                                                          ],
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              if (item.reactions.isNotEmpty)
                                                Transform.translate(
                                                  offset: const Offset(0, -4),
                                                  child: _ReactionBar(
                                                    reactions: item.reactions,
                                                    onTapEmoji: (emoji) =>
                                                        _toggleReaction(
                                                          item,
                                                          emoji,
                                                        ),
                                                  ),
                                                ),
                                            ],
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
                  if (_showJumpToUnread && firstUnreadIndex != null)
                    Positioned(
                      right: 18,
                      bottom: _showJumpToBottom ? 74 : 16,
                      child: FilledButton.tonalIcon(
                        onPressed: () => _jumpToFirstUnread(firstUnreadIndex),
                        icon: const Icon(Icons.mark_chat_unread_outlined),
                        label: const Text('Unread'),
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
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
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              child: Column(
                children: [
                  if (_activeBubbleActionsMessage != null)
                    _InlineBubbleActionsBar(
                      hasText: _activeBubbleActionsHasText,
                      isMine: _activeBubbleActionsIsMine,
                      onActionTap: _handleInlineBubbleAction,
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
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                decoration: BoxDecoration(
                  color: colors.surface,
                  border: Border(top: BorderSide(color: colors.border)),
                ),
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
                    if (_selectedAudio != null)
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
                            if (_loadingPreviewPath ==
                                (_selectedAudio?.path ?? ''))
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: colors.brand,
                                ),
                              )
                            else
                              IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 24,
                                  minHeight: 24,
                                ),
                                onPressed: _toggleSelectedAudioPreview,
                                icon: Icon(
                                  _playingPreviewPath ==
                                          (_selectedAudio?.path ?? '')
                                      ? Icons.pause_circle_filled_rounded
                                      : Icons.play_circle_fill_rounded,
                                  color: colors.brand,
                                ),
                              ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _selectedAudioLabel(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: colors.textPrimary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  if ((_selectedAudio?.size ?? 0) > 0)
                                    Text(
                                      '${_selectedAudioDurationSeconds != null ? _formatAudioDuration(_selectedAudioDurationSeconds!) : '--:--'} · ${_formatAudioSize(_selectedAudio!.size)}',
                                      style: TextStyle(
                                        color: colors.textMuted,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  if (_voiceUploadProgress > 0 &&
                                      _voiceUploadProgress < 1) ...[
                                    const SizedBox(height: 6),
                                    LinearProgressIndicator(
                                      value: _voiceUploadProgress,
                                      minHeight: 4,
                                    ),
                                  ],
                                  if (_voiceUploadFailed) ...[
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Text(
                                          'Send failed',
                                          style: TextStyle(
                                            color: Colors.red.shade600,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        TextButton(
                                          onPressed: _isSending ? null : _sendMessage,
                                          child: const Text('Retry'),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                setState(() {
                                  _selectedAudio = null;
                                  _selectedAudioDurationSeconds = null;
                                  _playingPreviewPath = null;
                                });
                              },
                              icon: const Icon(Icons.close),
                            ),
                            const SizedBox(width: 6),
                            AppSendActionButton(
                              onPressed: _sendMessage,
                              isBusy: _isSending,
                              size: 40,
                            ),
                          ],
                        ),
                      ),
                    if (_isRecordingVoice)
                      Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: colors.surfaceMuted,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: colors.border),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _isRecordingLocked
                                  ? Icons.lock_clock_outlined
                                  : Icons.mic_rounded,
                              color: colors.brand,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _isRecordingLocked
                                        ? 'Recording $_recordDurationLabel '
                                        : 'Recording $_recordDurationLabel - slide left to cancel, up to lock',
                                    style: TextStyle(
                                      color: colors.textPrimary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  _VoiceWaveform(level: _recordLevel),
                                ],
                              ),
                            ),
                            if (_isRecordingLocked) ...[
                              IconButton(
                                onPressed: _cancelVoiceRecording,
                                icon: const Icon(Icons.delete_outline_rounded),
                              ),
                              IconButton(
                                onPressed: _stopVoiceRecording,
                                tooltip: 'Finish recording',
                                icon: const Icon(Icons.check_rounded),
                              ),
                            ],
                          ],
                        ),
                      ),
                    if (_selectedAudio != null || _isRecordingVoice)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Voice notes expire after 30 days.',
                            style: TextStyle(
                              color: colors.textMuted,
                              fontSize: 8,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (!(_isRecordingVoice || _selectedAudio != null)) ...[
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
                                focusNode: _composerFocusNode,
                                textCapitalization:
                                    TextCapitalization.sentences,
                                minLines: 1,
                                maxLines: null,
                                onTap: () {
                                  if (_showEmojiPicker) {
                                    setState(() {
                                      _showEmojiPicker = false;
                                    });
                                  }
                                  _scrollToBottomAnimated();
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
                        ],
                        Builder(
                          builder: (context) {
                            if (_isRecordingVoice || _selectedAudio != null) {
                              return const SizedBox.shrink();
                            }
                            final hasTypedText = _controller.text
                                .trim()
                                .isNotEmpty;
                            final hasPhoto = _selectedPhoto != null;
                            final hasAudio = _selectedAudio != null;
                            final shouldShowSend =
                                hasTypedText ||
                                hasPhoto ||
                                hasAudio ||
                                _editingMessage != null;
                            if (shouldShowSend) {
                              return AppSendActionButton(
                                onPressed: _sendMessage,
                                isBusy: _isSending,
                                size: 40,
                              );
                            }
                            return GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                unawaited(_startVoiceRecordingLocked());
                              },
                              onLongPress: () {
                                HapticFeedback.lightImpact();
                                unawaited(_startVoiceRecordingLocked());
                              },
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: colors.brand,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Icon(
                                  Icons.mic_none_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    if (_showEmojiPicker && !(_isRecordingVoice || _selectedAudio != null))
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

class _ThreadEmptyState extends StatelessWidget {
  const _ThreadEmptyState({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: colors.surfaceMuted,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colors.border),
              ),
              child: Icon(
                Icons.chat_bubble_outline_rounded,
                color: colors.textSecondary,
                size: 24,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textMuted,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReactionBar extends StatelessWidget {
  const _ReactionBar({required this.reactions, required this.onTapEmoji});

  final List<ChatReactionSummary> reactions;
  final Future<void> Function(String emoji) onTapEmoji;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final totalCount = reactions.fold<int>(
      0,
      (sum, reaction) => sum + reaction.count,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...reactions.map(
            (reaction) => Padding(
              padding: const EdgeInsets.only(right: 4),
              child: InkWell(
                onTap: () => onTapEmoji(reaction.emoji),
                borderRadius: BorderRadius.circular(999),
                child: Text(
                  reaction.emoji,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 2),
          Text(
            '$totalCount',
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
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
  bool _hasConversationDelta(
    ConversationListItem? previous,
    ConversationListItem next,
  ) {
    if (previous == null) return true;
    return previous.status != next.status ||
        previous.typingUserId != next.typingUserId ||
        previous.typingAt != next.typingAt ||
        previous.typingUserName != next.typingUserName ||
        previous.updatedAt != next.updatedAt ||
        previous.unreadCount != next.unreadCount ||
        previous.otherUser.isOnline != next.otherUser.isOnline ||
        previous.otherUser.lastSeen != next.otherUser.lastSeen;
  }

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

  int? _firstUnreadIndexFor(
    List<ChatMessage> messages,
    ConversationListItem? conversation,
  ) {
    final unreadCount = conversation?.unreadCount ?? 0;
    if (unreadCount <= 0 || messages.isEmpty) return null;
    var remaining = unreadCount;
    for (var index = messages.length - 1; index >= 0; index--) {
      final message = messages[index];
      final isMine = widget.currentUser != null
          ? message.senderId == widget.currentUser!.id
          : message.sender?.username != widget.username;
      if (isMine || message.id <= 0) {
        continue;
      }
      remaining -= 1;
      if (remaining <= 0) {
        return index;
      }
    }
    return null;
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
    if (incoming.isEmpty) {
      return existing;
    }
    if (existing.isEmpty) {
      return incoming;
    }

    final merged = <int, ChatMessage>{};
    for (final message in existing) {
      merged[message.id] = message;
    }
    for (final message in incoming) {
      final previous = merged[message.id];
      merged[message.id] = previous == null
          ? message
          : _mergeMessagePair(previous, message);
    }
    final incomingPersisted = incoming
        .where((message) => message.id > 0)
        .toList(growable: false);
    final pending = existing.where((message) => message.id < 0);
    for (final message in pending) {
      final matchedIncoming = incomingPersisted.any(
        (candidate) => _isSameLogicalMessage(message, candidate),
      );
      if (matchedIncoming) {
        continue;
      }
      merged.putIfAbsent(message.id, () => message);
    }
    final items = _dedupeById(merged.values.toList())
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

  List<ChatMessage> _dedupeById(List<ChatMessage> items) {
    final merged = <int, ChatMessage>{};
    for (final message in items) {
      final previous = merged[message.id];
      merged[message.id] = previous == null
          ? message
          : _mergeMessagePair(previous, message);
    }
    return merged.values.toList(growable: false);
  }

  void _scheduleDraftPersist(String rawText) {
    final nextDraft = rawText.trimRight();
    if (nextDraft == _lastPersistedDraft) {
      return;
    }
    _draftPersistDebounce?.cancel();
    _draftPersistDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) {
        return;
      }
      final latest = _controller.text.trimRight();
      if (latest == _lastPersistedDraft) {
        return;
      }
      _lastPersistedDraft = latest;
      unawaited(_persistDraft(latest));
    });
  }

  ChatMessage _mergeMessagePair(ChatMessage base, ChatMessage incoming) {
    final resolvedReplyId = incoming.replyId != 0 ? incoming.replyId : base.replyId;
    final resolvedReplyTo = incoming.replyTo ?? base.replyTo;
    final resolvedSender = incoming.sender ?? base.sender;
    final resolvedRecipient = incoming.recipient ?? base.recipient;
    final resolvedLocalImageBytes =
        incoming.localImageBytes ?? base.localImageBytes;

    if (resolvedReplyId == incoming.replyId &&
        identical(resolvedReplyTo, incoming.replyTo) &&
        identical(resolvedSender, incoming.sender) &&
        identical(resolvedRecipient, incoming.recipient) &&
        identical(resolvedLocalImageBytes, incoming.localImageBytes)) {
      return incoming;
    }

    return ChatMessage(
      id: incoming.id,
      conversationId: incoming.conversationId,
      senderId: incoming.senderId,
      recipientId: incoming.recipientId,
      message: incoming.message,
      photoUrl: incoming.photoUrl,
      audioUrl: incoming.audioUrl,
      isVoiceNote: incoming.isVoiceNote,
      voiceNoteExpired: incoming.voiceNoteExpired,
      audioDurationSeconds: incoming.audioDurationSeconds,
      audioMimeType: incoming.audioMimeType,
      audioSizeBytes: incoming.audioSizeBytes,
      replyId: resolvedReplyId,
      status: incoming.status,
      createdAt: incoming.createdAt,
      sender: resolvedSender,
      recipient: resolvedRecipient,
      replyTo: resolvedReplyTo,
      reactions: incoming.reactions,
      localImageBytes: resolvedLocalImageBytes,
    );
  }

  bool _isSameLogicalMessage(ChatMessage pending, ChatMessage persisted) {
    if (pending.id >= 0 || persisted.id <= 0) {
      return false;
    }

    final pendingText = pending.message.trim();
    final persistedText = persisted.message.trim();
    final pendingHasPhoto =
        (pending.localImageBytes != null) || pending.photoUrl.trim().isNotEmpty;
    final persistedHasPhoto = persisted.photoUrl.trim().isNotEmpty;
    final pendingHasAudio =
        pending.audioSizeBytes > 0 || pending.audioUrl.trim().isNotEmpty;
    final persistedHasAudio = persisted.audioUrl.trim().isNotEmpty;

    final pendingIsVoicePlaceholder =
        pendingHasAudio &&
        (pendingText.isEmpty ||
            pendingText.toLowerCase() == 'sent a voice note');
    final persistedIsVoicePlaceholder =
        persistedHasAudio &&
        (persistedText.isEmpty ||
            persistedText.toLowerCase() == 'sent a voice note');
    final pendingIsMediaPlaceholder =
        pendingHasPhoto && pendingText.isEmpty;
    final persistedIsMediaPlaceholder =
        persistedHasPhoto && persistedText.isEmpty;

    final shouldRelaxTextMatch =
        (pendingIsVoicePlaceholder && persistedIsVoicePlaceholder) ||
        (pendingIsMediaPlaceholder && persistedIsMediaPlaceholder);
    final sameText = shouldRelaxTextMatch || pendingText == persistedText;
    final sameSender = pending.senderId == persisted.senderId;
    final sameConversation =
        pending.conversationId > 0 &&
        pending.conversationId == persisted.conversationId;
    final sameRecipient = pending.recipientId == persisted.recipientId;
    final sameReplyTarget = pending.replyId == persisted.replyId;
    final samePhotoShape = pendingHasPhoto == persistedHasPhoto;
    final sameAudioShape = pendingHasAudio == persistedHasAudio;

    final pendingTime = DateTime.tryParse(pending.createdAt);
    final persistedTime = DateTime.tryParse(persisted.createdAt);
    final closeInTime = pendingTime != null && persistedTime != null
        ? pendingTime.difference(persistedTime).abs() <=
              const Duration(minutes: 2)
        : true;

    return sameText &&
        sameSender &&
        (sameConversation || sameRecipient) &&
        sameReplyTarget &&
        samePhotoShape &&
        sameAudioShape &&
        closeInTime;
  }
}

class _SwipeReplyWrapper extends StatefulWidget {
  const _SwipeReplyWrapper({required this.onReply, required this.child});

  final VoidCallback onReply;
  final Widget child;

  @override
  State<_SwipeReplyWrapper> createState() => _SwipeReplyWrapperState();
}

class _SwipeReplyWrapperState extends State<_SwipeReplyWrapper> {
  static const double _maxOffset = 72;
  static const double _triggerOffset = 52;
  static const Duration _resetDuration = Duration(milliseconds: 130);

  double _dragOffset = 0;
  bool _replyTriggered = false;

  void _handleHorizontalDragUpdate(DragUpdateDetails details) {
    final delta = details.primaryDelta ?? 0;
    if (delta <= 0 && _dragOffset <= 0) {
      return;
    }
    final nextOffset = (_dragOffset + delta).clamp(0.0, _maxOffset);
    if (nextOffset == _dragOffset) {
      return;
    }
    setState(() {
      _dragOffset = nextOffset;
    });
    if (!_replyTriggered && nextOffset >= _triggerOffset) {
      _replyTriggered = true;
      HapticFeedback.selectionClick();
      widget.onReply();
    }
  }

  void _resetSwipe() {
    if (_dragOffset == 0 && !_replyTriggered) {
      return;
    }
    setState(() {
      _dragOffset = 0;
      _replyTriggered = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final progress = (_dragOffset / _triggerOffset).clamp(0.0, 1.0);

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: _handleHorizontalDragUpdate,
      onHorizontalDragEnd: (_) => _resetSwipe(),
      onHorizontalDragCancel: _resetSwipe,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          Positioned(
            left: 8,
            child: Opacity(
              opacity: progress,
              child: Icon(Icons.reply_rounded, size: 18, color: colors.brand),
            ),
          ),
          AnimatedContainer(
            duration: _resetDuration,
            curve: Curves.easeOutCubic,
            transform: Matrix4.translationValues(_dragOffset, 0, 0),
            child: widget.child,
          ),
        ],
      ),
    );
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

class _InlineBubbleActionsBar extends StatelessWidget {
  const _InlineBubbleActionsBar({
    required this.hasText,
    required this.isMine,
    required this.onActionTap,
  });

  final bool hasText;
  final bool isMine;
  final Future<void> Function(String action) onActionTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final actionItems = <({
      IconData icon,
      String label,
      String action,
      Color? color,
    })>[
      (
        icon: Icons.reply_outlined,
        label: 'Reply',
        action: 'reply',
        color: colors.brand,
      ),
      if (hasText)
        (
          icon: Icons.content_copy_rounded,
          label: 'Copy',
          action: 'copy',
          color: null,
        ),
      if (isMine)
        (
          icon: Icons.edit_rounded,
          label: 'Edit',
          action: 'edit',
          color: null,
        ),
      if (isMine)
        (
          icon: Icons.delete_outline_rounded,
          label: 'Delete',
          action: 'delete',
          color: colors.dangerText,
        ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: colors.surfaceMuted.withValues(alpha: 0.92),
        border: Border(
          top: BorderSide(color: colors.border),
          bottom: BorderSide(color: colors.border),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (var i = 0; i < ReactionConfig.chatQuick.length; i++) ...[
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: i == ReactionConfig.chatQuick.length - 1 ? 0 : 6,
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: () => onActionTap('react:${ReactionConfig.chatQuick[i]}'),
                      child: Container(
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: colors.border),
                        ),
                        child: Text(
                          ReactionConfig.chatQuick[i],
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (var i = 0; i < actionItems.length; i++) ...[
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: i == actionItems.length - 1 ? 0 : 6,
                    ),
                    child: InkWell(
                      onTap: () => onActionTap(actionItems[i].action),
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: colors.border),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              actionItems[i].icon,
                              size: 14,
                              color: actionItems[i].color ?? colors.textSecondary,
                            ),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                actionItems[i].label,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color:
                                      actionItems[i].color ?? colors.textSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
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

class _VoiceTickerState {
  const _VoiceTickerState({
    this.position = Duration.zero,
    this.totalDuration = Duration.zero,
    this.playbackSpeed = 1.0,
  });

  final Duration position;
  final Duration totalDuration;
  final double playbackSpeed;

  _VoiceTickerState copyWith({
    Duration? position,
    Duration? totalDuration,
    double? playbackSpeed,
  }) {
    return _VoiceTickerState(
      position: position ?? this.position,
      totalDuration: totalDuration ?? this.totalDuration,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
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

class _VoiceWaveform extends StatelessWidget {
  const _VoiceWaveform({required this.level});

  final double level;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return SizedBox(
      height: 18,
      child: Row(
        children: List.generate(20, (index) {
          final t = (index + 1) / 20;
          final active = t <= (0.15 + (level * 0.85));
          final barHeight = 4 + (10 * (0.5 + (math.sin(index * 0.8) * 0.5)));
          return Padding(
            padding: const EdgeInsets.only(right: 2),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 90),
              width: 3,
              height: barHeight,
              decoration: BoxDecoration(
                color: active ? colors.brand : colors.border,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          );
        }),
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





