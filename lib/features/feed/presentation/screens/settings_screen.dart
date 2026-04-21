import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hopefulme_flutter/app/theme/app_theme.dart';
import 'package:hopefulme_flutter/app/theme/theme_controller.dart';
import 'package:hopefulme_flutter/core/config/app_config.dart';
import 'package:hopefulme_flutter/core/presentation/screens/web_page_screen.dart';
import 'package:hopefulme_flutter/core/widgets/app_toast.dart';
import 'package:hopefulme_flutter/features/auth/data/auth_repository.dart';
import 'package:hopefulme_flutter/features/profile/data/profile_repository.dart';
import 'package:hopefulme_flutter/features/profile/presentation/screens/edit_profile_media_screen.dart';
import 'package:hopefulme_flutter/features/profile/presentation/screens/edit_profile_screen.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    required this.username,
    required this.authRepository,
    required this.profileRepository,
    required this.themeController,
    required this.onLogout,
    required this.onCheckForUpdates,
    super.key,
  });

  final String username;
  final AuthRepository authRepository;
  final ProfileRepository profileRepository;
  final ThemeController themeController;
  final Future<void> Function() onLogout;
  final Future<void> Function() onCheckForUpdates;

  static const _officialWebsiteUrl = 'https://www.ahopefulme.com';
  static const _inviteMessage =
      "I am inviting to join me at Hopefulme, let's inspire the world around us - www.ahopefulme.com/app";

  Future<void> _shareInviteLink(BuildContext context) async {
    try {
      await Share.share(_inviteMessage, subject: 'Join me on HopefulMe');
    } catch (_) {
      await Clipboard.setData(const ClipboardData(text: _inviteMessage));
      if (!context.mounted) {
        return;
      }
      AppToast.info(context, 'Sharing unavailable. Invite message copied.');
    }
  }

  Future<void> _copyOfficialWebsiteLink(BuildContext context) async {
    await Clipboard.setData(const ClipboardData(text: _officialWebsiteUrl));
    if (!context.mounted) {
      return;
    }
    AppToast.success(context, 'Official website link copied.');
  }

  Future<void> _openSignedWebPage(
    BuildContext context, {
    required String title,
    required String rawUrl,
  }) async {
    var targetUrl = rawUrl;
    try {
      final bridged = await authRepository.createWebSessionUrl(rawUrl);
      if (bridged.trim().isNotEmpty) {
        targetUrl = bridged.trim();
      }
    } catch (_) {
      // Fall back to direct URL if signing fails.
    }

    if (!context.mounted) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => WebPageScreen(title: title, url: targetUrl),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final webBaseUrl = AppConfig.fromEnvironment().webBaseUrl;

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
            icon: Icons.logout_rounded,
            title: 'Log Out',
            subtitle: 'Sign out of your HopefulMe account.',
            onTap: () async {
              await onLogout();
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            },
          ),
          const SizedBox(height: 14),
          const _SettingsSectionTitle('Appearance'),
          AnimatedBuilder(
            animation: themeController,
            builder: (context, _) {
              return _ThemeToggleTile(
                isDarkMode: themeController.isDarkMode,
                onChanged: (value) => themeController.setThemeMode(
                  value ? ThemeMode.dark : ThemeMode.light,
                ),
              );
            },
          ),
          const SizedBox(height: 14),
          const _SettingsSectionTitle('Community'),
          _SettingsTile(
            icon: Icons.ios_share_outlined,
            title: 'Invite Friends',
            subtitle: 'Share HopefulMe on WhatsApp, mail, and more.',
            onTap: () => _shareInviteLink(context),
          ),
          const SizedBox(height: 14),
          const _SettingsSectionTitle('Official'),
          _SettingsTile(
            icon: Icons.language_rounded,
            title: 'Official Website',
            subtitle: 'www.ahopefulme.com',
            onTap: () => _copyOfficialWebsiteLink(context),
          ),
          const SizedBox(height: 14),
          const _SettingsSectionTitle('Support'),
          _SettingsTile(
            icon: Icons.system_update_alt_rounded,
            title: 'Check for Updates',
            subtitle: 'Check if a new app version is available.',
            onTap: () async {
              AppToast.success(context, 'Checking for updates...');
              await onCheckForUpdates();
            },
          ),
          _SettingsTile(
            icon: Icons.info_outline_rounded,
            title: 'About',
            subtitle: 'Learn more about HopefulMe.',
            onTap: () => _openSignedWebPage(
              context,
              title: 'About',
              rawUrl: 'https://www.ahopefulme.com/about',
            ),
          ),
          _SettingsTile(
            icon: Icons.mail_outline_rounded,
            title: 'Contact',
            subtitle: 'Reach the HopefulMe team.',
            onTap: () => _openSignedWebPage(
              context,
              title: 'Contact',
              rawUrl: 'https://www.ahopefulme.com/contact',
            ),
          ),
          _SettingsTile(
            icon: Icons.help_outline_rounded,
            title: 'How It Works',
            subtitle: 'Learn how HopefulMe App works.',
            onTap: () => _openSignedWebPage(
              context,
              title: 'How It Works',
              rawUrl: '$webBaseUrl/how-it-works',
            ),
          ),
          const SizedBox(height: 14),
          const _SettingsSectionTitle('Legal'),
          _SettingsTile(
            icon: Icons.description_outlined,
            title: 'Terms',
            subtitle: 'Read the terms of service.',
            onTap: () => _openSignedWebPage(
              context,
              title: 'Terms',
              rawUrl: 'https://www.ahopefulme.com/terms',
            ),
          ),
          _SettingsTile(
            icon: Icons.verified_user_outlined,
            title: 'Privacy',
            subtitle: 'Read the privacy policy.',
            onTap: () => _openSignedWebPage(
              context,
              title: 'Privacy Policy',
              rawUrl: 'https://www.ahopefulme.com/privacy',
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
        trailing: Icon(Icons.chevron_right_rounded, color: colors.textMuted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }
}

class _ThemeToggleTile extends StatelessWidget {
  const _ThemeToggleTile({required this.isDarkMode, required this.onChanged});

  final bool isDarkMode;
  final ValueChanged<bool> onChanged;

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
      child: SwitchListTile(
        value: isDarkMode,
        onChanged: onChanged,
        secondary: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: colors.accentSoft,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            isDarkMode ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
            color: colors.brand,
            size: 20,
          ),
        ),
        title: Text(
          'Dark Theme',
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          isDarkMode ? 'Dark mode is on.' : 'Light mode is on.',
          style: TextStyle(
            color: colors.textMuted,
            fontSize: 12.2,
            fontWeight: FontWeight.w500,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
            : 'v${snapshot.data!.version}';

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
            if (version.isNotEmpty)
              Text(
                version,
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
