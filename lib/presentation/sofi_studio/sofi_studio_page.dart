// lib/presentation/sofi_studio/sofi_studio_page.dart

import 'dart:convert';
import 'dart:async' show Timer, unawaited;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform;
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/rendering.dart';

import 'package:sofi_test_connect/services/premium_service.dart';
import 'package:sofi_test_connect/services/performance_service.dart';
import 'package:sofi_test_connect/services/sofi_session_memory.dart';
import 'package:sofi_test_connect/presentation/premium/paywall_sheet.dart';
import 'package:sofi_test_connect/presentation/premium/premium_page.dart';
import 'package:sofi_test_connect/presentation/mood/mood_mode.dart';

import 'package:sofi_test_connect/services/two_step_generation_service.dart';
import 'package:sofi_test_connect/services/audio_service.dart';
import 'package:sofi_test_connect/services/storage_service.dart';
import 'package:sofi_test_connect/services/voice_coach_service.dart';
import 'package:sofi_test_connect/services/user_preferences_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:sofi_test_connect/services/theme_manager.dart';
import 'package:sofi_test_connect/services/remote_debug_logger.dart';
import 'package:sofi_test_connect/presentation/sofi_studio/favorites_manager.dart';
import 'package:sofi_test_connect/presentation/sofi_studio/models/favorite_outfit.dart';
import 'package:http/http.dart' as http;

import '../../constants/base_prompts.dart';
import '../../services/sofi_export_service.dart';
import '../../services/mood_visual_mapper.dart';
import 'web_download.dart';

import 'custom_doll_storage.dart';
import 'sofi_prompt_data.dart';
import 'sofi_studio_controller.dart';
import 'sofi_studio_models.dart';
import 'sofi_studio_theme.dart';
import 'sofi_male_prompt_data.dart';
import 'widgets/sofi_bottom_drawer.dart';
import 'widgets/sofi_history_sheet.dart';
import 'widgets/generation_loader.dart';
import 'widgets/voice_coach_settings_sheet.dart';
import 'widgets/sofi_settings_sheet.dart';
import 'dart:typed_data';
import 'package:confetti/confetti.dart';

class _QuickMood {
  final String id;
  final String label;
  final IconData icon;
  final String promptFragment;
  const _QuickMood({
    required this.id,
    required this.label,
    required this.icon,
    required this.promptFragment,
  });
}

class SofiStudioPage extends StatefulWidget {
  /// 🔑 Passed from MoodCameraEntryPage via Splash
  final String? initialMood;
  final String?
      initialMode; // 'human' | 'doll' | 'cinematic' | 'fantasy' | 'anime'
  final Uint8List? selfieBytes;
  final String? selfiePath;

  /// 🔑 NEW: Callback to configure controller after creation (for Mood flow)
  final void Function(SofiStudioController controller)? onControllerReady;

  const SofiStudioPage({
    super.key,
    this.initialMood,
    this.initialMode,
    this.selfieBytes,
    this.selfiePath,
    this.onControllerReady,
  });

  @override
  State<SofiStudioPage> createState() => _SofiStudioPageState();
}

