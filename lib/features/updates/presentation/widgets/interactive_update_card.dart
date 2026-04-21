import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:hopefulme_flutter/core/config/app_config.dart';
import 'package:hopefulme_flutter/app/theme/app_theme.dart';
import 'package:hopefulme_flutter/core/utils/time_formatter.dart';
import 'package:hopefulme_flutter/core/widgets/app_toast.dart';
import 'package:hopefulme_flutter/core/widgets/fullscreen_network_image_screen.dart';
import 'package:hopefulme_flutter/features/auth/models/user.dart';
import 'package:hopefulme_flutter/features/updates/data/update_repository.dart';
import 'package:hopefulme_flutter/features/updates/presentation/widgets/update_card.dart';

class InteractiveUpdateCard extends StatefulWidget {
  const InteractiveUpdateCard({
    required this.updateId,
    required this.updateType,
    required this.title,
    required this.body,
    required this.photoUrl,
    required this.avatarUrl,
    required this.fallbackLabel,
    required this.device,
    required this.createdAt,
    required this.likesCount,
    required this.commentsCount,
    required this.views,
    required this.updateRepository,
    required this.onOpenUpdate,
    this.currentUser,
    this.ownerUsername,
    this.onOpenProfile,
    this.onOpenHashtag,
    this.onOpenLink,
    this.isVerified = false,
    this.isLiked = false,
    super.key,
  });

  final int updateId;
  final String updateType;
  final String title;
  final String body;
  final String photoUrl;
  final String avatarUrl;
  final String fallbackLabel;
  final String device;
  final bool isVerified;
  final String createdAt;
  final int likesCount;
  final int commentsCount;
  final int views;
  final UpdateRepository updateRepository;
  final Future<void> Function() onOpenUpdate;
  final User? currentUser;
  final String? ownerUsername;
  final Future<void> Function(String username)? onOpenProfile;
  final Future<void> Function(String hashtag)? onOpenHashtag;
  final Future<void> Function(String url)? onOpenLink;
  final bool isLiked;

  @override
  State<InteractiveUpdateCard> createState() => _InteractiveUpdateCardState();
}

