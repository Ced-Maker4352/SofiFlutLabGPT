// lib/presentation/sofi_studio/sofi_studio_controller.dart

import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'sofi_studio_models.dart';
import '../../services/prompt_builder.dart';
import '../mood/mood_mode.dart';
import '../../services/models_lab_service.dart';
import '../../services/remote_debug_logger.dart';
import '../../services/performance_service.dart';
import '../../services/two_step_generation_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:sofi_test_connect/services/user_preferences_service.dart';

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



  VoidCallback? onClearGenerated;

  SofiStudioController() {
    onClearGenerated = clearGeneratedImage;
    UserPreferencesService.instance.addListener(_onGenderPreferenceChanged);
  }

  @override
  void dispose() {
    UserPreferencesService.instance.removeListener(_onGenderPreferenceChanged);
    super.dispose();
  }

  void _onGenderPreferenceChanged() {
    // Reload dolls and rebuild prompt when gender changes
    loadDolls();
    rebuildPrompt(
      userPrompt: _rawUserIntention,
      mode: selectedMode.id,
      mood: selectedMood,
    );
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
    _rawUserIntention = userPrompt;
    final isMale = UserPreferencesService.instance.isMaleMode;

    // Use instruction-style prompt for flux-kontext-pro
    // If mood is neutral, it technically shouldn't override the whole instruction,
    // but the builder now mixes them together anyway
    if (mood.isNotEmpty && mood != 'neutral') {
      _currentPrompt = buildMoodEditInstruction(mood, userText: userPrompt, mode: mode, isMale: isMale);
    } else {
      _currentPrompt = buildCustomEditInstruction(userPrompt, mood: mood == 'neutral' ? '' : mood, mode: mode, isMale: isMale);
    }

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
  // ---------------------------------------------------------------
  // MOOD SELECTION HANDLER (RE-ARM GENERATION)
  // ---------------------------------------------------------------
  void onMoodSelectedInStudio(String mood) {
    selectedMood = mood;

    // Use instruction-style prompt for flux-kontext-pro
    _rawUserIntention = mood;
    final isMale = UserPreferencesService.instance.isMaleMode;
    _currentPrompt = buildMoodEditInstruction(mood, isMale: isMale);

    debugPrint('[Studio] Mood selected: $mood');
    debugPrint('[Studio] Instruction prompt: $_currentPrompt');

    hasPendingGeneration = true;
    notifyListeners();
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
  // GENERATION METHOD (KONTEXT PRO via flux-kontext-pro V7)
  // ---------------------------------------------------------------
  Future<Uint8List> generateFromSelfie({
    required Uint8List selfieBytes,
  }) async {
    if (isGenerating) throw Exception('Already generating in progress');

    final bool isDollMode = UserPreferencesService.instance.isDollMode;
    final bool isMaleMode = UserPreferencesService.instance.isMaleMode;

    // Use the already built _currentPrompt from the UI state.
    String prompt = _currentPrompt;
    
    // If the prompt is somehow empty, fallback to the base mood instruction.
    if (prompt.isEmpty) {
      prompt = buildMoodEditInstruction(
        selectedMood.isNotEmpty ? selectedMood : 'creative',
        isMale: isMaleMode,
      );
    }

    // Now securely append the mode instruction at the time of generation.
    // If doll mode is active, append its aesthetic override.
    if (isDollMode) {
      final genderLabel = isMaleMode ? 'male' : 'female';
      final dollAesthetic = 'Transform this into a full body $genderLabel fashion doll portrait. Show head-to-toe in a stylish pose with clean background. Soft plastic texture. ';
      if (!prompt.contains('plastic texture')) {
        prompt = '$prompt $dollAesthetic';
      }
    }

    debugPrint('[SofiStudio] Generating with instruction prompt: $prompt');

    await Future<void>.delayed(const Duration(milliseconds: 300));

    isGenerating = true;
    generationError = null;
    hasPendingGeneration = false;
    notifyListeners();

    try {
      // flux-kontext-pro: instruction-following model
      // No strength/steps/guidanceScale needed — model understands "change X, keep face"
      Uint8List resultBytes;

      if (isDollMode) {
        // DOLL MODE: Requires the Two-Step Pipeline to break identity lock
        final twoStep = TwoStepGenerationService();
        
        // Step 1: Force body transformation
        final genderLabel = isMaleMode ? 'male' : 'female';
        final lockedBody = await twoStep.runStep1IdentityLock(
          selfieBytes,
          'Transform this into a full body $genderLabel fashion doll portrait. Show head-to-toe in a stylish pose with clean background. Soft plastic texture. ',
        );

        // Step 2: Apply the user's outfit/mood prompt
        resultBytes = await twoStep.generateStyledOnly(
          lockedBody,
          prompt,
        );
      } else {
        // HUMAN MODE: Standard single pass
        final initImageBase64 = 'data:image/png;base64,${base64Encode(selfieBytes)}';
        final imageUrl = await ModelsLabService.generateKontextPro(
          prompt: prompt,
          negativePrompt: 'deformed face, changed identity, different person, '
              'bad anatomy, worst quality, blurry',
          initImageBase64: initImageBase64,
          aspectRatio: '9:16',
        );

        final resp = await http.get(Uri.parse(imageUrl));
        if (resp.statusCode != 200) {
          throw Exception('Failed to download generated image: \${resp.statusCode}');
        }
        resultBytes = resp.bodyBytes;
      }

      generatedImageBytes = resultBytes;
      skipWelcomeOverlay = false;
      return resultBytes;
    } catch (e) {
      generationError = e.toString();
      debugPrint('[SofiStudio] Generation error: \$e');
      rethrow;
    } finally {
      isGenerating = false;
      debugPrint('[GENERATION] Completed. Image bytes: '
          '\${generatedImageBytes?.length}');
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

    final bool isMale = UserPreferencesService.instance.isMaleMode;
    final String baseFolder = isMale ? "images/dolls/male/base" : "images/dolls/base";
    final String specialFolder = isMale ? "images/dolls/male/special" : "images/dolls/special";

    // ---------------------------
    // 10 BASE DOLLS (Firebase Storage)
    // ---------------------------
    for (int i = 1; i <= 10; i++) {
      final num = two(i);
      final String prefix = isMale ? "male" : "base";
      baseDolls.add(
        SofiDoll(
          id: "${isMale ? 'm' : ''}$i",
          thumbPath: "$baseFolder/thumbs/${prefix}_${num}_base_thumb.png",
          stagePath: "$baseFolder/stage/${prefix}_${num}_base_stage.png",
          isPremium: false,
          isStoragePath: true, // Load from Firebase Storage
        ),
      );
    }

    // ---------------------------
    // 5 PREMIUM DOLLS (Firebase Storage)
    // ---------------------------
    for (int i = 1; i <= 5; i++) {
      final num = two(i);
      final String prefix = isMale ? "male_special" : "special";
      premiumDolls.add(
        SofiDoll(
          id: "${isMale ? 'ms' : ''}${100 + i}",
          thumbPath:
              "$specialFolder/thumbs/${prefix}_${num}_base_thumb.png",
          stagePath: "$specialFolder/stage/${prefix}_${num}_base_stage.png",
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
