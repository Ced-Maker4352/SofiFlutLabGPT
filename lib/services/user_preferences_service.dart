import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A global service to store and manage user preferences, 
/// such as the master switch for "Doll Mode" vs "Human Mode".
class UserPreferencesService extends ChangeNotifier {
  static const String _dollModeKey = 'global_doll_mode_enabled';
  static const String _maleModeKey = 'global_male_mode_enabled';
  static const String _geminiApiKeyKey = 'custom_gemini_api_key';
  static const String _useCustomAiProviderKey = 'use_custom_ai_provider';

  bool _isDollMode = true;
  bool _isMaleMode = false;
  String _geminiApiKey = '';
  bool _useCustomAiProvider = false;

  /// Whether the user has toggled on the 3D Plastic Doll master switch.
  bool get isDollMode => _isDollMode;
  
  /// Whether the user has toggled on the Male generator switch.
  bool get isMaleMode => _isMaleMode;

  /// Custom Gemini API key provided by the user.
  String get geminiApiKey => _geminiApiKey;

  /// Whether to use the custom AI provider (Gemini) instead of the default backend.
  bool get useCustomAiProvider => _useCustomAiProvider;

  /// Singleton instance
  static final UserPreferencesService instance = UserPreferencesService._();
  UserPreferencesService._();

  /// Loads preferences from device storage on app startup.
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _isDollMode = prefs.getBool(_dollModeKey) ?? true;
    _isMaleMode = prefs.getBool(_maleModeKey) ?? false;
    _geminiApiKey = prefs.getString(_geminiApiKeyKey) ?? '';
    _useCustomAiProvider = prefs.getBool(_useCustomAiProviderKey) ?? false;
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

  /// Sets the custom Gemini API key and saves to storage.
  Future<void> setGeminiApiKey(String value) async {
    if (_geminiApiKey == value) return;
    
    _geminiApiKey = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_geminiApiKeyKey, value);
    
    notifyListeners();
  }

  /// Toggles the custom AI provider switch and saves to storage.
  Future<void> setUseCustomAiProvider(bool value) async {
    if (_useCustomAiProvider == value) return;
    
    _useCustomAiProvider = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_useCustomAiProviderKey, value);
    
    notifyListeners();
  }
}
