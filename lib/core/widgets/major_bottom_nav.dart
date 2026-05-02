import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';
import 'package:hopefulme_flutter/app/theme/app_theme.dart';

class MajorBottomNav extends StatelessWidget {
  const MajorBottomNav({
    required this.selectedIndex,
    required this.onSelected,
    this.unreadGroupsCount = 0,
    super.key,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final int unreadGroupsCount;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isCompactBottomNav = MediaQuery.sizeOf(context).width < 360;
    final navIconSize = isCompactBottomNav ? 22.0 : 24.0;
    final createButtonSize = isCompactBottomNav ? 48.0 : 52.0;
    final createIconSize = isCompactBottomNav ? 26.0 : 28.0;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedNavColor = colors.brand;
    final unselectedNavColor = isDark
        ? colors.textPrimary.withValues(alpha: 0.82)
        : colors.textPrimary.withValues(alpha: 0.86);
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(0, 0, 0, 0),
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface.withValues(alpha: 0.97),
          border: Border(
            top: BorderSide(color: colors.border.withValues(alpha: 0.95)),
          ),
          boxShadow: [
            BoxShadow(
              color: colors.shadow.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, -1),
            ),
          ],
        ),
        child: NavigationBar(
          height: isCompactBottomNav ? 70 : 76,
          backgroundColor: Colors.transparent,
          indicatorColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((states) {
            final selected = states.contains(WidgetState.selected);
            return TextStyle(
              color: selected ? selectedNavColor : unselectedNavColor,
              fontSize: isCompactBottomNav ? 11.0 : 11.5,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
            );
          }),
          selectedIndex: selectedIndex,
          onDestinationSelected: onSelected,
          destinations: [
            NavigationDestination(
              icon: HeroIcon(
                HeroIcons.home,
                size: navIconSize,
                color: unselectedNavColor,
              ),
              selectedIcon: HeroIcon(
                HeroIcons.home,
                size: navIconSize,
                color: selectedNavColor,
                style: HeroIconStyle.solid,
              ),
              label: 'Home',
            ),
            NavigationDestination(
              icon: HeroIcon(
                HeroIcons.magnifyingGlass,
                size: navIconSize,
                color: unselectedNavColor,
              ),
              selectedIcon: HeroIcon(
                HeroIcons.magnifyingGlass,
                size: navIconSize,
                color: selectedNavColor,
                style: HeroIconStyle.solid,
              ),
              label: 'Search',
            ),
            NavigationDestination(
              icon: Container(
                width: createButtonSize,
                height: createButtonSize,
                decoration: BoxDecoration(
                  color: colors.brand,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.add_rounded,
                  color: Colors.white,
                  size: createIconSize,
                ),
              ),
              label: '',
            ),
            NavigationDestination(
              icon: _BottomNavBadgeIcon(
                icon: HeroIcons.users,
                count: unreadGroupsCount,
                dotOnly: true,
                iconSize: navIconSize,
                boxSize: isCompactBottomNav ? 28 : 30,
                iconColor: unselectedNavColor,
              ),
              selectedIcon: _BottomNavBadgeIcon(
                icon: HeroIcons.users,
                count: unreadGroupsCount,
                dotOnly: true,
                solid: true,
                iconSize: navIconSize,
                boxSize: isCompactBottomNav ? 28 : 30,
                iconColor: selectedNavColor,
              ),
              label: 'Groups',
            ),
            NavigationDestination(
              icon: HeroIcon(
                HeroIcons.userPlus,
                size: navIconSize,
                color: unselectedNavColor,
              ),
              selectedIcon: HeroIcon(
                HeroIcons.userPlus,
                size: navIconSize,
                color: selectedNavColor,
                style: HeroIconStyle.solid,
              ),
              label: 'Connect',
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomNavBadgeIcon extends StatelessWidget {
  const _BottomNavBadgeIcon({
    required this.icon,
    required this.count,
    this.dotOnly = false,
    this.solid = false,
    this.iconSize = 24,
    this.boxSize = 30,
    required this.iconColor,
  });

  final HeroIcons icon;
  final int count;
  final bool dotOnly;
  final bool solid;
  final double iconSize;
  final double boxSize;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        SizedBox(
          width: boxSize,
          height: boxSize,
          child: HeroIcon(
            icon,
            size: iconSize,
            color: iconColor,
            style: solid ? HeroIconStyle.solid : HeroIconStyle.outline,
          ),
        ),
        if (count > 0)
          Positioned(
            top: -2,
            right: -2,
            child: Container(
              width: dotOnly ? 10 : null,
              height: dotOnly ? 10 : null,
              padding: dotOnly
                  ? EdgeInsets.zero
                  : const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444),
                borderRadius: BorderRadius.circular(999),
                border: dotOnly
                    ? Border.all(color: colors.surface, width: 1.4)
                    : null,
              ),
              child: dotOnly
                  ? null
                  : Text(
                      count > 9 ? '9+' : '$count',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
          ),
      ],
    );
  }
}
