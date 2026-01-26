enum MoodMode {
  human,      // free
  doll,       // free
  cinematic,  // premium
  fantasy,    // premium
  artistic,   // premium
}

extension MoodModeX on MoodMode {
  bool get isPremium =>
      this == MoodMode.cinematic ||
      this == MoodMode.fantasy ||
      this == MoodMode.artistic;

  String get id => name;
}
