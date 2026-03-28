import 'package:flutter/material.dart';
import 'package:hopefulme_flutter/app/theme/app_theme.dart';
import 'package:hopefulme_flutter/core/widgets/app_status_state.dart';
import 'package:hopefulme_flutter/features/auth/models/user.dart';
import 'package:hopefulme_flutter/features/messages/data/message_repository.dart';
import 'package:hopefulme_flutter/features/profile/data/profile_repository.dart';
import 'package:hopefulme_flutter/features/profile/models/profile_dashboard.dart';
import 'package:hopefulme_flutter/features/updates/data/update_repository.dart';
import 'package:hopefulme_flutter/features/updates/presentation/screens/update_detail_screen.dart';
import 'package:hopefulme_flutter/features/updates/presentation/widgets/interactive_update_card.dart';

class ProfileUpdatesScreen extends StatefulWidget {
  const ProfileUpdatesScreen({
    required this.profile,
    required this.repository,
    required this.messageRepository,
    required this.updateRepository,
    required this.currentUser,
    super.key,
  });

  final ProfileSummary profile;
  final ProfileRepository repository;
  final MessageRepository messageRepository;
  final UpdateRepository updateRepository;
  final User? currentUser;

  @override
  State<ProfileUpdatesScreen> createState() => _ProfileUpdatesScreenState();
}

class _ProfileUpdatesScreenState extends State<ProfileUpdatesScreen> {
  final ScrollController _scrollController = ScrollController();
  final List<ProfileContentItem> _items = <ProfileContentItem>[];
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
      final page = await widget.repository.fetchUserUpdates(
        widget.profile.username,
        page: 1,
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
      final page = await widget.repository.fetchUserUpdates(
        widget.profile.username,
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

  Future<void> _openUpdate(ProfileContentItem item) async {
    final result = await Navigator.of(context).push<UpdateDetailResult>(
      MaterialPageRoute<UpdateDetailResult>(
        builder: (context) => UpdateDetailScreen(
          updateId: item.id,
          currentUser: widget.currentUser,
          repository: widget.updateRepository,
          profileRepository: widget.repository,
          messageRepository: widget.messageRepository,
        ),
      ),
    );
    if (result?.shouldRefresh == true) {
      await _loadInitial();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Scaffold(
      backgroundColor: colors.scaffold,
      appBar: AppBar(
        title: Text('${widget.profile.displayName} Updates'),
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

                  final item = _items[index];
                  return InteractiveUpdateCard(
                    updateId: item.id,
                    title: widget.profile.displayName,
                    body: item.body,
                    photoUrl: item.photoUrl,
                    avatarUrl: widget.profile.photoUrl,
                    fallbackLabel: widget.profile.displayName,
                    device: item.device,
                    createdAt: item.createdAt,
                    likesCount: item.likesCount,
                    commentsCount: item.commentsCount,
                    views: item.views,
                    updateRepository: widget.updateRepository,
                    onOpenUpdate: () => _openUpdate(item),
                    currentUser: widget.currentUser,
                    ownerUsername: widget.profile.username,
                  );
                },
              ),
            ),
    );
  }
}
