import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

class ModelsLabService {
  static final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'us-central1');

  /// Generates a photorealistic human image using flux-kontext-pro via the human-specific endpoint.
  static Future<String> generateHumanFlux({
    required Uint8List initImageBytes,
    required String prompt,
    String? negativePrompt,
    int width = 768,
    int height = 1024,
  }) async {
    debugPrint('[ModelsLab] Calling generateHumanFlux...');

    final String initImageBase64 =
        'data:image/png;base64,${base64Encode(initImageBytes)}';

    final callable = _functions.httpsCallable(
      'generateImageFunc', // Map to the existing robust function for now
      options: HttpsCallableOptions(timeout: const Duration(minutes: 5)),
    );

    final result = await callable.call({
      'prompt': prompt,
      if (negativePrompt != null) 'negative_prompt': negativePrompt,
      'initImageBase64': initImageBase64,
      'width': width,
      'height': height,
      'strength': 0.35, // Lock identity for human photorealism
    });

    final data = Map<String, dynamic>.from(result.data as Map);

    if (data['ok'] != true) {
      debugPrint('[ModelsLab] ❌ Human Generation Error: $data');
      throw Exception(
          'Human generation failed: ${data['message'] ?? data.toString()}');
    }

    return data['imageUrl'];
  }

  /// Generates an image using flux-kontext-pro (V7 API).
  ///
  /// flux-kontext-pro is an instruction-following edit model.
  static Future<String> generateKontextPro({
    required String prompt,
    String? negativePrompt,
    required String initImageBase64,
    String aspectRatio = '9:16',
    int? seed,
    double? strength,
  }) async {
    debugPrint('[ModelsLab] Calling flux-kontext-pro via generateImageFunc...');
    debugPrint(
        '[ModelsLab] Prompt: ${prompt.substring(0, prompt.length.clamp(0, 120))}...');

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
      if (strength != null) 'strength': strength,
    });

    final data = Map<String, dynamic>.from(result.data as Map);

    if (data['ok'] != true) {
      debugPrint('[ModelsLab] ❌ Generation Error Data: $data');
      throw Exception(
          'Generation failed: ${data['message'] ?? data.toString()}');
    }

    final imageUrl = data['imageUrl'];
    if (imageUrl == null || imageUrl is! String || imageUrl.isEmpty) {
      throw Exception('No imageUrl returned from backend.');
    }

    debugPrint('[ModelsLab] ✅ Got imageUrl: $imageUrl');
    return imageUrl;
  }
}

