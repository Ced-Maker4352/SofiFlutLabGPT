import 'dart:typed_data';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';

/// Mobile implementation: saves to Photos/Gallery using image_gallery_saver_plus
Future<void> saveImageBytes(Uint8List bytes, String fileName) async {
  final result = await ImageGallerySaverPlus.saveImage(
    bytes,
    quality: 100,
    name: fileName,
  );
  
  if (result == null || result['isSuccess'] != true) {
    throw Exception('Save to Photos failed');
  }
}
