// lib/presentation/sofi_studio/sofi_prompt_builder.dart

import 'sofi_studio_models.dart';

/// Look mode for the free front-door.
/// - human: realistic human result
/// - pixar: your original Sofi stylized Pixar-like look (NOT plastic toy joints)
enum LookMode {
  human,
  pixar,
}

/// Responsible for building the final prompt sent to ModelsLab.
///
/// IMPORTANT:
/// This builder is used for the "free" pipeline.
/// Premium pipelines (cinema/anime/etc) should keep using PremiumStudioController prompts.
class SofiPromptBuilder {
  static String build({
    required EditCategory category,
    required String styleLabel,
    required String freeText,
    required LookMode lookMode,
    bool isMale = false,
  }) {
    final buffer = StringBuffer();
    final gender = isMale ? 'male' : 'female';
    final person = isMale ? 'boy/man' : 'girl/woman';

    // 1) Base style (MODE CONTROLS THIS)
    if (lookMode == LookMode.human) {
      buffer.write(
        "Photorealistic $gender human portrait. Natural human anatomy and facial proportions. "
        "Realistic skin texture, pores, and lighting. No cartoon features. "
        "STRICTLY ensure the person remains clearly $person, with no feminine features for boys or masculine features for girls. ",
      );
    } else {
      // This aligns with your original “Pixar-ish” app feel.
      buffer.write(
        "High-quality, child-friendly 3D animated Pixar-like $gender character render. "
        "Vibrant and playful colors, soft shading, smooth gradients, cinematic but clean lighting. "
        "Maintain a friendly, believable human-like character face and playful proportions. "
        "STRICTLY ensure the character remains clearly $person, with no mixed-gender features. ",
      );
    }

    // 2) ENHANCED Identity protection (prevents face drift and distortion)
    // CRITICAL: Strong face-locking directives to prevent any facial modification
    buffer.write(
      "[FACE LOCK - ABSOLUTE PRIORITY] "
      "The face from the input image is SACRED and IMMUTABLE. "
      "PRESERVE EXACTLY: eye shape, eye color, eye spacing, eye symmetry, "
      "nose shape, nose size, nostril width, "
      "lip shape, lip fullness, lip color, "
      "skin tone, skin texture, complexion, "
      "facial bone structure, jawline, cheekbones, forehead. "
      "Do NOT regenerate, modify, distort, warp, or alter ANY facial features. "
      "The face region must be PIXEL-IDENTICAL to the source image. "
      "Apply all changes ONLY to clothing and accessories below the neck. ",
    );

    // 3) Category tag
    buffer.write("Focus on ${category.promptTag}. ");

    // 4) Preset label
    buffer.write("Style: $styleLabel. ");

    // 5) Free text from user
    final trimmed = freeText.trim();
    if (trimmed.isNotEmpty) {
      buffer.write("Additional details: $trimmed. ");
    }

    // 6) Output quality - CRITICAL for crisp, clear images
    buffer.write(
      "QUALITY REQUIREMENTS: Ultra high resolution, photorealistic quality, "
      "masterpiece, best quality, crisp details, sharp focus, perfect clarity, "
      "clean render, smooth skin texture, professional photography lighting, "
      "no noise, no grain, no blur, no pixelation, no artifacts. "
      "8K quality, highly detailed, crystal clear, pristine image quality."
    );

    return buffer.toString();
  }
}
