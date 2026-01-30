String moodToVisualPrompt(String mood) {
  switch (mood.toLowerCase()) {
    case 'powerful':
      return 'powerful presence, strong posture, bold structured outfit, commanding silhouette, confident stance';

    case 'bold':
      return 'high-contrast colors, striking fashion, dramatic pose, confident expression, sharp styling';

    case 'soft':
      return 'soft pastel colors, relaxed posture, flowing fabrics, gentle expression, airy styling';

    case 'calm':
      return 'minimalist outfit, neutral tones, serene pose, balanced composition, peaceful mood';

    case 'confident':
      return 'tailored outfit, upright posture, self-assured stance, polished appearance';

    case 'creative':
      return 'experimental fashion, unique textures, artistic styling, expressive pose';

    case 'happy':
      return 'bright colors, open posture, joyful expression, playful fashion';

    case 'mysterious':
      return 'dark tones, dramatic lighting, subtle expression, enigmatic presence';

    default:
      return mood; // safe fallback
  }
}
