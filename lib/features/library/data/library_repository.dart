import 'package:hopefulme_flutter/features/auth/data/auth_repository.dart';
import 'package:hopefulme_flutter/core/storage/page_cache.dart';
import 'package:hopefulme_flutter/features/library/models/library_models.dart';

class LibraryRepository {
  LibraryRepository(this._authRepository, {PageCache? cache})
    : _cache = cache ?? PageCache();

  static const List<String> categories = <String>[
    'All',
    'Motivation',
    'Faith',
    'Self-help',
    'Inspiration',
    'Self-development',
    'Novel',
    'Story book',
    'Academic',
    'Fiction',
    'Other',
  ];

  final AuthRepository _authRepository;
  final PageCache _cache;

  Future<LibraryPage> fetchLibrary({
    int page = 1,
    String category = 'All',
  }) async {
    final normalizedCategory = category.trim().isEmpty || category == 'All'
        ? 'All'
        : category.trim();
    final key = 'library:$normalizedCategory:$page';
    try {
      final response = await _authRepository.get(
        'library',
        queryParameters: {
          'page': page,
          if (normalizedCategory != 'All') 'category': normalizedCategory,
        },
      );
      await _cache.save(key, response);
      return LibraryPage.fromJson(response);
    } catch (error) {
      final cached = await _cache.read(key);
      if (cached != null) {
        return LibraryPage.fromJson(cached);
      }
      rethrow;
    }
  }

  Future<LibraryDetailResponse> fetchLibraryItem(int id) async {
    final key = 'library-item:$id';
    try {
      final response = await _authRepository.get('library/$id');
      await _cache.save(key, response);
      return LibraryDetailResponse.fromJson(response);
    } catch (error) {
      final cached = await _cache.read(key);
      if (cached != null) {
        return LibraryDetailResponse.fromJson(cached);
      }
      rethrow;
    }
  }
}
