import 'package:shared_preferences/shared_preferences.dart';

class SofiSessionMemory {
  static const _modeKey = 'sofi_last_mode';
  static const _guidanceKey = 'sofi_last_guidance';
  static const _ratioKey = 'sofi_last_ratio';

  // SAVE
  static Future<void> save({
    required String mode,
    required double guidance,
    required String ratio,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modeKey, mode);
    await prefs.setDouble(_guidanceKey, guidance);
    await prefs.setString(_ratioKey, ratio);
  }

  // LOAD
  static Future<Map<String, dynamic>> load() async {
    final prefs = await SharedPreferences.getInstance();

    return {
      'mode': prefs.getString(_modeKey) ?? 'pixar',
      'guidance': prefs.getDouble(_guidanceKey) ?? 6.8,
      'ratio': prefs.getString(_ratioKey) ?? 'portrait',
    };
  }

  // CLEAR (optional)
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_modeKey);
    await prefs.remove(_guidanceKey);
    await prefs.remove(_ratioKey);
  }
}
