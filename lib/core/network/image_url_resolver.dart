class ImageUrlResolver {
  const ImageUrlResolver._();

  static const String _fallbackCloudName = String.fromEnvironment(
    'CLOUDINARY_CLOUD_NAME',
    defaultValue: 'daxsbltc3',
  );

  static String resolve(
    String rawUrl, {
    List<String> contextUrls = const <String>[],
  }) {
    final normalized = rawUrl.trim();
    if (normalized.isEmpty) {
      return '';
    }

    if (_isAbsoluteUrl(normalized)) {
      return normalized;
    }

    final cloudName = _findCloudName(contextUrls);
    if (cloudName != null) {
      return 'https://res.cloudinary.com/'
          '$cloudName/image/upload/w_1200,h_1200,c_limit,q_auto,f_auto/'
          '$normalized';
    }

    if (_fallbackCloudName.isNotEmpty) {
      return 'https://res.cloudinary.com/'
          '$_fallbackCloudName/image/upload/w_1200,h_1200,c_limit,q_auto,f_auto/'
          '$normalized';
    }

    return normalized;
  }

  static String resolveOriginal(
    String rawUrl, {
    List<String> contextUrls = const <String>[],
  }) {
    final normalized = rawUrl.trim();
    if (normalized.isEmpty) {
      return '';
    }

    if (_isAbsoluteUrl(normalized)) {
      return _stripCloudinaryTransformations(normalized);
    }

    final cloudName = _findCloudName(contextUrls);
    if (cloudName != null) {
      return 'https://res.cloudinary.com/'
          '$cloudName/image/upload/$normalized';
    }

    if (_fallbackCloudName.isNotEmpty) {
      return 'https://res.cloudinary.com/'
          '$_fallbackCloudName/image/upload/$normalized';
    }

    return normalized;
  }

  static String avatar(String url, {int size = 120}) {
    final normalized = url.trim();
    if (normalized.isEmpty) {
      return '';
    }

    final clean = resolveOriginal(normalized);

    if (!clean.contains('res.cloudinary.com/')) {
      return clean;
    }

    const marker = '/upload/';
    final markerIndex = clean.indexOf(marker);
    if (markerIndex == -1) {
      return clean;
    }

    final prefix = clean.substring(0, markerIndex + marker.length);
    final suffix = clean.substring(markerIndex + marker.length);

    return '${prefix}w_$size,h_$size,c_limit,q_auto,f_auto/$suffix';
  }

  static String thumbnail(String url, {int size = 160}) {
    final normalized = url.trim();
    if (normalized.isEmpty) {
      return '';
    }

    // Get the clean URL without any current high-res Cloudinary transformations
    final clean = resolveOriginal(normalized);

    // If it's not a Cloudinary URL, we return the original as we can't transform it
    if (!clean.contains('res.cloudinary.com/')) {
      return clean;
    }

    const marker = '/upload/';
    final markerIndex = clean.indexOf(marker);
    if (markerIndex == -1) {
      return clean;
    }

    final prefix = clean.substring(0, markerIndex + marker.length);
    final suffix = clean.substring(markerIndex + marker.length);

    // c_fill: aspect ratio crop, g_face: zoom in on faces, q_auto: optimized quality
    return '${prefix}w_$size,h_$size,c_fill,g_face,q_auto,f_auto/$suffix';
  }

  static bool _isAbsoluteUrl(String value) {
    return value.startsWith('http://') || value.startsWith('https://');
  }

  static String _stripCloudinaryTransformations(String url) {
    const marker = '/upload/';
    final markerIndex = url.indexOf(marker);
    if (markerIndex == -1 || !url.contains('res.cloudinary.com/')) {
      return url;
    }

    final prefix = url.substring(0, markerIndex + marker.length);
    final suffix = url.substring(markerIndex + marker.length);
    final segments = suffix.split('/');
    if (segments.isEmpty) {
      return url;
    }

    var index = 0;
    while (index < segments.length &&
        !_looksLikeCloudinaryPublicIdStart(segments[index])) {
      index++;
    }

    if (index == 0 || index >= segments.length) {
      return url;
    }

    return '$prefix${segments.sublist(index).join('/')}';
  }

  static bool _looksLikeCloudinaryPublicIdStart(String segment) {
    if (segment.isEmpty) {
      return false;
    }

    if (RegExp(r'^v\d+$').hasMatch(segment)) {
      return true;
    }

    return !_looksLikeCloudinaryTransformation(segment);
  }

  static bool _looksLikeCloudinaryTransformation(String segment) {
    if (segment.contains(',')) {
      return true;
    }

    return RegExp(
      r'^(?:'
      r'a_|ar_|b_|bo_|c_|co_|dpr_|e_|f_|fl_|g_|h_|l_|o_|q_|r_|t_|u_|w_|x_|y_|z_)',
    ).hasMatch(segment);
  }

  static String? _findCloudName(List<String> urls) {
    for (final url in urls) {
      final match = RegExp(r'res\.cloudinary\.com/([^/]+)/').firstMatch(url);
      if (match != null) {
        return match.group(1);
      }
    }
    return null;
  }
}
