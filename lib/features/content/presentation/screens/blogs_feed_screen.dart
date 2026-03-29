import 'package:flutter/material.dart';
import 'package:hopefulme_flutter/app/theme/app_theme.dart';
import 'package:hopefulme_flutter/core/utils/time_formatter.dart';
import 'package:hopefulme_flutter/core/widgets/app_status_state.dart';
import 'package:hopefulme_flutter/core/widgets/app_toast.dart';
import 'package:hopefulme_flutter/core/widgets/rich_display_text.dart';
import 'package:hopefulme_flutter/features/content/data/content_repository.dart';
import 'package:hopefulme_flutter/features/content/models/content_detail.dart';
import 'package:hopefulme_flutter/features/content/presentation/content_navigation.dart';
import 'package:hopefulme_flutter/features/content/presentation/screens/blog_editor_screen.dart';
import 'package:hopefulme_flutter/features/feed/data/feed_repository.dart';
import 'package:hopefulme_flutter/features/feed/models/feed_dashboard.dart';
import 'package:hopefulme_flutter/features/messages/data/message_repository.dart';
import 'package:hopefulme_flutter/features/profile/data/profile_repository.dart';
import 'package:hopefulme_flutter/features/profile/presentation/profile_navigation.dart';
import 'package:hopefulme_flutter/features/search/data/search_repository.dart';
import 'package:hopefulme_flutter/features/search/presentation/screens/search_screen.dart';
import 'package:hopefulme_flutter/features/updates/data/update_repository.dart';

class BlogsFeedScreen extends StatefulWidget {
  const BlogsFeedScreen({
    required this.feedRepository,
    required this.contentRepository,
    required this.profileRepository,
    required this.messageRepository,
    required this.updateRepository,
    required this.searchRepository,
    required this.currentUsername,
    super.key,
  });

  final FeedRepository feedRepository;
  final ContentRepository contentRepository;
  final ProfileRepository profileRepository;
  final MessageRepository messageRepository;
  final UpdateRepository updateRepository;
  final SearchRepository searchRepository;
  final String? currentUsername;

  @override
  State<BlogsFeedScreen> createState() => _BlogsFeedScreenState();
}

