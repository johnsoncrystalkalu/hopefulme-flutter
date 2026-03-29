import 'package:hopefulme_flutter/core/utils/json_parsing.dart';

class LibraryPage {
  const LibraryPage({
    required this.items,
    required this.featured,
    required this.currentPage,
    required this.lastPage,
    required this.total,
  });

  final List<LibraryItem> items;
  final List<LibraryItem> featured;
  final int currentPage;
  final int lastPage;
  final int total;

  bool get hasMore => currentPage < lastPage;

  factory LibraryPage.fromJson(Map<String, dynamic> json) {
    final meta = json['meta'] as Map<String, dynamic>? ?? <String, dynamic>{};
    return LibraryPage(
      items: _mapItems(json['data']),
      featured: _mapItems(json['featured']),
      currentPage: parseInt(meta['current_page'], fallback: 1),
      lastPage: parseInt(meta['last_page'], fallback: 1),
      total: parseInt(meta['total']),
    );
  }

  static List<LibraryItem> _mapItems(dynamic value) {
    final items = value as List<dynamic>? ?? const <dynamic>[];
    return items
        .whereType<Map<String, dynamic>>()
        .map(LibraryItem.fromJson)
        .toList();
  }
}

class LibraryDetailResponse {
  const LibraryDetailResponse({required this.item, required this.related});

  final LibraryItem item;
  final List<LibraryItem> related;

  factory LibraryDetailResponse.fromJson(Map<String, dynamic> json) {
    return LibraryDetailResponse(
      item: LibraryItem.fromJson(
        json['library'] as Map<String, dynamic>? ?? <String, dynamic>{},
      ),
      related: (json['related'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(LibraryItem.fromJson)
          .toList(),
    );
  }
}

class LibraryItem {
  const LibraryItem({
    required this.id,
    required this.title,
    required this.author,
    required this.tagline,
    required this.description,
    required this.coverUrl,
    required this.category,
    required this.featured,
    required this.published,
    required this.views,
    required this.downloads,
    required this.createdAt,
    required this.links,
  });

  final int id;
  final String title;
  final String author;
  final String tagline;
  final String description;
  final String coverUrl;
  final String category;
  final bool featured;
  final bool published;
  final int views;
  final int downloads;
  final String createdAt;
  final LibraryLinks links;

  factory LibraryItem.fromJson(Map<String, dynamic> json) {
    return LibraryItem(
      id: parseInt(json['id']),
      title: json['title']?.toString() ?? '',
      author: json['author']?.toString() ?? '',
      tagline: json['tagline']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      coverUrl: json['cover_url']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      featured: parseBool(json['featured']),
      published: parseBool(json['published']),
      views: parseInt(json['views']),
      downloads: parseInt(json['downloads']),
      createdAt: json['created_at']?.toString() ?? '',
      links: LibraryLinks.fromJson(
        json['links'] as Map<String, dynamic>? ?? <String, dynamic>{},
      ),
    );
  }
}

class LibraryLinks {
  const LibraryLinks({
    required this.pdf,
    required this.epub,
    required this.apk,
    required this.apkUrl,
    required this.apkPackage,
    required this.externalDownloadUrl,
    required this.purchaseUrl,
    required this.purchaseLabel,
    required this.purchasePrice,
    required this.appstoreUrl,
  });

  final String pdf;
  final String epub;
  final String apk;
  final String apkUrl;
  final String apkPackage;
  final String externalDownloadUrl;
  final String purchaseUrl;
  final String purchaseLabel;
  final String purchasePrice;
  final String appstoreUrl;

  bool get hasPdf => pdf.trim().isNotEmpty;
  bool get hasEpub => epub.trim().isNotEmpty;
  bool get hasApk => apk.trim().isNotEmpty || apkUrl.trim().isNotEmpty;
  bool get hasExternalDownload => externalDownloadUrl.trim().isNotEmpty;
  bool get hasPurchase => purchaseUrl.trim().isNotEmpty;
  bool get hasAppStore => appstoreUrl.trim().isNotEmpty;

  factory LibraryLinks.fromJson(Map<String, dynamic> json) {
    return LibraryLinks(
      pdf: json['pdf']?.toString() ?? '',
      epub: json['epub']?.toString() ?? '',
      apk: json['apk']?.toString() ?? '',
      apkUrl: json['apk_url']?.toString() ?? '',
      apkPackage: json['apk_package']?.toString() ?? '',
      externalDownloadUrl: json['external_download_url']?.toString() ?? '',
      purchaseUrl: json['purchase_url']?.toString() ?? '',
      purchaseLabel: json['purchase_label']?.toString() ?? '',
      purchasePrice: json['purchase_price']?.toString() ?? '',
      appstoreUrl: json['appstore_url']?.toString() ?? '',
    );
  }
}
