import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  static const brand = Color(0xFF3D5AFE);
  static const brandDark = Color(0xFF2742D6);
  static const accent = Color(0xFF7C3AED);
  static const danger = Color(0xFFFF4D6D);
  static const warning = Color(0xFFFFB020);
  static const success = Color(0xFF16A34A);
  static const scaffold = Color(0xFFF4F7FB);
  static const surface = Colors.white;
  static const border = Color(0xFFE2E8F0);
  static const borderSoft = Color(0xFFD6E0EE);
  static const text = Color(0xFF0F172A);
  static const muted = Color(0xFF64748B);
  static const faint = Color(0xFF94A3B8);
  static const softFill = Color(0xFFF8FAFC);
}

@immutable
class AppThemeColors extends ThemeExtension<AppThemeColors> {
  const AppThemeColors({
    required this.brand,
    required this.brandStrong,
    required this.accent,
    required this.scaffold,
    required this.surface,
    required this.surfaceMuted,
    required this.surfaceRaised,
    required this.border,
    required this.borderStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.icon,
    required this.sidebar,
    required this.sidebarSurface,
    required this.sidebarText,
    required this.sidebarMuted,
    required this.accentSoft,
    required this.accentSoftText,
    required this.unreadSurface,
    required this.warningSoft,
    required this.warningText,
    required this.dangerSoft,
    required this.dangerText,
    required this.success,
    required this.avatarPlaceholder,
    required this.heroFallback,
    required this.shadow,
  });

  final Color brand;
  final Color brandStrong;
  final Color accent;
  final Color scaffold;
  final Color surface;
  final Color surfaceMuted;
  final Color surfaceRaised;
  final Color border;
  final Color borderStrong;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color icon;
  final Color sidebar;
  final Color sidebarSurface;
  final Color sidebarText;
  final Color sidebarMuted;
  final Color accentSoft;
  final Color accentSoftText;
  final Color unreadSurface;
  final Color warningSoft;
  final Color warningText;
  final Color dangerSoft;
  final Color dangerText;
  final Color success;
  final Color avatarPlaceholder;
  final Color heroFallback;
  final Color shadow;

  LinearGradient get brandGradient => LinearGradient(colors: [brand, accent]);

  static const light = AppThemeColors(
    brand: AppColors.brand,
    brandStrong: AppColors.brandDark,
    accent: AppColors.accent,
    scaffold: Color(0xFFF4F7FB),
    surface: Colors.white,
    surfaceMuted: Color(0xFFF8FAFC),
    surfaceRaised: Color(0xFFF1F5F9),
    border: Color(0xFFE2E8F0),
    borderStrong: Color(0xFFD6E0EE),
    textPrimary: Color(0xFF0F172A),
    textSecondary: Color(0xFF334155),
    textMuted: Color(0xFF64748B),
    icon: Color(0xFF64748B),
    sidebar: Color(0xFF0A0F1E),
    sidebarSurface: Color.fromRGBO(255, 255, 255, 0.08),
    sidebarText: Color(0xFFDDE6F6),
    sidebarMuted: Color(0xFF94A3B8),
    accentSoft: Color(0xFFEEF1FF),
    accentSoftText: AppColors.brand,
    unreadSurface: Color(0xFFF5F8FF),
    warningSoft: Color(0xFFFFF8EC),
    warningText: AppColors.warning,
    dangerSoft: Color(0xFFFFF1F4),
    dangerText: AppColors.danger,
    success: AppColors.success,
    avatarPlaceholder: Color(0xFFEEF1FF),
    heroFallback: Color(0xFF0F172A),
    shadow: Color.fromRGBO(15, 23, 42, 0.06),
  );

  static const dark = AppThemeColors(
    brand: Color(0xFF7C93FF),
    brandStrong: Color(0xFF5876FF),
    accent: Color(0xFFA78BFA),
    scaffold: Color(0xFF0B1220),
    surface: Color(0xFF111A2E),
    surfaceMuted: Color(0xFF162238),
    surfaceRaised: Color(0xFF1A2842),
    border: Color(0xFF23324D),
    borderStrong: Color(0xFF31425F),
    textPrimary: Color(0xFFF8FAFC),
    textSecondary: Color(0xFFD7E0EE),
    textMuted: Color(0xFF9FB1C8),
    icon: Color(0xFFB7C4D7),
    sidebar: Color(0xFF070D18),
    sidebarSurface: Color.fromRGBO(255, 255, 255, 0.06),
    sidebarText: Color(0xFFF8FAFC),
    sidebarMuted: Color(0xFF8FA3BD),
    accentSoft: Color(0xFF1E2B4C),
    accentSoftText: Color(0xFFAFC0FF),
    unreadSurface: Color(0xFF15203A),
    warningSoft: Color(0xFF372B15),
    warningText: Color(0xFFFFC966),
    dangerSoft: Color(0xFF3A1720),
    dangerText: Color(0xFFFF94A8),
    success: Color(0xFF4ADE80),
    avatarPlaceholder: Color(0xFF1E2B4C),
    heroFallback: Color(0xFF050A14),
    shadow: Color.fromRGBO(2, 6, 23, 0.38),
  );

