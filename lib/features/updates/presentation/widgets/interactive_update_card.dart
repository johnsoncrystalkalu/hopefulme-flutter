import 'package:flutter/material.dart';
import 'package:hopefulme_flutter/app/theme/app_theme.dart';
import 'package:hopefulme_flutter/core/utils/time_formatter.dart';
import 'package:hopefulme_flutter/core/widgets/app_toast.dart';
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

  @override
  State<InteractiveUpdateCard> createState() => _InteractiveUpdateCardState();
}

class _InteractiveUpdateCardState extends State<InteractiveUpdateCard>
    with SingleTickerProviderStateMixin {
  late int _likesCount;
  late int _commentsCount;
  late String _body;
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
    _likeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      lowerBound: 0.9,
      upperBound: 1.15,
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

    if (updateChanged || bodyChanged || likesChanged || commentsChanged) {
      _body = widget.body;
      _likesCount = widget.likesCount;
      _commentsCount = widget.commentsCount;
      _liked = false;
      _isDeleted = false;
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
          decoration: const InputDecoration(hintText: 'What is on your mind?'),
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
      if (!mounted) {
        return;
      }
      setState(() {
        _body = updated.status;
      });
      AppToast.success(context, 'Update edited successfully.');
    } catch (error) {
      if (!mounted) {
        return;
      }
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

    if (confirm != true) {
      return;
    }

    setState(() {
      _busy = true;
    });

    try {
      await widget.updateRepository.deleteUpdate(widget.updateId);
      if (!mounted) {
        return;
      }
      setState(() {
        _isDeleted = true;
      });
      AppToast.success(context, 'Update deleted.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      AppToast.error(context, error);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
        metaLeading: widget.device.isEmpty ? 'UPDATE' : widget.device,
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
      onImageTap: () => widget.onOpenUpdate(),
      onMentionTap: widget.onOpenProfile,
      onHashtagTap: widget.onOpenHashtag,
      onLinkTap: widget.onOpenLink,
      headerTrailing: PopupMenuButton<String>(
        icon: const Icon(Icons.more_horiz, color: Color(0xFF94A3B8)),
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
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem(value: 'view', child: Text('View Post')),
          if (_canEdit)
            const PopupMenuItem(value: 'edit', child: Text('Edit Update')),
          if (_isOwner)
            const PopupMenuItem(value: 'delete', child: Text('Delete Update')),
        ],
      ),
      footer: Row(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _toggleLike,
            child: ScaleTransition(
              scale: _likeController,
              child: _ActionPill(
                icon: _liked ? Icons.favorite : Icons.favorite_border,
                label: '$_likesCount',
                color: const Color(0xFFFF4D6D),
                background: const Color(0xFFFFF1F4),
              ),
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => widget.onOpenUpdate(),
            child: _ActionPill(
              icon: Icons.chat_bubble_outline,
              label: '$_commentsCount',
              color: const Color(0xFF3D5AFE),
              background: const Color(0xFFEEF1FF),
            ),
          ),
          const Spacer(),
          Row(
            children: [
              const Icon(
                Icons.remove_red_eye_outlined,
                size: 16,
                color: Color(0xFF94A3B8),
              ),
              const SizedBox(width: 6),
              Text(
                '${widget.views}',
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
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
    required this.label,
    required this.color,
    required this.background,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.transparent : background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? colors.borderStrong : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
