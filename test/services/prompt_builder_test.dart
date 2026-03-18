// test/services/prompt_builder_test.dart
//
// Unit tests for the new instruction-style prompt builder.

import 'package:flutter_test/flutter_test.dart';
import 'package:sofi_test_connect/services/prompt_builder.dart';

void main() {
  // ─────────────────────────────────────────────
  // buildMoodEditInstruction
  // ─────────────────────────────────────────────
  group('buildMoodEditInstruction', () {
    test('includes face preservation directive', () {
      final prompt = buildMoodEditInstruction('Bold');
      expect(prompt.toLowerCase(), contains('face'));
      expect(prompt.toLowerCase(), contains('identical'));
    });

    test('includes outfit change for Bold mood', () {
      final prompt = buildMoodEditInstruction('Bold');
      expect(prompt.toLowerCase(), contains('bold'));
      expect(prompt.toLowerCase(), contains('outfit'));
    });

    test('includes pastel aesthetic for Soft mood', () {
      final prompt = buildMoodEditInstruction('Soft');
      expect(prompt.toLowerCase(), contains('pastel'));
      expect(prompt.toLowerCase(), contains('soft'));
    });

    test('includes night-sky aesthetic for Mysterious mood', () {
      final prompt = buildMoodEditInstruction('Mysterious');
      expect(prompt.toLowerCase(), contains('night-sky'));
    });

    test('handles unknown mood gracefully', () {
      final prompt = buildMoodEditInstruction('CustomMood');
      expect(prompt.toLowerCase(), contains('change the outfit'));
      expect(prompt.toLowerCase(), contains('face'));
    });
  });

  // ─────────────────────────────────────────────
  // buildCustomEditInstruction
  // ─────────────────────────────────────────────
  group('buildCustomEditInstruction', () {
    test('includes user text in instruction', () {
      final prompt = buildCustomEditInstruction('Red dress with gold details');
      expect(prompt, contains('Red dress with gold details'));
    });

    test('includes face preservation directive', () {
      final prompt = buildCustomEditInstruction('A cool outfit');
      expect(prompt.toLowerCase(), contains('face'));
      expect(prompt.toLowerCase(), contains('identical'));
    });

    test('includes mood clause when mood is provided', () {
      final prompt = buildCustomEditInstruction('Test', mood: 'Bold');
      expect(prompt, contains('Bold'));
    });
  });
}
