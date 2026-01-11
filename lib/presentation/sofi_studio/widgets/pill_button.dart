// lib/presentation/sofi_studio/widgets/pill_button.dart

import 'package:flutter/material.dart';
import 'package:sofi_test_connect/services/audio_service.dart';
import '../sofi_studio_theme.dart';

class PillButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool primary; // true = filled blue, false = white with blue border
  final bool showStars;

  const PillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.primary = true,
    this.showStars = false,
  });

  @override
  Widget build(BuildContext context) {
    final String textLabel = showStars ? '★ $label ★' : label;

    if (primary) {
      return ElevatedButton(
        onPressed: () async {
          await AudioService.instance.playClick();
          onPressed?.call();
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: SofiStudioTheme.blue,
           disabledBackgroundColor: SofiStudioTheme.blue.withValues(alpha: 0.4),
          foregroundColor: Colors.white,
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          elevation: 6,
           shadowColor: Colors.black.withValues(alpha: 0.3),
        ),
        child: Text(
          textLabel,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
      );
    } else {
      // Secondary white pill with blue border
      return OutlinedButton(
        onPressed: () async {
          await AudioService.instance.playClick();
          onPressed?.call();
        },
        style: OutlinedButton.styleFrom(
          foregroundColor: SofiStudioTheme.blue,
          backgroundColor: Colors.white,
          side: BorderSide(
            color: onPressed == null
                 ? SofiStudioTheme.charcoal.withValues(alpha: 0.3)
                : SofiStudioTheme.blue,
            width: 1.2,
          ),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        ),
        child: Text(
          textLabel,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }
  }
}
