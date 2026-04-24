import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// RECOMMENDED THEME — Social Premium + Brand Blue
//
// Concept: Twitter/X structure but with brand blue (#3D5AFE) baked into
// the dark surface stack — so dark mode feels distinctly *yours*, not generic.
//
// Dark:
//   Scaffold     → #111827  blue-tinted dark (warmer than Twitter, cooler than navy)
//   Surface      → #161F2E  brand-tinted card layer
//   SurfaceMuted → #192338  input fills, inset areas
//   SurfaceRaised→ #1C2840  modals, bottom sheets
//   Sidebar      → #0C1220  deepest brand-tinted black
//
// Light:
//   Scaffold     → #FFFFFF  Twitter true white — brand blue pops on white
//   Surface      → #FFFFFF  same
//   SurfaceMuted → #fbfcfd  faint brand-tinted input bg (not grey, slightly blue)
//   Border       → #EEF0F8  brand-tinted hairline
// ─────────────────────────────────────────────────────────────────────────────

class AppColors {
  const AppColors._();

  // Brand — your electric blue
  static const brand = Color(0xFF3252E6);
  static const brandDark = Color(0xFF2846CC);
  static const accent = Color(0xFF7C3AED);

  // Semantic
  static const danger = Color(0xFFef4444);
  static const warning = Color(0xFFFFB020);
  static const success = Color(0xFF16A34A);
}

@immutable
class AppThemeColors extends ThemeExtension<AppThemeColors> {
  const AppThemeColors({
    required this.brand,
    required this.brandStrong,
    required this.heroStart,
    required this.heroEnd,
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
  final Color heroStart;
  final Color heroEnd;
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

  LinearGradient get brandGradient => LinearGradient(
    colors: [AppColors.brand, AppColors.brandDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  LinearGradient get heroGradient => LinearGradient(
    colors: [heroStart, heroEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ─── LIGHT ───────────────────────────────────────────────────────────────
  // Twitter true white — brand blue pops on pure white.
  // Borders get a faint blue tint so even hairlines feel on-brand.
  static const light = AppThemeColors(
    brand: AppColors.brand,
    brandStrong: AppColors.brandDark,
    heroStart: AppColors.brandDark,
    heroEnd: AppColors.brand,
    accent: AppColors.accent,

    scaffold: Color(0xFFf9fafc), // Twitter true white
    surface: Color(0xFFFFFFFF), // Flush — no separation needed
    surfaceMuted: Color(0xFFf9fafc), // Faint brand-blue input bg
    surfaceRaised: Color(0xFFEEF1FF), // Brand-tinted raised panels

    border: Color(0xFFEEF0F8), // Brand-tinted hairline
    borderStrong: Color(0xFFD5DAF0), // Visible brand-tinted divider

    textPrimary: Color(0xFF0F1419), // Twitter ink black
    textSecondary: Color(0xFF2D3748), // Dark slate
    textMuted: Color(0xFF536471), // Twitter grey
    icon: Color(0xFF536471),

    sidebar: Color(0xFF111827), // Match dark scaffold
    sidebarSurface: Color.fromRGBO(255, 255, 255, 0.07),
    sidebarText: Color(0xFFF0F4FF),
    sidebarMuted: Color(0xFF7A8FA8),

    accentSoft: Color(0xFFEEF0FF), // Brand soft fill
    accentSoftText: AppColors.brand,
    unreadSurface: Color(0xFFF0F3FF),

    warningSoft: Color(0xFFFFF8EC),
    warningText: AppColors.warning,
    dangerSoft: Color(0xFFFFF0F2),
    dangerText: AppColors.danger,
    success: AppColors.success,

    avatarPlaceholder: Color(0xFFEEF0FF),
    heroFallback: Color(0xFF0F1419),
    shadow: Color.fromRGBO(61, 90, 254, 0.10), // Brand-tinted shadow
  );

  // ─── DARK ────────────────────────────────────────────────────────────────
  // Twitter Dim structure + brand blue baked into every surface layer.
  // The result: a dark mode that is unmistakably yours.
  //
  // Elevation stack:
  //   #0C1220  sidebar       (deepest)
  //   #111827  scaffold      ← base
  //   #161F2E  surface       (+1)
  //   #192338  surfaceMuted  (+1.5 — inputs)
  //   #1C2840  surfaceRaised (+2 — modals)
  static const dark = AppThemeColors(
    brand: AppColors.brand,
    brandStrong: AppColors.brandDark,
    heroStart: Color(0xFF1A3580),
    heroEnd: Color(0xFF3D5AFE),
    accent: Color(0xFFA78BFA),

    scaffold: Color(0xFF0A111D), // Slightly deeper base
    surface: Color(0xFF0F1826), // Darker card layer
    surfaceMuted: Color(0xFF121C2D), // Input fills, inset areas
    surfaceRaised: Color(0xFF162136), // Modals, bottom sheets

    border: Color(0xFF172435), // Subtle structural border
    borderStrong: Color(0xFF1D2C42), // Softer strong divider

    textPrimary: Color(0xFFF0F4FF), // Cool off-white with blue tint
    textSecondary: Color(0xFF90A5BE), // Secondary copy
    textMuted: Color(0xFF647890), // Readable muted copy
    icon: Color(0xFF8095AF), // More visible muted icon tone

    sidebar: Color(0xFF0C1220), // Deepest brand-tinted black
    sidebarSurface: Color.fromRGBO(61, 90, 254, 0.08), // Brand-tinted overlay
    sidebarText: Color(0xFFF0F4FF),
    sidebarMuted: Color(0xFF647890),

    accentSoft: Color(0xFF1A2550), // Rich brand fill — distinctive
    accentSoftText: Color(0xFFBBCBFF),
    unreadSurface: Color(0xFF141E34), // Slightly blue-shifted unread bg

    warningSoft: Color(0xFF2A2010),
    warningText: Color(0xFFFFC966),
    dangerSoft: Color(0xFF2C1018),
    dangerText: Color(0xFFef4444),
    success: Color(0xFF4ADE80),

    avatarPlaceholder: Color(0xFF1A2550),
    heroFallback: Color(0xFF0C1220),
    shadow: Color.fromRGBO(10, 15, 40, 0.60), // Deep brand-tinted shadow
  );

  @override
  AppThemeColors copyWith({
    Color? brand,
    Color? brandStrong,
    Color? heroStart,
    Color? heroEnd,
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
      heroStart: heroStart ?? this.heroStart,
      heroEnd: heroEnd ?? this.heroEnd,
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
    if (other is! AppThemeColors) return this;
    return AppThemeColors(
      brand: Color.lerp(brand, other.brand, t)!,
      brandStrong: Color.lerp(brandStrong, other.brandStrong, t)!,
      heroStart: Color.lerp(heroStart, other.heroStart, t)!,
      heroEnd: Color.lerp(heroEnd, other.heroEnd, t)!,
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

    final baseTextTheme =
        (brightness == Brightness.dark
                ? Typography.material2021().white
                : Typography.material2021().black)
            .apply(
              bodyColor: colors.textPrimary,
              displayColor: colors.textPrimary,
              fontFamily: 'Inter',
            );

    return ThemeData(
      brightness: brightness,
      useMaterial3: true,
      fontFamily: 'Inter',
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colors.scaffold,
      dividerColor: colors.border,
      disabledColor: colors.textMuted,
      shadowColor: colors.shadow,
      extensions: <ThemeExtension<dynamic>>[colors],
      textTheme: baseTextTheme,
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
      dialogTheme: DialogThemeData(
        backgroundColor: brightness == Brightness.light
            ? Colors.white
            : colors.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
