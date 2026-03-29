import 'package:flutter/material.dart';
import 'package:hopefulme_flutter/core/widgets/app_network_image.dart';

class FullscreenNetworkImageScreen extends StatelessWidget {
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
          child: SizedBox.expand(
            child: AppNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.contain,
              backgroundColor: Colors.black,
              placeholderIcon: Icons.photo_outlined,
            ),
          ),
        ),
      ),
    );
  }
}
