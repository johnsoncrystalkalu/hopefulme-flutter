import 'package:flutter/material.dart';
import 'package:hopefulme_flutter/app/theme/app_theme.dart';
import 'package:hopefulme_flutter/core/config/app_config.dart';
import 'package:hopefulme_flutter/core/presentation/screens/web_page_screen.dart';

class AuthPageFooter extends StatelessWidget {
  const AuthPageFooter({super.key});

  Future<void> _openPage(
    BuildContext context, {
    required String title,
    required String path,
  }) {
    final base = AppConfig.fromEnvironment().webBaseUrl;
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => WebPageScreen(
          title: title,
          url: '$base$path',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    Widget link(String label, String path) {
      return InkWell(
        onTap: () => _openPage(context, title: label, path: path),
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Text(
            label,
            style: TextStyle(
              color: colors.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }

    return Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 6,
        runSpacing: 2,
        children: [
          link('About', '/about'),
          Text('•', style: TextStyle(color: colors.textMuted.withValues(alpha: 0.7))),
          link('Contact', '/contact'),
          Text('•', style: TextStyle(color: colors.textMuted.withValues(alpha: 0.7))),
          link('Terms', '/terms'),
        ],
      ),
    );
  }
}
