// lib/utils/web_history_fix.dart
// Provides a no-op on non-web, and a real workaround on web via conditional import.

import 'package:sofi_test_connect/utils/web_history_fix_stub.dart'
    if (dart.library.html) 'package:sofi_test_connect/utils/web_history_fix_html.dart' as impl;

/// Installs a workaround for iOS WebKit "unexpected null history state" assertion
/// by ensuring the browser history state always has a non-null object.
/// Safe to call multiple times; it will only install once.
void installWebHistoryWorkaround() => impl.installWebHistoryWorkaround();
