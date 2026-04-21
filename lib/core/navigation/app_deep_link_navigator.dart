import 'package:flutter/material.dart';
import 'package:hopefulme_flutter/core/presentation/screens/web_page_screen.dart';
import 'package:hopefulme_flutter/features/auth/models/user.dart';
import 'package:hopefulme_flutter/features/content/data/content_repository.dart';
import 'package:hopefulme_flutter/features/content/presentation/content_navigation.dart';
import 'package:hopefulme_flutter/features/content/presentation/screens/blogs_feed_screen.dart';
import 'package:hopefulme_flutter/features/content/presentation/screens/inspiration_inbox_screen.dart';
import 'package:hopefulme_flutter/features/content/presentation/screens/posts_feed_screen.dart';
import 'package:hopefulme_flutter/features/feed/data/feed_repository.dart';
import 'package:hopefulme_flutter/features/feed/models/feed_dashboard.dart';
import 'package:hopefulme_flutter/features/feed/presentation/screens/today_birthdays_screen.dart';
import 'package:hopefulme_flutter/features/groups/data/group_repository.dart';
import 'package:hopefulme_flutter/features/groups/presentation/screens/group_thread_screen.dart';
import 'package:hopefulme_flutter/features/groups/presentation/screens/groups_screen.dart';
import 'package:hopefulme_flutter/features/library/data/library_repository.dart';
import 'package:hopefulme_flutter/features/library/presentation/screens/library_detail_screen.dart';
import 'package:hopefulme_flutter/features/library/presentation/screens/library_screen.dart';
import 'package:hopefulme_flutter/features/templates/data/flyer_template_repository.dart';
import 'package:hopefulme_flutter/features/templates/presentation/screens/flyer_template_editor_screen.dart';
import 'package:hopefulme_flutter/features/templates/presentation/screens/flyer_templates_screen.dart';
import 'package:hopefulme_flutter/features/messages/data/message_repository.dart';
import 'package:hopefulme_flutter/features/messages/presentation/screens/message_thread_screen.dart';
import 'package:hopefulme_flutter/features/messages/presentation/screens/messages_screen.dart';
import 'package:hopefulme_flutter/features/profile/data/profile_repository.dart';
import 'package:hopefulme_flutter/features/profile/presentation/profile_navigation.dart';
import 'package:hopefulme_flutter/features/search/data/search_repository.dart';
import 'package:hopefulme_flutter/features/search/presentation/screens/search_screen.dart';
import 'package:hopefulme_flutter/features/updates/data/update_repository.dart';
import 'package:hopefulme_flutter/features/updates/presentation/screens/update_detail_screen.dart';
import 'package:hopefulme_flutter/features/updates/presentation/screens/updates_feed_screen.dart';

class AppDeepLinkNavigator {
  const AppDeepLinkNavigator({
    required this.feedRepository,
    required this.contentRepository,
    required this.profileRepository,
    required this.messageRepository,
    required this.groupRepository,
    required this.updateRepository,
    required this.searchRepository,
    required this.libraryRepository,
    required this.flyerTemplateRepository,
    required this.currentUser,
    required this.webBaseUrl,
  });

  final FeedRepository feedRepository;
  final ContentRepository contentRepository;
  final ProfileRepository profileRepository;
  final MessageRepository messageRepository;
  final GroupRepository groupRepository;
  final UpdateRepository updateRepository;
  final SearchRepository searchRepository;
  final LibraryRepository libraryRepository;
  final FlyerTemplateRepository flyerTemplateRepository;
  final User? currentUser;
  final String webBaseUrl;

  Future<bool> open(BuildContext context, Uri uri) async {
    final normalized = _normalizeUri(uri);
    if (normalized == null) {
      return false;
    }

    final segments = normalized.pathSegments
        .where((segment) => segment.isNotEmpty)
        .toList();

    if (segments.isEmpty) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      return true;
    }

