import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hopefulme_flutter/app/theme/app_theme.dart';
import 'package:hopefulme_flutter/core/config/app_config.dart';
import 'package:hopefulme_flutter/core/config/reaction_config.dart';
import 'package:hopefulme_flutter/core/utils/compact_count_formatter.dart';
import 'package:hopefulme_flutter/core/utils/time_formatter.dart';
import 'package:hopefulme_flutter/core/widgets/app_avatar.dart';
import 'package:hopefulme_flutter/core/widgets/app_network_image.dart';
import 'package:hopefulme_flutter/core/widgets/app_send_action_button.dart';
import 'package:hopefulme_flutter/core/widgets/app_status_state.dart';
import 'package:hopefulme_flutter/core/widgets/app_toast.dart';
import 'package:hopefulme_flutter/core/widgets/fullscreen_network_image_screen.dart';
import 'package:hopefulme_flutter/core/widgets/rich_display_text.dart';
import 'package:hopefulme_flutter/core/widgets/verified_name_text.dart';
import 'package:hopefulme_flutter/features/auth/models/user.dart';
import 'package:hopefulme_flutter/features/content/data/content_repository.dart';
import 'package:hopefulme_flutter/features/messages/data/message_repository.dart';
import 'package:hopefulme_flutter/features/profile/data/profile_repository.dart';
import 'package:hopefulme_flutter/features/profile/presentation/profile_navigation.dart';
import 'package:hopefulme_flutter/features/search/data/search_repository.dart';
import 'package:hopefulme_flutter/features/search/presentation/screens/search_screen.dart';
import 'package:hopefulme_flutter/features/updates/data/update_repository.dart';
import 'package:hopefulme_flutter/features/updates/models/update_detail.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateDetailResult {
  const UpdateDetailResult({
    required this.deleted,
    required this.shouldRefresh,
  });

  final bool deleted;
  final bool shouldRefresh;
}

class UpdateDetailScreen extends StatefulWidget {
  const UpdateDetailScreen({
    required this.updateId,
    this.initialDetail,
    required this.currentUser,
    required this.repository,
    this.contentRepository,
    required this.profileRepository,
    required this.messageRepository,
    this.searchRepository,
    this.initialLiked = false,
    this.autofocusComment = false,
    super.key,
  });

  final int updateId;
  final UpdateDetail? initialDetail;
  final User? currentUser;
  final UpdateRepository repository;
  final ContentRepository? contentRepository;
  final ProfileRepository profileRepository;
  final MessageRepository messageRepository;
  final SearchRepository? searchRepository;
  final bool initialLiked;
  final bool autofocusComment;

  @override
  State<UpdateDetailScreen> createState() => _UpdateDetailScreenState();
}

