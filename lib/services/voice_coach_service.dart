// lib/services/voice_coach_service.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sofi_test_connect/services/audio_service.dart';
import 'package:sofi_test_connect/services/remote_debug_logger.dart';
// Conditional TTS helper for web (uses Web Speech API when available)
import 'package:sofi_test_connect/services/tts_platform_stub.dart'
    if (dart.library.html) 'package:sofi_test_connect/services/tts_platform_web.dart';

/// Lightweight, name-aware voice coach using on-device TTS.
/// - Persists preferences with SharedPreferences
/// - Ducks background/generation music while speaking
/// - Offers event-specific prompts (generation start/success/error)
class VoiceCoachService {
  VoiceCoachService._();
  static final VoiceCoachService instance = VoiceCoachService._();

  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;
  bool _enabled = true; // opt-in default; can be toggled in settings later
  bool _sayName = true;
  String? _name; // Preferred name
  String? _phonetic; // Optional phonetic spelling
  String? _voiceIdentifier; // Platform voice name/id
  final String _language = 'en-US';
  final double _rate = 0.95; // Natural pacing
  final double _pitch = 1.03; // Slightly bright
  DateTime _lastUtter = DateTime.fromMillisecondsSinceEpoch(0);
  bool _introSpokenThisSession = false; // prevent repeating welcome

  // Frequency control: minimal | helpful | verbose
  String _frequency = 'helpful';

  // Public getters
  bool get enabled => _enabled;
  bool get sayName => _sayName;
  String? get name => _name;
  String? get phonetic => _phonetic;
  String get frequency => _frequency;

  // Queue/coalescing state
  final List<String> _queue = <String>[];
  Timer? _debounceTimer;
  bool _speaking = false;
  String? _lastText; // for de-duping
  bool _generationBusy = false; // gate to silence during heavy work
  String? _pendingAfterBusy; // last message to deliver after busy period
  // Exposed speaking/hold state to coordinate with UI and heavy tasks
  final ValueNotifier<bool> speakingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> exclusiveHoldNotifier = ValueNotifier<bool>(false);
  DateTime _holdUntil = DateTime.fromMillisecondsSinceEpoch(0);

  // Public state getters
  bool get isSpeaking => _speaking;
  bool get isExclusiveHoldActive => DateTime.now().isBefore(_holdUntil);

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    await _loadPrefs();

