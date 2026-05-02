import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hopefulme_flutter/app/theme/theme_controller.dart';
import 'package:hopefulme_flutter/core/widgets/major_bottom_nav.dart';
import 'package:hopefulme_flutter/features/auth/presentation/controllers/auth_controller.dart';
import 'package:hopefulme_flutter/features/community/presentation/screens/meet_new_friends_screen.dart';
import 'package:hopefulme_flutter/features/content/data/content_repository.dart';
import 'package:hopefulme_flutter/features/feed/data/feed_repository.dart';
import 'package:hopefulme_flutter/features/feed/presentation/screens/home_screen.dart';
import 'package:hopefulme_flutter/features/groups/data/group_repository.dart';
import 'package:hopefulme_flutter/features/groups/presentation/screens/groups_screen.dart';
import 'package:hopefulme_flutter/features/library/data/library_repository.dart';
import 'package:hopefulme_flutter/features/messages/data/message_repository.dart';
import 'package:hopefulme_flutter/features/notifications/data/notification_repository.dart';
import 'package:hopefulme_flutter/features/profile/data/profile_repository.dart';
import 'package:hopefulme_flutter/features/search/data/search_repository.dart';
import 'package:hopefulme_flutter/features/search/presentation/screens/search_screen.dart';
import 'package:hopefulme_flutter/features/templates/data/flyer_template_repository.dart';
import 'package:hopefulme_flutter/features/updates/data/update_repository.dart';
import 'package:hopefulme_flutter/features/updates/models/update_detail.dart';
import 'package:hopefulme_flutter/features/updates/presentation/screens/update_compose_screen.dart';

class MainShellScreen extends StatefulWidget {
  const MainShellScreen({
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
    required this.flyerTemplateRepository,
    required this.onCheckForUpdates,
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
  final FlyerTemplateRepository flyerTemplateRepository;
  final Future<void> Function() onCheckForUpdates;

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int _selectedIndex = 0;
  int _unreadGroupsCount = 0;
  final ValueNotifier<UpdateDetail?> _pendingCreatedUpdateNotifier =
      ValueNotifier<UpdateDetail?>(null);

  @override
  void initState() {
    super.initState();
    _refreshUnreadGroupsCount();
  }

  @override
  void dispose() {
    _pendingCreatedUpdateNotifier.dispose();
    super.dispose();
  }

  Future<void> _refreshUnreadGroupsCount() async {
    if (!widget.authController.isAuthenticated) {
      if (!mounted) return;
      setState(() {
        _unreadGroupsCount = 0;
      });
      return;
    }

    try {
      final groupsPage = await widget.groupRepository.fetchGroups(page: 1);
      final count = groupsPage.items.fold<int>(
        0,
        (sum, group) => sum + group.unreadCount,
      );
      if (!mounted) return;
      setState(() {
        _unreadGroupsCount = count;
      });
    } catch (_) {
      // Keep last known value on transient failures.
    }
  }

  Future<void> _onTabSelected(int index) async {
    if (!mounted) return;
    if (index == 2) {
      final created = await Navigator.of(context).push<UpdateDetail>(
        MaterialPageRoute<UpdateDetail>(
          builder: (context) => UpdateComposeScreen(
            updateRepository: widget.updateRepository,
            contentRepository: widget.contentRepository,
            currentUsername: widget.authController.currentUser?.username,
            currentUser: widget.authController.currentUser,
          ),
        ),
      );
      if (!mounted) return;
      if (created != null) {
        _pendingCreatedUpdateNotifier.value = created;
        setState(() {
          _selectedIndex = 0;
        });
        unawaited(_refreshUnreadGroupsCount());
      }
      return;
    }
    if (_selectedIndex == index) {
      unawaited(_refreshUnreadGroupsCount());
      return;
    }
    setState(() {
      _selectedIndex = index;
    });
    unawaited(_refreshUnreadGroupsCount());
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final showBottomNav = width < 960;
    final currentUser = widget.authController.currentUser;
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          HomeScreen(
            authController: widget.authController,
            themeController: widget.themeController,
            feedRepository: widget.feedRepository,
            contentRepository: widget.contentRepository,
            notificationRepository: widget.notificationRepository,
            messageRepository: widget.messageRepository,
            groupRepository: widget.groupRepository,
            profileRepository: widget.profileRepository,
            searchRepository: widget.searchRepository,
            updateRepository: widget.updateRepository,
            libraryRepository: widget.libraryRepository,
            flyerTemplateRepository: widget.flyerTemplateRepository,
            onCheckForUpdates: widget.onCheckForUpdates,
            embedInMajorShell: true,
            onMajorTabSelected: _onTabSelected,
            pendingCreatedUpdateNotifier: _pendingCreatedUpdateNotifier,
          ),
          SearchScreen(
            repository: widget.searchRepository,
            contentRepository: widget.contentRepository,
            messageRepository: widget.messageRepository,
            profileRepository: widget.profileRepository,
            updateRepository: widget.updateRepository,
            currentUser: currentUser,
            showMajorBottomNav: false,
          ),
          const SizedBox.shrink(),
          GroupsScreen(
            repository: widget.groupRepository,
            currentUser: currentUser,
            profileRepository: widget.profileRepository,
            messageRepository: widget.messageRepository,
            updateRepository: widget.updateRepository,
            showMajorBottomNav: false,
          ),
          MeetNewFriendsScreen(
            feedRepository: widget.feedRepository,
            profileRepository: widget.profileRepository,
            messageRepository: widget.messageRepository,
            updateRepository: widget.updateRepository,
            currentUser: currentUser,
            showMajorBottomNav: false,
          ),
        ],
      ),
      bottomNavigationBar: showBottomNav
          ? MajorBottomNav(
              selectedIndex: _selectedIndex,
              unreadGroupsCount: _unreadGroupsCount,
              onSelected: (index) {
                _onTabSelected(index);
              },
            )
          : null,
    );
  }
}
