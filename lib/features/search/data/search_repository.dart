import 'package:hopefulme_flutter/features/auth/data/auth_repository.dart';
import 'package:hopefulme_flutter/core/storage/page_cache.dart';
import 'package:hopefulme_flutter/features/search/models/search_result.dart';

class SearchRepository {
  SearchRepository(this._authRepository, {PageCache? cache})
    : _cache = cache ?? PageCache();

  final AuthRepository _authRepository;
  final PageCache _cache;

  Future<SearchResult> search({
    required String query,
    required String type,
    int page = 1,
  }) async {
    final normalizedType = type == 'all' ? '' : '/$type';
    final key = 'search:$type:${query.trim().toLowerCase()}:$page';
    try {
      final response = await _authRepository.get(
        'search$normalizedType',
        queryParameters: {
          'q': query,
          'page': page,
        },
      );
      await _cache.save(key, response);
      return SearchResult.fromJson(response);
    } catch (error) {
      final cached = await _cache.read(key);
      if (cached != null) {
        return SearchResult.fromJson(cached);
      }
      rethrow;
    }
  }
}
