import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Spacing scale (dp).
class AppSpace {
  AppSpace._();
  static const double xs = 4;
  static const double s = 8;
  static const double m = 12;
  static const double l = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

/// Corner radii (dp).
class AppRadius {
  AppRadius._();
  static const double chip = 8;
  static const double control = 12;
  static const double card = 12;
  static const double sheet = 16;
}

/// Component sizes (dp).
class AppSize {
  AppSize._();
  static const double minTouch = 48;
  static const double button = 48;
  static const double iconBadge = 36;
  static const double iconInBadge = 20;
  static const double iconNav = 24;
}

/// Light/dark color tokens used by every KEEPON component.
@immutable
class KeepOnTokens {
  const KeepOnTokens({
    required this.isDark,
    required this.background,
    required this.surface,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.primary,
    required this.primaryDeep,
    required this.primarySoft,
  });

  final bool isDark;
  final Color background;
  final Color surface;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color primary;
  final Color primaryDeep;
  final Color primarySoft;

  // Aliases for older call sites.
  Color get accent => primary;
  Color get divider => border;

  static const light = KeepOnTokens(
    isDark: false,
    background: AppColors.background,
    surface: AppColors.surface,
    border: AppColors.border,
    textPrimary: AppColors.textPrimary,
    textSecondary: AppColors.textSecondary,
    primary: AppColors.primary,
    primaryDeep: AppColors.primaryDeep,
    primarySoft: AppColors.primarySoft,
  );

  static const dark = KeepOnTokens(
    isDark: true,
    background: Color(0xFF0F1722),
    surface: Color(0xFF16202D),
    border: Color(0xFF263243),
    textPrimary: Color(0xFFEEF3F9),
    textSecondary: Color(0xFF9AA9BC),
    primary: Color(0xFF5E95EE),
    primaryDeep: Color(0xFF246FE5),
    primarySoft: Color(0xFF1B2A44),
  );

  static KeepOnTokens of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

ThemeData buildKeepOnTheme(Brightness brightness) {
  final t = brightness == Brightness.dark ? KeepOnTokens.dark : KeepOnTokens.light;
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: brightness,
  ).copyWith(
    primary: t.primary,
    surface: t.surface,
    onSurface: t.textPrimary,
    outline: t.border,
    error: AppColors.error,
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    brightness: brightness,
    // Söhne is a licensed font: add the files (see pubspec.yaml) and it is used automatically.
    // Without them Android falls back to its default sans-serif.
    fontFamily: 'Sohne',
  );
  final text = base.textTheme.apply(bodyColor: t.textPrimary, displayColor: t.textPrimary);

  return base.copyWith(
    scaffoldBackgroundColor: t.background,
    dividerColor: t.border,
    dividerTheme: DividerThemeData(color: t.border, thickness: 1, space: 1),
    textTheme: text.copyWith(
      headlineMedium: text.headlineMedium?.copyWith(fontSize: 24, fontWeight: FontWeight.w600, letterSpacing: -0.3, height: 1.2),
      headlineSmall: text.headlineSmall?.copyWith(fontSize: 20, fontWeight: FontWeight.w600, height: 1.25),
      titleLarge: text.titleLarge?.copyWith(fontSize: 18, fontWeight: FontWeight.w600, height: 1.3),
      titleMedium: text.titleMedium?.copyWith(fontSize: 16, fontWeight: FontWeight.w600, height: 1.3),
      titleSmall: text.titleSmall?.copyWith(fontSize: 14, fontWeight: FontWeight.w600, height: 1.3),
      bodyLarge: text.bodyLarge?.copyWith(fontSize: 16, height: 1.45),
      bodyMedium: text.bodyMedium?.copyWith(fontSize: 14, height: 1.45),
      bodySmall: text.bodySmall?.copyWith(fontSize: 13, height: 1.4, color: t.textSecondary),
      labelLarge: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      labelMedium: text.labelMedium?.copyWith(fontSize: 12, fontWeight: FontWeight.w600),
      labelSmall: text.labelSmall?.copyWith(fontSize: 11.5, fontWeight: FontWeight.w600, letterSpacing: 0.1),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: t.background,
      foregroundColor: t.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: t.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 68,
      indicatorColor: t.primarySoft,
      indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.control)),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
          fontSize: 12,
          fontWeight: s.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w500,
          color: s.contains(WidgetState.selected) ? t.primary : t.textSecondary,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: t.primary,
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        minimumSize: const Size(AppSize.minTouch, 40),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? Colors.white : t.textSecondary,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? t.primary : t.border,
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: t.primary,
      thumbColor: t.primary,
      inactiveTrackColor: t.border,
      overlayColor: t.primary.withValues(alpha: 0.12),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? t.primarySoft : Colors.transparent,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? t.primary : t.textSecondary,
        ),
        side: WidgetStatePropertyAll(BorderSide(color: t.border)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.control)),
        ),
        textStyle: const WidgetStatePropertyAll(TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: t.isDark ? const Color(0xFF2A3B52) : AppColors.textPrimary,
      contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.control)),
    ),
  );
}
