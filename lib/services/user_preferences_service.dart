import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A global service to store and manage user preferences, 
/// such as the master switch for "Doll Mode" vs "Human Mode".
class UserPreferencesService extends ChangeNotifier {
  static const String _dollModeKey = 'global_doll_mode_enabled';

  bool _isDollMode = false;

  /// Whether the user has toggled on the 3D Plastic Doll master switch.
  bool get isDollMode => _isDollMode;

  /// Singleton instance
  static final UserPreferencesService instance = UserPreferencesService._();
  UserPreferencesService._();

  /// Loads preferences from device storage on app startup.
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _isDollMode = prefs.getBool(_dollModeKey) ?? false;
    notifyListeners();
  }

  /// Toggles the master switch and saves to storage.
  Future<void> setDollMode(bool value) async {
    if (_isDollMode == value) return;
    
    _isDollMode = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_dollModeKey, value);
    
    notifyListeners();
  }
}
