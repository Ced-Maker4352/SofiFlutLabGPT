// lib/constants/base_prompts.dart
// Single source of truth for mode-specific base prompts

const String humanBasePrompt = '''
Photorealistic human portrait.
Natural human proportions.
Real skin texture.
Editorial fashion photography.
No doll, toy, or plastic features.
''';

const String dollBasePrompt = '''
Transform this into a full-body fashion doll portrait.
Show head-to-toe in a playful, stylish pose with clean background.
Proportions of an 8-12 year old child. 
Kid-friendly body style: not overly curvy, not sexy, no tight revealing clothing.
Modest and age-appropriate fashion for kids.
Soft plastic doll texture.
''';

const String cinematicBasePrompt = '''
Cinematic luxury portrait.
Hollywood editorial style.
Professional studio lighting.
High-end fashion photography aesthetic.
''';

const String fantasyBasePrompt = '''
Fantasy character portrait.
Ethereal and magical aesthetic.
Dramatic lighting and atmosphere.
High fantasy art style.
''';

const String animeBasePrompt = '''
Anime-style character portrait.
Cel-shaded rendering.
Expressive anime proportions.
Japanese animation aesthetic.
''';

const String artisticBasePrompt = '''
Artistic editorial portrait.
Creative fashion illustration.
High-end artistic photography.
Stylized creative aesthetic.
''';
