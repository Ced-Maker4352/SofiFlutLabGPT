// lib/presentation/sofi_studio/sofi_studio_controller.dart

import 'package:flutter/foundation.dart';
import 'sofi_studio_models.dart';

class SofiStudioController extends ChangeNotifier {
  VoidCallback? onClearGenerated;

  /// Whether the bottom drawer is currently open.
  bool isDrawerOpen = false;

  void clearGeneratedOverride() {
    onClearGenerated?.call();
  }

  void openDrawer() {
    isDrawerOpen = true;
    notifyListeners();
  }

  void closeDrawer() {
    isDrawerOpen = false;
    notifyListeners();
  }

  /// All dolls (base + premium)
  final List<SofiDoll> allDolls = [];

  /// Base dolls only
  final List<SofiDoll> baseDolls = [];

  /// Premium dolls only
  final List<SofiDoll> premiumDolls = [];

  /// Currently selected doll
  SofiDoll? currentDoll;

  /// ---------------------------------------------------------------
  /// LOAD DOLLS (from Firebase Storage)
  /// ---------------------------------------------------------------
  Future<void> loadDolls() async {
    baseDolls.clear();
    premiumDolls.clear();
    allDolls.clear();

    // ---------------------------
    // 10 BASE DOLLS (Firebase Storage)
    // Thumbs: images/dolls/base/thumbs/base_XX_base_thumb.png
    // Stage: images/dolls/base/stage/base_XX_base_stage.png
    // ---------------------------
    for (int i = 1; i <= 10; i++) {
      final num = two(i);
      baseDolls.add(
        SofiDoll(
          id: "$i",
          thumbPath: "images/dolls/base/thumbs/base_${num}_base_thumb.png",
          stagePath: "images/dolls/base/stage/base_${num}_base_stage.png",
          isPremium: false,
          isStoragePath: true, // Load from Firebase Storage
        ),
      );
    }

    // ---------------------------
    // 5 PREMIUM DOLLS (Firebase Storage)
    // Thumbs: images/dolls/special/thumbs/special_XX_base_thumb.png
    // Stage: images/dolls/special/stage/special_XX_base_stage.png
    // ---------------------------
    for (int i = 1; i <= 5; i++) {
      final num = two(i);
      premiumDolls.add(
        SofiDoll(
          id: "${100 + i}",
          thumbPath: "images/dolls/special/thumbs/special_${num}_base_thumb.png",
          stagePath: "images/dolls/special/stage/special_${num}_base_stage.png",
          isPremium: true,
          isStoragePath: true, // Load from Firebase Storage
        ),
      );
    }

    // Merge lists
    allDolls.addAll(baseDolls);
    allDolls.addAll(premiumDolls);

    // Default selection (first base doll)
    if (allDolls.isNotEmpty) {
      currentDoll = allDolls.first;
    }

    debugPrint("[SofiStudio] Loaded ${allDolls.length} dolls from Firebase Storage.");
  }

  /// ---------------------------------------------------------------
  /// SELECT A DOLL
  /// ---------------------------------------------------------------
  void selectDoll(SofiDoll doll) {
    currentDoll = doll;
    debugPrint("[SofiStudio] Selected doll id=${doll.id}");
  }

  /// ---------------------------------------------------------------
  /// Helper: convert integer to 2-digit string
  /// ---------------------------------------------------------------
  String two(int n) => n.toString().padLeft(2, '0');
}
