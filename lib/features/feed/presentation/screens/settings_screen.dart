import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hopefulme_flutter/app/theme/app_theme.dart';
import 'package:hopefulme_flutter/core/config/app_config.dart';
import 'package:hopefulme_flutter/core/presentation/screens/web_page_screen.dart';
import 'package:hopefulme_flutter/core/widgets/app_toast.dart';
import 'package:hopefulme_flutter/features/profile/data/profile_repository.dart';
import 'package:hopefulme_flutter/features/profile/presentation/screens/edit_profile_media_screen.dart';
import 'package:hopefulme_flutter/features/profile/presentation/screens/edit_profile_screen.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    required this.username,
    required this.profileRepository,
    super.key,
  });

  final String username;
  final ProfileRepository profileRepository;

  static const _playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.ahopefulme.app';
  static const _facebookUrl = 'https://www.facebook.com/share/1CT9MKaSbU/';

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

  Future<void> _openExternalUrl(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      AppToast.error(context, 'Unable to open this link right now.');
      return;
    }

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      AppToast.error(context, 'Unable to open this link right now.');
    }
  }

  Future<void> _copyInviteLink(BuildContext context) async {
    await Clipboard.setData(const ClipboardData(text: _playStoreUrl));
    if (!context.mounted) {
      return;
    }
    AppToast.success(context, 'Play Store link copied.');
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
          _SettingsHero(username: username),
          const SizedBox(height: 18),
          const _SettingsSectionTitle('Account'),
          _SettingsTile(
            icon: Icons.person_outline_rounded,
            title: 'Edit Profile',
            subtitle: 'Update your name, bio, email and preferences.',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => EditProfileScreen(
                  username: username,
                  repository: profileRepository,
                ),
              ),
            ),
          ),
          _SettingsTile(
            icon: Icons.photo_camera_outlined,
            title: 'Change Photo',
            subtitle: 'Update your profile and cover photo.',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => EditProfileMediaScreen(
                  username: username,
                  repository: profileRepository,
                ),
              ),
            ),
          ),
          _SettingsTile(
            icon: Icons.notifications_outlined,
            title: 'Edit Notifications',
            subtitle: 'Manage your email and account notification preferences.',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => EditProfileScreen(
                  username: username,
                  repository: profileRepository,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          const _SettingsSectionTitle('Community'),
          _SettingsTile(
            icon: Icons.share_outlined,
            title: 'Invite Friends',
            subtitle: 'Copy the Play Store link and share HopefulMe.',
            onTap: () => _copyInviteLink(context),
          ),
          const _InfoTile(
            icon: Icons.groups_2_outlined,
            title: 'The LionessHub',
            subtitle: 'A women-focused HopefulMe community space.',
          ),
          const _InfoTile(
            icon: Icons.group_outlined,
            title: 'Complete Man',
            subtitle: 'A brotherhood and growth-focused HopefulMe community.',
          ),
          const SizedBox(height: 14),
          const _SettingsSectionTitle('Follow HopefulMe'),
          _SettingsTile(
            icon: Icons.language_rounded,
            title: 'Official Website',
            subtitle: 'Visit HopefulMe online.',
            onTap: () => _openPage(context, title: 'HopefulMe', path: '/'),
          ),
          _SettingsTile(
            icon: Icons.facebook_rounded,
            title: 'Facebook',
            subtitle: 'Follow HopefulMe on Facebook.',
            onTap: () => _openExternalUrl(context, _facebookUrl),
          ),
          _SettingsTile(
            icon: Icons.campaign_outlined,
            title: 'Outreach',
            subtitle: 'See HopefulMe outreach and community impact.',
            onTap: () => _openPage(
              context,
              title: 'Outreach',
              path: '/outreach',
            ),
          ),
          const SizedBox(height: 14),
          const _SettingsSectionTitle('Support'),
          _SettingsTile(
            icon: Icons.info_outline_rounded,
            title: 'About',
            subtitle: 'Learn more about HopefulMe.',
            onTap: () => _openPage(context, title: 'About', path: '/about'),
          ),
          _SettingsTile(
            icon: Icons.mail_outline_rounded,
            title: 'Contact',
            subtitle: 'Reach the HopefulMe team.',
            onTap: () => _openPage(context, title: 'Contact', path: '/contact'),
          ),
          const SizedBox(height: 14),
          const _SettingsSectionTitle('Legal'),
          _SettingsTile(
            icon: Icons.description_outlined,
            title: 'Terms',
            subtitle: 'Read the terms of service.',
            onTap: () => _openPage(context, title: 'Terms', path: '/terms'),
          ),
          _SettingsTile(
            icon: Icons.verified_user_outlined,
            title: 'Privacy',
            subtitle: 'Read the privacy policy.',
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

class _SettingsHero extends StatelessWidget {
  const _SettingsHero({required this.username});

  final String username;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.borderStrong),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: colors.accentSoft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.settings_outlined,
              color: colors.brand,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Personal Settings',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '@$username',
                  style: TextStyle(
                    color: colors.textMuted,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
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
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
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
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: colors.accentSoft,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: colors.brand, size: 20),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Text(
            subtitle,
            style: TextStyle(
              color: colors.textMuted,
              fontSize: 12.2,
              fontWeight: FontWeight.w500,
              height: 1.35,
            ),
          ),
        ),
        trailing: Icon(
          Icons.chevron_right_rounded,
          color: colors.textMuted,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.borderStrong),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colors.accentSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: colors.brand, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: colors.textMuted,
                    fontSize: 12.2,
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
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
