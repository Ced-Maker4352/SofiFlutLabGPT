// lib/services/models_lab_service.dart
//
// FINAL PRODUCTION VERSION
// • Works EXACTLY with your Cloud Run function
// • Sends base64 init image (data URL format)
// • Downloads the final image from ModelsLab output URL
// • Includes your API key inline for WEB (DreamFlow)
// • Uses .env on mobile

import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ModelsLabService {
// Your Cloud Run function endpoint
static const String _endpoint =
"https://generateimagefunc-bv6sqztnoq-uc.a.run.app";

// ================================
// API KEY HANDLING
// ================================
static String get _apiKey {
// Web uses inline key (DreamFlow preview cannot read .env)
// Native iOS/Android load from .env file for security
if (kIsWeb) {
return "vg7Asub5EQfYY4PZVm2yjLvNkSMgzawioWhTlwuLpr7jHGDhCMZNDnwdAJX8A";
}

// Native iOS: Load from .env file (bundled in assets)
final envKey = dotenv.env['MODELSLAB_API_KEY'];
if (envKey != null && envKey.isNotEmpty) {
return envKey;
}

// Fallback for native builds (same key for now - production should use .env)
return "vg7Asub5EQfYY4PZVm2yjLvNkSMgzawioWhTlwuLpr7jHGDhCMZNDnwdAJX8A";
}

// ================================
// MAIN IMAGE-TO-IMAGE FUNCTION
// ================================
static Future<Uint8List> generateFromImage({
required Uint8List initImageBytes,
required String prompt,
}) async {
if (_apiKey.isEmpty) {
throw Exception("ModelsLab API Key is missing.");
}

// Convert bytes → Base64 → `data:image/png;base64,...`
final String base64Image = base64Encode(initImageBytes);
final String dataUrl = "data:image/png;base64,$base64Image";

final Map<String, dynamic> body = {
"init_image": dataUrl,
"prompt": prompt,
"model_id": "seededit-i2i",
};

// ================================
// SEND REQUEST TO CLOUD RUN
// ================================
final response = await http.post(
Uri.parse(_endpoint),
headers: {
"Content-Type": "application/json",
"x-api-key": _apiKey,
},
body: jsonEncode(body),
);

  // Debug logging (safe)
  debugPrint("🔵 RAW STATUS: ${response.statusCode}");
  debugPrint("🔵 RAW BODY: ${response.body}");

if (response.statusCode != 200) {
throw Exception(
"ModelsLab error (${response.statusCode}): ${response.body}");
}

final Map<String, dynamic> jsonRes = json.decode(response.body);

if (jsonRes["status"] != "success") {
final msg = jsonRes["message"] ?? jsonRes["status"];
throw Exception(msg);
}

// ================================
// ModelsLab returns an array of URLs
// ================================
final List output = jsonRes["output"];
if (output.isEmpty) throw Exception("No image URLs returned.");

  final String imageUrl = output.first;
  debugPrint("🟢 Downloading: $imageUrl");

// ================================
// DOWNLOAD FINAL IMAGE BYTES
// ================================
final http.Response imgRes = await http.get(Uri.parse(imageUrl));

if (imgRes.statusCode != 200) {
throw Exception(
"Failed to download generated image: ${imgRes.statusCode}",
);
}

return imgRes.bodyBytes;
}
}
