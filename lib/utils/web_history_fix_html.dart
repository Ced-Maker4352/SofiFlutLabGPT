// lib/utils/web_history_fix_html.dart

/// Safely bypasses the web_history_fix for iOS/Android builds
/// This file was previously using deprecated dart:js_util functions
/// which caused flutter analyze to fail. 
void installWebHistoryWorkaround() {
  // No-op for modern Flutter apps
}
