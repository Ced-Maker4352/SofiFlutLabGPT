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
          ? 'Change the outfit to a bold streetwear look: oversized graphic hoodie, technical cargo pants, and high-top sneakers.'
          : 'Change the outfit to an edgy, bold fashion look: dark leather jacket or structured power pieces with statement accessories.';
    case 'happy':
      return 'Change the outfit to bright, joyful colors with fun patterns $genderSuffix. Think sunshine yellows, pops of color, and cheerful prints.';
    case 'calm':
      return 'Change the outfit to soft, muted earth tones in flowing relaxed clothing $genderSuffix. Think linen, soft neutrals, cozy minimalist style.';
    case 'confident':
      return isMale
          ? 'Change the outfit to a sharp, tailored suit or a sophisticated blazer and trousers look for a man.'
          : 'Change the outfit to a sleek, polished power look with sharp tailored silhouettes. Think blazers, structured pieces, monochrome elegance.';
    case 'creative':
      return 'Change the outfit to a colorful, artsy look with unexpected patterns and expressive accessories $genderSuffix.';
    case 'soft':
      return isMale
          ? 'Change the outfit to a soft, cozy knitwear look with light pastel colors and relaxed fit for a boy.'
          : 'Change the outfit to a soft girl pastel aesthetic: light pinks, creams, lilacs, fluffy textures, bows, and feminine details.';
    case 'powerful':
      return isMale
          ? 'Change the outfit to a strong, structured military-inspired or high-fashion suit look for a man.'
          : 'Change the outfit to a commanding power look: structured blazer, sharp lines, strong silhouette, dark bold colors.';
    case 'mysterious':
      return 'Change the outfit to a dark, mysterious aesthetic with deep jewel tones and moody styling $genderSuffix.';
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
      return 'Transform this into a full body fashion doll portrait. Show head-to-toe in a stylish pose with clean background. ';
    default:
      return ''; // 'human' uses default realistic styles
  }
}
