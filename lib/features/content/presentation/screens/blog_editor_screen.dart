import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hopefulme_flutter/app/theme/app_theme.dart';
import 'package:hopefulme_flutter/features/content/data/content_repository.dart';
import 'package:hopefulme_flutter/features/content/models/content_detail.dart';

class BlogEditorScreen extends StatefulWidget {
  const BlogEditorScreen.create({
    required this.repository,
    required this.currentUsername,
    super.key,
  }) : initialDetail = null;

  const BlogEditorScreen.edit({
    required this.repository,
    required this.currentUsername,
    required this.initialDetail,
    super.key,
  });

  final ContentRepository repository;
  final String? currentUsername;
  final ContentDetail? initialDetail;

  bool get isEditing => initialDetail != null;

  @override
  State<BlogEditorScreen> createState() => _BlogEditorScreenState();
}

class _BlogEditorScreenState extends State<BlogEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _labelController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  XFile? _selectedPhoto;
  Uint8List? _selectedPhotoBytes;
  bool _removeExistingPhoto = false;
  bool _isSaving = false;
  String? _selectedTag;
  Object? _error;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialDetail;
    _titleController.text = initial?.title ?? '';
    _contentController.text = initial?.body ?? '';
    _labelController.text =
        initial?.label ?? _defaultLabel(widget.currentUsername);
    _selectedTag = initial?.tag.isNotEmpty == true
        ? initial!.tag
        : ContentRepository.blogTags.first;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _labelController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2600,
      imageQuality: kIsWeb ? null : 90,
    );
    if (picked == null || !mounted) {
      return;
    }

    final bytes = await picked.readAsBytes();
    if (!mounted) {
      return;
    }

    setState(() {
      _selectedPhoto = picked;
      _selectedPhotoBytes = bytes;
      _removeExistingPhoto = false;
    });
  }

  Future<void> _save() async {
    if (_isSaving || !_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final result = widget.isEditing
          ? await widget.repository.updateBlog(
              blogId: widget.initialDetail!.id,
              title: _titleController.text.trim(),
              content: _contentController.text.trim(),
              tag: _selectedTag!,
              label: _labelController.text.trim(),
              photo: _selectedPhoto,
              removePhoto: _removeExistingPhoto,
            )
          : await widget.repository.createBlog(
              title: _titleController.text.trim(),
              content: _contentController.text.trim(),
              tag: _selectedTag!,
              label: _labelController.text.trim(),
              photo: _selectedPhoto,
            );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(result);
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
          _isSaving = false;
        });
      }
    }
  }

  void _removePhoto() {
    setState(() {
      _selectedPhoto = null;
      _selectedPhotoBytes = null;
      _removeExistingPhoto = widget.initialDetail?.photoUrl.isNotEmpty == true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final hasExistingPhoto =
        widget.initialDetail?.photoUrl.isNotEmpty == true &&
        !_removeExistingPhoto &&
        _selectedPhotoBytes == null;

    return Scaffold(
      backgroundColor: colors.scaffold,
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Article' : 'Write Article'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: colors.borderStrong),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.isEditing
                          ? 'Refresh your article'
                          : 'Publish an article',
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Contribute to the HopefulMe community with a thoughtful story, reflection, or encouragement.',
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _SectionLabel(label: 'Title'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _titleController,
                      maxLength: 100,
                      decoration: _inputDecoration(
                        context,
                        hintText: 'Enter title',
                      ),
                      validator: (value) {
                        if ((value ?? '').trim().isEmpty) {
                          return 'Please add a title.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    _SectionLabel(label: 'Body'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _contentController,
                      minLines: 10,
                      maxLines: 16,
                      decoration: _inputDecoration(
                        context,
                        hintText: 'Start writing...',
                      ),
                      validator: (value) {
                        if ((value ?? '').trim().isEmpty) {
                          return 'Please write your article.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        SizedBox(
                          width: 320,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _SectionLabel(label: 'Featured Image'),
                              const SizedBox(height: 8),
                              _ImagePickerCard(
                                imageUrl: hasExistingPhoto
                                    ? widget.initialDetail!.photoUrl
                                    : '',
                                bytes: _selectedPhotoBytes,
                                onTap: _pickPhoto,
                                onRemove:
                                    hasExistingPhoto ||
                                        _selectedPhotoBytes != null
                                    ? _removePhoto
                                    : null,
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: 320,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _SectionLabel(label: 'Tag'),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String>(
                                initialValue: _selectedTag,
                                decoration: _inputDecoration(
                                  context,
                                  hintText: 'Select tag',
                                ),
                                items: ContentRepository.blogTags
                                    .map(
                                      (tag) => DropdownMenuItem<String>(
                                        value: tag,
                                        child: Text(tag),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _selectedTag = value;
                                  });
                                },
                                validator: (value) {
                                  if ((value ?? '').trim().isEmpty) {
                                    return 'Please choose a tag.';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              const _SectionLabel(label: 'Your Label'),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _labelController,
                                decoration: _inputDecoration(
                                  context,
                                  hintText: 'Hopeful_username',
                                ),
                                validator: (value) {
                                  if ((value ?? '').trim().isEmpty) {
                                    return 'Please add your label.';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _error.toString(),
                        style: TextStyle(
                          color: colors.dangerText,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _isSaving ? null : _save,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send_rounded),
                      label: Text(
                        _isSaving
                            ? (widget.isEditing ? 'Saving...' : 'Publishing...')
                            : (widget.isEditing
                                  ? 'Save Changes'
                                  : 'Publish Article'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Text(
      label,
      style: TextStyle(
        color: colors.textPrimary,
        fontSize: 13,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _ImagePickerCard extends StatelessWidget {
  const _ImagePickerCard({
    required this.imageUrl,
    required this.bytes,
    required this.onTap,
    required this.onRemove,
  });

  final String imageUrl;
  final Uint8List? bytes;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: bytes != null
                  ? Image.memory(bytes!, fit: BoxFit.cover)
                  : imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: colors.icon,
                        ),
                      ),
                    )
                  : Center(
                      child: Icon(
                        Icons.image_outlined,
                        size: 36,
                        color: colors.icon,
                      ),
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onTap,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: Text(
                      imageUrl.isNotEmpty || bytes != null
                          ? 'Change Image'
                          : 'Choose Image',
                    ),
                  ),
                ),
                if (onRemove != null) ...[
                  const SizedBox(width: 10),
                  IconButton(
                    onPressed: onRemove,
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Remove image',
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

InputDecoration _inputDecoration(
  BuildContext context, {
  required String hintText,
}) {
  final colors = context.appColors;
  return InputDecoration(
    hintText: hintText,
    filled: true,
    fillColor: colors.surfaceMuted,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(color: colors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(color: colors.brand, width: 1.5),
    ),
  );
}

String _defaultLabel(String? username) {
  final value = (username ?? '').trim();
  return value.isEmpty ? 'Hopeful_writer' : 'Hopeful_$value';
}
