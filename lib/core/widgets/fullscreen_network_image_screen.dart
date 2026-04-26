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
    this.authorName,
    this.authorUsername,
    this.primaryActionLabel,
    this.secondaryActionLabel,
    this.onPrimaryAction,
    this.onSecondaryAction,
    super.key,
  });

  final List<String> imageUrls;
  final int initialIndex;
  final String? authorName;
  final String? authorUsername;
  final String? primaryActionLabel;
  final String? secondaryActionLabel;
  final Future<void> Function()? onPrimaryAction;
  final Future<void> Function()? onSecondaryAction;

  static Future<void> show(
    BuildContext context, {
    required String imageUrl,
    String? authorName,
    String? authorUsername,
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
      authorName: authorName,
      authorUsername: authorUsername,
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
    String? authorName,
    String? authorUsername,
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
          authorName: authorName,
          authorUsername: authorUsername,
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
    extends State<FullscreenNetworkImageScreen>
    with TickerProviderStateMixin {
  bool _isSaving = false;
  late final PageController _pageController;
  late final List<TransformationController> _zoomControllers;

  // Tracks per-page zoom level so we can react to changes
  late final List<ValueNotifier<double>> _scaleNotifiers;

  late int _currentIndex;
  double _verticalDragOffset = 0;
  bool _isRunningAction = false;

  // True while any zoom interaction is live (finger on screen + zoomed)
  bool _isZoomed = false;

  // Used to debounce double-tap so it doesn't also fire a single-tap
  DateTime? _lastTapTime;

  // ------------------------------------------------------------------
  // Zoom constants
  // ------------------------------------------------------------------
  static const double _zoomedScale = 2.5;
  static const double _zoomThreshold = 1.01;

  String get _currentImageUrl => widget.imageUrls[_currentIndex];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _zoomControllers = List<TransformationController>.generate(
      widget.imageUrls.length,
      (_) => TransformationController(),
    );
    _scaleNotifiers = List<ValueNotifier<double>>.generate(
      widget.imageUrls.length,
      (_) => ValueNotifier<double>(1.0),
    );

    // Keep scale notifiers in sync with transformation controllers
    for (var i = 0; i < _zoomControllers.length; i++) {
      final index = i;
      _zoomControllers[index].addListener(() {
        final scale = _zoomControllers[index].value.getMaxScaleOnAxis();
        _scaleNotifiers[index].value = scale;
        if (index == _currentIndex) {
          _syncZoomState(scale);
        }
      });
    }
  }

  @override
  void dispose() {
    for (final c in _zoomControllers) {
      c.dispose();
    }
    for (final n in _scaleNotifiers) {
      n.dispose();
    }
    _pageController.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------
  // Zoom helpers
  // ------------------------------------------------------------------

  void _syncZoomState(double scale) {
    final zoomed = scale > _zoomThreshold;
    if (_isZoomed != zoomed) {
      setState(() => _isZoomed = zoomed);
    }
  }

  /// Resets the zoom for the given page with an animation.
  void _resetZoom(int index) {
    final controller = _zoomControllers[index];
    final currentMatrix = controller.value;
    final currentScale = currentMatrix.getMaxScaleOnAxis();
    if (currentScale <= _zoomThreshold) return;

    // Animate back to identity over 250 ms
    final animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    final animation = Matrix4Tween(
      begin: currentMatrix,
      end: Matrix4.identity(),
    ).animate(CurvedAnimation(parent: animController, curve: Curves.easeOut));

    animation.addListener(() {
      controller.value = animation.value;
    });
    animController.forward().whenComplete(animController.dispose);
  }

  /// Double-tap: toggle between identity and a 2.5× zoom centred on the tap.
  void _handleDoubleTap(TapDownDetails details) {
    final controller = _zoomControllers[_currentIndex];
    final currentScale = controller.value.getMaxScaleOnAxis();

    final targetMatrix = currentScale > _zoomThreshold
        ? Matrix4.identity()
        : _centredZoomMatrix(details.localPosition, _zoomedScale);

    final animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    final animation = Matrix4Tween(
      begin: controller.value,
      end: targetMatrix,
    ).animate(
      CurvedAnimation(parent: animController, curve: Curves.easeInOutCubic),
    );

    animation.addListener(() {
      controller.value = animation.value;
    });
    HapticFeedback.lightImpact();
    animController.forward().whenComplete(animController.dispose);
  }

  /// Builds a Matrix4 that zooms to [scale] centred on [focalPoint].
  Matrix4 _centredZoomMatrix(Offset focalPoint, double scale) {
    final dx = -focalPoint.dx * (scale - 1);
    final dy = -focalPoint.dy * (scale - 1);
    return Matrix4.identity()
      ..translate(dx, dy)
      ..scale(scale);
  }

  // ------------------------------------------------------------------
  // Save image
  // ------------------------------------------------------------------

  Future<void> _showImageActions() async {
    await HapticFeedback.mediumImpact();
    if (!mounted) return;

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
    if (resolvedUrl.isEmpty || _isSaving) return;

    setState(() => _isSaving = true);

    try {
      final uri = Uri.tryParse(resolvedUrl);
      if (uri == null) throw const FormatException('Invalid image URL');

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
      if (!mounted) return;

      if (saved == true) {
        AppToast.success(context, 'Image saved to your gallery.');
      } else {
        AppToast.info(context, 'Could not save image right now.');
      }
    } catch (error) {
      if (!mounted) return;
      AppToast.error(context, error);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _inferImageExtension(Uri uri) {
    final path = uri.path.toLowerCase();
    if (path.endsWith('.png')) return 'png';
    if (path.endsWith('.webp')) return 'webp';
    if (path.endsWith('.gif')) return 'gif';
    return 'jpg';
  }

  // ------------------------------------------------------------------
  // External actions
  // ------------------------------------------------------------------

  Future<void> _runExternalAction(Future<void> Function()? action) async {
    if (action == null || _isRunningAction) return;
    setState(() => _isRunningAction = true);
    try {
      Navigator.of(context).pop();
      await action();
    } catch (error) {
      if (mounted) AppToast.error(context, error);
    } finally {
      if (mounted) setState(() => _isRunningAction = false);
    }
  }

  // ------------------------------------------------------------------
  // Build
  // ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final translatedOffset = _verticalDragOffset < 0 ? 0.0 : _verticalDragOffset;
    final dragProgress = (translatedOffset / 320).clamp(0.0, 1.0);
    final screenOpacity = (1 - (dragProgress * 0.25)).clamp(0.75, 1.0);

    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: screenOpacity),
      appBar: AppBar(
        backgroundColor: Colors.black,
        surfaceTintColor: Colors.black,
        scrolledUnderElevation: 0,
        foregroundColor: Colors.white,
        flexibleSpace: (widget.authorName ?? '').trim().isEmpty
            ? null
            : SafeArea(
                child: Stack(
                  children: [
                    Align(
                      alignment: Alignment.center,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 220),
                        child: Text(
                          widget.authorName!.trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
        actions: [
          if (widget.primaryActionLabel != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: OutlinedButton(
                onPressed: _isRunningAction
                    ? null
                    : () => _runExternalAction(widget.onPrimaryAction),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.white.withValues(alpha: 0.12),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.38)),
                  minimumSize: const Size(0, 34),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: Text(
                  widget.primaryActionLabel!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
        ],
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        // ── Vertical swipe-to-dismiss ──────────────────────────────────
        // Only active when the image is at 1× scale.
        onVerticalDragUpdate: (details) {
          if (_isZoomed) return;
          final nextOffset = _verticalDragOffset + details.delta.dy;
          if (nextOffset <= 0) {
            if (_verticalDragOffset != 0) {
              setState(() => _verticalDragOffset = 0);
            }
            return;
          }
          setState(() => _verticalDragOffset = nextOffset);
        },
        onVerticalDragEnd: (details) {
          if (_isZoomed) return;
          final velocity = details.primaryVelocity ?? 0;
          if (velocity > 850 || _verticalDragOffset > 120) {
            Navigator.of(context).maybePop();
            return;
          }
          if (_verticalDragOffset != 0) {
            setState(() => _verticalDragOffset = 0);
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
                  // ── Double-tap to zoom ───────────────────────────────
                  onDoubleTapDown: _handleDoubleTap,
                  onDoubleTap: () {
                    // Intentionally empty: the work is done in onDoubleTapDown
                    // so we have the tap position available.
                  },
                  child: PageView.builder(
                    controller: _pageController,
                    // Disable PageView swiping while zoomed in so the user
                    // can pan the image freely without accidentally changing pages.
                    physics: _isZoomed
                        ? const NeverScrollableScrollPhysics()
                        : const BouncingScrollPhysics(),
                    itemCount: widget.imageUrls.length,
                    onPageChanged: (index) {
                      // Animate the old page back to 1× before leaving it
                      _resetZoom(_currentIndex);
                      setState(() {
                        _currentIndex = index;
                        _verticalDragOffset = 0;
                      });
                      // Sync zoom state for the newly visible page
                      final newScale =
                          _zoomControllers[index].value.getMaxScaleOnAxis();
                      _syncZoomState(newScale);
                    },
                    itemBuilder: (context, index) {
                      return InteractiveViewer(
                        transformationController: _zoomControllers[index],
                        minScale: 1.0,
                        maxScale: 5.0,
                        // Allow the image to be panned even when it fits the
                        // viewport — needed so double-tap zoom then pan works.
                        panEnabled: true,
                        scaleEnabled: true,
                        // Clip keeps out-of-bounds panning invisible.
                        clipBehavior: Clip.hardEdge,
                        onInteractionUpdate: (details) {
                          if (index != _currentIndex) return;
                          final scale =
                              _zoomControllers[index].value.getMaxScaleOnAxis();
                          _syncZoomState(scale);
                        },
                        onInteractionEnd: (details) {
                          if (index != _currentIndex) return;
                          final scale =
                              _zoomControllers[index].value.getMaxScaleOnAxis();

                          // Snap back to 1× if the user pinched past the minimum
                          if (scale < 1.0) {
                            _resetZoom(index);
                          } else {
                            _syncZoomState(scale);
                          }
                        },
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

              // ── Page indicator ─────────────────────────────────────
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

              // ── Bottom actions ─────────────────────────────────────
              Positioned(
                left: 20,
                right: 20,
                bottom: 28,
                child: IgnorePointer(
                  ignoring: _isRunningAction,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.secondaryActionLabel != null)
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: [
                            FilledButton.tonal(
                              onPressed: () =>
                                  _runExternalAction(widget.onSecondaryAction),
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
                      if (widget.secondaryActionLabel != null)
                        const SizedBox(height: 8),
                      // Hint pill — fades out while zoomed so it's not distracting
                      AnimatedOpacity(
                        opacity: _isZoomed ? 0.0 : 1.0,
                        duration: const Duration(milliseconds: 200),
                        child: Center(
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
                              'Double-tap to zoom  ·  Long press to save',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                              ),
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