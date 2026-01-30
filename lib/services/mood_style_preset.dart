// lib/services/mood_style_preset.dart

enum MoodStylePreset {
  pixar,
  cinematic,
  fashion,
  softIllustration,
}

class MoodStylePresetMapper {
  static MoodStylePreset map(String mood) {
    switch (mood.toLowerCase()) {
      case 'glow':
        return MoodStylePreset.pixar;

      case 'happy':
        return MoodStylePreset.pixar;

      case 'bold':
        return MoodStylePreset.fashion;

      case 'noir':
        return MoodStylePreset.cinematic;

      case 'pastel':
        return MoodStylePreset.softIllustration;

      case 'street':
        return MoodStylePreset.fashion;

      case 'lux':
        return MoodStylePreset.fashion;

      case 'soft':
        return MoodStylePreset.softIllustration;

      default:
        return MoodStylePreset.pixar;
    }
  }
}
