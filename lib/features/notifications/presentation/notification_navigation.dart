import 'package:flutter/material.dart';
import 'package:hopefulme_flutter/features/auth/models/user.dart';
import 'package:hopefulme_flutter/features/content/data/content_repository.dart';
import 'package:hopefulme_flutter/features/content/presentation/content_navigation.dart';
import 'package:hopefulme_flutter/features/messages/data/message_repository.dart';
import 'package:hopefulme_flutter/features/messages/presentation/screens/message_thread_screen.dart';
import 'package:hopefulme_flutter/features/notifications/models/app_notification.dart';
import 'package:hopefulme_flutter/features/profile/data/profile_repository.dart';
import 'package:hopefulme_flutter/features/profile/presentation/profile_navigation.dart';
import 'package:hopefulme_flutter/features/profile/presentation/screens/edit_profile_screen.dart';
import 'package:hopefulme_flutter/features/search/data/search_repository.dart';
import 'package:hopefulme_flutter/features/updates/data/update_repository.dart';
import 'package:hopefulme_flutter/features/updates/presentation/screens/update_detail_screen.dart';

class NotificationNavigator {
  const NotificationNavigator({
    required this.profileRepository,
    required this.contentRepository,
    required this.messageRepository,
    this.searchRepository,
    required this.updateRepository,
    required this.currentUser,
  });

  final ProfileRepository profileRepository;
  final ContentRepository contentRepository;
  final MessageRepository messageRepository;
  final SearchRepository? searchRepository;
  final UpdateRepository updateRepository;
  final User? currentUser;

  Future<bool> open(BuildContext context, AppNotification notification) async {
    final uri = Uri.tryParse(notification.url.trim());
    if (uri == null) {
      return false;
    }

    final segments = uri.pathSegments
        .where((segment) => segment.isNotEmpty)
        .toList();
    if (segments.isEmpty) {
      return false;
    }

    if (segments.length == 1 && _looksLikeProfileSegment(segments.first)) {
      await openUserProfile(
        context,
        profileRepository: profileRepository,
        messageRepository: messageRepository,
        updateRepository: updateRepository,
        currentUser: currentUser,
        username: segments.first,
      );
      return true;
    }

    if (segments.length >= 2 && segments[0] == 'social') {
      final rawTarget = segments[1];
      final idPart = rawTarget.split('@').first;
      final updateId = int.tryParse(idPart);
      if (updateId == null) {
        return false;
      }

      await Navigator.of(context).push<UpdateDetailResult>(
        MaterialPageRoute<UpdateDetailResult>(
          builder: (context) => UpdateDetailScreen(
            updateId: updateId,
            currentUser: currentUser,
            repository: updateRepository,
            contentRepository: contentRepository,
            profileRepository: profileRepository,
            messageRepository: messageRepository,
            searchRepository: searchRepository,
          ),
        ),
      );
      return true;
    }

    if ((notification.contentType == 'post' || _looksLikePostPath(segments)) &&
        notification.contentId > 0) {
      await openPostDetail(
        context,
        contentRepository: contentRepository,
        profileRepository: profileRepository,
        messageRepository: messageRepository,
        searchRepository: searchRepository,
        updateRepository: updateRepository,
        postId: notification.contentId,
        currentUsername: currentUser?.username,
      );
      return true;
    }

    if ((notification.contentType == 'blog' || _looksLikeBlogPath(segments)) &&
        notification.contentId > 0) {
      await openBlogDetail(
        context,
        contentRepository: contentRepository,
        profileRepository: profileRepository,
        messageRepository: messageRepository,
        searchRepository: searchRepository,
        updateRepository: updateRepository,
        blogId: notification.contentId,
        currentUsername: currentUser?.username,
      );
      return true;
    }

    if ((notification.type == 'inspiration' ||
            _looksLikeInspirePath(segments)) &&
        notification.inspirationId > 0) {
      await openInspirationDetail(
        context,
        contentRepository: contentRepository,
        profileRepository: profileRepository,
        messageRepository: messageRepository,
        updateRepository: updateRepository,
        currentUser: currentUser,
        inspirationId: notification.inspirationId,
      );
      return true;
    }

    if (segments.length >= 2 && segments[0] == 'chat') {
      final username = segments[1].trim().replaceFirst('@', '');
      if (username.isEmpty) {
        return false;
      }

      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => MessageThreadScreen(
            repository: messageRepository,
            profileRepository: profileRepository,
            updateRepository: updateRepository,
            currentUser: currentUser,
            username: username,
            title: username,
          ),
        ),
      );
      return true;
    }

    if (segments.length >= 2 &&
        segments[0] == 'myprofile' &&
        segments[1] == 'edit' &&
        currentUser != null) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => EditProfileScreen(
            username: currentUser!.username,
            repository: profileRepository,
          ),
        ),
      );
      return true;
    }

    return false;
  }

  bool _looksLikeProfileSegment(String segment) {
    const reserved = <String>{
      'about',
      'admin',
      'adverts',
      'api',
      'blog',
      'chat',
      'community',
      'contact',
      'groups',
      'home',
      'inspire',
      'library',
      'login',
      'logout',
      'myprofile',
      'notifications',
      'outreach',
      'post',
      'posts',
      'privacy',
      'register',
      'search',
      'settings',
      'social',
      'terms',
      'welcome',
    };

    return !reserved.contains(segment.toLowerCase());
  }

  bool _looksLikePostPath(List<String> segments) {
    return segments.length >= 2 && segments[0] == 'post';
  }

  bool _looksLikeBlogPath(List<String> segments) {
    return segments.isNotEmpty && segments[0] == 'blog';
  }

  bool _looksLikeInspirePath(List<String> segments) {
    return segments.length >= 2 && segments[0] == 'inspire';
  }
}