    if (segments.first.toLowerCase() == 'home') {
      Navigator.of(context).popUntil((route) => route.isFirst);
      return true;
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

    if (segments.first.startsWith('@')) {
      final username = segments.first.substring(1).trim();
      if (username.isNotEmpty) {
        await openUserProfile(
          context,
          profileRepository: profileRepository,
          messageRepository: messageRepository,
          updateRepository: updateRepository,
          currentUser: currentUser,
          username: username,
        );
        return true;
      }
    }

    switch (segments.first.toLowerCase()) {
      case 'updates':
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (context) => UpdatesFeedScreen(
              feedRepository: feedRepository,
              contentRepository: contentRepository,
              updateRepository: updateRepository,
              profileRepository: profileRepository,
              messageRepository: messageRepository,
              searchRepository: searchRepository,
              currentUser: currentUser,
            ),
          ),
        );
        return true;
      case 'social':
        final updateId = _extractLeadingInt(segments.elementAtOrNull(1));
        if (updateId == null) {
          return _openWebPage(context, normalized, title: 'Activity');
        }
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
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
      case 'posts':
        final category =
            segments.length >= 3 && segments[1].toLowerCase() == 'category'
            ? Uri.decodeComponent(segments[2])
            : 'All';
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (context) => PostsFeedScreen(
              feedRepository: feedRepository,
              contentRepository: contentRepository,
              profileRepository: profileRepository,
              messageRepository: messageRepository,
              updateRepository: updateRepository,
              searchRepository: searchRepository,
              currentUser: currentUser,
              currentUsername: currentUser?.username,
              initialCategory: category,
            ),
          ),
        );
        return true;
      case 'post':
        final postId = _extractLeadingInt(segments.elementAtOrNull(1));
        if (postId == null) {
          return _openWebPage(context, normalized, title: 'Post');
        }
        await openPostDetail(
          context,
          contentRepository: contentRepository,
          profileRepository: profileRepository,
          messageRepository: messageRepository,
          searchRepository: searchRepository,
          updateRepository: updateRepository,
          postId: postId,
          currentUsername: currentUser?.username,
        );
        return true;
      case 'blog':
        if (segments.length == 1) {
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (context) => BlogsFeedScreen(
                feedRepository: feedRepository,
                contentRepository: contentRepository,
                profileRepository: profileRepository,
                messageRepository: messageRepository,
                updateRepository: updateRepository,
                searchRepository: searchRepository,
                currentUsername: currentUser?.username,
              ),
            ),
          );
          return true;
        }

        final blogId = _extractLeadingInt(segments[1]);
        if (blogId == null) {
          return _openWebPage(context, normalized, title: 'Blog');
        }
        await openBlogDetail(
          context,
          contentRepository: contentRepository,
          profileRepository: profileRepository,
          messageRepository: messageRepository,
          searchRepository: searchRepository,
          updateRepository: updateRepository,
          blogId: blogId,
          currentUsername: currentUser?.username,
        );
        return true;
      case 'library':
        final libraryId = _extractLeadingInt(segments.elementAtOrNull(1));
        if (libraryId == null) {
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (context) =>
                  LibraryScreen(repository: libraryRepository),
            ),
          );
          return true;
        }
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (context) => LibraryDetailScreen(
              libraryId: libraryId,
              repository: libraryRepository,
            ),
          ),
        );
        return true;
      case 'templates':
        final templateId = _extractLeadingInt(segments.elementAtOrNull(1));
        if (templateId == null) {
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (context) => FlyerTemplatesScreen(
                repository: flyerTemplateRepository,
                webBaseUrl: webBaseUrl,
              ),
            ),
          );
          return true;
        }

        final navigatorState = Navigator.of(context);
        final template = await flyerTemplateRepository.fetchTemplate(
          templateId,
        );
        await navigatorState.push(
          MaterialPageRoute<void>(
            builder: (context) => FlyerTemplateEditorScreen(
              template: template,
              repository: flyerTemplateRepository,
            ),
          ),
        );
        return true;
      case 'chat':
        if (segments.length == 1) {
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (context) => MessagesScreen(
                repository: messageRepository,
                profileRepository: profileRepository,
                updateRepository: updateRepository,
                groupRepository: groupRepository,
                currentUser: currentUser,
              ),
            ),
          );
          return true;
        }

        final username = segments[1].trim().replaceFirst('@', '');
        if (username.isEmpty) {
          return _openWebPage(context, normalized, title: 'Messages');
        }
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (context) => MessageThreadScreen(
              repository: messageRepository,
              profileRepository: profileRepository,
              updateRepository: updateRepository,
              currentUser: currentUser,
              username: username,
              title: 'Conversation',
            ),
          ),
        );
        return true;
      case 'groups':
        final groupId = _extractLeadingInt(segments.elementAtOrNull(1));
        if (groupId == null) {
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (context) => GroupsScreen(
                repository: groupRepository,
                currentUser: currentUser,
                profileRepository: profileRepository,
                messageRepository: messageRepository,
                updateRepository: updateRepository,
              ),
            ),
          );
          return true;
        }
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (context) => GroupThreadScreen(
              groupId: groupId,
              currentUser: currentUser,
              repository: groupRepository,
              profileRepository: profileRepository,
              messageRepository: messageRepository,
              updateRepository: updateRepository,
            ),
          ),
        );
        return true;
      case 'community':
        if (segments.length >= 2 && segments[1].toLowerCase() == 'birthdays') {
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (context) => TodayBirthdaysScreen(
                feedRepository: feedRepository,
                initialUsers: const <FeedUser>[],
                profileRepository: profileRepository,
                messageRepository: messageRepository,
                updateRepository: updateRepository,
                currentUser: currentUser,
              ),
            ),
          );
          return true;
        }
        break;
      case 'search':
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (context) => SearchScreen(
              repository: searchRepository,
              contentRepository: contentRepository,
              messageRepository: messageRepository,
              profileRepository: profileRepository,
              updateRepository: updateRepository,
              currentUser: currentUser,
              initialQuery:
                  normalized.queryParameters['q'] ??
                  normalized.queryParameters['query'] ??
                  '',
            ),
          ),
        );
        return true;
      case 'inspire':
        if (segments.length == 1 ||
            (segments.length >= 2 && segments[1].toLowerCase() == 'inbox')) {
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (context) => InspirationInboxScreen(
                repository: contentRepository,
                profileRepository: profileRepository,
                messageRepository: messageRepository,
                updateRepository: updateRepository,
                currentUser: currentUser,
              ),
            ),
          );
          return true;
        }

        if (segments.length >= 3 && segments[1].toLowerCase() == 'for') {
          final username = segments[2].trim().replaceFirst('@', '');
          if (username.isEmpty) {
            return _openWebPage(context, normalized, title: 'Inspirations');
          }

          await openUserProfile(
            context,
            profileRepository: profileRepository,
            messageRepository: messageRepository,
            updateRepository: updateRepository,
            currentUser: currentUser,
            username: username,
          );
          return true;
        }

        final inspirationId = _extractLeadingInt(segments.elementAtOrNull(1));
        if (inspirationId == null) {
          return _openWebPage(context, normalized, title: 'Inspirations');
        }

        await openInspirationDetail(
          context,
          contentRepository: contentRepository,
          profileRepository: profileRepository,
          messageRepository: messageRepository,
          updateRepository: updateRepository,
          currentUser: currentUser,
          inspirationId: inspirationId,
        );
        return true;
      case 'store':
        return _openWebPage(context, normalized, title: 'Marketplace');
      case 'tv':
        return _openWebPage(context, normalized, title: 'HopefulMe TV');
      case 'outreach':
        return _openWebPage(context, normalized, title: 'Outreach');
      case 'about':
        return _openWebPage(context, normalized, title: 'About');
      case 'contact':
        return _openWebPage(context, normalized, title: 'Contact');
      case 'profile':
        if (segments.length >= 2) {
          await openUserProfile(
            context,
            profileRepository: profileRepository,
            messageRepository: messageRepository,
            updateRepository: updateRepository,
            currentUser: currentUser,
            username: segments[1],
          );
          return true;
        }
    }

    if (!context.mounted) {
      return false;
    }

    return _openWebPage(context, normalized, title: 'HopefulMe');
  }

  Uri? _normalizeUri(Uri uri) {
    if (!uri.hasScheme) {
      return uri;
    }

    final configuredHost = Uri.tryParse(webBaseUrl)?.host.toLowerCase();
    final host = uri.host.toLowerCase();
    final allowedHosts = <String>{
      if (configuredHost != null && configuredHost.isNotEmpty) configuredHost,
      'ahopefulme.com',
      'www.ahopefulme.com',
      // '127.0.0.1',
      //'localhost',
    };

    if (host.isNotEmpty && !allowedHosts.contains(host)) {
      return null;
    }

    return uri;
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
      'games',
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
      'store',
      'terms',
      'templates',
      'tv',
      'updates',
      'welcome',
    };

    final normalized = segment.toLowerCase();
    return !reserved.contains(normalized) && !normalized.startsWith('@');
  }

  int? _extractLeadingInt(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }

    final match = RegExp(r'^(\d+)').firstMatch(raw.trim());
    return match == null ? null : int.tryParse(match.group(1)!);
  }

  Future<bool> _openWebPage(
    BuildContext context,
    Uri uri, {
    required String title,
  }) async {
    final absoluteUri = uri.hasScheme
        ? uri
        : Uri.parse(webBaseUrl).resolveUri(uri);

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => WebPageScreen(
          title: title,
          url: absoluteUri.toString(),
          onInternalLinkTap: (uri) async {
            if (!WebPageScreen.shouldUseNativeRouting(
              uri,
              originUrl: webBaseUrl,
            )) {
              return false;
            }
            if (!context.mounted) {
              return false;
            }
            return open(context, uri);
          },
        ),
      ),
    );

    return true;
  }
}
