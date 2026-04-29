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
import 'package:shared_preferences/shared_preferences.dart';

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
  static const String _draftKeyPrefix = 'update_submission_draft_v1';
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
  bool _hasTypedContent = false;

  String get _draftKey => '$_draftKeyPrefix:${widget.currentUser?.id ?? 0}';

  @override
  void initState() {
    super.initState();
    _hasTypedContent = _controller.text.trim().isNotEmpty;
    unawaited(_restoreDraft());
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
    unawaited(_persistDraft(_controller.text));
    final hasTypedContent = _controller.text.trim().isNotEmpty;
    if (!mounted || hasTypedContent == _hasTypedContent) {
      return;
    }
    setState(() {
      _hasTypedContent = hasTypedContent;
    });
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
        final rankedSuggestions = _rankMentionSuggestions(query, suggestions);
        if (!mounted || requestId != _mentionRequestId) {
          return;
        }
        setState(() {
          _mentionSuggestions = rankedSuggestions;
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

  List<MentionSuggestion> _rankMentionSuggestions(
    String query,
    List<MentionSuggestion> suggestions,
  ) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty || suggestions.length < 2) {
      return suggestions;
    }

    int score(MentionSuggestion item) {
      final full = item.fullname.trim().toLowerCase();
      final user = item.username.trim().toLowerCase();
      if (full.isNotEmpty && full.startsWith(normalized)) return 0;
      if (full.isNotEmpty && full.contains(normalized)) return 1;
      if (user.startsWith(normalized)) return 2;
      if (user.contains(normalized)) return 3;
      return 4;
    }

    final ranked = List<MentionSuggestion>.from(suggestions);
    ranked.sort((a, b) {
      final sa = score(a);
      final sb = score(b);
      if (sa != sb) return sa.compareTo(sb);
      final af = a.fullname.trim();
      final bf = b.fullname.trim();
      if (af.isNotEmpty != bf.isNotEmpty) {
        return af.isNotEmpty ? -1 : 1;
      }
      return a.username.toLowerCase().compareTo(b.username.toLowerCase());
    });
    return ranked;
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
    _restoreComposerFocus();
  }

  void _restoreComposerFocus() {
    if (!mounted) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (!_composerFocusNode.hasFocus) {
        _composerFocusNode.requestFocus();
      }
    });
  }

  Future<void> _restoreDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final draft = prefs.getString(_draftKey);
    if (!mounted || draft == null || draft.isEmpty) {
      return;
    }
    _controller.value = TextEditingValue(
      text: draft,
      selection: TextSelection.collapsed(offset: draft.length),
    );
    final hasTypedContent = draft.trim().isNotEmpty;
    if (hasTypedContent != _hasTypedContent) {
      setState(() {
        _hasTypedContent = hasTypedContent;
      });
    }
  }

  Future<void> _persistDraft(String value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value.trim().isEmpty) {
      await prefs.remove(_draftKey);
      return;
    }
    await prefs.setString(_draftKey, value);
  }

  Future<void> _clearDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_draftKey);
  }

  Future<void> _discardAndClose() async {
    _controller.clear();
    if (mounted) {
      setState(() {
        _selectedPhoto = null;
        _selectedPhotoBytes = null;
        _showEmojiPicker = false;
        _clearMentionState();
        _hasTypedContent = false;
      });
    }
    await _clearDraft();
    if (mounted) {
      Navigator.of(context).pop();
    }
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

  void _insertTrigger(String trigger) {
    final value = _controller.value;
    final text = value.text;
    final cursor = value.selection.baseOffset;
    final safeCursor = cursor < 0 ? text.length : cursor.clamp(0, text.length);

    final before = text.substring(0, safeCursor);
    final after = text.substring(safeCursor);
    final needsLeadingSpace =
        before.isNotEmpty && !RegExp(r'\s$').hasMatch(before);
    final insertion = '${needsLeadingSpace ? ' ' : ''}$trigger';
    final nextText = '$before$insertion$after';
    final nextOffset = before.length + insertion.length;

    _controller.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: nextOffset),
    );

    setState(() {
      _showEmojiPicker = false;
    });
    _composerFocusNode.requestFocus();
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
      await _clearDraft();
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

  Widget _buildFloatingMentionPanel(double keyboardInset) {
    final colors = context.appColors;
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(18),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: keyboardInset > 0 ? 112 : 148,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: colors.borderStrong),
          ),
          child: _mentionLoading
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
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
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  shrinkWrap: true,
                  itemCount: _mentionSuggestions.length,
                  separatorBuilder: (_, unused) => Divider(
                    height: 1,
                    color: colors.border.withValues(alpha: 0.55),
                  ),
                  itemBuilder: (context, index) {
                    final suggestion = _mentionSuggestions[index];
                    return InkWell(
                      canRequestFocus: false,
                      onTapDown: (_) => _restoreComposerFocus(),
                      onTap: () => _insertMention(suggestion),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            AppAvatar(
                              imageUrl: suggestion.photoUrl,
                              label: suggestion.fullname,
                              radius: 16,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          suggestion.fullname.trim().isEmpty
                                              ? suggestion.username
                                              : suggestion.fullname,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: colors.textPrimary,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      if (suggestion.isVerified) ...[
                                        const SizedBox(width: 4),
                                        Icon(
                                          Icons.verified_rounded,
                                          size: 14,
                                          color: colors.brand,
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '@${suggestion.username}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: colors.textMuted,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final hasContent = _hasTypedContent || _selectedPhoto != null;
    final canSubmit = !_submitting && hasContent;
    final mediaQuery = MediaQuery.of(context);
    final keyboardInset = mediaQuery.viewInsets.bottom;
    final maxSheetHeight = mediaQuery.size.height * 0.82;

    return SafeArea(
      top: false,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(bottom: keyboardInset),
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 24, 16, keyboardInset > 0 ? 0 : 12),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxSheetHeight),
            child: Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: colors.borderStrong),
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
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
                              color: colors.surfaceMuted.withValues(alpha: 0.45),
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
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _ComposerHintPill(
                                  icon: Icons.alternate_email_rounded,
                                  label: '@Mention',
                                  onTap: _submitting
                                      ? null
                                      : () => _insertTrigger('@'),
                                ),
                                _ComposerHintPill(
                                  icon: Icons.tag_rounded,
                                  label: '#Hashtag',
                                  onTap: _submitting
                                      ? null
                                      : () => _insertTrigger('#'),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if ((_mentionLoading ||
                                        _mentionSuggestions.isNotEmpty) &&
                                    _composerFocusNode.hasFocus) ...[
                                  _buildFloatingMentionPanel(keyboardInset),
                                  const SizedBox(height: 8),
                                ],
                                TextFormField(
                                  controller: _controller,
                                  focusNode: _composerFocusNode,
                                  textCapitalization:
                                      TextCapitalization.sentences,
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
                                    fontSize: 16,
                                    height: 1.55,
                                    fontWeight: FontWeight.w400,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Share your thoughts...',
                                    hintStyle: TextStyle(
                                      color: colors.textMuted.withValues(
                                        alpha: 0.55,
                                      ),
                                      fontSize: 16,
                                      fontWeight: FontWeight.w400,
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
                              ],
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
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                            child: Row(
                              children: [
                                _ComposerActionButton(
                                  icon: Icons.image_outlined,
                                  label: 'Choose image',
                                  backgroundColor: colors.brand.withValues(
                                    alpha: 0.12,
                                  ),
                                  foregroundColor: colors.brandStrong,
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
                    height: keyboardInset > 0 ? 260 : 320,
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
                      ],
                    ),
                  ),
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
                  decoration: BoxDecoration(
                    color: colors.surfaceMuted.withValues(alpha: 0.45),
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
                            : _discardAndClose,
                        child: const Text('Discard'),
                      ),
                      const Spacer(),
                      Container(
                        decoration: BoxDecoration(
                          color: canSubmit
                              ? colors.brand
                              : colors.surface.withValues(alpha: 0.96),
                          borderRadius: BorderRadius.circular(18),
                          border: canSubmit
                              ? null
                              : Border.all(color: colors.borderStrong),
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
    this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.onPressed,
  });

  final IconData icon;
  final String? label;
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
        child: Container(
          height: 46,
          padding: EdgeInsets.symmetric(horizontal: label == null ? 0 : 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: label == null ? 46 : null,
                child: Icon(icon, color: foregroundColor),
              ),
              if (label != null) ...[
                const SizedBox(width: 8),
                Text(
                  label!,
                  style: TextStyle(
                    color: foregroundColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ComposerHintPill extends StatelessWidget {
  const _ComposerHintPill({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Material(
      color: colors.surfaceMuted.withValues(alpha: 0.9),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: colors.borderStrong),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: colors.textSecondary),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
