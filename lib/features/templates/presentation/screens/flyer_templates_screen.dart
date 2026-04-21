import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:hopefulme_flutter/app/theme/app_theme.dart';
import 'package:hopefulme_flutter/core/presentation/screens/web_page_screen.dart';
import 'package:hopefulme_flutter/core/widgets/app_status_state.dart';
import 'package:hopefulme_flutter/features/templates/data/flyer_template_repository.dart';
import 'package:hopefulme_flutter/features/templates/models/flyer_template_models.dart';
import 'package:hopefulme_flutter/features/templates/presentation/screens/flyer_template_editor_screen.dart';

class FlyerTemplatesScreen extends StatefulWidget {
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
  bool _isLoading = true;
  String _selectedCategory = 'all';
  String? _error;
  bool _endpointMissing = false;
  List<String> _categories = const <String>['all'];
  List<FlyerTemplateItem> _templates = const <FlyerTemplateItem>[];

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
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      final message = error.toString();
      setState(() {
        _error = _friendlyErrorMessage(message);
        _endpointMissing =
            message.toLowerCase().contains('could not be found') ||
            message.toLowerCase().contains('(404)');
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
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: colors.brand.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: colors.brand.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: colors.brand.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Icon(
                            Icons.photo,
                            size: 16,
                            color: colors.brand,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Text(
                              //   'Why we added this feature',
                              //   style: TextStyle(
                              //     color: colors.textPrimary,
                              //     fontSize: 12.5,
                              //     fontWeight: FontWeight.w800,
                              //   ),
                              // ),
                             // const SizedBox(height: 6),
                              Text(
                                'Create your own HopefulMe flyers, birthday cards and posters. Share them and invite more friends to the community.',
                                style: TextStyle(
                                  color: colors.textSecondary,
                                  fontSize: 12,
                                  height: 1.45,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Choose a template category and create your flyer.',
                    style: TextStyle(
                      color: colors.textMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
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
                                              const ColoredBox(
                                                color: Color(0xFFF1F5F9),
                                                child: Icon(
                                                  Icons.image_not_supported,
                                                ),
                                              ),
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
