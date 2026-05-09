import 'package:hopefulme_flutter/features/auth/data/auth_repository.dart';
import 'package:hopefulme_flutter/features/daily_checkin/models/daily_checkin_models.dart';

class DailyCheckinRepository {
  DailyCheckinRepository(this._authRepository);

  final AuthRepository _authRepository;

  Future<DailyCheckinEntry?> fetchToday() async {
    final response = await _authRepository.get('daily-checkins/today');
    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      return null;
    }
    return DailyCheckinEntry.fromJson(data);
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
    final response = await _authRepository.get('daily-checkins/summary');
    return DailyCheckinSummary.fromJson(response);
  }

  Future<List<DailyCheckinEntry>> fetchHistory({int page = 1}) async {
    final response = await _authRepository.get(
      'daily-checkins/history',
      queryParameters: <String, dynamic>{'page': page},
    );
    final data = response['data'] as List<dynamic>? ?? const <dynamic>[];
    return data
        .whereType<Map<String, dynamic>>()
        .map(DailyCheckinEntry.fromJson)
        .toList();
  }
}
