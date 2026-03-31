import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hopefulme_flutter/app/theme/app_theme.dart';
import 'package:hopefulme_flutter/core/network/image_url_resolver.dart';
import 'package:hopefulme_flutter/core/widgets/app_status_state.dart';
import 'package:hopefulme_flutter/core/utils/time_formatter.dart';
import 'package:hopefulme_flutter/features/auth/models/user.dart';
import 'package:hopefulme_flutter/features/content/data/content_repository.dart';
import 'package:hopefulme_flutter/features/content/presentation/content_navigation.dart';
import 'package:hopefulme_flutter/features/messages/data/message_repository.dart';
import 'package:hopefulme_flutter/features/profile/data/profile_repository.dart';
import 'package:hopefulme_flutter/features/profile/presentation/profile_navigation.dart';
import 'package:hopefulme_flutter/features/search/data/search_repository.dart';
import 'package:hopefulme_flutter/features/search/models/search_result.dart';
import 'package:hopefulme_flutter/features/updates/data/update_repository.dart';
import 'package:hopefulme_flutter/features/updates/presentation/screens/update_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({
    required this.repository,
    required this.contentRepository,
    required this.messageRepository,
    required this.profileRepository,
    required this.updateRepository,
    required this.currentUser,
    this.initialQuery,
    super.key,
  });

  final SearchRepository repository;
  final ContentRepository contentRepository;
  final MessageRepository messageRepository;
  final ProfileRepository profileRepository;
  final UpdateRepository updateRepository;
  final User? currentUser;
  final String? initialQuery;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounce;
  SearchResult? _result;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String _activeType = 'all';
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery != null && widget.initialQuery!.trim().isNotEmpty) {
      _controller.text = widget.initialQuery!.trim();
    }
    _scrollController.addListener(_onScroll);
    _runSearch(immediate: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _runSearch(immediate: true);
    });
  }

  void _onScroll() {
    if (_activeType != 'users' ||
        _isLoadingMore ||
        _result == null ||
        !_result!.hasMore) {
      return;
    }

    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 220) {
      _loadMoreUsers();
    }
  }

  Future<void> _runSearch({required bool immediate}) async {
    if (immediate) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final result = await widget.repository.search(
        query: _controller.text.trim(),
        type: _activeType,
      );
      if (!mounted) return;
      setState(() {
        _result = result;
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

  Future<void> _loadMoreUsers() async {
    final result = _result;
    if (result == null || !result.hasMore) {
      return;
    }

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final next = await widget.repository.search(
        query: _controller.text.trim(),
        type: _activeType,
        page: result.currentPage + 1,
      );
      if (!mounted) return;
      setState(() {
        _result = SearchResult(
          query: next.query,
          type: next.type,
          isSuggestion: next.isSuggestion,
          users: [...result.users, ...next.users],
          posts: next.posts,
          blogs: next.blogs,
          updates: next.updates,
          currentPage: next.currentPage,
          lastPage: next.lastPage,
          total: next.total,
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  void _setType(String type) {
    if (_activeType == type) {
      return;
    }
    setState(() {
      _activeType = type;
    });
    _runSearch(immediate: true);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final result = _result;

    return Scaffold(
      backgroundColor: colors.scaffold,
      appBar: AppBar(
        backgroundColor: colors.surface,
        surfaceTintColor: colors.surface,
        titleSpacing: 12,
        title: TextField(
          controller: _controller,
          onChanged: _onChanged,
          decoration: InputDecoration(
            hintText: 'Type name or topic...',
            filled: true,
            fillColor: colors.surfaceMuted,
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _SearchTab(
                    label: 'All Results',
                    selected: _activeType == 'all',
                    onTap: () => _setType('all'),
                  ),
                  const SizedBox(width: 10),
                  _SearchTab(
                    label: result == null
                        ? 'People'
                        : _activeType == 'users'
                        ? 'People (${result.total})'
                        : 'People (${result.users.length})',
                    selected: _activeType == 'users',
                    onTap: () => _setType('users'),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? AppStatusState.fromError(
                    error: _error!,
                    actionLabel: 'Try again',
                    onAction: () => _runSearch(immediate: true),
                  )
                : RefreshIndicator(
                    onRefresh: () => _runSearch(immediate: true),
                    child: ListView(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      children: [
                        if ((result?.query ?? '').isEmpty)
                          _SearchHero(
                            isSuggestion: result?.isSuggestion ?? false,
                          ),
                        if (_activeType == 'users')
                          _UsersGrid(
                            users: result?.users ?? const <SearchUser>[],
                            onUserTap: (username) => openUserProfile(
                              context,
                              profileRepository: widget.profileRepository,
                              messageRepository: widget.messageRepository,
                              updateRepository: widget.updateRepository,
                              currentUser: widget.currentUser,
                              username: username,
                            ),
                          )
                        else
                          _MixedResults(
                            result: result,
                            onUserTap: (username) => openUserProfile(
                              context,
                              profileRepository: widget.profileRepository,
                              messageRepository: widget.messageRepository,
                              updateRepository: widget.updateRepository,
                              currentUser: widget.currentUser,
                              username: username,
                            ),
                            onPostTap: (postId) => openPostDetail(
                              context,
                              contentRepository: widget.contentRepository,
                              profileRepository: widget.profileRepository,
                              messageRepository: widget.messageRepository,
                              searchRepository: widget.repository,
                              updateRepository: widget.updateRepository,
                              postId: postId,
                              currentUsername: widget.currentUser?.username,
                            ),
                            onBlogTap: (blogId) => openBlogDetail(
                              context,
                              contentRepository: widget.contentRepository,
                              profileRepository: widget.profileRepository,
                              messageRepository: widget.messageRepository,
                              searchRepository: widget.repository,
                              updateRepository: widget.updateRepository,
                              blogId: blogId,
                              currentUsername: widget.currentUser?.username,
                            ),
                            onUpdateTap: (updateId) =>
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (context) => UpdateDetailScreen(
                                      updateId: updateId,
                                      currentUser: widget.currentUser,
                                      repository: widget.updateRepository,
                                      contentRepository:
                                          widget.contentRepository,
                                      profileRepository:
                                          widget.profileRepository,
                                      messageRepository:
                                          widget.messageRepository,
                                      searchRepository: widget.repository,
                                    ),
                                  ),
                                ),
                          ),
                        if (_isLoadingMore)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _SearchTab extends StatelessWidget {
  const _SearchTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? colors.brand : colors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? colors.brand : colors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : colors.textMuted,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _SearchHero extends StatelessWidget {
  const _SearchHero({required this.isSuggestion});

  final bool isSuggestion;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 18),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: colors.accentSoft,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(Icons.search, color: colors.accentSoftText, size: 34),
          ),
          const SizedBox(height: 14),
          Text(
            isSuggestion ? 'Discover Community' : 'Search the Community',
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 26,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Find people, posts, and topics you are interested in.',
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.textMuted, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _UsersGrid extends StatelessWidget {
  const _UsersGrid({required this.users, required this.onUserTap});

  final List<SearchUser> users;
  final Future<void> Function(String username) onUserTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    if (users.isEmpty) {
      return const _SearchEmpty(label: 'No matching people found.');
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - 14) / 2;
        final childAspectRatio = cardWidth / 152;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: users.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: childAspectRatio.clamp(0.82, 1.18),
          ),
          itemBuilder: (context, index) {
            final user = users[index];
            return InkWell(
              onTap: () => onUserTap(user.username),
              borderRadius: BorderRadius.circular(24),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: colors.border),
                ),
                child: Column(
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundImage: user.photoUrl.isNotEmpty
                              ? NetworkImage(
                                  ImageUrlResolver.avatar(
                                    user.photoUrl,
                                    size: 84,
                                  ),
                                )
                              : null,
                          child: user.photoUrl.isEmpty
                              ? const Icon(Icons.person)
                              : null,
                        ),
                        if (user.isOnline)
                          const Positioned(
                            right: 0,
                            bottom: 0,
                            child: CircleAvatar(
                              radius: 6,
                              backgroundColor: Colors.green,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      user.displayName,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '@${user.username}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: colors.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _MixedResults extends StatelessWidget {
  const _MixedResults({
    required this.result,
    required this.onUserTap,
    required this.onPostTap,
    required this.onBlogTap,
    required this.onUpdateTap,
  });

  final SearchResult? result;
  final Future<void> Function(String username) onUserTap;
  final Future<void> Function(int postId) onPostTap;
  final Future<void> Function(int blogId) onBlogTap;
  final Future<void> Function(int updateId) onUpdateTap;

  @override
  Widget build(BuildContext context) {
    final data = result;
    if (data == null) {
      return const SizedBox.shrink();
    }

    final hasResults =
        data.users.isNotEmpty ||
        data.posts.isNotEmpty ||
        data.blogs.isNotEmpty ||
        data.updates.isNotEmpty;

    if (!hasResults) {
      return const _SearchEmpty(label: 'No results matched your keywords.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (data.users.isNotEmpty) ...[
          const _SearchSectionTitle(title: 'People'),
          const SizedBox(height: 12),
          _UsersGrid(users: data.users, onUserTap: onUserTap),
          const SizedBox(height: 20),
        ],
        if (data.posts.isNotEmpty) ...[
          const _SearchSectionTitle(title: 'Top Posts'),
          const SizedBox(height: 12),
          ...data.posts.map(
            (item) => _SearchCard(
              item: item,
              label: 'POST',
              onUserTap: onUserTap,
              onTap: () => onPostTap(item.id),
            ),
          ),
          const SizedBox(height: 20),
        ],
        if (data.blogs.isNotEmpty) ...[
          const _SearchSectionTitle(title: 'Articles'),
          const SizedBox(height: 12),
          ...data.blogs.map(
            (item) => _SearchCard(
              item: item,
              label: 'BLOG',
              onUserTap: onUserTap,
              onTap: () => onBlogTap(item.id),
            ),
          ),
          const SizedBox(height: 20),
        ],
        if (data.updates.isNotEmpty) ...[
          const _SearchSectionTitle(title: 'Updates'),
          const SizedBox(height: 12),
          ...data.updates.map(
            (item) => _SearchCard(
              item: item,
              label: 'UPDATE',
              onUserTap: onUserTap,
              onTap: () => onUpdateTap(item.id),
            ),
          ),
        ],
      ],
    );
  }
}

class _SearchSectionTitle extends StatelessWidget {
  const _SearchSectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Text(
      title,
      style: TextStyle(
        color: colors.textMuted,
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _SearchCard extends StatelessWidget {
  const _SearchCard({
    required this.item,
    required this.label,
    required this.onUserTap,
    required this.onTap,
  });

  final SearchContentItem item;
  final String label;
  final Future<void> Function(String username) onUserTap;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (item.photoUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  child: Image.network(
                    item.photoUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const SizedBox(
                          height: 180,
                          child: Center(
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
                        label,
                        style: TextStyle(
                          color: colors.accentSoftText,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (item.title.isNotEmpty)
                      Text(
                        item.title,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    if (item.body.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        item.body,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.textMuted,
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                    ],
                    if (item.user != null) ...[
                      const SizedBox(height: 14),
                      InkWell(
                        onTap: () => onUserTap(item.user!.username),
                        borderRadius: BorderRadius.circular(999),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundImage: item.user!.photoUrl.isNotEmpty
                                  ? NetworkImage(
                                      ImageUrlResolver.avatar(
                                        item.user!.photoUrl,
                                        size: 42,
                                      ),
                                    )
                                  : null,
                              child: item.user!.photoUrl.isEmpty
                                  ? const Icon(Icons.person, size: 14)
                                  : null,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                item.user!.displayName,
                                style: TextStyle(
                                  color: colors.textPrimary,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (item.createdAt.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          formatRelativeTimestamp(item.createdAt),
                          style: TextStyle(
                            color: colors.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchEmpty extends StatelessWidget {
  const _SearchEmpty({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.border),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: colors.textMuted,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
