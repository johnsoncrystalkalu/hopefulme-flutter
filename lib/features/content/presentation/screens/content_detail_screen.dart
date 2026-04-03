import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';
import 'package:hopefulme_flutter/app/theme/app_theme.dart';
import 'package:hopefulme_flutter/core/config/app_config.dart';
import 'package:hopefulme_flutter/core/network/image_url_resolver.dart';
import 'package:hopefulme_flutter/core/utils/time_formatter.dart';
import 'package:hopefulme_flutter/core/widgets/app_network_image.dart';
import 'package:hopefulme_flutter/core/widgets/app_send_action_button.dart';
import 'package:hopefulme_flutter/core/widgets/app_status_state.dart';
import 'package:hopefulme_flutter/core/widgets/app_toast.dart';
import 'package:hopefulme_flutter/core/widgets/fullscreen_network_image_screen.dart';
import 'package:hopefulme_flutter/core/widgets/rich_display_text.dart';
import 'package:hopefulme_flutter/core/widgets/verified_name_text.dart';
import 'package:hopefulme_flutter/features/content/data/content_repository.dart';
import 'package:hopefulme_flutter/features/content/models/content_detail.dart';
import 'package:hopefulme_flutter/features/content/presentation/screens/blog_editor_screen.dart';
import 'package:hopefulme_flutter/features/messages/data/message_repository.dart';
import 'package:hopefulme_flutter/features/profile/data/profile_repository.dart';
import 'package:hopefulme_flutter/features/profile/presentation/profile_navigation.dart';
import 'package:hopefulme_flutter/features/search/data/search_repository.dart';
import 'package:hopefulme_flutter/features/search/presentation/screens/search_screen.dart';
import 'package:hopefulme_flutter/features/updates/data/update_repository.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class ContentDetailScreen extends StatefulWidget {
  const ContentDetailScreen.post({
    required this.contentId,
    required this.repository,
    required this.profileRepository,
    required this.messageRepository,
    this.searchRepository,
    required this.updateRepository,
    required this.currentUsername,
    super.key,
  }) : kind = 'post';

  const ContentDetailScreen.blog({
    required this.contentId,
    required this.repository,
    required this.profileRepository,
    required this.messageRepository,
    this.searchRepository,
    required this.updateRepository,
    required this.currentUsername,
    super.key,
  }) : kind = 'blog';

  final int contentId;
  final String kind;
  final ContentRepository repository;
  final ProfileRepository profileRepository;
  final MessageRepository messageRepository;
  final SearchRepository? searchRepository;
  final UpdateRepository updateRepository;
  final String? currentUsername;

  @override
  State<ContentDetailScreen> createState() => _ContentDetailScreenState();
}

class _ContentDetailScreenState extends State<ContentDetailScreen> {
  late Future<ContentDetail> _future;
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmittingComment = false;
  BlogActionResult? _pendingBlogAction;

  bool _isOwner(ContentDetail detail) {
    final username = widget.currentUsername?.trim().toLowerCase();
    final owner = detail.user?.username.trim().toLowerCase();
    return widget.kind == 'blog' &&
        username != null &&
        username.isNotEmpty &&
        owner != null &&
        owner.isNotEmpty &&
        username == owner;
  }

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
            videoUrl: detail.videoUrl,
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

