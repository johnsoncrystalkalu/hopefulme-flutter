import 'package:flutter/material.dart';
import 'package:hopefulme_flutter/app/theme/app_theme.dart';
import 'package:hopefulme_flutter/core/utils/time_formatter.dart';
import 'package:hopefulme_flutter/core/widgets/app_status_state.dart';
import 'package:hopefulme_flutter/core/widgets/fullscreen_network_image_screen.dart';
import 'package:hopefulme_flutter/core/widgets/rich_display_text.dart';
import 'package:hopefulme_flutter/features/content/data/content_repository.dart';
import 'package:hopefulme_flutter/features/content/models/content_detail.dart';
import 'package:hopefulme_flutter/features/messages/data/message_repository.dart';
import 'package:hopefulme_flutter/features/profile/data/profile_repository.dart';
import 'package:hopefulme_flutter/features/profile/presentation/profile_navigation.dart';
import 'package:hopefulme_flutter/features/updates/data/update_repository.dart';

class ContentDetailScreen extends StatefulWidget {
  const ContentDetailScreen.post({
    required this.contentId,
    required this.repository,
    required this.profileRepository,
    required this.messageRepository,
    required this.updateRepository,
    required this.currentUsername,
    super.key,
  }) : kind = 'post';

  const ContentDetailScreen.blog({
    required this.contentId,
    required this.repository,
    required this.profileRepository,
    required this.messageRepository,
    required this.updateRepository,
    required this.currentUsername,
    super.key,
  }) : kind = 'blog';

  final int contentId;
  final String kind;
  final ContentRepository repository;
  final ProfileRepository profileRepository;
  final MessageRepository messageRepository;
  final UpdateRepository updateRepository;
  final String? currentUsername;

  @override
  State<ContentDetailScreen> createState() => _ContentDetailScreenState();
}

class _ContentDetailScreenState extends State<ContentDetailScreen> {
  late Future<ContentDetail> _future;
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmittingComment = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<ContentDetail> _load() {
    return switch (widget.kind) {
      'blog' => widget.repository.fetchBlog(widget.contentId),
      _ => widget.repository.fetchPost(widget.contentId),
    };
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
    await _future;
  }

