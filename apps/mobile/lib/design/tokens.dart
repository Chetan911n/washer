import 'package:flutter/material.dart';

/// Shared visual foundations for customer and washer experiences.
abstract final class WashColors {
  static const ink = Color(0xFF142D3A);
  static const muted = Color(0xFF526873);
  static const brand = Color(0xFF087E8B);
  static const brandDark = Color(0xFF075E68);
  static const canvas = Color(0xFFF5F8F8);
  static const surface = Color(0xFFFFFFFF);
  static const border = Color(0xFF7F9297);
  static const success = Color(0xFF18794E);
  static const warning = Color(0xFF9A5B00);
  static const danger = Color(0xFFB42318);
  static const unavailable = Color(0xFFE7ECEE);
}

abstract final class WashSpace {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
}

abstract final class WashRadius {
  static const card = 16.0;
  static const control = 12.0;
  static const pill = 999.0;
}

ThemeData washTheme() => ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: WashColors.canvas,
  colorScheme:
      ColorScheme.fromSeed(
        seedColor: WashColors.brand,
        primary: WashColors.brand,
        surface: WashColors.surface,
        error: WashColors.danger,
      ).copyWith(
        onPrimary: Colors.white,
        onSurface: WashColors.ink,
        onSurfaceVariant: WashColors.muted,
        onError: Colors.white,
      ),
  textTheme: const TextTheme(
    headlineSmall: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w700,
      color: WashColors.ink,
    ),
    titleLarge: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      color: WashColors.ink,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: WashColors.ink,
    ),
    bodyLarge: TextStyle(fontSize: 16, color: WashColors.ink),
    bodyMedium: TextStyle(fontSize: 14, color: WashColors.muted),
    labelLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
  ),
  cardTheme: CardThemeData(
    color: WashColors.surface,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(WashRadius.card),
      side: const BorderSide(color: WashColors.border),
    ),
  ),
  inputDecorationTheme: InputDecorationThemeData(
    filled: true,
    fillColor: WashColors.surface,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(WashRadius.control),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(WashRadius.control),
      borderSide: const BorderSide(color: WashColors.border),
    ),
    contentPadding: const EdgeInsets.symmetric(
      horizontal: WashSpace.md,
      vertical: WashSpace.md,
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      minimumSize: const Size.fromHeight(52),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(WashRadius.control),
      ),
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
    ),
  ),
);
