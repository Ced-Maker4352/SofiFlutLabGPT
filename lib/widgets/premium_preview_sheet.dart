import 'package:flutter/material.dart';
import 'package:sofi_test_connect/presentation/mood/mood_mode.dart';
import 'package:sofi_test_connect/constants/mood_icons.dart';
import 'package:sofi_test_connect/services/storage_service.dart';

class PremiumPreviewSheet extends StatelessWidget {
  final MoodMode mode;
  final VoidCallback onTryFree;
  final VoidCallback onUpgrade;

  const PremiumPreviewSheet({
    super.key,
    required this.mode,
    required this.onTryFree,
    required this.onUpgrade,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.92),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Firebase image preview
          FutureBuilder<String?>(
            future: StorageService.instance.getDownloadUrlSafe(
              MoodIcons.firebasePath[mode]!,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Container(
                  height: 160,
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                );
              }

              if (snapshot.hasError || snapshot.data == null) {
                return Container(
                  height: 160,
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.broken_image, color: Colors.white54),
                );
              }

              return ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  snapshot.data!,
                  height: 160,
                  fit: BoxFit.cover,
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Text(
            'Try ${mode.name.toUpperCase()} Look',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            'One free preview per day',
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onTryFree,
              child: const Text('Try Once Free'),
            ),
          ),
          TextButton(
            onPressed: onUpgrade,
            child: const Text(
              'Unlock Premium',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }
}
