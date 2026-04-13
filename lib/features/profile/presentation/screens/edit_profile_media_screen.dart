import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:hopefulme_flutter/app/theme/app_theme.dart';
import 'package:hopefulme_flutter/core/network/api_client.dart';
import 'package:hopefulme_flutter/core/widgets/app_status_state.dart';
import 'package:hopefulme_flutter/core/widgets/app_toast.dart';
import 'package:hopefulme_flutter/features/profile/data/profile_repository.dart';
import 'package:hopefulme_flutter/features/profile/models/profile_dashboard.dart';

class EditProfileMediaScreen extends StatefulWidget {
  const EditProfileMediaScreen({
    required this.username,
    required this.repository,
    super.key,
  });

  final String username;
  final ProfileRepository repository;

  @override
  State<EditProfileMediaScreen> createState() => _EditProfileMediaScreenState();
}

class _EditProfileMediaScreenState extends State<EditProfileMediaScreen> {
  final ImagePicker _picker = ImagePicker();

  ProfileSummary? _profile;
  Uint8List? _pendingPhotoBytes;
  Uint8List? _pendingCoverBytes;
  bool _isLoading = true;
  bool _isUploadingPhoto = false;
  bool _isUploadingCover = false;
  bool _isRemovingPhoto = false;
  bool _isRemovingCover = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final dashboard = await widget.repository.fetchProfile(widget.username);
      if (!mounted) {
        return;
      }
      setState(() {
        _profile = dashboard.profile;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pickAndUploadPhoto() async {
    if (_isUploadingPhoto) {
      return;
    }

    final file = await _pickAndCropImage(
      maxWidth: 2200,
      filenameFallback: 'profile.jpg',
    );
    if (file == null) {
      return;
    }

    final bytes = file.bytes;
    if (!mounted) {
      return;
    }

    setState(() {
      _pendingPhotoBytes = bytes;
      _isUploadingPhoto = true;
      _error = null;
    });

    try {
      await widget.repository.updateProfilePhoto(
        ApiMultipartFile(field: 'photo', filename: file.filename, bytes: bytes),
      );
      await _load();
      if (!mounted) {
        return;
      }
      AppToast.success(context, 'Profile photo updated.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingPhoto = false;
          _pendingPhotoBytes = null;
        });
      }
    }
  }

