// lib/services/prompt_builder.dart
//
// Instruction-style prompt builder for flux-kontext-pro.
// flux-kontext-pro is an EDIT model — it understands "change X, keep Y".
// Use imperative commands, not descriptions.

/// Builds an instruction-style prompt for a given mood.
///
/// flux-kontext-pro understands these instructions natively
/// and will change only what is specified, preserving the face.
String buildMoodEditInstruction(String mood, {String userText = '', String mode = 'human'}) {
  final outfitInstruction = _moodToOutfitInstruction(mood);
  final styleClause = _modeToStyleInstruction(mode);
  final userEdits = userText.isNotEmpty ? ' Additional specific edits: $userText.' : '';
  
  return '$outfitInstruction $styleClause$userEdits '
      'Keep the person\'s face, skin tone, body structure, and pose '
      'identical to the original photo. '
      'Only change the clothing, accessories, hair styling, and background.';
}

/// Builds a custom-text edit instruction (e.g. from a user's typed prompt in Studio).
String buildCustomEditInstruction(String userText, {String mood = '', String mode = 'human'}) {
  final moodClause = mood.isNotEmpty ? ' Mood: $mood.' : '';
  final styleClause = _modeToStyleInstruction(mode);
  
  return 'Edit this photo: $userText$moodClause $styleClause'
      'Keep the person\'s face, skin tone, and body structure identical to '
      'the original photo.';
}

/// Maps a mood name to a specific outfit-change instruction.
String _moodToOutfitInstruction(String mood) {
  switch (mood.toLowerCase()) {
    case 'bold':
      return 'Change the outfit to an edgy, bold fashion look: '
          'dark leather jacket or structured power pieces with statement accessories.';
    case 'happy':
      return 'Change the outfit to bright, joyful colors with fun patterns '
          'and playful accessories. Think sunshine yellows, pops of pink, cheerful prints.';
    case 'calm':
      return 'Change the outfit to soft, muted earth tones in flowing relaxed clothing. '
          'Think linen, soft neutrals, cozy minimalist style.';
    case 'confident':
      return 'Change the outfit to a sleek, polished power look with sharp tailored '
          'silhouettes. Think blazers, structured pieces, monochrome elegance.';
    case 'creative':
      return 'Change the outfit to a colorful, artsy look with unexpected patterns, '
          'expressive accessories, and a fashion-forward mix of textures.';
    case 'soft':
      return 'Change the outfit to a soft girl pastel aesthetic: '
          'light pinks, creams, lilacs, fluffy textures, bows, and feminine details.';
    case 'powerful':
      return 'Change the outfit to a commanding power look: '
          'structured blazer, sharp sharp lines, strong silhouette, dark bold colors.';
    case 'mysterious':
      return 'Change the outfit to a dark, mysterious aesthetic: '
          'deep jewel tones, long flowing fabrics, dramatic details, moody lighting.';
    default:
      return 'Change the outfit to a stylish, fashion-forward look '
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
      return 'Transform into a 3D highly detailed fashion doll, plastic texture, toy-like appearance, immaculate styling. ';
    default:
      return ''; // 'human' uses default realistic styles
  }
}
