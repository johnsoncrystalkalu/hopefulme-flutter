import 'package:flutter/material.dart';
import 'package:hopefulme_flutter/app/theme/app_theme.dart';
import 'package:hopefulme_flutter/core/network/image_url_resolver.dart';
import 'package:hopefulme_flutter/core/widgets/verified_name_text.dart';
import 'package:hopefulme_flutter/core/widgets/app_status_state.dart';
import 'package:hopefulme_flutter/features/auth/models/user.dart';
import 'package:hopefulme_flutter/features/messages/data/message_repository.dart';
import 'package:hopefulme_flutter/features/profile/data/profile_repository.dart';
import 'package:hopefulme_flutter/features/profile/models/profile_dashboard.dart';
import 'package:hopefulme_flutter/features/profile/presentation/profile_navigation.dart';
import 'package:hopefulme_flutter/features/updates/data/update_repository.dart';

enum ProfileConnectionsType { followers, following }

class ProfileConnectionsScreen extends StatefulWidget {
  const ProfileConnectionsScreen({
    required this.username,
    required this.type,
    required this.repository,
    required this.messageRepository,
    required this.updateRepository,
    required this.currentUser,
    super.key,
  });

  final String username;
  final ProfileConnectionsType type;
  final ProfileRepository repository;
  final MessageRepository messageRepository;
  final UpdateRepository updateRepository;
  final User? currentUser;

  @override
  State<ProfileConnectionsScreen> createState() =>
      _ProfileConnectionsScreenState();
}

class _ProfileConnectionsScreenState extends State<ProfileConnectionsScreen> {
  final ScrollController _scrollController = ScrollController();
  final List<ProfileConnectionUser> _items = <ProfileConnectionUser>[];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  int _currentPage = 0;
  int _lastPage = 1;
  Object? _error;

  String get _title => widget.type == ProfileConnectionsType.followers
      ? 'Followers'
      : 'Following';

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

  Future<ProfileConnectionPage> _fetch(int page) {
    return widget.type == ProfileConnectionsType.followers
        ? widget.repository.fetchFollowers(widget.username, page: page)
        : widget.repository.fetchFollowing(widget.username, page: page);
  }

  Future<void> _loadInitial() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final page = await _fetch(1);
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(page.items);
        _currentPage = page.currentPage;
        _lastPage = page.lastPage;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
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
    if (_isLoadingMore || _currentPage >= _lastPage) {
      return;
    }

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final page = await _fetch(_currentPage + 1);
      if (!mounted) return;
      setState(() {
        _items.addAll(page.items);
        _currentPage = page.currentPage;
        _lastPage = page.lastPage;
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
        _scrollController.position.maxScrollExtent - 220) {
      _loadMore();
    }
  }

  Future<void> _openProfile(String username) {
    return openUserProfile(
      context,
      profileRepository: widget.repository,
      messageRepository: widget.messageRepository,
      updateRepository: widget.updateRepository,
      currentUser: widget.currentUser,
      username: username,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Scaffold(
      backgroundColor: colors.scaffold,
      appBar: AppBar(
        backgroundColor: colors.surface,
        surfaceTintColor: colors.surface,
        title: Text(_title),
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
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _items.length + (_isLoadingMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index >= _items.length) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final item = _items[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      onTap: () => _openProfile(item.username),
                      borderRadius: BorderRadius.circular(22),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: colors.border),
                        ),
                        child: Row(
                          children: [
                            Stack(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundImage: item.photoUrl.isNotEmpty
                                      ? NetworkImage(
                                          ImageUrlResolver.avatar(
                                            item.photoUrl,
                                            size: 72,
                                          ),
                                        )
                                      : null,
                                  child: item.photoUrl.isEmpty
                                      ? const Icon(Icons.person)
                                      : null,
                                ),
                                if (item.isOnline)
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
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  VerifiedNameText(
                                    name: item.displayName,
                                    verified: item.isVerified,
                                    style: TextStyle(
                                      color: colors.textPrimary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '@${item.username}',
                                    style: TextStyle(
                                      color: colors.textMuted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right, color: colors.icon),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
