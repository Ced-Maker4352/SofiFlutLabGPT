// lib/services/two_step_generation_service.dart
//
// Two-step pipeline:
// Step 1: Identity lock / base generation
// Step 2: Style-only edit using the locked identity
//
// IMPORTANT:
// - Uses ONE backend function
// - Uses ONE model (flux_headshot)
// - No human/doll switching
// - No strength / isHumanMode params
// - Style differences handled ONLY via prompt text

import 'dart:typed_data';
import 'package:http/http.dart' as http;

import 'models_lab_service.dart';

class TwoStepGenerationService {
  const TwoStepGenerationService();

  /// STEP 1: Identity lock
  /// Goal: Preserve face + proportions with high fidelity
  Future<Uint8List> runStep1IdentityLock({
    required Uint8List baseImage,
    required String prompt,
    String? negativePrompt,
  }) async {
    final finalPrompt = _mergePrompt(prompt, negativePrompt);

    final imageUrl = await ModelsLabService.generateFromImage(
      initImageBytes: baseImage,
      prompt: finalPrompt,
      isHumanMode: true, // 🔒 Identity lock always uses human mode
      guidanceScale: 7.5,
      steps: 50,
      width: 1024,
      height: 1536,
      negativePrompt:
          'low quality, low resolution, pixelated, grainy, blurry, noisy, '
          'jpeg artifacts, compression artifacts, '
          'distorted face, warped face, asymmetrical face, '
          'changed identity, different person, wrong proportions, '
          'plastic skin, waxy skin, uncanny valley, '
          'bad anatomy, deformed features, worst quality',
    );

    return _downloadBytes(imageUrl);
  }

  /// STEP 2: Style application
  /// Goal: Apply outfit / art style WITHOUT altering identity
  Future<Uint8List> generateStyledOnly({
    required Uint8List identityLockedImage,
    required String prompt,
    String? negativePrompt,
  }) async {
    final finalPrompt = _mergePrompt(prompt, negativePrompt);

    final imageUrl = await ModelsLabService.generateFromImage(
      initImageBytes: identityLockedImage,
      prompt: finalPrompt,
      isHumanMode: true, // 🔒 Style application preserves human identity
      guidanceScale: 7.5,
      steps: 45,
      width: 1024,
      height: 1536,
      negativePrompt:
          'low quality, low resolution, pixelated, grainy, blurry, noisy, '
          'jpeg artifacts, compression artifacts, '
          'changed face, different face, altered identity, '
          'changed eye color, changed nose shape, changed lips, '
          'plastic face, uncanny valley, '
          'bad anatomy, deformed features, worst quality',
    );

    return _downloadBytes(imageUrl);
  }

  // ---- helpers ----

  String _mergePrompt(String prompt, String? negative) {
    final p = prompt.trim();
    final n = (negative ?? '').trim();
    if (n.isEmpty) return p;
    return '$p\n\nNEGATIVE: $n';
  }

  Future<Uint8List> _downloadBytes(String url) async {
    final uri = Uri.parse(url);
    final resp = await http.get(uri);

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception(
        'Failed to download generated image ($url): ${resp.statusCode}',
      );
    }

    return resp.bodyBytes;
  }
}
