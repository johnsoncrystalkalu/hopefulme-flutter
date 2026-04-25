import 'dart:async';

import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hopefulme_flutter/app/theme/app_theme.dart';
import 'package:hopefulme_flutter/core/network/image_url_resolver.dart';
import 'package:hopefulme_flutter/core/widgets/app_avatar.dart';
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
  final FocusNode _composerFocusNode = FocusNode();

  bool _submitting = false;
  bool _showEmojiPicker = false;
  XFile? _selectedPhoto;
  Uint8List? _selectedPhotoBytes;
  List<MentionSuggestion> _mentionSuggestions = const <MentionSuggestion>[];
  Timer? _mentionDebounce;
  int _mentionRequestId = 0;
  bool _mentionLoading = false;
  int? _activeMentionStart;
  String _activeMentionQuery = '';

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleComposerChanged);
    _composerFocusNode.addListener(() {
      if (!_composerFocusNode.hasFocus && mounted) {
        setState(() {
          _clearMentionState();
        });
      }
    });
  }

  @override
  void dispose() {
    _mentionDebounce?.cancel();
    _composerFocusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleComposerChanged() {
    _updateMentionSuggestions();
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  void _clearMentionState() {
    _mentionDebounce?.cancel();
    _activeMentionStart = null;
    _activeMentionQuery = '';
    _mentionLoading = false;
    _mentionSuggestions = const <MentionSuggestion>[];
  }

  void _updateMentionSuggestions() {
    final token = _extractActiveMentionToken(_controller.value);
    if (token == null || !_composerFocusNode.hasFocus) {
      if (_activeMentionStart != null ||
          _mentionSuggestions.isNotEmpty ||
          _mentionLoading) {
        setState(_clearMentionState);
      }
      return;
    }

    _activeMentionStart = token.start;
    final query = token.query;
    if (query == _activeMentionQuery &&
        (_mentionSuggestions.isNotEmpty || _mentionLoading)) {
      return;
    }
    _activeMentionQuery = query;

    _mentionDebounce?.cancel();
    _mentionDebounce = Timer(const Duration(milliseconds: 180), () async {
      final requestId = ++_mentionRequestId;
      if (mounted) {
        setState(() {
          _mentionLoading = true;
        });
      }

      try {
        final suggestions = await widget.updateRepository
            .fetchMentionSuggestions(query, limit: query.isEmpty ? 4 : 6);
        if (!mounted || requestId != _mentionRequestId) {
          return;
        }
        setState(() {
          _mentionSuggestions = suggestions;
          _mentionLoading = false;
        });
      } catch (_) {
        if (!mounted || requestId != _mentionRequestId) {
          return;
        }
        setState(() {
          _mentionSuggestions = const <MentionSuggestion>[];
          _mentionLoading = false;
        });
      }
    });
  }

  _MentionToken? _extractActiveMentionToken(TextEditingValue value) {
    final cursor = value.selection.baseOffset;
    if (cursor < 0 || cursor > value.text.length) {
      return null;
    }

    final beforeCursor = value.text.substring(0, cursor);
    final match = RegExp(r'(^|\s)@([a-zA-Z0-9_-]*)$').firstMatch(beforeCursor);
    if (match == null) {
      return null;
    }

    final prefix = match.group(1) ?? '';
    final query = match.group(2) ?? '';
    final start = match.start + prefix.length;
    return _MentionToken(start: start, query: query);
  }

  void _insertMention(MentionSuggestion suggestion) {
    final value = _controller.value;
    final cursor = value.selection.baseOffset;
    final mentionStart = _activeMentionStart;
    if (cursor < 0 || mentionStart == null || mentionStart > cursor) {
      return;
    }

    final text = value.text;
    final replaced =
        '${text.substring(0, mentionStart)}@${suggestion.username} '
        '${text.substring(cursor)}';
    final nextOffset = mentionStart + suggestion.username.length + 2;

    _controller.value = TextEditingValue(
      text: replaced,
      selection: TextSelection.collapsed(offset: nextOffset),
    );
    setState(_clearMentionState);
    _composerFocusNode.requestFocus();
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
      _clearMentionState();
    });
  }

  void _toggleEmojiPicker() {
    FocusScope.of(context).unfocus();
    setState(() {
      _showEmojiPicker = !_showEmojiPicker;
      if (_showEmojiPicker) {
        _clearMentionState();
      }
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
    final canSubmit = !_submitting && hasContent;

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
                              onPressed: _submitting
                                  ? null
                                  : () => Navigator.of(context).pop(),
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
                                          widget
                                                  .currentUser
                                                  ?.photoUrl
                                                  .isNotEmpty ==
                                              true
                                          ? NetworkImage(
                                              ImageUrlResolver.avatar(
                                                widget.currentUser!.photoUrl,
                                                size: 84,
                                              ),
                                            )
                                          : null,
                                      child:
                                          widget
                                                  .currentUser
                                                  ?.photoUrl
                                                  .isEmpty ??
                                              true
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: colors.border,
                                          ),
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
                                              'Everyone',
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
                              focusNode: _composerFocusNode,
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
                                hintText:
                                    'Share your thoughts...  (Type @ to mention someone)',
                                hintStyle: TextStyle(
                                  color: colors.textMuted.withValues(
                                    alpha: 0.55,
                                  ),
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
                          if (_mentionLoading || _mentionSuggestions.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 160),
                                curve: Curves.easeOut,
                                constraints: const BoxConstraints(
                                  maxHeight: 220,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.surface,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: colors.borderStrong,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: colors.shadow.withValues(
                                        alpha: 0.09,
                                      ),
                                      blurRadius: 20,
                                      offset: const Offset(0, 8),
                                      spreadRadius: -12,
                                    ),
                                  ],
                                ),
                                child: _mentionLoading
                                    ? Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 18,
                                        ),
                                        child: Center(
                                          child: SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: colors.brand,
                                            ),
                                          ),
                                        ),
                                      )
                                    : ListView.separated(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 6,
                                        ),
                                        shrinkWrap: true,
                                        itemCount: _mentionSuggestions.length,
                                        separatorBuilder: (_, unused) =>
                                            Divider(
                                              height: 1,
                                              color: colors.border.withValues(
                                                alpha: 0.55,
                                              ),
                                            ),
                                        itemBuilder: (context, index) {
                                          final suggestion =
                                              _mentionSuggestions[index];
                                          return InkWell(
                                            onTap: () =>
                                                _insertMention(suggestion),
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 10,
                                                  ),
                                              child: Row(
                                                children: [
                                                  AppAvatar(
                                                    imageUrl:
                                                        suggestion.photoUrl,
                                                    label: suggestion.fullname,
                                                    radius: 16,
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Row(
                                                          children: [
                                                            Flexible(
                                                              child: Text(
                                                                suggestion
                                                                        .fullname
                                                                        .trim()
                                                                        .isEmpty
                                                                    ? suggestion
                                                                          .username
                                                                    : suggestion
                                                                          .fullname,
                                                                maxLines: 1,
                                                                overflow:
                                                                    TextOverflow
                                                                        .ellipsis,
                                                                style: TextStyle(
                                                                  color: colors
                                                                      .textPrimary,
                                                                  fontSize: 13,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w700,
                                                                ),
                                                              ),
                                                            ),
                                                            if (suggestion
                                                                .isVerified) ...[
                                                              const SizedBox(
                                                                width: 4,
                                                              ),
                                                              Icon(
                                                                Icons
                                                                    .verified_rounded,
                                                                size: 14,
                                                                color: colors
                                                                    .brand,
                                                              ),
                                                            ],
                                                          ],
                                                        ),
                                                        const SizedBox(
                                                          height: 2,
                                                        ),
                                                        Text(
                                                          '@${suggestion.username}',
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style: TextStyle(
                                                            color: colors
                                                                .textMuted,
                                                            fontSize: 12,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
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
                                      color: colors.surface.withValues(
                                        alpha: 0.92,
                                      ),
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
                                  onPressed: _submitting
                                      ? null
                                      : _toggleEmojiPicker,
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
                        onPressed: _submitting
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: const Text('Discard'),
                      ),
                      const Spacer(),
                      Container(
                        decoration: BoxDecoration(
                          color: canSubmit
                              ? null
                              : colors.surface.withValues(alpha: 0.96),
                          gradient: canSubmit
                              ? LinearGradient(
                                  colors: [colors.brand, colors.brandStrong],
                                )
                              : null,
                          borderRadius: BorderRadius.circular(18),
                          border: canSubmit
                              ? null
                              : Border.all(color: colors.borderStrong),
                          boxShadow: canSubmit
                              ? [
                                  BoxShadow(
                                    color: colors.brand.withValues(alpha: 0.22),
                                    blurRadius: 24,
                                    offset: const Offset(0, 10),
                                    spreadRadius: -16,
                                  ),
                                ]
                              : [],
                        ),
                        child: FilledButton.icon(
                          onPressed: canSubmit ? _submit : null,
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            disabledBackgroundColor: Colors.transparent,
                            disabledForegroundColor: colors.textMuted,
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

class _MentionToken {
  const _MentionToken({required this.start, required this.query});

  final int start;
  final String query;
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