    try {
      // TTS base configuration optimized for iOS
      await _tts.setLanguage(_language);
      await _tts.setSpeechRate(_rate);
      await _tts.setPitch(_pitch);
      await _tts.awaitSpeakCompletion(true);
      
      // iOS-specific: Set volume to ensure audio plays through speaker
      if (!kIsWeb) {
        try {
          await _tts.setVolume(1.0);
        } catch (_) {}
      }

      // Pick a female en-US voice if available (iOS has great Siri voices)
      await _pickBestVoice();

      _tts.setStartHandler(() {
        debugPrint('[VoiceCoach] speaking started');
        _speaking = true;
        speakingNotifier.value = true;
      });
      _tts.setCompletionHandler(() {
        debugPrint('[VoiceCoach] speaking completed');
        _speaking = false;
        speakingNotifier.value = false;
        if (!isExclusiveHoldActive) exclusiveHoldNotifier.value = false;
        _pumpQueue();
      });
      _tts.setCancelHandler(() {
        debugPrint('[VoiceCoach] speaking cancelled');
        _speaking = false;
        speakingNotifier.value = false;
        if (!isExclusiveHoldActive) exclusiveHoldNotifier.value = false;
        _pumpQueue();
      });
      _tts.setErrorHandler((msg) {
        debugPrint('[VoiceCoach] TTS error: $msg');
        unawaited(RemoteDebugLogger.instance.logAudio('TTS_ERROR', msg));
      });
    } catch (e, st) {
      debugPrint('[VoiceCoach] init failed: $e\n$st');
      unawaited(RemoteDebugLogger.instance.logError('VoiceCoach init failed', e, st));
    }
  }

  Future<void> _pickBestVoice() async {
    try {
      final voices = await _tts.getVoices;
      if (voices is List) {
        // Score voices to strongly prefer female English, then any English, then anything
        Map<String, dynamic>? best;
        int bestScore = -9999;
        const femaleNameHints = <String>{
          // iOS common female voices
          'samantha', 'victoria', 'karen', 'moira', 'serena', 'tessa', 'ava', 'siri',
          // Google/Android style identifiers often include x-... with gender hints
          'female', 'en-us-x',
          // Edge/Windows
          'aria', 'zira',
          // Misc
          'joanna', 'emma', 'amy', 'olivia', 'linda', 'salli',
        };

        for (final v in voices) {
          if (v is Map) {
            final nameRaw = (v['name'] ?? '').toString();
            final localeRaw = (v['locale'] ?? '').toString();
            final genderRaw = (v['gender'] ?? '').toString();
            final name = nameRaw.toLowerCase();
            final locale = localeRaw.toLowerCase();
            final gender = genderRaw.toLowerCase();

            var score = 0;
            // Locale preference
            if (locale.startsWith('en')) score += 10;
            if (locale.contains('us')) score += 5;
            // Gender/name hints
            if (gender.contains('female')) score += 50;
            if (name.contains('female')) score += 40;
            if (femaleNameHints.any((h) => name.contains(h))) score += 30;

            // Slightly prefer higher quality voices if exposed
            final quality = (v['quality'] ?? '').toString().toLowerCase();
            if (quality.contains('enhanced') || quality.contains('network')) score += 3;

            if (score > bestScore) {
              bestScore = score;
              best = Map<String, dynamic>.from(v);
            }
          }
        }

        best ??= voices.cast<Map>().cast<Map<String, dynamic>?>().firstWhere(
          (m) => (m?['locale']?.toString().toLowerCase() ?? '').startsWith('en'),
          orElse: () => null,
        );
        if (best != null) {
          _voiceIdentifier = best['name']?.toString();
          try {
            // Not all platforms require setVoice; handle gracefully
            await _tts.setVoice({
              'name': (_voiceIdentifier ?? (best['name']?.toString() ?? '')),
              'locale': (best['locale']?.toString() ?? _language),
            });
          } catch (_) {}
          debugPrint('[VoiceCoach] voice: ${best['name']} (${best['locale']})');
        }
      }
    } catch (e) {
      debugPrint('[VoiceCoach] getVoices failed: $e');
    }
  }

  Future<void> _loadPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool('vc_enabled') ?? _enabled;
      _sayName = prefs.getBool('vc_say_name') ?? _sayName;
      _name = prefs.getString('vc_name');
      _phonetic = prefs.getString('vc_name_phonetic');
      _frequency = prefs.getString('vc_freq') ?? _frequency;
    } catch (e) {
      debugPrint('[VoiceCoach] prefs load failed: $e');
    }
  }

  Future<void> _savePrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('vc_enabled', _enabled);
      await prefs.setBool('vc_say_name', _sayName);
      if (_name != null) await prefs.setString('vc_name', _name!);
      if (_phonetic != null) await prefs.setString('vc_name_phonetic', _phonetic!);
      await prefs.setString('vc_freq', _frequency);
    } catch (e) {
      debugPrint('[VoiceCoach] prefs save failed: $e');
    }
  }

  // Public setters
  Future<void> setEnabled(bool value) async { _enabled = value; await _savePrefs(); }
  Future<void> setSayName(bool value) async { _sayName = value; await _savePrefs(); }
  Future<void> setName(String value) async { _name = value.trim(); await _savePrefs(); }
  Future<void> setPhonetic(String? value) async { _phonetic = value?.trim(); await _savePrefs(); }
  Future<void> setFrequency(String value) async { _frequency = value; await _savePrefs(); }

  /// Inform the service that image generation (or other heavy operation)
  /// is in progress. While busy, we suppress mid-stream TTS spam and only
  /// keep the latest requested line to speak right after the busy window.
  void setGenerating(bool value) {
    _generationBusy = value;
    if (!value) {
      // Drain any pending line kept during busy state
      if (_pendingAfterBusy != null) {
        _enqueue(_pendingAfterBusy!);
        _pendingAfterBusy = null;
      }
      _pumpQueue();
    }
  }

  // Speak helpers (queued + coalesced)
  Future<void> speak(String text) async {
    try {
      await initialize();
      if (!_enabled) return;

      // If generation is in progress, coalesce to the latest line after finish
      if (_generationBusy) {
        _pendingAfterBusy = text;
        return;
      }

      // Frequency throttle (minimal: 8s, helpful: 5s, verbose: 2s)
      final now = DateTime.now();
      final gapMs = _frequency == 'minimal' ? 8000 : _frequency == 'verbose' ? 2000 : 5000;
      if (now.difference(_lastUtter).inMilliseconds < gapMs) return;

      // Build name prefix
      final String prefix;
      if (_sayName && (_name != null && _name!.isNotEmpty)) {
        final p = _phonetic ?? _name!;
        prefix = '$p, ';
      } else {
        prefix = '';
      }

      final utterance = '$prefix$text';

      // Enqueue with coalescing
      _enqueue(utterance);
      _lastUtter = now;
    } catch (e, st) {
      debugPrint('[VoiceCoach] speak outer error: $e\n$st');
    }
  }

  // Add an item to the queue with de-dup and short debounce to absorb bursts
  void _enqueue(String text) {
    // Drop if identical to last spoken/queued
    if (text.trim().isNotEmpty && (text == _lastText || (_queue.isNotEmpty && _queue.last == text))) {
      return;
    }
    _lastText = text;

    // Coalesce rapid fire within 150ms
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 150), () {
      _queue.clear();
      _queue.add(text);
      _pumpQueue();
    });
  }

  void _pumpQueue() {
    if (_speaking) return;
    if (_queue.isEmpty) return;
    final next = _queue.removeAt(0);
    _speaking = true;
    speakingNotifier.value = true;
    _speakNow(next).whenComplete(() {
      _speaking = false;
      speakingNotifier.value = false;
      if (!isExclusiveHoldActive) exclusiveHoldNotifier.value = false;
      // Stagger slightly to avoid WebKit race conditions
      Future.delayed(const Duration(milliseconds: 120), _pumpQueue);
    });
  }

  Future<void> _speakNow(String text) async {
    // Duck music/loop to avoid clashes
    await AudioService.instance.setDucking(true);
    try {
      if (kIsWeb) {
        // On web, cancel any ongoing speech explicitly before starting a new one
        final ok = await ttsPlatformSpeak(
          text,
          lang: _language,
          rate: _rate,
          pitch: _pitch,
        );
        if (!ok) debugPrint('[VoiceCoach] Web speech not available');
      } else {
        try { await _tts.stop(); } catch (_) {}
        await _tts.speak(text);
      }
    } catch (e, st) {
      debugPrint('[VoiceCoach] speak failed: $e');
      unawaited(RemoteDebugLogger.instance.logError('TTS speak failed', e, st));
    } finally {
      // Give TTS a moment to fully complete on some platforms, then unduck
      unawaited(Future<void>.delayed(const Duration(milliseconds: 150)).then((_) => AudioService.instance.setDucking(false)));
    }
  }

  // Event-driven prompts
  static const List<String> _startShort = [
    'Got it. Generating now.',
    'One moment, working on it.',
    'Okay, creating your look.',
    'On it — generating.',
  ];
  static const List<String> _successShort = [
    'Done. Want another?',
    'All set. Save or tweak?',
    'Nice. Try a new background.',
    'Looking good. Add accessories?',
    'Finished. What next?',
  ];
  static const List<String> _errorShort = [
    'Didn\'t go through. Try again.',
    'Network snag — one more try.',
    'Hmm, that failed. Try once more.',
  ];

  Future<void> onGenerationStart() async {
    if (!_enabled) return;
    await speakExclusive(capitalize(_pick(_startShort)));
  }

  Future<void> onGenerationSuccess() async {
    if (!_enabled) return;
    await speakExclusive(capitalize(_pick(_successShort)));
  }

  Future<void> onGenerationError() async {
    if (!_enabled) return;
    await speakExclusive(capitalize(_pick(_errorShort)));
  }

  String _pick(List<String> items) {
    if (items.isEmpty) return '';
    final i = DateTime.now().millisecondsSinceEpoch % items.length;
    return items[i];
  }

  String capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  /// Speaks a short, once-per-session welcome guide.
  /// Respects the enabled toggle, name preference, and platform differences.
  Future<void> speakWelcomeIntro() async {
    if (_introSpokenThisSession) return;
    if (!_enabled) return;
    _introSpokenThisSession = true;
    // Keep it short and actionable.
    const script =
        'Welcome to Sofi Studio. Tap Design Studio or the options button to browse outfits and poses. '
        'Type your idea or tap the mic, then press Generate to create. '
        'Save with the heart, and share using the share button.';
    await speak(script);
  }

  /// Speak and enter a brief exclusive-hold window to avoid overlapping heavy work.
  /// The hold lasts for [holdMs] after the call (best-effort on web where completion
  /// callbacks are unreliable). UI can observe [exclusiveHoldNotifier].
  Future<void> speakExclusive(String text, {int holdMs = 2500}) async {
    try {
      final until = DateTime.now().add(Duration(milliseconds: holdMs));
      if (until.isAfter(_holdUntil)) {
        _holdUntil = until;
        exclusiveHoldNotifier.value = true;
      }
      await speak(text);
    } catch (e) {
      debugPrint('[VoiceCoach] speakExclusive failed: $e');
    }
  }
}
