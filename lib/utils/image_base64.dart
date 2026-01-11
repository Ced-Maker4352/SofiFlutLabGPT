// lib/utils/image_base64.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

/// Convert a bundled asset (your stage PNG) into Base64 for ModelsLab.
Future<String> assetToBase64(String assetPath) async {
  final data = await rootBundle.load(assetPath);
  final bytes = data.buffer.asUint8List();
  return base64Encode(bytes);
}

/// Convert an image URL (e.g. previous generation) into Base64.
Future<String> urlToBase64(String imageUrl) async {
  final response = await http.get(Uri.parse(imageUrl));
  if (response.statusCode != 200) {
    throw Exception("Failed to download image from URL");
  }
  return base64Encode(response.bodyBytes);
}

/// Convert raw bytes (e.g. from file picker) into Base64.
String bytesToBase64(Uint8List bytes) {
  return base64Encode(bytes);
}
