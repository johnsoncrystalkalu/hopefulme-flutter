import 'package:flutter/material.dart';
import 'package:hopefulme_flutter/app/theme/app_theme.dart';
import 'package:hopefulme_flutter/core/widgets/app_avatar.dart';
import 'package:hopefulme_flutter/core/widgets/app_status_state.dart';
import 'package:hopefulme_flutter/core/widgets/verified_name_text.dart';
import 'package:hopefulme_flutter/features/updates/data/update_repository.dart';
import 'package:hopefulme_flutter/features/updates/models/update_reaction.dart';

class UpdateReactionsScreen extends StatefulWidget {
  const UpdateReactionsScreen({
    required this.updateId,
    required this.updateRepository,
    this.onOpenProfile,
    this.title = 'People who reacted',
    super.key,
  });

  final int updateId;
  final UpdateRepository updateRepository;
  final Future<void> Function(String username)? onOpenProfile;
  final String title;

  @override
  State<UpdateReactionsScreen> createState() => _UpdateReactionsScreenState();
}

class _UpdateReactionsScreenState extends State<UpdateReactionsScreen> {
  final ScrollController _scrollController = ScrollController();
  final List<UpdateReactionItem> _items = <UpdateReactionItem>[];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  Object? _error;
  int _currentPage = 0;
  int _lastPage = 1;

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
    });

    try {
      final page = await widget.updateRepository.fetchUpdateReactions(
        widget.updateId,
        page: 1,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _items
          ..clear()
          ..addAll(page.items);
        _currentPage = page.currentPage;
        _lastPage = page.lastPage;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
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
      final page = await widget.updateRepository.fetchUpdateReactions(
        widget.updateId,
        page: _currentPage + 1,
      );
      if (!mounted) {
        return;
      }
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

  Future<void> _openProfile(String username) async {
    final onOpenProfile = widget.onOpenProfile;
    if (onOpenProfile == null || username.trim().isEmpty) {
      return;
    }
    await onOpenProfile(username);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Scaffold(
      backgroundColor: colors.scaffold,
      appBar: AppBar(
        backgroundColor: colors.surface,
        surfaceTintColor: colors.surface,
        title: Text(widget.title),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? AppStatusState.fromError(
              error: _error!,
              actionLabel: 'Try again',
              onAction: _loadInitial,
            )
          : _items.isEmpty
          ? Center(
              child: Text(
                'No reactions yet.',
                style: TextStyle(
                  color: colors.textMuted,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadInitial,
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                itemCount: _items.length + (_isLoadingMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index >= _items.length) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final item = _items[index];
                  final username = item.user.username.trim();
                  final canOpenProfile =
                      widget.onOpenProfile != null && username.isNotEmpty;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: canOpenProfile
                          ? () => _openProfile(item.user.username)
                          : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: colors.border),
                        ),
                        child: Row(
                          children: [
                            AppAvatar(
                              imageUrl: item.user.photoUrl,
                              label: item.user.displayName,
                              radius: 19,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  VerifiedNameText(
                                    name: item.user.displayName,
                                    verified: item.user.isVerified,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: colors.textPrimary,
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    username.isNotEmpty
                                        ? '@$username'
                                        : 'Unknown user',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: colors.textMuted,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 34,
                              height: 34,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: colors.surfaceMuted,
                                shape: BoxShape.circle,
                                border: Border.all(color: colors.border),
                              ),
                              child: Text(
                                item.reaction.isNotEmpty ? item.reaction : '❤',
                                style: const TextStyle(fontSize: 17),
                              ),
                            ),
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
