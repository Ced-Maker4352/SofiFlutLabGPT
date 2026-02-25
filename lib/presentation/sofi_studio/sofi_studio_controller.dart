// lib/presentation/sofi_studio/sofi_studio_controller.dart

import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'sofi_studio_models.dart';
import '../../services/two_step_generation_service.dart';
import '../../services/prompt_builder.dart';
import '../../services/mood_visual_mapper.dart';
import '../mood/mood_mode.dart';

class SofiStudioController extends ChangeNotifier {
  // ---------------------------------------------------------------
  // GENERATION STATE
  // ---------------------------------------------------------------
  Uint8List? generatedImageBytes;
  bool isGenerating = false;
  String? generationError;
  bool hasPendingGeneration = false; // 🔑 Re-arm flag for mood selection
  bool autoGenConsumed = false; // 🔑 Prevents double auto-generation
  Uint8List? selfieBytes; // 🔑 Stored selfie for mood-triggered generation
  bool skipWelcomeOverlay =
      false; // 🔑 Bypass welcome overlay when entering from Mood flow

  // ---------------------------------------------------------------
  // PROMPT OWNERSHIP (SINGLE SOURCE OF TRUTH)
  // ---------------------------------------------------------------
  String _currentPrompt = ''; // 🔑 The active prompt used by Generate button
  String get currentPrompt => _currentPrompt;
  String selectedMood = '';
  MoodMode selectedMode = MoodMode.doll;

  final _twoStep = const TwoStepGenerationService();

  VoidCallback? onClearGenerated;

  SofiStudioController() {
    onClearGenerated = clearGeneratedImage;
  }

  /// Whether the bottom drawer is currently open.
  bool isDrawerOpen = false;

  void clearGeneratedOverride() {
    onClearGenerated?.call();
  }

  // ---------------------------------------------------------------
  // PROMPT BUILDER (CENTRALIZED)
  // ---------------------------------------------------------------
  void rebuildPrompt({
    required String userPrompt,
    required String mode,
    String mood = '',
    double styleStrength = 7.0,
  }) {
    _currentPrompt = buildSofiPrompt(
      userPrompt: userPrompt,
      mode: mode,
      mood: mood,
      styleStrength: styleStrength,
    );

    debugPrint('[PROMPT BUILT]\n$_currentPrompt');
    notifyListeners(); // 🔑 FIX #1: Explicit rebuild notification
  }

  // ---------------------------------------------------------------
  // MOOD FLOW ENTRY (SINGLE ENTRY POINT FROM MOOD PAGE)
  // ---------------------------------------------------------------
  void enterFromMoodFlow({
    required Uint8List selfie,
    required String mood,
    required MoodMode mode,
  }) {
    debugPrint('[Studio] Entering from Mood flow');
    debugPrint('[Studio] Mode: ${mode.id}, Mood: $mood');

    selfieBytes = selfie;
    selectedMood = mood;
    selectedMode = mode;

    // 🔑 FIX: Skip welcome overlay and auto-generate
    skipWelcomeOverlay = true;

    rebuildPrompt(
      userPrompt: mood,
      mode: mode.id,
      mood: mood, // 🔑 FIX: Pass mood for style flavor
    );

    hasPendingGeneration = true;
    autoGenConsumed = false;

    debugPrint('[Studio] Prompt built, ready for auto-generation');
    if (hasListeners) notifyListeners();
  }

  // ---------------------------------------------------------------
  // MOOD SELECTION HANDLER (RE-ARM GENERATION)
  // ---------------------------------------------------------------
  void onMoodSelectedInStudio(String mood) {
    selectedMood = mood;

    final visualPrompt = MoodVisualMapper.map(mood);

    rebuildPrompt(
      userPrompt: visualPrompt,
      mode: selectedMode.id,
      mood: mood, // 🔑 Pass mood for style preset mapping
    );

    hasPendingGeneration = true;
    notifyListeners();

    // 🔑 STEP 3: Auto-trigger generation on mood change
    debugPrint('[UI] Triggering generateFromSelfie');
    if (selfieBytes != null && !isGenerating) {
      generateFromSelfie(selfieBytes: selfieBytes!);
    }
  }

  // ---------------------------------------------------------------
  // GENERATION ENTRY POINT (PUBLIC API)
  // ---------------------------------------------------------------
  Future<Uint8List> generateIfReady({
    required Uint8List selfieBytes,
  }) async {
    if (_currentPrompt.isEmpty) {
      throw Exception('Attempted generation with empty prompt');
    }
    return await generateFromSelfie(selfieBytes: selfieBytes);
  }

  // ---------------------------------------------------------------
  // GENERATION METHOD (KONTEXT PRO - INTERNAL)
  // ---------------------------------------------------------------
  Future<Uint8List> generateFromSelfie({
    required Uint8List selfieBytes,
  }) async {
    if (isGenerating) throw Exception('Already generating in progress');

    // Snapshot current state
    final userPromptSnapshot =
        selectedMood.isNotEmpty ? selectedMood : _currentPrompt;
    final modeSnapshot = selectedMode.id;

    // 🔒 Build focused prompts
    final identityPrompt = buildSofiPrompt(
      userPrompt: userPromptSnapshot,
      mode: modeSnapshot,
      identityOnly: true,
    );

    final fullPrompt = _currentPrompt;

    if (fullPrompt.isEmpty) {
      throw Exception('Prompt missing at generation time');
    }

    await Future<void>.delayed(const Duration(milliseconds: 300));

    isGenerating = true;
    generationError = null;
    hasPendingGeneration = false;
    notifyListeners();

    try {
      // STEP 1 — identity lock (uses CLEAN identity-only prompt)
      final locked = await _twoStep.runStep1IdentityLock(
        selfieBytes,
        identityPrompt,
      );

      // STEP 2 — style application (uses FULL stylized prompt)
      final styled = await _twoStep.generateStyledOnly(
        locked,
        fullPrompt,
      );

      generatedImageBytes = styled;
      skipWelcomeOverlay = false;
      return styled;
    } catch (e) {
      generationError = e.toString();
      debugPrint('[SofiStudio] Generation error: $e');
      rethrow;
    } finally {
      isGenerating = false;
      debugPrint('[GENERATION] Completed. Image bytes: '
          '${generatedImageBytes?.length}');
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------
  // CLEAR GENERATED IMAGE
  // ---------------------------------------------------------------
  void clearGeneratedImage() {
    generatedImageBytes = null;
    generationError = null;
    skipWelcomeOverlay =
        false; // 🔑 Reset flag so welcome overlay can show on next normal entry
    notifyListeners();
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
          thumbPath:
              "images/dolls/special/thumbs/special_${num}_base_thumb.png",
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

    debugPrint(
        "[SofiStudio] Loaded ${allDolls.length} dolls from Firebase Storage.");
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
