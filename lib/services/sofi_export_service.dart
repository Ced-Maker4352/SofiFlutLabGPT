import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';

// Conditional imports for platform-specific functionality
import 'package:sofi_test_connect/services/sofi_export_mobile.dart'
    if (dart.library.html) 'package:sofi_test_connect/services/sofi_export_web.dart';

class SofiExportService {
  /// Downloads image bytes from a public/signed URL
  static Future<Uint8List> _downloadBytes(String imageUrl) async {
    final res = await http.get(Uri.parse(imageUrl));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Failed to download image (${res.statusCode})');
    }
    return res.bodyBytes;
  }

  /// SHARE
  /// - Mobile: native share sheet with image file
  /// - Web: shares link/text
  static Future<void> shareImage({
    required BuildContext context,
    required String imageUrl,
    String? shareText,
    String fileName = 'sofi_studio.png',
  }) async {
    if (kIsWeb) {
      await Share.share(
        shareText == null ? imageUrl : '$shareText\n$imageUrl',
        subject: 'Sofi Studio',
      );
      return;
    }

    final bytes = await _downloadBytes(imageUrl);
    final box = context.findRenderObject() as RenderBox?;
    final origin = box != null ? box.localToGlobal(Offset.zero) & box.size : null;

    await Share.shareXFiles(
      [
        XFile.fromData(
          bytes,
          name: fileName,
          mimeType: 'image/png',
        ),
      ],
      text: shareText ?? 'Made with Sofi Studio',
      subject: 'Sofi Studio',
      sharePositionOrigin: origin,
    );
  }

  /// SAVE TO PHOTOS / GALLERY
  /// - Mobile: saves to Photos (iOS) / Gallery (Android)
  /// - Web: triggers file download
  static Future<void> saveImage({
    required String imageUrl,
    String fileName = 'sofi_studio.png',
  }) async {
    final bytes = await _downloadBytes(imageUrl);
    await saveImageBytes(bytes, fileName);
  }
}
