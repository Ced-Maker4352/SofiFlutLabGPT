// lib/presentation/sofi_studio/sofi_studio_models.dart

/// Core doll model used across Sofi Saint.
class SofiDoll {
  /// Unique ID (used to track active selections).
  final String id;

  /// Small preview image (thumb).
  final String thumbPath;

  /// Full-size PNG used for generation.
  final String stagePath;

  /// true = special / premium doll.
  final bool isPremium;

  /// true = paths are Firebase Storage paths (not local assets).
  final bool isStoragePath;

  const SofiDoll({
    required this.id,
    required this.thumbPath,
    required this.stagePath,
    required this.isPremium,
    this.isStoragePath = false,
  });

  // Backward-compatible alias for older code.
  bool get isSpecial => isPremium;
}

/// High-level edit focus for the prompt builder and UI.
/// NOTE: `prettyName` makes the drawer tab names readable.
enum EditCategory {
  fullOutfit('full outfit', 'Full Outfit'),
  hair('hair', 'Hair'),
  top('top', 'Tops'),
  bottom('bottom', 'Bottoms'),
  shoes('shoes', 'Shoes'),
  background('background', 'Backgrounds'),
  accessories('accessories', 'Accessories'),
  hats('hats', 'Hats'),
  jewelry('jewelry', 'Jewelry'),
  glasses('glasses', 'Glasses'),
  poses('poses', 'Poses');

  final String promptTag;
  final String prettyName;
  const EditCategory(this.promptTag, this.prettyName);
}

/// Global style mode for the look.
enum StyleMode {
  illustration, // Pixar-style 3D illustration
  photo,        // semi-realistic photo render
}
