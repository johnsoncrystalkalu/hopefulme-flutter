import 'package:flutter/material.dart';
import 'package:hopefulme_flutter/app/theme/app_theme.dart';
import 'package:hopefulme_flutter/features/auth/models/user.dart';
import 'package:hopefulme_flutter/core/utils/time_formatter.dart';
import 'package:hopefulme_flutter/core/widgets/app_status_state.dart';
import 'package:hopefulme_flutter/features/content/data/content_repository.dart';
import 'package:hopefulme_flutter/features/content/models/content_detail.dart';
import 'package:hopefulme_flutter/features/content/presentation/content_navigation.dart';
import 'package:hopefulme_flutter/features/messages/data/message_repository.dart';
import 'package:hopefulme_flutter/features/profile/data/profile_repository.dart';
import 'package:hopefulme_flutter/features/updates/data/update_repository.dart';

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
      final page = await widget.repository.fetchInspirationInbox(page: 1);
      setState(() {
        _items
          ..clear()
          ..addAll(page.items);
        _currentPage = page.currentPage;
        _lastPage = page.lastPage;
      });
    } catch (error) {
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
      );
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

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Scaffold(
      backgroundColor: colors.scaffold,
      appBar: AppBar(
        backgroundColor: colors.surface,
        surfaceTintColor: colors.surface,
        title: const Text('Inspiration Inbox'),
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
                          child: _HeroBanner(totalCount: _items.length),
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
  const _HeroBanner({required this.totalCount});

  final int totalCount;

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
                const Align(
                  alignment: Alignment.center,
                  child: Text(
                    'Your Inspirations',
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
                    '$totalCount inspiration${totalCount != 1 ? 's' : ''} received so far',
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
  const _InspirationInboxTile({required this.item, required this.onTap});

  final InspirationDetail item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final sender = item.isAnonymous ? 'Anonymous' : item.senderName;

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(26),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(26),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                colors.surface,
                colors.accentSoft.withValues(alpha: 0.42),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: colors.borderStrong),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: item.isAnonymous
                      ? LinearGradient(
                          colors: [colors.warningSoft, colors.accentSoft],
                        )
                      : colors.brandGradient,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  item.isAnonymous
                      ? Icons.auto_awesome_outlined
                      : Icons.mail_outline_rounded,
                  color: item.isAnonymous ? colors.warningText : Colors.white,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            sender,
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: colors.surfaceMuted,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            item.isPublic ? 'Public' : 'Private',
                            style: TextStyle(
                              color: colors.textMuted,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.message,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 14,
                        height: 1.55,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 14,
                          color: colors.textMuted,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            formatDetailedTimestamp(item.createdAt),
                            style: TextStyle(
                              color: colors.textMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          'Open',
                          style: TextStyle(
                            color: colors.brand,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
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
      ),
    );
  }
}
