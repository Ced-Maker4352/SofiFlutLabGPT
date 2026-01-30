class MoodVisualMapper {
  static String map(String mood) {
    switch (mood.toLowerCase()) {
      case 'glow':
        return '''
Bright joyful vibe with warm studio lighting.
Soft glow on the subject, clean cinematic color, crisp details.
Upbeat energy with polished styling and flattering highlights.
''';

      case 'happy':
        return '''
Bright, joyful energy.
Warm lighting, soft highlights.
Vibrant colors.
Relaxed, confident posture.
Friendly facial expression.
Playful, stylish outfit.
''';

      case 'bold':
        return '''
Strong confident stance.
High-contrast lighting.
Fashion-forward outfit.
Power pose.
Sharp color accents.
Cinematic presence.
''';

      case 'noir':
        return '''
Dark cinematic noir lighting.
High contrast shadows.
Monochrome or muted palette.
Moody atmosphere.
Dramatic pose.
Film noir fashion styling.
''';

      case 'pastel':
        return '''
Pastel palette with soft airy lighting and gentle gradients.
Dreamy boutique style, delicate highlights, clean background.
Graceful posture with a relaxed, calm expression.
''';

      case 'street':
        return '''
Urban streetwear energy with crisp lighting.
Editorial look, concrete or city hints, sharp details, confident attitude.
Dynamic pose with modern styling and texture-rich fabrics.
''';

      case 'lux':
        return '''
Luxury fashion editorial mood.
Premium materials, glossy highlights, elegant studio lighting.
Sophisticated pose, high-end styling, polished finishing.
''';

      case 'soft':
        return '''
Soft pastel tones.
Gentle lighting.
Calm relaxed posture.
Minimalist styling.
Dreamy atmosphere.
''';

      default:
        return '''
Neutral balanced styling.
Clean lighting.
Modern fashion.
Natural posture.
''';
    }
  }
}
