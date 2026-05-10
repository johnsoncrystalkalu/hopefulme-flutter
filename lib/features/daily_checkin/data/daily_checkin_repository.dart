import 'package:hopefulme_flutter/features/auth/data/auth_repository.dart';
import 'package:hopefulme_flutter/core/storage/page_cache.dart';
import 'package:hopefulme_flutter/features/daily_checkin/models/daily_checkin_models.dart';

class DailyCheckinRepository {
  DailyCheckinRepository(this._authRepository, {PageCache? cache})
    : _cache = cache ?? PageCache();

  final AuthRepository _authRepository;
  final PageCache _cache;

  Future<DailyCheckinEntry?> fetchToday() async {
    const key = 'daily_checkins:today';
    try {
      final response = await _authRepository.get('daily-checkins/today');
      await _cache.save(key, response);
      final data = response['data'];
      if (data is! Map<String, dynamic>) {
        return null;
      }
      return DailyCheckinEntry.fromJson(data);
    } catch (_) {
      final cached = await _cache.read(key);
      final data = cached?['data'];
      if (data is! Map<String, dynamic>) {
        return null;
      }
      return DailyCheckinEntry.fromJson(data);
    }
  }

  Future<(DailyCheckinEntry, String, List<String>)> saveCheckin({
    required String mood,
    required String energyLevel,
    required String focusArea,
    required String status,
    required int progress,
    required String goal,
    required String content,
  }) async {
    final response = await _authRepository.post(
      'daily-checkins/check-in',
      body: <String, dynamic>{
        'mood': mood,
        'energy_level': energyLevel,
        'focus_area': focusArea,
        'status': status,
        'progress': progress,
        'goal': goal,
        'content': content,
      },
    );

    final data = DailyCheckinEntry.fromJson(
      response['data'] as Map<String, dynamic>? ?? <String, dynamic>{},
    );
    final encouragement = response['encouragement']?.toString() ?? '';
    final suggestions = (response['suggestions'] as List<dynamic>? ?? const <dynamic>[])
        .map((item) => item.toString())
        .where((item) => item.trim().isNotEmpty)
        .toList();

    return (data, encouragement, suggestions);
  }

  Future<DailyCheckinSummary> fetchSummary() async {
    const key = 'daily_checkins:summary';
    try {
      final response = await _authRepository.get('daily-checkins/summary');
      await _cache.save(key, response);
      return DailyCheckinSummary.fromJson(response);
    } catch (_) {
      final cached = await _cache.read(key);
      if (cached != null) {
        return DailyCheckinSummary.fromJson(cached);
      }
      rethrow;
    }
  }

  Future<List<DailyCheckinEntry>> fetchHistory({int page = 1}) async {
    final key = 'daily_checkins:history:page:$page';
    try {
      final response = await _authRepository.get(
        'daily-checkins/history',
        queryParameters: <String, dynamic>{'page': page},
      );
      await _cache.save(key, response);
      final data = response['data'] as List<dynamic>? ?? const <dynamic>[];
      return data
          .whereType<Map<String, dynamic>>()
          .map(DailyCheckinEntry.fromJson)
          .toList();
    } catch (_) {
      final cached = await _cache.read(key);
      if (cached != null) {
        final data = cached['data'] as List<dynamic>? ?? const <dynamic>[];
        return data
            .whereType<Map<String, dynamic>>()
            .map(DailyCheckinEntry.fromJson)
            .toList();
      }
      rethrow;
    }
  }

  Future<void> deleteEntry(int id) async {
    await _authRepository.delete('daily-checkins/$id');
  }

  Future<void> deleteAllEntries() async {
    await _authRepository.delete('daily-checkins');
  }
}
