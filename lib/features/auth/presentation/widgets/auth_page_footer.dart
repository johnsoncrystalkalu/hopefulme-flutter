import 'package:flutter/material.dart';
import 'package:hopefulme_flutter/app/theme/app_theme.dart';
import 'package:hopefulme_flutter/core/config/app_config.dart';
import 'package:hopefulme_flutter/core/presentation/screens/web_page_screen.dart';
import 'package:hopefulme_flutter/features/auth/presentation/screens/login_screen.dart';
import 'package:hopefulme_flutter/features/auth/presentation/screens/register_screen.dart';

class AuthPageFooter extends StatelessWidget {
  const AuthPageFooter({super.key});

  Future<bool> _handleInternalLinkTap(BuildContext context, Uri uri) async {
    final rawSegments = uri.pathSegments
        .where((segment) => segment.trim().isNotEmpty)
        .map((segment) => segment.trim().toLowerCase())
        .toList(growable: false);

    final segments = rawSegments.isNotEmpty && rawSegments.first == 'app'
        ? rawSegments.skip(1).toList(growable: false)
        : rawSegments;

    if (segments.isEmpty) {
      return false;
    }

    final head = segments.first;
    final navigator = Navigator.of(context);

    if (head == 'login') {
      navigator.pushNamedAndRemoveUntil(LoginScreen.routeName, (_) => false);
      return true;
    }

    if (head == 'register') {
      navigator.pushNamedAndRemoveUntil(RegisterScreen.routeName, (_) => false);
      return true;
    }

    return false;
  }

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
          onInternalLinkTap: (uri) => _handleInternalLinkTap(context, uri),
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
          Text(
            '•',
            style: TextStyle(color: colors.textMuted.withValues(alpha: 0.7)),
          ),
          link('Contact', '/contact'),
          Text(
            '•',
            style: TextStyle(color: colors.textMuted.withValues(alpha: 0.7)),
          ),
          link('Terms', '/terms'),
        ],
      ),
    );
  }
}
