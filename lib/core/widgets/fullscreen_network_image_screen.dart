import 'package:flutter/material.dart';

class FullscreenNetworkImageScreen extends StatelessWidget {
  const FullscreenNetworkImageScreen({
    required this.imageUrl,
    super.key,
  });

  final String imageUrl;

  static Future<void> show(
    BuildContext context, {
    required String imageUrl,
  }) {
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 1,
          maxScale: 4,
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => const Padding(
              padding: EdgeInsets.all(24),
              child: Icon(
                Icons.broken_image_outlined,
                color: Colors.white70,
                size: 48,
              ),
            ),
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) {
                return child;
              }

              return const CircularProgressIndicator(color: Colors.white);
            },
          ),
        ),
      ),
    );
  }
}
