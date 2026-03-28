import 'package:hopefulme_flutter/features/auth/data/auth_repository.dart';
import 'package:hopefulme_flutter/core/storage/page_cache.dart';
import 'package:hopefulme_flutter/features/content/models/content_detail.dart';

class ContentRepository {
  ContentRepository(this._authRepository, {PageCache? cache})
    : _cache = cache ?? PageCache();

  final AuthRepository _authRepository;
  final PageCache _cache;

  Future<ContentDetail> fetchPost(int id) async {
    final key = 'post:$id';
    try {
      final response = await _authRepository.get('posts/$id');
      await _cache.save(key, response);
      return ContentDetail.fromApi(
        response['post'] as Map<String, dynamic>? ?? <String, dynamic>{},
        kind: 'post',
      );
    } catch (error) {
      final cached = await _cache.read(key);
      if (cached != null) {
        return ContentDetail.fromApi(
          cached['post'] as Map<String, dynamic>? ?? <String, dynamic>{},
          kind: 'post',
        );
      }
      rethrow;
    }
  }

  Future<ContentDetail> fetchBlog(int id) async {
    final key = 'blog:$id';
    try {
      final response = await _authRepository.get('blogs/$id');
      await _cache.save(key, response);
      return ContentDetail.fromApi(
        response['blog'] as Map<String, dynamic>? ?? <String, dynamic>{},
        kind: 'blog',
      );
    } catch (error) {
      final cached = await _cache.read(key);
      if (cached != null) {
        return ContentDetail.fromApi(
          cached['blog'] as Map<String, dynamic>? ?? <String, dynamic>{},
          kind: 'blog',
        );
      }
      rethrow;
    }
  }

  Future<InspirationDetail> fetchInspiration(int id) async {
    final response = await _authRepository.get('inspire/$id');
    return InspirationDetail.fromApi(
      response['inspiration'] as Map<String, dynamic>? ?? <String, dynamic>{},
    );
  }

  Future<InspirationPage> fetchInspirationInbox({int page = 1}) async {
    final key = 'inspire-inbox:$page';
    try {
      final response = await _authRepository.get(
        'inspire/inbox',
        queryParameters: {'page': page},
      );
      await _cache.save(key, response);
      return InspirationPage.fromApi(response);
    } catch (error) {
      final cached = await _cache.read(key);
      if (cached != null) {
        return InspirationPage.fromApi(cached);
      }
      rethrow;
    }
  }

  Future<ContentComment> addComment({
    required String kind,
    required int contentId,
    required String comment,
  }) async {
    final response = await _authRepository.post(
      'comments',
      body: {
        'commentable_type': kind,
        'commentable_id': contentId,
        'comment': comment,
      },
    );

    return ContentComment.fromJson(
      response['comment'] as Map<String, dynamic>? ?? <String, dynamic>{},
    );
  }
}
