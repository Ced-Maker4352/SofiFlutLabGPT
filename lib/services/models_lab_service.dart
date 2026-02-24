import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

class ModelsLabService {
  static final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// CLEAN: Single-call generation (NO polling)
  ///
  /// Backend handles:
  /// - upload init image
  /// - signed URL init_image
  /// - ModelsLab submit + poll
  /// - returns final imageUrl
  static Future<String> generateKontextPro({
    required String prompt,
    String? negativePrompt,
    required String initImageBase64,
    String aspectRatio = '9:16',
    int steps = 28,
    double guidanceScale = 7,
    int? seed,
  }) async {
    debugPrint('[ModelsLab] Calling generateImageFunc (CLEAN)...');

    final callable = _functions.httpsCallable(
      'generateImageFunc',
      options: HttpsCallableOptions(timeout: const Duration(minutes: 5)),
    );

    final result = await callable.call({
      'prompt': prompt,
      if (negativePrompt != null) 'negative_prompt': negativePrompt,
      'initImageBase64': initImageBase64,
      'aspect_ratio': aspectRatio,
      'steps': steps,
      'guidance_scale': guidanceScale,
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
