import 'package:flutter/foundation.dart';

class AppConfig {
  const AppConfig({required this.baseUrl, required this.iosAppStoreId});

  static const String appName = 'HopefulMe';
  static const Duration requestTimeout = Duration(seconds: 35);

  static const String oneSignalAppId = '416d7ded-013d-47fa-8269-f876e432e460';

  final String baseUrl;
  final String iosAppStoreId;

  String get webBaseUrl {
    final normalized = baseUrl.trim();
    if (normalized.endsWith('/api')) {
      return normalized.substring(0, normalized.length - 4);
    }
    if (normalized.endsWith('/api/')) {
      return normalized.substring(0, normalized.length - 5);
    }
    return normalized;
  }

  factory AppConfig.fromEnvironment() {
    const configuredBaseUrl = String.fromEnvironment('API_BASE_URL');
    const configuredIosAppStoreId = String.fromEnvironment('IOS_APP_STORE_ID');

    return AppConfig(
      baseUrl: configuredBaseUrl.isNotEmpty
          ? configuredBaseUrl
          : _defaultBaseUrl(),
      iosAppStoreId: configuredIosAppStoreId.trim(),
    );
  }

  static String _defaultBaseUrl() {
    if (kIsWeb) {
      return 'https://ahopefulme.com/api';
    }

    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'https://ahopefulme.com/api',
      _ => 'https://ahopefulme.com/api',
    };
  }
}
