import 'package:flutter/material.dart';
import 'package:hopefulme_flutter/app/theme/app_theme.dart';
import 'package:hopefulme_flutter/core/utils/time_formatter.dart';
import 'package:hopefulme_flutter/core/widgets/app_status_state.dart';
import 'package:hopefulme_flutter/core/widgets/rich_display_text.dart';
import 'package:hopefulme_flutter/features/content/data/content_repository.dart';
import 'package:hopefulme_flutter/features/content/presentation/content_navigation.dart';
import 'package:hopefulme_flutter/features/feed/data/feed_repository.dart';
import 'package:hopefulme_flutter/features/feed/models/feed_dashboard.dart';
import 'package:hopefulme_flutter/features/messages/data/message_repository.dart';
import 'package:hopefulme_flutter/features/profile/data/profile_repository.dart';
import 'package:hopefulme_flutter/features/profile/presentation/profile_navigation.dart';
import 'package:hopefulme_flutter/features/updates/data/update_repository.dart';

class BlogsFeedScreen extends StatefulWidget {
  const BlogsFeedScreen({
    required this.feedRepository,
    required this.contentRepository,
    required this.profileRepository,
    required this.messageRepository,
    required this.updateRepository,
    required this.currentUsername,
    super.key,
  });

  final FeedRepository feedRepository;
  final ContentRepository contentRepository;
  final ProfileRepository profileRepository;
  final MessageRepository messageRepository;
  final UpdateRepository updateRepository;
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
      updateRepository: widget.updateRepository,
      blogId: entry.id,
      currentUsername: widget.currentUsername,
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
                itemCount: _items.length + (_isLoadingMore ? 1 : 0),
                separatorBuilder: (_, __) => const SizedBox(height: 14),
                itemBuilder: (context, index) {
                  if (index >= _items.length) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final entry = _items[index];
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
                                      const Center(
                                        child: Icon(Icons.broken_image_outlined),
                                      ),
                                ),
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  entry.title,
                                  style: TextStyle(
                                    color: colors.textPrimary,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                  ),
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
                                ),
                                const SizedBox(height: 14),
                                Row(
                                  children: [
                                    if (entry.user != null) ...[
                                      InkWell(
                                        onTap: () => _openProfile(
                                          entry.user!.username,
                                        ),
                                        borderRadius: BorderRadius.circular(999),
                                        child: CircleAvatar(
                                          radius: 14,
                                          backgroundImage:
                                              entry.user!.photoUrl.isNotEmpty
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
                                          onTap: () => _openProfile(
                                            entry.user!.username,
                                          ),
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
                },
              ),
            ),
    );
  }
}
