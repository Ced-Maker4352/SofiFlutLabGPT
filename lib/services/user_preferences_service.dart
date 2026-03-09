import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A global service to store and manage user preferences, 
/// such as the master switch for "Doll Mode" vs "Human Mode".
class UserPreferencesService extends ChangeNotifier {
  static const String _dollModeKey = 'global_doll_mode_enabled';
  static const String _maleModeKey = 'global_male_mode_enabled';

  bool _isDollMode = true;
  bool _isMaleMode = false;

  /// Whether the user has toggled on the 3D Plastic Doll master switch.
  bool get isDollMode => _isDollMode;
  
  /// Whether the user has toggled on the Male generator switch.
  bool get isMaleMode => _isMaleMode;

  /// Singleton instance
  static final UserPreferencesService instance = UserPreferencesService._();
  UserPreferencesService._();

  /// Loads preferences from device storage on app startup.
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _isDollMode = prefs.getBool(_dollModeKey) ?? true;
    _isMaleMode = prefs.getBool(_maleModeKey) ?? false;
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

  /// Toggles the male mode switch and saves to storage.
  Future<void> setMaleMode(bool value) async {
    if (_isMaleMode == value) return;
    
    _isMaleMode = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_maleModeKey, value);
    
    notifyListeners();
  }
}
