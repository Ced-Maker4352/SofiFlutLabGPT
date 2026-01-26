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
}
