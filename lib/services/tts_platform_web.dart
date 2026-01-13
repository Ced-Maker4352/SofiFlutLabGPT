// lib/services/tts_platform_web.dart
//
// Web TTS using the browser SpeechSynthesis API.
// This version is designed to COMPILE in FlutLab/DreamFlow environments.

@deprecated
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:flutter/foundation.dart';

html.SpeechSynthesisVoice? _cachedVoice;

html.SpeechSynthesisVoice? _pickVoice(html.SpeechSynthesis synth,
    {String? lang}) {
  try {
    final voices = synth.getVoices();
    if (voices.isEmpty) return null;

    const femaleHints = <String>[
      'female',
      'samantha',
      'victoria',
      'karen',
      'moira',
      'serena',
      'tessa',
      'aria',
      'zira',
      'joanna',
      'emma',
      'amy',
      'olivia',
      'linda',
      'salli',
      'google uk english female',
    ];

    html.SpeechSynthesisVoice? best;
    var bestScore = -9999;

    for (final v in voices) {
      final name = (v.name ?? '').toLowerCase();
      final vlang = (v.lang ?? '').toLowerCase();
      var score = 0;

      if (vlang.startsWith('en')) score += 10;
      if (lang != null && vlang.startsWith(lang.toLowerCase())) score += 8;
      if (vlang.contains('us')) score += 5;
      if (femaleHints.any(name.contains)) score += 50;
      if (name.contains('google')) score += 3;

      if (score > bestScore) {
        bestScore = score;
        best = v;
      }
    }
    return best;
  } catch (_) {
    return null;
  }
}

Future<bool> ttsPlatformSpeak(
  String text, {
  String? lang,
  double? rate,
  double? pitch,
}) async {
  try {
    final synth = html.window.speechSynthesis;
    if (synth == null) return false;

    final u = html.SpeechSynthesisUtterance(text);
    if (lang != null) u.lang = lang;
    if (rate != null) u.rate = rate.clamp(0.1, 2.0);
    if (pitch != null) u.pitch = pitch.clamp(0.1, 2.0);

    final isSpeaking = (synth.speaking ?? false) == true;
    if (isSpeaking) synth.cancel();

    _cachedVoice ??= _pickVoice(synth, lang: lang);
    if (_cachedVoice != null) {
      try {
        u.voice = _cachedVoice;
      } catch (_) {
        // Some browsers disallow setting voice until voices are loaded.
      }
    }

    synth.speak(u);
    return true;
  } catch (e) {
    debugPrint('[TTS] speak failed: $e');
    return false;
  }
}
