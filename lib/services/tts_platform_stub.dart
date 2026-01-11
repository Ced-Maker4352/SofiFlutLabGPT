// lib/services/tts_platform_stub.dart
// Stub implementation for non-web platforms.

Future<bool> ttsPlatformSpeak(String text, {String? lang, double? rate, double? pitch}) async {
  // Not supported outside web in this helper; VoiceCoachService uses flutter_tts natively.
  return false;
}
