import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:hopefulme_flutter/core/config/app_config.dart';
import 'package:hopefulme_flutter/core/config/reaction_config.dart';
import 'package:hopefulme_flutter/app/theme/app_theme.dart';
import 'package:hopefulme_flutter/core/utils/compact_count_formatter.dart';
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
    this.onOpenComment,
    this.currentUser,
    this.ownerUsername,
    this.onOpenProfile,
    this.onOpenHashtag,
    this.onOpenLink,
    this.isVerified = false,
    this.isLiked = false,
    this.myReaction,
    this.reactionsPreview = const <String>[],
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
  final Future<void> Function()? onOpenComment;
  final User? currentUser;
  final String? ownerUsername;
  final Future<void> Function(String username)? onOpenProfile;
  final Future<void> Function(String hashtag)? onOpenHashtag;
  final Future<void> Function(String url)? onOpenLink;
  final bool isLiked;
  final String? myReaction;
  final List<String> reactionsPreview;

  @override
  State<InteractiveUpdateCard> createState() => _InteractiveUpdateCardState();
}

class _InteractiveUpdateCardState extends State<InteractiveUpdateCard>
    with SingleTickerProviderStateMixin {
  late int _likesCount;
  late int _commentsCount;
  late String _body;
  late List<String> _reactionsPreview;
  String? _myReaction;
  bool _liked = false;
  bool _busy = false;
  bool _isDeleted = false;
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
    _liked = widget.isLiked;
    _myReaction = widget.myReaction;
    _reactionsPreview = List<String>.from(widget.reactionsPreview);
    _likeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      lowerBound: 1.0,
      upperBound: 1.12,
    )..value = 1;
  }

  @override
  void dispose() {
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
    final myReactionChanged = oldWidget.myReaction != widget.myReaction;
    final reactionsPreviewChanged =
        oldWidget.reactionsPreview.join('|') !=
        widget.reactionsPreview.join('|');

    if (updateChanged ||
        bodyChanged ||
        likesChanged ||
        commentsChanged ||
        likedChanged ||
        myReactionChanged ||
        reactionsPreviewChanged) {
      _body = widget.body;
      _likesCount = widget.likesCount;
      _commentsCount = widget.commentsCount;
      _liked = widget.isLiked;
      _myReaction = widget.myReaction;
      _reactionsPreview = List<String>.from(widget.reactionsPreview);
      _isDeleted = false;
    }
  }

  Future<void> _toggleLike() async {
    if (_busy) return;
    setState(() {
      _busy = true;
    });
    try {
      final defaultReaction =
          (_myReaction != null && _myReaction!.trim().isNotEmpty)
          ? _myReaction!.trim()
          : '\u2764\uFE0F';
      final result = _liked
          ? await widget.updateRepository.toggleLike(widget.updateId)
          : await widget.updateRepository.toggleLike(
              widget.updateId,
              reaction: defaultReaction,
            );
      _likeController
        ..forward()
        ..reverse();
      if (!mounted) return;
      setState(() {
        _liked = result.liked;
        _likesCount = result.count;
        _myReaction = result.myReaction;
        _reactionsPreview = result.reactionsPreview;
        _busy = false;
      });
    } finally {
      if (mounted && _busy) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _pickReaction() async {
    if (_busy) return;

    final selected = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        final colors = dialogContext.appColors;
        final isDark = Theme.of(dialogContext).brightness == Brightness.dark;
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
              children: ReactionConfig.updateQuick.map((emoji) {
                return InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () => Navigator.of(dialogContext).pop(emoji),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    child: Text(emoji, style: const TextStyle(fontSize: 24)),
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );

    if (selected == null || selected.trim().isEmpty) {
      return;
    }

    setState(() {
      _busy = true;
    });
    try {
      final result = await widget.updateRepository.toggleLike(
        widget.updateId,
        reaction: selected,
      );
      if (!mounted) return;
      setState(() {
        _liked = result.liked;
        _likesCount = result.count;
        _myReaction = result.myReaction;
        _reactionsPreview = result.reactionsPreview;
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
    final onOpenComment = widget.onOpenComment;
    if (onOpenComment != null) {
      await onOpenComment();
      return;
    }
    await widget.onOpenUpdate();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final visibleReactions = _reactionsPreview
        .take(ReactionConfig.updatePreviewMax)
        .toList(growable: false);
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
                onLongPress: _pickReaction,
                child: RepaintBoundary(
                  child: ScaleTransition(
                    scale: _likeController,
                    child: _ActionPill(
                      icon: _liked ? Icons.favorite : Icons.favorite_border,
                      iconFill: _liked ? 1 : 0,
                      label: formatCompactCount(_likesCount),
                      color: _liked ? const Color(0xFFef4444) : colors.icon,
                      background: const Color(0xFFFFF7F6),
                      darkBackground: const Color(0x221A1618),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 0),
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: _handleCommentTap,
                child: _ActionPill(
                  icon: Icons.chat_bubble_outline,
                  label: formatCompactCount(_commentsCount),
                  color: colors.icon,
                  background: const Color(0x00000000),
                ),
              ),
              const Spacer(),
              if (_reactionsPreview.isNotEmpty)
                Tooltip(
                  message: 'Hold like button to react',
                  triggerMode: TooltipTriggerMode.longPress,
                  textStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surfaceMuted,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: colors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ...visibleReactions.map(
                          (emoji) => Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: Text(
                              emoji,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: _shareUpdate,
                child: _ActionPill(
                  icon: Icons.ios_share_outlined,
                  color: colors.icon,
                  background: const Color(0x00000000),
                  iconSize: 16,
                ),
              ),
            ],
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
    this.iconSize = 19,
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
