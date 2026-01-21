import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class ModelsLabService {
  ModelsLabService._();

  // Cloud Run backend
  static const String _backendBaseUrl =
      'https://us-central1-sofi-saint-app.cloudfunctions.net';

  static Uri _generateUri() => Uri.parse('$_backendBaseUrl/generateImageFunc');

  /// Default negative prompt to prevent common issues like facial distortion
  static const String _defaultNegativePrompt = 
    'distorted face, distorted eyes, asymmetrical eyes, cross-eyed, uneven eyes, '
    'distorted lips, distorted mouth, distorted nose, deformed face, '
    'blurry face, low quality face, bad anatomy, extra limbs, '
    'mutated hands, bad hands, bad fingers, fused fingers, '
    'ugly, deformed, noisy, blurry, low quality, grainy, '
    'unnatural skin, unnatural creases, wrinkled clothing artifacts';

  /// One-step image-to-image generation
  static Future<String> generateFromImage({
    required Uint8List initImageBytes,
    required String prompt,
    String? negativePrompt,
  }) async {
    if (initImageBytes.isEmpty) {
      throw Exception('Init image bytes are empty');
    }

    final String initImageDataUrl =
        'data:image/png;base64,${base64Encode(initImageBytes)}';

    // Combine custom negative prompt with defaults
    final effectiveNegativePrompt = negativePrompt != null && negativePrompt.isNotEmpty
        ? '$negativePrompt, $_defaultNegativePrompt'
        : _defaultNegativePrompt;

    final response = await http.post(
      _generateUri(),
      headers: const {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'prompt': prompt,
        'negative_prompt': effectiveNegativePrompt,
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
