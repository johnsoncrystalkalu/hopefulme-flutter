import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';
import 'package:http/http.dart' as http;
import 'package:hopefulme_flutter/core/widgets/app_network_image.dart';
import 'package:hopefulme_flutter/core/widgets/app_toast.dart';

class FullscreenNetworkImageScreen extends StatefulWidget {
  const FullscreenNetworkImageScreen({
    required this.imageUrls,
    this.initialIndex = 0,
    this.primaryActionLabel,
    this.secondaryActionLabel,
    this.onPrimaryAction,
    this.onSecondaryAction,
    super.key,
  });

  final List<String> imageUrls;
  final int initialIndex;
  final String? primaryActionLabel;
  final String? secondaryActionLabel;
  final Future<void> Function()? onPrimaryAction;
  final Future<void> Function()? onSecondaryAction;

  static Future<void> show(
    BuildContext context, {
    required String imageUrl,
    String? primaryActionLabel,
    String? secondaryActionLabel,
    Future<void> Function()? onPrimaryAction,
    Future<void> Function()? onSecondaryAction,
  }) {
    if (imageUrl.trim().isEmpty) {
      return Future<void>.value();
    }

    return showGallery(
      context,
      imageUrls: <String>[imageUrl],
      initialIndex: 0,
      primaryActionLabel: primaryActionLabel,
      secondaryActionLabel: secondaryActionLabel,
      onPrimaryAction: onPrimaryAction,
      onSecondaryAction: onSecondaryAction,
    );
  }

  static Future<void> showGallery(
    BuildContext context, {
    required List<String> imageUrls,
    int initialIndex = 0,
    String? primaryActionLabel,
    String? secondaryActionLabel,
    Future<void> Function()? onPrimaryAction,
    Future<void> Function()? onSecondaryAction,
  }) {
    final filteredUrls = imageUrls
        .map((url) => url.trim())
        .where((url) => url.isNotEmpty)
        .toList();

    if (filteredUrls.isEmpty) {
      return Future<void>.value();
    }

    final safeInitialIndex = initialIndex < 0
        ? 0
        : (initialIndex >= filteredUrls.length
              ? filteredUrls.length - 1
              : initialIndex);

    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FullscreenNetworkImageScreen(
          imageUrls: filteredUrls,
          initialIndex: safeInitialIndex,
          primaryActionLabel: primaryActionLabel,
          secondaryActionLabel: secondaryActionLabel,
          onPrimaryAction: onPrimaryAction,
          onSecondaryAction: onSecondaryAction,
        ),
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
  late final PageController _pageController;
  late int _currentIndex;
  double _verticalDragOffset = 0;
  bool _isRunningAction = false;

  String get _currentImageUrl => widget.imageUrls[_currentIndex];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

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
                  title: Text(_isSaving ? 'Saving image...' : 'Save to phone'),
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
    final resolvedUrl = _currentImageUrl.trim();
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

  Future<void> _runExternalAction(Future<void> Function()? action) async {
    if (action == null || _isRunningAction) {
      return;
    }

    setState(() {
      _isRunningAction = true;
    });

    try {
      Navigator.of(context).pop();
      await action();
    } catch (error) {
      if (mounted) {
        AppToast.error(context, error);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRunningAction = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final translatedOffset = _verticalDragOffset < 0
        ? 0.0
        : _verticalDragOffset;
    final dragProgress = (translatedOffset / 320).clamp(0.0, 1.0);
    final screenOpacity = (1 - (dragProgress * 0.25)).clamp(0.75, 1.0);

    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: screenOpacity),
      appBar: AppBar(
        backgroundColor: Colors.black,
        surfaceTintColor: Colors.black,
        scrolledUnderElevation: 0,
        foregroundColor: Colors.white,
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onVerticalDragUpdate: (details) {
          final nextOffset = _verticalDragOffset + details.delta.dy;
          if (nextOffset <= 0) {
            if (_verticalDragOffset != 0) {
              setState(() {
                _verticalDragOffset = 0;
              });
            }
            return;
          }
          setState(() {
            _verticalDragOffset = nextOffset;
          });
        },
        onVerticalDragEnd: (details) {
          final velocity = details.primaryVelocity ?? 0;
          if (velocity > 850 || _verticalDragOffset > 120) {
            Navigator.of(context).maybePop();
            return;
          }
          if (_verticalDragOffset != 0) {
            setState(() {
              _verticalDragOffset = 0;
            });
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(0, translatedOffset, 0),
          child: Stack(
            children: [
              Center(
                child: GestureDetector(
                  onLongPress: _showImageActions,
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: widget.imageUrls.length,
                    onPageChanged: (index) {
                      setState(() {
                        _currentIndex = index;
                      });
                    },
                    itemBuilder: (context, index) {
                      return InteractiveViewer(
                        minScale: 1,
                        maxScale: 4,
                        child: SizedBox.expand(
                          child: AppNetworkImage(
                            imageUrl: widget.imageUrls[index],
                            fit: BoxFit.contain,
                            backgroundColor: Colors.black,
                            placeholderIcon: Icons.photo_outlined,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              if (widget.imageUrls.length > 1)
                Positioned(
                  top: kToolbarHeight + 18,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        child: Text(
                          '${_currentIndex + 1} / ${widget.imageUrls.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              Positioned(
                left: 20,
                right: 20,
                bottom: 28,
                child: IgnorePointer(
                  ignoring: _isRunningAction,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.primaryActionLabel != null ||
                          widget.secondaryActionLabel != null)
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: [
                            if (widget.primaryActionLabel != null)
                              FilledButton.tonal(
                                onPressed: () => _runExternalAction(
                                  widget.onPrimaryAction,
                                ),
                                style: FilledButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  backgroundColor: Colors.white.withValues(
                                    alpha: 0.17,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 9,
                                  ),
                                  minimumSize: const Size(0, 36),
                                  textStyle: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                child: Text(widget.primaryActionLabel!),
                              ),
                            if (widget.secondaryActionLabel != null)
                              FilledButton.tonal(
                                onPressed: () => _runExternalAction(
                                  widget.onSecondaryAction,
                                ),
                                style: FilledButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  backgroundColor: Colors.white.withValues(
                                    alpha: 0.17,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 9,
                                  ),
                                  minimumSize: const Size(0, 36),
                                  textStyle: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                child: Text(widget.secondaryActionLabel!),
                              ),
                          ],
                        ),
                      if (widget.primaryActionLabel != null ||
                          widget.secondaryActionLabel != null)
                        const SizedBox(height: 8),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.1),
                            ),
                          ),
                          child: const Text(
                            'Long press to save',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
