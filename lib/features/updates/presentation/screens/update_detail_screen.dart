import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hopefulme_flutter/app/theme/app_theme.dart';
import 'package:hopefulme_flutter/core/config/app_config.dart';
import 'package:hopefulme_flutter/core/config/reaction_config.dart';
import 'package:hopefulme_flutter/core/network/image_url_resolver.dart';
import 'package:hopefulme_flutter/core/utils/compact_count_formatter.dart';
import 'package:hopefulme_flutter/core/utils/time_formatter.dart';
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
  bool _liked = false;
  bool _isSubmittingComment = false;
  bool _isLoadingMoreComments = false;
  bool _shouldRefresh = false;
  bool _didRequestInitialCommentFocus = false;

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
      lowerBound: 0.9,
      upperBound: 1.15,
    )..value = 1;
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
    _likeController.dispose();
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
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
    final defaultReaction =
        detail.myReaction?.trim().isNotEmpty == true ? detail.myReaction!.trim() : '\u2764\uFE0F';
    final result = _liked
        ? await widget.repository.toggleLike(detail.id)
        : await widget.repository.toggleLike(
            detail.id,
            reaction: defaultReaction,
          );
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
    final selected = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (sheetContext) {
        final colors = sheetContext.appColors;
        final isDark = Theme.of(sheetContext).brightness == Brightness.dark;
        return Dialog(
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 26),
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? colors.surface : Colors.white,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: colors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.24 : 0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: ReactionConfig.updateQuick
                  .map(
                    (emoji) => InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: () => Navigator.of(sheetContext).pop(emoji),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 4,
                        ),
                        child: Text(emoji, style: const TextStyle(fontSize: 24)),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        );
      },
    );

    if (selected == null || selected.trim().isEmpty) {
      return;
    }

    final result = await widget.repository.toggleLike(
      detail.id,
      reaction: selected,
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
    final controller = TextEditingController();
    final replyText = await showModalBottomSheet<String>(
      context: pageContext,
      isScrollControlled: true,
      builder: (bottomSheetContext) {
        final colors = bottomSheetContext.appColors;
        return Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            18,
            16,
            MediaQuery.of(bottomSheetContext).viewInsets.bottom + 18,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Reply',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                minLines: 2,
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText: 'Write your reply...',
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(
                    bottomSheetContext,
                  ).pop(controller.text.trim()),
                  child: const Text('Send reply'),
                ),
              ),
            ],
          ),
        );
      },
    );
    controller.dispose();

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
    final controller = TextEditingController(text: detail.status);
    final updatedText = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Update'),
        content: TextField(
          controller: controller,
          maxLines: 6,
          decoration: const InputDecoration(hintText: 'Share your thoughts...'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (updatedText == null || updatedText.isEmpty) {
      return;
    }

    final updated = await widget.repository.updateStatus(
      updateId: detail.id,
      status: updatedText,
    );
    _shouldRefresh = true;
    setState(() {
      _future = Future.value(updated);
    });
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

  Future<void> _openFullImage(String imageUrl) {
    return FullscreenNetworkImageScreen.show(context, imageUrl: imageUrl);
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
    return FutureBuilder<UpdateDetail>(
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
                    onSelected: (value) async {
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
                                    child: CircleAvatar(
                                      radius: 22,
                                      backgroundImage:
                                          detail.user.photoUrl.isNotEmpty
                                          ? NetworkImage(
                                              ImageUrlResolver.avatar(
                                                detail.user.photoUrl,
                                                size: 66,
                                              ),
                                            )
                                          : null,
                                      child: detail.user.photoUrl.isEmpty
                                          ? const Icon(Icons.person)
                                          : null,
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                      placeholderLabel: detail.user.displayName,
                                    ),
                                  ),
                                ),
                              ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                18,
                                14,
                                18,
                                16,
                              ),
                              child: Row(
                                children: [
                                  InkWell(
                                    borderRadius: BorderRadius.circular(16),
                                    onTap: () => _toggleLike(detail),
                                    onLongPress: () => _pickReaction(detail),
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
                                        color: _liked
                                            ? const Color(0xFFFF4D6D)
                                            : colors.icon,
                                        background: const Color(0xFFFFF1F4),
                                        darkBackground: const Color(
                                          0x221A1618,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  InkWell(
                                    borderRadius: BorderRadius.circular(16),
                                    onTap: () => _commentFocusNode.requestFocus(),
                                    child: _DetailActionPill(
                                      icon: Icons.chat_bubble_outline,
                                      label: formatCompactCount(
                                        detail.commentsCount,
                                      ),
                                      color: colors.icon,
                                      background: const Color(0x00000000),
                                    ),
                                  ),
                                  InkWell(
                                    borderRadius: BorderRadius.circular(16),
                                    onTap: () => _shareUpdate(detail),
                                    child: _DetailActionPill(
                                      icon: Icons.ios_share_outlined,
                                      color: colors.icon,
                                      background: const Color(0x00000000),
                                      iconSize: 16.5,
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
                                        borderRadius: BorderRadius.circular(999),
                                        border: Border.all(color: colors.border),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          ...detail.reactionsPreview
                                              .take(
                                                ReactionConfig.updatePreviewMax,
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
                                                      fontSize: 13,
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
                                  const SizedBox(width: 8),
                                  Text(
                                    '${formatCompactCount(detail.views)} views',
                                    style: TextStyle(
                                      color: colors.textMuted,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
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
                                fontSize: 17,
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
                                        borderRadius: BorderRadius.circular(16),
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
    final effectiveLightBackground = hasLikeBg ? background : Colors.transparent;
    final effectiveDarkBackground = hasLikeBg
        ? (darkBackground ?? Colors.transparent)
        : Colors.transparent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? effectiveDarkBackground : effectiveLightBackground,
        borderRadius: BorderRadius.circular(16),
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

class _CommentTile extends StatelessWidget {
  const _CommentTile({
    required this.comment,
    required this.onProfileTap,
    required this.onMentionTap,
    required this.onHashtagTap,
    required this.onLinkTap,
    required this.onReplyTap,
    required this.onDelete,
    required this.isOwner,
  });

  final UpdateComment comment;
  final VoidCallback onProfileTap;
  final Future<void> Function(String username) onMentionTap;
  final Future<void> Function(String hashtag) onHashtagTap;
  final Future<void> Function(String url) onLinkTap;
  final VoidCallback onReplyTap;
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
          child: CircleAvatar(
            radius: 18,
            backgroundImage: comment.user.photoUrl.isNotEmpty
                ? NetworkImage(
                    ImageUrlResolver.avatar(comment.user.photoUrl, size: 56),
                  )
                : null,
            child: comment.user.photoUrl.isEmpty
                ? const Icon(Icons.person)
                : null,
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
                          if (value == 'delete') {
                            onDelete();
                          }
                        },
                        itemBuilder: (context) => [
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
