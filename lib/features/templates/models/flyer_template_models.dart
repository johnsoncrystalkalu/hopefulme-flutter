import 'package:hopefulme_flutter/core/utils/json_parsing.dart';

class FlyerTemplatePage {
  const FlyerTemplatePage({
    required this.categories,
    required this.selectedCategory,
    required this.templates,
  });

  final List<String> categories;
  final String selectedCategory;
  final List<FlyerTemplateItem> templates;

  factory FlyerTemplatePage.fromJson(Map<String, dynamic> json) {
    final categories =
        (json['categories'] as List<dynamic>? ?? const <dynamic>[])
            .map((value) => value.toString().trim().toLowerCase())
            .where((value) => value.isNotEmpty)
            .toList(growable: false);

    final templates = (json['templates'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(FlyerTemplateItem.fromJson)
        .toList(growable: false);

    return FlyerTemplatePage(
      categories: categories.isEmpty ? const <String>['all'] : categories,
      selectedCategory:
          json['selected_category']?.toString().trim().toLowerCase() ?? 'all',
      templates: templates,
    );
  }
}

class FlyerTemplateItem {
  const FlyerTemplateItem({
    required this.id,
    required this.name,
    required this.slug,
    required this.category,
    required this.imageUrl,
    required this.sortOrder,
    required this.config,
    this.isOfflineAsset = false,
  });

  final int id;
  final String name;
  final String slug;
  final String category;
  final String imageUrl;
  final int sortOrder;
  final Map<String, dynamic> config;
  final bool isOfflineAsset;

  factory FlyerTemplateItem.fromJson(Map<String, dynamic> json) {
    return FlyerTemplateItem(
      id: parseInt(json['id']),
      name: json['name']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      category: json['category']?.toString().toLowerCase() ?? 'flyers',
      imageUrl: json['image_url']?.toString() ?? '',
      sortOrder: parseInt(json['sort_order']),
      config: (json['config'] as Map<String, dynamic>?) ?? <String, dynamic>{},
      isOfflineAsset: parseBool(json['is_offline_asset']),
    );
  }
}
