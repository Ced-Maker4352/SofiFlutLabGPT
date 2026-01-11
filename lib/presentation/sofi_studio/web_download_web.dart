import 'package:web/web.dart' as web;
import 'dart:convert';
import 'package:flutter/foundation.dart';

// Uses DOM APIs to trigger a client-side download.
void downloadImageBytesImpl(Uint8List bytes, String name) {
  try {
    final b64 = base64Encode(bytes);
    final url = 'data:image/png;base64,$b64';

    final anchor = web.document.createElement('a');
    anchor.setAttribute('href', url);
    anchor.setAttribute('download', name);

    web.document.body?.appendChild(anchor);
    // Use dynamic call to avoid strict DOM typing issues across web interop
    (anchor as dynamic).click();
    anchor.remove();
  } catch (e) {
    debugPrint('[WebDownload] Failed to trigger download: $e');
  }
}