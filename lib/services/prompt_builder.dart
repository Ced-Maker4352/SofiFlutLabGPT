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

String buildSofiPromptV1({
  required String userPrompt,
  required String mode,
  String mood = '',
  double styleStrength = 7.0,
}) {
  const baseIdentityLock = '''
You are generating a character image using a reference photo.

Strictly preserve the subject's facial identity, including:
- face shape
- eye shape and spacing
- nose structure
- mouth shape
- hairline and hair texture
- skin tone
- age and ethnicity

Do not change the person's identity.
Do not stylize the face in a way that alters likeness.

Generate a full-body character with natural human anatomy.
Show the entire body head to toe, uncropped.
Maintain correct limb proportions and posture.
Lighting should be clean, cinematic, and realistic.
''';

  // Determine style preset from mood (or fallback to pixar)
  final stylePreset = mood.isNotEmpty
      ? MoodStylePresetMapper.map(mood)
      : MoodStylePreset.pixar;

  final styleBuffer = StringBuffer();
  switch (stylePreset) {
    case MoodStylePreset.pixar:
      styleBuffer.writeln('''
Style the character as a Pixar-style 3D animated character.
Soft rounded features.
Expressive eyes.
High-quality animation render.
''');
      break;

    case MoodStylePreset.cinematic:
      styleBuffer.writeln('''
Style the character as a cinematic realistic character.
Film lighting.
High contrast shadows.
Detailed textures.
Professional photography look.
''');
      break;

    case MoodStylePreset.fashion:
      styleBuffer.writeln('''
Style the character as a high-fashion editorial model.
Runway-ready outfit.
Clean studio lighting.
Magazine-quality photography.
''');
      break;

    case MoodStylePreset.softIllustration:
      styleBuffer.writeln('''
Style the character as a soft illustrated figure.
Pastel tones.
Gentle lighting.
Dreamlike atmosphere.
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

User request:
$userPrompt
''';
}

String buildSofiPrompt({
  required String userPrompt,
  required String mode,
  String mood = '',
  double styleStrength = 7.0,
  String version = SOFI_PROMPT_VERSION,
}) {
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
