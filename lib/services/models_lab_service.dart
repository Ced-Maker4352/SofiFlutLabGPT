import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

class ModelsLabService {
  static final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// Generates an image using flux-kontext-pro (V7 API).
  ///
  /// flux-kontext-pro is an instruction-following edit model.
  /// It understands "change the outfit, keep the face" semantics natively.
  /// Do NOT pass strength/steps/guidanceScale — the model handles this itself.
  static Future<String> generateKontextPro({
    required String prompt,
    String? negativePrompt,
    required String initImageBase64,
    String aspectRatio = '9:16',
    int? seed,
  }) async {
    debugPrint('[ModelsLab] Calling flux-kontext-pro via generateImageFunc...');
    debugPrint('[ModelsLab] Prompt: ${prompt.substring(0, prompt.length.clamp(0, 120))}...');

    final callable = _functions.httpsCallable(
      'generateImageFunc',
      options: HttpsCallableOptions(timeout: const Duration(minutes: 5)),
    );

    final result = await callable.call({
      'prompt': prompt,
      if (negativePrompt != null) 'negative_prompt': negativePrompt,
      'initImageBase64': initImageBase64,
      'aspect_ratio': aspectRatio,
      if (seed != null) 'seed': seed,
    });

    final data = Map<String, dynamic>.from(result.data as Map);

    if (data['ok'] != true) {
      throw Exception('Generation failed: ${data.toString()}');
    }

    final imageUrl = data['imageUrl'];
    if (imageUrl == null || imageUrl is! String || imageUrl.isEmpty) {
      throw Exception('No imageUrl returned from backend.');
    }

    debugPrint('[ModelsLab] ✅ Got imageUrl: $imageUrl');
    return imageUrl;
  }
}
