import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hopefulme_flutter/app/theme/app_theme.dart';
import 'package:hopefulme_flutter/core/widgets/app_status_state.dart';
import 'package:hopefulme_flutter/core/utils/time_formatter.dart';
import 'package:hopefulme_flutter/features/auth/models/user.dart';
import 'package:hopefulme_flutter/features/feed/data/feed_repository.dart';
import 'package:hopefulme_flutter/features/feed/models/feed_dashboard.dart';
import 'package:hopefulme_flutter/features/messages/data/message_repository.dart';
import 'package:hopefulme_flutter/features/profile/data/profile_repository.dart';
import 'package:hopefulme_flutter/features/profile/presentation/profile_navigation.dart';
import 'package:hopefulme_flutter/features/updates/data/update_repository.dart';
import 'package:hopefulme_flutter/features/updates/presentation/screens/update_detail_screen.dart';
import 'package:hopefulme_flutter/features/updates/presentation/widgets/interactive_update_card.dart';

class UpdatesFeedScreen extends StatefulWidget {
  const UpdatesFeedScreen({
    required this.feedRepository,
    required this.updateRepository,
    required this.profileRepository,
    required this.messageRepository,
    required this.currentUser,
    super.key,
  });

  final FeedRepository feedRepository;
  final UpdateRepository updateRepository;
  final ProfileRepository profileRepository;
  final MessageRepository messageRepository;
  final User? currentUser;

  @override
  State<UpdatesFeedScreen> createState() => _UpdatesFeedScreenState();
}

