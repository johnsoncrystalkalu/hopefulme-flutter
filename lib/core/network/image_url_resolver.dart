class ImageUrlResolver {
  const ImageUrlResolver._();

  static const String _baseUrl = 'https://ahopefulme.com';
  static final Uri _baseUri = Uri.parse(_baseUrl);
  // static const String _baseUrl = 'http://127.0.0.1:8000';

  static String resolve(String? url) {
    final trimmed = _sanitize(url);
    if (trimmed.isEmpty) {
      return '';
    }

    if (_isAbsoluteUrl(trimmed)) {
      return _normalizeAbsoluteUrl(trimmed);
    }

    if (trimmed.startsWith('//')) {
      return _normalizeAbsoluteUrl('https:$trimmed');
    }

    return _resolveRelativeUrl(trimmed);
  }

  static String resolveOriginal(String? url) {
    return resolve(url);
  }

  static String avatar(String? url, {int size = 80}) {
    final trimmed = _sanitize(url);
    if (trimmed.isEmpty) {
      return '';
    }

    final resolved = resolve(trimmed);

    if (size > 100) {
      return resolved;
    }

    if ((_isAbsoluteUrl(trimmed) || trimmed.startsWith('//')) &&
        !resolved.contains('ahopefulme.com')) {
      return resolved;
    }

    final cloudflarePattern = RegExp(r'/cdn-cgi/image/[^/]*/');
    final stripped = resolved.replaceFirst(cloudflarePattern, '/');

    if (stripped.contains('/storage/')) {
      return stripped.replaceFirst(
        '/storage/',
        '/cdn-cgi/image/width=$size,quality=80,onerror=redirect/storage/',
      );
    }

    return stripped;
  }

  static String thumbnail(String? url, {int size = 160}) {
    return resolve(url);
  }

  static bool _isAbsoluteUrl(String value) {
    return value.startsWith('http://') || value.startsWith('https://');
  }

  static String _sanitize(String? value) {
    return value?.trim().replaceAll('\\', '/') ?? '';
  }

  static String _normalizeAbsoluteUrl(String value) {
    final uri = Uri.tryParse(Uri.encodeFull(value));
    return uri?.toString() ?? value;
  }

  static String _resolveRelativeUrl(String value) {
    final normalizedValue = value.replaceFirst(RegExp(r'^\./+'), '');
    final encodedValue = Uri.encodeFull(normalizedValue);
    return _baseUri.resolve(encodedValue).toString();
  }
}
