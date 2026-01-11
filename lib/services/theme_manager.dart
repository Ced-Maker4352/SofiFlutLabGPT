// lib/services/theme_manager.dart

import 'package:flutter/material.dart';

enum AppThemeType { blue, yellow, pink, black }

class AppThemeData {
  final AppThemeType type;
  final String name;
  final Color headerColor;
  final Color headerTextColor;
  final Color accentColor;
  final Color backgroundColor;
  final IconData icon;

  const AppThemeData({
    required this.type,
    required this.name,
    required this.headerColor,
    required this.headerTextColor,
    required this.accentColor,
    required this.backgroundColor,
    required this.icon,
  });
}

class ThemeManager extends ChangeNotifier {
  static final ThemeManager _instance = ThemeManager._internal();
  static ThemeManager get instance => _instance;
  ThemeManager._internal();

  static const Map<AppThemeType, AppThemeData> themes = {
    AppThemeType.blue: AppThemeData(
      type: AppThemeType.blue,
      name: 'Ocean Blue',
      headerColor: Color(0xFFDAE8FF),
      headerTextColor: Color(0xFF1A237E),
      accentColor: Color(0xFF5A2DFF),
      backgroundColor: Color(0xFFDAE8FF),
      icon: Icons.water_drop,
    ),
    AppThemeType.yellow: AppThemeData(
      type: AppThemeType.yellow,
      name: 'Sunshine',
      headerColor: Color(0xFFFFF3B0),
      headerTextColor: Color(0xFF5D4037),
      accentColor: Color(0xFFFFB300),
      backgroundColor: Color(0xFFFFF8DC),
      icon: Icons.wb_sunny,
    ),
    AppThemeType.pink: AppThemeData(
      type: AppThemeType.pink,
      name: 'Rose',
      headerColor: Color(0xFFFFD6E8),
      headerTextColor: Color(0xFF880E4F),
      accentColor: Color(0xFFE91E63),
      backgroundColor: Color(0xFFFFF0F5),
      icon: Icons.local_florist,
    ),
    AppThemeType.black: AppThemeData(
      type: AppThemeType.black,
      name: 'Midnight',
      headerColor: Color(0xFF1A1A2E),
      headerTextColor: Color(0xFFE0E0E0),
      accentColor: Color(0xFF6C63FF),
      backgroundColor: Color(0xFF16213E),
      icon: Icons.nightlight_round,
    ),
  };

  AppThemeType _currentTheme = AppThemeType.blue;

  AppThemeType get currentTheme => _currentTheme;
  AppThemeData get current => themes[_currentTheme]!;

  void setTheme(AppThemeType theme) {
    _currentTheme = theme;
    notifyListeners();
  }

  void cycleTheme() {
    final values = AppThemeType.values;
    final nextIndex = (values.indexOf(_currentTheme) + 1) % values.length;
    _currentTheme = values[nextIndex];
    notifyListeners();
  }
}