class _UpdateDetailScreenState extends State<UpdateDetailScreen>
    with SingleTickerProviderStateMixin {
  late Future<UpdateDetail> _future;
  late AnimationController _likeController;
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  Timer? _commentMentionDebounce;
  List<MentionSuggestion> _commentMentionSuggestions =
      const <MentionSuggestion>[];
  bool _commentMentionLoading = false;
  int _commentMentionRequestId = 0;
  int? _commentMentionStart;
  String _commentMentionQuery = '';
  bool _liked = false;
  bool _isSubmittingComment = false;
  bool _isLoadingMoreComments = false;
  bool _shouldRefresh = false;
  bool _didRequestInitialCommentFocus = false;
  final GlobalKey _likeTapTargetKey = GlobalKey();
  OverlayEntry? _reactionOverlayEntry;

  @override
  void initState() {
    super.initState();
    _liked = widget.initialDetail?.isLiked ?? widget.initialLiked;
    _future = _load().then((detail) {
      if (mounted) {
        setState(() {
          _liked = detail.isLiked;
        });
      } else {
        _liked = detail.isLiked;
      }
      return detail;
    });
    _likeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
      lowerBound: 1.0,
      upperBound: 1.12,
    )..value = 1;
    _commentController.addListener(_handleCommentChanged);
    _commentFocusNode.addListener(() {
      if (!_commentFocusNode.hasFocus && mounted) {
        setState(_clearCommentMentionState);
      }
    });
  }

  Future<UpdateDetail> _load({int commentPage = 1}) {
    return widget.repository.fetchUpdate(
      widget.updateId,
      commentPage: commentPage,
    );
  }

  void _maybeRequestInitialCommentFocus() {
    if (_didRequestInitialCommentFocus || !widget.autofocusComment) {
      return;
    }
    _didRequestInitialCommentFocus = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _commentFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _hideReactionOverlay();
    _commentMentionDebounce?.cancel();
    _likeController.dispose();
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  void _clearCommentMentionState() {
    _commentMentionDebounce?.cancel();
    _commentMentionSuggestions = const <MentionSuggestion>[];
    _commentMentionLoading = false;
    _commentMentionStart = null;
    _commentMentionQuery = '';
  }

  void _handleCommentChanged() {
    final token = _extractActiveMentionToken(_commentController.value);
    if (token == null || !_commentFocusNode.hasFocus) {
      if (_commentMentionLoading ||
          _commentMentionSuggestions.isNotEmpty ||
          _commentMentionStart != null) {
        setState(_clearCommentMentionState);
      }
      return;
    }

    _commentMentionStart = token.start;
    if (token.query == _commentMentionQuery &&
        (_commentMentionLoading || _commentMentionSuggestions.isNotEmpty)) {
      return;
    }
    _commentMentionQuery = token.query;
    _commentMentionDebounce?.cancel();
    _commentMentionDebounce = Timer(
      const Duration(milliseconds: 180),
      () async {
        final requestId = ++_commentMentionRequestId;
        if (mounted) {
          setState(() {
            _commentMentionLoading = true;
          });
        }

        try {
          final suggestions = await widget.repository.fetchMentionSuggestions(
            token.query,
            limit: token.query.isEmpty ? 4 : 6,
          );
          if (!mounted || requestId != _commentMentionRequestId) {
            return;
          }
          setState(() {
            _commentMentionSuggestions = suggestions;
            _commentMentionLoading = false;
          });
        } catch (_) {
          if (!mounted || requestId != _commentMentionRequestId) {
            return;
          }
          setState(() {
            _commentMentionSuggestions = const <MentionSuggestion>[];
            _commentMentionLoading = false;
          });
        }
      },
    );
  }

  _MentionToken? _extractActiveMentionToken(TextEditingValue value) {
    final cursor = value.selection.baseOffset;
    if (cursor < 0 || cursor > value.text.length) {
      return null;
    }

    final beforeCursor = value.text.substring(0, cursor);
    final match = RegExp(r'(^|\s)@([a-zA-Z0-9_-]*)$').firstMatch(beforeCursor);
    if (match == null) {
      return null;
    }

    final prefix = match.group(1) ?? '';
    final query = match.group(2) ?? '';
    final start = match.start + prefix.length;
    return _MentionToken(start: start, query: query);
  }

  void _insertCommentMention(MentionSuggestion suggestion) {
    final value = _commentController.value;
    final cursor = value.selection.baseOffset;
    final mentionStart = _commentMentionStart;
    if (cursor < 0 || mentionStart == null || mentionStart > cursor) {
      return;
    }

    final text = value.text;
    final replaced =
        '${text.substring(0, mentionStart)}@${suggestion.username} '
        '${text.substring(cursor)}';
    final nextOffset = mentionStart + suggestion.username.length + 2;
    _commentController.value = TextEditingValue(
      text: replaced,
      selection: TextSelection.collapsed(offset: nextOffset),
    );
    setState(_clearCommentMentionState);
    _commentFocusNode.requestFocus();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
    await _future;
  }

  Future<void> _handleLinkTap(String url) async {
    final normalized = url.startsWith('http://') || url.startsWith('https://')
        ? url
        : 'https://$url';
    final uri = Uri.tryParse(normalized);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.platformDefault);
    }
  }

  Future<void> _toggleLike(UpdateDetail detail) async {
    _hideReactionOverlay();
    final result = await widget.repository.toggleLike(detail.id);
    _shouldRefresh = true;
    _likeController
      ..forward()
      ..reverse();
    setState(() {
      _liked = result.liked;
      _future = Future.value(
        detail.copyWith(
          likesCount: result.count,
          isLiked: result.liked,
          myReaction: result.myReaction,
          reactionsPreview: result.reactionsPreview,
        ),
      );
    });
  }

  Future<void> _pickReaction(UpdateDetail detail) async {
    if (_reactionOverlayEntry != null) {
      _hideReactionOverlay();
      return;
    }
    final renderObject = _likeTapTargetKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox) {
      return;
    }
    final likeGlobalTopLeft = renderObject.localToGlobal(Offset.zero);
    final media = MediaQuery.of(context);
    final safeTop = media.padding.top + 8;
    final estimatedPickerHeight = 54.0;
    final estimatedGap = 8.0;
    final desiredTop =
        likeGlobalTopLeft.dy - estimatedPickerHeight - estimatedGap;
    final overlayTop = desiredTop < safeTop ? safeTop : desiredTop;
    final overlay = Overlay.of(context, rootOverlay: true);
    final entry = OverlayEntry(
      builder: (overlayContext) {
        return Material(
          type: MaterialType.transparency,
          child: Stack(
            children: [
              Positioned.fill(
                child: Listener(
                  behavior: HitTestBehavior.translucent,
                  onPointerDown: (_) => _hideReactionOverlay(),
                ),
              ),
              Positioned(
                top: overlayTop,
                left: 12,
                right: 12,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 170),
                    tween: Tween<double>(begin: 0.94, end: 1),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) {
                      return Opacity(
                        opacity: value.clamp(0, 1),
                        child: Transform.scale(scale: value, child: child),
                      );
                    },
                    child: _InlineReactionPicker(
                      onSelect: (emoji) => _submitReaction(detail, emoji),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
    _reactionOverlayEntry = entry;
    overlay.insert(entry);
  }

  void _hideReactionOverlay() {
    _reactionOverlayEntry?.remove();
    _reactionOverlayEntry = null;
  }

  Future<void> _submitReaction(UpdateDetail detail, String selected) async {
    final reaction = selected.trim();
    if (reaction.isEmpty) {
      return;
    }
    _hideReactionOverlay();
    final result = await widget.repository.toggleLike(
      detail.id,
      reaction: reaction,
    );
    _shouldRefresh = true;
    setState(() {
      _liked = result.liked;
      _future = Future.value(
        detail.copyWith(
          likesCount: result.count,
          isLiked: result.liked,
          myReaction: result.myReaction,
          reactionsPreview: result.reactionsPreview,
        ),
      );
    });
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (_reactionOverlayEntry != null) {
      _hideReactionOverlay();
    }
    return false;
  }

  Future<void> _submitComment(UpdateDetail detail) async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _isSubmittingComment) {
      return;
    }

    setState(() {
      _isSubmittingComment = true;
    });

    try {
      final comment = await widget.repository.addComment(
        updateId: detail.id,
        comment: text,
      );
      _shouldRefresh = true;
      _commentController.clear();
      _clearCommentMentionState();
      setState(() {
        _future = Future.value(
          detail.copyWith(
            commentsCount: detail.commentsCount + 1,
            commentsTotal: detail.commentsTotal + 1,
            comments: [comment, ...detail.comments],
          ),
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmittingComment = false;
        });
      }
    }
  }

  Future<void> _loadMoreComments(UpdateDetail detail) async {
    if (_isLoadingMoreComments || !detail.hasMoreComments) {
      return;
    }

    setState(() {
      _isLoadingMoreComments = true;
    });

    try {
      final nextPage = await _load(commentPage: detail.commentsCurrentPage + 1);
      if (!mounted) return;
      setState(() {
        _future = Future.value(
          detail.copyWith(
            comments: [...detail.comments, ...nextPage.comments],
            commentsCurrentPage: nextPage.commentsCurrentPage,
            commentsLastPage: nextPage.commentsLastPage,
            commentsTotal: nextPage.commentsTotal,
          ),
        );
      });
    } catch (error) {
      if (!mounted) return;
      AppToast.error(context, error);
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMoreComments = false;
        });
      }
    }
  }

  Future<void> _replyToComment(
    UpdateDetail detail,
    UpdateComment target,
  ) async {
    final pageContext = context;
    final replyText = await showModalBottomSheet<String>(
      context: pageContext,
      isScrollControlled: true,
      builder: (bottomSheetContext) =>
          _ReplyComposerSheet(repository: widget.repository),
    );

    if (replyText == null || replyText.trim().isEmpty) {
      return;
    }

    try {
      await widget.repository.addCommentReply(
        commentId: target.id,
        comment: replyText.trim(),
      );
      if (!mounted || !pageContext.mounted) {
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _future = widget.repository.fetchUpdate(widget.updateId);
          });
        }
      });
    } catch (error) {
      if (!mounted || !pageContext.mounted) {
        return;
      }
      AppToast.error(pageContext, error);
    }
  }

  Future<void> _shareUpdate(UpdateDetail detail) async {
    final baseUrl = AppConfig.fromEnvironment().webBaseUrl;
    final normalizedBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final url = '$normalizedBase/social/${detail.id}@${detail.user.username}';
    try {
      await Share.share(
        '${detail.user.displayName} shared an update on HopefulMe:\n$url',
        subject: 'HopefulMe Update',
      );
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: url));
      if (!mounted) return;
      AppToast.info(context, 'Update link copied to clipboard');
    }
  }

  Future<void> _editUpdate(UpdateDetail detail) async {
    String draft = detail.status;
    final updatedText = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Update'),
        content: TextFormField(
          initialValue: detail.status,
          maxLines: 6,
          onChanged: (value) => draft = value,
          decoration: const InputDecoration(hintText: 'Share your thoughts...'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, draft.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (updatedText == null ||
        updatedText.isEmpty ||
        updatedText == detail.status) {
      return;
    }

    try {
      await widget.repository.updateStatus(
        updateId: detail.id,
        status: updatedText,
      );
      if (!mounted) {
        return;
      }
      _shouldRefresh = true;
      await _refresh();
      if (!mounted) {
        return;
      }
      AppToast.success(context, 'Update edited successfully.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      AppToast.error(context, error);
    }
  }

  Future<void> _deleteUpdate(UpdateDetail detail) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete update?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) {
      return;
    }

    await widget.repository.deleteUpdate(detail.id);
    if (!mounted) return;
    Navigator.of(
      context,
    ).pop(const UpdateDetailResult(deleted: true, shouldRefresh: true));
  }

  void _close() {
    Navigator.of(
      context,
    ).pop(UpdateDetailResult(deleted: false, shouldRefresh: _shouldRefresh));
  }

  Future<void> _deleteComment(UpdateComment comment) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete comment?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) {
      return;
    }

    try {
      await widget.repository.deleteComment(comment.id);
      if (!mounted) return;
      setState(() {
        _future = widget.repository.fetchUpdate(widget.updateId);
      });
    } catch (error) {
      if (!mounted) return;
      AppToast.error(context, error);
    }
  }

  Future<void> _editComment(UpdateDetail detail, UpdateComment comment) async {
    String draft = comment.comment;
    final updatedText = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit comment'),
        content: TextFormField(
          initialValue: comment.comment,
          minLines: 2,
          maxLines: 6,
          autofocus: true,
          onChanged: (value) => draft = value,
          decoration: const InputDecoration(hintText: 'Update your comment...'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, draft.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (updatedText == null ||
        updatedText.isEmpty ||
        updatedText == comment.comment) {
      return;
    }

    try {
      final updated = await widget.repository.updateComment(
        commentId: comment.id,
        comment: updatedText,
      );
      if (!mounted) return;
      final merged = UpdateComment(
        id: updated.id,
        comment: updated.comment,
        createdAt: updated.createdAt.isNotEmpty
            ? updated.createdAt
            : comment.createdAt,
        user: updated.user,
        replies: updated.replies.isNotEmpty ? updated.replies : comment.replies,
      );
      setState(() {
        _future = Future<UpdateDetail>.value(
          detail.copyWith(
            comments: detail.comments
                .map((item) => item.id == comment.id ? merged : item)
                .toList(),
          ),
        );
      });
      _shouldRefresh = true;
      AppToast.success(context, 'Comment updated.');
    } catch (error) {
      if (!mounted) return;
      AppToast.error(context, error);
    }
  }

  Future<void> _openProfile(String username) async {
    await openUserProfile(
      context,
      profileRepository: widget.profileRepository,
      messageRepository: widget.messageRepository,
      updateRepository: widget.repository,
      currentUser: widget.currentUser,
      username: username,
    );
  }

  Future<void> _openFullImage(UpdateDetail detail, String imageUrl) {
    return FullscreenNetworkImageScreen.show(
      context,
      imageUrl: imageUrl,
      authorName: detail.user.displayName,
      authorUsername: detail.user.username,
    );
  }

  Future<void> _openSearchQuery(String query) {
    if (widget.searchRepository == null || widget.contentRepository == null) {
      return Future<void>.value();
    }
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => SearchScreen(
          repository: widget.searchRepository!,
          contentRepository: widget.contentRepository!,
          messageRepository: widget.messageRepository,
          profileRepository: widget.profileRepository,
          updateRepository: widget.repository,
          currentUser: widget.currentUser,
          initialQuery: query,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: _handleScrollNotification,
      child: FutureBuilder<UpdateDetail>(
        future: _future,
        builder: (context, snapshot) {
          final detail = snapshot.data;
          final isOwner =
              detail != null &&
              widget.currentUser?.username == detail.user.username;
          final isAdmin = widget.currentUser?.isAdmin == true;
          final canEdit =
              detail != null &&
              (isOwner || isAdmin) &&
              detail.type.trim().toLowerCase() == 'update';
          final canDelete = detail != null && (isOwner || isAdmin);

          return PopScope<Object?>(
            canPop: false,
            onPopInvokedWithResult: (didPop, result) {
              if (didPop) {
                return;
              }
              _close();
            },
            child: Scaffold(
              backgroundColor: context.appColors.scaffold,
              appBar: AppBar(
                backgroundColor: context.appColors.surface,
                surfaceTintColor: context.appColors.surface,
                leading: IconButton(
                  onPressed: _close,
                  icon: const Icon(Icons.arrow_back),
                ),
                // title: const Text('Update'),
                actions: [
                  if (detail != null)
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_horiz),
                      onSelected: (value) {
                        WidgetsBinding.instance.addPostFrameCallback((_) async {
                          if (!mounted) {
                            return;
                          }
                          switch (value) {
                            case 'share':
                              await _shareUpdate(detail);
                              break;
                            case 'edit':
                              await _editUpdate(detail);
                              break;
                            case 'delete':
                              await _deleteUpdate(detail);
                              break;
                          }
                        });
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'share',
                          child: Text('Share To...'),
                        ),
                        if (canEdit)
                          const PopupMenuItem(
                            value: 'edit',
                            child: Text('Edit Update'),
                          ),
                        if (canDelete)
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete Update'),
                          ),
                      ],
                    ),
                ],
              ),
              body: Builder(
                builder: (context) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError && !snapshot.hasData) {
                    return AppStatusState.fromError(
                      error: snapshot.error ?? 'Unable to load this update.',
                      actionLabel: 'Try again',
                      onAction: _refresh,
                    );
                  }

                  if (detail == null) {
                    return const SizedBox.shrink();
                  }
                  _maybeRequestInitialCommentFocus();

                  final colors = context.appColors;
                  final isGeneratedActivity =
                      detail.type.trim().toLowerCase() != 'update';

                  return RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: colors.surface,
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(color: colors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  18,
                                  18,
                                  18,
                                  12,
                                ),
                                child: Row(
                                  children: [
                                    InkWell(
                                      onTap: () =>
                                          _openProfile(detail.user.username),
                                      borderRadius: BorderRadius.circular(999),
                                      child: AppAvatar(
                                        imageUrl: detail.user.photoUrl,
                                        label: detail.user.displayName,
                                        radius: 22,
                                        size: 66,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: InkWell(
                                        onTap: () =>
                                            _openProfile(detail.user.username),
                                        borderRadius: BorderRadius.circular(10),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            VerifiedNameText(
                                              name: detail.user.displayName,
                                              verified: detail.user.isVerified,
                                              style: TextStyle(
                                                color: colors.textPrimary,
                                                fontSize: 15,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              detail.device.isNotEmpty
                                                  ? '${formatRelativeTimestamp(detail.createdAt)} · ${detail.device}'
                                                  : formatRelativeTimestamp(
                                                      detail.createdAt,
                                                    ),
                                              style: TextStyle(
                                                color: colors.textMuted,
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
                              if (detail.status.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    18,
                                    0,
                                    18,
                                    12,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      RichDisplayText(
                                        text: detail.status,
                                        style: TextStyle(
                                          color: isGeneratedActivity
                                              ? colors.textMuted.withValues(
                                                  alpha: 0.82,
                                                )
                                              : colors.textSecondary,
                                          fontSize: isGeneratedActivity
                                              ? 12.5
                                              : 13.75,
                                          height: 1.62,
                                          fontWeight: isGeneratedActivity
                                              ? FontWeight.w500
                                              : FontWeight.w500,
                                        ),
                                        onMentionTap: _openProfile,
                                        onHashtagTap: _openSearchQuery,
                                        onLinkTap: _handleLinkTap,
                                      ),
                                    ],
                                  ),
                                ),
                              if (detail.photoUrl.isNotEmpty)
                                InkWell(
                                  onTap: () => _openFullImage(
                                    detail,
                                    detail.originalPhotoUrl.isNotEmpty
                                        ? detail.originalPhotoUrl
                                        : detail.photoUrl,
                                  ),
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      minHeight: 260,
                                      maxHeight:
                                          MediaQuery.of(context).size.height *
                                          0.58,
                                    ),
                                    child: SizedBox(
                                      width: double.infinity,
                                      child: AppNetworkImage(
                                        imageUrl:
                                            detail.originalPhotoUrl.isNotEmpty
                                            ? detail.originalPhotoUrl
                                            : detail.photoUrl,
                                        fit: BoxFit.cover,
                                        backgroundColor: colors.surfaceMuted,
                                        placeholderLabel:
                                            detail.user.displayName,
                                      ),
                                    ),
                                  ),
                                ),
                              Container(
                                padding: const EdgeInsets.fromLTRB(10, 6, 5, 8),
                                decoration: BoxDecoration(
                                  border: Border(
                                    top: BorderSide(color: colors.border),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    KeyedSubtree(
                                      key: _likeTapTargetKey,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(16),
                                        onTap: () => _toggleLike(detail),
                                        onLongPress: () =>
                                            _pickReaction(detail),
                                        child: ScaleTransition(
                                          scale: _likeController,
                                          child: _DetailActionPill(
                                            icon: _liked
                                                ? Icons.favorite
                                                : Icons.favorite_border,
                                            iconFill: _liked ? 1 : 0,
                                            label: formatCompactCount(
                                              detail.likesCount,
                                            ),
                                            iconSize: 23,
                                            color: _liked
                                                ? const Color(0xFFe84242)
                                                : colors.icon,
                                            background: const Color(0xFFFFF7F6),
                                            darkBackground: const Color(
                                              0x221A1618,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    InkWell(
                                      borderRadius: BorderRadius.circular(16),
                                      onTap: () =>
                                          _commentFocusNode.requestFocus(),
                                      child: _DetailActionPill(
                                        icon: Icons.chat_bubble_outline,
                                        label: formatCompactCount(
                                          detail.commentsCount,
                                        ),
                                        iconSize: 22,
                                        color: colors.icon,
                                        background: const Color(0x00000000),
                                      ),
                                    ),
                                    const Spacer(),
                                    if (detail.reactionsPreview.isNotEmpty)
                                      Container(
                                        margin: const EdgeInsets.only(right: 8),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 7,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: colors.surfaceMuted,
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                          border: Border.all(
                                            color: colors.border,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            ...detail.reactionsPreview
                                                .take(
                                                  ReactionConfig
                                                      .updatePreviewMax,
                                                )
                                                .map(
                                                  (emoji) => Padding(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 2,
                                                        ),
                                                    child: Text(
                                                      emoji,
                                                      style: const TextStyle(
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                            if (detail.reactionsPreview.length >
                                                ReactionConfig.updatePreviewMax)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  left: 3,
                                                ),
                                                child: Text(
                                                  '+${detail.reactionsPreview.length - ReactionConfig.updatePreviewMax}',
                                                  style: TextStyle(
                                                    color: colors.textMuted,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    InkWell(
                                      borderRadius: BorderRadius.circular(16),
                                      onTap: () => _shareUpdate(detail),
                                      child: _DetailActionPill(
                                        icon: Icons.ios_share_outlined,
                                        color: colors.icon,
                                        background: const Color(0x00000000),
                                        iconSize: 18,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: colors.surface,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: colors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Comments',
                                style: TextStyle(
                                  color: colors.textPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _commentController,
                                      focusNode: _commentFocusNode,
                                      minLines: 1,
                                      maxLines: 3,
                                      decoration: InputDecoration(
                                        hintText: 'Enter comment...',
                                        filled: true,
                                        fillColor: colors.surfaceMuted,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          borderSide: BorderSide.none,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  AppSendActionButton(
                                    onPressed: _isSubmittingComment
                                        ? null
                                        : () => _submitComment(detail),
                                    isBusy: _isSubmittingComment,
                                  ),
                                ],
                              ),
                              if (_commentMentionLoading ||
                                  _commentMentionSuggestions.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                _MentionSuggestionList(
                                  suggestions: _commentMentionSuggestions,
                                  isLoading: _commentMentionLoading,
                                  onTapSuggestion: _insertCommentMention,
                                ),
                              ],
                              const SizedBox(height: 16),
                              if (detail.comments.isEmpty)
                                Text(
                                  'No comments yet.',
                                  style: TextStyle(color: colors.textMuted),
                                )
                              else
                                ...detail.comments.map(
                                  (comment) => Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: _CommentTile(
                                      comment: comment,
                                      onProfileTap: () =>
                                          _openProfile(comment.user.username),
                                      onMentionTap: _openProfile,
                                      onHashtagTap: _openSearchQuery,
                                      onLinkTap: _handleLinkTap,
                                      onReplyTap: () =>
                                          _replyToComment(detail, comment),
                                      onEdit: () =>
                                          _editComment(detail, comment),
                                      onDelete: () => _deleteComment(comment),
                                      isOwner:
                                          widget.currentUser?.id ==
                                          comment.user.id,
                                    ),
                                  ),
                                ),
                              if (detail.hasMoreComments) ...[
                                const SizedBox(height: 4),
                                Center(
                                  child: TextButton(
                                    onPressed: _isLoadingMoreComments
                                        ? null
                                        : () => _loadMoreComments(detail),
                                    child: Text(
                                      _isLoadingMoreComments
                                          ? 'Loading comments...'
                                          : 'Load more comments',
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DetailActionPill extends StatelessWidget {
  const _DetailActionPill({
    required this.icon,
    required this.color,
    required this.background,
    this.darkBackground,
    this.label,
    this.iconFill,
    this.iconSize = 17,
  });

  final IconData icon;
  final String? label;
  final Color color;
  final Color background;
  final Color? darkBackground;
  final double? iconFill;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLikePill = icon == Icons.favorite || icon == Icons.favorite_border;
    final hasLikeBg = isLikePill && iconFill != null && iconFill! > 0;
    final effectiveLightBackground = hasLikeBg
        ? background
        : Colors.transparent;
    final effectiveDarkBackground = hasLikeBg
        ? Colors.transparent
        : Colors.transparent;
    final effectiveBorder = isDark && hasLikeBg
        ? Border.all(color: color.withValues(alpha: 0.26), width: 0.75)
        : null;
    final horizontalPadding = isLikePill ? 10.0 : 12.0;
    final verticalPadding = isLikePill ? 6.0 : 8.0;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      decoration: BoxDecoration(
        color: isDark ? effectiveDarkBackground : effectiveLightBackground,
        borderRadius: BorderRadius.circular(16),
        border: effectiveBorder,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: iconSize, color: color, fill: iconFill),
          if (label != null) ...[
            const SizedBox(width: 6),
            Text(
              label!,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReplyComposerSheet extends StatefulWidget {
  const _ReplyComposerSheet({required this.repository});

  final UpdateRepository repository;

  @override
  State<_ReplyComposerSheet> createState() => _ReplyComposerSheetState();
}

class _ReplyComposerSheetState extends State<_ReplyComposerSheet> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _mentionDebounce;
  List<MentionSuggestion> _suggestions = const <MentionSuggestion>[];
  bool _loading = false;
  int _requestId = 0;
  int? _mentionStart;
  String _mentionQuery = '';

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleTextChanged);
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _mentionDebounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _clearMentionState() {
    _mentionDebounce?.cancel();
    _loading = false;
    _suggestions = const <MentionSuggestion>[];
    _mentionStart = null;
    _mentionQuery = '';
  }

  void _handleTextChanged() {
    final token = _extractToken(_controller.value);
    if (token == null) {
      if (_loading || _suggestions.isNotEmpty || _mentionStart != null) {
        setState(_clearMentionState);
      }
      return;
    }

    _mentionStart = token.start;
    if (token.query == _mentionQuery && (_loading || _suggestions.isNotEmpty)) {
      return;
    }
    _mentionQuery = token.query;
    _mentionDebounce?.cancel();
    _mentionDebounce = Timer(const Duration(milliseconds: 180), () async {
      final requestId = ++_requestId;
      if (mounted) {
        setState(() {
          _loading = true;
        });
      }

      try {
        final suggestions = await widget.repository.fetchMentionSuggestions(
          token.query,
          limit: token.query.isEmpty ? 4 : 6,
        );
        if (!mounted || requestId != _requestId) {
          return;
        }
        setState(() {
          _suggestions = suggestions;
          _loading = false;
        });
      } catch (_) {
        if (!mounted || requestId != _requestId) {
          return;
        }
        setState(() {
          _suggestions = const <MentionSuggestion>[];
          _loading = false;
        });
      }
    });
  }

  _MentionToken? _extractToken(TextEditingValue value) {
    final cursor = value.selection.baseOffset;
    if (cursor < 0 || cursor > value.text.length) {
      return null;
    }

    final beforeCursor = value.text.substring(0, cursor);
    final match = RegExp(r'(^|\s)@([a-zA-Z0-9_-]*)$').firstMatch(beforeCursor);
    if (match == null) {
      return null;
    }

    final prefix = match.group(1) ?? '';
    final query = match.group(2) ?? '';
    final start = match.start + prefix.length;
    return _MentionToken(start: start, query: query);
  }

  void _insertMention(MentionSuggestion suggestion) {
    final value = _controller.value;
    final cursor = value.selection.baseOffset;
    final start = _mentionStart;
    if (cursor < 0 || start == null || start > cursor) {
      return;
    }

    final text = value.text;
    final replaced =
        '${text.substring(0, start)}@${suggestion.username} '
        '${text.substring(cursor)}';
    final nextOffset = start + suggestion.username.length + 2;
    _controller.value = TextEditingValue(
      text: replaced,
      selection: TextSelection.collapsed(offset: nextOffset),
    );
    setState(_clearMentionState);
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        18,
        16,
        MediaQuery.of(context).viewInsets.bottom + 18,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Reply',
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            focusNode: _focusNode,
            minLines: 2,
            maxLines: 5,
            decoration: const InputDecoration(
              hintText: 'Write your reply...  (Type @ to mention)',
            ),
          ),
          if (_loading || _suggestions.isNotEmpty) ...[
            const SizedBox(height: 10),
            _MentionSuggestionList(
              suggestions: _suggestions,
              isLoading: _loading,
              onTapSuggestion: _insertMention,
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(_controller.text.trim()),
              child: const Text('Send reply'),
            ),
          ),
        ],
      ),
    );
  }
}

class _MentionSuggestionList extends StatelessWidget {
  const _MentionSuggestionList({
    required this.suggestions,
    required this.isLoading,
    required this.onTapSuggestion,
  });

  final List<MentionSuggestion> suggestions;
  final bool isLoading;
  final ValueChanged<MentionSuggestion> onTapSuggestion;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      constraints: const BoxConstraints(maxHeight: 220),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: isLoading
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colors.brand,
                  ),
                ),
              ),
            )
          : ListView.separated(
              shrinkWrap: true,
              itemCount: suggestions.length,
              separatorBuilder: (_, _) => Divider(
                height: 1,
                color: colors.border.withValues(alpha: 0.6),
              ),
              itemBuilder: (context, index) {
                final item = suggestions[index];
                return InkWell(
                  onTap: () => onTapSuggestion(item),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 9,
                    ),
                    child: Row(
                      children: [
                        AppAvatar(
                          imageUrl: item.photoUrl,
                          label: item.fullname,
                          radius: 15,
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      item.fullname.trim().isEmpty
                                          ? item.username
                                          : item.fullname,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: colors.textPrimary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  if (item.isVerified) ...[
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.verified_rounded,
                                      size: 14,
                                      color: colors.brand,
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '@${item.username}',
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
                  ),
                );
              },
            ),
    );
  }
}

class _MentionToken {
  const _MentionToken({required this.start, required this.query});

  final int start;
  final String query;
}

class _InlineReactionPicker extends StatelessWidget {
  const _InlineReactionPicker({required this.onSelect});

  final Future<void> Function(String emoji) onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? colors.surface : Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.10),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: ReactionConfig.updateQuick.map((emoji) {
          return InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () => onSelect(emoji),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Text(emoji, style: const TextStyle(fontSize: 24)),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({
    required this.comment,
    required this.onProfileTap,
    required this.onMentionTap,
    required this.onHashtagTap,
    required this.onLinkTap,
    required this.onReplyTap,
    required this.onEdit,
    required this.onDelete,
    required this.isOwner,
  });

  final UpdateComment comment;
  final VoidCallback onProfileTap;
  final Future<void> Function(String username) onMentionTap;
  final Future<void> Function(String hashtag) onHashtagTap;
  final Future<void> Function(String url) onLinkTap;
  final VoidCallback onReplyTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool isOwner;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final commentTimestamp = formatRelativeTimestamp(comment.createdAt);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onProfileTap,
          borderRadius: BorderRadius.circular(999),
          child: AppAvatar(
            imageUrl: comment.user.photoUrl,
            label: comment.user.displayName,
            radius: 18,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.surfaceMuted,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: onProfileTap,
                        borderRadius: BorderRadius.circular(8),
                        child: VerifiedNameText(
                          name: comment.user.displayName,
                          verified: comment.user.isVerified,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    if (isOwner)
                      PopupMenuButton<String>(
                        icon: Icon(
                          Icons.more_vert,
                          size: 18,
                          color: colors.textMuted,
                        ),
                        onSelected: (value) {
                          if (value == 'edit') {
                            onEdit();
                          }
                          if (value == 'delete') {
                            onDelete();
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit_outlined, size: 18),
                                SizedBox(width: 8),
                                Text('Edit'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline, size: 18),
                                SizedBox(width: 8),
                                Text('Delete'),
                              ],
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                if (commentTimestamp.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    commentTimestamp,
                    style: TextStyle(
                      color: colors.textMuted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                RichDisplayText(
                  text: comment.comment,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 13.5,
                    height: 1.45,
                  ),
                  onMentionTap: onMentionTap,
                  onHashtagTap: onHashtagTap,
                  onLinkTap: onLinkTap,
                ),
                const SizedBox(height: 10),
                InkWell(
                  onTap: onReplyTap,
                  borderRadius: BorderRadius.circular(8),
                  child: Text(
                    'Reply',
                    style: TextStyle(
                      color: colors.brand,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (comment.replies.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ...comment.replies.map(
                    (reply) => Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: _ReplyTile(
                        reply: reply,
                        onMentionTap: onMentionTap,
                        onHashtagTap: onHashtagTap,
                        onLinkTap: onLinkTap,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ReplyTile extends StatelessWidget {
  const _ReplyTile({
    required this.reply,
    required this.onMentionTap,
    required this.onHashtagTap,
    required this.onLinkTap,
  });

  final UpdateCommentReply reply;
  final Future<void> Function(String username) onMentionTap;
  final Future<void> Function(String hashtag) onHashtagTap;
  final Future<void> Function(String url) onLinkTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final replyTimestamp = formatRelativeTimestamp(reply.createdAt);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          VerifiedNameText(
            name: reply.user.displayName,
            verified: reply.user.isVerified,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (replyTimestamp.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              replyTimestamp,
              style: TextStyle(
                color: colors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: 5),
          RichDisplayText(
            text: reply.comment,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 12.5,
              height: 1.45,
            ),
            onMentionTap: onMentionTap,
            onHashtagTap: onHashtagTap,
            onLinkTap: onLinkTap,
          ),
        ],
      ),
    );
  }
}
