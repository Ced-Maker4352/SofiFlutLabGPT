// lib/presentation/sofi_studio/widgets/history_viewer.dart

import 'dart:typed_data';
import 'package:flutter/material.dart';

class HistoryViewer extends StatelessWidget {
  final List<Uint8List> history;
  final void Function(int index) onSelect;
  final VoidCallback onClose;

  const HistoryViewer({
    super.key,
    required this.history,
    required this.onSelect,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 240,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          GestureDetector(
            onTap: onClose,
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 10),

          const Text(
            "History",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),

          const SizedBox(height: 12),

          Expanded(
            child: history.isEmpty
                ? const Center(
                    child: Text(
                      "No saved looks yet.",
                      style: TextStyle(color: Colors.black54),
                    ),
                  )
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    itemCount: history.length,
                    itemBuilder: (_, index) {
                      final bytes = history[index];

                      return GestureDetector(
                        onTap: () => onSelect(index),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.memory(
                            bytes,
                            width: 120,
                            height: 180,
                            fit: BoxFit.cover,
                          ),
                        ),
                      );
                    },
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                  ),
          ),
        ],
      ),
    );
  }
}
