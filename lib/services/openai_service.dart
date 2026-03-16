import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// A service to handle AI generation using standard OpenAI-compatible endpoints.
/// This works for Ollama, Qwen, Groq, Together, etc.
class OpenAiService {
  final String baseUrl;
  final String apiKey;
  final String model;

  OpenAiService({
    required this.baseUrl,
    required this.apiKey,
    required this.model,
  });

  /// Generates an image using an OpenAI-compatible DALL-E endpoint.
  Future<Uint8List?> generateImage({
    required String prompt,
    String aspectRatio = '1024x1024',
  }) async {
    try {
      debugPrint('[OpenAiService] Generating image via $baseUrl ($model)...');
      
      final url = Uri.parse('$baseUrl/images/generations');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (apiKey.isNotEmpty) 'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': model,
          'prompt': prompt,
          'size': aspectRatio,
          'n': 1,
          'response_format': 'b64_json',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final b64 = data['data']?[0]?['b64_json'];
        if (b64 != null) {
          return base64Decode(b64);
        }
      }

      debugPrint('[OpenAiService] ❌ Image Generation Error: ${response.body}');
      return null;
    } catch (e) {
      debugPrint('[OpenAiService] ❌ Image Gen Exception: $e');
      return null;
    }
  }

  /// Generates text using standard chat/completions endpoint.
  Future<String?> generateText(String prompt) async {
    try {
      final url = Uri.parse('$baseUrl/chat/completions');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (apiKey.isNotEmpty) 'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': model,
          'messages': [
            {'role': 'user', 'content': prompt}
          ],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices']?[0]?['message']?['content'];
      }

      debugPrint('[OpenAiService] ❌ Text Generation Error: ${response.body}');
      return null;
    } catch (e) {
      debugPrint('[OpenAiService] ❌ Text Gen Exception: $e');
      return null;
    }
  }
}
