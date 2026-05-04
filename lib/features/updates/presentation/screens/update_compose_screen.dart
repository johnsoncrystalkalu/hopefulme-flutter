import 'package:flutter/material.dart';
import 'package:hopefulme_flutter/app/theme/app_theme.dart';
import 'package:hopefulme_flutter/features/content/data/content_repository.dart';
import 'package:hopefulme_flutter/features/content/presentation/screens/blog_editor_screen.dart';
import 'package:hopefulme_flutter/features/auth/models/user.dart';
import 'package:hopefulme_flutter/features/updates/data/update_repository.dart';
import 'package:hopefulme_flutter/features/updates/presentation/widgets/update_submission_modal.dart';

class UpdateComposeScreen extends StatelessWidget {
  static const String openBlogsFeedSignal = 'open_blogs_feed';

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

  Future<void> _openArticleEditor(BuildContext context) async {
    final repository = contentRepository;
    if (repository == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Article editor unavailable right now.'),
          backgroundColor: context.appColors.surface,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final result = await Navigator.of(context).push<Object?>(
      MaterialPageRoute<Object?>(
        builder: (context) => BlogEditorScreen.create(
          repository: repository,
          currentUsername: currentUsername,
        ),
      ),
    );
    if (result != null && context.mounted) {
      Navigator.of(context).pop(openBlogsFeedSignal);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: colors.scaffold,
      appBar: AppBar(
        backgroundColor: colors.surface,
        surfaceTintColor: colors.surface,
        titleSpacing: 0,
        title: const Text('Create Post'),
        
      ),
      body: UpdateSubmissionModal(
        updateRepository: updateRepository,
        currentUser: currentUser,
        fullScreen: true,
      ),
    );
  }
}
