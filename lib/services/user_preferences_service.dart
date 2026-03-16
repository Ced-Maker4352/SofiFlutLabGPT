import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Available AI Providers for custom integration.
enum AiProvider {
  none,
  gemini,
  generic, // OpenAI-compatible (Ollama, Qwen, etc)
}

/// A global service to store and manage user preferences, 
/// such as the master switch for "Doll Mode" vs "Human Mode".
class UserPreferencesService extends ChangeNotifier {
  static const String _dollModeKey = 'global_doll_mode_enabled';
  static const String _maleModeKey = 'global_male_mode_enabled';
  static const String _geminiApiKeyKey = 'custom_gemini_api_key';
  static const String _useCustomAiProviderKey = 'use_custom_ai_provider';
  static const String _aiProviderKey = 'active_ai_provider';
  static const String _customBaseUrlKey = 'custom_ai_base_url';
  static const String _customModelKey = 'custom_ai_model_name';

  bool _isDollMode = true;
  bool _isMaleMode = false;
  String _geminiApiKey = '';
  bool _useCustomAiProvider = false; // Legacy toggle
  AiProvider _activeAiProvider = AiProvider.none;
  String _customBaseUrl = '';
  String _customModel = '';

  /// Whether the user has toggled on the 3D Plastic Doll master switch.
  bool get isDollMode => _isDollMode;
  
  /// Whether the user has toggled on the Male generator switch.
  bool get isMaleMode => _isMaleMode;

  /// Custom Gemini API key provided by the user.
  String get geminiApiKey => _geminiApiKey;

  /// Whether to use a custom AI provider (legacy toggle, now maps to _activeAiProvider != none).
  bool get useCustomAiProvider => _activeAiProvider != AiProvider.none;

  /// The currently active AI provider.
  AiProvider get activeAiProvider => _activeAiProvider;

  /// Custom Base URL for generic OpenAI-compatible providers.
  String get customBaseUrl => _customBaseUrl;

  /// Custom Model name for generic AI providers.
  String get customModel => _customModel;

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
    
    final providerIndex = prefs.getInt(_aiProviderKey) ?? 0;
    _activeAiProvider = AiProvider.values[providerIndex];
    
    // Auto-migrate legacy toggle if needed
    if (_useCustomAiProvider && _activeAiProvider == AiProvider.none) {
      _activeAiProvider = AiProvider.gemini;
    }
    
    _customBaseUrl = prefs.getString(_customBaseUrlKey) ?? '';
    _customModel = prefs.getString(_customModelKey) ?? '';
    
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

  /// Toggles the custom AI provider switch (Legacy, avoids breaking UI).
  Future<void> setUseCustomAiProvider(bool value) async {
    final newProvider = value ? AiProvider.gemini : AiProvider.none;
    await setActiveAiProvider(newProvider);
  }

  /// Sets the active AI provider and saves to storage.
  Future<void> setActiveAiProvider(AiProvider value) async {
    if (_activeAiProvider == value) return;
    
    _activeAiProvider = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_aiProviderKey, value.index);
    await prefs.setBool(_useCustomAiProviderKey, value != AiProvider.none);
    
    notifyListeners();
  }

  /// Sets the custom Base URL and saves to storage.
  Future<void> setCustomBaseUrl(String value) async {
    if (_customBaseUrl == value) return;
    _customBaseUrl = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_customBaseUrlKey, value);
    notifyListeners();
  }

  /// Sets the custom Model name and saves to storage.
  Future<void> setCustomModel(String value) async {
    if (_customModel == value) return;
    _customModel = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_customModelKey, value);
    notifyListeners();
  }
}
