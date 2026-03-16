import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;

/// A service to handle AI generation using Google Gemini (via Google AI Studio).
/// This allows users to use their own API keys to save project credits.
class GeminiService {
  final String apiKey;

  GeminiService({required this.apiKey});

  /// Generates an image using Gemini (Imagen model).
  /// Note: As of current google_generative_ai versions, Imagen support is evolving.
  /// We'll focused on text-to-image or image-to-image prompts.
  Future<Uint8List?> generateImage({
    required String prompt,
    Uint8List? initImage,
    String? negativePrompt,
    String aspectRatio = '9:16',
  }) async {
    try {
      debugPrint('[GeminiService] Generating image with custom API key...');
      
      // Initialize Gemini Model
      // Using 'gemini-1.5-flash' for general tasks or 'imagen-3' if available/supported
      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: apiKey,
      );

      // Construct content
      final content = [
        Content.multi([
          TextPart(prompt),
          if (initImage != null) DataPart('image/png', initImage),
        ])
      ];

      // Note: Full Imagen API integration in google_generative_ai may require 
      // specific model names or beta features. We'll start with text/multi-modal.
      final response = await model.generateContent(content);
      
      // If the response contains an image (common in some Gemini versions for Imagen),
      // we would extract it here. Otherwise, Gemini might return a URL or text.
      // For now, we'll log the response and handle accordingly.
      debugPrint('[GeminiService] Response: ${response.text}');

      // Placeholder: If Gemini returns a URL in text, we download it.
      // If it returns bytes directly in a Part, we use them.
      for (var candidate in response.candidates) {
        for (var part in candidate.content.parts) {
          if (part is DataPart) {
            return part.bytes;
          }
        }
      }

      return null;
    } catch (e) {
      debugPrint('[GeminiService] ❌ Error: $e');
      rethrow;
    }
  }

  /// Generates text/prompts (e.g., for Voice Coach or refinement).
  Future<String?> generateText(String prompt) async {
    try {
      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: apiKey,
      );
      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);
      return response.text;
    } catch (e) {
      debugPrint('[GeminiService] ❌ Text Gen Error: $e');
      return null;
    }
  }
}
