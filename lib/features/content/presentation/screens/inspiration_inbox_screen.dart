import 'package:flutter/material.dart';
import 'package:hopefulme_flutter/app/theme/app_theme.dart';
import 'package:hopefulme_flutter/core/widgets/app_avatar.dart';
import 'package:hopefulme_flutter/features/auth/models/user.dart';
import 'package:hopefulme_flutter/core/utils/time_formatter.dart';
import 'package:hopefulme_flutter/core/widgets/app_status_state.dart';
import 'package:hopefulme_flutter/core/widgets/app_toast.dart';
import 'package:hopefulme_flutter/features/content/data/content_repository.dart';
import 'package:hopefulme_flutter/features/content/models/content_detail.dart';
import 'package:hopefulme_flutter/features/content/presentation/content_navigation.dart';
import 'package:hopefulme_flutter/features/messages/data/message_repository.dart';
import 'package:hopefulme_flutter/features/profile/data/profile_repository.dart';
import 'package:hopefulme_flutter/features/updates/data/update_repository.dart';

enum _InspirationInboxView { received, sent }

class InspirationInboxScreen extends StatefulWidget {
  const InspirationInboxScreen({
    required this.repository,
    required this.profileRepository,
    required this.messageRepository,
    required this.updateRepository,
    required this.currentUser,
    super.key,
  });

  final ContentRepository repository;
  final ProfileRepository profileRepository;
  final MessageRepository messageRepository;
  final UpdateRepository updateRepository;
  final User? currentUser;

  @override
  State<InspirationInboxScreen> createState() => _InspirationInboxScreenState();
}

