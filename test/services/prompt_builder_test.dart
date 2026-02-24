// test/services/prompt_builder_test.dart
//
// Unit tests for the prompt builder and mood style preset mapper.
// These are pure functions with zero dependencies — ideal for testing.

import 'package:flutter_test/flutter_test.dart';
import 'package:sofi_test_connect/services/prompt_builder.dart';
import 'package:sofi_test_connect/services/mood_style_preset.dart';

void main() {
  // ─────────────────────────────────────────────
  // MoodStylePresetMapper
  // ─────────────────────────────────────────────
  group('MoodStylePresetMapper', () {
    test('maps "glow" to pixar', () {
      expect(MoodStylePresetMapper.map('glow'), MoodStylePreset.pixar);
    });

    test('maps "noir" to cinematic', () {
      expect(MoodStylePresetMapper.map('noir'), MoodStylePreset.cinematic);
    });

    test('maps "pastel" to softIllustration', () {
      expect(MoodStylePresetMapper.map('pastel'),
          MoodStylePreset.softIllustration);
    });

    test('maps "street" to fashion', () {
      expect(MoodStylePresetMapper.map('street'), MoodStylePreset.fashion);
    });

    test('maps "lux" to fashion', () {
      expect(MoodStylePresetMapper.map('lux'), MoodStylePreset.fashion);
    });

    test('maps "bold" to fashion', () {
      expect(MoodStylePresetMapper.map('bold'), MoodStylePreset.fashion);
    });

    test('maps unknown mood to pixar (default)', () {
      expect(MoodStylePresetMapper.map('unknown_mood'), MoodStylePreset.pixar);
    });

    test('is case-insensitive', () {
      expect(MoodStylePresetMapper.map('GLOW'), MoodStylePreset.pixar);
      expect(MoodStylePresetMapper.map('Noir'), MoodStylePreset.cinematic);
      expect(MoodStylePresetMapper.map('PASTEL'),
          MoodStylePreset.softIllustration);
    });
  });

  // ─────────────────────────────────────────────
  // styleIntensityModifier
  // ─────────────────────────────────────────────
  group('styleIntensityModifier', () {
    test('low strength returns subtle modifier', () {
      final result = styleIntensityModifier(4.0);
      expect(result, contains('subtly'));
      expect(result, contains('realism'));
    });

    test('balanced strength returns balanced modifier', () {
      final result = styleIntensityModifier(7.0);
      expect(result, contains('balanced'));
    });

    test('high strength returns strong modifier', () {
      final result = styleIntensityModifier(9.0);
      expect(result, contains('strong'));
    });

    test('boundary at 5.5 returns subtle', () {
      final result = styleIntensityModifier(5.5);
      expect(result, contains('subtly'));
    });

    test('boundary at 7.5 returns balanced', () {
      final result = styleIntensityModifier(7.5);
      expect(result, contains('balanced'));
    });
  });

  // ─────────────────────────────────────────────
  // optimizedSteps
  // ─────────────────────────────────────────────
  group('optimizedSteps', () {
    test('low strength returns 20 steps', () {
      expect(optimizedSteps(styleStrength: 4.0), 20);
    });

    test('balanced strength returns 26 steps', () {
      expect(optimizedSteps(styleStrength: 7.0), 26);
    });

    test('high strength returns default steps (30)', () {
      expect(optimizedSteps(styleStrength: 9.0), 30);
    });

    test('custom defaultSteps is used for high strength', () {
      expect(optimizedSteps(styleStrength: 9.0, defaultSteps: 32), 32);
    });
  });

  // ─────────────────────────────────────────────
  // buildSofiPrompt (integration of above)
  // ─────────────────────────────────────────────
  group('buildSofiPrompt', () {
    test('includes version header', () {
      final prompt = buildSofiPrompt(
        userPrompt: 'A cool outfit',
        mode: 'doll',
      );
      expect(prompt, contains('[SOFI_PROMPT_VERSION: v1]'));
    });

    test('includes identity lock block', () {
      final prompt = buildSofiPrompt(
        userPrompt: 'Test prompt',
        mode: 'doll',
      );
      expect(prompt, contains('Strictly preserve'));
      expect(prompt, contains('facial identity'));
    });

    test('includes user prompt text', () {
      final prompt = buildSofiPrompt(
        userPrompt: 'A red dress with gold details',
        mode: 'doll',
      );
      expect(prompt, contains('A red dress with gold details'));
    });

    test('includes mood-based style when mood is provided', () {
      final promptNoir = buildSofiPrompt(
        userPrompt: 'Test',
        mode: 'doll',
        mood: 'noir',
      );
      expect(promptNoir, contains('cinematic'));
      expect(promptNoir, contains('Film lighting'));
    });

    test('defaults to pixar style when mood is empty', () {
      final prompt = buildSofiPrompt(
        userPrompt: 'Test',
        mode: 'doll',
        mood: '',
      );
      expect(prompt, contains('Pixar'));
    });

    test('includes intensity modifier based on styleStrength', () {
      final subtlePrompt = buildSofiPrompt(
        userPrompt: 'Test',
        mode: 'doll',
        styleStrength: 4.0,
      );
      expect(subtlePrompt, contains('subtly'));

      final strongPrompt = buildSofiPrompt(
        userPrompt: 'Test',
        mode: 'doll',
        styleStrength: 9.0,
      );
      expect(strongPrompt, contains('strong'));
    });
  });
}