  @override
  AppThemeColors copyWith({
    Color? brand,
    Color? brandStrong,
    Color? accent,
    Color? scaffold,
    Color? surface,
    Color? surfaceMuted,
    Color? surfaceRaised,
    Color? border,
    Color? borderStrong,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? icon,
    Color? sidebar,
    Color? sidebarSurface,
    Color? sidebarText,
    Color? sidebarMuted,
    Color? accentSoft,
    Color? accentSoftText,
    Color? unreadSurface,
    Color? warningSoft,
    Color? warningText,
    Color? dangerSoft,
    Color? dangerText,
    Color? success,
    Color? avatarPlaceholder,
    Color? heroFallback,
    Color? shadow,
  }) {
    return AppThemeColors(
      brand: brand ?? this.brand,
      brandStrong: brandStrong ?? this.brandStrong,
      accent: accent ?? this.accent,
      scaffold: scaffold ?? this.scaffold,
      surface: surface ?? this.surface,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      icon: icon ?? this.icon,
      sidebar: sidebar ?? this.sidebar,
      sidebarSurface: sidebarSurface ?? this.sidebarSurface,
      sidebarText: sidebarText ?? this.sidebarText,
      sidebarMuted: sidebarMuted ?? this.sidebarMuted,
      accentSoft: accentSoft ?? this.accentSoft,
      accentSoftText: accentSoftText ?? this.accentSoftText,
      unreadSurface: unreadSurface ?? this.unreadSurface,
      warningSoft: warningSoft ?? this.warningSoft,
      warningText: warningText ?? this.warningText,
      dangerSoft: dangerSoft ?? this.dangerSoft,
      dangerText: dangerText ?? this.dangerText,
      success: success ?? this.success,
      avatarPlaceholder: avatarPlaceholder ?? this.avatarPlaceholder,
      heroFallback: heroFallback ?? this.heroFallback,
      shadow: shadow ?? this.shadow,
    );
  }

  @override
  AppThemeColors lerp(ThemeExtension<AppThemeColors>? other, double t) {
    if (other is! AppThemeColors) {
      return this;
    }

    return AppThemeColors(
      brand: Color.lerp(brand, other.brand, t)!,
      brandStrong: Color.lerp(brandStrong, other.brandStrong, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      scaffold: Color.lerp(scaffold, other.scaffold, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      icon: Color.lerp(icon, other.icon, t)!,
      sidebar: Color.lerp(sidebar, other.sidebar, t)!,
      sidebarSurface: Color.lerp(sidebarSurface, other.sidebarSurface, t)!,
      sidebarText: Color.lerp(sidebarText, other.sidebarText, t)!,
      sidebarMuted: Color.lerp(sidebarMuted, other.sidebarMuted, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      accentSoftText: Color.lerp(accentSoftText, other.accentSoftText, t)!,
      unreadSurface: Color.lerp(unreadSurface, other.unreadSurface, t)!,
      warningSoft: Color.lerp(warningSoft, other.warningSoft, t)!,
      warningText: Color.lerp(warningText, other.warningText, t)!,
      dangerSoft: Color.lerp(dangerSoft, other.dangerSoft, t)!,
      dangerText: Color.lerp(dangerText, other.dangerText, t)!,
      success: Color.lerp(success, other.success, t)!,
      avatarPlaceholder: Color.lerp(
        avatarPlaceholder,
        other.avatarPlaceholder,
        t,
      )!,
      heroFallback: Color.lerp(heroFallback, other.heroFallback, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
    );
  }
}

extension AppThemeContext on BuildContext {
  AppThemeColors get appColors =>
      Theme.of(this).extension<AppThemeColors>() ?? AppThemeColors.light;
}

class AppTheme {
  static ThemeData light() =>
      _buildTheme(brightness: Brightness.light, colors: AppThemeColors.light);

  static ThemeData dark() =>
      _buildTheme(brightness: Brightness.dark, colors: AppThemeColors.dark);

  static ThemeData _buildTheme({
    required Brightness brightness,
    required AppThemeColors colors,
  }) {
    final colorScheme =
        ColorScheme.fromSeed(
          brightness: brightness,
          seedColor: colors.brand,
        ).copyWith(
          primary: colors.brand,
          secondary: colors.accent,
          surface: colors.surface,
          onSurface: colors.textPrimary,
          onPrimary: Colors.white,
          outline: colors.border,
          error: colors.dangerText,
        );

    return ThemeData(
      brightness: brightness,
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colors.scaffold,
      dividerColor: colors.border,
      disabledColor: colors.textMuted,
      shadowColor: colors.shadow,
      extensions: <ThemeExtension<dynamic>>[colors],
      textTheme: (brightness == Brightness.dark
              ? Typography.material2021().white
              : Typography.material2021().black)
          .apply(
            bodyColor: colors.textPrimary,
            displayColor: colors.textPrimary,
          ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: colors.brand),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.surface,
        surfaceTintColor: colors.surface,
        foregroundColor: colors.textPrimary,
        elevation: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colors.surface,
        elevation: 0,
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: colors.borderStrong),
        ),
        contentTextStyle: TextStyle(
          color: colors.textPrimary,
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: colors.surface,
        surfaceTintColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colors.surface,
        indicatorColor: colors.accentSoft,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return TextStyle(
            color: states.contains(WidgetState.selected)
                ? colors.brand
                : colors.textMuted,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            color: states.contains(WidgetState.selected)
                ? colors.brand
                : colors.icon,
          );
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceMuted,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        hintStyle: TextStyle(color: colors.textMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colors.brand, width: 1.4),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          backgroundColor: colors.brand,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colors.brand,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: colors.icon),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
    );
  }
}
