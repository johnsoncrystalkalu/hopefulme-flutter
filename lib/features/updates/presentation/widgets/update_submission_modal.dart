import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hopefulme_flutter/app/theme/app_theme.dart';
import 'package:hopefulme_flutter/core/network/image_url_resolver.dart';
import 'package:hopefulme_flutter/core/widgets/app_toast.dart';
import 'package:hopefulme_flutter/features/auth/models/user.dart';
import 'package:hopefulme_flutter/features/updates/data/update_repository.dart';
import 'package:hopefulme_flutter/features/updates/models/update_detail.dart';

class UpdateSubmissionModal extends StatefulWidget {
  const UpdateSubmissionModal({
    required this.updateRepository,
    required this.currentUser,
    this.onSuccess,
    this.onError,
    super.key,
  });

  final UpdateRepository updateRepository;
  final User? currentUser;
  final void Function(UpdateDetail update)? onSuccess;
  final void Function(Object error)? onError;

  static Future<UpdateDetail?> show(
    BuildContext context, {
    required UpdateRepository updateRepository,
    required User? currentUser,
  }) {
    return showModalBottomSheet<UpdateDetail?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => UpdateSubmissionModal(
        updateRepository: updateRepository,
        currentUser: currentUser,
      ),
    );
  }

  @override
  State<UpdateSubmissionModal> createState() => _UpdateSubmissionModalState();
}

class _UpdateSubmissionModalState extends State<UpdateSubmissionModal> {
  final TextEditingController _controller = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final ImagePicker _imagePicker = ImagePicker();
  bool _submitting = false;
  XFile? _selectedPhoto;
  Uint8List? _selectedPhotoBytes;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final photo = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: kIsWeb ? null : 88,
    );
    if (photo == null || !mounted) {
      return;
    }
    final bytes = await photo.readAsBytes();
    setState(() {
      _selectedPhoto = photo;
      _selectedPhotoBytes = bytes;
    });
  }

  Future<void> _submit() async {
    final hasText = _controller.text.trim().isNotEmpty;
    final hasPhoto = _selectedPhoto != null;
    if ((!hasText && !hasPhoto) || _submitting) {
      _formKey.currentState?.validate();
      return;
    }
    setState(() {
      _submitting = true;
    });
    try {
      final update = await widget.updateRepository.createUpdate(
        status: _controller.text.trim(),
        photo: _selectedPhoto,
      );
      if (mounted) {
        widget.onSuccess?.call(update);
        Navigator.of(context).pop(update);
      }
    } catch (error) {
      if (mounted) {
        widget.onError?.call(error);
        AppToast.error(
          context,
          'We could not post your update right now. Please try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: colors.borderStrong),
            boxShadow: [
              BoxShadow(
                color: colors.shadow.withValues(alpha: 0.1),
                blurRadius: 26,
                offset: const Offset(0, 16),
                spreadRadius: -18,
              ),
            ],
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        colors.brand.withValues(alpha: 0.14),
                        colors.accentSoft.withValues(alpha: 0.3),
                        colors.surfaceMuted.withValues(alpha: 0.94),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: colors.brand.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundImage:
                            widget.currentUser?.photoUrl.isNotEmpty == true
                            ? NetworkImage(
                                ImageUrlResolver.avatar(
                                  widget.currentUser!.photoUrl,
                                  size: 66,
                                ),
                              )
                            : null,
                        child: widget.currentUser?.photoUrl.isEmpty ?? true
                            ? const Icon(Icons.person)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.currentUser?.displayName ??
                                  'Share an update',
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: colors.surface.withValues(alpha: 0.82),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                'Post to feed',
                                style: TextStyle(
                                  color: colors.textSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _submitting
                            ? null
                            : () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Create update',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Share something honest, hopeful, or helpful with your community.',
                  style: TextStyle(
                    color: colors.textMuted,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _controller,
                  minLines: 4,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    hintText: 'What is on your mind?',
                  ),
                  validator: (value) {
                    if ((value == null || value.trim().isEmpty) &&
                        _selectedPhoto == null) {
                      return 'Please write something or add a photo.';
                    }
                    return null;
                  },
                ),
                if (_selectedPhoto != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.surfaceMuted,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: colors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: AspectRatio(
                            aspectRatio: 4 / 3,
                            child: _selectedPhotoBytes != null
                                ? Image.memory(
                                    _selectedPhotoBytes!,
                                    fit: BoxFit.cover,
                                  )
                                : Container(
                                    color: colors.accentSoft,
                                    child: Icon(
                                      Icons.image_outlined,
                                      color: colors.accentSoftText,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _selectedPhoto!.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: colors.textPrimary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Photo ready to post',
                                    style: TextStyle(
                                      color: colors.textMuted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: _submitting
                                  ? null
                                  : () {
                                      setState(() {
                                        _selectedPhoto = null;
                                        _selectedPhotoBytes = null;
                                      });
                                    },
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                Row(
                  children: [
                    IconButton.outlined(
                      onPressed: _submitting ? null : _pickPhoto,
                      icon: Icon(
                        _selectedPhoto == null
                            ? Icons.image_outlined
                            : Icons.check_circle_outline,
                        color: colors.brand,
                      ),
                      tooltip: _selectedPhoto == null
                          ? 'Add Photo'
                          : 'Photo added',
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: _submitting ? null : _submit,
                      child: _submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Post'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
