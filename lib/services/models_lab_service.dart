import 'dart:typed_data';
import 'dart:convert';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

class ModelsLabService {
  ModelsLabService._();

  /// Firebase Functions instance (CORS-safe for Web)
  static FirebaseFunctions get _functions =>
      FirebaseFunctions.instanceFor(region: 'us-central1');

  /// Strong default negative prompt (safe for Flux)
  static const String _defaultNegativePrompt =
      'low quality, worst quality, low resolution, blurry, '
      'distorted face, warped face, asymmetrical face, '
      'bad anatomy, deformed features, uncanny valley, '
      'jpeg artifacts, noisy skin, melted face';

  /// Generic callable wrapper.
  /// Returns a String imageUrl on success.
  static Future<String> _callImageFunction(
    String functionName,
    Map<String, dynamic> payload,
  ) async {
    // 🚨 STEP 2 — Block empty prompts before Firebase call
    final prompt = payload['prompt'];
    if (prompt == null || prompt.toString().trim().isEmpty) {
      debugPrint('❌ BLOCKED: Empty prompt sent to Firebase');
      throw Exception('Generation blocked: empty prompt');
    }

    // 🔒 Force-assign cleaned prompt at last moment
    payload['prompt'] = prompt.toString().trim();

    // 🔍 STEP 3 — Log the actual payload
    debugPrint('[GEN PAYLOAD] prompt="${payload['prompt']}"');
    debugPrint('[GEN PAYLOAD] isHumanMode=${payload['isHumanMode']}');
    debugPrint('[GEN PAYLOAD] mode=${payload['mode']}');

    final callable = _functions.httpsCallable(
      functionName,
      options: HttpsCallableOptions(timeout: const Duration(seconds: 120)),
    );

    debugPrint('[ModelsLab] Calling $functionName via Firebase Callable');
    final res = await callable.call(payload);
    final data = res.data;

    // Accept common shapes:
    // { imageUrl: "..." } or { url: "..." } or { image_url: "..." } or direct string.
    if (data is String) return data;

    if (data is Map) {
      final imageUrl = data['imageUrl'] ?? data['url'] ?? data['image_url'] ?? data['image'];
      if (imageUrl is String && imageUrl.isNotEmpty) return imageUrl;
    }

    throw Exception('Unexpected function response from $functionName: $data');
  }

  /// 🔥 Main pipeline (Pixar/Doll/Anime/etc) — CORS-safe on Web
  static Future<String> generateFromImage({
    required Uint8List initImageBytes,
    required String prompt,
    required bool isHumanMode,
    double? strength,
    double? guidanceScale,
    int? steps,
    int? width,
    int? height,
    String? negativePrompt,
  }) async {
    if (initImageBytes.isEmpty) {
      throw Exception('Init image bytes are empty');
    }

    final payload = <String, dynamic>{
      'prompt': prompt,
      'initImageBase64': base64Encode(initImageBytes),

      // 🔥 FORCE correct mode handling
      'isHumanMode': isHumanMode,
      'mode': isHumanMode ? 'flux_human' : 'standard',

      // Optional tuning — backend can ignore safely
      if (strength != null) 'strength': strength,
      if (guidanceScale != null) 'guidanceScale': guidanceScale,
      if (steps != null) 'steps': steps,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (negativePrompt != null) 'negativePrompt': negativePrompt,
    };

    debugPrint('[ModelsLab] generateFromImage - isHumanMode: $isHumanMode');
    
    final functionName =
        isHumanMode ? 'generateImageFunc' : 'generateImageFunc';

    debugPrint('[ModelsLab] Calling $functionName via Firebase Callable');

    return _callImageFunction(functionName, payload);
  }

  /// ✅ Human FLUX pipeline — fixes the analyzer error AND routes via callable
  static Future<String> generateHumanFlux({
    required Uint8List initImageBytes,
    required String prompt,
  }) async {
    debugPrint('[ModelsLab] generateHumanFlux invoked');

    return generateFromImage(
      initImageBytes: initImageBytes,
      prompt: prompt,
      isHumanMode: true, // 🔒 FORCE HUMAN
    );
  }
}
