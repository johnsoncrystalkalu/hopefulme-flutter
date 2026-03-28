import 'package:hopefulme_flutter/core/network/api_client.dart';
import 'package:hopefulme_flutter/features/feed/models/feed_item.dart';

class FeedService {
  FeedService({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<List<FeedItem>> fetchFeed() async {
    final payload = await _apiClient.get('/feed');

    final rawItems = switch (payload['data']) {
      List<dynamic> data => data,
      Map<String, dynamic> data when data['items'] is List<dynamic> =>
        data['items'] as List<dynamic>,
      _ when payload['items'] is List<dynamic> =>
        payload['items'] as List<dynamic>,
      _ => <dynamic>[],
    };

    return rawItems
        .whereType<Map<String, dynamic>>()
        .map(FeedItem.fromJson)
        .toList();
  }
}
