import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_box_transform/flutter_box_transform.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hopefulme_flutter/app/theme/app_theme.dart';
import 'package:hopefulme_flutter/features/templates/data/flyer_template_repository.dart';
import 'package:hopefulme_flutter/features/templates/models/flyer_template_models.dart';

class FlyerTemplateEditorScreen extends StatefulWidget {
  const FlyerTemplateEditorScreen({
    required this.template,
    required this.repository,
    super.key,
  });

  final FlyerTemplateItem template;
  final FlyerTemplateRepository repository;

  @override
  State<FlyerTemplateEditorScreen> createState() =>
      _FlyerTemplateEditorScreenState();
}

class _FlyerTemplateEditorScreenState extends State<FlyerTemplateEditorScreen> {
  static const String _networkImageFallbackAsset = 'assets/templates/1.webp';
  final GlobalKey _repaintKey = GlobalKey();
  final TextEditingController _nameController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  ui.Image? _userImage;
  Size? _userImageSize;
  bool _saving = false;
  bool _lockImageRatio = true;
  double _templateAspectRatio = 1;

  Size _stageSize = Size.zero;
  Rect? _photoRect;
  Rect? _textRect;
  String _activeLayer = 'photo';
  String _textEditMode = 'move';

  double _nameFontSize = 34;
  Color _nameColor = Colors.white;

  static const _cropPresets = <_CropPreset>[
    _CropPreset.free(),
    _CropPreset.ratio('1:1', 1, 1),
    _CropPreset.ratio('4:5', 4, 5),
    _CropPreset.ratio('3:4', 3, 4),
    _CropPreset.ratio('16:9', 16, 9),
  ];

  @override
  void initState() {
    super.initState();
    _loadTemplateAspectRatio();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  ImageProvider _templateImageProvider() {
    if (widget.template.isOfflineAsset) {
      return AssetImage(widget.template.imageUrl);
    }
    return NetworkImage(widget.template.imageUrl);
  }

  Future<void> _loadTemplateAspectRatio() async {
    final completer = Completer<ui.Image>();
    final stream = _templateImageProvider().resolve(const ImageConfiguration());
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (imageInfo, _) {
        if (!completer.isCompleted) {
          completer.complete(imageInfo.image);
        }
        stream.removeListener(listener);
      },
      onError: (error, stackTrace) {
        if (!completer.isCompleted) {
          completer.completeError(StateError('Could not load image size'));
        }
        stream.removeListener(listener);
      },
    );
    stream.addListener(listener);

    try {
      final image = await completer.future;
      if (!mounted) {
        return;
      }
      if (image.height > 0) {
        setState(() {
          _templateAspectRatio = image.width / image.height;
        });
      }
    } catch (_) {
      // Keep default ratio.
    }
  }

