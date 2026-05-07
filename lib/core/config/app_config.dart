import 'package:flutter/foundation.dart';

class AppConfig {
  const AppConfig({required this.baseUrl, required this.iosAppStoreId});

  static const String appName = 'HopefulMe';
  static const Duration requestTimeout = Duration(seconds: 35);

  static const String oneSignalAppId = '416d7ded-013d-47fa-8269-f876e432e460';
  // Replace test IDs with production IDs before release.
  static const String admobBannerHomeUnitId = String.fromEnvironment(
    'ADMOB_BANNER_HOME_UNIT_ID',
    defaultValue: 'ca-app-pub-3940256099942544/6300978111',
  );
  static const String admobBannerHomeSecondaryUnitId = String.fromEnvironment(
    'ADMOB_BANNER_HOME_SECONDARY_UNIT_ID',
    defaultValue: 'ca-app-pub-3940256099942544/6300978111',
  );
  static const String admobBannerGroupsUnitId = String.fromEnvironment(
    'ADMOB_BANNER_GROUPS_UNIT_ID',
    defaultValue: 'ca-app-pub-3940256099942544/6300978111',
  );

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
