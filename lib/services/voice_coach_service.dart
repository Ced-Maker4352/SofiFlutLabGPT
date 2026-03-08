// lib/services/voice_coach_service.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sofi_test_connect/services/audio_service.dart';

/// Lightweight, name-aware voice coach using pre-recorded MP3 assets.
class VoiceCoachService {
  VoiceCoachService._();
  static final VoiceCoachService instance = VoiceCoachService._();

  bool _initialized = false;
  bool _enabled = true; // opt-in default
  DateTime _lastUtter = DateTime.fromMillisecondsSinceEpoch(0);
  bool _introSpokenThisSession = false;

  // Public getters
  bool get enabled => _enabled;

  final ValueNotifier<bool> speakingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> exclusiveHoldNotifier = ValueNotifier<bool>(false);
  DateTime _holdUntil = DateTime.fromMillisecondsSinceEpoch(0);

  bool get isExclusiveHoldActive => DateTime.now().isBefore(_holdUntil);

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    await _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool('vc_enabled') ?? _enabled;
    } catch (e) {
      debugPrint('[VoiceCoach] prefs load failed: $e');
    }
  }

  Future<void> _savePrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('vc_enabled', _enabled);
    } catch (e) {
      debugPrint('[VoiceCoach] prefs save failed: $e');
    }
  }

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    await _savePrefs();
  }

  /// Plays a specific voice asset
  Future<void> _play(String assetPath, {int holdMs = 2500}) async {
    if (!_enabled) return;
    
    // Throttle repeated phrases (minimally 3s between any voice)
    final now = DateTime.now();
    if (now.difference(_lastUtter).inMilliseconds < 3000) return;
    _lastUtter = now;

    try {
      speakingNotifier.value = true;
      final until = now.add(Duration(milliseconds: holdMs));
      if (until.isAfter(_holdUntil)) {
        _holdUntil = until;
        exclusiveHoldNotifier.value = true;
      }

      await AudioService.instance.playVoice(assetPath);
      
      // Auto-reset notifier after expected duration
      Future.delayed(Duration(milliseconds: holdMs), () {
        speakingNotifier.value = false;
        if (!isExclusiveHoldActive) exclusiveHoldNotifier.value = false;
      });
    } catch (e) {
      debugPrint('[VoiceCoach] play failed: $e');
    }
  }

  // --- Event-driven triggers ---

  Future<void> onGenerationStart() async {
    final variants = [
      AudioService.instance.coachStart0Path,
      AudioService.instance.coachStart1Path,
      AudioService.instance.coachStart2Path,
      AudioService.instance.coachStart3Path,
    ];
    await _play(_pick(variants));
  }

  Future<void> onGenerationSuccess() async {
    final variants = [
      AudioService.instance.coachSuccess0Path,
      AudioService.instance.coachSuccess1Path,
      AudioService.instance.coachSuccess2Path,
      AudioService.instance.coachSuccess3Path,
    ];
    await _play(_pick(variants));
  }

  Future<void> onGenerationError() async {
    await _play(AudioService.instance.coachError0Path);
  }

  Future<void> speakWelcomeIntro() async {
    if (_introSpokenThisSession || !_enabled) return;
    _introSpokenThisSession = true;
    await _play(AudioService.instance.coachIntroPath, holdMs: 6000);
  }

  /// Preview for settings page
  Future<void> playPreview() async {
    await _play(AudioService.instance.coachIntroPath, holdMs: 6000);
  }

  String _pick(List<String> items) {
    if (items.isEmpty) return '';
    final i = DateTime.now().millisecondsSinceEpoch % items.length;
    return items[i];
  }

  // Compatibility stub for any leftover calls
  Future<void> speak(String text) async {
    // We no longer support arbitrary text, but we can play a generic success/intro if needed
    debugPrint('[VoiceCoach] speak(text) no longer supported. Use event methods.');
  }

  void setGenerating(bool value) {
    // No longer needed as we don't queue arbitrary text
  }
}
