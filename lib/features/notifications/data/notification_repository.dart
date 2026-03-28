import 'package:hopefulme_flutter/features/auth/data/auth_repository.dart';
import 'package:hopefulme_flutter/core/storage/page_cache.dart';
import 'package:hopefulme_flutter/features/notifications/models/app_notification.dart';

class NotificationRepository {
  NotificationRepository(this._authRepository, {PageCache? cache})
    : _cache = cache ?? PageCache();

  final AuthRepository _authRepository;
  final PageCache _cache;

  Future<NotificationPage> fetchPage({int page = 1}) async {
    final key = 'notifications:$page';
    try {
      final response = await _authRepository.get(
        'notifications',
        queryParameters: {'page': page},
      );
      await _cache.save(key, response);
      return NotificationPage.fromJson(response);
    } catch (error) {
      final cached = await _cache.read(key);
      if (cached != null) {
        return NotificationPage.fromJson(cached);
      }
      rethrow;
    }
  }

  Future<void> markRead(String id) async {
    await _authRepository.patch('notifications/$id/read');
  }

  Future<void> markAllRead() async {
    await _authRepository.post('notifications/read-all');
  }
}
