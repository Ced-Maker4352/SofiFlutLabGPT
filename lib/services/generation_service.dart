// lib/services/generation_service.dart
//
// SAFE STUB VERSION — allows DreamFlow to load the app with no backend.
// No TODOs. No missing URLs. No missing API keys. No errors.
//

import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:sofi_test_connect/services/user_preferences_service.dart';
import 'package:sofi_test_connect/services/gemini_service.dart';

class GenerationService {
  const GenerationService();

  /// Stub method — Always returns null.
  /// This prevents crashes and lets the app compile while backend is not ready.
  Future<Uint8List?> generateImage({
    required String prompt,
    String? style,
    Uint8List? initImage,
  }) async {
    final prefs = UserPreferencesService.instance;

    // Check if custom Gemini provider is enabled
    if (prefs.useCustomAiProvider && prefs.geminiApiKey.isNotEmpty) {
      try {
        final gemini = GeminiService(apiKey: prefs.geminiApiKey);
        final result = await gemini.generateImage(
          prompt: prompt,
          initImage: initImage,
        );
        if (result != null) return result;
      } catch (e) {
        debugPrint('[GenerationService] Gemini fallback failed: $e');
        // Fallback to default behavior or return null
      }
    }

    // No remote calls to avoid Dreamflow analysis errors.
    // You can add logging or mock bytes here if needed.

    return null; // indicates "no output yet"
  }
}
