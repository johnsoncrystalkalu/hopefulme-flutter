import 'package:flutter/material.dart';
import 'package:hopefulme_flutter/app/theme/app_theme.dart';
import 'package:hopefulme_flutter/features/content/data/content_repository.dart';
import 'package:hopefulme_flutter/features/content/presentation/screens/blog_editor_screen.dart';
import 'package:hopefulme_flutter/features/auth/models/user.dart';
import 'package:hopefulme_flutter/features/updates/data/update_repository.dart';
import 'package:hopefulme_flutter/features/updates/presentation/widgets/update_submission_modal.dart';

class UpdateComposeScreen extends StatelessWidget {
  const UpdateComposeScreen({
    required this.updateRepository,
    required this.currentUser,
    this.contentRepository,
    this.currentUsername,
    super.key,
  });

  final UpdateRepository updateRepository;
  final ContentRepository? contentRepository;
  final String? currentUsername;
  final User? currentUser;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appColors.scaffold,
      appBar: AppBar(
        backgroundColor: context.appColors.surface,
        surfaceTintColor: context.appColors.surface,
        titleSpacing: 0,
        title: const Text('Create Post'),
        actions: [
          TextButton(
            onPressed: () {
              final repository = contentRepository;
              if (repository == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Article editor unavailable right now.'),
                  ),
                );
                return;
              }
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => BlogEditorScreen.create(
                    repository: repository,
                    currentUsername: currentUsername,
                  ),
                ),
              );
            },
            child: const Text('Write Article'),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: UpdateSubmissionModal(
        updateRepository: updateRepository,
        currentUser: currentUser,
        fullScreen: true,
      ),
    );
  }
}
