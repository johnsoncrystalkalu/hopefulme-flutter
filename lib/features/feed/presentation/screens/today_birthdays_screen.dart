import 'package:flutter/material.dart';
import 'package:hopefulme_flutter/app/theme/app_theme.dart';
import 'package:hopefulme_flutter/core/network/image_url_resolver.dart';
import 'package:hopefulme_flutter/core/widgets/app_status_state.dart';
import 'package:hopefulme_flutter/core/widgets/verified_name_text.dart';
import 'package:hopefulme_flutter/features/auth/models/user.dart';
import 'package:hopefulme_flutter/features/feed/data/feed_repository.dart';
import 'package:hopefulme_flutter/features/feed/models/feed_dashboard.dart';
import 'package:hopefulme_flutter/features/messages/data/message_repository.dart';
import 'package:hopefulme_flutter/features/messages/presentation/screens/message_thread_screen.dart';
import 'package:hopefulme_flutter/features/profile/data/profile_repository.dart';
import 'package:hopefulme_flutter/features/profile/presentation/profile_navigation.dart';
import 'package:hopefulme_flutter/features/updates/data/update_repository.dart';

class TodayBirthdaysScreen extends StatefulWidget {
  const TodayBirthdaysScreen({
    required this.feedRepository,
    required this.initialUsers,
    required this.profileRepository,
    required this.messageRepository,
    required this.updateRepository,
    required this.currentUser,
    super.key,
  });

  final FeedRepository feedRepository;
  final List<FeedUser> initialUsers;
  final ProfileRepository profileRepository;
  final MessageRepository messageRepository;
  final UpdateRepository updateRepository;
  final User? currentUser;

  @override
  State<TodayBirthdaysScreen> createState() => _TodayBirthdaysScreenState();
}

class _TodayBirthdaysScreenState extends State<TodayBirthdaysScreen> {
  final ScrollController _scrollController = ScrollController();
  final List<FeedUser> _items = <FeedUser>[];
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
    final seededUsers = List<FeedUser>.from(widget.initialUsers);
    setState(() {
      _isLoading = true;
      _error = null;
      _page = 1;
      _hasMore = true;
      _items
        ..clear()
        ..addAll(seededUsers);
    });

    try {
      final page = await widget.feedRepository.fetchTodayBirthdays(page: 1);
      if (!mounted) return;
      setState(() {
        if (page.items.isNotEmpty || _items.isEmpty) {
          _items
            ..clear()
            ..addAll(page.items);
        }
        _hasMore = page.hasMore;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _hasMore = seededUsers.isEmpty ? false : true;
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
      final page = await widget.feedRepository.fetchTodayBirthdays(
        page: nextPage,
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

  Future<void> _openChat(FeedUser user) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => MessageThreadScreen(
          repository: widget.messageRepository,
          profileRepository: widget.profileRepository,
          updateRepository: widget.updateRepository,
          currentUser: widget.currentUser,
          username: user.username,
          title: user.displayName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: colors.scaffold,
      appBar: AppBar(title: const Text("Today's Birthdays")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _items.isEmpty
          ? AppStatusState.fromError(
              error: _error!,
              actionLabel: 'Try again',
              onAction: _loadInitial,
            )
          : _items.isEmpty
          ? AppStatusState(
              title: 'No birthdays today',
              message:
                  'There are no users matching today\'s birthday date right now.',
            )
          : RefreshIndicator(
              onRefresh: _loadInitial,
              child: ListView.separated(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _items.length + (_isLoadingMore ? 1 : 0),
                separatorBuilder: (_, itemIndex) =>
                    itemIndex == _items.length - 1 && !_isLoadingMore
                    ? const SizedBox(height: 0)
                    : const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  if (index >= _items.length) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final user = _items[index];
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: colors.borderStrong),
                    ),
                    child: Row(
                      children: [
                        InkWell(
                          onTap: () => _openProfile(user.username),
                          borderRadius: BorderRadius.circular(999),
                          child: CircleAvatar(
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
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: InkWell(
                            onTap: () => _openProfile(user.username),
                            borderRadius: BorderRadius.circular(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                VerifiedNameText(
                                  name: user.displayName,
                                  verified: user.isVerified,
                                  style: TextStyle(
                                    color: colors.textPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  user.cityState.isNotEmpty
                                      ? user.cityState
                                      : '@${user.username}',
                                  style: TextStyle(
                                    color: colors.textMuted,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: () => _openChat(user),
                          icon: const Icon(Icons.celebration_outlined),
                          label: const Text('Celebrate'),
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
