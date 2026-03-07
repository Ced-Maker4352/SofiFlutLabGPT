import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image/image.dart' as img;

import 'package:sofi_test_connect/data/theme_presets_data.dart';
import 'package:sofi_test_connect/models/theme_presets.dart';
import 'package:sofi_test_connect/services/two_step_generation_service.dart';
import 'package:sofi_test_connect/services/prompt_builder.dart';
import 'package:sofi_test_connect/presentation/shared/stage_image.dart';
import 'package:sofi_test_connect/presentation/sofi_studio/widgets/generation_loader.dart';
import 'package:sofi_test_connect/presentation/sofi_studio/favorites_manager.dart';
import 'package:sofi_test_connect/presentation/sofi_studio/models/favorite_outfit.dart';
import 'package:sofi_test_connect/presentation/premium/sofi_music_page.dart';
import 'package:sofi_test_connect/presentation/premium/share_hub_page.dart';
import 'package:sofi_test_connect/presentation/premium/favorites_hub_page.dart';
import 'package:sofi_test_connect/presentation/premium/discover_page.dart';
import 'package:sofi_test_connect/services/storage_service.dart';
import 'package:sofi_test_connect/services/sofi_export_service.dart';
import 'package:sofi_test_connect/presentation/premium/paywall_sheet.dart';

class PremiumStudioPage extends StatefulWidget {
  /// If null, user can upload from within Premium page
  final String? userHeadshotBase64;

  /// If true, premium-only theme packs unlock
  final bool isPremiumUser;

  final TwoStepGenerationService generationService;
  final List<String> premiumAssetPaths;

  /// If provided, auto-opens the theme sheet with this theme selected
  final ThemePreset? initialTheme;

  const PremiumStudioPage({
    super.key,
    this.userHeadshotBase64,
    required this.generationService,
    this.isPremiumUser = false,
    this.premiumAssetPaths = const [],
    this.initialTheme,
  });

  @override
  State<PremiumStudioPage> createState() => _PremiumStudioPageState();
}

enum ExportPreset {
  story, // 9:16
  post, // 1:1
  wallpaper, // 9:16 (full height)
}

/// Compress + downscale favorite images so they fit inside web localStorage limits.
Future<Uint8List> _compressFavoriteImage(Uint8List bytes) async {
  return compute(_compressFavoriteImageIsolate, bytes);
}

Uint8List _compressFavoriteImageIsolate(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return bytes;

  // INCREASED resolution and quality to preserve facial details
  const int maxDim = 1200; // Higher resolution to preserve face details
  final resized = img.copyResize(
    decoded,
    width: decoded.width >= decoded.height ? maxDim : null,
    height: decoded.height > decoded.width ? maxDim : null,
    interpolation:
        img.Interpolation.cubic, // Better quality interpolation for faces
  );

  // Higher JPEG quality to preserve facial details and reduce artifacts
  final jpg = img.encodeJpg(resized, quality: 88);
  return Uint8List.fromList(jpg);
}

class _PremiumStudioPageState extends State<PremiumStudioPage> {
  // ---------------- SOURCE / STEP 1 / STEP 2 ----------------
  Uint8List? _userImageBytes;

  bool loadingIdentity = false;
  Uint8List? lockedBodyBytes;

  bool applyingStyle = false;
  Uint8List? styledBytes;
  Uint8List? _styledBytesOriginal; // for crop reset

  // ---------------- THEME ----------------
  ThemePreset? selectedTheme;
  ThemeVariant? selectedVariant;

  // ---------------- HISTORY ----------------
  final List<_GenerationHistoryEntry> _generationHistory = [];
  int _historyIndex = -1;

  // ---------------- CUSTOM PROMPT ----------------
  final TextEditingController _promptController = TextEditingController();

  // ---------------- FAVORITES ----------------
  static const _favKey = 'favorite_styles_v1';
  final Set<String> favorites = {};

  bool _currentImageSaved = false;

  // ---------------- ADVANCED (kept for later) ----------------
  bool showAdvanced = false;
  bool batchEnabled = false;
  int batchCount = 4;
  bool mixVariants = true;

  // ---------------- CROP ----------------
  double? _cropAspect; // null = full
  double _cropFocus = 0; // -1 top, 0 center, 1 bottom

  bool get _needsUpload => _userImageBytes == null && lockedBodyBytes == null;

  // ---------------- HELPERS ----------------
  String? _b64(Uint8List? bytes) => bytes == null ? null : base64Encode(bytes);

  double _aspectForPreset(ExportPreset preset) {
    switch (preset) {
      case ExportPreset.story:
        return 9 / 16;
      case ExportPreset.post:
        return 1.0;
      case ExportPreset.wallpaper:
        return 9 / 16;
    }
  }

  String _fileNameForPreset(ExportPreset preset) {
    final ts = DateTime.now().millisecondsSinceEpoch;
    switch (preset) {
      case ExportPreset.story:
        return 'sofi_story_$ts.png';
      case ExportPreset.post:
        return 'sofi_post_$ts.png';
      case ExportPreset.wallpaper:
        return 'sofi_wallpaper_$ts.png';
    }
  }

