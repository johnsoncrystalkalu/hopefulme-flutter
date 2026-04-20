import 'dart:io';

import 'package:gallery_saver_plus/gallery_saver.dart';
import 'package:http/http.dart' as http;

class ImageDownloadHelper {
  static Future<bool> saveNetworkImage(String imageUrl) async {
    final resolvedUrl = imageUrl.trim();
    if (resolvedUrl.isEmpty) {
      return false;
    }

    final uri = Uri.tryParse(resolvedUrl);
    if (uri == null) {
      return false;
    }

    final response = await http.get(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return false;
    }

    final extension = _inferImageExtension(uri);
    final tempFile = File(
      '${Directory.systemTemp.path}${Platform.pathSeparator}'
      'hopefulme_${DateTime.now().millisecondsSinceEpoch}.$extension',
    );
    await tempFile.writeAsBytes(response.bodyBytes, flush: true);
    return await GallerySaver.saveImage(tempFile.path) == true;
  }

  static String _inferImageExtension(Uri uri) {
    final path = uri.path.toLowerCase();
    if (path.endsWith('.png')) {
      return 'png';
    }
    if (path.endsWith('.webp')) {
      return 'webp';
    }
    if (path.endsWith('.gif')) {
      return 'gif';
    }
    return 'jpg';
  }
}
