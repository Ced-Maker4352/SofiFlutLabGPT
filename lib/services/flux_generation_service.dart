// lib/services/flux_generation_service.dart
//
// FLUX Kontext Pro generation service for human photorealism
// Uses editorial-grade model for magazine-quality portraits

import 'dart:typed_data';
import 'dart:convert';
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
  /// - Fixed 1024x1024 resolution (clamped at backend)
  /// 
  /// Use this for "Human" and "Artistic" modes instead of TwoStepGenerationService
  Future<Uint8List> generateHumanPortrait({
    required Uint8List selfieBytes,
    required String prompt,
  }) async {
    // Convert bytes to base64 with data URL prefix (backend expects this format)
    final base64Image = 'data:image/png;base64,${base64Encode(selfieBytes)}';
    
    // Call FLUX Kontext Pro endpoint (backend handles polling)
    final imageUrl = await ModelsLabService.generateKontextPro(
      prompt: prompt,
      initImageBase64: base64Image,
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