  String _hashtagsForPlatform({
    required ExportPreset preset,
  }) {
    switch (preset) {
      case ExportPreset.story:
        // TikTok / Reels style: short + trending
        return '#SofiStudio #AIArt #FYP #Creative';

      case ExportPreset.post:
        // Instagram feed style: discoverable + clean
        return '#SofiStudio #AICreative #DigitalArt #ArtOfTheDay';

      case ExportPreset.wallpaper:
        return '#SofiStudio #Wallpaper';

      default:
        return '#SofiStudio';
    }
  }

  String _captionForPreset(ExportPreset preset) {
    final hashtags = _hashtagsForPlatform(preset: preset);

    switch (preset) {
      case ExportPreset.story:
        return '✨ Made with Sofi Studio\n$hashtags';

      case ExportPreset.post:
        return 'Created with Sofi Studio ✨\n\n$hashtags';

      case ExportPreset.wallpaper:
        return 'Wallpaper created with Sofi Studio ✨\n$hashtags';

      default:
        return 'Made with Sofi Studio\n$hashtags';
    }
  }

  Future<void> _exportWithPreset(
    ExportPreset preset, {
    bool share = false,
  }) async {
    if (styledBytes == null || _styledBytesOriginal == null) return;

    final aspect = _aspectForPreset(preset);

    final cropped = await _cropBytesToAspect(
      bytes: _styledBytesOriginal!,
      aspect: aspect,
      focusY: 0, // center focus by default
    );

    if (!mounted || cropped == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Export failed')),
      );
      return;
    }

    final fileName = _fileNameForPreset(preset);

