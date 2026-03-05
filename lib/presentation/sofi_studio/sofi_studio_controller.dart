// lib/presentation/sofi_studio/sofi_studio_controller.dart

import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'sofi_studio_models.dart';
import '../../services/two_step_generation_service.dart';
import '../../services/prompt_builder.dart';
import '../../services/mood_visual_mapper.dart';
import '../mood/mood_mode.dart';
import '../../services/models_lab_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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
  // ---------------------------------------------------------------
  // PROMPT OWNERSHIP (SINGLE SOURCE OF TRUTH)
  // ---------------------------------------------------------------
  String _currentPrompt = ''; // 🔑 The active templated prompt
  String get currentPrompt => _currentPrompt;

  String _rawUserIntention =
      ''; // 🔑 The clean user-facing intent (no system tags)
  String get rawUserIntention => _rawUserIntention;

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
    _rawUserIntention = userPrompt; // 🔑 Store the RAW intent

    _currentPrompt = buildSofiPrompt(
      userPrompt: userPrompt,
      mode: mode,
      mood: mood,
      styleStrength: styleStrength,
    );

    debugPrint('[PROMPT BUILT]\n$_currentPrompt');
    notifyListeners();
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

    skipWelcomeOverlay = true;

    // Use the mood name as the initial intention
    rebuildPrompt(
      userPrompt: mood,
      mode: mode.id,
      mood: mood,
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
      mood: mood,
    );

    hasPendingGeneration = true;
    notifyListeners();

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
    final intentionSnapshot = _rawUserIntention.isNotEmpty
        ? _rawUserIntention
        : 'high quality portrait';
    final fullPromptSnapshot = _currentPrompt;

    if (fullPromptSnapshot.isEmpty) {
      throw Exception('Prompt missing at generation time');
    }

    // 🔒 Build focused prompts for each step
    // Step 1: Identity Lock (uses RAW intent to avoid double-templating)
    final identityPrompt = buildStep1IdentityPrompt(
      userIntent: intentionSnapshot,
    );

    // Step 2: Style Application (uses the full TEMPLATED prompt we already built)
    final fullPrompt = fullPromptSnapshot;

    await Future<void>.delayed(const Duration(milliseconds: 300));

    isGenerating = true;
    generationError = null;
    hasPendingGeneration = false;
    notifyListeners();

    try {
      // SINGLE PASS GENERATION
      // Bypasses the strict 2-step lock to allow moods/clothing to actually apply
      final initImageBase64 = 'data:image/png;base64,${base64Encode(selfieBytes)}';
      
      final imageUrl = await ModelsLabService.generateKontextPro(
        prompt: fullPrompt,
        negativePrompt: 'changed face, different person, altered identity, '
            'bad anatomy, deformed, worst quality, uncanny valley',
        initImageBase64: initImageBase64,
        aspectRatio: '9:16',
        steps: 8, // Optimized for Turbo
        guidanceScale: 0.0, // Optimized for Turbo
        strength: 0.70, // 🔑 Balanced: High enough to allow clothing/style changes, low enough to keep face structural anchor
      );

      final resp = await http.get(Uri.parse(imageUrl));
      if (resp.statusCode != 200) {
        throw Exception('Failed to download generated image: ${resp.statusCode}');
      }
      final resultBytes = resp.bodyBytes;

      generatedImageBytes = resultBytes;
      skipWelcomeOverlay = false;
      return resultBytes;
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
