import 'dart:async';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hopefulme_flutter/app/theme/app_theme.dart';
import 'package:hopefulme_flutter/app/theme/theme_controller.dart';
import 'package:hopefulme_flutter/core/utils/time_formatter.dart';
import 'package:hopefulme_flutter/core/config/app_config.dart';
import 'package:hopefulme_flutter/core/presentation/screens/web_page_screen.dart';
import 'package:hopefulme_flutter/core/widgets/app_avatar.dart';
import 'package:hopefulme_flutter/core/widgets/app_network_image.dart';
import 'package:hopefulme_flutter/core/widgets/app_toast.dart';
import 'package:hopefulme_flutter/core/widgets/rich_display_text.dart';
import 'package:hopefulme_flutter/features/auth/models/user.dart';
import 'package:hopefulme_flutter/features/auth/presentation/controllers/auth_controller.dart';
import 'package:hopefulme_flutter/features/community/presentation/screens/meet_new_friends_screen.dart';
import 'package:hopefulme_flutter/features/content/data/content_repository.dart';
import 'package:hopefulme_flutter/features/content/presentation/content_navigation.dart';
import 'package:hopefulme_flutter/features/content/presentation/screens/blogs_feed_screen.dart';
import 'package:hopefulme_flutter/features/content/presentation/screens/inspiration_inbox_screen.dart';
import 'package:hopefulme_flutter/features/content/presentation/screens/posts_feed_screen.dart';
import 'package:hopefulme_flutter/features/feed/data/feed_repository.dart';
import 'package:hopefulme_flutter/features/feed/models/feed_dashboard.dart';
import 'package:hopefulme_flutter/features/feed/presentation/screens/today_birthdays_screen.dart';
import 'package:hopefulme_flutter/features/groups/data/group_repository.dart';
import 'package:hopefulme_flutter/features/groups/presentation/screens/groups_screen.dart';
import 'package:hopefulme_flutter/features/messages/data/message_repository.dart';
import 'package:hopefulme_flutter/features/messages/models/conversation_models.dart';
import 'package:hopefulme_flutter/features/messages/presentation/screens/message_thread_screen.dart';
import 'package:hopefulme_flutter/features/messages/presentation/screens/messages_screen.dart';
import 'package:hopefulme_flutter/features/notifications/data/notification_repository.dart';
import 'package:hopefulme_flutter/features/notifications/models/app_notification.dart';
import 'package:hopefulme_flutter/features/notifications/presentation/notification_navigation.dart';
import 'package:hopefulme_flutter/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:hopefulme_flutter/features/profile/data/profile_repository.dart';
import 'package:hopefulme_flutter/features/profile/presentation/profile_navigation.dart';
import 'package:hopefulme_flutter/features/search/data/search_repository.dart';
import 'package:hopefulme_flutter/features/search/presentation/screens/search_screen.dart';
import 'package:hopefulme_flutter/features/updates/data/update_repository.dart';
import 'package:hopefulme_flutter/features/updates/presentation/screens/update_detail_screen.dart';
import 'package:hopefulme_flutter/features/updates/presentation/screens/updates_feed_screen.dart';
import 'package:hopefulme_flutter/features/updates/presentation/widgets/interactive_update_card.dart';
import 'package:hopefulme_flutter/features/library/data/library_repository.dart';
import 'package:hopefulme_flutter/features/library/presentation/screens/library_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    required this.authController,
    required this.themeController,
    required this.feedRepository,
    required this.contentRepository,
    required this.notificationRepository,
    required this.messageRepository,
    required this.groupRepository,
    required this.profileRepository,
    required this.searchRepository,
    required this.updateRepository,
    required this.libraryRepository,
    super.key,
  });

  final AuthController authController;
  final ThemeController themeController;
  final FeedRepository feedRepository;
  final ContentRepository contentRepository;
  final NotificationRepository notificationRepository;
  final MessageRepository messageRepository;
  final GroupRepository groupRepository;
  final ProfileRepository profileRepository;
  final SearchRepository searchRepository;
  final UpdateRepository updateRepository;
  final LibraryRepository libraryRepository;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _inAppNotificationsPrefKey = 'in_app_notifications_enabled';
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  late Future<FeedDashboard> _dashboardFuture;
  late final NotificationNavigator _notificationNavigator;
  Timer? _pollingTimer;
  List<AppNotification> _latestNotifications = const <AppNotification>[];
  List<ConversationListItem> _latestConversations =
      const <ConversationListItem>[];
  int _unreadNotifications = 0;
  int _unreadMessages = 0;
  int _selectedBottomNav = 0;
  bool _inAppNotificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _dashboardFuture = widget.feedRepository.fetchDashboard();
    _notificationNavigator = NotificationNavigator(
      profileRepository: widget.profileRepository,
      contentRepository: widget.contentRepository,
      messageRepository: widget.messageRepository,
      searchRepository: widget.searchRepository,
      updateRepository: widget.updateRepository,
      currentUser: widget.authController.currentUser,
    );
    _loadShellPreferences();
    _refreshTopbarData();
    _pollingTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _refreshTopbarData(silent: true),
    );
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshDashboard() async {
    setState(() {
      _dashboardFuture = widget.feedRepository.fetchDashboard();
    });

    await _dashboardFuture;
  }

  Future<void> _refreshTopbarData({bool silent = false}) async {
    try {
      final notifications = await widget.notificationRepository.fetchPage(
        page: 1,
      );
      final conversations = await widget.messageRepository.fetchConversations();
      if (!mounted) {
        return;
      }
      setState(() {
        _latestNotifications = notifications.items.take(10).toList();
        _unreadNotifications = notifications.unreadCount;
        _latestConversations = conversations.take(10).toList();
        _unreadMessages = conversations.fold<int>(
          0,
          (sum, item) => sum + item.unreadCount,
        );
      });
    } catch (_) {
      if (!silent) {
        rethrow;
      }
    }
  }

  Future<void> _loadShellPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_inAppNotificationsPrefKey) ?? true;
    if (!mounted) {
      return;
    }
    setState(() {
      _inAppNotificationsEnabled = enabled;
    });
  }

  Future<void> _setInAppNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_inAppNotificationsPrefKey, enabled);
    if (!mounted) {
      return;
    }
    setState(() {
      _inAppNotificationsEnabled = enabled;
      if (!enabled) {
        _latestNotifications = const <AppNotification>[];
        _unreadNotifications = 0;
      }
    });
    if (enabled) {
      await _refreshTopbarData(silent: true);
      if (mounted) {
        AppToast.success(context, 'In-app notifications enabled.');
      }
    } else {
      AppToast.info(context, 'In-app notifications muted.');
    }
  }

  Future<void> _openProfile() async {
    await openUserProfile(
      context,
      profileRepository: widget.profileRepository,
      messageRepository: widget.messageRepository,
      updateRepository: widget.updateRepository,
      currentUser: widget.authController.currentUser,
      username: widget.authController.currentUser?.username ?? '',
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedBottomNav = 0;
    });
  }

  Future<void> _goHome() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedBottomNav = 0;
      _dashboardFuture = widget.feedRepository.fetchDashboard();
    });
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => NotificationsScreen(
          repository: widget.notificationRepository,
          profileRepository: widget.profileRepository,
          contentRepository: widget.contentRepository,
          messageRepository: widget.messageRepository,
          searchRepository: widget.searchRepository,
          updateRepository: widget.updateRepository,
          currentUser: widget.authController.currentUser,
        ),
      ),
    );
    await _refreshTopbarData(silent: true);
  }

  Future<void> _openMessages() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => MessagesScreen(
          repository: widget.messageRepository,
          profileRepository: widget.profileRepository,
          updateRepository: widget.updateRepository,
          groupRepository: widget.groupRepository,
          currentUser: widget.authController.currentUser,
        ),
      ),
    );
    await _refreshTopbarData(silent: true);
  }

  Future<void> _openGroups() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => GroupsScreen(
          repository: widget.groupRepository,
          currentUser: widget.authController.currentUser,
          profileRepository: widget.profileRepository,
          messageRepository: widget.messageRepository,
          updateRepository: widget.updateRepository,
        ),
      ),
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedBottomNav = 0;
    });
  }

  Future<void> _openConversation(ConversationListItem item) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => MessageThreadScreen(
          repository: widget.messageRepository,
          profileRepository: widget.profileRepository,
          updateRepository: widget.updateRepository,
          currentUser: widget.authController.currentUser,
          username: item.otherUser.username,
          title: item.otherUser.displayName,
        ),
      ),
    );
    await _refreshTopbarData(silent: true);
  }

  Future<void> _openUserProfile(String username) async {
    await openUserProfile(
      context,
      profileRepository: widget.profileRepository,
      messageRepository: widget.messageRepository,
      updateRepository: widget.updateRepository,
      currentUser: widget.authController.currentUser,
      username: username,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedBottomNav = 0;
    });
  }

  Future<void> _openUpdateDetail(FeedEntry entry) async {
    final result = await Navigator.of(context).push<UpdateDetailResult>(
      MaterialPageRoute<UpdateDetailResult>(
        builder: (context) => UpdateDetailScreen(
          updateId: entry.id,
          currentUser: widget.authController.currentUser,
          repository: widget.updateRepository,
          contentRepository: widget.contentRepository,
          profileRepository: widget.profileRepository,
          messageRepository: widget.messageRepository,
          searchRepository: widget.searchRepository,
        ),
      ),
    );
    if (result?.shouldRefresh == true) {
      await _refreshDashboard();
    }
  }

  Future<void> _openPostDetail(FeedEntry entry) async {
    await openPostDetail(
      context,
      contentRepository: widget.contentRepository,
      profileRepository: widget.profileRepository,
      messageRepository: widget.messageRepository,
      searchRepository: widget.searchRepository,
      updateRepository: widget.updateRepository,
      postId: entry.id,
      currentUsername: widget.authController.currentUser?.username,
    );
  }

  Future<void> _openBlogDetail(FeedEntry entry) async {
    await openBlogDetail(
      context,
      contentRepository: widget.contentRepository,
      profileRepository: widget.profileRepository,
      messageRepository: widget.messageRepository,
      searchRepository: widget.searchRepository,
      updateRepository: widget.updateRepository,
      blogId: entry.id,
      currentUsername: widget.authController.currentUser?.username,
    );
  }

  Future<void> _openSearch() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => SearchScreen(
          repository: widget.searchRepository,
          contentRepository: widget.contentRepository,
          messageRepository: widget.messageRepository,
          profileRepository: widget.profileRepository,
          updateRepository: widget.updateRepository,
          currentUser: widget.authController.currentUser,
        ),
      ),
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedBottomNav = 0;
    });
  }

  Future<void> _openSearchQuery(String query) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => SearchScreen(
          repository: widget.searchRepository,
          contentRepository: widget.contentRepository,
          messageRepository: widget.messageRepository,
          profileRepository: widget.profileRepository,
          updateRepository: widget.updateRepository,
          currentUser: widget.authController.currentUser,
          initialQuery: query,
        ),
      ),
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedBottomNav = 0;
    });
  }

  Future<void> _openActivities() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => UpdatesFeedScreen(
          feedRepository: widget.feedRepository,
          contentRepository: widget.contentRepository,
          updateRepository: widget.updateRepository,
          profileRepository: widget.profileRepository,
          messageRepository: widget.messageRepository,
          searchRepository: widget.searchRepository,
          currentUser: widget.authController.currentUser,
        ),
      ),
    );
  }

  Future<void> _openPostsFeed({String initialCategory = 'All'}) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => PostsFeedScreen(
          feedRepository: widget.feedRepository,
          contentRepository: widget.contentRepository,
          profileRepository: widget.profileRepository,
          messageRepository: widget.messageRepository,
          updateRepository: widget.updateRepository,
          searchRepository: widget.searchRepository,
          currentUser: widget.authController.currentUser,
          currentUsername: widget.authController.currentUser?.username,
          initialCategory: initialCategory,
        ),
      ),
    );
  }

  Future<void> _openPostById(int postId) {
    return openPostDetail(
      context,
      contentRepository: widget.contentRepository,
      profileRepository: widget.profileRepository,
      messageRepository: widget.messageRepository,
      searchRepository: widget.searchRepository,
      updateRepository: widget.updateRepository,
      postId: postId,
      currentUsername: widget.authController.currentUser?.username,
    );
  }

  Future<void> _openBlogsFeed() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => BlogsFeedScreen(
          feedRepository: widget.feedRepository,
          contentRepository: widget.contentRepository,
          profileRepository: widget.profileRepository,
          messageRepository: widget.messageRepository,
          updateRepository: widget.updateRepository,
          searchRepository: widget.searchRepository,
          currentUsername: widget.authController.currentUser?.username,
        ),
      ),
    );
  }

  Future<void> _openInspirations() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) =>
            InspirationInboxScreen(repository: widget.contentRepository),
      ),
    );
  }

  Future<void> _openLibrary() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) =>
            LibraryScreen(repository: widget.libraryRepository),
      ),
    );
  }

  Future<void> _openWebPage(String title, String path) async {
    final base = AppConfig.fromEnvironment().webBaseUrl;
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) =>
            WebPageScreen(title: title, url: '$base$normalizedPath'),
      ),
    );
  }

  Future<void> _openStorePage() => _openWebPage('Marketplace', '/store/home');

  Future<void> _openTvPage() => _openWebPage('HopefulMe TV', '/tv/home');

  Future<void> _openOutreachPage() => _openWebPage('Outreach', '/outreach');

  Future<void> _openPrivacyPolicyPage() =>
      _openWebPage('Privacy Policy', '/privacy');

  Future<void> _openTermsPage() => _openWebPage('Terms', '/terms');

  Future<void> _openMeetNewFriends() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => MeetNewFriendsScreen(
          feedRepository: widget.feedRepository,
          profileRepository: widget.profileRepository,
          messageRepository: widget.messageRepository,
          updateRepository: widget.updateRepository,
          currentUser: widget.authController.currentUser,
        ),
      ),
    );
  }

  Future<void> _openTodayBirthdays(List<FeedUser> users) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => TodayBirthdaysScreen(
          feedRepository: widget.feedRepository,
          initialUsers: users,
          profileRepository: widget.profileRepository,
          messageRepository: widget.messageRepository,
          updateRepository: widget.updateRepository,
          currentUser: widget.authController.currentUser,
        ),
      ),
    );
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
        bool showEmojiPicker = false;

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
              } catch (error, stack) {
                // Debug logs to help diagnose post/update issues during development
                if (kDebugMode) {
                  debugPrint('Post update failed: $error');
                  if (stack != null) debugPrint('Stack: $stack');
                }
                // Revert to graceful user-facing error handling
                if (context.mounted) {
                  AppToast.error(context, _friendlyComposerError(error));
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
                    key: formKey,
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
                              _Avatar(
                                imageUrl:
                                    widget
                                        .authController
                                        .currentUser
                                        ?.photoUrl ??
                                    '',
                                label:
                                    widget
                                        .authController
                                        .currentUser
                                        ?.displayName ??
                                    'You',
                                radius: 22,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget
                                              .authController
                                              .currentUser
                                              ?.displayName ??
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
                                        color: colors.surface.withValues(
                                          alpha: 0.82,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
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
                                onPressed: submitting
                                    ? null
                                    : () => Navigator.of(context).pop(false),
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
                          controller: controller,
                          minLines: 4,
                          maxLines: 8,
                          decoration: const InputDecoration(
                            hintText: 'What is on your mind?',
                          ),
                          validator: (value) {
                            if ((value == null || value.trim().isEmpty) &&
                                selectedPhoto == null) {
                              return 'Please write something or add a photo.';
                            }
                            return null;
                          },
                        ),
                        if (selectedPhoto != null) ...[
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
                                    child: selectedPhotoBytes != null
                                        ? Image.memory(
                                            selectedPhotoBytes!,
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
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            selectedPhoto!.name,
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
                                      onPressed: submitting
                                          ? null
                                          : () {
                                              setSheetState(() {
                                                selectedPhoto = null;
                                                selectedPhotoBytes = null;
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
                              onPressed: submitting ? null : pickPhoto,
                              icon: Icon(
                                selectedPhoto == null
                                    ? Icons.image_outlined
                                    : Icons.check_circle_outline,
                                color: colors.brand,
                              ),
                              tooltip: selectedPhoto == null
                                  ? 'Add Photo'
                                  : 'Photo added',
                            ),
                            const SizedBox(width: 8),
                            IconButton.outlined(
                              onPressed: () {
                                setSheetState(() {
                                  showEmojiPicker = !showEmojiPicker;
                                });
                              },
                              icon: const Icon(Icons.emoji_emotions_outlined),
                              tooltip: 'Feeling/Activity',
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
                                  : const Text('Post'),
                            ),
                          ],
                        ),
                        if (showEmojiPicker) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 280,
                            child: EmojiPicker(
                              textEditingController: controller,
                              config: Config(
                                height: 280,
                                checkPlatformCompatibility: true,
                                emojiViewConfig: const EmojiViewConfig(
                                  emojiSizeMax: 26,
                                ),
                                categoryViewConfig: CategoryViewConfig(
                                  iconColor: colors.textMuted,
                                  iconColorSelected: colors.brand,
                                  backspaceColor: colors.brand,
                                ),
                                bottomActionBarConfig:
                                    const BottomActionBarConfig(enabled: false),
                                searchViewConfig: SearchViewConfig(
                                  backgroundColor: colors.surface,
                                  buttonIconColor: colors.textMuted,
                                ),
                              ),
                            ),
                          ),
                        ],
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
      await _refreshDashboard();
    }
  }

  String _friendlyComposerError(Object error) {
    final message = error.toString();
    if (message.contains('Asset') || message.contains('asset')) {
      return 'Photo upload failed. Please try a smaller image or restart the app.';
    }
    if (message.length > 180) {
      return 'Unable to post that update right now.';
    }
    return message;
  }

  Future<void> _markNotificationRead(AppNotification item) async {
    if (!item.isRead) {
      await widget.notificationRepository.markRead(item.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _latestNotifications = _latestNotifications.map((entry) {
          if (entry.id != item.id) {
            return entry;
          }
          return AppNotification(
            id: entry.id,
            type: entry.type,
            message: entry.message,
            preview: entry.preview,
            url: entry.url,
            contentType: entry.contentType,
            contentId: entry.contentId,
            inspirationId: entry.inspirationId,
            icon: entry.icon,
            avatarUrl: entry.avatarUrl,
            isRead: true,
            createdAt: entry.createdAt,
          );
        }).toList();
        if (_unreadNotifications > 0) {
          _unreadNotifications -= 1;
        }
      });
    }

    if (!mounted) {
      return;
    }

    final opened = await _notificationNavigator.open(context, item);
    if (!opened && mounted) {
      AppToast.info(context, 'This notification can be viewed on our website.');
    }
  }

  Future<void> _markAllNotificationsRead() async {
    await widget.notificationRepository.markAllRead();
    if (!mounted) {
      return;
    }
    setState(() {
      _latestNotifications = _latestNotifications.map((entry) {
        return AppNotification(
          id: entry.id,
          type: entry.type,
          message: entry.message,
          preview: entry.preview,
          url: entry.url,
          contentType: entry.contentType,
          contentId: entry.contentId,
          inspirationId: entry.inspirationId,
          icon: entry.icon,
          avatarUrl: entry.avatarUrl,
          isRead: true,
          createdAt: entry.createdAt,
        );
      }).toList();
      _unreadNotifications = 0;
    });
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You will need to sign in again to continue.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) {
      return;
    }

    await widget.authController.logout();
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.authController.currentUser;
    final colors = context.appColors;
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 1180;
    final showRightRail = width >= 1380;
    final showBottomNav = width < 960;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: colors.scaffold,
      bottomNavigationBar: showBottomNav ? _buildBottomNav() : null,
      drawer: isDesktop
          ? null
          : Drawer(
              width: 256,
              child: _HomeSidebar(
                user: user,
                onSearchTap: _openSearch,
                onHomeTap: _goHome,
                onPostsTap: _openPostsFeed,
                onBlogsTap: _openBlogsFeed,
                onActivitiesTap: _openActivities,
                onGroupsTap: _openGroups,
                onLibraryTap: _openLibrary,
                onInspirationsTap: _openInspirations,
                onStoreTap: _openStorePage,
                onTvTap: _openTvPage,
                onOutreachTap: _openOutreachPage,
                onMeetNewFriendsTap: _openMeetNewFriends,
                onLogoutTap: _handleLogout,
              ),
            ),
      body: FutureBuilder<FeedDashboard>(
        future: _dashboardFuture,
        builder: (context, snapshot) {
          final dashboard = snapshot.data;

          return Row(
            children: [
              if (isDesktop)
                _HomeSidebar(
                  user: user,
                  onSearchTap: _openSearch,
                  onHomeTap: _goHome,
                  onPostsTap: _openPostsFeed,
                  onBlogsTap: _openBlogsFeed,
                  onActivitiesTap: _openActivities,
                  onGroupsTap: _openGroups,
                  onLibraryTap: _openLibrary,
                  onInspirationsTap: _openInspirations,
                  onStoreTap: _openStorePage,
                  onTvTap: _openTvPage,
                  onOutreachTap: _openOutreachPage,
                  onMeetNewFriendsTap: _openMeetNewFriends,
                  onLogoutTap: _handleLogout,
                ),
              Expanded(
                child: Column(
                  children: [
                    _HomeTopBar(
                      user: user,
                      themeController: widget.themeController,
                      latestNotifications: _latestNotifications,
                      latestConversations: _latestConversations,
                      unreadNotifications: _unreadNotifications,
                      unreadMessages: _unreadMessages,
                      onConversationTap: _openConversation,
                      onMessageCenterTap: _openMessages,
                      onNotificationTap: _markNotificationRead,
                      onNotificationCenterTap: _openNotifications,
                      onNotificationsMarkAllRead: _markAllNotificationsRead,
                      onHomeTap: _goHome,
                      onProfileTap: _openProfile,
                      onMenuTap: isDesktop
                          ? null
                          : () {
                              _scaffoldKey.currentState?.openDrawer();
                            },
                      onLogout: widget.authController.isLoading
                          ? null
                          : _handleLogout,
                    ),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _refreshDashboard,
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: EdgeInsets.fromLTRB(
                            16,
                            16,
                            16,
                            showBottomNav ? 28 : 24,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 900,
                                  ),
                                  child: _HomeContent(
                                    user: user,
                                    dashboard: dashboard,
                                    onCreateUpdate: _openCreateUpdate,
                                    onOpenProfile: _openUserProfile,
                                    onOpenUpdate: _openUpdateDetail,
                                    onOpenPost: _openPostDetail,
                                    onOpenPostById: _openPostById,
                                    onOpenBlog: _openBlogDetail,
                                    onOpenUpdatesFeed: _openActivities,
                                    onOpenPostsFeed: _openPostsFeed,
                                    onOpenBlogsFeed: _openBlogsFeed,
                                    onOpenHashtag: _openSearchQuery,
                                    onOpenTodayBirthdays: _openTodayBirthdays,
                                    updateRepository: widget.updateRepository,
                                    isLoading:
                                        snapshot.connectionState ==
                                            ConnectionState.waiting &&
                                        dashboard == null,
                                    error: snapshot.error?.toString(),
                                  ),
                                ),
                              ),
                              if (showRightRail) ...[
                                const SizedBox(width: 24),
                                SizedBox(
                                  width: 360,
                                  child: _RightRail(
                                    user: user,
                                    dashboard: dashboard,
                                    onOpenProfile: _openUserProfile,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBottomNav() {
    final colors = context.appColors;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(0, 0, 0, 0),
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border(
            top: BorderSide(color: colors.border.withOpacity(0.95)),
          ),
          boxShadow: [
            BoxShadow(
              color: colors.shadow.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, -1),
            ),
          ],
        ),
        child: NavigationBar(
          height: 76,
          backgroundColor: Colors.transparent,
          indicatorColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          selectedIndex: _selectedBottomNav,
          onDestinationSelected: (index) {
            setState(() {
              _selectedBottomNav = index;
            });
            if (index == 1) {
              _openSearch();
            }
            if (index == 2) {
              _openCreateUpdate();
            }
            if (index == 3) {
              _openGroups();
            }
            if (index == 4) {
              _openProfile();
            }
          },
          destinations: [
            const NavigationDestination(
              icon: Icon(CupertinoIcons.home),
              selectedIcon: Icon(CupertinoIcons.home),
              label: 'Home',
            ),
            const NavigationDestination(
              icon: Icon(CupertinoIcons.search),
              selectedIcon: Icon(CupertinoIcons.search),
              label: 'Search',
            ),
            NavigationDestination(
              icon: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: colors.brandGradient,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              label: '',
            ),
            const NavigationDestination(
              icon: Icon(CupertinoIcons.group),
              selectedIcon: Icon(CupertinoIcons.group),
              label: 'Groups',
            ),
            const NavigationDestination(
              icon: Icon(CupertinoIcons.person),
              selectedIcon: Icon(CupertinoIcons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeTopBar extends StatelessWidget {
  const _HomeTopBar({
    required this.user,
    required this.themeController,
    required this.latestNotifications,
    required this.latestConversations,
    required this.unreadNotifications,
    required this.unreadMessages,
    required this.onConversationTap,
    required this.onMessageCenterTap,
    required this.onNotificationTap,
    required this.onNotificationCenterTap,
    required this.onNotificationsMarkAllRead,
    required this.onHomeTap,
    required this.onProfileTap,
    required this.onMenuTap,
    required this.onLogout,
  });

  final User? user;
  final ThemeController themeController;
  final List<AppNotification> latestNotifications;
  final List<ConversationListItem> latestConversations;
  final int unreadNotifications;
  final int unreadMessages;
  final Future<void> Function(ConversationListItem item) onConversationTap;
  final Future<void> Function() onMessageCenterTap;
  final Future<void> Function(AppNotification item) onNotificationTap;
  final Future<void> Function() onNotificationCenterTap;
  final Future<void> Function() onNotificationsMarkAllRead;
  final Future<void> Function() onHomeTap;
  final Future<void> Function() onProfileTap;
  final VoidCallback? onMenuTap;
  final Future<void> Function()? onLogout;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final brightness = Theme.of(context).brightness;
    return SafeArea(
      bottom: false,
      child: Container(
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: colors.surface.withOpacity(0.96),
          border: Border(bottom: BorderSide(color: colors.borderStrong)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 46,
              height: 46,
              child: onMenuTap == null
                  ? const SizedBox.shrink()
                  : IconButton(
                      onPressed: onMenuTap,
                      icon: Icon(Icons.menu_outlined, color: colors.icon),
                      style: IconButton.styleFrom(
                        backgroundColor: colors.surfaceMuted.withValues(
                          alpha: 0.72,
                        ),
                        side: BorderSide(color: colors.border),
                      ),
                    ),
            ),
            const Spacer(),
            _MessagesDropdownButton(
              conversations: latestConversations,
              unreadCount: unreadMessages,
              onConversationTap: onConversationTap,
              onViewAllTap: onMessageCenterTap,
            ),
            const SizedBox(width: 8),
            _NotificationsDropdownButton(
              notifications: latestNotifications,
              unreadCount: unreadNotifications,
              onNotificationTap: onNotificationTap,
              onViewAllTap: onNotificationCenterTap,
              onMarkAllReadTap: onNotificationsMarkAllRead,
            ),
            const SizedBox(width: 12),
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'profile') {
                  await onProfileTap();
                }
                if (value == 'theme') {
                  await themeController.cycleThemeMode();
                }
                if (value == 'home') {
                  await onHomeTap();
                }
                if (value == 'logout' && onLogout != null) {
                  await onLogout!();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'profile',
                  child: Text('View Profile'),
                ),
                PopupMenuItem(
                  value: 'theme',
                  child: Text(
                    themeController.isDarkMode
                        ? 'Switch to Light Mode'
                        : 'Switch to Dark Mode',
                  ),
                ),
                PopupMenuItem(
                  enabled: false,
                  value: 'theme_state',
                  child: Text(themeController.themeLabel(brightness)),
                ),
                const PopupMenuItem(value: 'home', child: Text('Go Home')),
                const PopupMenuItem(value: 'logout', child: Text('Log Out')),
              ],
              child: AppAvatar(
                imageUrl: user?.photoUrl ?? '',
                label: user?.displayName ?? 'User',
                radius: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationsDropdownButton extends StatelessWidget {
  const _NotificationsDropdownButton({
    required this.notifications,
    required this.unreadCount,
    required this.onNotificationTap,
    required this.onViewAllTap,
    required this.onMarkAllReadTap,
  });

  final List<AppNotification> notifications;
  final int unreadCount;
  final Future<void> Function(AppNotification item) onNotificationTap;
  final Future<void> Function() onViewAllTap;
  final Future<void> Function() onMarkAllReadTap;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      offset: const Offset(0, 14),
      color: Colors.transparent,
      elevation: 0,
      padding: EdgeInsets.zero,
      itemBuilder: (context) => [
        PopupMenuItem<int>(
          enabled: false,
          padding: EdgeInsets.zero,
          child: SizedBox(
            width: 340,
            child: _DropdownShell(
              title: 'Notifications',
              count: unreadCount,
              actionLabel: unreadCount > 0 ? 'Mark all read' : null,
              onActionTap: unreadCount > 0
                  ? () async {
                      Navigator.pop(context);
                      await onMarkAllReadTap();
                    }
                  : null,
              footerLabel: 'View all',
              onFooterTap: () async {
                Navigator.pop(context);
                await onViewAllTap();
              },
              child: notifications.isEmpty
                  ? const _DropdownEmptyState(label: 'All caught up')
                  : Column(
                      children: notifications
                          .map(
                            (item) => _NotificationDropdownRow(
                              item: item,
                              onTap: () async {
                                Navigator.pop(context);
                                await onNotificationTap(item);
                              },
                            ),
                          )
                          .toList(),
                    ),
            ),
          ),
        ),
      ],
      child: _BadgeTopBarIcon(
        icon: Icons.notifications_outlined,
        count: unreadCount,
      ),
    );
  }
}

class _MessagesDropdownButton extends StatelessWidget {
  const _MessagesDropdownButton({
    required this.conversations,
    required this.unreadCount,
    required this.onConversationTap,
    required this.onViewAllTap,
  });

  final List<ConversationListItem> conversations;
  final int unreadCount;
  final Future<void> Function(ConversationListItem item) onConversationTap;
  final Future<void> Function() onViewAllTap;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      offset: const Offset(0, 14),
      color: Colors.transparent,
      elevation: 0,
      padding: EdgeInsets.zero,
      itemBuilder: (context) => [
        PopupMenuItem<int>(
          enabled: false,
          padding: EdgeInsets.zero,
          child: SizedBox(
            width: 340,
            child: _DropdownShell(
              title: 'Messages',
              count: unreadCount,
              footerLabel: 'View all',
              onFooterTap: () async {
                Navigator.pop(context);
                await onViewAllTap();
              },
              child: conversations.isEmpty
                  ? const _DropdownEmptyState(label: 'No messages yet')
                  : Column(
                      children: conversations
                          .map(
                            (item) => _MessageDropdownRow(
                              item: item,
                              onTap: () async {
                                Navigator.pop(context);
                                await onConversationTap(item);
                              },
                            ),
                          )
                          .toList(),
                    ),
            ),
          ),
        ),
      ],
      child: _BadgeTopBarIcon(
        icon: Icons.chat_bubble_outline,
        count: unreadCount,
      ),
    );
  }
}

class _BadgeTopBarIcon extends StatelessWidget {
  const _BadgeTopBarIcon({required this.icon, required this.count});

  final IconData icon;
  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        SizedBox(
          width: 46,
          height: 46,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  isDark ? colors.surfaceRaised : colors.surface,
                  isDark
                      ? colors.surfaceMuted.withValues(alpha: 0.96)
                      : colors.accentSoft.withValues(alpha: 0.26),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.all(Radius.circular(14)),
              border: Border.fromBorderSide(
                BorderSide(color: colors.borderStrong),
              ),
              boxShadow: [
                BoxShadow(
                  color: colors.shadow.withValues(alpha: 0.045),
                  blurRadius: 14,
                  offset: const Offset(0, 8),
                  spreadRadius: -10,
                ),
              ],
            ),
          ),
        ),
        Positioned.fill(child: Icon(icon, size: 22, color: colors.icon)),
        if (count > 0)
          Positioned(
            top: -4,
            right: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                count > 9 ? '9+' : '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _DropdownShell extends StatelessWidget {
  const _DropdownShell({
    required this.title,
    required this.count,
    required this.child,
    required this.footerLabel,
    required this.onFooterTap,
    this.actionLabel,
    this.onActionTap,
  });

  final String title;
  final int count;
  final String? actionLabel;
  final Future<void> Function()? onActionTap;
  final Widget child;
  final String footerLabel;
  final Future<void> Function() onFooterTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        decoration: BoxDecoration(
          color: isDark
              ? colors.surfaceRaised.withValues(alpha: 0.98)
              : colors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: colors.borderStrong),
          boxShadow: [
            BoxShadow(
              color: colors.shadow.withValues(alpha: isDark ? 0.28 : 0.08),
              blurRadius: isDark ? 24 : 28,
              offset: const Offset(0, 16),
              spreadRadius: -20,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (count > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3D5AFE),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        count > 9 ? '9+' : '$count',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (actionLabel != null)
                    TextButton(
                      onPressed: () => onActionTap?.call(),
                      child: Text(actionLabel!),
                    ),
                ],
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: SingleChildScrollView(child: child),
            ),
            Divider(height: 1, color: colors.border),
            InkWell(
              onTap: () => onFooterTap(),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(22),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Center(
                  child: Text(
                    footerLabel,
                    style: TextStyle(
                      color: colors.brand,
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
    );
  }
}

class _NotificationDropdownRow extends StatelessWidget {
  const _NotificationDropdownRow({required this.item, required this.onTap});

  final AppNotification item;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: () => onTap(),
      child: Container(
        color: item.isRead
            ? (isDark ? colors.surfaceRaised : colors.surface)
            : (isDark
                  ? colors.accentSoft.withValues(alpha: 0.42)
                  : colors.accentSoft.withValues(alpha: 0.2)),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundImage: item.avatarUrl.isNotEmpty
                  ? NetworkImage(item.avatarUrl)
                  : null,
              child: item.avatarUrl.isEmpty ? const Icon(Icons.person) : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 12.5,
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatConversationListTimestamp(item.createdAt),
                    style: TextStyle(color: colors.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
            if (!item.isRead)
              const Padding(
                padding: EdgeInsets.only(left: 8, top: 4),
                child: CircleAvatar(
                  radius: 4,
                  backgroundColor: Color(0xFF3D5AFE),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MessageDropdownRow extends StatelessWidget {
  const _MessageDropdownRow({required this.item, required this.onTap});

  final ConversationListItem item;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: () => onTap(),
      child: Container(
        color: item.unreadCount > 0
            ? (isDark
                  ? colors.accentSoft.withValues(alpha: 0.42)
                  : colors.accentSoft.withValues(alpha: 0.2))
            : (isDark ? colors.surfaceRaised : colors.surface),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage: item.otherUser.photoUrl.isNotEmpty
                      ? NetworkImage(item.otherUser.photoUrl)
                      : null,
                  child: item.otherUser.photoUrl.isEmpty
                      ? const Icon(Icons.person)
                      : null,
                ),
                if (item.otherUser.isOnline)
                  const Positioned(
                    right: 0,
                    bottom: 0,
                    child: CircleAvatar(
                      radius: 5,
                      backgroundColor: Colors.green,
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.otherUser.displayName,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        formatConversationListTimestamp(
                          item.latestMessage?.createdAt.isNotEmpty == true
                              ? item.latestMessage!.createdAt
                              : item.updatedAt,
                        ),
                        style: TextStyle(
                          color: colors.textMuted,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.latestMessage?.message.isNotEmpty == true
                        ? item.latestMessage!.message
                        : 'Open conversation',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: colors.textMuted, fontSize: 11.5),
                  ),
                ],
              ),
            ),
            if (item.unreadCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF3D5AFE),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  item.unreadCount > 9 ? '9+' : '${item.unreadCount}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DropdownEmptyState extends StatelessWidget {
  const _DropdownEmptyState({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: context.appColors.textMuted,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _HomeSidebar extends StatelessWidget {
  const _HomeSidebar({
    required this.user,
    required this.onSearchTap,
    required this.onHomeTap,
    required this.onPostsTap,
    required this.onBlogsTap,
    required this.onActivitiesTap,
    required this.onGroupsTap,
    required this.onLibraryTap,
    required this.onInspirationsTap,
    required this.onStoreTap,
    required this.onTvTap,
    required this.onOutreachTap,
    required this.onMeetNewFriendsTap,
    required this.onLogoutTap,
  });

  final User? user;
  final Future<void> Function() onSearchTap;
  final Future<void> Function() onHomeTap;
  final Future<void> Function() onPostsTap;
  final Future<void> Function() onBlogsTap;
  final Future<void> Function() onActivitiesTap;
  final Future<void> Function() onGroupsTap;
  final Future<void> Function() onLibraryTap;
  final Future<void> Function() onInspirationsTap;
  final Future<void> Function() onStoreTap;
  final Future<void> Function() onTvTap;
  final Future<void> Function() onOutreachTap;
  final Future<void> Function() onMeetNewFriendsTap;
  final Future<void> Function() onLogoutTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      width: 256,
      decoration: BoxDecoration(color: colors.sidebar),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 18),
            child: Row(
              children: [
                Text(
                  'HopefulMe',
                  style: TextStyle(
                    color: colors.sidebarText,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: InkWell(
              onTap: () => onSearchTap(),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                height: 42,
                decoration: BoxDecoration(
                  color: colors.sidebarSurface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    SizedBox(width: 14),
                    Icon(Icons.search, size: 18, color: colors.sidebarMuted),
                    SizedBox(width: 8),
                    Text(
                      'Search...',
                      style: TextStyle(
                        color: colors.sidebarMuted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          _SidebarSection(
            title: 'Community',
            items: [
              _SidebarItemData(
                Icons.home_outlined,
                'Home',
                true,
                onTap: onHomeTap,
              ),
              _SidebarItemData(
                Icons.article_outlined,
                'Post & News',
                false,
                onTap: onPostsTap,
              ),
              _SidebarItemData(
                Icons.local_activity_outlined,
                'Activities',
                false,
                onTap: onActivitiesTap,
              ),
              _SidebarItemData(
                Icons.groups_outlined,
                'Group Chats',
                false,
                onTap: onGroupsTap,
              ),
              _SidebarItemData(
                Icons.people_outline,
                'Meet New Friends',
                false,
                onTap: onMeetNewFriendsTap,
              ),
            ],
          ),
          _SidebarSection(
            title: 'Content',
            items: [
              _SidebarItemData(
                Icons.edit_note_outlined,
                'Blog & Articles',
                false,
                onTap: onBlogsTap,
              ),
              _SidebarItemData(
                Icons.auto_awesome_outlined,
                'Inspirations',
                false,
                onTap: onInspirationsTap,
              ),
            ],
          ),
          _SidebarSection(
            title: 'Resources',
            items: [
              _SidebarItemData(
                Icons.local_library_outlined,
                'Library',
                false,
                onTap: onLibraryTap,
              ),
            ],
          ),
          _SidebarSection(
            title: 'Web',
            items: [
              _SidebarItemData(
                Icons.storefront_outlined,
                'Marketplace',
                false,
                onTap: onStoreTap,
              ),
              _SidebarItemData(
                Icons.live_tv_outlined,
                'HopefulMe TV',
                false,
                onTap: onTvTap,
              ),
              _SidebarItemData(
                Icons.volunteer_activism_outlined,
                'Outreach',
                false,
                onTap: onOutreachTap,
              ),
            ],
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.sidebarSurface.withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  _Avatar(
                    imageUrl: user?.photoUrl ?? '',
                    label: user?.displayName ?? 'U',
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.displayName ?? 'Member',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.sidebarText,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          user == null ? '' : '@${user!.username}',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.sidebarMuted,
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: () => onLogoutTap(),
                    borderRadius: BorderRadius.circular(999),
                    child: Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(
                        Icons.logout,
                        color: colors.sidebarMuted,
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarSection extends StatelessWidget {
  const _SidebarSection({required this.title, required this.items});

  final String title;
  final List<_SidebarItemData> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 12, 10, 8),
            child: Text(
              title,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.8,
              ),
            ),
          ),
          ...items.map(_SidebarItem.new),
        ],
      ),
    );
  }
}

class _SidebarItemData {
  const _SidebarItemData(this.icon, this.label, this.active, {this.onTap});

  final IconData icon;
  final String label;
  final bool active;
  final Future<void> Function()? onTap;
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem(this.item);

  final _SidebarItemData item;

  @override
  Widget build(BuildContext context) {
    final gradient = item.active
        ? const LinearGradient(colors: [Color(0xFF3D5AFE), Color(0xFF7C3AED)])
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: item.onTap == null ? null : () => item.onTap!(),
          child: ListTile(
            dense: true,
            visualDensity: const VisualDensity(vertical: -2),
            leading: Icon(
              item.icon,
              color: item.active ? Colors.white : const Color(0xFF94A3B8),
              size: 18,
            ),
            title: Text(
              item.label,
              style: TextStyle(
                color: item.active ? Colors.white : const Color(0xFFDDE6F6),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeContent extends StatelessWidget {
  const _HomeContent({
    required this.user,
    required this.dashboard,
    required this.onCreateUpdate,
    required this.onOpenProfile,
    required this.onOpenUpdate,
    required this.onOpenPost,
    required this.onOpenPostById,
    required this.onOpenBlog,
    required this.onOpenUpdatesFeed,
    required this.onOpenPostsFeed,
    required this.onOpenBlogsFeed,
    required this.onOpenHashtag,
    required this.onOpenTodayBirthdays,
    required this.updateRepository,
    required this.isLoading,
    required this.error,
  });

  final User? user;
  final FeedDashboard? dashboard;
  final Future<void> Function() onCreateUpdate;
  final Future<void> Function(String username) onOpenProfile;
  final Future<void> Function(FeedEntry entry) onOpenUpdate;
  final Future<void> Function(FeedEntry entry) onOpenPost;
  final Future<void> Function(int postId) onOpenPostById;
  final Future<void> Function(FeedEntry entry) onOpenBlog;
  final Future<void> Function() onOpenUpdatesFeed;
  final Future<void> Function({String initialCategory}) onOpenPostsFeed;
  final Future<void> Function() onOpenBlogsFeed;
  final Future<void> Function(String hashtag) onOpenHashtag;
  final Future<void> Function(List<FeedUser> users) onOpenTodayBirthdays;
  final UpdateRepository updateRepository;
  final bool isLoading;
  final String? error;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.only(top: 80),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (error != null && dashboard == null) {
      return _SurfaceCard(
        padding: const EdgeInsets.all(20),
        child: Text(error!),
      );
    }

    final data = dashboard;
    if (data == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StoriesRow(
          users: data.onlineUsers,
          onUserTap: onOpenProfile,
          onCreateUpdate: onCreateUpdate,
        ),
        const SizedBox(height: 18),
        _ComposerCard(user: user, onCreateUpdate: onCreateUpdate),
        const SizedBox(height: 18),
        if (data.todayBirthdays.isNotEmpty) ...[
          _BirthdayCelebrationStrip(
            users: data.todayBirthdays,
            onOpenProfile: onOpenProfile,
            onViewAll: () => onOpenTodayBirthdays(data.todayBirthdays),
          ),
          const SizedBox(height: 18),
        ],
        _SectionHeader(
          title: 'Random Quotes for you..',
          leading: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: context.appColors.brand.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.format_quote_rounded,
              color: context.appColors.brand,
              size: 18,
            ),
          ),
          action: 'See more',
          onActionTap: () => onOpenPostsFeed(initialCategory: 'Quote'),
        ),
        const SizedBox(height: 8),
        _QuoteGrid(quotes: data.trendingQuotes, onOpenQuote: onOpenPostById),
        const SizedBox(height: 16),
        ...data.feed.map(
          (entry) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _FeedEntryCard(
              entry: entry,
              currentUser: user,
              onOpenProfile: onOpenProfile,
              onOpenUpdate: onOpenUpdate,
              onOpenPost: onOpenPost,
              onOpenBlog: onOpenBlog,
              onOpenHashtag: onOpenHashtag,
              updateRepository: updateRepository,
            ),
          ),
        ),
        if (data.feed.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _FeedExploreMoreCard(
              onOpenUpdatesFeed: onOpenUpdatesFeed,
              onOpenPostsFeed: onOpenPostsFeed,
              onOpenBlogsFeed: onOpenBlogsFeed,
            ),
          ),
      ],
    );
  }
}

class _StoriesRow extends StatelessWidget {
  const _StoriesRow({
    required this.users,
    required this.onUserTap,
    required this.onCreateUpdate,
  });

  final List<FeedUser> users;
  final Future<void> Function(String username) onUserTap;
  final Future<void> Function() onCreateUpdate;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: users.length + 1,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          if (index == 0) {
            return InkWell(
              onTap: () => onCreateUpdate(),
              borderRadius: BorderRadius.circular(999),
              child: const SizedBox(
                width: 70,
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Color(0xFFEEF2FF),
                      child: Icon(Icons.add, color: Color(0xFF3D5AFE)),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Post',
                      style: TextStyle(
                        color: Color(0xFF3D5AFE),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final user = users[index - 1];
          return InkWell(
            onTap: () => onUserTap(user.username),
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              width: 70,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(2.5),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Color(0xFF3D5AFE), Color(0xFF7C3AED)],
                      ),
                    ),
                    child: _Avatar(
                      imageUrl: user.photoUrl,
                      label: user.displayName,
                      radius: 28,
                      backgroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    user.username,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ComposerCard extends StatelessWidget {
  const _ComposerCard({required this.user, required this.onCreateUpdate});

  final User? user;
  final Future<void> Function() onCreateUpdate;

  @override
  Widget build(BuildContext context) {
    final firstName = (user?.displayName ?? 'there').split(' ').first;

return _SurfaceCard(
  child: Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      children: [
        // Top Row: Avatar and Text Input Field
        Row(
          crossAxisAlignment: CrossAxisAlignment.center, // Centered for better vertical alignment
          children: [
            _Avatar(
              imageUrl: user?.photoUrl ?? '',
              label: user?.displayName ?? 'U',
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InkWell(
                onTap: () => onCreateUpdate(),
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: context.appColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    "What's on your mind, $firstName?",
                    style: TextStyle(
                      color: context.appColors.textMuted,
                      fontSize: 14, // Slightly increased for readability
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 16), // Increased spacing for a cleaner look

        // Bottom Row: Chips and Publish Button
        Row(
          children: [
            _ComposerChip(
              icon: Icons.image_outlined,
              label: 'Photo',
              background: context.appColors.accentSoft,
              color: context.appColors.accentSoftText,
            ),
            const SizedBox(width: 8),
            _ComposerChip(
              icon: Icons.sentiment_satisfied_alt_outlined,
              label: 'Feeling',
              background: context.appColors.warningSoft,
              color: context.appColors.warningText,
            ),
            
            const Spacer(), // This pushes the button to the far right

            // The "Publish" Button (Inline)
            SizedBox(
              height: 40, // Match the height of the chips for symmetry
              child: FilledButton.icon(
                onPressed: () => onCreateUpdate(),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF93A2F6), // Using that soft purple from your image
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                label: const Text('Post'),
                icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                iconAlignment: IconAlignment.end, // Puts arrow on the right
              ),
            ),
          ],
        ),
      ],
    ),
  ),
);
  }
}

class _ComposerChip extends StatelessWidget {
  const _ComposerChip({
    required this.icon,
    required this.label,
    required this.background,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color background;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuoteGrid extends StatelessWidget {
  const _QuoteGrid({required this.quotes, required this.onOpenQuote});

  final List<QuoteCard> quotes;
  final Future<void> Function(int postId) onOpenQuote;

  @override
  Widget build(BuildContext context) {
    if (quotes.isEmpty) {
      return const SizedBox.shrink();
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: quotes.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1,
      ),
      itemBuilder: (context, index) {
        final quote = quotes[index];

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => onOpenQuote(quote.id),
            borderRadius: BorderRadius.circular(18),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (quote.photoUrl.isNotEmpty)
                    AppNetworkImage(
                      imageUrl: quote.photoUrl,
                      fit: BoxFit.cover,
                      backgroundColor: context.appColors.surfaceMuted,
                      placeholderLabel: quote.title,
                    )
                  else
                    Container(color: const Color(0xFF3D5AFE)),
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Color.fromRGBO(0, 0, 0, 0.82),
                          Color.fromRGBO(0, 0, 0, 0.12),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 12,
                    child: Text(
                      quote.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ignore: unused_element
class _BirthdayCelebrationCard extends StatelessWidget {
  const _BirthdayCelebrationCard({
    required this.users,
    required this.onOpenProfile,
    required this.onViewAll,
  });

  final List<FeedUser> users;
  final Future<void> Function(String username) onOpenProfile;
  final Future<void> Function() onViewAll;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final previewUsers = users.take(5).toList();
    return _SurfaceCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(
              title: 'Today Birthday Celebrations',
              accent: '🎂',
              action: 'View all',
              onActionTap: () => onViewAll(),
            ),
            const SizedBox(height: 10),
            Text(
              users.length == 1
                  ? 'Someone in the HopefulMe community is celebrating today.'
                  : '${users.length} people in the HopefulMe community are celebrating today.',
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: previewUsers
                  .map(
                    (user) => InkWell(
                      onTap: () => onOpenProfile(user.username),
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        width: 150,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colors.surfaceMuted,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundImage: user.photoUrl.isNotEmpty
                                  ? NetworkImage(user.photoUrl)
                                  : null,
                              child: user.photoUrl.isEmpty
                                  ? const Icon(Icons.person)
                                  : null,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              user.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              user.cityState.isNotEmpty
                                  ? user.cityState
                                  : '@${user.username}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: colors.textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _BirthdayCelebrationStrip extends StatelessWidget {
  const _BirthdayCelebrationStrip({
    required this.users,
    required this.onOpenProfile,
    required this.onViewAll,
  });

  final List<FeedUser> users;
  final Future<void> Function(String username) onOpenProfile;
  final Future<void> Function() onViewAll;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final previewUsers = users.take(9).toList();
    final leadName = users.first.displayName;
    final othersCount = users.length - 1;

    return _SurfaceCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Text('🎈', style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      Text(
                        "Today's Birthdays",
                        style: TextStyle(
                          color: colors.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ),
                InkWell(
                  onTap: () => onViewAll(),
                  borderRadius: BorderRadius.circular(999),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Text(
                      'View All',
                      style: TextStyle(
                        color: Color(0xFF3D5AFE),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 48,
              child: Stack(
                children: [
                  for (var index = 0; index < previewUsers.length; index++)
                    Positioned(
                      left: index * 32,
                      child: InkWell(
                        onTap: () =>
                            onOpenProfile(previewUsers[index].username),
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: colors.surface, width: 4),
                            boxShadow: [
                              BoxShadow(
                                color: colors.shadow.withOpacity(0.08),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                            color: colors.surfaceMuted,
                          ),
                          child: CircleAvatar(
                            radius: 20,
                            backgroundColor: colors.surfaceMuted,
                            backgroundImage:
                                previewUsers[index].photoUrl.isNotEmpty
                                ? NetworkImage(previewUsers[index].photoUrl)
                                : null,
                            child: previewUsers[index].photoUrl.isEmpty
                                ? const Icon(Icons.person, size: 18)
                                : null,
                          ),
                        ),
                      ),
                    ),
                  if (users.length >= 5)
                    Positioned(
                      left: previewUsers.length * 32,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: colors.surfaceMuted,
                          shape: BoxShape.circle,
                          border: Border.all(color: colors.surface, width: 4),
                        ),
                        child: Center(
                          child: Text(
                            '+',
                            style: TextStyle(
                              color: colors.textMuted,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            RichText(
              text: TextSpan(
                style: TextStyle(
                  color: colors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
                children: [
                  const TextSpan(text: "It's "),
                  TextSpan(
                    text: leadName,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (othersCount > 0)
                    TextSpan(text: ' and $othersCount others'),
                  const TextSpan(text: "' birthday! 🎉"),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedEntryCard extends StatelessWidget {
  const _FeedEntryCard({
    required this.entry,
    required this.currentUser,
    required this.onOpenProfile,
    required this.onOpenUpdate,
    required this.onOpenPost,
    required this.onOpenBlog,
    required this.onOpenHashtag,
    required this.updateRepository,
  });

  final FeedEntry entry;
  final User? currentUser;
  final Future<void> Function(String username) onOpenProfile;
  final Future<void> Function(FeedEntry entry) onOpenUpdate;
  final Future<void> Function(FeedEntry entry) onOpenPost;
  final Future<void> Function(FeedEntry entry) onOpenBlog;
  final Future<void> Function(String hashtag) onOpenHashtag;
  final UpdateRepository updateRepository;

  @override
  Widget build(BuildContext context) {
    return switch (entry.type) {
      'update' => _UpdateFeedCard(
        entry: entry,
        currentUser: currentUser,
        onOpenProfile: onOpenProfile,
        onOpenUpdate: onOpenUpdate,
        onOpenHashtag: onOpenHashtag,
        updateRepository: updateRepository,
      ),
      'blog' => _BlogFeedCard(
        entry: entry,
        onOpenProfile: onOpenProfile,
        onOpenBlog: onOpenBlog,
        onOpenHashtag: onOpenHashtag,
      ),
      _ => _PostFeedCard(
        entry: entry,
        onOpenPost: onOpenPost,
        onOpenProfile: onOpenProfile,
        onOpenHashtag: onOpenHashtag,
      ),
    };
  }
}

class _PostFeedCard extends StatelessWidget {
  const _PostFeedCard({
    required this.entry,
    required this.onOpenPost,
    required this.onOpenProfile,
    required this.onOpenHashtag,
  });

  final FeedEntry entry;
  final Future<void> Function(FeedEntry entry) onOpenPost;
  final Future<void> Function(String username) onOpenProfile;
  final Future<void> Function(String hashtag) onOpenHashtag;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return InkWell(
      onTap: () => onOpenPost(entry),
      borderRadius: BorderRadius.circular(26),
      child: _SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (entry.photoUrl.isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(26),
                ),
                child: Image.network(
                  entry.photoUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const SizedBox(
                    height: 180,
                    child: Center(child: Icon(Icons.broken_image_outlined)),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (entry.body.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    RichDisplayText(
                      text: entry.body,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textMuted,
                        fontSize: 14,
                        height: 1.55,
                      ),
                      onMentionTap: onOpenProfile,
                      onHashtagTap: onOpenHashtag,
                    ),
                  ],
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF3D5AFE), Color(0xFF7C3AED)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'View Post',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UpdateFeedCard extends StatelessWidget {
  const _UpdateFeedCard({
    required this.entry,
    required this.currentUser,
    required this.onOpenProfile,
    required this.onOpenUpdate,
    required this.onOpenHashtag,
    required this.updateRepository,
  });

  final FeedEntry entry;
  final User? currentUser;
  final Future<void> Function(String username) onOpenProfile;
  final Future<void> Function(FeedEntry entry) onOpenUpdate;
  final Future<void> Function(String hashtag) onOpenHashtag;
  final UpdateRepository updateRepository;

  @override
  Widget build(BuildContext context) {
    final entry = this.entry;
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
      updateRepository: updateRepository,
      onOpenUpdate: () => onOpenUpdate(entry),
      currentUser: currentUser,
      ownerUsername: entry.user?.username,
      onOpenProfile: onOpenProfile,
      onOpenHashtag: onOpenHashtag,
    );
  }
}

class _BlogFeedCard extends StatelessWidget {
  const _BlogFeedCard({
    required this.entry,
    required this.onOpenProfile,
    required this.onOpenBlog,
    required this.onOpenHashtag,
  });

  final FeedEntry entry;
  final Future<void> Function(String username) onOpenProfile;
  final Future<void> Function(FeedEntry entry) onOpenBlog;
  final Future<void> Function(String hashtag) onOpenHashtag;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return InkWell(
      onTap: () => onOpenBlog(entry),
      borderRadius: BorderRadius.circular(26),
      child: _SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (entry.photoUrl.isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(26),
                ),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(
                    entry.photoUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const Center(child: Icon(Icons.broken_image_outlined)),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF1FF),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'BLOG',
                          style: TextStyle(
                            color: Color(0xFF3D5AFE),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        formatRelativeTimestamp(entry.createdAt).isEmpty
                            ? 'Article'
                            : 'Article · ${formatRelativeTimestamp(entry.createdAt)}',
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    entry.title,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (entry.body.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    RichDisplayText(
                      text: entry.body,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textMuted,
                        fontSize: 14,
                        height: 1.55,
                      ),
                      onMentionTap: onOpenProfile,
                      onHashtagTap: onOpenHashtag,
                    ),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      InkWell(
                        onTap: entry.user == null
                            ? null
                            : () => onOpenProfile(entry.user!.username),
                        borderRadius: BorderRadius.circular(999),
                        child: _Avatar(
                          imageUrl: entry.user?.photoUrl ?? '',
                          label: entry.user?.displayName ?? entry.title,
                          radius: 14,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: InkWell(
                          onTap: entry.user == null
                              ? null
                              : () => onOpenProfile(entry.user!.username),
                          borderRadius: BorderRadius.circular(10),
                          child: Text(
                            entry.user?.displayName ?? 'HopefulMe',
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(
                            Icons.remove_red_eye_outlined,
                            size: 14,
                            color: Color(0xFF94A3B8),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${entry.views}',
                            style: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedExploreMoreCard extends StatelessWidget {
  const _FeedExploreMoreCard({
    required this.onOpenUpdatesFeed,
    required this.onOpenPostsFeed,
    required this.onOpenBlogsFeed,
  });

  final Future<void> Function() onOpenUpdatesFeed;
  final Future<void> Function({String initialCategory}) onOpenPostsFeed;
  final Future<void> Function() onOpenBlogsFeed;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return _SurfaceCard(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Explore more',
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Open the full pages for activities, posts and blogs from here.',
              style: TextStyle(
                color: colors.textMuted,
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _FeedExploreChip(
                  icon: Icons.dynamic_feed_rounded,
                  label: 'More updates',
                  onTap: onOpenUpdatesFeed,
                ),
                _FeedExploreChip(
                  icon: Icons.article_outlined,
                  label: 'More posts',
                  onTap: () => onOpenPostsFeed(initialCategory: 'All'),
                ),
                _FeedExploreChip(
                  icon: Icons.auto_stories_outlined,
                  label: 'More blogs',
                  onTap: onOpenBlogsFeed,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedExploreChip extends StatelessWidget {
  const _FeedExploreChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return InkWell(
      onTap: () => onTap(),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: colors.surfaceMuted,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: colors.brand),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RightRail extends StatelessWidget {
  const _RightRail({
    required this.user,
    required this.dashboard,
    required this.onOpenProfile,
  });

  final User? user;
  final FeedDashboard? dashboard;
  final Future<void> Function(String username) onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final suggested = dashboard?.suggested ?? const <FeedUser>[];
    final onlineUsers = dashboard?.onlineUsers ?? const <FeedUser>[];

    return Column(
      children: [
        _GrowthCard(onlineUsers: onlineUsers),
        const SizedBox(height: 14),
        _GreetingCard(user: user),
        const SizedBox(height: 14),
        _UserListCard(
          title: 'Currently Online',
          action: 'View All',
          users: onlineUsers.take(5).toList(),
          onUserTap: onOpenProfile,
          showStatus: true,
        ),
        const SizedBox(height: 14),
        _UserListCard(
          title: 'Meet New Friends',
          action: 'See All',
          users: suggested.take(5).toList(),
          onUserTap: onOpenProfile,
        ),
      ],
    );
  }
}

class _GrowthCard extends StatelessWidget {
  const _GrowthCard({required this.onlineUsers});

  final List<FeedUser> onlineUsers;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3D5AFE), Color(0xFF7C3AED)],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Community Growth',
            style: TextStyle(
              color: Color.fromRGBO(255, 255, 255, 0.72),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '+${onlineUsers.length}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.w900,
            ),
          ),
          const Text(
            'People active around you',
            style: TextStyle(
              color: Color.fromRGBO(255, 255, 255, 0.68),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _GreetingCard extends StatelessWidget {
  const _GreetingCard({required this.user});

  final User? user;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            _Avatar(
              imageUrl: user?.photoUrl ?? '',
              label: user?.displayName ?? 'U',
              radius: 28,
            ),
            const SizedBox(height: 10),
            Text(
              'Good ${_greeting()}, ${(user?.displayName ?? 'friend').split(' ').first}!',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF1C2540),
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Keep sharing. Keep inspiring.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF8896B0), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  static String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Morning';
    if (hour < 17) return 'Afternoon';
    return 'Evening';
  }
}

class _UserListCard extends StatelessWidget {
  const _UserListCard({
    required this.title,
    required this.action,
    required this.users,
    required this.onUserTap,
    this.showStatus = false,
  });

  final String title;
  final String action;
  final List<FeedUser> users;
  final Future<void> Function(String username) onUserTap;
  final bool showStatus;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _SectionHeader(title: title, action: action),
            const SizedBox(height: 14),
            ...users.map(
              (user) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: () => onUserTap(user.username),
                  borderRadius: BorderRadius.circular(18),
                  child: Row(
                    children: [
                      Stack(
                        children: [
                          _Avatar(
                            imageUrl: user.photoUrl,
                            label: user.displayName,
                            radius: 20,
                          ),
                          if (showStatus && user.isOnline)
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.displayName,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF1C2540),
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '@${user.username}',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF8896B0),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0A0F1E),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Follow',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.action,
    this.accent,
    this.leading,
    this.onActionTap,
  });

  final String title;
  final String? action;
  final String? accent;
  final Widget? leading;
  final VoidCallback? onActionTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (leading != null) ...[leading!, const SizedBox(width: 10)],
        if (accent != null) ...[
          Text(accent!, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: context.appColors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (action != null)
          InkWell(
            onTap: onActionTap,
            borderRadius: BorderRadius.circular(999),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Text(
                action!,
                style: TextStyle(
                  color: context.appColors.brand,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: colors.borderStrong),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.imageUrl,
    required this.label,
    this.radius = 18,
    this.backgroundColor = const Color(0xFFEEF1FF),
  });

  final String imageUrl;
  final String label;
  final double radius;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final initials = _initials(label);

    return AppAvatar(
      imageUrl: imageUrl,
      label: initials,
      radius: radius,
      backgroundColor: backgroundColor,
    );
  }

  static String _initials(String input) {
    final parts = input
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty);
    if (parts.isEmpty) {
      return 'U';
    }

    final letters = parts.take(2).map((part) => part[0].toUpperCase()).join();
    return letters.isEmpty ? 'U' : letters;
  }
}
