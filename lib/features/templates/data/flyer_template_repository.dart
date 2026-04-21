import 'package:hopefulme_flutter/core/storage/page_cache.dart';
import 'package:hopefulme_flutter/features/auth/data/auth_repository.dart';
import 'package:hopefulme_flutter/features/templates/models/flyer_template_models.dart';

class FlyerTemplateRepository {
  FlyerTemplateRepository(this._authRepository, {PageCache? cache})
    : _cache = cache ?? PageCache();

  final AuthRepository _authRepository;
  final PageCache _cache;

  Future<FlyerTemplatePage> fetchTemplates({String category = 'all'}) async {
    final normalized = category.trim().isEmpty
        ? 'all'
        : category.trim().toLowerCase();
    final cacheKey = 'flyer-templates:$normalized';

    try {
      final response = await _authRepository.get(
        'flyer-templates',
        queryParameters: <String, dynamic>{
          if (normalized != 'all') 'category': normalized,
        },
      );
      await _cache.save(cacheKey, response);
      return FlyerTemplatePage.fromJson(response);
    } catch (error) {
      final cached = await _cache.read(cacheKey);
      if (cached != null) {
        return FlyerTemplatePage.fromJson(cached);
      }
      rethrow;
    }
  }

  Future<FlyerTemplateItem> fetchTemplate(int id) async {
    final cacheKey = 'flyer-template:$id';

    try {
      final response = await _authRepository.get('flyer-templates/$id');
      await _cache.save(cacheKey, response);
      return FlyerTemplateItem.fromJson(
        response['template'] as Map<String, dynamic>? ?? <String, dynamic>{},
      );
    } catch (error) {
      final cached = await _cache.read(cacheKey);
      if (cached != null) {
        return FlyerTemplateItem.fromJson(
          cached['template'] as Map<String, dynamic>? ?? <String, dynamic>{},
        );
      }
      rethrow;
    }
  }

  Future<String> buildWebFallbackUrl(String webBaseUrl) async {
    final normalizedPath = '/templates';
    final target = '${webBaseUrl.trim()}$normalizedPath';

    try {
      final bridged = await _authRepository.createWebSessionUrl(target);
      if (bridged.trim().isNotEmpty) {
        return bridged.trim();
      }
    } catch (_) {
      // Fall back to direct URL.
    }

    return target;
  }
}