    try {
      if (share) {
        // Share flow
        await SofiExportService.shareImage(
          context: context,
          imageUrl: await StorageService.instance
              .uploadTempBytesAndGetUrl(cropped, fileName),
          shareText: _captionForPreset(preset),
          fileName: fileName,
        );
      } else {
        // Save to Photos / Download
        await SofiExportService.saveImage(
          imageUrl: await StorageService.instance
              .uploadTempBytesAndGetUrl(cropped, fileName),
          fileName: fileName,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✓ Exported')),
      );
    } catch (e) {
      debugPrint('Export failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Export failed')),
      );
    }
  }

  Future<void> _batchExportStoryAndPost() async {
    if (styledBytes == null || _styledBytesOriginal == null) return;

    try {
      // STORY (9:16)
      final storyBytes = await _cropBytesToAspect(
        bytes: _styledBytesOriginal!,
        aspect: 9 / 16,
        focusY: 0,
      );

      // POST (1:1)
      final postBytes = await _cropBytesToAspect(
        bytes: _styledBytesOriginal!,
        aspect: 1.0,
        focusY: 0,
      );

      if (!mounted || storyBytes == null || postBytes == null) {
        throw Exception('Batch crop failed');
      }

      final ts = DateTime.now().millisecondsSinceEpoch;

      // Upload both (reuse your existing storage helper)
      final storyUrl = await StorageService.instance
          .uploadTempBytesAndGetUrl(storyBytes, 'sofi_story_$ts.png');

      final postUrl = await StorageService.instance
          .uploadTempBytesAndGetUrl(postBytes, 'sofi_post_$ts.png');

      // Save both
      await SofiExportService.saveImage(
        imageUrl: storyUrl,
        fileName: 'sofi_story_$ts.png',
      );

      await SofiExportService.saveImage(
        imageUrl: postUrl,
        fileName: 'sofi_post_$ts.png',
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✓ Story + Post exported')),
      );
    } catch (e) {
      debugPrint('Batch export failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Batch export failed')),
      );
    }
  }

  Future<void> _batchShareStoryAndPost() async {
    if (styledBytes == null || _styledBytesOriginal == null) return;

    try {
      // STORY (9:16)
      final storyBytes = await _cropBytesToAspect(
        bytes: _styledBytesOriginal!,
        aspect: 9 / 16,
        focusY: 0,
      );

      // POST (1:1)
      final postBytes = await _cropBytesToAspect(
        bytes: _styledBytesOriginal!,
        aspect: 1.0,
        focusY: 0,
      );

      if (!mounted || storyBytes == null || postBytes == null) {
        throw Exception('Batch crop failed');
      }

      final ts = DateTime.now().millisecondsSinceEpoch;

      // Upload temp files (reuse your existing helper)
      final storyUrl = await StorageService.instance
          .uploadTempBytesAndGetUrl(storyBytes, 'sofi_story_$ts.png');

      final postUrl = await StorageService.instance
          .uploadTempBytesAndGetUrl(postBytes, 'sofi_post_$ts.png');

      // Share both (mobile = files, web = links)
      await SofiExportService.shareImage(
        context: context,
        imageUrl: storyUrl,
        shareText: _captionForPreset(ExportPreset.story),
        fileName: 'sofi_story_$ts.png',
      );

      await SofiExportService.shareImage(
        context: context,
        imageUrl: postUrl,
        shareText: _captionForPreset(ExportPreset.post),
        fileName: 'sofi_post_$ts.png',
      );
    } catch (e) {
      debugPrint('Batch share failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Batch share failed')),
      );
    }
  }

  bool _isLockedTheme(ThemePreset t) => t.isPremium && !widget.isPremiumUser;

  @override
  void initState() {
    super.initState();
    _loadFavorites();

    // Load incoming headshot if provided
    if (widget.userHeadshotBase64 != null &&
        widget.userHeadshotBase64!.trim().isNotEmpty) {
      try {
        _userImageBytes = base64Decode(widget.userHeadshotBase64!);
        loadingIdentity = true;
        _runIdentityLock();
      } catch (_) {
        // ignore bad base64
      }
    }

    if (widget.initialTheme != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openThemeSheet(widget.initialTheme!);
      });
    }
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    favorites.addAll(prefs.getStringList(_favKey) ?? []);
    if (mounted) setState(() {});
  }

  Future<void> _saveFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_favKey, favorites.toList());
  }

  // ---------------- PROMPTS ----------------
  String _buildIdentityLockPrompt() {
    return buildCustomEditInstruction(
      'Transform this into a full-body fashion doll portrait. '
      'Show head-to-toe in a stylish pose with clean background. '
      'Keep the face identical to the original photo.',
    );
  }

  String _buildPrompt(ThemePreset t, ThemeVariant? v) {
    final custom = _promptController.text.trim();

    // Assemble the clean edit instruction
    final buffer = StringBuffer();
    buffer.writeln(t.basePrompt);
    if (v != null) buffer.writeln(v.prompt);
    if (custom.isNotEmpty) buffer.writeln('Custom user detail: $custom');

    final userIntent = buffer.toString().trim();

    // Use instruction-style prompt for flux-kontext-pro
    return buildCustomEditInstruction(userIntent);
  }

  // ---------------- STEP 1 ----------------

  Future<void> _runIdentityLock() async {
    if (_userImageBytes == null) return;

    try {
      final res = await widget.generationService.runStep1IdentityLock(
        _userImageBytes!,
        _buildIdentityLockPrompt(),
      );

      if (!mounted) return;
      setState(() {
        lockedBodyBytes = res;
        loadingIdentity = false;
        styledBytes = null;
        _styledBytesOriginal = null;
        _currentImageSaved = false;
      });
    } catch (e) {
      debugPrint('Identity Lock Failed: $e');
      if (!mounted) return;
      setState(() => loadingIdentity = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Failed to lock identity. Please try again.')),
      );
    }
  }

  // ---------------- UPLOAD ----------------

  Future<void> _uploadImage() async {
    final picker = ImagePicker();

    final selection = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        top: false,
        child: FractionallySizedBox(
          heightFactor: 0.9,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(
                  child: Text(
                    'Select Photo',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF333333)),
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.camera_alt_outlined,
                      color: Color(0xFF333333)),
                  title: const Text('Take Photo',
                      style: TextStyle(color: Color(0xFF333333))),
                  onTap: () => Navigator.pop(ctx, 0),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined,
                      color: Color(0xFF333333)),
                  title: const Text('Choose from Gallery',
                      style: TextStyle(color: Color(0xFF333333))),
                  onTap: () => Navigator.pop(ctx, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (selection == null) return;

    Uint8List? imageBytes;
    if (selection == 0) {
      final XFile? photo = await picker.pickImage(source: ImageSource.camera);
      if (photo != null) imageBytes = await photo.readAsBytes();
    } else {
      final XFile? photo = await picker.pickImage(source: ImageSource.gallery);
      if (photo != null) imageBytes = await photo.readAsBytes();
    }

    if (imageBytes == null) return;

    setState(() {
      _userImageBytes = imageBytes;
      loadingIdentity = true;
      lockedBodyBytes = null;
      styledBytes = null;
      _styledBytesOriginal = null;
      _currentImageSaved = false;
    });

    _runIdentityLock();
  }

  Widget _buildUploadPrompt() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final content = Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey[300]!, width: 2),
                ),
                child: Icon(Icons.person_add_alt_1_rounded,
                    size: 40, color: Colors.grey[500]),
              ),
              const SizedBox(height: 12),
              Text(
                'Upload Your Photo',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Take a selfie or choose from your gallery',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _uploadImage,
                    icon: const Icon(Icons.add_a_photo_rounded, size: 20),
                    label: const Text('Add Photo',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: const StadiumBorder(),
                    ),
                  ),
                ),
              ),
            ],
          );

          return constraints.maxHeight < 220
              ? SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Center(child: content),
                )
              : Center(child: content);
        },
      ),
    );
  }

  // ---------------- STEP 2 ----------------

  Future<void> _applySingleStyle() async {
    if (applyingStyle) return;
    if (selectedTheme == null) return;

    if (!mounted) return;
    setState(() => applyingStyle = true);

    try {
      // ------------------------------------------------------------
      // 🔒 IDENTITY ANCHOR (CRITICAL FIX)
      //
      // This identity source MUST NEVER CHANGE.
      // It is always derived from:
      // 1) original user image (preferred)
      // 2) or first locked identity image
      //
      // We NEVER use the current canvas or history image
      // as the identity input for generation.
      // ------------------------------------------------------------

      // If identity is not locked yet, lock it ONCE
      if (lockedBodyBytes == null) {
        if (_userImageBytes != null) {
          lockedBodyBytes = Uint8List.fromList(_userImageBytes!);
        } else if (styledBytes != null) {
          // Fallback: first generated image ONLY (one-time)
          lockedBodyBytes = Uint8List.fromList(styledBytes!);
        } else {
          throw Exception('No identity source available');
        }
      }

      // ------------------------------------------------------------
      // Build prompt (unchanged)
      // ------------------------------------------------------------
      final prompt = _buildPrompt(
        selectedTheme!,
        selectedVariant,
      );

      // ------------------------------------------------------------
      // 🚨 IMPORTANT:
      // We ALWAYS pass lockedBodyBytes as the identity image.
      // NEVER pass styledBytes or history images here.
      // ------------------------------------------------------------
      final result = await widget.generationService.generateStyledOnly(
        lockedBodyBytes!,
        prompt,
      );

      if (!mounted) return;

      // ------------------------------------------------------------
      // Update canvas & history
      // ------------------------------------------------------------
      final entry = _GenerationHistoryEntry(
        imageBytes: result,
        themeName: selectedTheme!.label,
        variantName: selectedVariant?.label,
        prompt: prompt,
        timestamp: DateTime.now(),
      );

      if (_historyIndex < _generationHistory.length - 1) {
        _generationHistory.removeRange(
            _historyIndex + 1, _generationHistory.length);
      }
      _generationHistory.add(entry);
      _historyIndex = _generationHistory.length - 1;

      if (!mounted) return;
      setState(() {
        styledBytes = result;
        _styledBytesOriginal = result;
        _currentImageSaved = false;
        _cropAspect = null;
        _cropFocus = 0;
      });
    } catch (e) {
      debugPrint('[Premium Studio] Apply style failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to apply style.')),
      );
    } finally {
      if (mounted) {
        setState(() => applyingStyle = false);
      }
    }
  }

  // ---------------- CROPPING ----------------

  Future<Uint8List?> _cropBytesToAspect({
    required Uint8List bytes,
    required double aspect,
    required double focusY,
  }) async {
    try {
      final ui.Codec codec = await ui.instantiateImageCodec(bytes);
      final ui.FrameInfo frame = await codec.getNextFrame();
      final ui.Image image = frame.image;

      final int imgW = image.width;
      final int imgH = image.height;

      final double imgAspect = imgW / imgH;
      double srcW, srcH;

      if (imgAspect > aspect) {
        srcH = imgH.toDouble();
        srcW = srcH * aspect;
      } else {
        srcW = imgW.toDouble();
        srcH = srcW / aspect;
      }

      final double dx = (imgW - srcW) / 2.0;
      final double maxDy = (imgH - srcH).toDouble();
      double dy = ((focusY + 1) / 2) * maxDy;
      dy = dy.clamp(0, maxDy);

      final ui.Rect srcRect = ui.Rect.fromLTWH(dx, dy, srcW, srcH);
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final ui.Canvas canvas = ui.Canvas(recorder);
      final ui.Rect dstRect = ui.Rect.fromLTWH(0, 0, srcW, srcH);

      canvas.drawImageRect(image, srcRect, dstRect, ui.Paint());
      final ui.Picture picture = recorder.endRecording();
      final ui.Image outImage =
          await picture.toImage(srcW.toInt(), srcH.toInt());
      final ByteData? pngBytes =
          await outImage.toByteData(format: ui.ImageByteFormat.png);
      if (pngBytes == null) return null;
      return pngBytes.buffer.asUint8List();
    } catch (e) {
      debugPrint('Crop failed: $e');
      return null;
    }
  }

  void _openCropSheet() {
    if (_styledBytesOriginal == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        double? tempAspect = _cropAspect;
        double tempFocus = _cropFocus;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            Widget buildPreview() {
              final imageWidget = Image.memory(
                _styledBytesOriginal!,
                fit: BoxFit.cover,
                alignment: Alignment(0, tempFocus.clamp(-1, 1)),
              );

              if (tempAspect == null) {
                return AspectRatio(
                  aspectRatio: 1,
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: SizedBox(width: 300, child: imageWidget),
                  ),
                );
              }

              return AspectRatio(
                aspectRatio: tempAspect!,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: imageWidget,
                ),
              );
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Refine Crop',
                          style: TextStyle(
                              color: Color(0xFF333333),
                              fontSize: 18,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(height: 240, child: Center(child: buildPreview())),
                  const SizedBox(height: 16),
                  const Text('Aspect Ratio',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, children: [
                    ChoiceChip(
                      label: const Text('Full'),
                      selected: tempAspect == null,
                      onSelected: (_) => setSheetState(() => tempAspect = null),
                    ),
                    ChoiceChip(
                      label: const Text('1:1'),
                      selected: tempAspect == 1.0,
                      onSelected: (_) => setSheetState(() => tempAspect = 1.0),
                    ),
                    ChoiceChip(
                      label: const Text('3:4'),
                      selected: tempAspect != null &&
                          (tempAspect! - 3 / 4).abs() < 0.0001,
                      onSelected: (_) =>
                          setSheetState(() => tempAspect = 3 / 4),
                    ),
                    ChoiceChip(
                      label: const Text('9:16'),
                      selected: tempAspect != null &&
                          (tempAspect! - 9 / 16).abs() < 0.0001,
                      onSelected: (_) =>
                          setSheetState(() => tempAspect = 9 / 16),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  const Text('Focus',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, children: [
                    ChoiceChip(
                      label: const Text('Top'),
                      selected: tempFocus <= -0.5,
                      onSelected: (_) => setSheetState(() => tempFocus = -1),
                    ),
                    ChoiceChip(
                      label: const Text('Center'),
                      selected: tempFocus > -0.5 && tempFocus < 0.5,
                      onSelected: (_) => setSheetState(() => tempFocus = 0),
                    ),
                    ChoiceChip(
                      label: const Text('Bottom'),
                      selected: tempFocus >= 0.5,
                      onSelected: (_) => setSheetState(() => tempFocus = 1),
                    ),
                  ]),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() {
                              styledBytes = _styledBytesOriginal;
                              _cropAspect = null;
                              _cropFocus = 0;
                              _currentImageSaved = false;
                            });
                            Navigator.pop(context);
                          },
                          child: const Text('Reset'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.crop),
                          label: const Text('Apply'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () async {
                            if (_styledBytesOriginal == null) return;

                            if (tempAspect == null) {
                              setState(() {
                                styledBytes = _styledBytesOriginal;
                                _cropAspect = null;
                                _cropFocus = tempFocus;
                                _currentImageSaved = false;
                              });
                              Navigator.pop(context);
                              return;
                            }

                            final cropped = await _cropBytesToAspect(
                              bytes: _styledBytesOriginal!,
                              aspect: tempAspect!,
                              focusY: tempFocus,
                            );

                            if (!mounted) return;
                            if (cropped == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Cropping failed.')),
                              );
                              return;
                            }

                            setState(() {
                              styledBytes = cropped;
                              _cropAspect = tempAspect;
                              _cropFocus = tempFocus;
                              _currentImageSaved = false;
                            });

                            Navigator.pop(context);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ---------------- FAVORITES / RESET ----------------

  void _toggleFavorite() async {
    if (selectedTheme == null) return;
    final key = '${selectedTheme!.id}:${selectedVariant?.id ?? 'base'}';
    if (favorites.contains(key)) {
      favorites.remove(key);
    } else {
      favorites.add(key);
    }
    await _saveFavorites();
    if (mounted) setState(() {});
  }

  void _resetIdentity() {
    if (!mounted) return;
    setState(() {
      _userImageBytes = null;
      lockedBodyBytes = null;
      styledBytes = null;
      _styledBytesOriginal = null;
      loadingIdentity = false;
      applyingStyle = false;
      _cropAspect = null;
      _cropFocus = 0;
      _currentImageSaved = false;
      selectedTheme = null;
      selectedVariant = null;
    });
  }

  Future<void> _saveToFavorites({bool makeAnother = false}) async {
    if (styledBytes == null || selectedTheme == null) return;

    if (!makeAnother && _currentImageSaved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Already saved!')),
      );
      return;
    }

    try {
      final compressed = await _compressFavoriteImage(styledBytes!);

      final newFavorite = FavoriteOutfit(
        imageBytes: compressed,
        prompt: _buildPrompt(selectedTheme!, selectedVariant),
        timestamp: DateTime.now(),
      );

      await FavoritesManager.addFavorite(newFavorite);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Saved to Favorites!'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.green,
        ),
      );

      if (makeAnother) {
        setState(() {
          styledBytes = null;
          _styledBytesOriginal = null;
          _cropAspect = null;
          _cropFocus = 0;
          _currentImageSaved = false;
        });
      } else {
        setState(() => _currentImageSaved = true);
      }
    } catch (e) {
      debugPrint('Failed to save favorite: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to save to favorites.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  // ---------------- HISTORY ----------------

  bool get _canUndo => _historyIndex > 0;
  bool get _canRedo =>
      _historyIndex >= 0 && _historyIndex < _generationHistory.length - 1;
  bool get _hasHistory => _generationHistory.isNotEmpty;

  void _undo() {
    if (!_canUndo) return;
    setState(() {
      _historyIndex--;
      final entry = _generationHistory[_historyIndex];
      styledBytes = entry.imageBytes;
      _styledBytesOriginal = entry.imageBytes;
      _cropAspect = null;
      _cropFocus = 0;
      _currentImageSaved = false;
    });
  }

  void _redo() {
    if (!_canRedo) return;
    setState(() {
      _historyIndex++;
      final entry = _generationHistory[_historyIndex];
      styledBytes = entry.imageBytes;
      _styledBytesOriginal = entry.imageBytes;
      _cropAspect = null;
      _cropFocus = 0;
      _currentImageSaved = false;
    });
  }

  void _restoreFromHistory(int index) {
    if (index < 0 || index >= _generationHistory.length) return;
    setState(() {
      _historyIndex = index;
      final entry = _generationHistory[index];
      styledBytes = entry.imageBytes;
      _styledBytesOriginal = entry.imageBytes;
      _cropAspect = null;
      _cropFocus = 0;
      _currentImageSaved = false;
    });
    Navigator.of(context).pop();
  }

  void _openHistorySheet() {
    if (_generationHistory.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No generation history yet')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PremiumHistorySheet(
        history: _generationHistory,
        currentIndex: _historyIndex,
        onSelect: _restoreFromHistory,
      ),
    );
  }

  // ---------------- THEME SHEET ----------------

  void _openThemeSheet(ThemePreset theme) {
    selectedTheme = theme;
    showAdvanced = false;
    batchEnabled = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final isFav = favorites.contains(
              '${theme.id}:${selectedVariant?.id ?? 'base'}',
            );

            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          theme.label,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF333333),
                              ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          isFav ? Icons.star : Icons.star_border,
                          color: isFav ? Colors.amber : Colors.grey,
                          size: 28,
                        ),
                        onPressed: () {
                          _toggleFavorite();
                          setSheetState(() {});
                        },
                      ),
                    ],
                  ),
                  Text(
                    theme.description,
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Choose a style',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF333333)),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      ChoiceChip(
                        label: const Text('Base'),
                        selected: selectedVariant == null,
                        onSelected: (_) =>
                            setSheetState(() => selectedVariant = null),
                      ),
                      ...theme.variants.map((v) {
                        return ChoiceChip(
                          label: Text(v.label),
                          selected: selectedVariant?.id == v.id,
                          onSelected: (_) =>
                              setSheetState(() => selectedVariant = v),
                        );
                      }),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: applyingStyle
                          ? null
                          : () {
                              Navigator.pop(context);
                              _applySingleStyle();
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                      child: const Text(
                        'Apply Style',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ======================= BUILD =======================

  @override
  Widget build(BuildContext context) {
    final bool isLoading = loadingIdentity || applyingStyle;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Premium Studio'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        actions: [
          if (!widget.isPremiumUser)
            GestureDetector(
              onTap: () => PaywallSheet.show(context),
              child: Container(
                margin: const EdgeInsets.only(right: 12),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star_rounded, color: Colors.white, size: 16),
                    SizedBox(width: 4),
                    Text(
                      'Upgrade',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (widget.isPremiumUser)
            Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
                ),
                borderRadius: BorderRadius.all(Radius.circular(16)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star_rounded, color: Colors.white, size: 16),
                  SizedBox(width: 4),
                  Text(
                    'Premium',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              Column(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        if (styledBytes == null)
                          _PromoCarousel(
                              onDiscoverThemeSelected: _openThemeSheet),
                        Expanded(
                          child: styledBytes == null
                              ? (_needsUpload
                                  ? Center(child: _buildUploadPrompt())
                                  : lockedBodyBytes != null
                                      ? Stack(
                                          children: [
                                            Positioned.fill(
                                              child: InteractiveViewer(
                                                minScale: 1.0,
                                                maxScale: 6.0,
                                                child: StageImage(
                                                  base64: _b64(lockedBodyBytes)!,
                                                  fit: BoxFit.contain,
                                                ),
                                              ),
                                            ),
                                            Positioned(
                                              top: 8,
                                              right: 8,
                                              child: FloatingActionButton.small(
                                                heroTag: 'change_photo_btn',
                                                onPressed: _resetIdentity,
                                                backgroundColor: Colors.white,
                                                foregroundColor: Colors.black,
                                                tooltip: 'Change Photo',
                                                child: const Icon(Icons.edit),
                                              ),
                                            ),
                                          ],
                                        )
                                      : const SizedBox.shrink())
                              : SizedBox.expand(
                                  child: InteractiveViewer(
                                    minScale: 1.0,
                                    maxScale: 6.0,
                                    child: StageImage(
                                      base64: _b64(styledBytes)!,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),

                  // Bottom Controls
                  Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(24)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 10,
                          offset: Offset(0, -2),
                        )
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (styledBytes != null)
                          _buildAfterGenerationPanel()
                        else
                          _buildBeforeGenerationPanel(),
                        SizedBox(height: MediaQuery.of(context).padding.bottom),
                      ],
                    ),
                  ),
                ],
              ),
              if (isLoading)
                Positioned.fill(
                  child: GenerationLoader(
                    historyImages: const [],
                    premiumAssetPaths: widget.premiumAssetPaths,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAfterGenerationPanel() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 260),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Row 1: Undo/Redo/History + Refine/Discard ──
            Row(
              children: [
                IconButton(
                  onPressed: _canUndo ? _undo : null,
                  icon: const Icon(Icons.undo_rounded, size: 20),
                  tooltip: 'Undo',
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  onPressed: _canRedo ? _redo : null,
                  icon: const Icon(Icons.redo_rounded, size: 20),
                  tooltip: 'Redo',
                  visualDensity: VisualDensity.compact,
                ),
                if (_hasHistory)
                  IconButton(
                    onPressed: _openHistorySheet,
                    icon: const Icon(Icons.history_rounded, size: 20),
                    tooltip: 'History',
                    visualDensity: VisualDensity.compact,
                  ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _openCropSheet,
                  icon: const Icon(Icons.crop, size: 16),
                  label: const Text('Refine', style: TextStyle(fontSize: 12)),
                ),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      styledBytes = null;
                      _styledBytesOriginal = null;
                      _cropAspect = null;
                      _cropFocus = 0;
                      _currentImageSaved = false;
                    });
                  },
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text('Discard', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red[400],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // ── Row 2: Save + Save & New ──
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _saveToFavorites(makeAnother: false),
                    icon: Icon(
                      _currentImageSaved ? Icons.favorite : Icons.favorite_border,
                      size: 16,
                    ),
                    label: Text(
                      _currentImageSaved ? 'Saved' : 'Save',
                      style: const TextStyle(fontSize: 13),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: const BorderSide(color: Colors.pink),
                      foregroundColor: Colors.pink,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _saveToFavorites(makeAnother: true),
                    icon: const Icon(Icons.add_photo_alternate, size: 16),
                    label: const Text('Save & New', style: TextStyle(fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // ── Row 3: Send to Studio (full width) ──
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  if (styledBytes == null) return;
                  final prompt = (selectedTheme == null)
                      ? ''
                      : _buildPrompt(selectedTheme!, selectedVariant);

                  Navigator.pop(context, <String, String>{
                    'image': _b64(styledBytes)!,
                    'prompt': prompt,
                  });
                },
                icon: const Icon(Icons.send, size: 16),
                label: const Text('Send to Studio'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // ── Row 4: Export & Share (compact row) ──
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _exportWithPreset(ExportPreset.story),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    child: const Text('Story', style: TextStyle(fontSize: 11)),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _exportWithPreset(ExportPreset.post),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    child: const Text('Post', style: TextStyle(fontSize: 11)),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _exportWithPreset(ExportPreset.wallpaper),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    child: const Text('Wallpaper', style: TextStyle(fontSize: 11)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // ── Row 5: Batch export + Share ──
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _batchExportStoryAndPost,
                    icon: const Icon(Icons.download_rounded, size: 14),
                    label: const Text('Export Story + Post',
                        style: TextStyle(fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ShareHubPage(
                            imageBase64: _b64(styledBytes),
                            prompt:
                                selectedVariant?.prompt ?? selectedTheme?.label,
                            isPremiumImage: true,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.share_rounded, size: 14),
                    label: const Text('Share',
                        style: TextStyle(fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBeforeGenerationPanel() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Custom prompt pill
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Row(
              children: [
                const Padding(
                  padding: EdgeInsets.only(left: 16),
                  child: Icon(Icons.auto_awesome, color: Colors.purple),
                ),
                Expanded(
                  child: TextField(
                    controller: _promptController,
                    decoration: const InputDecoration(
                      hintText: 'Add custom style instructions...',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.mic),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content:
                              Text('Voice input not enabled in this demo')),
                    );
                  },
                ),
              ],
            ),
          ),
        ),

        // Theme strip
        Container(
          height: 140,
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: themePresets.length,
            itemBuilder: (_, i) {
              final t = themePresets[i];
              final bool locked = _isLockedTheme(t);

              return GestureDetector(
                onTap: (loadingIdentity || applyingStyle)
                    ? null
                    : () => _openThemeSheet(t),
                child: Container(
                  width: 90,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: Colors.grey[900],
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.10),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      )
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (t.assetPath != null)
                        _FirebaseImage(
                          path: t.assetPath!,
                          fit: BoxFit.cover,
                          fallback: Container(
                            color: Colors.amber,
                            child: const Icon(Icons.broken_image,
                                color: Colors.black54),
                          ),
                        )
                      else
                        Container(
                          color: Colors.amber,
                          child:
                              const Icon(Icons.person, color: Colors.black54),
                        ),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 6, horizontal: 4),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.9),
                              ],
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (locked)
                                const Icon(Icons.lock,
                                    size: 12, color: Colors.amber),
                              Text(
                                t.label,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
} // end _PremiumStudioPageState

// ======================= PROMO CAROUSEL =======================

class _PromoCarousel extends StatefulWidget {
  final void Function(ThemePreset theme)? onDiscoverThemeSelected;

  const _PromoCarousel({this.onDiscoverThemeSelected});

  @override
  State<_PromoCarousel> createState() => _PromoCarouselState();
}

class _PromoCarouselState extends State<_PromoCarousel> {
  late final PageController _pageController;
  Timer? _timer;
  int _currentPage = 0;

  static const _promoItems = [
    _PromoItem(
      title: 'Share Your Creations',
      subtitle: 'Show off your style on social media',
      icon: Icons.share_rounded,
      gradient: [Color(0xFF667eea), Color(0xFF764ba2)],
      action: 'Share Now',
    ),
    _PromoItem(
      title: 'Sofi Music',
      subtitle: 'Listen while you create amazing looks',
      icon: Icons.music_note_rounded,
      gradient: [Color(0xFFf093fb), Color(0xFFf5576c)],
      action: 'Listen Now',
    ),
    _PromoItem(
      title: 'Discover Styles',
      subtitle: 'Explore trending fashion from the community',
      icon: Icons.explore_rounded,
      gradient: [Color(0xFF4facfe), Color(0xFF00f2fe)],
      action: 'Explore',
    ),
    _PromoItem(
      title: 'Your Favorites',
      subtitle: 'Access your saved styles and looks',
      icon: Icons.favorite_rounded,
      gradient: [Color(0xFFfa709a), Color(0xFFfee140)],
      action: 'View All',
    ),
    _PromoItem(
      title: 'Go Premium',
      subtitle: 'Unlock exclusive styles and more',
      icon: Icons.star_rounded,
      gradient: [Color(0xFFffd700), Color(0xFFff8c00)],
      action: 'Upgrade',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.92);

    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      final nextPage = (_currentPage + 1) % _promoItems.length;
      _pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _onPromoTap(BuildContext context, int index) {
    switch (index) {
      case 0:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ShareHubPage()),
        );
        break;
      case 1:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SofiMusicPage()),
        );
        break;
      case 2:
        Navigator.of(context)
            .push<ThemePreset>(
          MaterialPageRoute(
            builder: (_) => DiscoverPage(
              onThemeSelected: (theme) => Navigator.of(context).pop(theme),
              onStyleSelected: (_) => Navigator.of(context).pop(),
            ),
          ),
        )
            .then((selectedTheme) {
          if (selectedTheme != null && mounted) {
            widget.onDiscoverThemeSelected?.call(selectedTheme);
          }
        });
        break;
      case 3:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const FavoritesHubPage()),
        );
        break;
      case 4:
        PaywallSheet.show(context);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      width: double.infinity,
      color: Colors.grey[100],
      child: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (page) => setState(() => _currentPage = page),
              itemCount: _promoItems.length,
              itemBuilder: (context, index) {
                final item = _promoItems[index];
                return GestureDetector(
                  onTap: () => _onPromoTap(context, index),
                  child: Container(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: item.gradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: item.gradient.first.withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          right: -20,
                          bottom: -20,
                          child: Icon(
                            item.icon,
                            size: 120,
                            color: Colors.white.withOpacity(0.15),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      item.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      item.subtitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.9),
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Text(
                                        item.action,
                                        style: TextStyle(
                                          color: item.gradient.first,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(
                                  item.icon,
                                  color: Colors.white,
                                  size: 26,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_promoItems.length, (index) {
                final isActive = index == _currentPage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: isActive ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isActive ? Colors.grey[800] : Colors.grey[400],
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _PromoItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> gradient;
  final String action;

  const _PromoItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.action,
  });
}

// ======================= HISTORY MODELS + SHEET =======================

class _GenerationHistoryEntry {
  final Uint8List imageBytes;
  final String themeName;
  final String? variantName;
  final String prompt;
  final DateTime timestamp;

  _GenerationHistoryEntry({
    required this.imageBytes,
    required this.themeName,
    this.variantName,
    required this.prompt,
    required this.timestamp,
  });
}

class _PremiumHistorySheet extends StatelessWidget {
  final List<_GenerationHistoryEntry> history;
  final int currentIndex;
  final void Function(int index) onSelect;

  const _PremiumHistorySheet({
    required this.history,
    required this.currentIndex,
    required this.onSelect,
  });

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.55,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2D1B4E), Color(0xFF1A1A2E)],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.history_rounded,
                      color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Generation History',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${history.length} looks created this session',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: Colors.white54),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.65,
              ),
              itemCount: history.length,
              itemBuilder: (ctx, index) {
                final reversedIndex = history.length - 1 - index;
                final entry = history[reversedIndex];
                final isCurrent = reversedIndex == currentIndex;

                return GestureDetector(
                  onTap: () => onSelect(reversedIndex),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isCurrent ? Colors.purple : Colors.transparent,
                        width: isCurrent ? 3 : 0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(isCurrent ? 13 : 16),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.memory(entry.imageBytes, fit: BoxFit.cover),
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withOpacity(0.85),
                                  ],
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    entry.themeName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (entry.variantName != null)
                                    Text(
                                      entry.variantName!,
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.7),
                                        fontSize: 11,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _formatTime(entry.timestamp),
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.5),
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (isCurrent)
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.purple,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'Current',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ======================= FIREBASE IMAGE HELPER =======================

class _FirebaseImage extends StatefulWidget {
  final String path;
  final BoxFit fit;
  final Widget? fallback;

  const _FirebaseImage({
    required this.path,
    this.fit = BoxFit.cover,
    this.fallback,
  });

  @override
  State<_FirebaseImage> createState() => _FirebaseImageState();
}

class _FirebaseImageState extends State<_FirebaseImage> {
  String? _url;
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(_FirebaseImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.path != oldWidget.path) _loadImage();
  }

  Future<void> _loadImage() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = false;
    });

    try {
      final url = await StorageService.instance.getDownloadUrlSafe(widget.path);
      if (!mounted) return;
      setState(() {
        _url = url;
        _error = (url == null);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = true);
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        color: Colors.grey[200],
        child: const Center(
          child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    }

    if (_error || _url == null) {
      return widget.fallback ??
          const Center(child: Icon(Icons.broken_image, size: 18));
    }

    return Image.network(
      _url!,
      fit: widget.fit,
      errorBuilder: (_, __, ___) =>
          widget.fallback ?? const Center(child: Icon(Icons.broken_image)),
    );
  }
}
