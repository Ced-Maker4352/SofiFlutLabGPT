import 'package:sofi_test_connect/presentation/mood/mood_mode.dart';

/// Centralized mood icon mapping (uses Firebase Storage paths from Premium Studio)
class MoodIcons {
  static const Map<MoodMode, String> firebasePath = {
    MoodMode.human: 'images/Premium page thumbnails/Realistic.png',
    MoodMode.doll: 'images/Premium page thumbnails/Toy_Delux.png',
    MoodMode.cinematic: 'images/Premium page thumbnails/Lux_Cinematic.png',
    MoodMode.fantasy: 'images/Premium page thumbnails/Fantasy.png',
    MoodMode.artistic: 'images/Premium page thumbnails/Anime.png',
  };

  /// Local asset fallbacks when Firebase images fail to load
  static const Map<MoodMode, String> localAssetPath = {
    MoodMode.human:
        'assets/images/Realistic_human_portrait_photography_thumbnail_null_1767430763061.jpg',
    MoodMode.doll:
        'assets/images/Toy_delux_3d_character_render_thumbnail_null_1767430763548.jpg',
    MoodMode.cinematic:
        'assets/images/Lux_cinematic_movie_style_portrait_thumbnail_null_1767430764387.jpg',
    MoodMode.fantasy:
        'assets/images/Fantasy_magical_character_landscape_thumbnail_null_1767430761693.jpg',
    MoodMode.artistic:
        'assets/images/Anime_style_character_illustration_thumbnail_null_1767430759094.jpg',
  };
}
