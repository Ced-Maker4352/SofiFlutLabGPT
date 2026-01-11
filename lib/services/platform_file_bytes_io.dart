import 'dart:io';
import 'dart:typed_data';

/// Reads a local file at [path] and returns its contents as bytes.
/// IO implementation (Android/iOS/macOS/Windows/Linux).
Future<Uint8List> readFileBytes(String path) async {
  final bytes = await File(path).readAsBytes();
  return bytes;
}