  Future<void> _pickPhoto() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 95,
    );
    if (picked == null) {
      return;
    }

    final preset = await _pickCropPreset();
    if (!mounted || preset == null) {
      return;
    }

    final lockRatio = preset.isLocked;

    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      compressFormat: ImageCompressFormat.png,
      aspectRatio: preset.aspectRatio,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Photo',
          lockAspectRatio: lockRatio,
          hideBottomControls: false,
        ),
        IOSUiSettings(title: 'Crop Photo', aspectRatioLockEnabled: lockRatio),
      ],
    );

    final path = cropped?.path ?? picked.path;
    final bytes = await File(path).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();

    if (!mounted) {
      return;
    }

    setState(() {
      _userImage = frame.image;
      _userImageSize = Size(
        frame.image.width.toDouble(),
        frame.image.height.toDouble(),
      );
      _photoRect = _defaultPhotoRect(_stageSize);
      _activeLayer = 'photo';
    });
  }

  Future<_CropPreset?> _pickCropPreset() {
    return showModalBottomSheet<_CropPreset>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            itemCount: _cropPresets.length,
            separatorBuilder: (context, index) => const SizedBox(height: 6),
            itemBuilder: (context, index) {
              final preset = _cropPresets[index];
              return ListTile(
                dense: true,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                title: Text(
                  preset.label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  preset.isLocked
                      ? 'Lock crop to ${preset.label}'
                      : 'No ratio lock',
                  style: const TextStyle(fontSize: 12),
                ),
                onTap: () => Navigator.of(context).pop(preset),
              );
            },
          ),
        );
      },
    );
  }

  Rect _defaultPhotoRect(Size stageSize) {
    if (stageSize.width <= 0 || stageSize.height <= 0) {
      return const Rect.fromLTWH(80, 80, 220, 220);
    }

    final imageSize = _userImageSize;
    if (imageSize == null || imageSize.width <= 0 || imageSize.height <= 0) {
      final size = stageSize.shortestSide * 0.58;
      return Rect.fromCenter(
        center: stageSize.center(Offset.zero),
        width: size,
        height: size,
      );
    }

    final aspect = imageSize.width / imageSize.height;
    var width = stageSize.width * 0.62;
    var height = width / aspect;

    final maxHeight = stageSize.height * 0.62;
    if (height > maxHeight) {
      height = maxHeight;
      width = height * aspect;
    }

    return Rect.fromCenter(
      center: stageSize.center(Offset.zero),
      width: width,
      height: height,
    );
  }

  Rect _defaultTextRect(Size stageSize) {
    final width = stageSize.width * 0.38;
    final height = stageSize.height * 0.12;
    return Rect.fromLTWH(
      (stageSize.width - width) / 2,
      stageSize.height * 0.78,
      width,
      height,
    );
  }

  void _updateStage(Size nextSize) {
    if (_stageSize == nextSize) {
      return;
    }

    setState(() {
      _stageSize = nextSize;
      _photoRect ??= _defaultPhotoRect(nextSize);
      _textRect ??= _defaultTextRect(nextSize);
    });
  }

  Future<void> _saveFlyer() async {
    if (_saving) {
      return;
    }

    setState(() {
      _saving = true;
    });

    final previousActiveLayer = _activeLayer;
    setState(() {
      _activeLayer = 'none';
    });
    await WidgetsBinding.instance.endOfFrame;

    try {
      final boundary =
          _repaintKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) {
        throw StateError('Could not capture flyer canvas');
      }

      final image = await boundary.toImage(pixelRatio: 3);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw StateError('Could not encode flyer image');
      }

      final bytes = byteData.buffer.asUint8List();
      final tempFile = File(
        '${Directory.systemTemp.path}${Platform.pathSeparator}flyer_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await tempFile.writeAsBytes(bytes, flush: true);

      final saved = await GallerySaver.saveImage(tempFile.path) == true;
      if (!mounted) {
        return;
      }

      if (!mounted) {
        return;
      }

      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            saved
                ? 'Flyer saved to your gallery. Share it with your friends!'
                : 'Could not save flyer to gallery.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save flyer right now.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _activeLayer = previousActiveLayer;
          _saving = false;
        });
      }
    }
  }

  Set<HandlePosition> _allHandles() => {...HandlePosition.values};

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: colors.scaffold,
      appBar: AppBar(title: Text(widget.template.name)),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              child: AspectRatio(
                aspectRatio: _templateAspectRatio,
                child: RepaintBoundary(
                  key: _repaintKey,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final size = Size(
                        constraints.maxWidth,
                        constraints.maxHeight,
                      );
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted) {
                          return;
                        }
                        _updateStage(size);
                      });

                      final clamping = Rect.fromLTWH(
                        0,
                        0,
                        size.width,
                        size.height,
                      );

                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          if (widget.template.isOfflineAsset)
                            Image.asset(
                              widget.template.imageUrl,
                              fit: BoxFit.cover,
                              filterQuality: FilterQuality.low,
                            )
                          else
                            Image.network(
                              widget.template.imageUrl,
                              fit: BoxFit.cover,
                              filterQuality: FilterQuality.low,
                              errorBuilder: (context, error, stackTrace) =>
                                  Image.asset(
                                    _networkImageFallbackAsset,
                                    fit: BoxFit.cover,
                                    filterQuality: FilterQuality.low,
                                  ),
                            ),
                          if (_userImage != null && _photoRect != null)
                            TransformableBox(
                              rect: _photoRect!,
                              clampingRect: clamping,
                              resizeModeResolver: () => _lockImageRatio
                                  ? ResizeMode.scale
                                  : ResizeMode.freeform,
                              visibleHandles: _activeLayer == 'photo'
                                  ? _allHandles()
                                  : <HandlePosition>{},
                              enabledHandles: _activeLayer == 'photo'
                                  ? _allHandles()
                                  : <HandlePosition>{},
                              onTap: () {
                                setState(() {
                                  _activeLayer = 'photo';
                                });
                              },
                              onChanged: (result, event) {
                                setState(() {
                                  _photoRect = result.rect;
                                });
                              },
                              contentBuilder: (context, rect, flip) {
                                return DecoratedBox(
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: _activeLayer == 'photo'
                                          ? const Color(0xFF2563EB)
                                          : Colors.transparent,
                                      width: 2,
                                    ),
                                  ),
                                  child: RawImage(
                                    image: _userImage,
                                    fit: BoxFit.fill,
                                    filterQuality: FilterQuality.high,
                                  ),
                                );
                              },
                            ),
                          if (_nameController.text.trim().isNotEmpty &&
                              _textRect != null)
                            TransformableBox(
                              rect: _textRect!,
                              clampingRect: clamping,
                              resizeModeResolver: () => ResizeMode.freeform,
                              resizable:
                                  _activeLayer == 'text' &&
                                  _textEditMode == 'resize',
                              visibleHandles:
                                  _activeLayer == 'text' &&
                                      _textEditMode == 'resize'
                                  ? _allHandles()
                                  : <HandlePosition>{},
                              enabledHandles:
                                  _activeLayer == 'text' &&
                                      _textEditMode == 'resize'
                                  ? _allHandles()
                                  : <HandlePosition>{},
                              onTap: () {
                                setState(() {
                                  _activeLayer = 'text';
                                });
                              },
                              onChanged: (result, event) {
                                setState(() {
                                  _textRect = result.rect;
                                });
                              },
                              contentBuilder: (context, rect, flip) {
                                return Container(
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: _activeLayer == 'text'
                                          ? const Color(0xFF2563EB)
                                          : Colors.transparent,
                                      width: 2,
                                    ),
                                  ),
                                  child: FittedBox(
                                    fit: BoxFit.contain,
                                    child: Text(
                                      _nameController.text.trim(),
                                      maxLines: 1,
                                      style: TextStyle(
                                        color: _nameColor,
                                        fontSize: _nameFontSize,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            textStyle: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          onPressed: _pickPhoto,
                          icon: const Icon(
                            Icons.photo_library_outlined,
                            size: 14,
                          ),
                          label: const Text('Choose a Photo'),
                        ),
                        if (_userImage != null)
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              textStyle: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            onPressed: () {
                              setState(() {
                                _activeLayer = 'photo';
                              });
                            },
                            icon: const Icon(Icons.photo_outlined, size: 16),
                            label: const Text('Photo Layer'),
                          ),
                        if (_nameController.text.trim().isNotEmpty)
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              textStyle: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            onPressed: () {
                              setState(() {
                                _activeLayer = 'text';
                              });
                            },
                            icon: const Icon(
                              Icons.text_fields_outlined,
                              size: 16,
                            ),
                            label: const Text('Text Layer'),
                          ),
                        if (_nameController.text.trim().isNotEmpty)
                          SegmentedButton<String>(
                            style: ButtonStyle(
                              visualDensity: VisualDensity.compact,
                              textStyle: WidgetStateProperty.all(
                                const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            segments: const [
                              ButtonSegment<String>(
                                value: 'move',
                                label: Text('Move'),
                                icon: Icon(Icons.open_with, size: 14),
                              ),
                              ButtonSegment<String>(
                                value: 'resize',
                                label: Text('Resize'),
                                icon: Icon(Icons.aspect_ratio, size: 14),
                              ),
                            ],
                            selected: {_textEditMode},
                            onSelectionChanged: (values) {
                              final mode = values.firstOrNull;
                              if (mode == null) {
                                return;
                              }
                              setState(() {
                                _textEditMode = mode;
                                _activeLayer = 'text';
                              });
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          textStyle: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _saving ? null : _saveFlyer,
                        icon: const Icon(Icons.download_outlined, size: 20),
                        label: Text(_saving ? 'Saving...' : 'Save Flyer'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Text mode: Move for easy dragging, Resize to show edge handles.',
                      style: TextStyle(
                        color: colors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 14),
                    SwitchListTile.adaptive(
                      value: _lockImageRatio,
                      onChanged: (value) {
                        setState(() {
                          _lockImageRatio = value;
                        });
                      },
                      title: const Text('Lock image ratio'),
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Name text (optional)',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        setState(() {
                          if (value.trim().isNotEmpty && _textRect == null) {
                            _textRect = _defaultTextRect(_stageSize);
                          }
                          _activeLayer = value.trim().isEmpty
                              ? _activeLayer
                              : 'text';
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Slider(
                            min: 12,
                            max: 92,
                            value: _nameFontSize,
                            onChanged: (value) =>
                                setState(() => _nameFontSize = value),
                          ),
                        ),
                        Text(
                          'Font ${_nameFontSize.toInt()}',
                          style: TextStyle(
                            color: colors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      children: [
                        _colorChip(Colors.white),
                        _colorChip(Colors.black),
                        _colorChip(const Color(0xFF2563EB)),
                        _colorChip(const Color(0xFFDC2626)),
                        _colorChip(const Color(0xFF059669)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Tip: tap photo or text to show edge handles, then drag/resize freely.',
                      style: TextStyle(
                        color: colors.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _colorChip(Color color) {
    final isActive = _nameColor.toARGB32() == color.toARGB32();
    return InkWell(
      onTap: () => setState(() => _nameColor = color),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isActive ? const Color(0xFF2563EB) : Colors.black26,
            width: isActive ? 3 : 1,
          ),
        ),
      ),
    );
  }
}

class _CropPreset {
  const _CropPreset(this.label, {this.ratioX, this.ratioY});

  const _CropPreset.free() : this('Free');

  const _CropPreset.ratio(String label, double x, double y)
    : this(label, ratioX: x, ratioY: y);

  final String label;
  final double? ratioX;
  final double? ratioY;

  bool get isLocked => ratioX != null && ratioY != null;

  CropAspectRatio? get aspectRatio {
    if (!isLocked) {
      return null;
    }
    return CropAspectRatio(ratioX: ratioX!, ratioY: ratioY!);
  }
}
