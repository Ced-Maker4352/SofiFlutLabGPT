import 'dart:typed_data';
import 'package:sofi_test_connect/presentation/sofi_studio/web_download.dart';

/// Web implementation: triggers browser download
Future<void> saveImageBytes(Uint8List bytes, String fileName) async {
  downloadImageBytes(bytes, fileName);
}
