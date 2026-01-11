import 'dart:typed_data';

/// Web does not have direct disk access by path. Use uploadBytes instead.
Future<Uint8List> readFileBytes(String path) async {
  throw UnsupportedError(
    'Reading a local file by path is not supported on web. Use uploadBytes with picked file bytes.',
  );
}
