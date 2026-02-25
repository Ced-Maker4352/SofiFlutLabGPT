// lib/services/prompt_builder.dart

import 'mood_style_preset.dart';

const String SOFI_PROMPT_VERSION = 'v1';

String styleIntensityModifier(double strength) {
  if (strength <= 5.5) {
    return '''
Apply styling very subtly.
Prioritize realism and facial accuracy.
Minimal exaggeration.
''';
  } else if (strength <= 7.5) {
    return '''
Apply a balanced level of stylization.
Maintain realism while clearly expressing the chosen style.
''';
  } else {
    return '''
Apply strong stylization.
Push the artistic style clearly and confidently,
while strictly preserving facial identity.
''';
  }
}

int optimizedSteps({
  required double styleStrength,
  int defaultSteps = 30,
}) {
  if (styleStrength <= 5.5) {
    // Subtle / realistic → converges fast
    return 20;
  } else if (styleStrength <= 7.5) {
    // Balanced → normal quality
    return 26;
  } else {
    // Bold stylization → needs more refinement
    return defaultSteps; // usually 30–32
  }
}

String buildIdentityOnlyPrompt({
  required String userPrompt,
}) {
  return '''
[SOFI_PROMPT_VERSION: identity_v1]
CRITICAL: IDENTITY LOCK ENABLED.
You MUST preserve the subject's facial identity EXACTLY from the reference photo.
Maintain: face shape, eye spacing, nose structure, skin tone, and ethnicity.
Do not stylize the face. Do not simplified facial geometry.

Context: $userPrompt
''';
}

String buildSofiPromptV1({
  required String userPrompt,
  required String mode,
  String mood = '',
  double styleStrength = 7.0,
}) {
  const baseIdentityLock = '''
CRITICAL: PRESERVE IDENTITY.
Strictly preserve the subject's facial identity: face shape, eye shape, nose structure, mouth shape, skin tone, and ethnicity.
Do not simplified facial geometry. Keep original likeness intact.

Generate a full-body character with natural human anatomy, uncropped, head to toe.
Lighting should be clean and cinematic.
''';

  // Determine style preset from mood (or fallback to pixar)
  final stylePreset =
      mood.isNotEmpty ? MoodStylePresetMapper.map(mood) : MoodStylePreset.pixar;

  final styleBuffer = StringBuffer();
  switch (stylePreset) {
    case MoodStylePreset.pixar:
      styleBuffer.writeln('''
Style: Pixar-style 3D animated character.
Soft rounded features, expressive eyes, high-quality animation render.
''');
      break;

    case MoodStylePreset.cinematic:
      styleBuffer.writeln('''
Style: Cinematic realistic character.
Film lighting, high contrast, detailed textures.
''');
      break;

    case MoodStylePreset.fashion:
      styleBuffer.writeln('''
Style: High-fashion editorial model.
Runway outfit, clean studio lighting, magazine quality.
''');
      break;

    case MoodStylePreset.softIllustration:
      styleBuffer.writeln('''
Style: Soft illustrated figure.
Pastel tones, gentle lighting, dreamlike atmosphere.
''');
      break;
  }

  final styleBlock = styleBuffer.toString();
  final intensityBlock = styleIntensityModifier(styleStrength);

  return '''
[SOFI_PROMPT_VERSION: v1]
$baseIdentityLock
$styleBlock
$intensityBlock

User request: $userPrompt
''';
}

String buildSofiPrompt({
  required String userPrompt,
  required String mode,
  String mood = '',
  double styleStrength = 7.0,
  String version = SOFI_PROMPT_VERSION,
  bool identityOnly = false,
}) {
  if (identityOnly) {
    return buildIdentityOnlyPrompt(userPrompt: userPrompt);
  }

  switch (version) {
    case 'v1':
    default:
      return buildSofiPromptV1(
        userPrompt: userPrompt,
        mode: mode,
        mood: mood,
        styleStrength: styleStrength,
      );
  }
}
