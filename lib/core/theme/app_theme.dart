import 'package:flutter/material.dart';

/// HSL tokens from [zipro_website_new/app/globals.css] :root (light).
class AppColors {
  AppColors._();

  static final Color background = _hsl(210, 0.20, 0.99);
  static final Color foreground = _hsl(222, 0.47, 0.11);
  static final Color primary = _hsl(216, 0.95, 0.26);
  static final Color primaryForeground = Colors.white;
  static final Color secondary = _hsl(210, 0.40, 0.96);
  static final Color secondaryForeground = _hsl(222, 0.47, 0.11);
  static final Color mutedForeground = _hsl(215, 0.16, 0.47);
  static final Color accent = _hsl(30, 1.0, 0.50);
  static final Color accentForeground = Colors.white;
  static final Color border = _hsl(214, 0.32, 0.91);
  static final Color destructive = _hsl(0, 0.84, 0.60);

  /// [h] hue 0–360, [s] and [l] 0–1 (Flutter HSLColor).
  static Color _hsl(double h, double s, double l) {
    return HSLColor.fromAHSL(1, h, s, l).toColor();
  }
}

ThemeData buildAppTheme() {
  final colorScheme = ColorScheme.light(
    surface: AppColors.background,
    onSurface: AppColors.foreground,
    primary: AppColors.primary,
    onPrimary: AppColors.primaryForeground,
    secondary: AppColors.secondary,
    onSecondary: AppColors.secondaryForeground,
    error: AppColors.destructive,
    outline: AppColors.border,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AppColors.background,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.foreground,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.background,
      indicatorColor: AppColors.primary.withValues(alpha: 0.12),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        return TextStyle(
          fontSize: 12,
          fontWeight:
              states.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w500,
          color: states.contains(WidgetState.selected)
              ? AppColors.primary
              : AppColors.mutedForeground,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        return IconThemeData(
          color: states.contains(WidgetState.selected)
              ? AppColors.primary
              : AppColors.mutedForeground,
          size: 22,
        );
      }),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.border),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.primaryForeground,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
  );
}
