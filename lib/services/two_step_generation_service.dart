import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sofi_test_connect/services/models_lab_service.dart';

/// Steps for the two-phase generation pipeline.
enum GenerationStep { identityFullBody }

class TwoStepGenerationResult {
  final String step1FullBodyBase64;
  final String finalStylizedBase64;
  const TwoStepGenerationResult({required this.step1FullBodyBase64, this.finalStylizedBase64 = ''});
}

/// UI-agnostic two-step generation engine that adapts to ModelsLabService.
class TwoStepGenerationService {
  TwoStepGenerationService();

  static const String step1IdentityFullBodyPrompt = '''
FULL BODY, head-to-toe, realistic human proportions.
Standing upright, arms visible, legs visible, feet visible.
Photorealistic, studio lighting, neutral background.
Preserve facial identity exactly from the reference image.
No cartoon, no animation, no stylization.
''';

  /// Step-1: Lock identity and produce a full-body base.
  Future<TwoStepGenerationResult> runStep1IdentityLock({required String userHeadshotBase64}) async {
    final step1 = await _generate(prompt: step1IdentityFullBodyPrompt, imageBase64: userHeadshotBase64);
    if (step1.isEmpty) {
      throw Exception('Step-1 failed: empty output');
    }
    return TwoStepGenerationResult(step1FullBodyBase64: step1);
  }

  /// Step-2: Apply theme/style prompt to a locked base image.
  Future<String> generateStyledOnly({required String base64Image, required String prompt}) async {
    final out = await _generate(prompt: prompt, imageBase64: base64Image);
    if (out.isEmpty) {
      throw Exception('Style generation failed: empty output');
    }
    return out;
  }

  Future<String> _generate({required String prompt, required String imageBase64}) async {
    try {
      final Uint8List initBytes = base64Decode(imageBase64);
      final Uint8List outBytes = await ModelsLabService.generateFromImage(initImageBytes: initBytes, prompt: prompt);
      return base64Encode(outBytes);
    } catch (e, st) {
      debugPrint('TwoStepGenerationService _generate error: $e\n$st');
      rethrow;
    }
  }

  // Back-compat: simple two-step pipeline with a default Pixar-like stylization
  static const String _defaultStep2Prompt = '''
Pixar-style 3D character render.
Soft cinematic lighting, smooth materials, expressive eyes.
Preserve pose, body proportions, and outfit exactly.
Do not crop. Do not change framing.
''';

  Future<TwoStepGenerationResult> runPipeline({required String userHeadshotBase64}) async {
    final step1 = await _generate(prompt: step1IdentityFullBodyPrompt, imageBase64: userHeadshotBase64);
    if (step1.isEmpty) throw Exception('Step-1 generation failed: empty output');
    final finalImage = await _generate(prompt: _defaultStep2Prompt, imageBase64: step1);
    if (finalImage.isEmpty) throw Exception('Step-2 generation failed: empty output');
    return TwoStepGenerationResult(step1FullBodyBase64: step1, finalStylizedBase64: finalImage);
  }
}

