import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:hopefulme_flutter/app/theme/app_theme.dart';
import 'package:hopefulme_flutter/core/presentation/screens/web_page_screen.dart';
import 'package:hopefulme_flutter/core/widgets/app_status_state.dart';
import 'package:hopefulme_flutter/features/templates/data/flyer_template_repository.dart';
import 'package:hopefulme_flutter/features/templates/models/flyer_template_models.dart';
import 'package:hopefulme_flutter/features/templates/presentation/screens/flyer_template_editor_screen.dart';

class FlyerTemplatesScreen extends StatefulWidget {
  static const String routeName = '/flyer-templates';

  const FlyerTemplatesScreen({
    required this.repository,
    required this.webBaseUrl,
    super.key,
  });

  final FlyerTemplateRepository repository;
  final String webBaseUrl;

  @override
  State<FlyerTemplatesScreen> createState() => _FlyerTemplatesScreenState();
}

class _FlyerTemplatesScreenState extends State<FlyerTemplatesScreen> {
  static const String _networkImageFallbackAsset = 'assets/templates/1.webp';
  bool _isLoading = true;
  bool _isOfflineMode = false;
  String _selectedCategory = 'all';
  String? _error;
  bool _endpointMissing = false;
  List<String> _categories = const <String>['all'];
  List<FlyerTemplateItem> _templates = const <FlyerTemplateItem>[];

  static const List<FlyerTemplateItem> _offlineTemplates = <FlyerTemplateItem>[
    FlyerTemplateItem(
      id: -1,
      name: 'Offline Template 1',
      slug: 'offline-template-1',
      category: 'flyers',
      imageUrl: 'assets/templates/1.webp',
      sortOrder: 1,
      config: <String, dynamic>{},
      isOfflineAsset: true,
    ),
    FlyerTemplateItem(
      id: -2,
      name: 'Offline Template 2',
      slug: 'offline-template-2',
      category: 'flyers',
      imageUrl: 'assets/templates/2.webp',
      sortOrder: 2,
      config: <String, dynamic>{},
      isOfflineAsset: true,
    ),
  ];

  String _friendlyErrorMessage(String rawError) {
    if (!kReleaseMode) {
      return rawError;
    }
    return 'Something went wrong. Please try again.';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({String? category}) async {
    final targetCategory = (category ?? _selectedCategory).trim().toLowerCase();

    setState(() {
      _isLoading = true;
      _error = null;
      _endpointMissing = false;
      _isOfflineMode = false;
      _selectedCategory = targetCategory;
    });

    try {
      final page = await widget.repository.fetchTemplates(
        category: targetCategory,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _categories = page.categories;
        _selectedCategory = page.selectedCategory;
        _templates = page.templates;
        _isOfflineMode = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      final message = error.toString();
      final lower = message.toLowerCase();
      final canUseOfflineFallback =
          lower.contains('socketexception') ||
          lower.contains('failed host lookup') ||
          lower.contains('connection') ||
          lower.contains('network') ||
          lower.contains('timed out') ||
          lower.contains('timeout') ||
          lower.contains('(500)');

      if (canUseOfflineFallback) {
        final offline = _offlineTemplates
            .where(
              (item) =>
                  targetCategory == 'all' || item.category == targetCategory,
            )
            .toList(growable: false);
        setState(() {
          _categories = const <String>['all', 'flyers'];
          _selectedCategory = targetCategory == 'all' ? 'all' : targetCategory;
          _templates = offline;
          _error = null;
          _endpointMissing = false;
          _isOfflineMode = true;
        });
        return;
      }

      setState(() {
        _error = _friendlyErrorMessage(message);
        _endpointMissing =
            lower.contains('could not be found') || lower.contains('(404)');
        _isOfflineMode = false;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _openTemplate(FlyerTemplateItem template) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => FlyerTemplateEditorScreen(
          template: template,
          repository: widget.repository,
        ),
      ),
    );
  }

  Future<void> _openWebFallback() async {
    final url = await widget.repository.buildWebFallbackUrl(widget.webBaseUrl);
    if (!mounted) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => WebPageScreen(title: 'Flyer Templates', url: url),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: colors.scaffold,
      appBar: AppBar(title: const Text('Flyer Templates')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _endpointMissing
                ? _EndpointUnavailableState(
                    error: _error!,
                    onRetry: _load,
                    onOpenWebFallback: _openWebFallback,
                  )
                : AppStatusState.fromError(
                    error: _error!,
                    actionLabel: 'Try again',
                    onAction: _load,
                  )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_isOfflineMode) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: colors.accentSoft,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colors.border),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.wifi_off_rounded,
                            size: 16,
                            color: colors.accentSoftText,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Offline mode: using local templates. Connect to internet to load new templates.',
                              style: TextStyle(
                                color: colors.accentSoftText,
                                fontSize: 12,
                                height: 1.35,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colors.border),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.photo, size: 16, color: colors.textMuted),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Create flyers, cards, and posters. Share and invite friends.',
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: 12,
                              height: 1.4,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.center,
                    child: Text(
                      'Choose a template category',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 44,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _categories.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final category = _categories[index];
                        final isActive = category == _selectedCategory;
                        return FilterChip(
                          label: Text(
                            category == 'all'
                                ? 'All'
                                : '${category[0].toUpperCase()}${category.substring(1)}',
                          ),
                          selected: isActive,
                          onSelected: (_) => _load(category: category),
                          showCheckmark: false,
                          labelStyle: TextStyle(
                            color: isActive
                                ? Colors.white
                                : colors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                          backgroundColor: colors.surface,
                          selectedColor: colors.brand,
                          side: BorderSide(
                            color: isActive
                                ? colors.brand
                                : colors.borderStrong,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_templates.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: colors.borderStrong),
                      ),
                      child: Text(
                        'No templates found in this category yet.',
                        style: TextStyle(
                          color: colors.textMuted,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  else
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.82,
                          ),
                      itemCount: _templates.length,
                      itemBuilder: (context, index) {
                        final template = _templates[index];
                        return InkWell(
                          onTap: () => _openTemplate(template),
                          borderRadius: BorderRadius.circular(18),
                          child: Container(
                            decoration: BoxDecoration(
                              color: colors.surface,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: colors.borderStrong),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (!template.isOfflineAsset)
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(18),
                                      ),
                                      child: Image.network(
                                        template.imageUrl,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                        filterQuality: FilterQuality.low,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                Image.asset(
                                                  _networkImageFallbackAsset,
                                                  width: double.infinity,
                                                  fit: BoxFit.cover,
                                                  filterQuality:
                                                      FilterQuality.low,
                                                ),
                                      ),
                                    ),
                                  )
                                else
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(18),
                                      ),
                                      child: Image.asset(
                                        template.imageUrl,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                        filterQuality: FilterQuality.low,
                                      ),
                                    ),
                                  ),
                                Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Text(
                                    template.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: colors.textPrimary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
    );
  }
}

class _EndpointUnavailableState extends StatelessWidget {
  const _EndpointUnavailableState({
    required this.error,
    required this.onRetry,
    required this.onOpenWebFallback,
  });

  final String error;
  final Future<void> Function() onRetry;
  final Future<void> Function() onOpenWebFallback;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.borderStrong),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Templates API is not available yet on this server.',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                error,
                style: TextStyle(
                  color: colors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton(
                    onPressed: onRetry,
                    child: const Text('Try Again'),
                  ),
                  OutlinedButton(
                    onPressed: onOpenWebFallback,
                    child: const Text('Open Web Version'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
