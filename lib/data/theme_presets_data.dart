import 'package:sofi_test_connect/models/theme_presets.dart';

final List<ThemePreset> themePresets = [
  ThemePreset(
    id: 'pixar',
    label: 'Pixar',
    description: 'Cinematic 3D animated look',
    basePrompt: '''
Pixar-style 3D character render.
Soft cinematic lighting, smooth materials, expressive eyes.
Preserve pose, proportions, outfit, and framing.
Do not crop. Do not change framing.
''',
    assetPath: 'images/Premium page thumbnails/Pixar.png',
    localAssetPath: 'assets/images/Pixar_style_3d_character_animation_thumbnail_null_1767430758269.jpg',
    variants: const [
      ThemeVariant(id: 'soft', label: 'Soft', prompt: 'Gentle lighting, warm softness.'),
      ThemeVariant(id: 'hero', label: 'Hero', prompt: 'Cinematic contrast, heroic lighting.'),
      ThemeVariant(id: 'toy', label: 'Toy', prompt: 'Playful materials, rounded softness.'),
    ],
    isPremium: false,
  ),

  ThemePreset(
    id: 'anime',
    label: 'Anime',
    description: 'Stylized anime illustration',
    basePrompt: '''
High-quality anime-style character illustration.
Clean linework, expressive face, stylized shading.
Preserve full-body proportions, pose, and framing.
''',
    assetPath: 'images/Premium page thumbnails/Anime.png',
    localAssetPath: 'assets/images/Anime_style_character_illustration_thumbnail_null_1767430759094.jpg',
    variants: const [
      ThemeVariant(id: 'clean', label: 'Clean', prompt: 'Modern clean anime style.'),
      ThemeVariant(id: 'ghibli', label: 'Ghibli', prompt: 'Soft storybook warmth, ghibli-inspired.'),
      ThemeVariant(id: 'cyber', label: 'Cyber', prompt: 'Neon cyber anime aesthetic.'),
    ],
    isPremium: false,
  ),

  ThemePreset(
    id: 'comic',
    label: 'Comic',
    description: 'Graphic novel style',
    basePrompt: '''
Comic-book style illustration.
Bold outlines, graphic shading, dramatic lighting.
Full body visible, stable framing.
''',
    assetPath: 'images/Premium page thumbnails/Comic.png',
    localAssetPath: 'assets/images/Comic_book_graphic_novel_illustration_thumbnail_null_1767430759573.jpg',
    variants: const [
      ThemeVariant(id: 'western', label: 'Western', prompt: 'Classic Western comic rendering.'),
      ThemeVariant(id: 'manga', label: 'Manga', prompt: 'Manga-inspired comic ink shading.'),
      ThemeVariant(id: 'noir', label: 'Noir', prompt: 'Noir graphic novel mood, gritty shadows.'),
    ],
    isPremium: false,
  ),

  ThemePreset(
    id: 'superhero',
    label: 'Superhero',
    description: 'Cinematic hero aesthetic',
    basePrompt: '''
Cinematic superhero character.
Powerful stance, dramatic lighting, detailed costume.
Full body preserved, clean silhouette.
''',
    assetPath: 'images/Premium page thumbnails/Super_Hero.png',
    localAssetPath: 'assets/images/Superhero_character_cinematic_portrait_thumbnail_null_1767430760282.jpg',
    variants: const [
      ThemeVariant(id: 'classic', label: 'Classic', prompt: 'Classic heroic vibe, clean costume lines.'),
      ThemeVariant(id: 'dark', label: 'Dark', prompt: 'Moody vigilante, darker palette and lighting.'),
      ThemeVariant(id: 'future', label: 'Future', prompt: 'Futuristic hero armor, sci-fi materials.'),
    ],
    isPremium: false,
  ),

  ThemePreset(
    id: 'fashion',
    label: 'Fashion',
    description: 'Editorial and runway looks',
    basePrompt: '''
High-fashion editorial character.
Premium fabrics, studio lighting, magazine composition.
Full body visible, runway-ready.
''',
    assetPath: 'images/Premium page Fashion.png',
    localAssetPath: 'assets/images/High_fashion_editorial_runway_model_thumbnail_null_1767430760949.jpg',
    variants: const [
      ThemeVariant(id: 'runway', label: 'Runway', prompt: 'Runway editorial styling, bold fashion.'),
      ThemeVariant(id: 'street', label: 'Streetwear', prompt: 'Urban streetwear styling, modern vibe.'),
      ThemeVariant(id: 'luxury', label: 'Luxury', prompt: 'Luxury casual styling, premium details.'),
    ],
    isPremium: false,
  ),

  ThemePreset(
    id: 'fantasy',
    label: 'Fantasy',
    description: 'Mythical and magical styles',
    basePrompt: '''
Fantasy character design.
Mystical atmosphere, elegant costume details.
Full body preserved, storybook realism.
''',
    assetPath: 'images/Premium page thumbnails/Fantasy.png',
    localAssetPath: 'assets/images/Fantasy_magical_character_landscape_thumbnail_null_1767430761693.jpg',
    variants: const [
      ThemeVariant(id: 'elf', label: 'Elf/Mage', prompt: 'Mystical mage aesthetics, subtle magic glow.'),
      ThemeVariant(id: 'royal', label: 'Royal', prompt: 'Royal fantasy elegance, ornate fabrics.'),
      ThemeVariant(id: 'dark', label: 'Dark', prompt: 'Dark fantasy mood, dramatic shadows.'),
    ],
    isPremium: false,
  ),

  ThemePreset(
    id: 'scifi',
    label: 'Sci-Fi',
    description: 'Futuristic and sci-fi looks',
    basePrompt: '''
Science fiction character.
Futuristic materials, cinematic sci-fi lighting.
Full body preserved, clean silhouette.
''',
    assetPath: 'images/Premium page thumbnails/SciFi.png',
    localAssetPath: 'assets/images/Sci-fi_futuristic_character_portrait_thumbnail_null_1767430762305.jpg',
    variants: const [
      ThemeVariant(id: 'cyberpunk', label: 'Cyberpunk', prompt: 'Neon cyberpunk glow, urban future.'),
      ThemeVariant(id: 'space', label: 'Space', prompt: 'Space explorer suit, high-tech realism.'),
      ThemeVariant(id: 'soldier', label: 'Soldier', prompt: 'Futuristic combat gear, tactical sci-fi.'),
    ],
    isPremium: false,
  ),

  ThemePreset(
    id: 'realistic',
    label: 'Realistic+',
    description: 'Enhanced realism',
    basePrompt: '''
Ultra-realistic enhanced character.
Cinematic lighting, premium realism.
Preserve natural human proportions and framing.
''',
    assetPath: 'images/Premium page thumbnails/Realistic.png',
    localAssetPath: 'assets/images/Realistic_human_portrait_photography_thumbnail_null_1767430763061.jpg',
    variants: const [
      ThemeVariant(id: 'studio', label: 'Studio', prompt: 'Professional studio realism.'),
      ThemeVariant(id: 'cinema', label: 'Cinematic', prompt: 'Cinematic realism tone, film lighting.'),
      ThemeVariant(id: 'lifestyle', label: 'Lifestyle', prompt: 'Natural lifestyle realism, soft daylight.'),
    ],
    isPremium: false,
  ),

  // Premium-only packs
  ThemePreset(
    id: 'lux_cinematic',
    label: 'Lux Cinematic',
    description: 'Premium cinematic character look',
    basePrompt: '''
Premium cinematic character render.
Film-grade lighting, high-end lens look, ultra-polished materials.
Preserve pose, proportions, outfit, and framing.
''',
    assetPath: 'images/Premium page thumbnails/Lux_Cinematic.png',
    localAssetPath: 'assets/images/Lux_cinematic_movie_style_portrait_thumbnail_null_1767430764387.jpg',
    variants: const [
      ThemeVariant(id: 'gold', label: 'Gold', prompt: 'Golden-hour cinematic lighting, soft glow.'),
      ThemeVariant(id: 'neon', label: 'Neon', prompt: 'Neon city cinematic lighting, glossy reflections.'),
      ThemeVariant(id: 'noir', label: 'Noir+', prompt: 'Premium noir lighting, dramatic shadows.'),
    ],
    isPremium: true,
    packId: 'premium_cinematic_pack',
  ),

  ThemePreset(
    id: 'toy_deluxe',
    label: 'Toy Deluxe',
    description: 'Premium collectible toy look',
    basePrompt: '''
Collectible toy deluxe render.
Premium plastics, subtle micro-textures, studio product lighting.
Preserve framing and silhouette.
''',
    assetPath: 'images/Premium page thumbnails/Toy_Delux.png',
    localAssetPath: 'assets/images/Toy_delux_3d_character_render_thumbnail_null_1767430763548.jpg',
    variants: const [
      ThemeVariant(id: 'matte', label: 'Matte', prompt: 'Matte deluxe finish, soft reflections.'),
      ThemeVariant(id: 'gloss', label: 'Gloss', prompt: 'High-gloss premium reflections, showroom look.'),
      ThemeVariant(id: 'limited', label: 'Limited', prompt: 'Limited edition aesthetic, premium packaging vibe.'),
    ],
    isPremium: true,
    packId: 'premium_toy_pack',
  ),
];
