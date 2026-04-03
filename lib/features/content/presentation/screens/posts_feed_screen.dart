import 'package:flutter/material.dart';
import 'package:hopefulme_flutter/app/theme/app_theme.dart';
import 'package:hopefulme_flutter/core/widgets/app_screen_app_bar.dart';
import 'package:hopefulme_flutter/core/widgets/app_status_state.dart';
import 'package:hopefulme_flutter/core/widgets/rich_display_text.dart';
import 'package:hopefulme_flutter/features/auth/models/user.dart';
import 'package:hopefulme_flutter/features/content/data/content_repository.dart';
import 'package:hopefulme_flutter/features/content/presentation/content_navigation.dart';
import 'package:hopefulme_flutter/features/feed/data/feed_repository.dart';
import 'package:hopefulme_flutter/features/feed/models/feed_dashboard.dart';
import 'package:hopefulme_flutter/features/messages/data/message_repository.dart';
import 'package:hopefulme_flutter/features/profile/data/profile_repository.dart';
import 'package:hopefulme_flutter/features/profile/presentation/profile_navigation.dart';
import 'package:hopefulme_flutter/features/search/data/search_repository.dart';
import 'package:hopefulme_flutter/features/search/presentation/screens/search_screen.dart';
import 'package:hopefulme_flutter/features/updates/data/update_repository.dart';
import 'package:url_launcher/url_launcher.dart';

class PostsFeedScreen extends StatefulWidget {
  const PostsFeedScreen({
    required this.feedRepository,
    required this.contentRepository,
    required this.profileRepository,
    required this.messageRepository,
    required this.updateRepository,
    required this.searchRepository,
    required this.currentUser,
    required this.currentUsername,
    this.initialCategory = 'All',
    super.key,
  });

  final FeedRepository feedRepository;
  final ContentRepository contentRepository;
  final ProfileRepository profileRepository;
  final MessageRepository messageRepository;
  final UpdateRepository updateRepository;
  final SearchRepository searchRepository;
  final User? currentUser;
  final String? currentUsername;
  final String initialCategory;

  @override
  State<PostsFeedScreen> createState() => _PostsFeedScreenState();
}

class _PostsFeedScreenState extends State<PostsFeedScreen> {
  static const List<String> _categories = <String>[
    'All',
    'Article',
    'Quote',
    'Excerpt',
    'Event',
    'Outreach',
    'News',
    'Photoshoot',
    'Poetry',
    'Design',
    'eBook',
    'Video',
  ];

  final ScrollController _scrollController = ScrollController();
  final List<FeedEntry> _items = <FeedEntry>[];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  late String _selectedCategory;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedCategory =
        _categories.any(
          (item) => item.toLowerCase() == widget.initialCategory.toLowerCase(),
        )
        ? _categories.firstWhere(
            (item) =>
                item.toLowerCase() == widget.initialCategory.toLowerCase(),
          )
        : 'All';
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
      final page = await widget.feedRepository.fetchPostsPage(
        page: 1,
        category: _selectedCategory,
      );
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
      final page = await widget.feedRepository.fetchPostsPage(
        page: nextPage,
        category: _selectedCategory,
      );
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
      currentUser: widget.currentUser,
      username: username,
    );
  }

  Future<void> _openPost(FeedEntry entry) {
    return openPostDetail(
      context,
      contentRepository: widget.contentRepository,
      profileRepository: widget.profileRepository,
      messageRepository: widget.messageRepository,
      searchRepository: widget.searchRepository,
      updateRepository: widget.updateRepository,
      postId: entry.id,
      currentUsername: widget.currentUsername,
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
          currentUser: widget.currentUser,
          initialQuery: query,
        ),
      ),
    );
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

  void _selectCategory(String category) {
    if (_selectedCategory == category) {
      return;
    }
    setState(() {
      _selectedCategory = category;
    });
    _loadInitial();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appColors.scaffold,
      appBar: buildAppScreenAppBar(
        context,
        title: 'Post & News',
        subtitle: 'Community',
      ),
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
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                itemCount: _items.length + (_isLoadingMore ? 1 : 0) + 1,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 14),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _PostsHeroHeader(categoryName: _selectedCategory),
                        const SizedBox(height: 18),
                        _PostCategoryStrip(
                          categories: _categories,
                          activeCategory: _selectedCategory,
                          onSelected: _selectCategory,
                        ),
                      ],
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
                  return _FeedStylePostCard(
                    entry: entry,
                    onOpenPost: _openPost,
                    onOpenProfile: _openProfile,
                    onOpenHashtag: _openSearchQuery,
                    onOpenLink: _handleLinkTap,
                  );
                },
              ),
            ),
    );
  }
}

