// lib/services/prompt_builder.dart

import 'mood_style_preset.dart';

const String GENERATION_SYSTEM_TAG = 'v2_neutral';

/// Common quality and realism directives used across all generations
const String commonQualityDirectives = '''
[QUALITY & REALISM DIRECTIVE]
MASTERPIECE, BEST QUALITY, ultra high resolution, 8K quality.
Photorealistic, crystal clear, sharp focus, crisp details, highly detailed.
Professional photography quality, smooth textures, pristine render.
No noise, no grain, no blur, no pixelation, no artifacts, no compression.
''';

/// Strong instructions for maintaining facial identity
const String commonIdentityDirectives = '''
[IDENTITY LOCK DIRECTIVE]
The face from the input reference image is SACRED and must be preserved with pixel-perfect accuracy.
- Copy EXACT eye shape, eye color, eye spacing, and symmetry from the input.
- Copy EXACT nose structure, nostril size, and nose bridge.
- Copy EXACT lip shape, fullness, and mouth width.
- Copy EXACT skin tone, skin texture, and complexion.
- Copy EXACT facial bone structure, jawline, and cheekbones.
- Maintain the original gender characteristics, ethnicity, and age.
- The face region (hairline to chin, ear to ear) must remain UNCHANGED.
- If style conflicts with identity preservation, ALWAYS PRIORITIZE IDENTITY.
''';

String styleIntensityModifier(double strength) {
  if (strength <= 5.5) {
    return 'SUBTLE STYLING: Prioritize organic realism and facial accuracy. Minimal exaggeration.';
  } else if (strength <= 7.5) {
    return 'BALANCED STYLING: Maintain realism while clearly expressing the chosen artistic aesthetic.';
  } else {
    return 'BOLD STYLING: Push the artistic aesthetic clearly while strictly anchoring to facial identity.';
  }
}

/// Step 1 — Identity Lock Prompt
/// This is used to convert a headshot into a stable full-body body-double.
String buildStep1IdentityPrompt({
  required String userIntent,
}) {
  return '''
[SYSTEM_TASK: IDENTITY_STABILIZATION]
$commonQualityDirectives
$commonIdentityDirectives

[BODY_EXTENSION]
Extend the subject to a full-body, head-to-toe pose.
Add clean, neutral styling. Keep the subject's original body type.
Simple, clean background.

Context Intention: $userIntent
''';
}

/// Step 2 — Style Application Prompt
/// This is used to apply outfits/themes/moods to a locked identity.
String buildStep2StylePrompt({
  required String userIntent,
  double styleStrength = 7.0,
}) {
  final intensity = styleIntensityModifier(styleStrength);

  return '''
[SYSTEM_TASK: STYLE_APPLICATION]
$commonQualityDirectives
$commonIdentityDirectives

[STYLE_DIRECTIVE]
$intensity
Apply style/outfit changes ONLY to clothing, accessories, and the environment.
DO NOT alter the subject's face or identity features.

User Intention: $userIntent
''';
}

/// Legacy/Helper method for the main controller to build the "Full" prompt (Step 2 equivalent)
String buildSofiPrompt({
  required String userPrompt,
  required String mode,
  String mood = '',
  double styleStrength = 7.0,
  bool identityOnly = false,
}) {
  if (identityOnly) {
    return buildStep1IdentityPrompt(userIntent: userPrompt);
  }

  // Map mood to style description if possible
  final stylePreset = mood.isNotEmpty ? MoodStylePresetMapper.map(mood) : null;
  String styleDescription = '';

  if (stylePreset != null) {
    styleDescription = switch (stylePreset) {
      MoodStylePreset.pixar =>
        'Aesthetic: High-quality 3D animated character style, vibrant colors.',
      MoodStylePreset.cinematic =>
        'Aesthetic: Cinematic film lighting, high contrast, atmospheric.',
      MoodStylePreset.fashion =>
        'Aesthetic: High-end fashion editorial presentation, professional lighting.',
      MoodStylePreset.softIllustration =>
        'Aesthetic: Soft illustrated character, gentle lighting, pastel tones.',
    };
  }

  final fullIntent = '$userPrompt\n$styleDescription'.trim();

  return buildStep2StylePrompt(
    userIntent: fullIntent,
    styleStrength: styleStrength,
  );
}
