import 'package:flutter/foundation.dart';

class AppConfig {
  const AppConfig({required this.baseUrl});

  static const String appName = 'HopefulMe';
  static const Duration requestTimeout = Duration(seconds: 35);

  final String baseUrl;

  factory AppConfig.fromEnvironment() {
    const configuredBaseUrl = String.fromEnvironment('API_BASE_URL');

    return AppConfig(
      baseUrl: configuredBaseUrl.isNotEmpty
          ? configuredBaseUrl
          : _defaultBaseUrl(),
    );
  }

  static String _defaultBaseUrl() {
    if (kIsWeb) {
      return 'http://127.0.0.1:8000/api';
    }

    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'http://10.0.2.2:8000/api',
      _ => 'http://127.0.0.1:8000/api',
    };
  }
}
