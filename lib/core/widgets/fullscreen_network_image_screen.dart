import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';
import 'package:http/http.dart' as http;
import 'package:hopefulme_flutter/core/widgets/app_network_image.dart';
import 'package:hopefulme_flutter/core/widgets/app_toast.dart';

class FullscreenNetworkImageScreen extends StatefulWidget {
  const FullscreenNetworkImageScreen({required this.imageUrl, super.key});

  final String imageUrl;

  static Future<void> show(BuildContext context, {required String imageUrl}) {
    if (imageUrl.trim().isEmpty) {
      return Future<void>.value();
    }

    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FullscreenNetworkImageScreen(imageUrl: imageUrl),
      ),
    );
  }

  @override
  State<FullscreenNetworkImageScreen> createState() =>
      _FullscreenNetworkImageScreenState();
}

class _FullscreenNetworkImageScreenState
    extends State<FullscreenNetworkImageScreen> {
  bool _isSaving = false;

  Future<void> _showImageActions() async {
    await HapticFeedback.mediumImpact();
    if (!mounted) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download_rounded),
                  title: Text(
                    _isSaving ? 'Saving image...' : 'Save to phone',
                  ),
                  enabled: !_isSaving,
                  onTap: _isSaving
                      ? null
                      : () async {
                          Navigator.of(context).pop();
                          await _saveImage();
                        },
                ),
                ListTile(
                  leading: const Icon(Icons.close_rounded),
                  title: const Text('Cancel'),
                  onTap: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _saveImage() async {
    final resolvedUrl = widget.imageUrl.trim();
    if (resolvedUrl.isEmpty || _isSaving) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final uri = Uri.tryParse(resolvedUrl);
      if (uri == null) {
        throw const FormatException('Invalid image URL');
      }

      final response = await http.get(uri);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'Image request failed with status ${response.statusCode}',
        );
      }

      final extension = _inferImageExtension(uri);
      final tempFile = File(
        '${Directory.systemTemp.path}${Platform.pathSeparator}'
        'hopefulme_${DateTime.now().millisecondsSinceEpoch}.$extension',
      );
      await tempFile.writeAsBytes(response.bodyBytes, flush: true);

      final saved = await GallerySaver.saveImage(tempFile.path);
      if (!mounted) {
        return;
      }

      if (saved == true) {
        AppToast.success(context, 'Image saved to your gallery.');
      } else {
        AppToast.info(context, 'Could not save image right now.');
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      AppToast.error(context, error);
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  String _inferImageExtension(Uri uri) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: GestureDetector(
          onLongPress: _showImageActions,
          child: InteractiveViewer(
            minScale: 1,
            maxScale: 4,
            child: SizedBox.expand(
              child: AppNetworkImage(
                imageUrl: widget.imageUrl,
                fit: BoxFit.contain,
                backgroundColor: Colors.black,
                placeholderIcon: Icons.photo_outlined,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
