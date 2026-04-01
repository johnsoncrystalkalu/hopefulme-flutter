class ImageUrlResolver {
  const ImageUrlResolver._();

  //static const String _baseUrl = 'https://ahopefulme.com';
  static const String _baseUrl = 'http://127.0.0.1:8000';

  static String resolve(String? url) {
    if (url == null || url.trim().isEmpty) {
      return '';
    }

    final trimmed = url.trim();

    if (_isAbsoluteUrl(trimmed)) {
      return trimmed;
    }

    return '$_baseUrl/$trimmed';
  }

  static String resolveOriginal(String? url) {
    return resolve(url);
  }

  static String avatar(String? url, {int size = 80}) {
    if (url == null || url.trim().isEmpty) {
      return '';
    }

    final trimmed = url.trim();

    String resolved;

    if (_isAbsoluteUrl(trimmed)) {
      resolved = trimmed;
    } else {
      resolved = '$_baseUrl/$trimmed';
    }

    if (size <= 100) {
      // Strip any existing Cloudflare transformation first
      final cloudflarePattern = RegExp(r'/cdn-cgi/image/[^/]*/');
      final stripped = resolved.replaceFirst(cloudflarePattern, '/');

      return stripped.replaceFirst(
        '/storage/',
        '/cdn-cgi/image/width=$size,quality=75/storage/',
      );
    }

    return resolved;
  }

  static String thumbnail(String? url, {int size = 160}) {
    return resolve(url);
  }

  static bool _isAbsoluteUrl(String value) {
    return value.startsWith('http://') || value.startsWith('https://');
  }
}
