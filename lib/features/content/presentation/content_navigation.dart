import 'package:flutter/material.dart';
import 'package:hopefulme_flutter/features/content/data/content_repository.dart';
import 'package:hopefulme_flutter/features/content/models/content_detail.dart';
import 'package:hopefulme_flutter/features/content/presentation/screens/content_detail_screen.dart';
import 'package:hopefulme_flutter/features/content/presentation/screens/inspiration_detail_screen.dart';
import 'package:hopefulme_flutter/features/messages/data/message_repository.dart';
import 'package:hopefulme_flutter/features/profile/data/profile_repository.dart';
import 'package:hopefulme_flutter/features/search/data/search_repository.dart';
import 'package:hopefulme_flutter/features/updates/data/update_repository.dart';

Future<void> openPostDetail(
  BuildContext context, {
  required ContentRepository contentRepository,
  required ProfileRepository profileRepository,
  required MessageRepository messageRepository,
  SearchRepository? searchRepository,
  required UpdateRepository updateRepository,
  required int postId,
  String? currentUsername,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (context) => ContentDetailScreen.post(
        contentId: postId,
        repository: contentRepository,
        profileRepository: profileRepository,
        messageRepository: messageRepository,
        searchRepository: searchRepository,
        updateRepository: updateRepository,
        currentUsername: currentUsername,
      ),
    ),
  );
}

Future<BlogActionResult?> openBlogDetail(
  BuildContext context, {
  required ContentRepository contentRepository,
  required ProfileRepository profileRepository,
  required MessageRepository messageRepository,
  SearchRepository? searchRepository,
  required UpdateRepository updateRepository,
  required int blogId,
  String? currentUsername,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute<BlogActionResult>(
      builder: (context) => ContentDetailScreen.blog(
        contentId: blogId,
        repository: contentRepository,
        profileRepository: profileRepository,
        messageRepository: messageRepository,
        searchRepository: searchRepository,
        updateRepository: updateRepository,
        currentUsername: currentUsername,
      ),
    ),
  );
}

Future<void> openInspirationDetail(
  BuildContext context, {
  required ContentRepository contentRepository,
  required int inspirationId,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (context) => InspirationDetailScreen(
        inspirationId: inspirationId,
        repository: contentRepository,
      ),
    ),
  );
}
