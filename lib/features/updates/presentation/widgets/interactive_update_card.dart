import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hopefulme_flutter/core/utils/time_formatter.dart';
import 'package:hopefulme_flutter/features/auth/models/user.dart';
import 'package:hopefulme_flutter/features/updates/data/update_repository.dart';
import 'package:hopefulme_flutter/features/updates/presentation/widgets/update_card.dart';

class InteractiveUpdateCard extends StatefulWidget {
  const InteractiveUpdateCard({
    required this.updateId,
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
    super.key,
  });

  final int updateId;
  final String title;
  final String body;
  final String photoUrl;
  final String avatarUrl;
  final String fallbackLabel;
  final String device;
  final String createdAt;
  final int likesCount;
  final int commentsCount;
  final int views;
  final UpdateRepository updateRepository;
  final Future<void> Function() onOpenUpdate;
  final User? currentUser;
  final String? ownerUsername;
  final Future<void> Function(String username)? onOpenProfile;

  @override
  State<InteractiveUpdateCard> createState() => _InteractiveUpdateCardState();
}

class _InteractiveUpdateCardState extends State<InteractiveUpdateCard>
    with SingleTickerProviderStateMixin {
  late int _likesCount;
  late int _commentsCount;
  bool _liked = false;
  bool _busy = false;
  late AnimationController _likeController;

  bool get _isOwner => widget.currentUser?.username == widget.ownerUsername;

  @override
  void initState() {
    super.initState();
    _likesCount = widget.likesCount;
    _commentsCount = widget.commentsCount;
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

  @override
  Widget build(BuildContext context) {
    return ReusableUpdateCard(
      data: UpdateCardData(
        title: widget.title,
        subtitle: 'UPDATE',
        metaLeading: widget.device.isEmpty ? 'UPDATE' : widget.device,
        metaTrailing: formatRelativeTimestamp(widget.createdAt),
        body: widget.body,
        photoUrl: widget.photoUrl,
        avatarUrl: widget.avatarUrl,
        fallbackLabel: widget.fallbackLabel,
      ),
      onHeaderTap: widget.ownerUsername == null || widget.onOpenProfile == null
          ? null
          : () => widget.onOpenProfile!(widget.ownerUsername!),
      onImageTap: () => widget.onOpenUpdate(),
      onMentionTap: widget.onOpenProfile,
      headerTrailing: PopupMenuButton<String>(
        icon: const Icon(Icons.more_horiz, color: Color(0xFF94A3B8)),
        onSelected: (value) async {
          switch (value) {
            case 'view':
            case 'edit':
            case 'delete':
              await widget.onOpenUpdate();
              break;
            case 'share':
              await Clipboard.setData(
                ClipboardData(text: 'HopefulMe update #${widget.updateId}'),
              );
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Update link copied to clipboard')),
              );
              break;
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: 'view',
            child: Text('View Full Post'),
          ),
          const PopupMenuItem(
            value: 'share',
            child: Text('Share To...'),
          ),
          if (_isOwner)
            const PopupMenuItem(
              value: 'edit',
              child: Text('Edit Update'),
            ),
          if (_isOwner)
            const PopupMenuItem(
              value: 'delete',
              child: Text('Delete Update'),
            ),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
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
