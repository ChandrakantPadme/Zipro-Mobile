import 'package:flutter/material.dart';

/// Auth-flow palette aligned with the Zipro login mock (navy + orange).
class LoginTheme {
  LoginTheme._();

  static const Color navy = Color(0xFF0A1628);
  static const Color navyDeep = Color(0xFF060D18);
  static const Color orange = Color(0xFFFF6B15);
  static const Color sheetWhite = Color(0xFFFFFFFF);
  static const Color textNavy = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF64748B);
  static const Color borderSubtle = Color(0xFFE2E8F0);
  static const Color otpBoxFill = Color(0xFF111C2E);
  static const Color otpBorder = Color(0xFF334155);

  static const double sheetTopRadius = 28;
  static const double controlRadius = 16;

  /// Same stops as [zipro_website_new/app/login/page.tsx] left panel.
  static final BoxDecoration webLoginHeroGradient = BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        HSLColor.fromAHSL(1, 30, 0.95, 0.55).toColor(),
        HSLColor.fromAHSL(1, 30, 0.90, 0.48).toColor(),
        HSLColor.fromAHSL(1, 216, 0.85, 0.32).toColor(),
        HSLColor.fromAHSL(1, 216, 0.90, 0.28).toColor(),
      ],
    ),
  );

  /// Hero when not using a raster background (legacy sunset).
  static const BoxDecoration sunsetHeroGradient = BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0xFF1E3A5F),
        Color(0xFF4F2A5C),
        Color(0xFFB84A2E),
        Color(0xFFE8893C),
      ],
      stops: [0.0, 0.35, 0.72, 1.0],
    ),
  );
}
