// lib/services/generation_service.dart
//
// SAFE STUB VERSION — allows DreamFlow to load the app with no backend.
// No TODOs. No missing URLs. No missing API keys. No errors.
//

import 'dart:typed_data';

class GenerationService {
  const GenerationService();

  /// Stub method — Always returns null.
  /// This prevents crashes and lets the app compile while backend is not ready.
  Future<Uint8List?> generateImage({
    required String prompt,
    String? style,
    Uint8List? initImage,
  }) async {
    // No remote calls to avoid Dreamflow analysis errors.
    // You can add logging or mock bytes here if needed.

    return null; // indicates "no output yet"
  }
}
