// lib/presentation/sofi_studio/widgets/frost_card.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:sofi_test_connect/services/performance_service.dart';

class FrostCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final double blur;
  final double elevation;

  /// Bright frost surface color (white glass)
  final Color backgroundColor;

  /// Thin frost border
  final Color borderColor;

  const FrostCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.blur = 16,
    this.elevation = 6,
    this.backgroundColor = const Color(0xF0FFFFFF), // bright white frost
    this.borderColor = const Color(0xCCFFFFFF),     // soft white border
  });

  @override
  Widget build(BuildContext context) {
    // Check performance mode - disables heavy effects on iOS web
    final perfService = PerformanceService.instance;
    final disableEffects = perfService.shouldDisableHeavyEffects;
    
    // In performance mode: simpler rendering without blur/shadows
    if (disableEffects) {
      return Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: borderRadius,
        ),
        child: Padding(
          padding: padding,
          child: child,
        ),
      );
    }
    
    // Full effects mode
    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: elevation,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: borderRadius,
              border: Border.all(
                color: borderColor,
                width: 1.2,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