class _PostsHeroHeader extends StatelessWidget {
  const _PostsHeroHeader({required this.categoryName});

  final String categoryName;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isAll = categoryName.toLowerCase() == 'all';
    final kicker = isAll ? 'Official' : categoryName;
    final title = isAll ? 'All Posts' : categoryName;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: Theme.of(context).brightness == Brightness.dark
              ? <Color>[
                  colors.surfaceRaised,
                  colors.surface,
                  colors.surfaceMuted,
                ]
              : const <Color>[
                  Color(0xFFF8FBFF),
                  Color(0xFFEAF1FF),
                  Color(0xFFFDF7F4),
                ],
        ),
        border: Border.all(color: colors.borderStrong),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
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
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: colors.brand.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            kicker,
                            style: TextStyle(
                              color: colors.brand,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: colors.textMuted.withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                          ),
                        ),
                        Text(
                          'HopefulMe Posts',
                          style: TextStyle(
                            color: colors.textMuted,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      title,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        height: 0.95,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Text(
                        'Stay informed with the latest events, news, posts and announcements from our community leaders.',
                        style: TextStyle(
                          color: colors.textMuted,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          height: 1.55,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? colors.surface.withValues(alpha: 0.92)
                      : Colors.white.withValues(alpha: 0.82),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: colors.brand.withValues(alpha: 0.16),
                  ),
                ),
                child: Icon(
                  isAll ? Icons.dynamic_feed_rounded : Icons.sell_outlined,
                  color: colors.brand,
                  size: 28,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PostCategoryStrip extends StatelessWidget {
  const _PostCategoryStrip({
    required this.categories,
    required this.activeCategory,
    required this.onSelected,
  });

  final List<String> categories;
  final String activeCategory;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final label = categories[index];
          final isActive = label.toLowerCase() == activeCategory.toLowerCase();
          return FilterChip(
            label: Text(label),
            selected: isActive,
            showCheckmark: false,
            onSelected: (_) => onSelected(label),
            labelStyle: TextStyle(
              color: isActive ? Colors.white : colors.textSecondary,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
            side: BorderSide(
              color: isActive ? colors.brand : colors.borderStrong,
            ),
            backgroundColor: colors.surface,
            selectedColor: colors.brand,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          );
        },
      ),
    );
  }
}

class _FeedStylePostCard extends StatelessWidget {
  const _FeedStylePostCard({
    required this.entry,
    required this.onOpenPost,
    required this.onOpenProfile,
    required this.onOpenHashtag,
    required this.onOpenLink,
  });

  final FeedEntry entry;
  final Future<void> Function(FeedEntry entry) onOpenPost;
  final Future<void> Function(String username) onOpenProfile;
  final Future<void> Function(String hashtag) onOpenHashtag;
  final Future<void> Function(String url) onOpenLink;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: colors.borderStrong),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (entry.photoUrl.isNotEmpty)
            InkWell(
              onTap: () => onOpenPost(entry),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(26),
                ),
                child: Image.network(
                  entry.photoUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const SizedBox(
                    height: 180,
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
                Text(
                  entry.title,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (entry.body.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  RichDisplayText(
                    text: entry.body,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.textMuted,
                      fontSize: 14,
                      height: 1.55,
                    ),
                    onMentionTap: onOpenProfile,
                    onHashtagTap: onOpenHashtag,
                    onLinkTap: onOpenLink,
                  ),
                ],
                const SizedBox(height: 18),
                InkWell(
                  onTap: () => onOpenPost(entry),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF3D5AFE), Color(0xFF7C3AED)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'View Post',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
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
  }
}
