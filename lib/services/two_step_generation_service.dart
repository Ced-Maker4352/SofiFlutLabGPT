import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

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
  }) async {
    final initImageBase64 = 'data:image/png;base64,${base64Encode(baseImage)}';

    final finalPrompt = _mergePrompt(
      prompt,
      // extra lock language helps reduce drift
      'Preserve the same person identity exactly. Do not change facial structure, age, ethnicity, skin tone, or proportions.',
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
  }) async {
    final initImageBase64 =
        'data:image/png;base64,${base64Encode(identityLockedImage)}';

    final finalPrompt = _mergePrompt(
      prompt,
      'Keep the same identity exactly. Only change clothing, styling, and background if requested.',
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
