import 'package:flutter/material.dart';

import 'package:hopefulme_flutter/app/theme/app_theme.dart';
import 'package:hopefulme_flutter/core/network/image_url_resolver.dart';
import 'package:hopefulme_flutter/core/widgets/app_status_state.dart';
import 'package:hopefulme_flutter/features/auth/models/user.dart';
import 'package:hopefulme_flutter/features/content/data/content_repository.dart';
import 'package:hopefulme_flutter/features/feed/data/feed_repository.dart';
import 'package:hopefulme_flutter/features/feed/models/feed_dashboard.dart';
import 'package:hopefulme_flutter/features/messages/data/message_repository.dart';
import 'package:hopefulme_flutter/features/profile/data/profile_repository.dart';
import 'package:hopefulme_flutter/features/profile/presentation/profile_navigation.dart';
import 'package:hopefulme_flutter/features/search/data/search_repository.dart';
import 'package:hopefulme_flutter/features/search/presentation/screens/search_screen.dart';
import 'package:hopefulme_flutter/features/updates/data/update_repository.dart';
import 'package:hopefulme_flutter/features/updates/presentation/screens/update_detail_screen.dart';
import 'package:hopefulme_flutter/features/updates/presentation/widgets/update_submission_modal.dart';
import 'package:hopefulme_flutter/features/updates/presentation/widgets/interactive_update_card.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdatesFeedScreen extends StatefulWidget {
  const UpdatesFeedScreen({
    required this.feedRepository,
    required this.contentRepository,
    required this.updateRepository,
    required this.profileRepository,
    required this.messageRepository,
    required this.searchRepository,
    required this.currentUser,
    super.key,
  });

  final FeedRepository feedRepository;
  final ContentRepository contentRepository;
  final UpdateRepository updateRepository;
  final ProfileRepository profileRepository;
  final MessageRepository messageRepository;
  final SearchRepository searchRepository;
  final User? currentUser;

  @override
  State<UpdatesFeedScreen> createState() => _UpdatesFeedScreenState();
}

class _UpdatesFeedScreenState extends State<UpdatesFeedScreen> {
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
      final page = await widget.feedRepository.fetchUpdatesPage(page: 1);
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
      final page = await widget.feedRepository.fetchUpdatesPage(page: nextPage);
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

  Future<void> _openUpdate(FeedEntry entry) async {
    final result = await Navigator.of(context).push<UpdateDetailResult>(
      MaterialPageRoute<UpdateDetailResult>(
        builder: (context) => UpdateDetailScreen(
          updateId: entry.id,
          currentUser: widget.currentUser,
          repository: widget.updateRepository,
          contentRepository: widget.contentRepository,
          profileRepository: widget.profileRepository,
          messageRepository: widget.messageRepository,
          searchRepository: widget.searchRepository,
        ),
      ),
    );

    if (result?.shouldRefresh == true) {
      await _loadInitial();
    }
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

  Future<void> _openCreateUpdate() async {
    final created = await UpdateSubmissionModal.show(
      context,
      updateRepository: widget.updateRepository,
      currentUser: widget.currentUser,
    );

    if (created != null) {
      await _loadInitial();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appColors.scaffold,
      appBar: AppBar(title: const Text('Activities')),
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
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                cacheExtent: 1200,
                padding: const EdgeInsets.all(16),
                itemCount: _items.length + (_isLoadingMore ? 1 : 0) + 1,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 14),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _ActivitiesComposerCard(
                      user: widget.currentUser,
                      onTap: _openCreateUpdate,
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
                  return RepaintBoundary(
                    child: InteractiveUpdateCard(
                      key: ValueKey('updates-feed-${entry.id}-${entry.createdAt}'),
                      updateId: entry.id,
                      title: entry.user?.displayName ?? entry.title,
                      body: entry.body,
                      photoUrl: entry.photoUrl,
                      avatarUrl: entry.user?.photoUrl ?? '',
                      fallbackLabel: entry.user?.displayName ?? entry.title,
                      device: entry.device,
                      createdAt: entry.createdAt,
                      likesCount: entry.likesCount,
                      commentsCount: entry.commentsCount,
                      views: entry.views,
                      updateRepository: widget.updateRepository,
                      currentUser: widget.currentUser,
                      ownerUsername: entry.user?.username,
                      isVerified: entry.user?.isVerified ?? false,
                      onOpenProfile: _openProfile,
                      onOpenUpdate: () => _openUpdate(entry),
                      onOpenHashtag: _openSearchQuery,
                      onOpenLink: _handleLinkTap,
                    ),
                  );
                },
              ),
            ),
    );
  }
}

class _ActivitiesComposerCard extends StatelessWidget {
  const _ActivitiesComposerCard({required this.user, required this.onTap});

  final User? user;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return InkWell(
      onTap: () => onTap(),
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: colors.borderStrong),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundImage: user?.photoUrl.isNotEmpty == true
                  ? NetworkImage(
                      ImageUrlResolver.avatar(user!.photoUrl, size: 66),
                    )
                  : null,
              child: user?.photoUrl.isEmpty ?? true
                  ? const Icon(Icons.person)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: colors.surfaceMuted,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  'What is on your mind?',
                  style: TextStyle(
                    color: colors.textMuted,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: colors.brandGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
