import 'package:flutter/material.dart';
import 'package:hopefulme_flutter/app/theme/app_theme.dart';
import 'package:hopefulme_flutter/core/config/app_config.dart';
import 'package:hopefulme_flutter/core/presentation/screens/web_page_screen.dart';
import 'package:package_info_plus/package_info_plus.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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

    return Scaffold(
      backgroundColor: colors.scaffold,
      appBar: AppBar(
        backgroundColor: colors.surface,
        surfaceTintColor: colors.surface,
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          const _SettingsSectionTitle('Support'),
          _SettingsTile(
            icon: Icons.info_outline_rounded,
            title: 'About',
            onTap: () => _openPage(context, title: 'About', path: '/about'),
          ),
          _SettingsTile(
            icon: Icons.help_outline_rounded,
            title: 'Help and Support',
            onTap: () => _openPage(
              context,
              title: 'Help and Support',
              path: '/contact',
            ),
          ),
          _SettingsTile(
            icon: Icons.mail_outline_rounded,
            title: 'Contact',
            onTap: () => _openPage(context, title: 'Contact', path: '/contact'),
          ),
          const SizedBox(height: 14),
          const _SettingsSectionTitle('Legal'),
          _SettingsTile(
            icon: Icons.description_outlined,
            title: 'Terms',
            onTap: () => _openPage(context, title: 'Terms', path: '/terms'),
          ),
          _SettingsTile(
            icon: Icons.verified_user_outlined,
            title: 'Privacy',
            onTap: () => _openPage(
              context,
              title: 'Privacy Policy',
              path: '/privacy',
            ),
          ),
          const SizedBox(height: 28),
          const _SettingsFooter(),
        ],
      ),
    );
  }
}

class _SettingsSectionTitle extends StatelessWidget {
  const _SettingsSectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          color: colors.textMuted,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.borderStrong),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: colors.textSecondary),
        title: Text(
          title,
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right_rounded,
          color: colors.textMuted,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      ),
    );
  }
}

class _SettingsFooter extends StatelessWidget {
  const _SettingsFooter();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        final version = snapshot.data == null
            ? ''
            : 'v${snapshot.data!.version} (${snapshot.data!.buildNumber})';

        return Column(
          children: [
            Text(
              AppConfig.appName,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              version.isEmpty ? 'Version' : version,
              style: TextStyle(
                color: colors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );
      },
    );
  }
}
