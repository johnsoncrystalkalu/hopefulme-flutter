import 'package:hopefulme_flutter/features/auth/data/auth_repository.dart';
import 'package:hopefulme_flutter/features/search/models/search_result.dart';

class SearchRepository {
  SearchRepository(this._authRepository);

  final AuthRepository _authRepository;

  Future<SearchResult> search({
    required String query,
    required String type,
    int page = 1,
  }) async {
    final normalizedType = type == 'all' ? '' : '/$type';
    final response = await _authRepository.get(
      'search$normalizedType',
      queryParameters: {
        'q': query,
        'page': page,
      },
    );
    return SearchResult.fromJson(response);
  }
}
