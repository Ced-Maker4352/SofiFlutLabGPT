import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class ModelsLabService {
  ModelsLabService._();

  // Cloud Run backend
  static const String _backendBaseUrl =
      'https://us-central1-sofi-saint-app.cloudfunctions.net';

  static Uri _generateUri() => Uri.parse('$_backendBaseUrl/generateImageFunc');

  /// One-step image-to-image generation
  static Future<String> generateFromImage({
    required Uint8List initImageBytes,
    required String prompt,
  }) async {
    if (initImageBytes.isEmpty) {
      throw Exception('Init image bytes are empty');
    }

    final String initImageDataUrl =
        'data:image/png;base64,${base64Encode(initImageBytes)}';

    final response = await http.post(
      _generateUri(),
      headers: const {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'prompt': prompt,
        'init_image': initImageDataUrl,
        'model_id': 'seededit-i2i',
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Backend /generate failed (${response.statusCode}): ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid backend response: ${response.body}');
    }

    final imageUrl = decoded['image_url'];
    if (imageUrl is! String || imageUrl.isEmpty) {
      throw Exception('Backend missing image_url: ${response.body}');
    }

    return imageUrl;
  }
}