class _UpdatesFeedScreenState extends State<UpdatesFeedScreen> {
  final ScrollController _scrollController = ScrollController();
  final List<FeedEntry> _items = <FeedEntry>[];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadInitial();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _page = 1;
      _hasMore = true;
      _items.clear();
    });

    try {
      final page = await widget.feedRepository.fetchUpdatesPage(page: 1);
      if (!mounted) return;
      setState(() {
        _items.addAll(page.items);
        _hasMore = page.hasMore;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) {
      return;
    }

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final nextPage = _page + 1;
      final page = await widget.feedRepository.fetchUpdatesPage(page: nextPage);
      if (!mounted) return;
      setState(() {
        _page = nextPage;
        _items.addAll(page.items);
        _hasMore = page.hasMore;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 240) {
      _loadMore();
    }
  }

  Future<void> _openProfile(String username) {
    return openUserProfile(
      context,
      profileRepository: widget.profileRepository,
      messageRepository: widget.messageRepository,
      updateRepository: widget.updateRepository,
      currentUser: widget.currentUser,
      username: username,
    );
  }

  Future<void> _openUpdate(FeedEntry entry) async {
    final result = await Navigator.of(context).push<UpdateDetailResult>(
      MaterialPageRoute<UpdateDetailResult>(
        builder: (context) => UpdateDetailScreen(
          updateId: entry.id,
          currentUser: widget.currentUser,
          repository: widget.updateRepository,
          profileRepository: widget.profileRepository,
          messageRepository: widget.messageRepository,
        ),
      ),
    );

    if (result?.shouldRefresh == true) {
      await _loadInitial();
    }
  }

  Future<void> _openCreateUpdate() async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final imagePicker = ImagePicker();

    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final colors = context.appColors;
        bool submitting = false;
        XFile? selectedPhoto;
        Uint8List? selectedPhotoBytes;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> pickPhoto() async {
              final photo = await imagePicker.pickImage(
                source: ImageSource.gallery,
                imageQuality: kIsWeb ? null : 88,
              );
              if (photo == null || !context.mounted) {
                return;
              }
              final bytes = await photo.readAsBytes();
              setSheetState(() {
                selectedPhoto = photo;
                selectedPhotoBytes = bytes;
              });
            }

            Future<void> submit() async {
              final hasText = controller.text.trim().isNotEmpty;
              final hasPhoto = selectedPhoto != null;
              if ((!hasText && !hasPhoto) || submitting) {
                formKey.currentState?.validate();
                return;
              }
              var dismissed = false;
              setSheetState(() {
                submitting = true;
              });
              try {
                await widget.updateRepository.createUpdate(
                  status: controller.text.trim(),
                  photo: selectedPhoto,
                );
                if (context.mounted) {
                  dismissed = true;
                  Navigator.of(context).pop(true);
                }
              } catch (error) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'We could not post your update right now. Please try again.',
                      ),
                    ),
                  );
                }
              } finally {
                if (context.mounted && !dismissed) {
                  setSheetState(() {
                    submitting = false;
                  });
                }
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: colors.border),
                  ),
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundImage:
                                  widget.currentUser?.photoUrl.isNotEmpty == true
                                  ? NetworkImage(widget.currentUser!.photoUrl)
                                  : null,
                              child: widget.currentUser?.photoUrl.isEmpty ?? true
                                  ? const Icon(Icons.person)
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                widget.currentUser?.displayName ?? 'Share an update',
                                style: TextStyle(
                                  color: colors.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: submitting
                                  ? null
                                  : () => Navigator.of(context).pop(false),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: controller,
                          minLines: 5,
                          maxLines: 8,
                          decoration: InputDecoration(
                            hintText: 'What is on your mind?',
                            filled: true,
                            fillColor: colors.surfaceMuted,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          validator: (_) {
                            if (controller.text.trim().isEmpty &&
                                selectedPhoto == null) {
                              return 'Add text or a photo to post an update.';
                            }
                            return null;
                          },
                        ),
                        if (selectedPhotoBytes != null) ...[
                          const SizedBox(height: 14),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Image.memory(
                              selectedPhotoBytes!,
                              height: 180,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            OutlinedButton.icon(
                              onPressed: submitting ? null : pickPhoto,
                              icon: const Icon(Icons.image_outlined),
                              label: const Text('Add Photo'),
                            ),
                            const Spacer(),
                            FilledButton(
                              onPressed: submitting ? null : submit,
                              child: submitting
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('Post Update'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    controller.dispose();
    if (created == true) {
      await _loadInitial();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appColors.scaffold,
      appBar: AppBar(title: const Text('Activities')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? AppStatusState.fromError(
              error: _error!,
              actionLabel: 'Try again',
              onAction: _loadInitial,
            )
          : RefreshIndicator(
              onRefresh: _loadInitial,
              child: ListView.separated(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _items.length + (_isLoadingMore ? 1 : 0) + 1,
                separatorBuilder: (_, __) => const SizedBox(height: 14),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _ActivitiesComposerCard(
                      user: widget.currentUser,
                      onTap: _openCreateUpdate,
                    );
                  }

                  final itemIndex = index - 1;
                  if (itemIndex >= _items.length) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final entry = _items[itemIndex];
                  return InteractiveUpdateCard(
                    updateId: entry.id,
                    title: entry.user?.displayName ?? entry.title,
                    body: entry.body,
                    photoUrl: entry.photoUrl,
                    avatarUrl: entry.user?.photoUrl ?? '',
                    fallbackLabel: entry.user?.displayName ?? entry.title,
                    device: entry.device,
                    createdAt: entry.createdAt,
                    likesCount: entry.likesCount,
                    commentsCount: entry.commentsCount,
                    views: entry.views,
                    updateRepository: widget.updateRepository,
                    currentUser: widget.currentUser,
                    ownerUsername: entry.user?.username,
                    onOpenProfile: _openProfile,
                    onOpenUpdate: () => _openUpdate(entry),
                  );
                },
              ),
            ),
    );
  }
}

class _ActivitiesComposerCard extends StatelessWidget {
  const _ActivitiesComposerCard({
    required this.user,
    required this.onTap,
  });

  final User? user;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return InkWell(
      onTap: () => onTap(),
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: colors.borderStrong),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundImage:
                  user?.photoUrl.isNotEmpty == true ? NetworkImage(user!.photoUrl) : null,
              child: user?.photoUrl.isEmpty ?? true ? const Icon(Icons.person) : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: colors.surfaceMuted,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  'What is on your mind?',
                  style: TextStyle(
                    color: colors.textMuted,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: colors.brandGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}


