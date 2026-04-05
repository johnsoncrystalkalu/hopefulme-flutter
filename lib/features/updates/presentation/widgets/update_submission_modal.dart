import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
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
  bool _showEmojiPicker = false;
  XFile? _selectedPhoto;
  Uint8List? _selectedPhotoBytes;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    FocusScope.of(context).unfocus();
    final photo = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: kIsWeb ? null : 88,
      maxWidth: 1800,
    );
    if (photo == null || !mounted) {
      return;
    }
    final bytes = await photo.readAsBytes();
    setState(() {
      _selectedPhoto = photo;
      _selectedPhotoBytes = bytes;
      _showEmojiPicker = false;
    });
  }

  void _toggleEmojiPicker() {
    FocusScope.of(context).unfocus();
    setState(() {
      _showEmojiPicker = !_showEmojiPicker;
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
    final hasContent =
        _controller.text.trim().isNotEmpty || _selectedPhoto != null;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(32),
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            IconButton(
                              onPressed:
                                  _submitting ? null : () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.arrow_back_rounded),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Text(
                                //   'Create Update',
                                //     style: TextStyle(
                                //       color: colors.textPrimary,
                                //       fontSize: 20,
                                //       fontWeight: FontWeight.w900,
                                //     ),
                                //   ),
                              ],
                            ),
                          ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7ED),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: const Color(0xFFFED7AA)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(
                              Icons.auto_awesome_rounded,
                              size: 12,
                              color: Color(0xFFD97706),
                            ),
                            SizedBox(width: 5),
                            Text(
                              'INSPIRING MODE',
                              style: TextStyle(
                                color: Color(0xFFD97706),
                                fontSize: 9.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.7,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: colors.border.withValues(alpha: 0.65),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: colors.shadow.withValues(alpha: 0.06),
                          blurRadius: 30,
                          offset: const Offset(0, 12),
                          spreadRadius: -22,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  colors.surfaceMuted.withValues(alpha: 0.85),
                                  colors.surface.withValues(alpha: 0.0),
                                ],
                              ),
                            ),
                            child: Row(
                              children: [
                                Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    CircleAvatar(
                                      radius: 28,
                                      backgroundImage:
                                          widget.currentUser?.photoUrl.isNotEmpty == true
                                          ? NetworkImage(
                                              ImageUrlResolver.avatar(
                                                widget.currentUser!.photoUrl,
                                                size: 84,
                                              ),
                                            )
                                          : null,
                                      child:
                                          widget.currentUser?.photoUrl.isEmpty ?? true
                                          ? const Icon(Icons.person)
                                          : null,
                                    ),
                                    Positioned(
                                      right: -1,
                                      bottom: -1,
                                      child: Container(
                                        width: 14,
                                        height: 14,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF22C55E),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: colors.surface,
                                            width: 2,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 14),
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
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: colors.surface,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: colors.border),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.public_rounded,
                                              size: 14,
                                              color: colors.brand,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              'Anyone can see',
                                              style: TextStyle(
                                                color: colors.textSecondary,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                            child: TextFormField(
                              controller: _controller,
                              minLines: 6,
                              maxLines: 10,
                              onTap: () {
                                if (_showEmojiPicker) {
                                  setState(() {
                                    _showEmojiPicker = false;
                                  });
                                }
                              },
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: 18,
                                height: 1.55,
                                fontWeight: FontWeight.w500,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Share your thoughts...',
                                hintStyle: TextStyle(
                                  color: colors.textMuted.withValues(alpha: 0.55),
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                ),
                                border: InputBorder.none,
                              ),
                              validator: (value) {
                                if ((value == null || value.trim().isEmpty) &&
                                    _selectedPhoto == null) {
                                  return 'Please write something or add a photo.';
                                }
                                return null;
                              },
                            ),
                          ),
                          if (_selectedPhoto != null)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                              child: Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(24),
                                    child: AspectRatio(
                                      aspectRatio: 4 / 3,
                                      child: _selectedPhotoBytes != null
                                          ? Image.memory(
                                              _selectedPhotoBytes!,
                                              fit: BoxFit.cover,
                                            )
                                          : Container(color: colors.accentSoft),
                                    ),
                                  ),
                                  Positioned(
                                    top: 12,
                                    right: 12,
                                    child: Material(
                                      color: colors.surface.withValues(alpha: 0.92),
                                      shape: const CircleBorder(),
                                      child: IconButton(
                                        onPressed: _submitting
                                            ? null
                                            : () {
                                                setState(() {
                                                  _selectedPhoto = null;
                                                  _selectedPhotoBytes = null;
                                                });
                                              },
                                        icon: const Icon(Icons.close_rounded),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                            child: Row(
                              children: [
                                _ComposerActionButton(
                                  icon: Icons.image_outlined,
                                  backgroundColor: colors.accentSoft,
                                  foregroundColor: colors.brand,
                                  onPressed: _submitting ? null : _pickPhoto,
                                ),
                                const SizedBox(width: 10),
                                _ComposerActionButton(
                                  icon: _showEmojiPicker
                                      ? Icons.keyboard_rounded
                                      : Icons.emoji_emotions_outlined,
                                  backgroundColor: colors.warningSoft,
                                  foregroundColor: colors.warningText,
                                  onPressed: _submitting ? null : _toggleEmojiPicker,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_showEmojiPicker)
                  SizedBox(
                    height: 320,
                    child: EmojiPicker(
                      textEditingController: _controller,
                      onBackspacePressed: () {},
                      config: Config(
                        height: 320,
                        checkPlatformCompatibility: true,
                        emojiViewConfig: EmojiViewConfig(
                          emojiSizeMax: 26,
                          backgroundColor: colors.surfaceMuted,
                        ),
                        categoryViewConfig: CategoryViewConfig(
                          backgroundColor: colors.surface,
                          indicatorColor: colors.brand,
                          iconColor: colors.textMuted,
                          iconColorSelected: colors.brand,
                          backspaceColor: colors.brand,
                          dividerColor: colors.border,
                        ),
                        bottomActionBarConfig: const BottomActionBarConfig(
                          enabled: false,
                        ),
                        searchViewConfig: SearchViewConfig(
                          backgroundColor: colors.surfaceMuted,
                          buttonIconColor: colors.textMuted,
                          inputTextStyle: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 14,
                          ),
                          hintTextStyle: TextStyle(
                            color: colors.textMuted,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
                  decoration: BoxDecoration(
                    color: colors.surfaceMuted.withValues(alpha: 0.65),
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(32),
                    ),
                    border: Border(
                      top: BorderSide(
                        color: colors.border.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      TextButton(
                        onPressed:
                            _submitting ? null : () => Navigator.of(context).pop(),
                        child: const Text('Discard'),
                      ),
                      const Spacer(),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [colors.brand, colors.brandStrong],
                          ),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: colors.brand.withValues(alpha: 0.22),
                              blurRadius: 24,
                              offset: const Offset(0, 10),
                              spreadRadius: -16,
                            ),
                          ],
                        ),
                        child: FilledButton.icon(
                          onPressed: _submitting || !hasContent ? null : _submit,
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            disabledBackgroundColor: colors.borderStrong,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          icon: _submitting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.send_rounded, size: 18),
                          label: Text(
                            _submitting ? 'Posting...' : 'Post Update',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ComposerActionButton extends StatelessWidget {
  const _ComposerActionButton({
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.onPressed,
  });

  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 46,
          height: 46,
          child: Icon(icon, color: foregroundColor),
        ),
      ),
    );
  }
}