  Future<void> _pickAndUploadCover() async {
    if (_isUploadingCover) {
      return;
    }

    final file = await _pickAndCropImage(
      maxWidth: 2600,
      filenameFallback: 'cover.jpg',
    );
    if (file == null) {
      return;
    }

    final bytes = file.bytes;
    if (!mounted) {
      return;
    }

    setState(() {
      _pendingCoverBytes = bytes;
      _isUploadingCover = true;
      _error = null;
    });

    try {
      await widget.repository.updateCoverPhoto(
        ApiMultipartFile(
          field: 'cover_photo',
          filename: file.filename,
          bytes: bytes,
        ),
      );
      await _load();
      if (!mounted) {
        return;
      }
      AppToast.success(context, 'Cover photo updated.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingCover = false;
          _pendingCoverBytes = null;
        });
      }
    }
  }

  Future<_PreparedUploadFile?> _pickAndCropImage({
    required int maxWidth,
    required String filenameFallback,
  }) async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: maxWidth.toDouble(),
      imageQuality: kIsWeb ? null : 88,
    );
    if (picked == null) {
      return null;
    }

    final bytes = await picked.readAsBytes();
    final filename = picked.name.isNotEmpty ? picked.name : filenameFallback;

    if (kIsWeb || defaultTargetPlatform == TargetPlatform.macOS) {
      return _PreparedUploadFile(bytes: bytes, filename: filename);
    }

    final tempDir = Directory.systemTemp;
    final tempFile = File(
      '${tempDir.path}/temp_pick_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    await tempFile.writeAsBytes(bytes);

    try {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: tempFile.path,
        maxWidth: maxWidth,
        uiSettings: [
          if (defaultTargetPlatform == TargetPlatform.iOS)
            IOSUiSettings(
              title: 'Crop Photo',
              cancelButtonTitle: 'Cancel',
              doneButtonTitle: 'Done',
            )
          else
            AndroidUiSettings(
              toolbarTitle: 'Crop Photo',
              toolbarColor: const Color(0xFF111827),
              toolbarWidgetColor: Colors.white,
              backgroundColor: const Color(0xFFF9FAFB),
              activeControlsWidgetColor: const Color(0xFF111827),
              dimmedLayerColor: Colors.black54,
              cropFrameColor: Colors.white,
              cropGridColor: Colors.white70,
              showCropGrid: true,
              lockAspectRatio: false,
              aspectRatioPresets: const [
                CropAspectRatioPreset.original,
                CropAspectRatioPreset.square,
                CropAspectRatioPreset.ratio3x2,
                CropAspectRatioPreset.ratio4x3,
                CropAspectRatioPreset.ratio16x9,
              ],
            ),
        ],
        compressQuality: 88,
        compressFormat: ImageCompressFormat.jpg,
      );
      if (croppedFile != null) {
        final croppedBytes = await croppedFile.readAsBytes();
        return _PreparedUploadFile(bytes: croppedBytes, filename: filename);
      }
    } catch (e) {
      // Cropper canceled or failed — user chose not to proceed
    } finally {
      try {
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      } catch (_) {}
    }

    return null;
  }

  Future<void> _removePhoto() async {
    if (_isRemovingPhoto) {
      return;
    }

    setState(() {
      _isRemovingPhoto = true;
      _error = null;
    });

    try {
      await widget.repository.removeProfilePhoto();
      await _load();
      if (!mounted) {
        return;
      }
      AppToast.success(context, 'Profile photo removed.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isRemovingPhoto = false;
        });
      }
    }
  }

  Future<void> _removeCover() async {
    if (_isRemovingCover) {
      return;
    }

    setState(() {
      _isRemovingCover = true;
      _error = null;
    });

    try {
      await widget.repository.removeCoverPhoto();
      await _load();
      if (!mounted) {
        return;
      }
      AppToast.success(context, 'Cover photo removed.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isRemovingCover = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final profile = _profile;

    return Scaffold(
      backgroundColor: colors.scaffold,
      appBar: AppBar(title: const Text('Profile Photos')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && profile == null
          ? AppStatusState.fromError(
              error: _error!,
              actionLabel: 'Try again',
              onAction: _load,
            )
          : SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _MediaCard(
                          title: 'Profile Photo',
                          subtitle:
                              'Shown on your profile, feed, comments, and chats.',
                          preview: _MediaPreview.avatar(
                            imageUrl: profile?.photoUrl ?? '',
                            bytes: _pendingPhotoBytes,
                            fallbackLabel:
                                profile?.displayName ?? 'HopefulMe User',
                          ),
                          primaryLabel: _isUploadingPhoto
                              ? 'Uploading...'
                              : 'Change Photo',
                          primaryIcon: Icons.photo_camera_outlined,
                          onPrimaryTap: _isUploadingPhoto
                              ? null
                              : _pickAndUploadPhoto,
                          secondaryLabel: _isRemovingPhoto
                              ? 'Removing...'
                              : 'Remove Photo',
                          onSecondaryTap: _isRemovingPhoto
                              ? null
                              : _removePhoto,
                        ),
                        const SizedBox(height: 16),
                        _MediaCard(
                          title: 'Cover Photo',
                          subtitle: 'Used at the top of your profile page (optional).',
                          preview: _MediaPreview.cover(
                            imageUrl: profile?.coverUrl ?? '',
                            fallbackImageUrl: profile?.photoUrl ?? '',
                            bytes: _pendingCoverBytes,
                          ),
                          primaryLabel: _isUploadingCover
                              ? 'Uploading...'
                              : 'Change Cover',
                          primaryIcon: Icons.landscape_outlined,
                          onPrimaryTap: _isUploadingCover
                              ? null
                              : _pickAndUploadCover,
                          secondaryLabel: _isRemovingCover
                              ? 'Removing...'
                              : 'Remove Cover',
                          onSecondaryTap: _isRemovingCover
                              ? null
                              : _removeCover,
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            _error!.toString(),
                            style: TextStyle(
                              color: colors.dangerText,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (_isUploadingPhoto || _isUploadingCover)
                    LinearProgressIndicator(
                      backgroundColor: colors.border,
                      color: colors.accent,
                    ),
                ],
              ),
            ),
    );
  }
}

class _PreparedUploadFile {
  const _PreparedUploadFile({required this.bytes, required this.filename});

  final Uint8List bytes;
  final String filename;
}

class _MediaCard extends StatelessWidget {
  const _MediaCard({
    required this.title,
    required this.subtitle,
    required this.preview,
    required this.primaryLabel,
    required this.primaryIcon,
    required this.onPrimaryTap,
    required this.secondaryLabel,
    required this.onSecondaryTap,
  });

  final String title;
  final String subtitle;
  final Widget preview;
  final String primaryLabel;
  final IconData primaryIcon;
  final VoidCallback? onPrimaryTap;
  final String secondaryLabel;
  final VoidCallback? onSecondaryTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(color: colors.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 16),
          preview,
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: onPrimaryTap,
                icon: Icon(primaryIcon),
                label: Text(primaryLabel),
              ),
              OutlinedButton(
                onPressed: onSecondaryTap,
                child: Text(secondaryLabel),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MediaPreview extends StatelessWidget {
  const _MediaPreview.cover({
    required this.imageUrl,
    required this.fallbackImageUrl,
    this.bytes,
  }) : fallbackLabel = '',
       isAvatar = false;

  const _MediaPreview.avatar({
    required this.imageUrl,
    required this.fallbackLabel,
    this.bytes,
  }) : fallbackImageUrl = '',
       isAvatar = true;

  final String imageUrl;
  final String fallbackImageUrl;
  final String fallbackLabel;
  final Uint8List? bytes;
  final bool isAvatar;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    if (isAvatar) {
      final initials = fallbackLabel
          .trim()
          .split(RegExp(r'\s+'))
          .where((part) => part.isNotEmpty)
          .take(2)
          .map((part) => part[0].toUpperCase())
          .join();

      return Center(
        child: Container(
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            color: colors.avatarPlaceholder,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: colors.borderStrong),
          ),
          clipBehavior: Clip.antiAlias,
          child: bytes != null
              ? Image.memory(bytes!, fit: BoxFit.cover)
              : imageUrl.isNotEmpty
              ? Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Center(
                    child: Text(
                      initials.isEmpty ? 'U' : initials,
                      style: TextStyle(
                        color: colors.accentSoftText,
                        fontSize: 42,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                )
              : Center(
                  child: Text(
                    initials.isEmpty ? 'U' : initials,
                    style: TextStyle(
                      color: colors.accentSoftText,
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: AspectRatio(
        aspectRatio: 16 / 7,
        child: bytes != null
            ? Image.memory(bytes!, fit: BoxFit.cover)
            : imageUrl.isNotEmpty || fallbackImageUrl.isNotEmpty
            ? Image.network(
                imageUrl.isNotEmpty ? imageUrl : fallbackImageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => ColoredBox(
                  color: colors.heroFallback,
                  child: const Center(
                    child: Icon(Icons.image_not_supported_outlined),
                  ),
                ),
              )
            : ColoredBox(
                color: colors.heroFallback,
                child: const Center(
                  child: Icon(Icons.image_not_supported_outlined),
                ),
              ),
      ),
    );
  }
}
