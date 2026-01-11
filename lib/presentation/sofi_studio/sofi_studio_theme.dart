// lib/presentation/sofi_studio/sofi_studio_theme.dart

import 'package:flutter/material.dart';

class SofiStudioTheme {
// Brand Colors
static const Color yellow = Color(0xFFFFE04D);
static const Color purple = Color(0xFF5A2DFF);

// NEW (required everywhere)
static const Color blue = Color(0xFF4A90E2);
static const Color charcoal = Color(0xFF333333);

// Brand gradient for primary call-to-action elements
static const LinearGradient brandGradient = LinearGradient(
begin: Alignment.topLeft,
end: Alignment.bottomRight,
colors: [purple, blue],
);

// NEW — padding / radius system
static const double radiusMedium = 16;

// NEW — selected pill background
static const Color pillSelected = Color(0xFFEEE8FF);

// NEW — Studio Background (Light Blue)
static const Color studioBackground = Color(0xFFDAE8FF);

// Soft Shadow used in selected tiles
static List<BoxShadow> get softShadow => [
BoxShadow(
color: Colors.black.withValues(alpha: 0.15),
blurRadius: 8,
offset: const Offset(0, 3),
),
];
}
