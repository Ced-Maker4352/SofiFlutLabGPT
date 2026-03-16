// lib/services/prompt_builder.dart
//
// Instruction-style prompt builder for flux-kontext-pro.
// flux-kontext-pro is an EDIT model — it understands "change X, keep Y".
// Use imperative commands, not descriptions.

/// Builds an instruction-style prompt for a given mood.
///
/// flux-kontext-pro understands these instructions natively
/// and will change only what is specified, preserving the face.
String buildMoodEditInstruction(String mood, {String userText = '', String mode = 'human', bool isMale = false}) {
  final outfitInstruction = _moodToOutfitInstruction(mood, isMale: isMale);
  final styleClause = _modeToStyleInstruction(mode);
  final userEdits = userText.isNotEmpty ? ' Additional specific edits: $userText.' : '';
  
  final isDoll = mode.toLowerCase() == 'doll';
  final genderLabel = isMale ? 'male' : 'female';
  final personLabel = isMale ? 'boy/man' : 'girl/woman';

  final preservation = isDoll
      ? 'Keep the $genderLabel person\'s underlying facial identity and pose identical, but apply the doll aesthetic to their skin, hair, and entire body.'
      : 'Keep the $genderLabel person\'s face, skin tone, body structure, and pose '
        'identical to the original photo. '
        'Only change the clothing, accessories, hair styling, and background. '
        'Ensure the person remains clearly $personLabel.';

  return '$outfitInstruction $styleClause$userEdits $preservation';
}

/// Builds a custom-text edit instruction (e.g. from a user's typed prompt in Studio).
String buildCustomEditInstruction(String userText, {String mood = '', String mode = 'human', bool isMale = false}) {
  final genderLabel = isMale ? 'male' : 'female';
  final moodClause = mood.isNotEmpty ? ' Mood: $mood.' : '';
  final styleClause = _modeToStyleInstruction(mode);
  
  final isDoll = mode.toLowerCase() == 'doll';
  final preservation = isDoll
      ? 'Keep the $genderLabel person\'s underlying facial identity identical, but cleanly apply the 3D doll plastic aesthetic to their skin and body without distortion.'
      : 'Keep the $genderLabel person\'s face, skin tone, and body structure identical to the original photo.';

  return 'Edit this $genderLabel photo: $userText$moodClause $styleClause $preservation';
}

/// Maps a mood name to a specific outfit-change instruction.
String _moodToOutfitInstruction(String mood, {bool isMale = false}) {
  final genderSuffix = isMale ? ' for a man/boy' : ' for a woman/girl';
  
  switch (mood.toLowerCase()) {
    case 'bold':
      return isMale 
          ? 'Change the outfit to a fun and energetic hero look: bright graphic hoodie with exciting patterns, colorful cargo shorts, and cool light-up sneakers.'
          : 'Change the outfit to a vibrant, bold fashion look: sparkly textures, fun statement patterns, and colorful accessories.';
    case 'happy':
      return 'Change the outfit to bright, joyful colors with playful fun patterns $genderSuffix. Think sunshine yellows, rainbow pops of color, and cheerful prints.';
    case 'calm':
      return 'Change the outfit to soft, cozy textures with friendly pastel colors $genderSuffix. Think fluffy knits, soft clouds, and gentle comfortable styles.';
    case 'confident':
      return isMale
          ? 'Change the outfit to a sharp and stylish "little lead" look: a clean blazer over a fun tee or a polished smart-casual outfit.'
          : 'Change the outfit to a polished and playful lead look: stylish matching sets with bright, clean colors and friendly silhouettes.';
    case 'creative':
      return 'Change the outfit to a magical and artsy look with rainbow colors, unexpected fun patterns, and many cute accessories $genderSuffix.';
    case 'soft':
      return isMale
          ? 'Change the outfit to a soft, cozy and cute look with friendly pastel colors and a relaxed, cuddly fit for a boy.'
          : 'Change the outfit to a cute and playful pastel aesthetic: soft pinks, mints, lilacs, fluffy textures, cute bows, and friendly details.';
    case 'powerful':
      return isMale
          ? 'Change the outfit to an exciting and strong superhero-inspired adventure look: bright colors, cool cape-like details, and high-energy gear.'
          : 'Change the outfit to a commanding and magical royal look: shimmering fabrics, strong but friendly silhouettes, and bright bold colors.';
    case 'mysterious':
      return 'Change the outfit to an enchanting and magical night-sky aesthetic with deep glowing blues and sparkly star details $genderSuffix.';
    default:
      return 'Change the outfit to a stylish, fashion-forward look $genderSuffix '
          'that matches the mood: $mood.';
  }
}

/// Maps a generation mode to a specific aesthetic/style instruction.
String _modeToStyleInstruction(String mode) {
  switch (mode.toLowerCase()) {
    case 'cinematic':
      return 'Make the entire image cinematic, highly detailed, dramatic studio lighting, 8k resolution, photorealistic. ';
    case 'fantasy':
      return 'Transform the image into a magical fantasy style, ethereal lighting, mystical atmosphere, highly detailed illustration. ';
    case 'artistic':
      return 'Transform the image into an anime illustration, vibrant colors, 2D shading, highly detailed manga art style. ';
    case 'doll':
      return 'Transform this into a playful 3D toy character or fashion doll portrait. Show head-to-toe in a friendly, stylish pose with a clean, toy-like background. ';
    default:
      return ''; // 'human' uses default realistic styles
  }
}