class _BlogsFeedScreenState extends State<BlogsFeedScreen> {
  final ScrollController _scrollController = ScrollController();
  final List<FeedEntry> _items = <FeedEntry>[];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadInitial();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _page = 1;
      _hasMore = true;
      _items.clear();
    });

    try {
      final page = await widget.feedRepository.fetchBlogsPage(page: 1);
      if (!mounted) return;
      setState(() {
        _items.addAll(page.items);
        _hasMore = page.hasMore;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) {
      return;
    }

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final nextPage = _page + 1;
      final page = await widget.feedRepository.fetchBlogsPage(page: nextPage);
      if (!mounted) return;
      setState(() {
        _page = nextPage;
        _items.addAll(page.items);
        _hasMore = page.hasMore;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 240) {
      _loadMore();
    }
  }

  Future<void> _openProfile(String username) {
    return openUserProfile(
      context,
      profileRepository: widget.profileRepository,
      messageRepository: widget.messageRepository,
      updateRepository: widget.updateRepository,
      currentUser: null,
      username: username,
    );
  }

  Future<void> _openBlog(FeedEntry entry) {
    return openBlogDetail(
      context,
      contentRepository: widget.contentRepository,
      profileRepository: widget.profileRepository,
      messageRepository: widget.messageRepository,
      searchRepository: widget.searchRepository,
      updateRepository: widget.updateRepository,
      blogId: entry.id,
      currentUsername: widget.currentUsername,
    ).then((result) {
      if (!mounted || result == null) {
        return;
      }
      if (result.isDeleted && result.deletedBlogId != null) {
        setState(() {
          _items.removeWhere((item) => item.id == result.deletedBlogId);
        });
      } else if (result.detail != null) {
        _upsertEntry(result.detail!.toFeedEntry());
      }
    });
  }

  bool _isOwner(FeedEntry entry) {
    final current = widget.currentUsername?.trim().toLowerCase();
    final owner = entry.user?.username.trim().toLowerCase();
    return current != null &&
        current.isNotEmpty &&
        owner != null &&
        owner.isNotEmpty &&
        current == owner;
  }

  void _upsertEntry(FeedEntry updated) {
    final index = _items.indexWhere((item) => item.id == updated.id);
    setState(() {
      if (index == -1) {
        _items.insert(0, updated);
      } else {
        _items[index] = updated;
      }
    });
  }

  Future<void> _openCreateBlog() async {
    final created = await Navigator.of(context).push<ContentDetail>(
      MaterialPageRoute<ContentDetail>(
        builder: (context) => BlogEditorScreen.create(
          repository: widget.contentRepository,
          currentUsername: widget.currentUsername,
        ),
      ),
    );

    if (!mounted || created == null) {
      return;
    }

    _upsertEntry(created.toFeedEntry());
    AppToast.success(context, 'Article published.');
  }

  Future<void> _openEditBlog(FeedEntry entry) async {
    final detail = await widget.contentRepository.fetchBlog(entry.id);
    if (!mounted) {
      return;
    }

    final updated = await Navigator.of(context).push<ContentDetail>(
      MaterialPageRoute<ContentDetail>(
        builder: (context) => BlogEditorScreen.edit(
          repository: widget.contentRepository,
          currentUsername: widget.currentUsername,
          initialDetail: detail,
        ),
      ),
    );

    if (!mounted || updated == null) {
      return;
    }

    _upsertEntry(updated.toFeedEntry());
    AppToast.success(context, 'Article updated.');
  }

  Future<void> _deleteBlog(FeedEntry entry) async {
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
      await widget.contentRepository.deleteBlog(entry.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _items.removeWhere((item) => item.id == entry.id);
      });
      AppToast.success(context, 'Article deleted.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      AppToast.error(context, error);
    }
  }

  Future<void> _onBlogMenuSelected(String value, FeedEntry entry) async {
    if (value == 'edit') {
      await _openEditBlog(entry);
      return;
    }
    if (value == 'delete') {
      await _deleteBlog(entry);
    }
  }

  Widget _buildBlogCard(FeedEntry entry) {
    final colors = context.appColors;
    return InkWell(
      onTap: () => _openBlog(entry),
      borderRadius: BorderRadius.circular(26),
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: colors.borderStrong),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (entry.photoUrl.isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(26),
                ),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(
                    entry.photoUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const Center(child: Icon(Icons.broken_image_outlined)),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          entry.title,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      if (_isOwner(entry))
                        PopupMenuButton<String>(
                          onSelected: (value) =>
                              _onBlogMenuSelected(value, entry),
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
                    ],
                  ),
                  const SizedBox(height: 10),
                  RichDisplayText(
                    text: entry.body,
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 14,
                      height: 1.55,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    onMentionTap: _openProfile,
                    onHashtagTap: _openSearchQuery,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      if (entry.user != null) ...[
                        InkWell(
                          onTap: () => _openProfile(entry.user!.username),
                          borderRadius: BorderRadius.circular(999),
                          child: CircleAvatar(
                            radius: 14,
                            backgroundImage: entry.user!.photoUrl.isNotEmpty
                                ? NetworkImage(entry.user!.photoUrl)
                                : null,
                            child: entry.user!.photoUrl.isEmpty
                                ? const Icon(Icons.person, size: 14)
                                : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: InkWell(
                            onTap: () => _openProfile(entry.user!.username),
                            borderRadius: BorderRadius.circular(8),
                            child: Text(
                              entry.user!.displayName,
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                      Text(
                        formatRelativeTimestamp(entry.createdAt),
                        style: TextStyle(
                          color: colors.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openSearchQuery(String query) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => SearchScreen(
          repository: widget.searchRepository,
          contentRepository: widget.contentRepository,
          messageRepository: widget.messageRepository,
          profileRepository: widget.profileRepository,
          updateRepository: widget.updateRepository,
          currentUser: null,
          initialQuery: query,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Scaffold(
      backgroundColor: colors.scaffold,
      appBar: AppBar(title: const Text('Blog & Articles')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? AppStatusState.fromError(
              error: _error!,
              actionLabel: 'Try again',
              onAction: _loadInitial,
            )
          : RefreshIndicator(
              onRefresh: _loadInitial,
              child: ListView.separated(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _items.length + (_isLoadingMore ? 1 : 0) + 1,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 14),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _BlogsHeroHeader(
                      onCreateTap: () => _openCreateBlog(),
                    );
                  }

                  final itemIndex = index - 1;
                  if (itemIndex >= _items.length) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final entry = _items[itemIndex];
                  return _buildBlogCard(entry);
                },
              ),
            ),
    );
  }
}

class _BlogsHeroHeader extends StatelessWidget {
  const _BlogsHeroHeader({required this.onCreateTap});

  final VoidCallback onCreateTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors.surface, colors.accentSoft.withValues(alpha: 0.82)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: colors.borderStrong),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 8,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  gradient: colors.brandGradient,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'Stories',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: colors.textMuted.withValues(alpha: 0.55),
                  shape: BoxShape.circle,
                ),
              ),
              Text(
                'HopefulMe Blog',
                style: TextStyle(
                  color: colors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'HopefulMe Blog',
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Read thoughtful stories, encouragement, and reflections from voices across the HopefulMe community.',
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 14,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: onCreateTap,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Create Post'),
            ),
          ),
        ],
      ),
    );
  }
}
