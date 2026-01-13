// lib/services/two_step_generation_service.dart
//
// Two-step pipeline:
// Step 1: Identity lock / full-body base
// Step 2: Style-only edit on the locked body

import 'dart:typed_data';
import 'package:http/http.dart' as http;

import 'models_lab_service.dart';

class TwoStepGenerationService {
  const TwoStepGenerationService();

  /// Step 1: Create a full-body / identity locked base from the user headshot.
  Future<Uint8List> runStep1IdentityLock({
    required Uint8List baseImage,
    required String prompt,
    String? negativePrompt,
  }) async {
    final finalPrompt = _mergePrompt(prompt, negativePrompt);

    final imageUrl = await ModelsLabService.generateFromImage(
      initImageBytes: baseImage,
      prompt: finalPrompt,
    );

    return _downloadBytes(imageUrl);
  }

  /// Step 2: Apply style-only changes to an identity-locked body image.
  Future<Uint8List> generateStyledOnly({
    required Uint8List identityLockedImage,
    required String prompt,
    String? negativePrompt,
  }) async {
    final finalPrompt = _mergePrompt(prompt, negativePrompt);

    final imageUrl = await ModelsLabService.generateFromImage(
      initImageBytes: identityLockedImage,
      prompt: finalPrompt,
    );

    return _downloadBytes(imageUrl);
  }

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
