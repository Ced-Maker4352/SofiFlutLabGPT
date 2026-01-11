// lib/theme.dart
import 'package:flutter/material.dart';

/// Brand token colors used across the app.
class BrandColors {
  static const Color maroon = Color(0xFF2B0014);
  static const Color neonCyan = Color(0xFF5FF7F3);
  static const Color yellow = Color(0xFFFFD54F);
}

/// Light-mode specific tokens.
class LightModeColors {
  static const Color lightBackground = Color(0xFFFFF8FB);
  static const Color lightSurface = Colors.white;
  static const Color lightOnBackground = Color(0xFF210015);
  static const Color lightOnSurface = Color(0xFF210015);
  static const Color lightPrimary = BrandColors.maroon;
  static const Color lightOnPrimary = Colors.white;
  static const Color lightError = Color(0xFFBA1A1A);
  static const Color lightOnError = Colors.white;
  static const Color lightShadow = Colors.black;
}

/// Dark-mode specific tokens.
class DarkModeColors {
  static const Color darkBackground = Color(0xFF0D0008);
  static const Color darkSurface = Color(0xFF1A0714);
  static const Color darkOnBackground = Color(0xFFFFECF4);
  static const Color darkOnSurface = Color(0xFFFFECF4);
  static const Color darkPrimary = BrandColors.maroon;
  static const Color darkOnPrimary = Colors.white;
  static const Color darkError = Color(0xFFFFB4AB);
  static const Color darkOnError = Color(0xFF690005);
  static const Color darkShadow = Colors.black;
}

final ThemeData lightTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: BrandColors.maroon,
    brightness: Brightness.light,
    surface: LightModeColors.lightBackground,
  ),
  scaffoldBackgroundColor: LightModeColors.lightBackground,
  fontFamily: 'Roboto',
  appBarTheme: const AppBarTheme(
    backgroundColor: BrandColors.maroon,
    foregroundColor: Colors.white,
    elevation: 0,
    centerTitle: false,
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.black.withValues(alpha: 0.85),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    ),
    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
  ),
  chipTheme: ChipThemeData(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    selectedColor: BrandColors.maroon,
    backgroundColor: Colors.white.withValues(alpha: 0.08),
    labelStyle: const TextStyle(color: Colors.white),
  ),
  snackBarTheme: SnackBarThemeData(
    behavior: SnackBarBehavior.floating,
    backgroundColor: Colors.black.withValues(alpha: 0.9),
    contentTextStyle: const TextStyle(color: Colors.white),
  ),
  textTheme: const TextTheme(
    titleLarge: TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.3,
    ),
    labelMedium: TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w500,
    ),
    labelSmall: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w400,
    ),
  ),
);

final ThemeData darkTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: BrandColors.neonCyan,
    brightness: Brightness.dark,
    surface: DarkModeColors.darkBackground,
  ),
  scaffoldBackgroundColor: DarkModeColors.darkBackground,
  fontFamily: 'Roboto',
  appBarTheme: const AppBarTheme(
    backgroundColor: BrandColors.maroon,
    foregroundColor: Colors.white,
    elevation: 0,
    centerTitle: false,
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.black.withValues(alpha: 0.85),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    ),
    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
  ),
  chipTheme: ChipThemeData(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    selectedColor: BrandColors.neonCyan,
    backgroundColor: Colors.white.withValues(alpha: 0.12),
    labelStyle: const TextStyle(color: Colors.white),
  ),
  snackBarTheme: SnackBarThemeData(
    behavior: SnackBarBehavior.floating,
    backgroundColor: Colors.black.withValues(alpha: 0.9),
    contentTextStyle: const TextStyle(color: Colors.white),
  ),
  textTheme: const TextTheme(
    titleLarge: TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.3,
    ),
    labelMedium: TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w500,
    ),
    labelSmall: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w400,
    ),
  ),
);
