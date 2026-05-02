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

  void _openArticleEditor(BuildContext context) {
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
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => BlogEditorScreen.create(
          repository: repository,
          currentUsername: currentUsername,
        ),
      ),
    );
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
        actions: [
          // "Write Article" as a contained pill — visually distinct from
          // a plain TextButton but not as heavy as a FilledButton
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () => _openArticleEditor(context),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: colors.accentSoft,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: colors.brand.withValues(alpha: 0.20),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.edit_note_rounded,
                      size: 16,
                      color: colors.brand,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Write Article',
                      style: TextStyle(
                        color: colors.brand,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
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