  Future<void> _replyToComment(
    ContentDetail detail,
    ContentComment target,
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
      if (!mounted) {
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _future = _load();
          });
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      AppToast.error(pageContext, error);
    }
  }

  Future<void> _openFullImage(String imageUrl) {
    return FullscreenNetworkImageScreen.show(context, imageUrl: imageUrl);
  }

  Future<void> _openSearchQuery(String query) {
    if (widget.searchRepository == null) {
      return Future<void>.value();
    }
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => SearchScreen(
          repository: widget.searchRepository!,
          contentRepository: widget.repository,
          messageRepository: widget.messageRepository,
          profileRepository: widget.profileRepository,
          updateRepository: widget.updateRepository,
          currentUser: null,
          initialQuery: query,
        ),
      ),
    );
  }

  Future<void> _editBlog(ContentDetail detail) async {
    final updated = await Navigator.of(context).push<ContentDetail>(
      MaterialPageRoute<ContentDetail>(
        builder: (context) => BlogEditorScreen.edit(
          repository: widget.repository,
          currentUsername: widget.currentUsername,
          initialDetail: detail,
        ),
      ),
    );

    if (!mounted || updated == null) {
      return;
    }

    setState(() {
      _future = Future<ContentDetail>.value(updated);
      _pendingBlogAction = BlogActionResult.updated(updated);
    });
  }

  Future<void> _deleteBlog(ContentDetail detail) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Article?'),
          content: const Text(
            'This article will be removed permanently and cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    try {
      await widget.repository.deleteBlog(detail.id);
      if (!mounted) {
        return;
      }
      AppToast.success(context, 'Blog post deleted successfully.');
      Navigator.of(context).pop(BlogActionResult.deleted(detail.id));
    } catch (error) {
      if (!mounted) {
        return;
      }
      AppToast.error(context, error);
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

  String _postMetaLine(ContentDetail detail) {
    final parts = <String>[
      if (detail.tag.trim().isNotEmpty) detail.tag.trim(),
      if (detail.createdAt.trim().isNotEmpty)
        formatDetailedTimestamp(detail.createdAt),
    ];
    return parts.join(' • ');
  }

  Future<void> _downloadImage(String imageUrl) async {
    final resolvedUrl = imageUrl.trim();
    if (resolvedUrl.isEmpty) {
      return;
    }
    try {
      final saved = await GallerySaver.saveImage(resolvedUrl);
      if (!mounted) {
        return;
      }
      if (saved == true) {
        AppToast.success(context, 'Image saved to your gallery.');
        return;
      }
    } catch (_) {
      // Fall back to opening the image externally below.
    }

    final uri = Uri.tryParse(resolvedUrl);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (mounted) {
        AppToast.info(
          context,
          'Could not save directly, so the image was opened externally.',
        );
      }
    }
  }

  Widget _buildPostHeader(ContentDetail detail, AppThemeColors colors) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(bottom: BorderSide(color: colors.borderStrong)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: colors.shadow.withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const ClipOval(
                  child: Image(
                    image: AssetImage('assets/images/hopefulme-logo.png'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            AppConfig.appName,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.verified_rounded,
                          size: 18,
                          color: colors.brand,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _postMetaLine(detail),
                      style: TextStyle(
                        color: colors.textMuted,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (detail.title.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text(
              detail.title,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPostImageActions(
    AppThemeColors colors, {
    required String primaryUrl,
    required String? secondaryUrl,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          if (primaryUrl.trim().isNotEmpty)
            _MediaActionChip(
              icon: Icons.download_rounded,
              label: 'Download image',
              onTap: () => _downloadImage(primaryUrl),
              colors: colors,
            ),
          if ((secondaryUrl ?? '').trim().isNotEmpty)
            _MediaActionChip(
              icon: Icons.collections_outlined,
              label: 'Download second image',
              onTap: () => _downloadImage(secondaryUrl!),
              colors: colors,
            ),
        ],
      ),
    );
  }

  Widget _buildImageBlock({
    required BuildContext context,
    required String imageUrl,
    required String originalImageUrl,
    required BorderRadiusGeometry borderRadius,
  }) {
    final resolvedImageUrl = originalImageUrl.isNotEmpty
        ? originalImageUrl
        : imageUrl;

    return InkWell(
      onTap: () => _openFullImage(resolvedImageUrl),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: SizedBox(
          width: double.infinity,
          child: AppNetworkImage(
            imageUrl: resolvedImageUrl,
            fit: BoxFit.fitWidth,
            backgroundColor: context.appColors.surfaceMuted,
            placeholderLabel: widget.kind == 'blog'
                ? 'Article image'
                : 'Post image',
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }
        Navigator.of(context).pop(_pendingBlogAction);
      },
      child: Scaffold(
        backgroundColor: colors.scaffold,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(_pendingBlogAction),
          ),
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
                        if (widget.kind == 'post')
                          _buildPostHeader(detail, colors),
                        if (widget.kind == 'post' &&
                            detail.videoUrl.trim().isNotEmpty)
                          _PostVideoEmbed(videoUrl: detail.videoUrl)
                        else if (detail.photoUrl.isNotEmpty)
                          _buildImageBlock(
                            context: context,
                            imageUrl: detail.photoUrl,
                            originalImageUrl: detail.originalPhotoUrl,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.zero,
                            ),
                          ),
                        if (widget.kind == 'post' &&
                            detail.photoUrl.isNotEmpty &&
                            detail.videoUrl.trim().isEmpty)
                          _buildPostImageActions(
                            colors,
                            primaryUrl: detail.originalPhotoUrl.isNotEmpty
                                ? detail.originalPhotoUrl
                                : detail.photoUrl,
                            secondaryUrl: detail.originalSecondaryPhotoUrl
                                    .trim()
                                    .isNotEmpty
                                ? detail.originalSecondaryPhotoUrl
                                : detail.secondaryPhotoUrl,
                          ),
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_isOwner(detail))
                                Align(
                                  alignment: Alignment.topRight,
                                  child: PopupMenuButton<String>(
                                    onSelected: (value) {
                                      if (value == 'edit') {
                                        _editBlog(detail);
                                        return;
                                      }
                                      if (value == 'delete') {
                                        _deleteBlog(detail);
                                      }
                                    },
                                    itemBuilder: (context) => const [
                                      PopupMenuItem<String>(
                                        value: 'edit',
                                        child: Text('Edit Article'),
                                      ),
                                      PopupMenuItem<String>(
                                        value: 'delete',
                                        child: Text('Delete Article'),
                                      ),
                                    ],
                                  ),
                                ),
                              if (widget.kind == 'blog' &&
                                  detail.tag.isNotEmpty)
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
                              if (widget.kind == 'post')
                                const SizedBox.shrink()
                              else if (detail.user != null) ...[
                                const SizedBox(height: 14),
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
                                        backgroundImage:
                                            detail.user!.photoUrl.isNotEmpty
                                            ? NetworkImage(
                                                detail.user!.photoUrl,
                                              )
                                            : null,
                                        child: detail.user!.photoUrl.isEmpty
                                            ? const Icon(Icons.person)
                                            : null,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            VerifiedNameText(
                                              name: detail.user!.displayName,
                                              verified: detail.user!.isVerified,
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
                              ] else if (detail.title.isNotEmpty) ...[
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
                                  onHashtagTap: _openSearchQuery,
                                  onLinkTap: _handleLinkTap,
                                ),
                              ],
                              if (detail.secondaryPhotoUrl.isNotEmpty) ...[
                                const SizedBox(height: 16),
                                _buildImageBlock(
                                  context: context,
                                  imageUrl: detail.secondaryPhotoUrl,
                                  originalImageUrl:
                                      detail.originalSecondaryPhotoUrl,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                if (widget.kind == 'post')
                                  _buildPostImageActions(
                                    colors,
                                    primaryUrl: '',
                                    secondaryUrl: detail
                                            .originalSecondaryPhotoUrl
                                            .trim()
                                            .isNotEmpty
                                        ? detail.originalSecondaryPhotoUrl
                                        : detail.secondaryPhotoUrl,
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
                                onHashtagTap: _openSearchQuery,
                                onReplyTap: () =>
                                    _replyToComment(detail, comment),
                                onLinkTap: _handleLinkTap,
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
      ),
    );
  }
}

class _PostVideoEmbed extends StatefulWidget {
  const _PostVideoEmbed({required this.videoUrl});

  final String videoUrl;

  @override
  State<_PostVideoEmbed> createState() => _PostVideoEmbedState();
}

class _PostVideoEmbedState extends State<_PostVideoEmbed> {
  WebViewController? _controller;
  String? _resolvedUrl;
  int _progress = 0;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      return;
    }
    _resolvedUrl = _resolveUrl(widget.videoUrl);
    if (_resolvedUrl != null) {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(const Color(0xFF000000))
        ..setNavigationDelegate(
          NavigationDelegate(
            onProgress: (progress) {
              if (!mounted) {
                return;
              }
              setState(() {
                _progress = progress;
              });
            },
          ),
        )
        ..loadRequest(Uri.parse(_resolvedUrl!));
    }
  }

  String? _resolveUrl(String rawUrl) {
    final value = rawUrl.trim();
    if (value.isEmpty) {
      return null;
    }

    final uri = Uri.tryParse(value);
    if (uri == null) {
      return null;
    }

    if (value.contains('/embed/')) {
      return value.contains('?') ? '$value&autoplay=1' : '$value?autoplay=1';
    }

    String? videoId;
    final host = uri.host.toLowerCase();
    if (host.contains('youtu.be')) {
      videoId = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
    } else if (host.contains('youtube.com') ||
        host.contains('youtube-nocookie.com')) {
      videoId = uri.queryParameters['v'];

      if ((videoId == null || videoId.isEmpty) && uri.pathSegments.isNotEmpty) {
        if (uri.pathSegments.contains('shorts')) {
          final index = uri.pathSegments.indexOf('shorts');
          if (index != -1 && index + 1 < uri.pathSegments.length) {
            videoId = uri.pathSegments[index + 1];
          }
        } else if (uri.pathSegments.contains('watch')) {
          videoId = uri.queryParameters['v'];
        } else {
          // Path-based video in /embed/<id> or /v/<id>
          final idSegment = uri.pathSegments.last;
          if (idSegment.isNotEmpty) {
            videoId = idSegment;
          }
        }
      }
    }

    if (videoId == null || videoId.isEmpty) {
      return value;
    }

    return 'https://www.youtube.com/embed/$videoId?autoplay=1';
  }

  Future<void> _openInBrowser() async {
    final url = _resolvedUrl ?? widget.videoUrl;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    if (kIsWeb) {
      return ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Container(
            color: colors.surfaceMuted,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.play_circle_outline_rounded,
                    size: 48,
                    color: colors.icon,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap to play video',
                    style: TextStyle(color: colors.textSecondary, fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _openInBrowser,
                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                    label: const Text('Watch on YouTube'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (_controller == null || _resolvedUrl == null) {
      return ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Container(
            color: colors.surfaceMuted,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.play_circle_outline_rounded,
                    size: 44,
                    color: colors.icon,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Video unavailable in preview',
                    style: TextStyle(color: colors.textSecondary),
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: _openInBrowser,
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('Open in YouTube'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          children: [
            WebViewWidget(controller: _controller!),
            if (_progress < 100)
              const Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: LinearProgressIndicator(minHeight: 2),
              ),
          ],
        ),
      ),
    );
  }
}

class _ContentCommentTile extends StatelessWidget {
  const _ContentCommentTile({
    required this.comment,
    required this.onProfileTap,
    required this.onMentionTap,
    required this.onHashtagTap,
    required this.onReplyTap,
    required this.onLinkTap,
  });

  final ContentComment comment;
  final VoidCallback? onProfileTap;
  final Future<void> Function(String username) onMentionTap;
  final Future<void> Function(String hashtag) onHashtagTap;
  final VoidCallback onReplyTap;
  final Future<void> Function(String url) onLinkTap;

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
                ? NetworkImage(
                    ImageUrlResolver.avatar(comment.user!.photoUrl, size: 56),
                  )
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
                  child: VerifiedNameText(
                    name: comment.user?.displayName ?? 'HopefulMe User',
                    verified: comment.user?.isVerified ?? false,
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
                      child: _ContentReplyTile(
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

class _ContentReplyTile extends StatelessWidget {
  const _ContentReplyTile({
    required this.reply,
    required this.onMentionTap,
    required this.onHashtagTap,
    required this.onLinkTap,
  });

  final ContentCommentReply reply;
  final Future<void> Function(String username) onMentionTap;
  final Future<void> Function(String hashtag) onHashtagTap;
  final Future<void> Function(String url) onLinkTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
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
            name: reply.user?.displayName ?? 'HopefulMe User',
            verified: reply.user?.isVerified ?? false,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          RichDisplayText(
            text: reply.body,
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

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

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

class _MediaActionChip extends StatelessWidget {
  const _MediaActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.colors,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final AppThemeColors colors;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: colors.surfaceMuted,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: colors.borderStrong),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: colors.brand),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
