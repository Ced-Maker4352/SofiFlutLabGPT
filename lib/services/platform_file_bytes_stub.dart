import 'dart:typed_data';

/// Fallback implementation if no platform condition matches.
Future<Uint8List> readFileBytes(String path) async {
  throw UnsupportedError('readFileBytes is not supported on this platform.');
}