class _InspirationInboxScreenState extends State<InspirationInboxScreen> {
  final ScrollController _scrollController = ScrollController();
  final List<InspirationDetail> _items = <InspirationDetail>[];
  final Set<int> _deletingIds = <int>{};
  _InspirationInboxView _activeView = _InspirationInboxView.received;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  int _currentPage = 0;
  int _lastPage = 1;
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
    });

    try {
      final page = await widget.repository.fetchInspirationInbox(
        page: 1,
        sent: _activeView == _InspirationInboxView.sent,
      );
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
    if (_isLoadingMore || _currentPage >= _lastPage) {
      return;
    }

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final page = await widget.repository.fetchInspirationInbox(
        page: _currentPage + 1,
        sent: _activeView == _InspirationInboxView.sent,
      );
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

  Future<void> _switchView(_InspirationInboxView view) async {
    if (_activeView == view) {
      return;
    }
    setState(() {
      _activeView = view;
      _items.clear();
      _currentPage = 0;
      _lastPage = 1;
    });
    await _loadInitial();
  }

  Future<void> _deleteInspiration(InspirationDetail item) async {
    final isSent = _activeView == _InspirationInboxView.sent;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete inspiration'),
        content: Text(
          isSent
              ? 'Delete this sent inspiration permanently?'
              : 'Delete this inspiration from your inbox?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _deletingIds.add(item.id);
    });

    try {
      await widget.repository.deleteInspiration(item.id);
      if (!mounted) return;
      setState(() {
        _items.removeWhere((entry) => entry.id == item.id);
      });
      AppToast.success(context, 'Inspiration deleted.');
    } catch (error) {
      if (!mounted) return;
      AppToast.error(context, error);
    } finally {
      if (mounted) {
        setState(() {
          _deletingIds.remove(item.id);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isSent = _activeView == _InspirationInboxView.sent;
    final toggleLabel = isSent ? 'View Inbox' : 'View Sent';
    return Scaffold(
      backgroundColor: colors.scaffold,
      appBar: AppBar(
        backgroundColor: colors.surface,
        surfaceTintColor: colors.surface,
        title: const Text('Inspiration Inbox'),
        actions: [
          TextButton(
            onPressed: () => _switchView(
              isSent
                  ? _InspirationInboxView.received
                  : _InspirationInboxView.sent,
            ),
            child: Text(toggleLabel),
          ),
          const SizedBox(width: 6),
        ],
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
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    itemCount: _items.length + 1 + (_isLoadingMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 24),
                          child: _HeroBanner(
                            totalCount: _items.length,
                            isSentView: isSent,
                          ),
                        );
                      }

                      if (index > _items.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      final item = _items[index - 1];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                          child: _InspirationInboxTile(
                            item: item,
                            isSentView: isSent,
                            isDeleting: _deletingIds.contains(item.id),
                            onDelete: () => _deleteInspiration(item),
                            onTap: () => openInspirationDetail(
                            context,
                            contentRepository: widget.repository,
                            profileRepository: widget.profileRepository,
                            messageRepository: widget.messageRepository,
                            updateRepository: widget.updateRepository,
                            currentUser: widget.currentUser,
                            inspirationId: item.id,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
    );
  }
}

class _HeroBanner extends StatelessWidget {
  const _HeroBanner({required this.totalCount, required this.isSentView});

  final int totalCount;
  final bool isSentView;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: colors.brandGradient,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.06,
              child: CustomPaint(
                painter: _DottedPatternPainter(dotColor: Colors.white),
              ),
            ),
          ),
          Positioned.fill(
            child: Center(
              child: Container(
                width: 236,
                height: 236,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF7C3AED).withValues(alpha: 0.28),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 30, 24, 36),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Align(
                  alignment: Alignment.center,
                  child: Container(
                    width: 66,
                    height: 66,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.18),
                      ),
                    ),
                    child: const Icon(
                      Icons.favorite_rounded,
                      color: Colors.white,
                      size: 34,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.center,
                  child: Text(
                    isSentView ? 'Inspirations Sent' : 'Your Inspirations',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      height: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.center,
                  child: Text(
                    '$totalCount inspiration${totalCount != 1 ? 's' : ''} ${isSentView ? 'sent' : 'received'} so far',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.58),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
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

class _DottedPatternPainter extends CustomPainter {
  _DottedPatternPainter({required this.dotColor});

  final Color dotColor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = dotColor;
    const dotSpacing = 28.0;
    const dotRadius = 1.0;

    for (double x = 0; x < size.width; x += dotSpacing) {
      for (double y = 0; y < size.height; y += dotSpacing) {
        canvas.drawCircle(Offset(x, y), dotRadius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DottedPatternPainter oldDelegate) => false;
}

class _InspirationInboxTile extends StatelessWidget {
  const _InspirationInboxTile({
    required this.item,
    required this.isSentView,
    required this.onTap,
    required this.onDelete,
    required this.isDeleting,
  });

  final InspirationDetail item;
  final bool isSentView;
  final VoidCallback onTap;
  final Future<void> Function() onDelete;
  final bool isDeleting;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    const sentAccent = Color(0xFF274A73);
    final sender = item.isAnonymous ? 'Anonymous' : item.senderName;
    final recipient = item.receiver?.displayName.trim().isNotEmpty == true
        ? item.receiver!.displayName
        : (item.receiverName.trim().isNotEmpty ? item.receiverName : 'Recipient');
    final title = isSentView ? 'To: $recipient' : sender;
    final senderPhotoUrl = item.sender?.photoUrl ?? '';
    final senderInitial = sender.trim().isNotEmpty ? sender.trim()[0] : 'U';

    return InkWell(
      onTap: isDeleting ? null : onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border.withValues(alpha: 0.7)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isSentView
                        ? sentAccent.withValues(alpha: 0.12)
                        : colors.surfaceMuted.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: isSentView
                      ? Icon(
                          Icons.north_east_rounded,
                          size: 25,
                          color: sentAccent,
                        )
                      : item.isAnonymous
                      ? Icon(
                          Icons.person_2_sharp,
                          size: 25,
                          color: colors.warningText,
                        )
                      : Padding(
                          padding: const EdgeInsets.all(2),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(7),
                            child: AppAvatar(
                              imageUrl: senderPhotoUrl,
                              label: senderInitial,
                              radius: 14,
                            ),
                          ),
                        ),
                ),
                const Spacer(),
                if (isDeleting)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  iconSize: 18,
                  splashRadius: 16,
                  icon: Icon(
                    Icons.more_horiz_rounded,
                    color: colors.textMuted,
                  ),
                  onSelected: (value) {
                    if (value == 'delete') {
                      onDelete();
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem<String>(
                      value: 'delete',
                      child: Text('Delete'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              item.message,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.schedule_rounded,
                  size: 13,
                  color: colors.textMuted,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    formatDetailedTimestamp(item.createdAt),
                    style: TextStyle(
                      color: colors.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: colors.textMuted,
                  size: 17,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
