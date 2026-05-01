import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';
import 'package:hopefulme_flutter/app/theme/app_theme.dart';
import 'package:hopefulme_flutter/app/theme/theme_controller.dart';
import 'package:hopefulme_flutter/core/widgets/app_avatar.dart';
import 'package:hopefulme_flutter/features/auth/models/user.dart';

class MenuScreen extends StatelessWidget {
  const MenuScreen({
    required this.user,
    required this.activeItemLabel,
    required this.themeController,
    required this.onSearchTap,
    required this.onHomeTap,
    required this.onProfileTap,
    required this.onPostsTap,
    required this.onBlogsTap,
    required this.onActivitiesTap,
    required this.onGroupsTap,
    required this.onLibraryTap,
    required this.onFlyerTemplatesTap,
    required this.onInspirationsTap,
    required this.onPlayGamesTap,
    required this.onStoreTap,
    required this.onOtherMenusTap,
    required this.onAdvertiseTap,
    required this.onVolunteerTap,
    required this.onTvTap,
    required this.onOutreachTap,
    required this.onAdminTap,
    required this.onMeetNewFriendsTap,
    required this.onSettingsTap,
    required this.onLogoutTap,
    super.key,
  });

  final User? user;
  final String activeItemLabel;
  final ThemeController themeController;
  final Future<void> Function() onSearchTap;
  final Future<void> Function() onHomeTap;
  final Future<void> Function() onProfileTap;
  final Future<void> Function() onPostsTap;
  final Future<void> Function() onBlogsTap;
  final Future<void> Function() onActivitiesTap;
  final Future<void> Function() onGroupsTap;
  final Future<void> Function() onLibraryTap;
  final Future<void> Function() onFlyerTemplatesTap;
  final Future<void> Function() onInspirationsTap;
  final Future<void> Function() onPlayGamesTap;
  final Future<void> Function() onStoreTap;
  final Future<void> Function() onOtherMenusTap;
  final Future<void> Function() onAdvertiseTap;
  final Future<void> Function() onVolunteerTap;
  final Future<void> Function() onTvTap;
  final Future<void> Function() onOutreachTap;
  final Future<void> Function() onAdminTap;
  final Future<void> Function() onMeetNewFriendsTap;
  final Future<void> Function() onSettingsTap;
  final Future<bool> Function() onLogoutTap;

