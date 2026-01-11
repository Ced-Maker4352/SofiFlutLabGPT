// lib/presentation/sofi_studio/widgets/side_button.dart

import 'package:flutter/material.dart';
import 'package:sofi_test_connect/services/audio_service.dart';
import '../sofi_studio_theme.dart';

class SideButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool isActive;

  const SideButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onTap,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color base = SofiStudioTheme.blue;
    final Color bg = isActive ? Colors.white : base;
    final Color iconColor = isActive ? base : Colors.white;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () async {
            await AudioService.instance.playClick();
            onTap?.call();
          },
          child: Ink(
            decoration: ShapeDecoration(
              color: bg,
              shape: const CircleBorder(),
              shadows: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Icon(
                icon,
                size: 20,
                color: iconColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
