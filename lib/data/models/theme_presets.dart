class ThemeVariant {
  final String id;
  final String label;
  final String prompt;

  const ThemeVariant({required this.id, required this.label, required this.prompt});
}

class ThemePreset {
  final String id;
  final String label;
  final String description;
  final String basePrompt;
  final String? assetPath;
  // Optional local asset used as a fallback when Firebase Storage is unavailable
  // (e.g., FlutLab or restricted web environments). This keeps thumbnails
  // consistent across platforms.
  final String? localAssetPath;
  final List<ThemeVariant> variants;
  final bool isPremium;
  final String? packId;

  const ThemePreset({
    required this.id,
    required this.label,
    required this.description,
    required this.basePrompt,
    this.assetPath,
    this.localAssetPath,
    required this.variants,
    required this.isPremium,
    this.packId,
  });
}

class StyleKey {
  final String themeId;
  final String variantId; // use "base" if no variant

  const StyleKey({required this.themeId, required this.variantId});

  String toStorageKey() => '$themeId:$variantId';

  static StyleKey fromStorageKey(String key) {
    final parts = key.split(':');
    if (parts.length != 2) {
      return StyleKey(themeId: parts.first, variantId: 'base');
    }
    return StyleKey(themeId: parts[0], variantId: parts[1]);
  }
}