  Future<void> _runAction(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    Navigator.of(context).pop();
    await action();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final displayName = user?.displayName ?? 'HopefulMe User';
    final username = '@${user?.username ?? 'hopefulme'}';
    final showAdminPanel = user?.rank.trim().isNotEmpty ?? false;
    final isDark = themeController.effectiveIsDark(Theme.of(context).brightness);
    final accountThemeLabel = isDark
        ? 'Switch to Light Mode'
        : 'Switch to Dark Mode';

    return Scaffold(
      backgroundColor: colors.scaffold,
      appBar: AppBar(title: const Text('Menu')),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                children: [
                  InkWell(
                    onTap: () => _runAction(context, onProfileTap),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: colors.borderStrong),
                      ),
                      child: Row(
                        children: [
                          AppAvatar(
                            imageUrl: user?.photoUrl ?? '',
                            label: displayName,
                            radius: 22,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: colors.textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  username,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: colors.textMuted,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: colors.icon,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _MenuSection(
                    title: 'Community',
                    items: [
                      _MenuItemData(HeroIcons.home, 'Home', () => _runAction(context, onHomeTap), selected: activeItemLabel == 'Home'),
                      _MenuItemData(HeroIcons.newspaper, 'Post & News', () => _runAction(context, onPostsTap), selected: activeItemLabel == 'Post & News'),
                      _MenuItemData(HeroIcons.sparkles, 'Activities', () => _runAction(context, onActivitiesTap), selected: activeItemLabel == 'Activities'),
                      _MenuItemData(HeroIcons.users, 'Group Chats', () => _runAction(context, onGroupsTap), selected: activeItemLabel == 'Group Chats'),
                      _MenuItemData(HeroIcons.userPlus, 'Meet New Friends', () => _runAction(context, onMeetNewFriendsTap), selected: activeItemLabel == 'Meet New Friends'),
                    ],
                  ),
                  _MenuSection(
                    title: 'Resources',
                    items: [
                      _MenuItemData(HeroIcons.bookOpen, 'Library', () => _runAction(context, onLibraryTap), selected: activeItemLabel == 'Library'),
                      _MenuItemData(HeroIcons.rectangleGroup, 'Flyer Templates', () => _runAction(context, onFlyerTemplatesTap), selected: activeItemLabel == 'Flyer Templates'),
                      _MenuItemData(HeroIcons.inboxStack, 'Inspiration Inbox', () => _runAction(context, onInspirationsTap), selected: activeItemLabel == 'Inspiration Inbox'),
                    ],
                  ),
                  _MenuSection(
                    title: 'Explore',
                    items: [
                      _MenuItemData(HeroIcons.magnifyingGlass, 'Search', () => _runAction(context, onSearchTap), selected: activeItemLabel == 'Search'),
                      _MenuItemData(HeroIcons.play, 'Play Games', () => _runAction(context, onPlayGamesTap), selected: activeItemLabel == 'Play Games'),
                      _MenuItemData(HeroIcons.shoppingBag, 'Store', () => _runAction(context, onStoreTap), selected: activeItemLabel == 'Store'),
                      _MenuItemData(HeroIcons.squares2x2, 'Other Menus', () => _runAction(context, onOtherMenusTap), selected: activeItemLabel == 'Other Menus'),
                    ],
                  ),
                  _MenuSection(
                    title: 'Get Involved',
                    items: [
                      _MenuItemData(HeroIcons.megaphone, 'Advertise', () => _runAction(context, onAdvertiseTap), selected: activeItemLabel == 'Advertise'),
                      _MenuItemData(HeroIcons.handRaised, 'Volunteer', () => _runAction(context, onVolunteerTap), selected: activeItemLabel == 'Volunteer'),
                      _MenuItemData(HeroIcons.videoCamera, 'Hope TV', () => _runAction(context, onTvTap), selected: activeItemLabel == 'Hope TV'),
                      _MenuItemData(HeroIcons.globeAlt, 'Outreach', () => _runAction(context, onOutreachTap), selected: activeItemLabel == 'Outreach'),
                    ],
                  ),
                  _MenuSection(
                    title: 'Account',
                    items: [
                      _MenuItemData(HeroIcons.cog6Tooth, 'Settings', () => _runAction(context, onSettingsTap), selected: activeItemLabel == 'Settings'),
                      _MenuItemData(HeroIcons.moon, accountThemeLabel, () async {
                        await themeController.cycleThemeMode();
                      }),
                    ],
                  ),
                  if (showAdminPanel)
                    _MenuSection(
                      title: 'Admin',
                      items: [
                        _MenuItemData(HeroIcons.shieldCheck, 'Admin', () => _runAction(context, onAdminTap), selected: activeItemLabel == 'Admin'),
                      ],
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final didLogout = await onLogoutTap();
                    if (!didLogout && context.mounted) {
                      return;
                    }
                  },
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Log out'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuSection extends StatelessWidget {
  const _MenuSection({required this.title, required this.items});

  final String title;
  final List<_MenuItemData> items;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              title,
              style: TextStyle(
                color: colors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
          ),
          ...items.map((item) => _MenuItem(item: item)),
        ],
      ),
    );
  }
}

class _MenuItemData {
  const _MenuItemData(this.icon, this.label, this.onTap, {this.selected = false});

  final HeroIcons icon;
  final String label;
  final Future<void> Function() onTap;
  final bool selected;
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({required this.item});

  final _MenuItemData item;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: item.selected
            ? colors.brand.withValues(alpha: 0.12)
            : colors.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => item.onTap(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                HeroIcon(
                  item.icon,
                  size: 18,
                  color: item.selected ? colors.brand : colors.icon,
                  style: item.selected ? HeroIconStyle.solid : HeroIconStyle.outline,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: item.selected ? colors.brand : colors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
