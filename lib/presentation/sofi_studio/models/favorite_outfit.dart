// lib/presentation/sofi_studio/models/favorite_outfit.dart

import 'dart:convert';
import 'dart:typed_data';

class FavoriteOutfit {
  final Uint8List? imageBytes;   // Optional: full image bytes
  final String? imageUrl;        // Optional: cloud URL
  final String prompt;
  final DateTime timestamp;

  FavoriteOutfit({
    this.imageBytes,
    this.imageUrl,
    required this.prompt,
    required this.timestamp,
  }) : assert(imageBytes != null || imageUrl != null, 'Must provide either bytes or URL');

  // JSON-safe serialization (base64 for bytes)
  Map<String, dynamic> toJson() {
    return {
      if (imageBytes != null) "imageBase64": base64Encode(imageBytes!),
      if (imageUrl != null) "imageUrl": imageUrl,
      "prompt": prompt,
      "timestamp": timestamp.toIso8601String(),
    };
  }

  factory FavoriteOutfit.fromJson(Map<String, dynamic> json) {
    final String? b64 = json["imageBase64"] as String?;
    return FavoriteOutfit(
      imageBytes: b64 != null ? base64Decode(b64) : null,
      imageUrl: json["imageUrl"] as String?,
      prompt: json["prompt"] as String? ?? "",
      timestamp: DateTime.parse(json["timestamp"] as String),
    );
  }
}
