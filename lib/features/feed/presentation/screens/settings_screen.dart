import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hopefulme_flutter/app/theme/app_theme.dart';
import 'package:hopefulme_flutter/app/theme/theme_controller.dart';
import 'package:hopefulme_flutter/core/config/app_config.dart';
import 'package:hopefulme_flutter/core/presentation/screens/web_page_screen.dart';
import 'package:hopefulme_flutter/core/widgets/app_toast.dart';
import 'package:hopefulme_flutter/core/widgets/app_avatar.dart';
import 'package:hopefulme_flutter/core/widgets/verified_name_text.dart';
import 'package:hopefulme_flutter/features/auth/models/user.dart';
import 'package:hopefulme_flutter/features/auth/data/auth_repository.dart';
import 'package:hopefulme_flutter/features/profile/data/profile_repository.dart';
import 'package:hopefulme_flutter/features/profile/presentation/screens/account_settings_screen.dart';
import 'package:hopefulme_flutter/features/profile/presentation/screens/edit_profile_media_screen.dart';
import 'package:hopefulme_flutter/features/profile/presentation/screens/edit_profile_screen.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    required this.username,
    required this.isVerified,
    this.currentUser,
    required this.authRepository,
    required this.profileRepository,
    required this.themeController,
    required this.onLogout,
    required this.onCheckForUpdates,
    this.onInternalLinkTap,
    super.key,
  });

  final String username;
  final bool isVerified;
  final User? currentUser;
  final AuthRepository authRepository;
  final ProfileRepository profileRepository;
  final ThemeController themeController;
  final Future<bool> Function() onLogout;
  final Future<void> Function() onCheckForUpdates;
  final Future<bool> Function(Uri uri)? onInternalLinkTap;

  static const _officialWebsiteUrl = 'https://www.ahopefulme.com';
  static const _inviteMessage =
      "I am inviting to join me at Hopefulme, let's inspire the world around us - www.ahopefulme.com/app";

  Future<void> _shareInviteLink(BuildContext context) async {
    try {
      await Share.share(_inviteMessage, subject: 'Join me on HopefulMe');
    } catch (_) {
      await Clipboard.setData(const ClipboardData(text: _inviteMessage));
      if (!context.mounted) return;
      AppToast.info(context, 'Sharing unavailable. Invite message copied.');
    }
  }

  Future<void> _copyOfficialWebsiteLink(BuildContext context) async {
    await Clipboard.setData(const ClipboardData(text: _officialWebsiteUrl));
    if (!context.mounted) return;
    AppToast.success(context, 'Official website link copied.');
  }

  Future<void> _openSignedWebPage(
    BuildContext context, {
    required String title,
    required String rawUrl,
    bool useSignedSession = false,
    bool enableInternalLinkRouting = true,
  }) async {
    var targetUrl = rawUrl;
    if (useSignedSession) {
      try {
        final bridged = await authRepository.createWebSessionUrl(rawUrl);
        if (bridged.trim().isNotEmpty) targetUrl = bridged.trim();
      } catch (_) {}
    }

    if (!context.mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => WebPageScreen(
          title: title,
          url: targetUrl,
          onInternalLinkTap:
              enableInternalLinkRouting ? onInternalLinkTap : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final webBaseUrl = AppConfig.fromEnvironment().webBaseUrl;
    final safeUsername = username.trim().replaceFirst('@', '');
    final displayName = currentUser?.displayName.trim() ?? '';

    return Scaffold(
      backgroundColor: colors.scaffold,
      appBar: AppBar(
        backgroundColor: colors.scaffold,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        title: Text(
          'Settings',
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: [
          _SettingsHeader(
            username: safeUsername,
            displayName: displayName,
            photoUrl: currentUser?.photoUrl ?? '',
            isVerified: isVerified,
          ),
          const SizedBox(height: 28),
          _SettingsGroup(
            title: 'Account',
            children: [
              _SettingsTile(
                icon: Icons.person_outline_rounded,
                title: 'Edit Profile',
                subtitle: 'Update your profile information',
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
                subtitle: 'Update your profile and cover photo',
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
                icon: Icons.lock_outline_rounded,
                title: 'Account Settings',
                subtitle: 'Change password and preferences',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) => AccountSettingsScreen(
                      username: username,
                      repository: profileRepository,
                    ),
                  ),
                ),
              ),
              _SettingsTile(
                icon: Icons.logout_rounded,
                title: 'Log Out',
                subtitle: 'Sign out of your HopefulMe account',
                onTap: () async {
                  final didLogout = await onLogout();
                  if (!context.mounted) return;
                  if (!didLogout) {
                    AppToast.error(context, 'Unable to log out right now.');
                    return;
                  }
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  }
                },
                emphasizeDanger: true,
              ),
            ],
          ),
          const SizedBox(height: 20),
          _SettingsGroup(
            title: 'Appearance',
            children: [
              AnimatedBuilder(
                animation: themeController,
                builder: (context, _) {
                  return _ThemeModeTile(
                    mode: themeController.themeMode,
                    onChanged: themeController.setThemeMode,
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          _SettingsGroup(
            title: 'Community',
            children: [
              _SettingsTile(
                icon: Icons.ios_share_outlined,
                title: 'Invite Friends',
                subtitle: 'Share HopefulMe with friends and loved ones',
                onTap: () => _shareInviteLink(context),
              ),
              _SettingsTile(
                icon: Icons.language_rounded,
                title: 'Official Website',
                subtitle: 'www.ahopefulme.com',
                onTap: () => _copyOfficialWebsiteLink(context),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _SettingsGroup(
            title: 'Support',
            children: [
              _SettingsTile(
                icon: Icons.system_update_alt_rounded,
                title: 'Check for Updates',
                subtitle: 'Check if a new app version is available',
                onTap: () async {
                  AppToast.success(context, 'Checking for updates...');
                  await onCheckForUpdates();
                },
              ),
              _SettingsTile(
                icon: Icons.info_outline_rounded,
                title: 'About',
                subtitle: 'Learn more about HopefulMe',
                onTap: () => _openSignedWebPage(
                  context,
                  title: 'About',
                  rawUrl: 'https://www.ahopefulme.com/about',
                ),
              ),
              _SettingsTile(
                icon: Icons.mail_outline_rounded,
                title: 'Contact',
                subtitle: 'Reach the HopefulMe team',
                onTap: () => _openSignedWebPage(
                  context,
                  title: 'Contact',
                  rawUrl: 'https://www.ahopefulme.com/contact',
                ),
              ),
              _SettingsTile(
                icon: Icons.help_outline_rounded,
                title: 'How It Works',
                subtitle: 'Learn how HopefulMe App works',
                onTap: () => _openSignedWebPage(
                  context,
                  title: 'How It Works',
                  rawUrl: '$webBaseUrl/how-it-works',
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _SettingsGroup(
            title: 'Legal',
            children: [
              _SettingsTile(
                icon: Icons.description_outlined,
                title: 'Terms of Service',
                subtitle: 'Read the terms of service',
                onTap: () => _openSignedWebPage(
                  context,
                  title: 'Terms',
                  rawUrl: 'https://www.ahopefulme.com/terms',
                ),
              ),
              _SettingsTile(
                icon: Icons.verified_user_outlined,
                title: 'Privacy Policy',
                subtitle: 'Read the privacy policy',
                onTap: () => _openSignedWebPage(
                  context,
                  title: 'Privacy Policy',
                  rawUrl: 'https://www.ahopefulme.com/privacy',
                ),
              ),
            ],
          ),
          const SizedBox(height: 36),
          const _SettingsFooter(),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Header
// ─────────────────────────────────────────────

class _SettingsHeader extends StatelessWidget {
  const _SettingsHeader({
    required this.username,
    required this.displayName,
    required this.photoUrl,
    required this.isVerified,
  });

  final String username;
  final String displayName;
  final String photoUrl;
  final bool isVerified;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final handle = username.trim().isEmpty ? 'hopefulme' : username;
    final resolvedName =
        displayName.trim().isEmpty ? handle : displayName.trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.borderStrong, width: 1),
      ),
      child: Row(
        children: [
          // Avatar with subtle ring
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: colors.brand.withValues(alpha: 0.25),
                width: 2.5,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: AppAvatar(
                imageUrl: photoUrl,
                label: resolvedName,
                radius: 22,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                VerifiedNameText(
                  name: resolvedName,
                  verified: isVerified,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '@$handle',
                  style: TextStyle(
                    color: colors.textMuted,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          // Subtle "view profile" caret
          Icon(
            Icons.chevron_right_rounded,
            color: colors.textMuted.withValues(alpha: 0.5),
            size: 20,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Section group
// ─────────────────────────────────────────────

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final visibleChildren =
        children.whereType<Widget>().toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SettingsSectionTitle(title),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Container(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: colors.borderStrong, width: 1),
            ),
            child: Column(
              children: List.generate(visibleChildren.length, (index) {
                final isLast = index == visibleChildren.length - 1;
                return Column(
                  children: [
                    visibleChildren[index],
                    if (!isLast)
                      Divider(
                        height: 1,
                        thickness: 0.75,
                        indent: 68,
                        color: colors.border.withValues(alpha: 0.5),
                      ),
                  ],
                );
              }),
            ),
          ),
        ),
      ],
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
      padding: const EdgeInsets.only(left: 6),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: colors.textMuted.withValues(alpha: 0.75),
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Tile
// ─────────────────────────────────────────────

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.emphasizeDanger = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool emphasizeDanger;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final actionColor =
        emphasizeDanger ? colors.dangerText : colors.brand;
    final iconBg =
        emphasizeDanger ? colors.dangerSoft : colors.accentSoft;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(0),
        splashColor: actionColor.withValues(alpha: 0.06),
        highlightColor: actionColor.withValues(alpha: 0.03),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              // Icon container — slightly rounded square
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: actionColor, size: 19),
              ),
              const SizedBox(width: 14),
              // Text block
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: emphasizeDanger
                            ? colors.dangerText
                            : colors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: colors.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: colors.textMuted.withValues(alpha: 0.45),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Theme tile
// ─────────────────────────────────────────────

class _ThemeModeTile extends StatelessWidget {
  const _ThemeModeTile({
    required this.mode,
    required this.onChanged,
  });

  final ThemeMode mode;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    final icon = switch (mode) {
      ThemeMode.dark => Icons.dark_mode_outlined,
      ThemeMode.light => Icons.light_mode_outlined,
      ThemeMode.system => Icons.brightness_auto_outlined,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: colors.accentSoft,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: colors.brand, size: 19),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Theme',
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.1,
              ),
            ),
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<ThemeMode>(
              value: mode,
              style: TextStyle(
                color: colors.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              icon: Icon(
                Icons.expand_more_rounded,
                color: colors.textMuted.withValues(alpha: 0.6),
                size: 18,
              ),
              borderRadius: BorderRadius.circular(14),
              onChanged: (value) {
                if (value != null) onChanged(value);
              },
              items: const [
                DropdownMenuItem(
                    value: ThemeMode.system, child: Text('System')),
                DropdownMenuItem(
                    value: ThemeMode.light, child: Text('Light')),
                DropdownMenuItem(
                    value: ThemeMode.dark, child: Text('Dark')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Footer
// ─────────────────────────────────────────────

class _SettingsFooter extends StatelessWidget {
  const _SettingsFooter();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        final version =
            snapshot.data == null ? '' : 'v${snapshot.data!.version}';

        return Column(
          children: [
            // Small logo mark
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: colors.brand.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Padding(
                padding: const EdgeInsets.all(7),
                child: Image.asset(
                  'assets/images/app-icon.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              AppConfig.appName,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.1,
              ),
            ),
            const SizedBox(height: 4),
            if (version.isNotEmpty)
              Text(
                version,
                style: TextStyle(
                  color: colors.textMuted.withValues(alpha: 0.6),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        );
      },
    );
  }
}
