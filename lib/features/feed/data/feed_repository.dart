import 'package:hopefulme_flutter/features/auth/data/auth_repository.dart';
import 'package:hopefulme_flutter/core/storage/page_cache.dart';
import 'package:hopefulme_flutter/features/feed/models/feed_dashboard.dart';
import 'package:hopefulme_flutter/features/feed/models/post.dart';

class FeedRepository {
  FeedRepository(this._authRepository, {PageCache? cache})
    : _cache = cache ?? PageCache();

  final AuthRepository _authRepository;
  final PageCache _cache;

  Future<FeedDashboard> fetchDashboard() async {
    const key = 'dashboard';
    try {
      final response = await _authRepository.get('feed');
      await _cache.save(key, response);
      return FeedDashboard.fromJson(response);
    } catch (error) {
      final cached = await _cache.read(key);
      if (cached != null) {
        return FeedDashboard.fromJson(cached);
      }
      rethrow;
    }
  }

  Future<List<Post>> fetchPosts() async {
    final page = await fetchPostsPage();
    return page.items
        .map(
          (entry) => Post(id: entry.id, title: entry.title, body: entry.body),
        )
        .toList();
  }

  Future<FeedEntryPage> fetchPostsPage({int page = 1, String? category}) async {
    final normalizedCategory =
        category == null || category.trim().isEmpty || category == 'All'
        ? null
        : category.trim();
    final key = normalizedCategory == null
        ? 'posts:$page'
        : 'posts:$normalizedCategory:$page';
    final queryParameters = <String, dynamic>{'page': page};
    if (normalizedCategory != null) {
      queryParameters['category'] = normalizedCategory;
    }
    try {
      final response = await _authRepository.get(
        'posts',
        queryParameters: queryParameters,
      );
      await _cache.save(key, response);
      return FeedEntryPage.fromJson(response);
    } catch (error) {
      final cached = await _cache.read(key);
      if (cached case final value?) {
        return FeedEntryPage.fromJson(value);
      }
      rethrow;
    }
  }

  Future<FeedEntryPage> fetchUpdatesPage({int page = 1}) async {
    final key = 'updates:$page';
    try {
      final response = await _authRepository.get(
        'updates',
        queryParameters: {'page': page},
      );
      await _cache.save(key, response);
      return FeedEntryPage.fromJson(response);
    } catch (error) {
      final cached = await _cache.read(key);
      if (cached != null) {
        return FeedEntryPage.fromJson(cached);
      }
      rethrow;
    }
  }

  Future<FeedUserPage> fetchMeetNewFriends({int page = 1}) async {
    final key = 'meet-new-friends:$page';
    try {
      final response = await _authRepository.get(
        'community/meet-new-friends',
        queryParameters: {'page': page},
      );
      await _cache.save(key, response);
      return FeedUserPage.fromJson(response);
    } catch (error) {
      final cached = await _cache.read(key);
      if (cached != null) {
        return FeedUserPage.fromJson(cached);
      }
      rethrow;
    }
  }

  Future<FeedUserPage> fetchTodayBirthdays({int page = 1}) async {
    final key = 'today-birthdays:$page';
    try {
      final response = await _authRepository.get(
        'community/birthdays',
        queryParameters: {'page': page},
      );
      await _cache.save(key, response);
      return FeedUserPage.fromJson(response);
    } catch (error) {
      final cached = await _cache.read(key);
      if (cached != null) {
        return FeedUserPage.fromJson(cached);
      }
      rethrow;
    }
  }

  Future<FeedEntryPage> fetchBlogsPage({int page = 1}) async {
    final key = 'blogs:$page';
    try {
      final response = await _authRepository.get(
        'blogs',
        queryParameters: {'page': page},
      );
      await _cache.save(key, response);
      return FeedEntryPage.fromJson(response);
    } catch (error) {
      final cached = await _cache.read(key);
      if (cached != null) {
        return FeedEntryPage.fromJson(cached);
      }
      rethrow;
    }
  }
}