  Future<void> _submitComment(ContentDetail detail) async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _isSubmittingComment) {
      return;
    }

    setState(() {
      _isSubmittingComment = true;
    });

    try {
      final comment = await widget.repository.addComment(
        kind: widget.kind,
        contentId: detail.id,
        comment: text,
      );
      _commentController.clear();
      setState(() {
        _future = Future<ContentDetail>.value(
          ContentDetail(
            id: detail.id,
            kind: detail.kind,
            title: detail.title,
            body: detail.body,
            photoUrl: detail.photoUrl,
            originalPhotoUrl: detail.originalPhotoUrl,
            secondaryPhotoUrl: detail.secondaryPhotoUrl,
            originalSecondaryPhotoUrl: detail.originalSecondaryPhotoUrl,
            tag: detail.tag,
            label: detail.label,
            views: detail.views,
            likesCount: detail.likesCount,
            commentsCount: detail.commentsCount + 1,
            createdAt: detail.createdAt,
            user: detail.user,
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

  Future<void> _openFullImage(String imageUrl) {
    return FullscreenNetworkImageScreen.show(context, imageUrl: imageUrl);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Scaffold(
      backgroundColor: colors.scaffold,
      appBar: AppBar(
        backgroundColor: colors.surface,
        surfaceTintColor: colors.surface,
        title: Text(widget.kind == 'blog' ? 'Article' : 'Post'),
      ),
      body: FutureBuilder<ContentDetail>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError && !snapshot.hasData) {
            return AppStatusState.fromError(
              error: snapshot.error ?? 'Unable to load this page.',
              actionLabel: 'Try again',
              onAction: _refresh,
            );
          }
          final detail = snapshot.data;
          if (detail == null) {
            return const Center(child: Text('Unable to load content.'));
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: colors.borderStrong),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (detail.photoUrl.isNotEmpty)
                        InkWell(
                          onTap: () => _openFullImage(
                            detail.originalPhotoUrl.isNotEmpty
                                ? detail.originalPhotoUrl
                                : detail.photoUrl,
                          ),
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(28),
                            ),
                            child: Image.network(
                              detail.originalPhotoUrl.isNotEmpty
                                  ? detail.originalPhotoUrl
                                  : detail.photoUrl,
                              width: double.infinity,
                              fit: BoxFit.fitWidth,
                              alignment: Alignment.topCenter,
                              errorBuilder: (context, error, stackTrace) =>
                                  const SizedBox(
                                    height: 220,
                                    child: Center(
                                      child: Icon(Icons.broken_image_outlined),
                                    ),
                                  ),
                            ),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (detail.tag.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.accentSoft,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  detail.tag,
                                  style: TextStyle(
                                    color: colors.accentSoftText,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            if (detail.title.isNotEmpty) ...[
                              const SizedBox(height: 14),
                              Text(
                                detail.title,
                                style: TextStyle(
                                  color: colors.textPrimary,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                            const SizedBox(height: 14),
                            if (detail.user != null)
                              InkWell(
                                onTap: () => openUserProfile(
                                  context,
                                  profileRepository: widget.profileRepository,
                                  messageRepository: widget.messageRepository,
                                  updateRepository: widget.updateRepository,
                                  currentUser: null,
                                  username: detail.user!.username,
                                ),
                                borderRadius: BorderRadius.circular(999),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 18,
                                      backgroundImage: detail.user!.photoUrl.isNotEmpty
                                          ? NetworkImage(detail.user!.photoUrl)
                                          : null,
                                      child: detail.user!.photoUrl.isEmpty
                                          ? const Icon(Icons.person)
                                          : null,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            detail.user!.displayName,
                                            style: TextStyle(
                                              color: colors.textPrimary,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          Text(
                                            formatRelativeTimestamp(
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
                                  ],
                                ),
                              ),
                            if (detail.body.isNotEmpty) ...[
                              const SizedBox(height: 18),
                              RichDisplayText(
                                text: detail.body,
                                style: TextStyle(
                                  color: colors.textSecondary,
                                  fontSize: 15,
                                  height: 1.7,
                                ),
                                onMentionTap: (username) => openUserProfile(
                                  context,
                                  profileRepository: widget.profileRepository,
                                  messageRepository: widget.messageRepository,
                                  updateRepository: widget.updateRepository,
                                  currentUser: null,
                                  username: username,
                                ),
                              ),
                            ],
                            if (detail.secondaryPhotoUrl.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              InkWell(
                                onTap: () => _openFullImage(
                                  detail.originalSecondaryPhotoUrl.isNotEmpty
                                      ? detail.originalSecondaryPhotoUrl
                                      : detail.secondaryPhotoUrl,
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: Image.network(
                                    detail.originalSecondaryPhotoUrl.isNotEmpty
                                        ? detail.originalSecondaryPhotoUrl
                                        : detail.secondaryPhotoUrl,
                                    width: double.infinity,
                                    fit: BoxFit.fitWidth,
                                    alignment: Alignment.topCenter,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            const SizedBox.shrink(),
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 18),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                _MetaChip(
                                  icon: Icons.chat_bubble_outline,
                                  label: '${detail.commentsCount} comments',
                                ),
                                _MetaChip(
                                  icon: Icons.remove_red_eye_outlined,
                                  label: '${detail.views} views',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
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
                              minLines: 1,
                              maxLines: 3,
                              decoration: InputDecoration(
                                hintText: widget.kind == 'blog'
                                    ? 'Add your response...'
                                    : 'Add a comment...',
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
                          IconButton.filled(
                            onPressed: _isSubmittingComment
                                ? null
                                : () => _submitComment(detail),
                            icon: _isSubmittingComment
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.send),
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
                            child: _ContentCommentTile(
                              comment: comment,
                              onProfileTap: comment.user == null
                                  ? null
                                  : () => openUserProfile(
                                        context,
                                        profileRepository:
                                            widget.profileRepository,
                                        messageRepository:
                                            widget.messageRepository,
                                        updateRepository:
                                            widget.updateRepository,
                                        currentUser: null,
                                        username: comment.user!.username,
                                      ),
                              onMentionTap: (username) => openUserProfile(
                                context,
                                profileRepository: widget.profileRepository,
                                messageRepository: widget.messageRepository,
                                updateRepository: widget.updateRepository,
                                currentUser: null,
                                username: username,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ContentCommentTile extends StatelessWidget {
  const _ContentCommentTile({
    required this.comment,
    required this.onProfileTap,
    required this.onMentionTap,
  });

  final ContentComment comment;
  final VoidCallback? onProfileTap;
  final Future<void> Function(String username) onMentionTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onProfileTap,
          borderRadius: BorderRadius.circular(999),
          child: CircleAvatar(
            radius: 18,
            backgroundImage: comment.user?.photoUrl.isNotEmpty == true
                ? NetworkImage(comment.user!.photoUrl)
                : null,
            child: comment.user?.photoUrl.isNotEmpty == true
                ? null
                : const Icon(Icons.person),
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
                InkWell(
                  onTap: onProfileTap,
                  borderRadius: BorderRadius.circular(8),
                  child: Text(
                    comment.user?.displayName ?? 'HopefulMe User',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                RichDisplayText(
                  text: comment.body,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 13.5,
                    height: 1.45,
                  ),
                  onMentionTap: onMentionTap,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: colors.icon),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
