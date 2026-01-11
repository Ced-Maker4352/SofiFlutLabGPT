// lib/presentation/sofi_studio/sofi_prompt_builder.dart

import 'sofi_studio_models.dart';

/// Responsible for building the final prompt sent to ModelsLab.
class SofiPromptBuilder {
  /// Builds a clean, unified prompt using:
  /// - selected category
  /// - preset label
  /// - optional free text
  /// - global style mode
  static String build({
    required EditCategory category,
    required String styleLabel,
    required String freeText,
    required StyleMode styleMode,
  }) {
    final buffer = StringBuffer();

    // 1) Base style
    if (styleMode == StyleMode.illustration) {
      buffer.write(
          "3D cartoon Pixar-style doll, soft shading, smooth gradients. ");
    } else {
      buffer.write("Semi-realistic photo render of a doll character. ");
    }

    // 2) Category tag
    buffer.write("Focus on ${category.promptTag}. ");

    // 3) Preset label
    buffer.write("Style: $styleLabel. ");

    // 4) Free text from user
    if (freeText.trim().isNotEmpty) {
      buffer.write("Additional details: ${freeText.trim()}. ");
    }

    // 5) Output quality
    buffer.write("Ultra clean output, full-body view, vibrant lighting.");

    return buffer.toString();
  }
}
