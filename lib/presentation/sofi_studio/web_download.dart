import 'package:flutter/foundation.dart';

import 'web_download_stub.dart'
    if (dart.library.js_interop) 'web_download_web.dart';

/// Downloads image bytes on web builds; no-op on other platforms.
void downloadImageBytes(Uint8List bytes, String name) {
  downloadImageBytesImpl(bytes, name);
}