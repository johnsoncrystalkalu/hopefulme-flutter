import 'package:flutter/material.dart';
import 'package:hopefulme_flutter/features/auth/models/user.dart';
import 'package:hopefulme_flutter/features/messages/data/message_repository.dart';
import 'package:hopefulme_flutter/features/profile/data/profile_repository.dart';
import 'package:hopefulme_flutter/features/profile/presentation/screens/profile_screen.dart';
import 'package:hopefulme_flutter/features/updates/data/update_repository.dart';

Future<void> openUserProfile(
  BuildContext context, {
  required ProfileRepository profileRepository,
  required MessageRepository messageRepository,
  required UpdateRepository updateRepository,
  required User? currentUser,
  required String username,
}) async {
  final normalized = username.trim().replaceFirst('@', '');
  if (normalized.isEmpty) {
    return;
  }

  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (context) => ProfileScreen(
        currentUser: currentUser,
        profileRepository: profileRepository,
        messageRepository: messageRepository,
        updateRepository: updateRepository,
        username: normalized,
      ),
    ),
  );
}
