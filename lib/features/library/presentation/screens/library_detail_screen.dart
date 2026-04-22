import 'package:flutter/material.dart';
import 'package:hopefulme_flutter/app/theme/app_theme.dart';
import 'package:hopefulme_flutter/core/config/app_config.dart';
import 'package:hopefulme_flutter/core/presentation/screens/web_page_screen.dart';
import 'package:hopefulme_flutter/core/utils/compact_count_formatter.dart';
import 'package:hopefulme_flutter/core/utils/time_formatter.dart';
import 'package:hopefulme_flutter/core/widgets/app_status_state.dart';
import 'package:hopefulme_flutter/features/library/data/library_repository.dart';
import 'package:hopefulme_flutter/features/library/models/library_models.dart';
import 'package:hopefulme_flutter/features/library/presentation/screens/library_reader_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class LibraryDetailScreen extends StatefulWidget {
  const LibraryDetailScreen({
    required this.libraryId,
    required this.repository,
    super.key,
  });

  final int libraryId;
  final LibraryRepository repository;

  @override
  State<LibraryDetailScreen> createState() => _LibraryDetailScreenState();
}

class _LibraryDetailScreenState extends State<LibraryDetailScreen> {
  late Future<LibraryDetailResponse> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.fetchLibraryItem(widget.libraryId);
  }

  Future<void> _refresh() async {
    setState(() {
      _future = widget.repository.fetchLibraryItem(widget.libraryId);
    });
    await _future;
  }

  Future<void> _openWebPage(String title, String url) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => WebPageScreen(title: title, url: url),
      ),
    );
  }

  Future<void> _openExternalUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return;
    }

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open this download right now.')),
      );
    }
  }

  String _downloadUrl(LibraryItem item, String format) {
    final base = AppConfig.fromEnvironment().webBaseUrl;
    return '$base/library/${item.id}/download/$format';
  }

  String _readUrl(LibraryItem item) {
    if (item.links.pdfViewUrl.trim().isNotEmpty) {
      return item.links.pdfViewUrl;
    }
    final base = AppConfig.fromEnvironment().webBaseUrl;
    return '$base/library/${item.id}/view/pdf';
  }

  Future<void> _openReader(LibraryItem item) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => LibraryReaderScreen(
          title: item.title,
          url: _readUrl(item),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Scaffold(
      backgroundColor: colors.scaffold,
      appBar: AppBar(title: const Text('Library')),
      body: FutureBuilder<LibraryDetailResponse>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError && !snapshot.hasData) {
            return AppStatusState.fromError(
              error: snapshot.error ?? 'Unable to load this resource.',
              actionLabel: 'Try again',
              onAction: _refresh,
            );
          }

          final detail = snapshot.data;
          if (detail == null) {
            return const Center(child: Text('Unable to load this resource.'));
          }
          final item = detail.item;

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: colors.borderStrong),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(22),
                            child: AspectRatio(
                              aspectRatio: 3 / 4,
                              child: item.coverUrl.isNotEmpty
                                  ? Image.network(
                                      item.coverUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              const Icon(
                                                Icons.menu_book_outlined,
                                                size: 42,
                                              ),
                                    )
                                  : const ColoredBox(
                                      color: Color(0xFFF8FAFC),
                                      child: Center(
                                        child: Icon(
                                          Icons.menu_book_outlined,
                                          size: 42,
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF4E8),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            item.category,
                            style: const TextStyle(
                              color: Color(0xFFEA580C),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          item.title,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'by ${item.author}',
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (item.tagline.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Text(
                            item.tagline,
                            style: TextStyle(
                              color: colors.textMuted,
                              fontSize: 14,
                              fontStyle: FontStyle.italic,
                              height: 1.5,
                            ),
                          ),
                        ],
                        if (item.description.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Text(
                            item.description,
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: 14.5,
                              height: 1.65,
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _MetricChip(
                              icon: Icons.remove_red_eye_outlined,
                              label: '${formatCompactCount(item.views)} views',
                            ),
                            if (item.createdAt.isNotEmpty)
                              _MetricChip(
                                icon: Icons.schedule_outlined,
                                label: formatDetailedTimestamp(item.createdAt),
                              ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Get this resource',
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (item.links.hasReadablePdf)
                          _ActionLink(
                            color: colors.brand,
                            icon: Icons.chrome_reader_mode_outlined,
                            label: 'Read in app',
                            onTap: () => _openReader(item),
                          ),
                        if (item.links.hasPdf)
                          _ActionLink(
                            color: const Color(0xFFEF4444),
                            icon: Icons.picture_as_pdf_outlined,
                            label: 'Download PDF',
                            onTap: () => _openExternalUrl(_downloadUrl(item, 'pdf')),
                          ),
                        if (item.links.hasEpub)
                          _ActionLink(
                            color: const Color(0xFF3B82F6),
                            icon: Icons.menu_book_outlined,
                            label: 'Download EPUB',
                            onTap: () =>
                                _openExternalUrl(_downloadUrl(item, 'epub')),
                          ),
                        if (item.links.hasExternalDownload)
                          _ActionLink(
                            color: const Color(0xFF475569),
                            icon: Icons.open_in_new_rounded,
                            label: 'External Download',
                            onTap: () => _openWebPage(
                              'External Download',
                              item.links.externalDownloadUrl,
                            ),
                          ),
                        if (item.links.hasPurchase)
                          _ActionLink(
                            color: const Color(0xFFEA580C),
                            icon: Icons.shopping_bag_outlined,
                            label: item.links.purchaseLabel.isNotEmpty
                                ? item.links.purchaseLabel
                                : 'Buy Now',
                            trailing: item.links.purchasePrice.isNotEmpty
                                ? item.links.purchasePrice
                                : null,
                            onTap: () => _openWebPage(
                              'Purchase',
                              item.links.purchaseUrl,
                            ),
                          ),
                        if (item.links.hasApk)
                          _ActionLink(
                            color: const Color(0xFF22C55E),
                            icon: Icons.android_rounded,
                            label: 'Download Android App',
                            onTap: () => _openExternalUrl(
                              item.links.apkUrl.isNotEmpty
                                  ? item.links.apkUrl
                                  : _downloadUrl(item, 'apk'),
                            ),
                          ),
                        if (item.links.hasAppStore)
                          _ActionLink(
                            color: const Color(0xFF0F172A),
                            icon: Icons.phone_iphone_rounded,
                            label: 'App Store',
                            onTap: () => _openWebPage(
                              'App Store',
                              item.links.appstoreUrl,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (detail.related.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Text(
                    'More in ${item.category}',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...detail.related.map(
                    (related) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        onTap: () => Navigator.of(context).pushReplacement(
                          MaterialPageRoute<void>(
                            builder: (context) => LibraryDetailScreen(
                              libraryId: related.id,
                              repository: widget.repository,
                            ),
                          ),
                        ),
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
                              ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: SizedBox(
                                  width: 60,
                                  height: 78,
                                  child: related.coverUrl.isNotEmpty
                                      ? Image.network(
                                          related.coverUrl,
                                          fit: BoxFit.cover,
                                        )
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
                                      related.title,
                                      style: TextStyle(
                                        color: colors.textPrimary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      related.author,
                                      style: TextStyle(
                                        color: colors.textMuted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: colors.icon),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionLink extends StatelessWidget {
  const _ActionLink({
    required this.color,
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
  });

  final Color color;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (trailing != null && trailing!.trim().isNotEmpty)
                Text(
                  trailing!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
