import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

import 'package:sofi_test_connect/services/user_preferences_service.dart';
import 'models_lab_service.dart';

class TwoStepGenerationService {
  const TwoStepGenerationService();

  /// Step 1 — Identity lock
  ///
  /// Goal:
  /// - lock face + proportions
  /// - minimal style change
  Future<Uint8List> runStep1IdentityLock(
    Uint8List baseImage,
    String prompt, {
    String? negativePrompt,
    String aspectRatio = '9:16',
    bool forceDollAesthetic = false,
  }) async {
    final initImageBase64 = 'data:image/png;base64,${base64Encode(baseImage)}';

    final String lockLanguage = forceDollAesthetic
        ? 'Preserve the same person facial identity exactly, but strictly apply the 3D toy plastic skin texture.'
        : 'Preserve the same person identity exactly. Do not change facial structure, age, ethnicity, skin tone, or proportions.';

    final finalPrompt = _mergePrompt(
      prompt,
      lockLanguage,
      negativePrompt,
    );

    final imageUrl = await ModelsLabService.generateKontextPro(
      prompt: finalPrompt,
      negativePrompt:
          'low quality, blurry, pixelated, grainy, noisy, jpeg artifacts, '
          'changed identity, different person, altered face, warped face, '
          'bad anatomy, deformed, worst quality',
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
  }) async {
    final initImageBase64 =
        'data:image/png;base64,${base64Encode(identityLockedImage)}';

    final String lockLanguage = forceDollAesthetic
        ? 'Keep the same identity exactly. Apply the requested artistic style (e.g. superhero, comic, etc), but render the character\'s skin and hair using a glossy 3D plastic toy aesthetic.'
        : 'Keep the same identity exactly. Only change clothing, styling, and background if requested.';

    final finalPrompt = _mergePrompt(
      prompt,
      lockLanguage,
      negativePrompt,
    );

    final imageUrl = await ModelsLabService.generateKontextPro(
      prompt: finalPrompt,
      negativePrompt: 'changed face, different person, altered identity, '
          'bad anatomy, deformed, worst quality, uncanny valley',
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
    const maxRetries = 5;
    const retryDelay = Duration(seconds: 2);

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      final resp = await http.get(Uri.parse(url));
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        debugPrint('[Download] ✅ Got ${resp.bodyBytes.length} bytes on attempt $attempt');
        return resp.bodyBytes;
      }

      // If 404, the CDN file may not have propagated yet — retry
      if (resp.statusCode == 404 && attempt < maxRetries) {
        debugPrint('[Download] ⏳ 404 on attempt $attempt, retrying in ${retryDelay.inSeconds}s...');
        await Future.delayed(retryDelay);
        continue;
      }

      throw Exception(
          'Failed to download generated image ($url): ${resp.statusCode}');
    }

    throw Exception('Failed to download image after $maxRetries attempts');
  }
}
