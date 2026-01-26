// lib/services/flux_generation_service.dart
//
// FLUX Kontext Pro generation service for human photorealism
// Uses editorial-grade model for magazine-quality portraits

import 'dart:typed_data';
import 'package:http/http.dart' as http;

import 'models_lab_service.dart';

class FluxGenerationService {
  const FluxGenerationService();

  /// Generate human photorealistic portrait using FLUX Kontext Pro
  /// 
  /// This method provides:
  /// - Editorial-grade photorealism
  /// - Strong facial identity preservation (strength: 0.35)
  /// - Professional studio quality output
  /// - High resolution support (up to 1536x2048)
  /// 
  /// Use this for "Human" and "Artistic" modes instead of TwoStepGenerationService
  Future<Uint8List> generateHumanPortrait({
    required Uint8List selfieBytes,
    required String prompt,
    int width = 1024,
    int height = 1536,
  }) async {
    // Call FLUX Kontext Pro endpoint
    final imageUrl = await ModelsLabService.generateHumanFlux(
      initImageBytes: selfieBytes,
      prompt: prompt,
    );

    // Download the generated image bytes
    return _downloadBytes(imageUrl);
  }

  /// Internal helper to download image bytes from URL
  Future<Uint8List> _downloadBytes(String url) async {
    final uri = Uri.parse(url);
    final resp = await http.get(uri);

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception(
        'Failed to download FLUX generated image ($url): ${resp.statusCode}',
      );
    }

    return resp.bodyBytes;
  }
}