class _InteractiveUpdateCardState extends State<InteractiveUpdateCard>
    with SingleTickerProviderStateMixin {
  late int _likesCount;
  late int _commentsCount;
  late String _body;
  final TextEditingController _inlineCommentController =
      TextEditingController();
  final FocusNode _inlineCommentFocusNode = FocusNode();
  bool _liked = false;
  bool _busy = false;
  bool _isDeleted = false;
  bool _showInlineCommentComposer = false;
  bool _isSubmittingInlineComment = false;
  late AnimationController _likeController;

  bool get _isOwner => widget.currentUser?.username == widget.ownerUsername;
  bool get _canEdit =>
      _isOwner && widget.updateType.trim().toLowerCase() == 'update';

  @override
  void initState() {
    super.initState();
    _likesCount = widget.likesCount;
    _commentsCount = widget.commentsCount;
    _body = widget.body;
    _liked = widget.isLiked; // ✅ init from backend
    _likeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      lowerBound: 0.9,
      upperBound: 1.15,
    )..value = 1;
  }

  @override
  void dispose() {
    _inlineCommentController.dispose();
    _inlineCommentFocusNode.dispose();
    _likeController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant InteractiveUpdateCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    final updateChanged = oldWidget.updateId != widget.updateId;
    final bodyChanged = oldWidget.body != widget.body;
    final likesChanged = oldWidget.likesCount != widget.likesCount;
    final commentsChanged = oldWidget.commentsCount != widget.commentsCount;
    final likedChanged = oldWidget.isLiked != widget.isLiked;

    if (updateChanged ||
        bodyChanged ||
        likesChanged ||
        commentsChanged ||
        likedChanged) {
      _body = widget.body;
      _likesCount = widget.likesCount;
      _commentsCount = widget.commentsCount;
      _liked = widget.isLiked; // ✅ restore from backend on refresh
      _isDeleted = false;
      _showInlineCommentComposer = false;
      _isSubmittingInlineComment = false;
      _inlineCommentController.clear();
      _inlineCommentFocusNode.unfocus();
    }
  }

  Future<void> _toggleLike() async {
    if (_busy) return;
    setState(() {
      _busy = true;
    });
    try {
      final result = await widget.updateRepository.toggleLike(widget.updateId);
      _likeController
        ..forward()
        ..reverse();
      if (!mounted) return;
      setState(() {
        _liked = result.liked;
        _likesCount = result.count;
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _editUpdate() async {
    final controller = TextEditingController(text: _body);
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

    if (updatedText == null || updatedText.isEmpty || updatedText == _body) {
      return;
    }

    setState(() {
      _busy = true;
    });

    try {
      final updated = await widget.updateRepository.updateStatus(
        updateId: widget.updateId,
        status: updatedText,
      );
      if (!mounted) return;
      setState(() {
        _body = updated.status;
      });
      AppToast.success(context, 'Update edited successfully.');
    } catch (error) {
      if (!mounted) return;
      AppToast.error(context, error);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _deleteUpdate() async {
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

    if (confirm != true) return;

    setState(() {
      _busy = true;
    });

    try {
      await widget.updateRepository.deleteUpdate(widget.updateId);
      if (!mounted) return;
      setState(() {
        _isDeleted = true;
      });
      AppToast.success(context, 'Update deleted.');
    } catch (error) {
      if (!mounted) return;
      AppToast.error(context, error);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _openFullImage() async {
    final imageUrl = widget.photoUrl.trim();
    if (imageUrl.isEmpty) {
      await widget.onOpenUpdate();
      return;
    }

    await FullscreenNetworkImageScreen.show(
      context,
      imageUrl: imageUrl,
      primaryActionLabel: 'View Post',
      onPrimaryAction: widget.onOpenUpdate,
    );
  }

  Future<void> _shareUpdate() async {
    final baseUrl = AppConfig.fromEnvironment().webBaseUrl;
    final normalizedBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final username = widget.ownerUsername?.trim() ?? '';
    final url = username.isNotEmpty
        ? '$normalizedBase/social/${widget.updateId}@$username'
        : '$normalizedBase/social/${widget.updateId}';
    final headline = widget.title.trim().isEmpty
        ? 'HopefulMe update'
        : widget.title.trim();

    try {
      await Share.share('$headline\n$url', subject: 'HopefulMe Update');
    } catch (error) {
      if (!mounted) {
        return;
      }
      AppToast.error(context, error);
    }
  }

  Future<void> _handleCommentTap() async {
    final shouldShow = !_showInlineCommentComposer;
    setState(() {
      _showInlineCommentComposer = shouldShow;
    });
    if (shouldShow) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _inlineCommentFocusNode.requestFocus();
        }
      });
    } else {
      _inlineCommentFocusNode.unfocus();
    }
  }

  Future<void> _submitInlineComment() async {
    final comment = _inlineCommentController.text.trim();
    if (comment.isEmpty || _isSubmittingInlineComment) {
      return;
    }

    setState(() {
      _isSubmittingInlineComment = true;
    });
    try {
      await widget.updateRepository.addComment(
        updateId: widget.updateId,
        comment: comment,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _commentsCount += 1;
        _showInlineCommentComposer = false;
      });
      _inlineCommentController.clear();
      AppToast.success(context, 'Comment posted.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      AppToast.error(context, error);
    } finally {
      if (mounted) {
        setState(() {
          _isSubmittingInlineComment = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    if (_isDeleted) {
      return const SizedBox.shrink();
    }

    final isGeneratedActivity =
        widget.updateType.trim().toLowerCase() != 'update';
    final activityBadgeLabel = isGeneratedActivity ? widget.updateType : '';

    return ReusableUpdateCard(
      key: ValueKey('update-card-${widget.updateId}'),
      data: UpdateCardData(
        title: widget.title,
        subtitle: 'UPDATE',
        metaLeading: widget.device.isEmpty ? 'Web' : widget.device,
        metaTrailing: formatRelativeTimestamp(widget.createdAt),
        body: _body,
        photoUrl: widget.photoUrl,
        avatarUrl: widget.avatarUrl,
        fallbackLabel: widget.fallbackLabel,
        isVerified: widget.isVerified,
        isGeneratedActivity: isGeneratedActivity,
        activityBadgeLabel: activityBadgeLabel,
      ),
      onHeaderTap: widget.ownerUsername == null || widget.onOpenProfile == null
          ? null
          : () => widget.onOpenProfile!(widget.ownerUsername!),
      onCardTap: () => widget.onOpenUpdate(),
      onImageTap: _openFullImage,
      onMentionTap: widget.onOpenProfile,
      onHashtagTap: widget.onOpenHashtag,
      onLinkTap: widget.onOpenLink,
      headerTrailing: PopupMenuButton<String>(
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
        iconSize: 20,
        splashRadius: 18,
        icon: Icon(Icons.more_horiz, color: colors.icon),
        onSelected: (value) async {
          switch (value) {
            case 'view':
              await widget.onOpenUpdate();
              break;
            case 'edit':
              await _editUpdate();
              break;
            case 'delete':
              await _deleteUpdate();
              break;
            case 'share':
              await _shareUpdate();
              break;
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem(value: 'view', child: Text('View Post')),
          const PopupMenuItem(value: 'share', child: Text('Share To...')),
          if (_canEdit)
            const PopupMenuItem(value: 'edit', child: Text('Edit Update')),
          if (_isOwner)
            const PopupMenuItem(value: 'delete', child: Text('Delete Update')),
        ],
      ),
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: _toggleLike,
                child: ScaleTransition(
                  scale: _likeController,
                  child: _ActionPill(
                    icon: _liked ? Icons.favorite : Icons.favorite_border,
                    iconFill: _liked ? 1 : 0,
                    label: '$_likesCount',
                    color: _liked
                        ? const Color(0xFFFF4D6D)
                        : colors.icon,
                    background: const Color(0xFFFFF1F4),
                    darkBackground: const Color(0x221A1618),
                  ),
                ),
              ),
              const SizedBox(width: 0),
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: _handleCommentTap,
                child: _ActionPill(
                  icon: Icons.chat_bubble_outline,
                  label: '$_commentsCount',
                  color: colors.icon,
                  background: const Color(0x00000000),
                ),
              ),
              const Spacer(),
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: _shareUpdate,
                child: _ActionPill(
                  icon: Icons.ios_share_outlined,
                  color: colors.icon,
                  background: const Color(0x00000000),
                ),
              ),
            ],
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: _showInlineCommentComposer
                ? Padding(
                    key: const ValueKey('inline_comment'),
                    padding: const EdgeInsets.only(top: 10),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
                      decoration: BoxDecoration(
                        color: colors.surfaceMuted,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colors.border),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _inlineCommentController,
                                  focusNode: _inlineCommentFocusNode,
                                  minLines: 1,
                                  maxLines: 3,
                                  textInputAction: TextInputAction.send,
                                  onSubmitted: (_) => _submitInlineComment(),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    hintText: 'Write a comment...',
                                    border: InputBorder.none,
                                    hintStyle: TextStyle(
                                      color: colors.textMuted,
                                      fontSize: 13,
                                    ),
                                  ),
                                  style: TextStyle(
                                    color: colors.textPrimary,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Post comment',
                                onPressed: _isSubmittingInlineComment
                                    ? null
                                    : _submitInlineComment,
                                icon: _isSubmittingInlineComment
                                    ? SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: colors.brand,
                                        ),
                                      )
                                    : Icon(
                                        Icons.send_rounded,
                                        size: 18,
                                        color: colors.brand,
                                      ),
                              ),
                            ],
                          ),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 0,
                                ),
                                visualDensity: VisualDensity.compact,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: () => widget.onOpenUpdate(),
                              child: Text(
                                'View all comments',
                                style: TextStyle(
                                  color: colors.textMuted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : const SizedBox.shrink(key: ValueKey('inline_comment_hidden')),
          ),
        ],
      ),
    );
  }
}

class _ActionPill extends StatelessWidget {
  const _ActionPill({
    required this.icon,
    required this.color,
    required this.background,
    this.darkBackground,
    this.label,
    this.iconFill,
  });

  final IconData icon;
  final String? label;
  final Color color;
  final Color background;
  final Color? darkBackground;
  final double? iconFill;

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
          Icon(icon, size: 19, color: color, fill: iconFill),
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
