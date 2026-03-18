import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

import 'package:sofi_test_connect/services/user_preferences_service.dart';
import 'models_lab_service.dart';

class TwoStepGenerationService {
  const TwoStepGenerationService();

  Future<Uint8List> runStep1IdentityLock(
    Uint8List baseImage,
    String prompt, {
    String? negativePrompt,
    String aspectRatio = '9:16',
    bool forceDollAesthetic = false,
    bool isMale = false,
  }) async {
    final initImageBase64 = 'data:image/png;base64,${base64Encode(baseImage)}';
    final String genderLabel = isMale ? 'young boy' : 'young girl';
    final String lockLanguage = forceDollAesthetic
        ? 'Preserve the same $genderLabel facial identity exactly, but strictly apply the 3D toy plastic skin texture.'
        : 'Preserve the same $genderLabel identity exactly. Do not change facial structure, age, ethnicity, skin tone, or proportions. Strictly follow $genderLabel characteristics.';

    final finalPrompt = _mergePrompt(
      prompt,
      lockLanguage,
      negativePrompt,
    );

    final genderNegatives = isMale
        ? 'female, feminine, girl, woman, dress, skirt, makeup, long eyelashes, feminine hair, feminine facial features'
        : 'male, masculine, boy, man, facial hair, masculine hair, masculine facial features';

    final imageUrl = await ModelsLabService.generateKontextPro(
      prompt: finalPrompt,
      negativePrompt:
          'low quality, blurry, pixelated, grainy, noisy, jpeg artifacts, '
          'changed identity, different person, altered face, warped face, '
          'bad anatomy, deformed, worst quality, $genderNegatives',
      initImageBase64: initImageBase64,
      aspectRatio: aspectRatio,
    );

    return _downloadBytes(imageUrl);
  }

  /// Step 2 — Style-only edit (on locked identity)
  ///
  /// Goal:
  /// - apply outfit/style
  /// - keep identity stable
  Future<Uint8List> generateStyledOnly(
    Uint8List identityLockedImage,
    String prompt, {
    String? negativePrompt,
    String aspectRatio = '9:16',
    bool forceDollAesthetic = false,
    bool isMale = false,
  }) async {
    final initImageBase64 =
        'data:image/png;base64,${base64Encode(identityLockedImage)}';

    final String genderLabel = isMale ? 'young boy' : 'young girl';
    final String lockLanguage = forceDollAesthetic
        ? 'Keep the same $genderLabel identity exactly. Apply the requested artistic style (e.g. superhero, comic, etc), but render the character\'s skin and hair using a glossy 3D plastic toy aesthetic.'
        : 'Keep the same $genderLabel identity exactly. Only change clothing, styling, and background if requested.';

    final finalPrompt = _mergePrompt(
      prompt,
      lockLanguage,
      negativePrompt,
    );

    final genderNegatives = isMale
        ? 'female, feminine, girl, woman, dress, skirt, makeup, long eyelashes, feminine hair, feminine facial features'
        : 'male, masculine, boy, man, facial hair, masculine hair, masculine facial features';

    final imageUrl = await ModelsLabService.generateKontextPro(
      prompt: finalPrompt,
      negativePrompt: 'changed face, different person, altered identity, '
          'bad anatomy, deformed, worst quality, uncanny valley, $genderNegatives',
      initImageBase64: initImageBase64,
      aspectRatio: aspectRatio,
    );

    return _downloadBytes(imageUrl);
  }

  /// Optimized Single-Pass Doll Mode (Main Studio)
  Future<Uint8List> generateConsolidatedDoll(
    Uint8List baseImage,
    String prompt, {
    String? negativePrompt,
    String aspectRatio = '9:16',
    bool isMale = false,
  }) async {
    final initImageBase64 = 'data:image/png;base64,${base64Encode(baseImage)}';
    final String genderNoun = isMale ? 'boy' : 'girl';
    final String genderStyle = isMale ? 'cool masculine' : 'cute feminine';

    final consolidatedPrompt = '''
$prompt
STRICTLY apply a glossy 3D plastic $genderNoun doll skin and hair texture.
PRESERVE original facial identity, features, and body proportions exactly.
MATCH skin tone exactly—DO NOT lighten or change ethnicity.
Style: $genderStyle $genderNoun doll fashion. Studio lighting.
''';


    final genderNegatives = isMale
        ? 'female, feminine, girl, woman, dress, skirt, makeup, long eyelashes, feminine hair, feminine facial features'
        : 'male, masculine, boy, man, facial hair, masculine hair, masculine facial features';

    final imageUrl = await ModelsLabService.generateKontextPro(
      prompt: consolidatedPrompt,
      negativePrompt: (negativePrompt ??
              'low quality, blurry, pixelated, grainy, noisy, jpeg artifacts, '
                  'changed identity, different person, altered face, warped face, '
                  'bad anatomy, deformed, worst quality, realistic human skin texture') +
          ', $genderNegatives',
      initImageBase64: initImageBase64,
      aspectRatio: aspectRatio,
    );

    return _downloadBytes(imageUrl);
  }

  // ---- helpers ----

  String _mergePrompt(String prompt, String lockLine, String? negative) {
    return '$prompt\n\n$lockLine';
  }

  Future<Uint8List> _downloadBytes(String url) async {
    const maxRetries = 15; // Increased retries for shorter delays
    const initialDelay = Duration(milliseconds: 800);
    const gradualDelay = Duration(milliseconds: 1500);

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final resp = await http.get(Uri.parse(url));
        if (resp.statusCode >= 200 && resp.statusCode < 300) {
          debugPrint(
              '[Download] ✅ Got ${resp.bodyBytes.length} bytes on attempt $attempt');
          return resp.bodyBytes;
        }

        // Handle 404 (propagation delay)
        if (resp.statusCode == 404) {
          debugPrint('[Download] ⏳ 404 on attempt $attempt, retrying...');
        } else {
          debugPrint('[Download] ❌ HTTP ${resp.statusCode} on attempt $attempt');
        }
      } catch (e) {
        debugPrint('[Download] ❌ Error on attempt $attempt: $e');
      }

      if (attempt < maxRetries) {
        // Faster polling for the first 5 attempts, then slow down
        await Future.delayed(attempt <= 5 ? initialDelay : gradualDelay);
      }
    }

    throw Exception('Failed to download image after $maxRetries attempts');
  }
}