class _SofiStudioPageState extends State<SofiStudioPage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // Pre-define all BorderRadius constants to prevent null values during rebuilds (Flutter Web crash fix)
  static const _radius32 = BorderRadius.all(Radius.circular(32));
  static const _radius24 = BorderRadius.all(Radius.circular(24));
  static const _radius20 = BorderRadius.all(Radius.circular(20));
  static const _radius16 = BorderRadius.all(Radius.circular(16));
  static const _radius12 = BorderRadius.all(Radius.circular(12));
  static const _radius10 = BorderRadius.all(Radius.circular(10));
  static const _radius100 = BorderRadius.all(Radius.circular(100));
  static const _radiusTop24 = BorderRadius.vertical(top: Radius.circular(24));

  final SofiStudioController controller = SofiStudioController();
  bool _isGenerating = false;
  // If we detect ModelsLab credit exhaustion, reflect it in UI and gate the button.
  bool _outOfCredits = false;

  // Animation for Generate button
  AnimationController? _generateBtnController;
  Animation<double>? _generateBtnScale;

  // Animation for Drawer
  late final AnimationController _drawerController;
  late final Animation<double> _drawerAnimation;

  final SpeechToText _speech = SpeechToText();
  bool _listening = false;
  final ImagePicker _picker = ImagePicker();

  Uint8List? generatedImageBytes;
  String? _latestImageUrl; // Track the URL for share/download
  final List<Uint8List> _history = [];
  final List<Uint8List> _redoStack = [];
  late ConfettiController _confettiController;

  // CRITICAL: Store the ORIGINAL base doll image to prevent generation drift.
  // This ensures we always generate from a clean source, not from previous outputs.
  Uint8List? _originalBaseDollBytes;

  // Helper: Did we enter from QuickMood selfie flow?
  bool get _fromQuickMoodSelfie {
    final bytes = controller.selfieBytes ?? widget.selfieBytes;
    return bytes != null && bytes.isNotEmpty;
  }

  /// Check if we should show the preview watermark
  bool _shouldShowPreviewWatermark() {
    // Only show watermark for free users in Quick-Mood flow with premium modes
    if (widget.initialMood == null || widget.initialMood!.isEmpty) return false;

    try {
      final mode = MoodMode.values.byName(widget.initialMood!);
      final premium = PremiumService();
      return premium.currentPlan == SubscriptionPlan.free && mode.isPremium;
    } catch (_) {
      return false;
    }
  }

  // ignore: unused_field
  List<FavoriteOutfit> _favorites = [];
  bool _isFavorited = false;

  // Generation counter for premium reminder
  int _generationCount = 0;
  bool _showPremiumReminder = false;
  Timer? _premiumReminderTimer;

  // Cooldown after generation to prevent rapid-fire requests
  bool _isOnCooldown = false;
  Timer? _cooldownTimer;
  static const Duration _cooldownDuration = Duration(seconds: 4);

  // When set, this overrides the default "3D Sofi Studio doll..." base prompt
  // allowing premium styles (e.g. Comic Book) to persist during editing.
  String? _activeBaseStylePrompt;

  // ================================
  // QUICK MOOD (Startup-ready)
  // ================================
  // Mood is a LIGHT style layer (lighting/palette/vibe) — not a full prompt rewrite.
  // It must NEVER be stacked/duplicated inside the free-form text field.
  //
  // Default mood is always active so the user never sees a “blank direction” state.
  static const List<_QuickMood> _quickMoods = [
    _QuickMood(
      id: 'glow',
      label: 'Magic Glow',
      icon: Icons.auto_awesome,
      promptFragment:
          'magical sparkly mood, rainbow-tinted lighting, glowing fairy dust, vibrant playful colors, high-quality 3D render',
    ),
    _QuickMood(
      id: 'noir',
      label: 'Starry Night',
      icon: Icons.stars,
      promptFragment:
          'dreamy night sky vibe, deep blues and purples, glowing stars, magical moonlit atmosphere, soft cinematic render',
    ),
    _QuickMood(
      id: 'pastel',
      label: 'Candy Pastel',
      icon: Icons.icecream,
      promptFragment:
          'bright cotton candy colors, pink and mint and lilac palette, playful sugary aesthetic, soft airy lighting, clean cute background',
    ),
    _QuickMood(
      id: 'street',
      label: 'Super Kid',
      icon: Icons.rocket_launch,
      promptFragment:
          'high-energy comic styles, bright primary colors, superhero vibrant vibe, sharp clean details, playful powerful energy',
    ),
    _QuickMood(
      id: 'lux',
      label: 'Royal',
      icon: Icons.crown,
      promptFragment:
          'royal prince and princess aesthetic, gold sparkles, crown jewels, majestic shimmering details, elegant royal studio lighting',
    ),
  ];

  // Always keep one active mood.
  String _activeMoodId = 'glow';

  _QuickMood get _activeMood =>
      _quickMoods.firstWhere((m) => m.id == _activeMoodId,
          orElse: () => _quickMoods.first);

  void _setQuickMood(String moodId) {
    if (_activeMoodId == moodId) return;
    if (!mounted) return;
    // 🔒 FIX #4: Block mood changes during generation
    if (controller.isGenerating) return;

    setState(() => _activeMoodId = moodId);

    // 🔑 RE-ARM GENERATION: Notify controller that mood changed
    controller.onMoodSelectedInStudio(moodId);

    // REMOTE DEBUG LOG: Mood changed (non-blocking)
    unawaited(RemoteDebugLogger.instance.logInteraction('MOOD_CHANGED', {
      'moodId': moodId,
      'label': _activeMood.label,
    }).catchError((_) {}));

    // Subtle feedback
    try {
      unawaited(AudioService.instance.playClick());
    } catch (_) {}
  }

  // Debounce timer for category selections (prevents crash from rapid taps)
  Timer? _selectionDebounceTimer;
  bool _selectionInProgress = false;

  // Pending selection to apply after debounce
  EditCategory? _pendingCategory;
  int? _pendingOption;

  final TextEditingController promptController = TextEditingController();

  // Heartbeat to detect app freeze/crash
  Timer? _heartbeatTimer;
  DateTime _lastHeartbeat = DateTime.now();

  // iOS Safari/web often requires a user gesture to enable audio output (TTS/UI sounds).
  // We show a one-time invisible tap catcher to unlock sound and trigger the intro.
  bool _awaitingFirstSoundUnlock = kIsWeb;

  // First-time canvas hint overlay
  bool _showCanvasHint = false;

  // Mood flow gate: block auto-generation until user taps Continue Styling
  bool _awaitingMoodFlowContinue = false;

  // Platform hint to tweak shadows/effects for iOS Web (reduce heavy blurs)
  bool get _isIOSWeb => kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  // Session-remembered preferences
  String _selectedMode = 'pixar';
  double _guidanceScale = 6.8;
  String _selectedRatio = 'portrait';

  final Map<EditCategory, int?> selectedOptions = {
    EditCategory.background: null,
  };

  // --- TEXT CAPTION STATE ---
  final GlobalKey _stageKey = GlobalKey();
  String _captionText = '';
  String _captionFont = 'Fredoka';
  EditCategory? _drawerInitialCategory;
  bool _showUI = true;
  Color _captionColor = Colors.white;
  double _captionY = 0.85; // 0.1 (top), 0.5 (mid), 0.85 (bottom)
  final List<String> _captionFonts = [
    'Luckiest Guy',
    'Pacifico',
    'Bangers',
    'Chewy',
    'Fredoka',
    'Indie Flower',
    'Patrick Hand',
    'Permanent Marker',
    'Amatic SC',
    'Comic Neue',
  ];

  @override
  void initState() {
    super.initState();

    // 🔑 STEP 6: Call onControllerReady callback immediately after controller creation
    widget.onControllerReady?.call(controller);

    // If Mood flow injected a selfie + pending generation, require user to press Continue
    _awaitingMoodFlowContinue =
        controller.selfieBytes != null && controller.hasPendingGeneration;
    if (_awaitingMoodFlowContinue) {
      _showCanvasHint = true; // ensure overlay is visible immediately
    }

    // REMOTE DEBUG LOG: Page entry
    unawaited(RemoteDebugLogger.instance
        .logInteraction('PAGE_ENTER', {'page': 'SofiStudioPage'}));

    // Drawer Animation
    _drawerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _drawerAnimation =
        CurvedAnimation(parent: _drawerController, curve: Curves.easeOutCubic);

    _confettiController = ConfettiController(duration: const Duration(seconds: 3));

    controller.addListener(() {
      try {
        if (controller.isDrawerOpen) {
          if (_drawerController.status != AnimationStatus.forward &&
              _drawerController.status != AnimationStatus.completed) {
            AudioService.instance.playSlideUp();
            _drawerController.forward();
          }
        } else {
          if (_drawerController.status != AnimationStatus.reverse &&
              _drawerController.status != AnimationStatus.dismissed) {
            AudioService.instance.playSlideDown();
            _drawerController.reverse().then((_) {
              if (mounted) AudioService.instance.playPop();
            }).catchError((e) {
              debugPrint('[SofiStudio] Drawer animation error: $e');
            });
          }
        }
        // Only rebuild if mounted and drawer state actually needs UI update
        if (mounted) setState(() {});
      } catch (e) {
        debugPrint('[SofiStudio] Controller listener error: $e');
      }
    });

    // Debounced prompt listener - only rebuild when text changes significantly
    String lastPrompt = '';
    promptController.addListener(() {
      final newText = promptController.text;
      if (newText != lastPrompt) {
        lastPrompt = newText;
        if (mounted) setState(() {});
      }
    });

    // Generate button pulse animation
    final ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _generateBtnController = ctrl;
    _generateBtnScale = Tween<double>(begin: 1.0, end: 1.05)
        .animate(CurvedAnimation(parent: ctrl, curve: Curves.easeInOut));

    ThemeManager.instance.addListener(_onThemeChanged);

    // STEP 3 — Force-hide Welcome overlay if entering from Mood flow
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (controller.skipWelcomeOverlay && _showCanvasHint) {
        setState(() {
          _showCanvasHint = false;
        });
        debugPrint('[Studio] Force-dismissed canvas hint (skipWelcomeOverlay)');
      }
    });

    // Observe app lifecycle to detect backgrounding/crashes
    WidgetsBinding.instance.addObserver(this);

    // Start heartbeat to detect freeze/crash (every 5s)
    _startHeartbeat();

    _init();

    // Load session memory (mode, guidance, ratio)
    SofiSessionMemory.load().then((memory) {
      if (!mounted) return;
      setState(() {
        _selectedMode = memory['mode'];
        _guidanceScale = memory['guidance'];
        _selectedRatio = memory['ratio'];
      });
    }).catchError((e) {
      debugPrint('⚠️ [SessionMemory] Failed to load: $e');
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint('\ud83d\udd04 [Lifecycle] State changed to: $state');
    try {
      RemoteDebugLogger.instance
          .logInteraction('LIFECYCLE_CHANGE', {'state': state.name})
          .timeout(const Duration(seconds: 1))
          .catchError((_) {});
    } catch (_) {}

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // App going to background - stop any ongoing work
      if (_isGenerating) {
        debugPrint('\u26a0\ufe0f [Lifecycle] App pausing while generating!');
      }
      if (_listening) {
        debugPrint('\u26a0\ufe0f [Lifecycle] App pausing while listening!');
        try {
          _speech.stop().catchError((_) {});
          if (mounted) {
            setState(() => _listening = false);
          }
        } catch (_) {}
      }

      // Cancel all timers to prevent crashes when app is backgrounded
      _heartbeatTimer?.cancel();
      _premiumReminderTimer?.cancel();
      _selectionDebounceTimer?.cancel();
      _cooldownTimer?.cancel();
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      final now = DateTime.now();
      final gap = now.difference(_lastHeartbeat).inSeconds;

      if (gap > 15) {
        // App was likely frozen for >15s
        debugPrint(
            '\u26a0\ufe0f [Heartbeat] Possible freeze detected (gap: ${gap}s)');
        try {
          RemoteDebugLogger.instance
              .logWarning('Possible app freeze', {
                'gapSeconds': gap,
                'isGenerating': _isGenerating,
              })
              .timeout(const Duration(seconds: 1))
              .catchError((_) {});
        } catch (_) {}
      }

      _lastHeartbeat = now;

      // Also log if we're in generating state for too long
      if (_isGenerating) {
        debugPrint('\ud83d\udd52 [Heartbeat] Still generating...');
      }
    });
  }

  @override
  void dispose() {
    // REMOTE DEBUG LOG: Page exit (may indicate crash if followed by SESSION_START)
    debugPrint('\ud83d\udea8 [Dispose] SofiStudioPage disposing');
    unawaited(RemoteDebugLogger.instance
        .logInteraction('PAGE_EXIT', {'page': 'SofiStudioPage'}));
    unawaited(
        RemoteDebugLogger.instance.flush()); // Ensure logs are sent before exit
    _confettiController.dispose();

    // Remove lifecycle observer
    WidgetsBinding.instance.removeObserver(this);

    // Stop heartbeat
    _heartbeatTimer?.cancel();

    // Ensure any ongoing dictation is stopped to avoid dangling audio sessions
    try {
      unawaited(_speech.stop());
    } catch (_) {}

    _drawerController.dispose();
    _generateBtnController?.dispose();
    promptController.dispose();
    _premiumReminderTimer?.cancel();
    _selectionDebounceTimer?.cancel();
    _cooldownTimer?.cancel();
    ThemeManager.instance.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _init() async {
    // Detect direct prop-based Mood flow (fallback path)
    if (!_awaitingMoodFlowContinue &&
        widget.selfieBytes != null &&
        widget.initialMood != null) {
      _awaitingMoodFlowContinue = true;
      _showCanvasHint = true;
    }

    // PRIORITY: Load user's last image FIRST before anything else
    // This ensures we show the right image immediately without showing default doll first
    // ================================
    // QUICK MOOD HANDOFF (ENTRY OVERRIDE)
    // ================================
    final Uint8List? incomingSelfie =
        controller.selfieBytes ?? widget.selfieBytes;
    final String? incomingMood = controller.selectedMood.isNotEmpty
        ? controller.selectedMood
        : widget.initialMood;

    if (incomingSelfie != null) {
      debugPrint('[QuickMood] 🔥 Entry from Mood flow with selfie');
      debugPrint(
          '[QuickMood] Mode: ${widget.initialMode ?? controller.selectedMode.id}');

      // Treat selfie as the ORIGINAL base to prevent drift
      _originalBaseDollBytes = incomingSelfie;
      generatedImageBytes = incomingSelfie;

      // Preselect mood (light style layer only)
      if (incomingMood != null && incomingMood.isNotEmpty) {
        _activeMoodId = incomingMood;
        debugPrint('[QuickMood] Mood preselected: $incomingMood');
      }
    }

    // 🔑 INITIALIZE CONTROLLER MOOD & MODE (respect injected state from Mood flow)
    if (widget.initialMode != null) {
      controller.selectedMode = switch (widget.initialMode) {
        'human' => MoodMode.human,
        'cinematic' => MoodMode.cinematic,
        'fantasy' => MoodMode.fantasy,
        'artistic' => MoodMode.artistic,
        'doll' => MoodMode.doll,
        _ => MoodMode.doll,
      };
    }

    // 🔑 Store selfieBytes on controller for mood-triggered generation (but never overwrite injected value)
    controller.selfieBytes ??= widget.selfieBytes;

    // Initialize prompt if we have a mood and prompt hasn't been set by callback
    final initialMood = controller.selectedMood.isNotEmpty
        ? controller.selectedMood
        : widget.initialMood;
    if (initialMood != null && controller.currentPrompt.isEmpty) {
      controller.selectedMood = initialMood;
      controller.rebuildPrompt(
        userPrompt: initialMood,
        mode: controller.selectedMode.id,
        mood: initialMood,
      );
      controller.hasPendingGeneration = true;
      debugPrint('[Controller] Initial prompt: ${controller.currentPrompt}');
    }

    await controller.loadDolls();

    controller.onClearGenerated = () {
      if (!mounted) return;
      setState(() {
        generatedImageBytes = null;
        _originalBaseDollBytes = null; // Also clear original base on reset
        _history.clear();
        _redoStack.clear();
        _activeBaseStylePrompt = null;
        _isFavorited = false;
      });
    };

    // Load history BEFORE anything else - only load last 3 initially for speed
    try {
      final storedHistory = await CustomDollStorage.loadHistory(maxItems: 3);
      if (!mounted) return;

      setState(() {
        _history
          ..clear()
          ..addAll(storedHistory);
        if (_history.isNotEmpty) {
          // If coming from Quick-Mood selfie flow, DO NOT overwrite the selfie canvas
          if (!_fromQuickMoodSelfie) {
            generatedImageBytes = _history.last;
          }

          // NOTE: History images are previous outputs.
          // We never use them as generation base to prevent drift.
        }
      });

      // ❌ STEP 1 FIX: DO NOT AUTO-GENERATE ON PAGE ENTER (TEMPORARILY DISABLED)
      // This stabilizes the render lifecycle and prevents web crashes
      // 🔥 QUICK-MOOD AUTO-GENERATE (ONCE) - TEMPORARILY COMMENTED OUT
      // If we entered from the Mood page with a selfie + mood,
      // trigger exactly one automatic generation after canvas is ready.
      // if (_fromQuickMoodSelfie &&
      //     widget.initialMood != null &&
      //     widget.initialMood!.isNotEmpty &&
      //     widget.initialMode != null &&
      //     !_didQuickMoodAutoGenerate) {
      //   _didQuickMoodAutoGenerate = true;

      //   // 🔑 FIX: Use controller's centralized prompt system
      //   final mood = widget.initialMood!;
      //   final mode = widget.initialMode!;
      //   final selfieBytes = widget.selfieBytes;

      //   if (selfieBytes != null && selfieBytes.isNotEmpty) {
      //     // 1️⃣ Set mode FIRST
      //     controller.selectedMode = MoodMode.values.byName(mode);

      //     // 2️⃣ Rebuild prompt from mood
      //     controller.onMoodSelectedInStudio(mood);

      //     // 3️⃣ Defer generation until next frame (prevents race)
      //     WidgetsBinding.instance.addPostFrameCallback((_) async {
      //       if (!mounted) return;
      //       if (_isGenerating || controller.isGenerating) return;

      //       debugPrint('[QuickMood] 🚀 Auto-generating from mood: $mood, mode: $mode');

      //       // Dismiss canvas hint if showing (auto-gen takes priority)
      //       if (_showCanvasHint) {
      //         setState(() => _showCanvasHint = false);
      //       }

      //       await controller.generateIfReady(
      //         selfieBytes: selfieBytes,
      //       );
      //     });
      //   } else {
      //     debugPrint('⚠️ [QuickMood] Auto-gen blocked: No selfie bytes');
      //   }
      // }

      // Preload original base doll ONLY when NOT coming from Quick-Mood selfie
      if (!_fromQuickMoodSelfie && controller.currentDoll != null) {
        try {
          final baseDollBytes = await _loadDollImage(
            controller.currentDoll!.stagePath,
            controller.currentDoll!.isStoragePath,
          ).timeout(const Duration(seconds: 10));
          if (mounted) {
            _originalBaseDollBytes = baseDollBytes;
            debugPrint(
                '[SofiStudio] ✅ Preloaded original base doll for drift prevention');
          }
        } catch (e) {
          debugPrint('[SofiStudio] ⚠️ Could not preload base doll: $e');
        }
      }
    } catch (e) {
      debugPrint('[SofiStudio] History load error: $e');
    }

    // NOW start deferred/background tasks after canvas is ready
    await _checkFirstVisitHint();

    // 🔑 AUTO-GEN TRIGGER: Fire auto-generation AFTER all setup is complete
    // This is the most reliable location — dolls loaded, selfie set, hint dismissed
    if (controller.hasPendingGeneration &&
        controller.selfieBytes != null &&
        !controller.autoGenConsumed &&
        !_isGenerating &&
        !controller.isGenerating) {
      debugPrint(
          '[Studio] 🚀 AUTO-GEN: Triggering from _init() — all setup complete');
      debugPrint(
          '[Studio] AUTO-GEN state: hasPending=${controller.hasPendingGeneration}'
          ' selfieLen=${controller.selfieBytes!.length}'
          ' currentDoll=${controller.currentDoll != null ? "loaded" : "null"}');

      // Dismiss canvas hint if still showing
      if (_showCanvasHint || _awaitingMoodFlowContinue) {
        setState(() {
          _showCanvasHint = false;
          _awaitingMoodFlowContinue = false;
        });
      }

      controller.autoGenConsumed = true;
      // Small delay to ensure the UI is fully rendered
      Future.delayed(const Duration(milliseconds: 200), () {
        if (!mounted) return;
        if (_isGenerating) return;
        debugPrint('[Studio] 🚀 AUTO-GEN: Firing _onGeneratePressed()');
        _onGeneratePressed();
      });
    }

    // Initialize voice coach (non-blocking, delayed)
    Future<void>.delayed(const Duration(milliseconds: 800)).then((_) {
      if (!mounted) return;
      unawaited(VoiceCoachService.instance.initialize().catchError((e, st) {
        debugPrint('[SofiStudio] VoiceCoach init error: $e\n$st');
      }));
    });

    // Pre-cache drawer URLs only AFTER initial load is complete (delayed)
    Future<void>.delayed(const Duration(seconds: 2)).then((_) {
      if (!mounted) return;

      unawaited(
        StorageService.instance
            // UI compatibility stub — empty list is intentional
            .precacheDrawerUrls(const []).catchError((e, st) {
          debugPrint('[SofiStudio] URL precache error: $e\n$st');
        }).then((_) async {
          // Optional: run a quiet verification pass to ensure
          // thumbs ↔ prompts and dolls ↔ stages map correctly
          await Future<void>.delayed(const Duration(seconds: 1));

          unawaited(
            StorageService.instance
                .verifyAllAssetMappings()
                .catchError((e, st) {
              debugPrint('[SofiStudio] Asset verify error: $e\n$st');
            }),
          );
        }),
      );
    });

    // Load favorites in background after main canvas is ready
    unawaited(_loadFavorites().catchError((e) {
      debugPrint('[SofiStudio] Favorites load error: $e');
    }));

    // After first frame, give a short, spoken intro (once per session)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // On web/iOS Safari, defer speaking until a user gesture unlocks audio.
      if (!kIsWeb) {
        Future<void>.delayed(const Duration(milliseconds: 600)).then((_) {
          if (!mounted) return;
          unawaited(
              VoiceCoachService.instance.speakWelcomeIntro().catchError((e) {
            debugPrint('[VoiceCoach] speakWelcomeIntro error: $e');
          }));
        });
      }
    });
  }

  Future<void> _loadFavorites() async {
    try {
      final favs = await FavoritesManager.load();
      if (mounted) setState(() => _favorites = favs);
    } catch (e) {
      debugPrint('Error loading favorites: $e');
    }
  }

  Future<void> _checkFirstVisitHint() async {
    // Skip hint overlay when coming from Mood flow via controller flag
    // (auto-generation should run uninterrupted)
    if (controller.skipWelcomeOverlay) {
      debugPrint('[Studio] Skipping canvas hint (skipWelcomeOverlay = true)');
      return;
    }

    // Show the hint overlay on regular app restart
    if (mounted) {
      setState(() => _showCanvasHint = true);
    }
  }

  void _dismissCanvasHint() {
    if (!mounted) return;

    // STEP 4  Clear controller flag when user manually dismisses
    controller.skipWelcomeOverlay = false;

    // Once overlay is dismissed, allow generation to proceed
    _awaitingMoodFlowContinue = false;

    setState(() => _showCanvasHint = false);
    // Don't persist - show again on next restart

    // On web, dismissing the hint also unlocks audio and speaks intro
    if (kIsWeb && _awaitingFirstSoundUnlock) {
      if (!mounted) return;
      setState(() => _awaitingFirstSoundUnlock = false);
      AudioService.instance.playClick();
      unawaited(VoiceCoachService.instance.speakWelcomeIntro().catchError((e) {
        debugPrint('[VoiceCoach] speakWelcomeIntro error: $e');
      }));
    }
  }
  /// Handler for "Continue Styling" button - safely triggers generation after dismiss
  void _onContinueStylingPressed() {
    // Prevent focus crashes on Flutter Web
    FocusScope.of(context).unfocus();

    // Mark flow as acknowledged so auto-trigger stays suppressed
    controller.autoGenConsumed = true;
    _awaitingMoodFlowContinue = false;

    // Dismiss overlay (not a modal, so no Navigator.pop)
    _dismissCanvasHint();

    // IMPORTANT: defer generation until after dismiss completes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _triggerGenerate(); // safe, deferred trigger
    });
  }

  Future<void> _pickSelfie() async {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Change your selfie'),
        message: const Text('Taking a clear, front-facing selfie works best.'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.pop(context);
              final file = await _picker.pickImage(
                source: ImageSource.camera,
                imageQuality: 92,
              );
              if (file != null) {
                final bytes = await file.readAsBytes();
                if (mounted) {
                  setState(() {
                    _originalBaseDollBytes = bytes;
                    generatedImageBytes = bytes;
                    controller.selfieBytes = bytes;
                  });
                  // Auto-trigger generation with current settings
                  _onGenerate();
                }
              }
            },
            child: const Text('Take Picture'),
          ),
          CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.pop(context);
              final file = await _picker.pickImage(
                source: ImageSource.gallery,
                imageQuality: 92,
              );
              if (file != null) {
                final bytes = await file.readAsBytes();
                if (mounted) {
                  setState(() {
                    _originalBaseDollBytes = bytes;
                    generatedImageBytes = bytes;
                    controller.selfieBytes = bytes;
                  });
                  // Auto-trigger generation with current settings
                  _onGenerate();
                }
              }
            },
            child: const Text('Choose from Gallery'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  /// Safely triggers generation if conditions are met
  void _triggerGenerate() {
    if (controller.isGenerating) {
      debugPrint(
          '[UI] _triggerGenerate: Generation already in progress, skipping');
      return;
    }
    if (controller.selfieBytes == null) {
      debugPrint('[UI] _triggerGenerate: No selfie bytes, cannot generate');
      return;
    }
    if (!controller.hasPendingGeneration) {
      debugPrint('[UI] _triggerGenerate: No pending generation flagged');
      return;
    }

    debugPrint('[UI] _triggerGenerate: Starting generation');
    controller.generateFromSelfie(selfieBytes: controller.selfieBytes!);
  }

  Future<void> _setCanvasAndAutosave(Uint8List bytes,
      {bool pushToStacks = true}) async {
    if (!mounted) return;
    setState(() {
      generatedImageBytes = bytes;
      if (pushToStacks) {
        _history.add(bytes);
        _redoStack.clear();
        // iOS Web memory guard: cap history length to avoid RAM spikes
        while (_history.length > 12) {
          _history.removeAt(0);
        }
      }
      // Reset favorite state when image changes
      _isFavorited = false;
      // Clear the latest URL when manually updating canvas
      _latestImageUrl = null;
    });
  }

  Future<void> _selectDollAndLoadStage(SofiDoll doll) async {
    debugPrint(
        '[SofiStudio] _selectDollAndLoadStage called for doll: ${doll.id}');
    debugPrint(
        '[SofiStudio] stagePath: ${doll.stagePath}, isStoragePath: ${doll.isStoragePath}');

    // Prevent rapid doll switching from overwhelming the system
    if (_selectionInProgress) {
      debugPrint('[SofiStudio] Selection already in progress, skipping');
      return;
    }
    _selectionInProgress = true;

    try {
      // Update the current doll selection in controller
      controller.selectDoll(doll);

      // Reset any custom premium style when switching base dolls
      _activeBaseStylePrompt = null;

      debugPrint('[SofiStudio] Loading stage image from Firebase...');

      Uint8List stageBytes;

      // Load from Firebase Storage
      try {
        debugPrint('[LoadDoll] 🎯 Attempting to load: ${doll.stagePath}');
        stageBytes = await _loadDollImage(doll.stagePath, doll.isStoragePath)
            .timeout(const Duration(seconds: 15));
        debugPrint(
            '[LoadDoll] ✅ Stage image loaded successfully, bytes: ${stageBytes.length}');
      } catch (loadError) {
        debugPrint('[LoadDoll] ❌ Failed to load ${doll.stagePath}: $loadError');
        rethrow;
      }

      if (stageBytes.isEmpty) {
        throw Exception('Empty image bytes received');
      }

      // Update canvas with the new doll image AND store as base
      if (mounted) {
        setState(() {
          // Always reset canvas to show the new doll
          generatedImageBytes = stageBytes;
          // Always store as the base doll image for generation
          _originalBaseDollBytes = stageBytes;
          _history.add(stageBytes);
          _redoStack.clear();
          _isFavorited = false;
        });
        // Clear stacked selections & prompt for a fresh start with new character
        selectedOptions.updateAll((key, value) => null);
        promptController.clear();
        debugPrint('[SofiStudio] Canvas reset with new doll: ${doll.id}');
        debugPrint(
            '[SofiStudio] ✅ Base doll stored (${stageBytes.length} bytes)');
      }

      // Save to storage in background
      unawaited(CustomDollStorage.saveLast(stageBytes,
              prompt: 'Base doll: ${doll.id}')
          .catchError((e) => debugPrint('[Storage] Save failed: $e')));
    } catch (e, stack) {
      debugPrint('❌ Failed to load stage for ${doll.id}: $e');
      debugPrint('Stack trace: $stack');

      // Show error feedback to user
      if (mounted) {
        _showSnack('Failed to load character. Please try again.');
      }
    } finally {
      _selectionInProgress = false;

      // Keep drawer OPEN after doll selection so user can continue
      // choosing clothing/options. Drawer closes on Generate or manual close.
    }
  }

  /// Helper to load doll image from either local assets or Firebase Storage
  Future<Uint8List> _loadDollImage(String path, bool isStorage) async {
    debugPrint(
        '[LoadDoll] Loading from ${isStorage ? "Firebase" : "assets"}: $path');

    if (isStorage) {
      try {
        // Use safe URL resolver with fallbacks for legacy paths
        final url = await StorageService.instance.getDownloadUrlSafe(path);
        if (url == null) {
          throw Exception('No download URL for $path');
        }
        debugPrint('[LoadDoll] Got download URL: ${url.substring(0, 50)}...');
        final response =
            await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
        if (response.statusCode != 200) {
          throw Exception('HTTP ${response.statusCode}');
        }
        debugPrint('[LoadDoll] Downloaded ${response.bodyBytes.length} bytes');
        return response.bodyBytes;
      } catch (e) {
        debugPrint('[LoadDoll] ❌ Firebase load failed: $e');
        debugPrint(
            '[LoadDoll] 💡 Hint: Verify this file exists in Firebase Storage: $path');
        rethrow;
      }
    } else {
      try {
        final byteData = await rootBundle.load(path);
        debugPrint(
            '[LoadDoll] Loaded ${byteData.lengthInBytes} bytes from assets');
        return byteData.buffer.asUint8List();
      } catch (e) {
        debugPrint('[LoadDoll] Asset load failed: $e');
        rethrow;
      }
    }
  }

  void _closeDrawer() => controller.closeDrawer();

  void _onCategorySelected(EditCategory category, int option) {
    // Debounce rapid selections to prevent overwhelming the system
    // Store the pending selection
    _pendingCategory = category;
    _pendingOption = option;

    // If already processing, just queue the selection
    if (_selectionInProgress) return;

    // Cancel any existing debounce timer
    _selectionDebounceTimer?.cancel();

    // Apply selection after a short debounce (80ms)
    _selectionDebounceTimer = Timer(const Duration(milliseconds: 80), () {
      if (!mounted || _pendingCategory == null || _pendingOption == null)
        return;
      _applyPendingSelection();
    });
  }

  void _applyPendingSelection() {
    if (!mounted || _pendingCategory == null || _pendingOption == null) return;

    _selectionInProgress = true;

    try {
      final category = _pendingCategory!;
      final option = _pendingOption!;

      // REMOTE DEBUG LOG: Category selection
      unawaited(RemoteDebugLogger.instance
          .logCategorySelection(category.name, option));

      // Enforce single-selection per category except Accessories (can stack)
      final newPrompt = _getPrompt(category, option);

      // If this category is NOT accessories, remove any previous fragment for this category
      if (category != EditCategory.accessories) {
        final previous = selectedOptions[category];
        if (previous != null) {
          try {
            final prevPrompt = _getPrompt(category, previous);
            final cleaned =
                _removeFragmentSafe(promptController.text, prevPrompt);
            if (cleaned != promptController.text) {
              promptController.text = cleaned;
            }
          } catch (e) {
            debugPrint(
                '[SofiStudio] Failed to remove previous fragment for ${category.name}: $e');
          }
        }
      }

      // Update current selection (single int per category)
      selectedOptions[category] = option;

      // Append or set new fragment
      final currentText = promptController.text.trim();
      if (currentText.isEmpty) {
        promptController.text = newPrompt;
      } else {
        // Avoid duplicate immediate re-append if already present at tail
        if (!currentText.endsWith(newPrompt)) {
          promptController.text = '$currentText, $newPrompt';
        }
      }

      // Clear pending after applying
      _pendingCategory = null;
      _pendingOption = null;

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('[SofiStudio] Selection error: $e');
    } finally {
      // Use microtask to reset flag after current frame completes
      Future.microtask(() {
        if (mounted) _selectionInProgress = false;
      });
    }
    // Drawer stays open for multiple selections ("Netflix style")
  }

  /// Safe helper that removes a fragment from a comma-separated prompt string.
  /// Handles begin/middle/end positions and cleans up extra commas/spaces.
  String _removeFragmentSafe(String text, String fragment) {
    var result = text;
    String esc(String input) => input.replaceAllMapped(
          RegExp(r'[\\.\^\$\|\?\*\+\(\)\{\}\[\]]'),
          (m) => '\\${m[0]}',
        );

    final frag = esc(fragment.trim());
    // Remove leading occurrence
    result = result.replaceFirst(RegExp('^$frag(\\s*,\\s*)?'), '');
    // Remove middle/end occurrences
    result = result.replaceAll(RegExp('(,\\s*)$frag'), '');
    // Normalize commas/spaces and strip stray leading/trailing commas
    result = result.replaceAll(RegExp(r'\s+,\s+'), ', ');
    result = result.replaceAll(RegExp(r'(^\s*,\s*|\s*,\s*$)'), '');
    result = result.trim();
    if (result.endsWith(',')) {
      result = result.substring(0, result.length - 1).trim();
    }
    return result;
  }

  /// Remove a specific fragment from the free-form prompt text, handling
  /// commas and whitespace gracefully regardless of position.
  // ignore: unused_element
  String _removePromptFragment(String text, String fragment) {
    String result = text;

    String esc(String input) => input.replaceAllMapped(
          RegExp(r'[\\.\^\$\|\?\*\+\(\)\{\}\[\]]'),
          (m) => '\\${m[0]}',
        );

    final frag = esc(fragment.trim());

    // 1) Remove leading: "fragment" or "fragment, "
    result = result.replaceFirst(RegExp('^$frag(\\s*,\\s*)?'), '');

    // 2) Remove middle/end occurrences: ", fragment"
    result = result.replaceAll(RegExp('(,\\s*)$frag'), '');

    // 3) Normalize stray commas and spaces
    result = result.replaceAll(RegExp('\\s+,\\s+'), ', ');
    /*
    result = result.replaceAll(RegExp('(^\\s*,\\s*|\\s*,\\s*[0$])'), '');
    */
    // Safe replacement for trailing/leading commas
    result = result.replaceAll(RegExp(r'(^\s*,\s*|\s*,\s*$)'), '');
    // Fallback trim
    result = result.trim();
    // Remove trailing comma if any after trims
    if (result.endsWith(',')) {
      result = result.substring(0, result.length - 1).trim();
    }
    return result;
  }

  String _getPrompt(EditCategory category, int option) {
    final idx = option - 1;
    final isMale = UserPreferencesService.instance.isMaleMode;

    if (isMale) {
      switch (category) {
        case EditCategory.hair:
          return idx < SofiMalePromptData.hair.length ? SofiMalePromptData.hair[idx] : 'natural haircut';
        case EditCategory.top:
          return idx < SofiMalePromptData.tops.length ? SofiMalePromptData.tops[idx] : 'stylish top';
        case EditCategory.bottom:
          return idx < SofiMalePromptData.bottoms.length ? SofiMalePromptData.bottoms[idx] : 'stylish bottom';
        case EditCategory.shoes:
          return idx < SofiMalePromptData.shoes.length ? SofiMalePromptData.shoes[idx] : 'stylish shoes';
        case EditCategory.fullOutfit:
          return idx < SofiMalePromptData.fullOutfits.length ? SofiMalePromptData.fullOutfits[idx]['prompt'] : 'full outfit';
        case EditCategory.caption:
          return '';
        default:
          break; // Fall back to female data for backgrounds/accessories if missing
      }
    }

    switch (category) {
      case EditCategory.hair:
        return SofiPromptData.hair[idx];
      case EditCategory.top:
        return SofiPromptData.tops[idx];
      case EditCategory.bottom:
        return SofiPromptData.bottoms[idx];
      case EditCategory.shoes:
        return SofiPromptData.shoes[idx];
      case EditCategory.accessories:
        return SofiPromptData.accessories[idx];
      case EditCategory.hats:
        return SofiPromptData.hats[idx];
      case EditCategory.jewelry:
        return SofiPromptData.jewelry[idx];
      case EditCategory.glasses:
        return SofiPromptData.glasses[idx];
      case EditCategory.poses:
        return SofiPromptData.poses[idx];
      case EditCategory.background:
        return SofiPromptData.backgrounds[idx];
      case EditCategory.fullOutfit:
        return SofiPromptData.fullOutfits[idx]['prompt'];
      case EditCategory.caption:
        return '';
    }
  }

  String _buildFinalPrompt() {
    final bool isDollMode = UserPreferencesService.instance.isDollMode;

    // 1. Start with the mode-specific base intent
    String base;
    if (_activeBaseStylePrompt != null) {
      base = isDollMode ? dollBasePrompt : _activeBaseStylePrompt!;
    } else {
      final modeId = isDollMode ? 'doll' : controller.selectedMode.id;
      base = switch (modeId) {
        'human' => humanBasePrompt,
        'cinematic' => cinematicBasePrompt,
        'fantasy' => fantasyBasePrompt,
        'artistic' => artisticBasePrompt,
        'anime' => animeBasePrompt,
        'doll' => dollBasePrompt,
        _ => dollBasePrompt,
      };
    }

    final buffer = StringBuffer(base.trim());
    if (!base.endsWith(' ')) buffer.write(' ');

    // 2. Add Mood layer
    if (_activeMood.id != 'neutral') {
      buffer.write('Mood style: ${_activeMood.promptFragment}. ');
    }

    // 3. Add Manual edits from the text box
    final manual = promptController.text.trim();
    if (manual.isNotEmpty) {
      buffer.write('Outfit/Scene details: $manual ');
    }

    // 4. Final polish
    return buffer.toString().trim();
  }

  Future<void> _onGeneratePressed() async {
    debugPrint('\u25b6\ufe0f [Generation] Button pressed');

    // 🔒 FIX #4: Block double-generation at controller level
    if (_isGenerating ||
        controller.isGenerating ||
        controller.currentDoll == null) {
      debugPrint(
          '\u26a0\ufe0f [Generation] Blocked: isGenerating=$_isGenerating, controller.isGenerating=${controller.isGenerating}, currentDoll=${controller.currentDoll}');
      return;
    }

    // 🔒 CRITICAL: Validate selfie before proceeding (for Quick-Mood flow)
    final effectiveSelfie = controller.selfieBytes ?? widget.selfieBytes;
    if (_fromQuickMoodSelfie &&
        (effectiveSelfie == null || effectiveSelfie.isEmpty)) {
      debugPrint('⚠️ [Generation] Blocked: No selfie image in Quick-Mood flow');
      _showSnack('Please upload a selfie first');
      return;
    }

    // NOTE: Empty prompt is OK for Quick-Mood flow (mode/mood provide base prompt)
    // Only block if we're NOT in Quick-Mood flow AND prompt is empty
    final promptText = promptController.text.trim();
    if (!_fromQuickMoodSelfie && promptText.isEmpty) {
      debugPrint('⚠️ [Generation] Blocked: Empty prompt (non Quick-Mood flow)');
      _showSnack('Please add a prompt to generate');
      return;
    }

    // If we've already detected an out-of-credits state, nudge to paywall instead.
    if (_outOfCredits) {
      debugPrint('⛔ [Generation] Blocked: out of credits');
      if (!mounted) return;
      final didSubscribe = await PaywallSheet.show(
        context,
        message:
            "You're out of generation credits. Start your trial or add credits to continue.",
      );
      if (didSubscribe == true) {
        if (!mounted) return;
        setState(() => _outOfCredits = false);
        _showSnack('Thanks! Try again.');
      } else {
        _showSnack('Out of credits. Upgrade to continue.');
      }
      return;
    }

    // Cooldown check to prevent rapid-fire generation requests
    if (_isOnCooldown) {
      debugPrint('\u26a0\ufe0f [Generation] Blocked: On cooldown');
      _showSnack('Please wait a moment before generating again.');
      return;
    }

    // Avoid overlapping heavy work while TTS is speaking/holding
    final vc = VoiceCoachService.instance;
    if (vc.isSpeaking || vc.isExclusiveHoldActive) {
      debugPrint('\u26a0\ufe0f [Generation] Blocked: VoiceCoach busy');
      _showSnack('One sec — finishing audio…');
      return;
    }

    // Capture a human-readable summary up-front (no longer narrated to reduce load)
    final summary = promptController.text.trim();
    final startTime = DateTime.now();

    debugPrint('\ud83d\udea8 [Generation] STARTING - prompt="$summary"');

    // REMOTE DEBUG LOG: Generation started
    try {
      await RemoteDebugLogger.instance
          .logGeneration('STARTED', duration: 0)
          .timeout(const Duration(seconds: 1));
    } catch (e) {
      debugPrint('\u26a0\ufe0f [RemoteLog] Failed to log start: $e');
    }

    // Let VoiceCoach know we're about to run a heavy task; suppress mid-stream chatter
    try {
      VoiceCoachService.instance.setGenerating(true);
    } catch (e) {
      debugPrint('\u26a0\ufe0f [VoiceCoach] setGenerating error: $e');
    }

    // SFX: start generation
    try {
      unawaited(AudioService.instance.playGenerateStart());
      unawaited(AudioService.instance.startGenerationLoop());
    } catch (e) {
      debugPrint('⚠️ [Audio] playGenerateStart error: $e');
    }

    // Platform-specific memory guard before heavy work
    _prepareForGenerationMemory();

    if (!mounted) return;
    setState(() {
      _isGenerating = true;
      _showUI = false;
    });

    try {
      // ================================
      // STEP 1: GET THE INIT IMAGE
      // ================================
      // If a doll/character is selected from the drawer, use it as the source.
      // Otherwise, use the selfie as the identity anchor.
      final Uint8List? selfie = controller.selfieBytes ?? widget.selfieBytes;

      Uint8List initImageBytes;
      if (_originalBaseDollBytes != null && _originalBaseDollBytes!.isNotEmpty) {
        // A character is active on the canvas: edit the character, not the selfie
        initImageBytes = _originalBaseDollBytes!;
        debugPrint(
            '[Identity] 🎭 CHARACTER MODE: Using selected character as source');
      } else if (selfie != null && selfie.isNotEmpty) {
        // SELFIE MODE: Use selfie as identity anchor
        initImageBytes = selfie;
        debugPrint(
            '[Identity] 📸 SELFIE MODE: Using selfie as source');
      } else if (controller.currentDoll != null) {
        // No selfie, no doll bytes loaded yet
        initImageBytes = await _loadDollImage(
          controller.currentDoll!.stagePath,
          controller.currentDoll!.isStoragePath,
        );
        debugPrint('[Identity] Loaded character from path');
      } else {
        throw Exception("No valid source image found to generate from.");
      }

      // NEW: Ensure payload size is reasonable for stability
      initImageBytes = await _ensureReasonableSize(initImageBytes);

      // ================================
      // STEP 2: SYNC & DELEGATE TO TWO-STEP CONTROLLER
      // ================================
      // We must sync the latest manual prompt edits from the UI to the controller
      // so the two-step pipeline uses the fresh intention.
      final freshIntent = _buildFinalPrompt();
      controller.rebuildPrompt(
        userPrompt: freshIntent,
        mode: controller.selectedMode.id,
        mood: _activeMood.id,
      );

      debugPrint('[GEN] Delegating to Two-Step Pipeline');
      debugPrint(
          '[GEN] Controller prompt length: ${controller.currentPrompt.length}');
      debugPrint('[GEN] Init image bytes: ${initImageBytes.length}');

      Uint8List result;
      try {
        result =
            await controller.generateFromSelfie(selfieBytes: initImageBytes);
      } catch (e, st) {
        debugPrint('❌ [Generation] CRASH: Two-Step Pipeline failed: $e');
        await RemoteDebugLogger.instance
            .logError('Two-Step Pipeline failed', e, st)
            .timeout(const Duration(seconds: 1))
            .catchError((_) {});
        rethrow;
      }

      // Step 4: Process and save result
      debugPrint('🖼️ [Generation] Processing result...');
      try {
        await _setGeneratedImage(result);
        debugPrint('✅ [Generation] Result processed and saved');
      } catch (e, st) {
        debugPrint('🛑 [Generation] CRASH: Failed to process result: $e');
        await RemoteDebugLogger.instance
            .logError('Result processing failed', e, st)
            .timeout(const Duration(seconds: 1))
            .catchError((_) {});
        rethrow;
      }

      final duration = DateTime.now().difference(startTime).inMilliseconds;
      debugPrint('\ud83c\udf89 [Generation] SUCCESS in ${duration}ms');

      // Trigger large confetti drop on success
      if (mounted) _confettiController.play();

      try {
        await RemoteDebugLogger.instance
            .logGeneration('SUCCESS', duration: duration)
            .timeout(const Duration(seconds: 1));
      } catch (e) {
        debugPrint('\u26a0\ufe0f [RemoteLog] Failed to log success: $e');
      }

      // Save session memory
      try {
        await SofiSessionMemory.save(
          mode: _selectedMode,
          guidance: _guidanceScale,
          ratio: _selectedRatio,
        );
      } catch (e) {
        debugPrint('⚠️ [SessionMemory] Failed to save: $e');
      }

      // SFX: success
      try {
        unawaited(AudioService.instance.playSuccess());
        unawaited(AudioService.instance.stopGenerationLoop());
      } catch (e) {
        debugPrint('⚠️ [Audio] playSuccess error: $e');
      }

      // Voice Coach: short success response only (no prompt narration)
      unawaited(
          Future<void>.delayed(const Duration(milliseconds: 200), () async {
        try {
          await VoiceCoachService.instance.onGenerationSuccess();
        } catch (e) {
          debugPrint('[VoiceCoach] onGenerationSuccess error: $e');
        }
      }));

      // Reset both text and selections so the next generation is clean
      selectedOptions.updateAll((key, value) => null);
      promptController.clear();

      // Track generations and show premium reminder every 2 generations
      _generationCount++;
      if (_generationCount % 2 == 0) {
        try {
          _showPremiumReminderPopup();
        } catch (e) {
          debugPrint('\u26a0\ufe0f [PremiumReminder] Error: $e');
        }
      }

      // Auto-close drawer to reveal the new image on canvas
      _closeDrawer();

      // Start cooldown timer to prevent rapid-fire generation
      _startGenerationCooldown();
    } catch (e, st) {
      // ERROR PATH
      final duration = DateTime.now().difference(startTime).inMilliseconds;
      debugPrint('\ud83d\uded1 [Generation] FAILED after ${duration}ms: $e');
      debugPrint('Stack trace: $st');

      try {
        await RemoteDebugLogger.instance
            .logGeneration('FAILED', duration: duration, error: e.toString())
            .timeout(const Duration(seconds: 1));
        await RemoteDebugLogger.instance
            .logError('Generation failed', e, st)
            .timeout(const Duration(seconds: 1));
      } catch (logErr) {
        debugPrint('\u26a0\ufe0f [RemoteLog] Failed to log error: $logErr');
      }

      // SFX: error
      try {
        unawaited(AudioService.instance.playError());
        unawaited(AudioService.instance.stopGenerationLoop());
      } catch (audioErr) {
        debugPrint('⚠️ [Audio] playError failed: $audioErr');
      }

      // Voice Coach: explain and nudge
      unawaited(VoiceCoachService.instance.onGenerationError().catchError((ve) {
        debugPrint('[VoiceCoach] onGenerationError error: $ve');
      }));

      // Special handling: Out of credits
      final msg = e.toString().toLowerCase();
      if (msg.contains('out of credits')) {
        debugPrint('💳 [Generation] Detected out-of-credits condition');
        if (mounted) {
          setState(() => _outOfCredits = true);
        }
        // Offer upgrade/paywall immediately
        if (mounted) {
          final didSubscribe = await PaywallSheet.show(
            context,
            message:
                "You're out of generation credits. Start your trial or add credits to continue.",
          );
          if (didSubscribe == true && mounted) {
            setState(() => _outOfCredits = false);
            _showSnack('Thanks! Try again.');
          } else if (mounted) {
            _showSnack('Out of credits. Open Premium to continue.');
          }
        }
      } else {
        // Generic error fallback
        if (mounted) {
          final errorStr = e.toString().toLowerCase();
          String userMsg = 'Generation failed. Please try again.';
          if (errorStr.contains('safety')) {
            userMsg = 'Safety filter triggered. Please try a different prompt.';
          } else if (errorStr.contains('timeout')) {
            userMsg = 'Request timed out. Please try again.';
          } else {
            // EXPOSE ACTUAL ERROR for debugging
            userMsg = 'Error: ${e.toString().replaceAll('Exception: ', '')}';
          }
          _showSnack(userMsg);
        }
      }
    } finally {
      // ALWAYS reset state
      debugPrint('\ud83c\udfaf [Generation] Cleanup: resetting state');
      if (mounted) {
        setState(() => _isGenerating = false);
      }
      try {
        VoiceCoachService.instance.setGenerating(false);
      } catch (e) {
        debugPrint('\u26a0\ufe0f [VoiceCoach] setGenerating(false) error: $e');
      }

      // Post-generation memory cleanup (A approach)
      _cleanupAfterGeneration();
    }
  }

  // Adapter to match SofiBottomDrawer(onGenerate: _onGenerate)
  void _onGenerate() {
    if (!_isGenerating) {
      _onGeneratePressed();
    }
  }

  /// Start a cooldown period after generation to prevent rapid-fire requests.
  /// This helps iPhone Safari stay stable by allowing memory to settle.
  void _startGenerationCooldown() {
    _cooldownTimer?.cancel();
    if (!mounted) return;
    setState(() => _isOnCooldown = true);

    _cooldownTimer = Timer(_cooldownDuration, () {
      if (mounted) {
        setState(() => _isOnCooldown = false);
        debugPrint('✅ [Generation] Cooldown ended, ready for next generation');
      }
    });
    debugPrint(
        '⏱️ [Generation] Cooldown started (${_cooldownDuration.inSeconds}s)');
  }

  /// Reduce memory pressure just before starting a heavy generation.
  /// Especially important for iOS Web (all iPhone browsers).
  /// Uses PerformanceService for centralized A+B memory management.
  void _prepareForGenerationMemory() {
    try {
      final cache = PaintingBinding.instance.imageCache;
      cache.clear();
      cache.clearLiveImages();

      if (kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        cache.maximumSizeBytes = 20 << 20; // 20 MB
      }

      final bytes = generatedImageBytes;
      if (bytes != null && bytes.isNotEmpty) {
        final provider = MemoryImage(bytes);
        provider.evict();
      }

      // Use PerformanceService for additional cleanup (A approach)
      unawaited(PerformanceService.instance.prepareForGeneration());
    } catch (e) {
      debugPrint('⚠️ Memory prep failed: $e');
    }
  }

  /// Called after generation completes to free memory (A approach).
  void _cleanupAfterGeneration() {
    try {
      unawaited(PerformanceService.instance.cleanupAfterGeneration());
    } catch (e) {
      debugPrint('⚠️ Post-generation cleanup failed: $e');
    }
  }

  Future<void> _setGeneratedImage(Uint8List bytes) async {
    debugPrint(
        '\ud83d\uddbc\ufe0f [SetImage] Processing ${bytes.length} bytes');

    try {
      debugPrint('\u2702\ufe0f [SetImage] Starting auto-crop...');
      // ULTRA-CONSERVATIVE CROP SETTINGS to protect face region
      // Only crop truly black borders, never anything that could be facial shadows
      final trimmed = await _autoCropDarkBorders(
        bytes,
        darknessThreshold:
            15, // VERY LOW - only pure black pixels (protects facial shadows)
        maxBorderFractionPerSide:
            0.10, // MAX 10% per side - protects face from being cropped
      ).timeout(const Duration(seconds: 15));

      debugPrint(
          '\u2705 [SetImage] Crop complete (${trimmed.length} bytes), saving...');
      await _setCanvasAndAutosave(trimmed);

      debugPrint('\ud83d\udcbe [SetImage] Persisting to storage...');
      unawaited(CustomDollStorage.saveLast(trimmed, prompt: _buildFinalPrompt())
          .catchError(
              (e) => debugPrint('\u26a0\ufe0f [Storage] Save failed: $e')));

      debugPrint('\u2705 [SetImage] Complete');
    } catch (e) {
      debugPrint(
          '\u26a0\ufe0f [SetImage] Trim/crop failed, using original: $e');
      try {
        await RemoteDebugLogger.instance
            .logWarning('Image crop failed', {'error': e.toString()})
            .timeout(const Duration(seconds: 1))
            .catchError((_) {});
      } catch (_) {}

      await _setCanvasAndAutosave(bytes);
      unawaited(CustomDollStorage.saveLast(bytes, prompt: _buildFinalPrompt())
          .catchError(
              (e) => debugPrint('\u26a0\ufe0f [Storage] Save failed: $e')));
    }
  }

  /// Crops uniformly dark margins (e.g., black letterboxing) from an image.
  /// CONSERVATIVE SETTINGS to preserve facial features and avoid quality loss.
  Future<Uint8List> _autoCropDarkBorders(
    Uint8List input, {
    int darknessThreshold =
        25, // Conservative: only pure black/very dark pixels
    double maxBorderFractionPerSide =
        0.20, // Conservative: max 20% crop per side
  }) async {
    try {
      debugPrint('\ud83d\udd0d [Crop] Decoding image codec...');
      final ui.Codec codec = await ui
          .instantiateImageCodec(input)
          .timeout(const Duration(seconds: 10));

      debugPrint('\ud83d\udd0d [Crop] Getting frame...');
      final ui.FrameInfo frame =
          await codec.getNextFrame().timeout(const Duration(seconds: 5));

      final ui.Image image = frame.image;
      final int w = image.width;
      final int h = image.height;
      debugPrint('\ud83d\udd0d [Crop] Image dimensions: ${w}x$h');

      // Sanity check for memory safety
      if (w * h > 16777216) {
        // 4096x4096 limit
        debugPrint(
            '\u26a0\ufe0f [Crop] Image too large (${w}x$h), skipping crop');
        await RemoteDebugLogger.instance
            .logWarning('Image too large for crop', {
              'width': w,
              'height': h,
              'pixels': w * h,
            })
            .timeout(const Duration(seconds: 1))
            .catchError((_) {});
        return input;
      }

      debugPrint('\ud83d\udd0d [Crop] Converting to RGBA bytes...');
      final ByteData? bd = await image
          .toByteData(format: ui.ImageByteFormat.rawRgba)
          .timeout(const Duration(seconds: 10));

      if (bd == null) {
        debugPrint('\u26a0\ufe0f [Crop] toByteData returned null');
        return input;
      }

      debugPrint(
          '\ud83d\udd0d [Crop] Got ${bd.lengthInBytes} bytes of RGBA data');

      final Uint8List rgba = bd.buffer.asUint8List();
      bool rowIsDark(int y) {
        final int rowStart = y * w * 4;
        int darkCount = 0;
        for (int x = 0; x < w; x++) {
          final int i = rowStart + x * 4;
          final int r = rgba[i];
          final int g = rgba[i + 1];
          final int b = rgba[i + 2];
          final int a = rgba[i + 3];
          // Only consider opaque-ish pixels as border (ignore transparency)
          if (a > 8) {
            final int maxc = r > g ? (r > b ? r : b) : (g > b ? g : b);
            if (maxc <= darknessThreshold) darkCount++;
          } else {
            // Transparent counts as dark to allow trimming transparent padding too
            darkCount++;
          }
        }
        // STRICTER: 95% of pixels must be dark (restored from 90%)
        return darkCount >= (w * 0.95).floor();
      }

      bool colIsDark(int x, int top, int bottom) {
        int darkCount = 0;
        for (int y = top; y <= bottom; y++) {
          final int i = (y * w + x) * 4;
          final int r = rgba[i];
          final int g = rgba[i + 1];
          final int b = rgba[i + 2];
          final int a = rgba[i + 3];
          if (a > 8) {
            final int maxc = r > g ? (r > b ? r : b) : (g > b ? g : b);
            if (maxc <= darknessThreshold) darkCount++;
          } else {
            darkCount++;
          }
        }
        // STRICTER: 95% of pixels must be dark
        return darkCount >= ((bottom - top + 1) * 0.95).floor();
      }

      int top = 0;
      int bottom = h - 1;
      int left = 0;
      int right = w - 1;

      final int maxCropY = (h * maxBorderFractionPerSide).floor();
      final int maxCropX = (w * maxBorderFractionPerSide).floor();

      // Scan top
      while (top < bottom && (top - 0) < maxCropY && rowIsDark(top)) {
        top++;
      }
      // Scan bottom
      while (bottom > top && (h - 1 - bottom) < maxCropY && rowIsDark(bottom)) {
        bottom--;
      }
      // Scan left
      while (left < right &&
          (left - 0) < maxCropX &&
          colIsDark(left, top, bottom)) {
        left++;
      }
      // Scan right
      while (right > left &&
          (w - 1 - right) < maxCropX &&
          colIsDark(right, top, bottom)) {
        right--;
      }

      final int newW = (right - left + 1).clamp(1, w);
      final int newH = (bottom - top + 1).clamp(1, h);

      // SAFETY: Only crop if we're removing more than 5% total area
      // This prevents unnecessary re-encoding for minimal crops
      final double cropPercentage = 1.0 - ((newW * newH) / (w * h));
      if (cropPercentage < 0.05) {
        debugPrint(
            '\ud83d\udd0d [Crop] Minimal crop detected (${(cropPercentage * 100).toStringAsFixed(1)}%), keeping original to preserve quality');
        return input;
      }

      // If nothing cropped, return original
      if (newW == w && newH == h) return input;

      debugPrint(
          '\ud83d\udd0d [Crop] Cropping from ${w}x$h to ${newW}x${newH} (${(cropPercentage * 100).toStringAsFixed(1)}% reduction)');

      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final ui.Canvas canvas = ui.Canvas(recorder);
      final ui.Rect src = ui.Rect.fromLTWH(
          left.toDouble(), top.toDouble(), newW.toDouble(), newH.toDouble());
      final ui.Rect dst =
          ui.Rect.fromLTWH(0, 0, newW.toDouble(), newH.toDouble());

      // QUALITY FIX: Use high-quality filtering to preserve details
      final ui.Paint paint = ui.Paint()
        ..filterQuality = FilterQuality.high
        ..isAntiAlias = true;

      canvas.drawImageRect(image, src, dst, paint);
      final ui.Picture picture = recorder.endRecording();
      final ui.Image cropped = await picture.toImage(newW, newH);
      final ByteData? png =
          await cropped.toByteData(format: ui.ImageByteFormat.png);
      if (png == null) return input;
      return png.buffer.asUint8List();
    } catch (e) {
      debugPrint('⚠️ _autoCropDarkBorders failed: $e');
      return input;
    }
  }

  /// Ensures the image is not excessively large before sending to ModelsLab.
  /// Downscales if either dimension exceeds [maxDimension].
  Future<Uint8List> _ensureReasonableSize(Uint8List bytes, {int maxDimension = 1024}) async {
    try {
      final ui.ImmutableBuffer buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      final ui.ImageDescriptor descriptor = await ui.ImageDescriptor.encoded(buffer);
      
      final int w = descriptor.width;
      final int h = descriptor.height;
      
      // If already small enough, skip processing
      if (w <= maxDimension && h <= maxDimension) {
        debugPrint('[Size] Image is already reasonable size: ${w}x$h');
        return bytes;
      }
      
      // Calculate scale to fit within maxDimension
      double scale = 1.0;
      if (w > h) {
        scale = maxDimension / w;
      } else {
        scale = maxDimension / h;
      }
      
      final int targetW = (w * scale).round();
      final int targetH = (h * scale).round();
      
      debugPrint('[Size] Downscaling from ${w}x$h to ${targetW}x$targetH (scale: ${scale.toStringAsFixed(2)})');
      
      final ui.Codec codec = await descriptor.instantiateCodec(
        targetWidth: targetW,
        targetHeight: targetH,
      );
      final ui.FrameInfo frame = await codec.getNextFrame();
      final ui.Image resized = frame.image;
      
      final ByteData? png = await resized.toByteData(format: ui.ImageByteFormat.png);
      if (png == null) return bytes;
      
      final result = png.buffer.asUint8List();
      debugPrint('[Size] Downscale complete: ${bytes.length} bytes -> ${result.length} bytes');
      return result;
    } catch (e) {
      debugPrint('⚠️ _ensureReasonableSize failed: $e');
      return bytes;
    }
  }

  void _undo() {
    if (_history.length <= 1) return;
    final last = _history.removeLast();
    _redoStack.add(last);
    final previousBytes = _history.last;
    _setCanvasAndAutosave(previousBytes, pushToStacks: false);
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    final bytes = _redoStack.removeLast();
    _history.add(bytes);
    _setCanvasAndAutosave(bytes, pushToStacks: false);
  }

  Future<Uint8List?> _captureCompositeImage() async {
    try {
      final boundary = _stageKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      
      // QUALITY: Use high pixel ratio for sharp text on save
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('❌ Composite capture failed: $e');
      return null;
    }
  }

  void _openHistory() {
    if (_history.isEmpty) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SofiHistorySheet(
        history: _history,
        onSelect: (bytes) async =>
            _setCanvasAndAutosave(bytes, pushToStacks: false),
        onDelete: (bytes) async {
          await CustomDollStorage.deleteFromHistory(bytes);
          if (!mounted) return;
          setState(() {
            _history.remove(bytes);
            if (generatedImageBytes == bytes) {
              generatedImageBytes = _history.isNotEmpty ? _history.last : null;
            }
          });
        },
      ),
    );
  }

  Future<void> _shareCurrent() async {
    try {
      Uint8List? bytes = await _captureCompositeImage() ?? generatedImageBytes;
      String name = 'sofi.png';

      if (bytes == null) {
        final doll = controller.currentDoll;
        if (doll != null) {
          bytes = await _loadDollImage(doll.stagePath, doll.isStoragePath);
          name = 'sofi_stage.png';
        }
      }

      if (bytes != null) {
        // Use share_plus shareXFiles - shows native share sheet on mobile and web (if supported)
        try {
          final result = await Share.shareXFiles(
            [XFile.fromData(bytes, name: name, mimeType: 'image/png')],
            text: 'Made with Sofi Saint',
            subject: 'Sofi Saint Creation',
          );
          debugPrint('✅ Share result: ${result.status}');
          // Check if sharing actually worked
          if (result.status == ShareResultStatus.success ||
              result.status == ShareResultStatus.dismissed) {
            return;
          }
          // Share unavailable - fallback to download on web
          if (kIsWeb) {
            downloadImageBytes(bytes, name);
            _showSnack('Image downloaded - share from your device');
            return;
          }
        } catch (e) {
          debugPrint('❌ shareXFiles failed: $e');
          // Try text-only share as fallback
          try {
            await Share.share(
              'Check out my creation made with Sofi Saint!',
              subject: 'Sofi Saint Creation',
            );
            return;
          } catch (e2) {
            debugPrint('❌ Text share also failed: $e2');
            if (kIsWeb) {
              downloadImageBytes(bytes, name);
              _showSnack('Image downloaded - share from your device');
              return;
            }
          }
        }
      } else {
        // No image yet: share text only
        await Share.share(
          'Check out Sofi Saint - AI Fashion Studio!',
          subject: 'Sofi Saint',
        );
      }
    } catch (e) {
      debugPrint('❌ Share failed: $e');
      _showSnack('Could not share. Please try again.');
    }
  }

  Future<void> _openPremium() async {
    try {
      // Check premium status and show paywall if needed
      final premiumService = PremiumService();
      await premiumService.initialize();
      if (!context.mounted) return;

      if (!premiumService.isPremium) {
        // Require subscription before entering the Premium Studio
        final didSubscribe = await PaywallSheet.show(
          context,
          message:
              'Premium required for this feature. Start your 3-Day Free Trial!',
        );
        // Re-check state after sheet closes
        await premiumService.initialize();
        if (!context.mounted) return;
        if (didSubscribe != true || !premiumService.isPremium) {
          _showSnack('Premium is required to continue.');
          return;
        }
      }

      final picker = ImagePicker();

      // Show option dialog
      if (!context.mounted) return;
      final selection = await showModalBottomSheet<int>(
        context: context,
        backgroundColor: Colors.transparent,
        // Allow the sheet to grow with content and avoid tight half-height constraints.
        isScrollControlled: true,
        builder: (ctx) => Theme(
          data: ThemeData.light(),
          child: SafeArea(
            top: false,
            child: FractionallySizedBox(
              heightFactor: 0.9, // allow up to 90% screen height
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: _radiusTop24,
                ),
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 20,
                  bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const Center(
                      child: Text(
                        'Select Identity Source',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Make inner content scroll when space is tight
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSheetOption(
                              icon: Icons.camera_alt_outlined,
                              label: 'Take Live Picture',
                              onTap: () => Navigator.pop(ctx, 0),
                            ),
                            const SizedBox(height: 8),
                            _buildSheetOption(
                              icon: Icons.photo_library_outlined,
                              label: 'Choose from Gallery',
                              onTap: () => Navigator.pop(ctx, 1),
                            ),
                            const SizedBox(height: 8),
                            _buildSheetOption(
                              icon: Icons.brush_outlined,
                              label: 'Use Current Canvas',
                              onTap: () => Navigator.pop(ctx, 2),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Divider(color: Colors.black12),
                            ),
                            _buildSheetOption(
                              icon: Icons.arrow_forward_rounded,
                              label: 'Go Directly to Premium',
                              subtitle: 'Browse styles, upload later',
                              isPrimary: true,
                              onTap: () => Navigator.pop(ctx, 3),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      if (selection == null) return;

      Uint8List? imageBytes;
      String? headshotBase64;

      if (selection == 3) {
        // Go Directly - no image yet, allow upload from Premium page
        headshotBase64 = null;
      } else if (selection == 0) {
        final XFile? photo = await picker.pickImage(source: ImageSource.camera);
        if (photo != null) imageBytes = await photo.readAsBytes();
      } else if (selection == 1) {
        final XFile? photo =
            await picker.pickImage(source: ImageSource.gallery);
        if (photo != null) imageBytes = await photo.readAsBytes();
      } else {
        // Use current canvas logic
        imageBytes = generatedImageBytes;
        if (imageBytes == null) {
          final doll = controller.currentDoll;
          if (doll != null) {
            imageBytes =
                await _loadDollImage(doll.stagePath, doll.isStoragePath);
          }
        }
      }

      if (selection != 3 && imageBytes == null) {
        if (selection == 2 && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No canvas image available.')));
        }
        return;
      }

      if (imageBytes != null) {
        headshotBase64 = base64Encode(imageBytes);
      }

      final premiumPaths =
          controller.premiumDolls.map((d) => d.stagePath).toList();

      if (!mounted) return;
      final result = await Navigator.push<dynamic>(
        context,
        MaterialPageRoute(
          builder: (_) => PremiumStudioPage(
            userHeadshotBase64: headshotBase64,
            generationService: TwoStepGenerationService(),
            isPremiumUser: false,
            premiumAssetPaths: premiumPaths,
          ),
        ),
      );

      if (result == null) return;

      // Handle both legacy String return (just in case) and new Map return
      String? returnedBase64;
      String? returnedPrompt;

      if (result is Map) {
        returnedBase64 = result['image'] as String?;
        returnedPrompt = result['prompt'] as String?;
      } else if (result is String) {
        returnedBase64 = result;
      }

      if (returnedBase64 == null) return;

      await _setCanvasAndAutosave(base64Decode(returnedBase64));

      // If we got a prompt back, store it as the active base style
      if (returnedPrompt != null && returnedPrompt.isNotEmpty) {
        if (!mounted) return;
        setState(() => _activeBaseStylePrompt = returnedPrompt);
        debugPrint('Activated premium style prompt override');
      }
    } catch (e) {
      debugPrint('❌ Failed to open Premium Studio: $e');
    }
  }

  Future<void> _onMicPressed() async {
    debugPrint('\ud83c\udfa4 [Mic] Button pressed');

    // Block mic while TTS is active/holding to prevent overlap
    final vc = VoiceCoachService.instance;
    if (vc.isSpeaking || vc.isExclusiveHoldActive) {
      debugPrint('\u26a0\ufe0f [Mic] Blocked: audio playing');
      _showSnack('Hold on — audio playing…');
      return;
    }

    // Detect iOS Safari web specifically
    final isIOSWeb = kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

    debugPrint(
        '\ud83c\udfa4 [Mic] State: kIsWeb=$kIsWeb, platform=$defaultTargetPlatform, listening=$_listening');

    // REMOTE DEBUG LOG: Mic pressed
    try {
      await RemoteDebugLogger.instance
          .logMic('PRESSED',
              'kIsWeb: $kIsWeb, platform: $defaultTargetPlatform, isIOSWeb: $isIOSWeb, listening: $_listening')
          .timeout(const Duration(seconds: 1));
    } catch (e) {
      debugPrint('\u26a0\ufe0f [RemoteLog] Failed to log mic press: $e');
    }

    try {
      if (!_listening) {
        // On web (including iOS Safari), we need to ensure proper initialization
        // The speech_to_text package uses the Web Speech API which iOS Safari supports
        debugPrint(
            '[Speech] Attempting to initialize... kIsWeb=$kIsWeb, platform=$defaultTargetPlatform');

        bool available = false;
        String? initError;

        try {
          debugPrint('\ud83c\udfa4 [Mic] Calling _speech.initialize()...');
          available = await _speech
              .initialize(
                onError: (error) {
                  debugPrint(
                      '\ud83d\uded1 [Speech] onError callback: ${error.errorMsg} (permanent: ${error.permanent})');
                  try {
                    RemoteDebugLogger.instance
                        .logMic('LISTEN_ERROR',
                            '${error.errorMsg} (permanent: ${error.permanent})')
                        .timeout(const Duration(seconds: 1))
                        .catchError((_) {});
                  } catch (_) {}
                  if (mounted) setState(() => _listening = false);
                  if (error.permanent) {
                    _showSnack('Mic error: ${error.errorMsg}');
                  }
                },
                onStatus: (status) {
                  debugPrint('\ud83d\udd0a [Speech] onStatus: $status');
                  if (status == 'notListening' && mounted) {
                    setState(() => _listening = false);
                  }
                },
                debugLogging: true, // Enable debug logging for troubleshooting
              )
              .timeout(const Duration(seconds: 10));
          debugPrint('\u2705 [Mic] initialize() complete');
        } catch (initEx) {
          initError = initEx.toString();
          debugPrint('\ud83d\uded1 [Speech] initialize() threw: $initEx');
        }

        debugPrint(
            '\ud83d\udd0d [Speech] initialize result: available=$available, initError=$initError');
        try {
          await RemoteDebugLogger.instance
              .logMic('INIT_RESULT', 'available: $available, error: $initError')
              .timeout(const Duration(seconds: 1));
        } catch (e) {
          debugPrint('\u26a0\ufe0f [RemoteLog] Failed to log init result: $e');
        }

        if (!available) {
          debugPrint('\u274c [Mic] Not available');
          // Provide more specific feedback for iOS web
          if (isIOSWeb) {
            _showSnack(
                'Voice dictation requires Safari permissions. Try the native app for best results.');
          } else {
            _showSnack('Mic not available. Check browser permissions.');
          }
          return;
        }

        if (!mounted) return;
        setState(() => _listening = true);
        debugPrint('\ud83c\udfa4 [Speech] Starting to listen...');

        try {
          await _speech
              .listen(
                onResult: (result) {
                  debugPrint(
                      '\ud83d\udde3\ufe0f [Speech] onResult: ${result.recognizedWords} (final: ${result.finalResult})');
                  if (mounted)
                    setState(
                        () => promptController.text = result.recognizedWords);
                },
                listenOptions: SpeechListenOptions(
                  listenMode: ListenMode.dictation,
                  partialResults: true,
                  cancelOnError: true,
                ),
                listenFor: const Duration(seconds: 30),
                pauseFor: const Duration(seconds: 3),
              )
              .timeout(const Duration(seconds: 35));

          debugPrint('\u2705 [Speech] listen() called successfully');
        } catch (listenEx) {
          debugPrint('\ud83d\uded1 [Speech] listen() threw: $listenEx');
          rethrow;
        }
      } else {
        debugPrint('[Speech] Stopping...');
        await _speech.stop();
        if (mounted) setState(() => _listening = false);
      }
    } catch (e, st) {
      debugPrint('\ud83d\uded1 [Speech] CRASH: mic press failed: $e');
      debugPrint('Stack: $st');

      // REMOTE DEBUG LOG: Mic error
      try {
        await RemoteDebugLogger.instance
            .logError('Mic press failed', e, st)
            .timeout(const Duration(seconds: 2));
      } catch (logErr) {
        debugPrint('\u26a0\ufe0f [RemoteLog] Failed to log mic error: $logErr');
      }

      if (isIOSWeb) {
        _showSnack(
            'Voice input unavailable in iOS preview. Works in native app.');
      } else {
        _showSnack('Mic not supported or permission denied.');
      }

      try {
        await _speech.stop();
      } catch (stopErr) {
        debugPrint('\u26a0\ufe0f [Speech] stop() error: $stopErr');
      }

      if (mounted) setState(() => _listening = false);
    }
  }

  Future<void> _toggleFavorite() async {
    if (generatedImageBytes == null) return;

    // If already favorited, just show message (unsave is complex without ID tracking)
    if (_isFavorited) {
      _showSnack('Already in your favorites');
      return;
    }

    try {
      final outfit = FavoriteOutfit(
        imageBytes: generatedImageBytes!,
        prompt: _buildFinalPrompt(),
        timestamp: DateTime.now(),
      );
      await FavoritesManager.addFavorite(outfit);

      // Reload or locally update favorites
      await _loadFavorites();

      if (mounted) {
        setState(() => _isFavorited = true);
        _showSnack('Saved to Favorites');
      }
    } catch (e) {
      debugPrint('❌ Failed to save favorite: $e');
      if (!mounted) return;
      _showSnack('Failed to save. Please try again.');
    }
  }

  Future<void> _shareImage() async {
    if (_latestImageUrl == null && generatedImageBytes == null) {
      _showSnack('No image to share');
      return;
    }

    try {
      await AudioService.instance.playClick();

      // If we have a URL and NO caption, use the URL; otherwise capture composite
      if (_captionText.isEmpty && _latestImageUrl != null) {
        await SofiExportService.shareImage(
          context: context,
          imageUrl: _latestImageUrl!,
          shareText: 'Made with Sofi Saint',
          fileName: 'sofi_studio_${DateTime.now().millisecondsSinceEpoch}.png',
        );
        _showSnack('Opening share sheet...');
      } else {
        final bytes = await _captureCompositeImage() ?? generatedImageBytes;
        if (bytes != null) {
          await Share.shareXFiles(
            [XFile.fromData(bytes, name: 'sofi.png', mimeType: 'image/png')],
            text: 'Made with Sofi Saint',
            subject: 'Sofi Saint Creation',
          );
        } else {
          _showSnack('No image to share');
        }
      }
    } catch (e) {
      debugPrint('❌ Failed to share: $e');
      _showSnack('Failed to share. Please try again.');
    }
  }

  Future<void> _downloadImage() async {
    if (_latestImageUrl == null && generatedImageBytes == null) {
      _showSnack('No image to download');
      return;
    }

    try {
      await AudioService.instance.playClick();

      // If we have no caption and a URL, use the service; otherwise save composite bytes
      if (_captionText.isEmpty && _latestImageUrl != null) {
        await SofiExportService.saveImage(
          imageUrl: _latestImageUrl ?? '',
          fileName: 'sofi_studio_${DateTime.now().millisecondsSinceEpoch}.png',
        );
      } else {
        final bytes = await _captureCompositeImage() ?? generatedImageBytes;
        if (bytes != null) {
          await SofiExportService.saveImageBytes(
            bytes,
            'sofi_studio_${DateTime.now().millisecondsSinceEpoch}.png',
          );
        } else {
          throw Exception('No image bytes to save');
        }
      }
      _showSnack(kIsWeb ? 'Image downloaded!' : 'Saved to Photos ✓');
    } catch (e) {
      debugPrint('❌ Failed to download: $e');
      _showSnack('Failed to save. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    // STEP 3 — OVERLAY DISMISS (auto-gen is handled in _init())
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // Force-hide welcome overlay if entering from mood flow
      if (controller.skipWelcomeOverlay && _showCanvasHint) {
        setState(() {
          _showCanvasHint = false;
          _awaitingMoodFlowContinue = false;
        });
        debugPrint('[Studio] Force-dismissed canvas hint (skipWelcomeOverlay)');

        // Celebration on first entry from mood flow
        _confettiController.play();
      }
    });

    final theme = ThemeManager.instance.current;
    // Updated background color to blend with stage
    return Scaffold(
      backgroundColor: theme.backgroundColor,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // 1. Full Screen Background Layer (if needed, but currently just color)

          // 2. Centered Content (Tablet View Constraint)
          Center(
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(maxWidth: 800), // Max tablet width
              child: Stack(
                children: [
                  // Main layout: Header at top, Stage fills the rest
                  Column(
                    children: [
                      SafeArea(
                        bottom: false,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOutCubic,
                          height: _showUI ? null : 0,
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 250),
                            opacity: _showUI ? 1.0 : 0.0,
                            child: _header(),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            setState(() => _showUI = !_showUI);
                          },
                          child: buildStage(controller),
                        ),
                      ),
                    ],
                  ),

                  // Floating Prompt Preview (above footer) (duck away)
                  if (promptController.text.isNotEmpty &&
                      !_isGenerating &&
                      !controller.isDrawerOpen)
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeOutCubic,
                      left: 24,
                      right: 24,
                      bottom: _showUI ? MediaQuery.of(context).padding.bottom + 90 : -50,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 250),
                        opacity: _showUI ? 1.0 : 0.0,
                        child: _buildPromptPreview(),
                      ),
                    ),

                  // Sidebars (They handle their own Positioned/AnimatedPositioned internals)
                if (!_isGenerating && !controller.isDrawerOpen) ...[
                  _buildQuickMoodBar(),
                  _buildUtilityBar(),
                  _buildBottomLeftExtras(),
                ],

                  // Preview Watermark (for free users using premium modes)
                  if (_shouldShowPreviewWatermark())
                    Positioned(
                      bottom: 240, 
                      right: 16,
                      child: Opacity(
                        opacity: 0.35,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Preview',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Floating "Giant Pill" Footer (handles its own AnimatedPositioned)
                  _buildFloatingFooter(),

                  // Tap-outside scrim (Animated)
                  AnimatedBuilder(
                    animation: _drawerAnimation,
                    builder: (context, child) {
                      if (_drawerAnimation.value == 0) {
                        return const SizedBox.shrink();
                      }
                      return Positioned.fill(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () async {
                            // AudioService.instance.playClick(); // Handled by onClose logic
                            _closeDrawer();
                          },
                          child: Container(
                            color: Colors.black.withOpacity(0.25 * _drawerAnimation.value),
                          ),
                        ),
                      );
                    },
                  ),

                  // Bottom Drawer (Animated)
                  AnimatedBuilder(
                    animation: _drawerAnimation,
                    builder: (context, child) {
                      if (_drawerAnimation.value == 0) {
                        return const SizedBox.shrink();
                      }

                      final double sheetHeight =
                          MediaQuery.of(context).size.height * 0.75;
                      final double offset =
                          sheetHeight * (1 - _drawerAnimation.value);

                      return Positioned(
                        key: const ValueKey('sofi_drawer'),
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Transform.translate(
                          offset: Offset(0, offset),
                          child: Opacity(
                            opacity: _drawerAnimation.value.clamp(0.0, 1.0),
                            child: SofiBottomDrawer(
                              initialCategory: _drawerInitialCategory,
                              onGenerate: _onGenerate,
                              onCategorySelected: (cat, opt) => _onCategorySelected(cat, opt),
                              currentDoll: controller.currentDoll,
                              baseDolls: controller.baseDolls,
                              premiumDolls: controller.premiumDolls,
                              onDollSelected: _selectDollAndLoadStage,
                              // Caption integration
                              captionText: _captionText,
                              onCaptionChanged: (val) => setState(() => _captionText = val),
                              captionFont: _captionFont,
                              onCaptionFontChanged: (val) => setState(() => _captionFont = val),
                              captionColor: _captionColor,
                              onCaptionColorChanged: (val) => setState(() => _captionColor = val),
                              captionY: _captionY,
                              onCaptionYChanged: (val) => setState(() => _captionY = val),
                              captionFonts: _captionFonts,
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  if (_isGenerating) _spinner(),

                  // One-time transparent tap catcher to unlock audio on iPhone Safari/web.
                  // Only show when canvas hint is not visible (canvas hint handles unlock when visible)
                  if (_awaitingFirstSoundUnlock && !_showCanvasHint)
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          setState(() => _awaitingFirstSoundUnlock = false);
                          // Play a subtle click to initialize audio route, then speak intro
                          AudioService.instance.playClick();
                          unawaited(VoiceCoachService.instance
                              .speakWelcomeIntro()
                              .catchError((e) {
                            debugPrint(
                                '[VoiceCoach] speakWelcomeIntro error: $e');
                          }));
                        },
                        child: Container(
                          color: Colors.transparent,
                        ),
                      ),
                    ),

                  // First-time canvas hint overlay
                  if (_showCanvasHint &&
                      !_isGenerating &&
                      !controller.isDrawerOpen &&
                      !controller.skipWelcomeOverlay)
                    _buildCanvasHintOverlay(),

                  // Premium reminder popup (every 2 generations)
                  if (_showPremiumReminder &&
                      !_isGenerating &&
                      !controller.isDrawerOpen)
                    _buildPremiumReminderOverlay(),

                  // ─────────────── CONFETTI DROP (TOP LAYER) ───────────────
                  Align(
                    alignment: Alignment.topCenter,
                    child: ConfettiWidget(
                      confettiController: _confettiController,
                      blastDirectionality: BlastDirectionality.explosive,
                      shouldLoop: false,
                      colors: const [
                        SofiStudioTheme.yellow,
                        SofiStudioTheme.purple,
                        Colors.white,
                        Colors.blueAccent,
                        Colors.pinkAccent,
                      ],
                      numberOfParticles: 50,
                      minBlastForce: 20,
                      maxBlastForce: 40,
                      gravity: 0.1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingPill({
    required Widget child,
    required VoidCallback onTap,
    bool active = false,
    String? tooltip,
    double width = 58,
    double height = 72,
  }) {
    final theme = ThemeManager.instance.current;
    final bool isDark = theme.type == AppThemeType.black;
    final bool isIOSWeb = kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

    return Tooltip(
      message: tooltip ?? '',
      child: GestureDetector(
        onTap: () {
          AudioService.instance.playTick();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: active
                ? theme.accentColor.withOpacity(isDark ? 0.85 : 0.9)
                : (isDark
                    ? Colors.black.withOpacity(0.5)
                    : theme.headerColor.withOpacity(0.85)),
            borderRadius: BorderRadius.circular(width / 2),
            border: Border.all(
              color: active
                  ? Colors.white54
                  : (isDark ? Colors.white24 : Colors.black12),
              width: active ? 1.5 : 1,
            ),
            boxShadow: isIOSWeb
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    )
                  ],
          ),
          alignment: Alignment.center,
          child: child,
        ),
      ),
    );
  }

  Widget _buildQuickMoodBar() {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      left: _showUI ? 12 : -80,
      top: 0,
      bottom: 0,
      child: Center(
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 250),
          opacity: _showUI ? 1.0 : 0.0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: _quickMoods.map((m) {
              final bool active = m.id == _activeMoodId;
              final theme = ThemeManager.instance.current;
              final bool isDark = theme.type == AppThemeType.black;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: _buildFloatingPill(
                  active: active,
                  onTap: () => _setQuickMood(m.id),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        m.icon,
                        size: 18,
                        color: active
                            ? Colors.white
                            : (isDark ? Colors.white70 : Colors.black54),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        m.label,
                        style: GoogleFonts.poppins(
                          fontSize: 9,
                          fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                          color: active
                              ? Colors.white
                              : (isDark ? Colors.white70 : Colors.black87),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    final theme = ThemeManager.instance.current;
    final bool isDark = theme.type == AppThemeType.black;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: theme.headerColor,
        // No border radius to blend seamlessly with stage background
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row 1: Branding and Global Actions
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  height: 32,
                  width: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDark
                        ? Colors.white.withOpacity(0.1)
                        : Colors.black.withOpacity(0.05),
                    border: Border.all(
                      color: isDark ? Colors.white24 : Colors.black12,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.arrow_back_ios_new,
                    size: 16,
                    color: theme.headerTextColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                height: 32,
                width: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFa855f7), Color(0xFFec4899)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                      color: isDark ? Colors.white54 : Colors.white,
                      width: 1.5),
                ),
                child: const Icon(Icons.auto_awesome,
                    color: Colors.white, size: 18),
              ),
              const Spacer(),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Share button (only show if image is generated)
                  if (_latestImageUrl != null) ...[
                    _headerBtn(
                      Icons.share,
                      'Share',
                      _shareImage,
                      color: theme.headerTextColor,
                    ),
                    const SizedBox(width: 8),
                  ],
                  // Download button (only show if image is generated)
                  if (_latestImageUrl != null) ...[
                    _headerBtn(
                      Icons.download,
                      'Download',
                      _downloadImage,
                      color: theme.headerTextColor,
                    ),
                    const SizedBox(width: 8),
                  ],
                  _headerBtn(
                    _isFavorited ? Icons.favorite : Icons.favorite_border,
                    'Save',
                    _toggleFavorite,
                    color: _isFavorited
                        ? const Color(0xFFe94560)
                        : theme.headerTextColor,
                  ),
                  const SizedBox(width: 8),
                  if (_latestImageUrl != null) ...[
                    _headerBtn(
                      Icons.report_problem_outlined,
                      'Report',
                      _reportContent,
                      color: Colors.orangeAccent,
                    ),
                    const SizedBox(width: 8),
                  ],
                  _PremiumEntryButton(onTap: _openPremium),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Row 2: Studio Specific Control
          ListenableBuilder(
            listenable: UserPreferencesService.instance,
            builder: (context, _) {
              final isDoll = UserPreferencesService.instance.isDollMode;
              final isMale = UserPreferencesService.instance.isMaleMode;
              return Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _buildHeaderToggle(
                        label: isDoll ? 'Doll' : 'Human',
                        value: isDoll,
                        onChanged: (val) {
                          UserPreferencesService.instance.setDollMode(val);
                        },
                        activeColor: SofiStudioTheme.purple,
                      ),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // New prominent Caption button
                      GestureDetector(
                        onTap: () async {
                          await AudioService.instance.playClick();
                          setState(() => _drawerInitialCategory = EditCategory.caption);
                          controller.openDrawer();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: SofiStudioTheme.brandGradient,
                            borderRadius: _radius20,
                            boxShadow: SofiStudioTheme.softShadow,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.closed_caption, color: Colors.white, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                'Caption',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () async {
                          await AudioService.instance.playClick();
                          setState(() => _drawerInitialCategory = EditCategory.fullOutfit);
                          controller.openDrawer();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withOpacity(0.1) : Colors.white,
                            borderRadius: _radius20,
                            boxShadow: isDark ? null : SofiStudioTheme.softShadow,
                            border: isDark ? Border.all(color: Colors.white24) : null,
                          ),
                          child: Text(
                            'Design Studio',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: theme.accentColor,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: _buildHeaderToggle(
                        label: isMale ? 'Male' : 'Fem',
                        value: isMale,
                        onChanged: (val) {
                          UserPreferencesService.instance.setMaleMode(val);
                        },
                        activeColor: Colors.blueAccent,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderToggle({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
    required Color activeColor,
  }) {
    final theme = ThemeManager.instance.current;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: value ? activeColor : theme.headerTextColor.withOpacity(0.7),
          ),
        ),
        const SizedBox(width: 4),
        SizedBox(
          height: 20,
          width: 32,
          child: FittedBox(
            fit: BoxFit.contain,
            child: CupertinoSwitch(
              value: value,
              activeColor: activeColor,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _headerBtn(IconData icon, String label, VoidCallback onTap,
      {Color? color}) {
    final theme = ThemeManager.instance.current;
    final bool isDark = theme.type == AppThemeType.black;
    final effectiveColor = color ?? theme.headerTextColor;

    return GestureDetector(
      onTap: () async {
        await AudioService.instance.playClick();
        onTap();
      },
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withOpacity(0.1)
              : Colors.white.withOpacity(0.5),
          borderRadius: _radius10,
          border: Border.all(color: isDark ? Colors.white24 : Colors.black12),
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 20, color: effectiveColor),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // STEP 3 — HARD LOCK STAGE RENDERING (WEB-SAFE)
  // ---------------------------------------------------------------------------
  Widget buildStage(SofiStudioController controller) {
    // STEP 3 — FIX CANVAS IMAGE SOURCE
    // Show generated image from local state first, then fallback to controller
    final selfie = generatedImageBytes ??
        controller.generatedImageBytes ??
        _originalBaseDollBytes ??
        controller.selfieBytes;

    if (controller.isGenerating || _isGenerating) {
      // Don't show a spinner here; the main Stack shows the GenerationLoader
      return const SizedBox.shrink();
    }

    if (selfie == null) {
      return const SizedBox();
    }

    return RepaintBoundary(
      key: _stageKey,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.memory(
            selfie,
            fit: BoxFit.cover,
            gaplessPlayback: true,
          ),
          if (_captionText.isNotEmpty)
            Positioned(
              left: 20,
              right: 20,
              top: 0,
              bottom: 0,
              child: Align(
                alignment: Alignment(0, (_captionY * 2) - 1),
                child: Text(
                  _captionText,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.getFont(
                    _captionFont,
                    color: _captionColor,
                    fontSize: 32,
                    shadows: [
                      const Shadow(
                        blurRadius: 8.0,
                        color: Colors.black54,
                        offset: Offset(2.0, 2.0),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // NOTE: Stage rendering now lives in buildStage(controller) (see above).

  Widget _buildPromptPreview() {
    final theme = ThemeManager.instance.current;
    final bool isDark = theme.type == AppThemeType.black;
    final text = promptController.text;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: text.isNotEmpty ? 1.0 : 0.0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.black.withOpacity(0.75)
              : Colors.white.withOpacity(0.9),
          borderRadius: _radius16, // ✅ CONST
          border: Border.all(
            color: isDark ? Colors.white24 : Colors.black12,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              _listening ? Icons.mic : Icons.format_quote,
              size: 16,
              color: _listening
                  ? theme.accentColor
                  : (isDark ? Colors.white54 : Colors.black38),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: GoogleFonts.poppins(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 15,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Clear button
            GestureDetector(
              onTap: () {
                promptController.clear();
                if (!mounted) return;
                setState(() {});
              },
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Icon(
                  Icons.close,
                  size: 18,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUtilityBar() {
    final theme = ThemeManager.instance.current;
    final bool isDark = theme.type == AppThemeType.black;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      right: _showUI ? 12 : -80,
      top: 0,
      bottom: 0,
      child: Center(
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 250),
          opacity: _showUI ? 1.0 : 0.0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildFloatingPill(
                width: 54,
                height: 54,
                tooltip: 'Options',
                onTap: () async {
                  await AudioService.instance.playClick();
                  controller.openDrawer();
                },
                child: Icon(Icons.tune,
                    color: isDark ? Colors.white70 : Colors.black87, size: 22),
              ),
              const SizedBox(height: 12),
              _buildFloatingPill(
                width: 54,
                height: 54,
                tooltip: 'Voice Coach',
                onTap: () async {
                  await AudioService.instance.playClick();
                  if (!mounted) return;
                  await showModalBottomSheet(
                    context: context,
                    backgroundColor: Colors.transparent,
                    isScrollControlled: false,
                    builder: (_) => const VoiceCoachSettingsSheet(),
                  );
                },
                child: Icon(Icons.record_voice_over,
                    color: isDark ? Colors.white70 : Colors.black87, size: 22),
              ),
              const SizedBox(height: 12),
              _buildFloatingPill(
                width: 54,
                height: 54,
                tooltip: 'Undo',
                active: false,
                onTap: _undo,
                child: Icon(Icons.undo_rounded,
                    color: _history.length > 1
                        ? (isDark ? Colors.white70 : Colors.black87)
                        : Colors.grey.withOpacity(0.5),
                    size: 22),
              ),
              const SizedBox(height: 12),
              _buildFloatingPill(
                width: 54,
                height: 54,
                tooltip: 'Redo',
                onTap: _redo,
                child: Icon(Icons.redo_rounded,
                    color: _redoStack.isNotEmpty
                        ? (isDark ? Colors.white70 : Colors.black87)
                        : Colors.grey.withOpacity(0.5),
                    size: 22),
              ),
              const SizedBox(height: 12),
              _buildFloatingPill(
                width: 54,
                height: 54,
                tooltip: 'History',
                onTap: _openHistory,
                child: Icon(Icons.history_rounded,
                    color: _history.isNotEmpty
                        ? (isDark ? Colors.white70 : Colors.black87)
                        : Colors.grey.withOpacity(0.5),
                    size: 22),
              ),
              const SizedBox(height: 12),
              _buildFloatingPill(
                width: 54,
                height: 54,
                tooltip: 'Camera',
                onTap: _pickSelfie,
                child: Icon(Icons.camera_alt_rounded,
                    color: isDark ? Colors.white70 : Colors.black87, size: 22),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomLeftExtras() {
    final theme = ThemeManager.instance.current;
    final bool isDark = theme.type == AppThemeType.black;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      left: 12,
      bottom: _showUI ? 100 + bottomPadding : -100, // Positioned above the footer
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 250),
        opacity: _showUI ? 1.0 : 0.0,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildFloatingPill(
              width: 44,
              height: 44,
              tooltip: 'Settings',
              onTap: () async {
                await AudioService.instance.playClick();
                if (!mounted) return;
                await showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.transparent,
                  builder: (_) => Theme(
                    data: ThemeData.light(),
                    child: SofiSettingsSheet(
                      autoSave: false,
                      onAutoSaveChanged: (_) {},
                    ),
                  ),
                );
              },
              child: Icon(Icons.settings,
                  color: isDark ? Colors.white54 : Colors.black45, size: 20),
            ),
            const SizedBox(width: 8),
            _buildFloatingPill(
              width: 44,
              height: 44,
              tooltip: 'Share',
              onTap: _shareCurrent,
              child: Icon(Icons.ios_share,
                  color: isDark ? Colors.white54 : Colors.black45, size: 20),
            ),
            const SizedBox(width: 8),
            _buildFloatingPill(
              width: 44,
              height: 44,
              tooltip: 'Theme',
              onTap: () => ThemeManager.instance.cycleTheme(),
              child: Icon(ThemeManager.instance.current.icon,
                  color: isDark ? Colors.white54 : Colors.black45, size: 20),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingFooter() {
    final theme = ThemeManager.instance.current;
    final bool isDark = theme.type == AppThemeType.black;
    final bool isIOSWeb = kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      left: 0,
      right: 0,
      bottom: _showUI ? 0 : -150, // Duck away downwards
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 250),
        opacity: _showUI ? 1.0 : 0.0,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomPadding),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.black.withOpacity(0.85)
                  : Colors.white.withOpacity(0.95),
              borderRadius: _radius32,
              border: Border.all(
                color: isDark ? Colors.white24 : Colors.black12,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                // Text Field
                Expanded(
                  child: TextField(
                    controller: promptController,
                    style: GoogleFonts.poppins(
                      color: isDark ? Colors.white : Colors.black87,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    decoration: InputDecoration(
                      hintText: 'Describe outfit…',
                      hintStyle: GoogleFonts.poppins(
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    textInputAction: TextInputAction.go,
                  ),
                ),
                // Mic
                IconButton(
                  icon: Icon(_listening ? Icons.mic : Icons.mic_none),
                  color: _listening
                      ? theme.accentColor
                      : (isDark ? Colors.white70 : Colors.black54),
                  onPressed: () async {
                    await AudioService.instance.playClick();
                    await _onMicPressed();
                  },
                ),
                const SizedBox(width: 8),
                // Generate Button
                ScaleTransition(
                  scale: _isGenerating
                      ? const AlwaysStoppedAnimation(1.0)
                      : (_generateBtnScale ?? const AlwaysStoppedAnimation(1.0)),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: controller.isGenerating
                          ? null
                          : () async {
                              HapticFeedback.mediumImpact();
                              if (_outOfCredits) {
                                if (!context.mounted) return;
                                await PaywallSheet.show(context);
                                return;
                              }
                              await _onGeneratePressed();
                            },
                      borderRadius: _radius24,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          gradient: _isGenerating ? null : SofiStudioTheme.brandGradient,
                          color: _isGenerating ? Colors.grey.shade400 : null,
                          borderRadius: _radius24,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_isGenerating)
                              const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white))
                            else ...[
                              const Icon(Icons.auto_awesome,
                                  size: 18, color: Colors.white),
                              const SizedBox(width: 8),
                              Text('Generate',
                                  style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14)),
                            ]
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _reportContent() {
    // App Store Guideline 1.1: Provide a way to report objectionable content
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report Content'),
        content: const Text(
          'Does this image violate our safety guidelines or contain objectionable content? Reporting helps keep Sofi Saint safe.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              unawaited(RemoteDebugLogger.instance.logInteraction('CONTENT_REPORTED', {
                'imageUrl': _latestImageUrl,
                'timestamp': DateTime.now().toIso8601String(),
              }));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Thank you. This content has been reported for review.')),
              );
            },
            child: const Text('Report', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // Floating cluster for undo/redo/history, positioned over the stage
  Widget floatingHistoryCluster({
    required bool canUndo,
    required bool canRedo,
    required bool hasHistory,
    required VoidCallback onUndo,
    required VoidCallback onRedo,
    required VoidCallback onOpenHistory,
  }) {
    final bool isIOSWeb = kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    return ClipRRect(
      borderRadius: _radius24,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.10),
          borderRadius: _radius24,
          border: isIOSWeb
              ? null
              : Border.all(
                  color: Colors.black.withOpacity(0.20), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _HistoryButton(
              icon: Icons.undo_rounded,
              tooltip: 'Undo',
              enabled: canUndo,
              onTap: () {
                AudioService.instance.playTick();
                HapticFeedback.lightImpact();
                onUndo();
              },
            ),
            _HistoryButton(
              icon: Icons.redo_rounded,
              tooltip: 'Redo',
              enabled: canRedo,
              onTap: () {
                AudioService.instance.playTick();
                HapticFeedback.lightImpact();
                onRedo();
              },
            ),
            _HistoryButton(
              icon: Icons.history_rounded,
              tooltip: 'History',
              enabled: hasHistory,
              onTap: () {
                AudioService.instance.playClick();
                HapticFeedback.lightImpact();
                onOpenHistory();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCanvasHintOverlay() {
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _dismissCanvasHint,
        child: Container(
          color: Colors.black.withOpacity(0.5),
          child: SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Welcome to Sofi Studio!',
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _HintButton(
                    icon: Icons.tune,
                    label: 'Tap Design Studio',
                    subtitle: 'to start styling',
                    onTap: () {
                      _dismissCanvasHint();
                      controller.openDrawer();
                    },
                  ),
                  const SizedBox(height: 12),
                  _HintButton(
                    icon: Icons.history_rounded,
                    label: 'Tap History',
                    subtitle: 'to view your creations',
                    onTap: () {
                      _dismissCanvasHint();
                      _openHistory();
                    },
                  ),
                  const SizedBox(height: 12),
                  _HintButton(
                    icon: Icons.favorite_rounded,
                    label: 'Tap Favorites',
                    subtitle: 'to save & reuse outfits',
                    onTap: () {
                      _dismissCanvasHint();
                      controller.openDrawer();
                    },
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _onContinueStylingPressed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6C4DFF),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 28, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text(
                      'Continue Styling',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Tap anywhere to dismiss',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _spinner() {
    // Collect premium doll paths for fallback
    final premiumPaths =
        controller.premiumDolls.map((d) => d.stagePath).toList();

    return Positioned.fill(
      child: GenerationLoader(
        historyImages: _history,
        premiumAssetPaths: premiumPaths,
      ),
    );
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins()),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showPremiumReminderPopup() {
    if (!mounted) return;
    _premiumReminderTimer?.cancel();
    setState(() => _showPremiumReminder = true);

    // Auto-dismiss after 10 seconds
    _premiumReminderTimer = Timer(const Duration(seconds: 10), () {
      if (mounted) {
        setState(() => _showPremiumReminder = false);
      }
    });
  }

  void _dismissPremiumReminder() {
    if (!mounted) return;
    _premiumReminderTimer?.cancel();
    setState(() => _showPremiumReminder = false);
  }

  Widget _buildPremiumReminderOverlay() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 70,
      left: 16,
      right: 16,
      child: TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 300),
        tween: Tween(begin: 0.0, end: 1.0),
        curve: Curves.easeOutBack,
        builder: (context, value, child) {
          return Transform.scale(
            scale: value,
            child: Opacity(opacity: value.clamp(0.0, 1.0), child: child),
          );
        },
        child: GestureDetector(
          onTap: _dismissPremiumReminder,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF9B59B6),
                  Color(0xFFE91E63),
                  Color(0xFFFF9800),
                ],
              ),
              borderRadius: _radius20,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF9B59B6).withOpacity(0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                // Sparkle icon
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                // Text content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Unlock More Styles!',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Explore premium features for unlimited creativity',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                // CTA button
                GestureDetector(
                  onTap: () {
                    _dismissPremiumReminder();
                    _openPremium();
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: _radius20,
                    ),
                    child: Text(
                      'Go',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF9B59B6),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Dismiss X
                GestureDetector(
                  onTap: _dismissPremiumReminder,
                  child: Icon(
                    Icons.close,
                    color: Colors.white.withOpacity(0.7),
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSheetOption({
    required IconData icon,
    required String label,
    String? subtitle,
    bool isPrimary = false,
    required VoidCallback onTap,
  }) {
    return Material(
      color: isPrimary ? const Color(0xFFF5F0FF) : Colors.grey.shade100,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(
                icon,
                size: 24,
                color: isPrimary
                    ? const Color(0xFF9B59B6)
                    : const Color(0xFF333333),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight:
                            isPrimary ? FontWeight.w600 : FontWeight.w500,
                        color: const Color(0xFF1A1A1A),
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF666666),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color:
                    isPrimary ? const Color(0xFF9B59B6) : Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Helper button for the history cluster
class _HistoryButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final bool enabled;
  final VoidCallback onTap;

  const _HistoryButton(
      {required this.icon,
      required this.tooltip,
      required this.enabled,
      required this.onTap});

  @override
  State<_HistoryButton> createState() => _HistoryButtonState();
}

class _HistoryButtonState extends State<_HistoryButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 80));
    _scale = Tween<double>(begin: 1.0, end: 0.85)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.enabled ? Colors.black87 : Colors.black26;
    return Tooltip(
      message: widget.tooltip,
      child: GestureDetector(
        onTapDown: widget.enabled ? (_) => _controller.forward() : null,
        onTapUp: widget.enabled ? (_) => _controller.reverse() : null,
        onTapCancel: widget.enabled ? () => _controller.reverse() : null,
        onTap: widget.enabled ? widget.onTap : null,
        child: ScaleTransition(
          scale: _scale,
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.enabled ? Colors.transparent : Colors.transparent,
            ),
            child: Icon(widget.icon, size: 20, color: color),
          ),
        ),
      ),
    );
  }
}

// Minimal glassy circular button used for the floating Share control
// See-through style with subtle black tint to match canvas aesthetics
// Intentionally lightweight (no heavy drop shadows)
// Note: Keep icon color high-contrast for accessibility
class _FrostyCircleButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  const _FrostyCircleButton(
      {required this.icon, required this.tooltip, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: ClipRRect(
        borderRadius: _SofiStudioPageState._radius24,
        child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.10),
              borderRadius: _SofiStudioPageState._radius24, // ✅ CONST
              border: (kIsWeb && defaultTargetPlatform == TargetPlatform.iOS)
                  ? null
                  : Border.all(
                      color: Colors.black.withOpacity(0.20), width: 1),
            ),
            child: IconButton(
              icon: Icon(icon, size: 20, color: Colors.black87),
              onPressed: () async {
                await AudioService.instance.playClick();
                onTap?.call();
              },
              tooltip: tooltip,
            ),
          ),
        ),
    );
  }
}

/// Widget to display doll stage image from Firebase Storage
class _FirebaseStageImage extends StatefulWidget {
  final String path;

  const _FirebaseStageImage({required this.path});

  @override
  State<_FirebaseStageImage> createState() => _FirebaseStageImageState();
}

class _FirebaseStageImageState extends State<_FirebaseStageImage> {
  String? _url;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(_FirebaseStageImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.path != oldWidget.path) {
      _loadImage();
    }
  }

  Future<void> _loadImage() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final url = await StorageService.instance.getDownloadUrl(widget.path);
      if (mounted) setState(() => _url = url);
    } catch (e) {
      debugPrint('Failed to load stage image: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_url == null) {
      return const Center(child: Icon(Icons.broken_image, size: 48));
    }
    return Image.network(
      _url!,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.high,
    );
  }
}

/// Hint button for first-time canvas overlay
class _HintButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _HintButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 110),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: _SofiStudioPageState._radius16, // ✅ CONST
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Color(0x1A9B59B6), // ✅ CONST (10% opacity of purple)
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: SofiStudioTheme.purple, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios,
                size: 14, color: Colors.black38),
          ],
        ),
      ),
    );
  }
}

/// Animated premium entry button with gradient shimmer effect
class _PremiumEntryButton extends StatefulWidget {
  final VoidCallback onTap;
  const _PremiumEntryButton({required this.onTap});

  @override
  State<_PremiumEntryButton> createState() => _PremiumEntryButtonState();
}

class _PremiumEntryButtonState extends State<_PremiumEntryButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        await AudioService.instance.playClick();
        widget.onTap();
      },
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              borderRadius: _SofiStudioPageState._radius12, // ✅ CONST
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: const [
                  Color(0xFF9B59B6), // Purple
                  Color(0xFFE91E63), // Pink
                  Color(0xFFFF9800), // Gold/Orange
                ],
                stops: [
                  (_controller.value - 0.3).clamp(0.0, 1.0),
                  _controller.value,
                  (_controller.value + 0.3).clamp(0.0, 1.0),
                ],
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x669B59B6), // ✅ CONST (40% opacity)
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Shimmer overlay
                ClipRRect(
                  borderRadius: _SofiStudioPageState._radius12, // ✅ CONST
                  child: Transform.translate(
                    offset: Offset(40 * (_controller.value - 0.5), 0),
                    child: Container(
                      width: 20,
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withOpacity(0),
                            Colors.white.withOpacity(0.4),
                            Colors.white.withOpacity(0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // Main content - stylized "S" with sparkle
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'S',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 2,
                            offset: const Offset(1, 1),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.auto_awesome,
                      size: 10,
                      color: Colors.white,
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
