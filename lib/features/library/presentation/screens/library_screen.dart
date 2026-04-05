import 'package:flutter/material.dart';
import 'package:hopefulme_flutter/app/theme/app_theme.dart';
import 'package:hopefulme_flutter/core/utils/time_formatter.dart';
import 'package:hopefulme_flutter/core/widgets/app_status_state.dart';
import 'package:hopefulme_flutter/features/library/data/library_repository.dart';
import 'package:hopefulme_flutter/features/library/models/library_models.dart';
import 'package:hopefulme_flutter/features/library/presentation/screens/library_detail_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({required this.repository, super.key});

  final LibraryRepository repository;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  static const Color _libraryAccent = Color(0xFFEA580C);
  final ScrollController _scrollController = ScrollController();
  final List<LibraryItem> _items = <LibraryItem>[];
  List<LibraryItem> _featured = <LibraryItem>[];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  int _total = 0;
  String _selectedCategory = 'All';
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
      _total = 0;
      _hasMore = true;
      _items.clear();
      _featured = <LibraryItem>[];
    });

    try {
      final page = await widget.repository.fetchLibrary(
        page: 1,
        category: _selectedCategory,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _items.addAll(page.items);
        _featured = page.featured;
        _total = page.total;
        _hasMore = page.hasMore;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
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
      final page = await widget.repository.fetchLibrary(
        page: nextPage,
        category: _selectedCategory,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _page = nextPage;
        _items.addAll(page.items);
        _total = page.total;
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
        _scrollController.position.maxScrollExtent - 220) {
      _loadMore();
    }
  }

  Future<void> _openItem(LibraryItem item) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => LibraryDetailScreen(
          libraryId: item.id,
          repository: widget.repository,
        ),
      ),
    );
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
    final colors = context.appColors;
    return Scaffold(
      backgroundColor: colors.scaffold,
      appBar: AppBar(title: const Text('Library')),
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
              child: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                children: [
                  _LibraryHero(total: _total),
                  if (_featured.isNotEmpty && _selectedCategory == 'All') ...[
                    const SizedBox(height: 18),
                    Text(
                      'Members Picks',
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 238,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _featured.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(width: 14),
                        itemBuilder: (context, index) {
                          final item = _featured[index];
                          return SizedBox(
                            width: 150,
                            child: _FeaturedBookCard(
                              item: item,
                              onTap: () => _openItem(item),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 44,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: LibraryRepository.categories.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final category = LibraryRepository.categories[index];
                        final isActive = category == _selectedCategory;
                        return FilterChip(
                          label: Text(category),
                          selected: isActive,
                          onSelected: (_) => _selectCategory(category),
                          showCheckmark: false,
                          labelStyle: TextStyle(
                            color: isActive
                                ? Colors.white
                                : colors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                          backgroundColor: colors.surface,
                          selectedColor: _libraryAccent,
                          side: BorderSide(
                            color: isActive
                                ? _libraryAccent
                                : colors.borderStrong,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 18),
                  ..._items.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _LibraryCard(
                        item: item,
                        onTap: () => _openItem(item),
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
    );
  }
}

class _LibraryHero extends StatelessWidget {
  const _LibraryHero({required this.total});

  static const Color _libraryAccent = Color(0xFFEA580C);
  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _libraryAccent,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Resources',
            style: TextStyle(
              color: Color.fromRGBO(255, 255, 255, 0.7),
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'HopefulMe Library',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$total titles available for reading, study, and growth.',
            style: const TextStyle(
              color: Color.fromRGBO(255, 255, 255, 0.76),
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeaturedBookCard extends StatelessWidget {
  const _FeaturedBookCard({required this.item, required this.onTap});

  final LibraryItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: colors.borderStrong),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  width: double.infinity,
                  child: item.coverUrl.isNotEmpty
                      ? Image.network(item.coverUrl, fit: BoxFit.cover)
                      : const ColoredBox(
                          color: Color(0xFFF8FAFC),
                          child: Icon(Icons.menu_book_outlined),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              item.author,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: colors.textMuted, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _LibraryCard extends StatelessWidget {
  const _LibraryCard({required this.item, required this.onTap});

  final LibraryItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: colors.borderStrong),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: 68,
                height: 88,
                child: item.coverUrl.isNotEmpty
                    ? Image.network(item.coverUrl, fit: BoxFit.cover)
                    : const ColoredBox(
                        color: Color(0xFFF8FAFC),
                        child: Icon(Icons.menu_book_outlined),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.author,
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (item.tagline.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      item.tagline,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textMuted,
                        fontSize: 12,
                        height: 1.45,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    '${item.category} · ${formatConversationListTimestamp(item.createdAt)}',
                    style: TextStyle(
                      color: colors.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
