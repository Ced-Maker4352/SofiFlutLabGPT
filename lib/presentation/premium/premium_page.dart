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
import 'package:sofi_test_connect/presentation/shared/stage_image.dart';
import 'package:sofi_test_connect/presentation/sofi_studio/widgets/generation_loader.dart';
import 'package:sofi_test_connect/presentation/sofi_studio/favorites_manager.dart';
import 'package:sofi_test_connect/presentation/sofi_studio/models/favorite_outfit.dart';
import 'package:sofi_test_connect/presentation/premium/sofi_music_page.dart';
import 'package:sofi_test_connect/presentation/premium/share_hub_page.dart';
import 'package:sofi_test_connect/presentation/premium/favorites_hub_page.dart';
import 'package:sofi_test_connect/presentation/premium/discover_page.dart';
import 'package:sofi_test_connect/services/storage_service.dart';
import 'package:sofi_test_connect/services/premium_service.dart';
import 'package:sofi_test_connect/presentation/premium/paywall_sheet.dart';

class PremiumStudioPage extends StatefulWidget {
/// If null, user can upload from within Premium page
final String? userHeadshotBase64;
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

/// Compress + downscale favorite images so they fit inside web localStorage limits.
Future<Uint8List> _compressFavoriteImage(Uint8List bytes) async {
return compute(_compressFavoriteImageIsolate, bytes);
}

Uint8List _compressFavoriteImageIsolate(Uint8List bytes) {
final decoded = img.decodeImage(bytes);
if (decoded == null) return bytes;

const int maxDim = 900; // keep reasonably sharp while trimming size
final resized = img.copyResize(
decoded,
width: decoded.width >= decoded.height ? maxDim : null,
height: decoded.height > decoded.width ? maxDim : null,
interpolation: img.Interpolation.average,
);

final jpg = img.encodeJpg(resized, quality: 72);
return Uint8List.fromList(jpg);
}

class _PremiumStudioPageState extends State<PremiumStudioPage> {
// User's source image
String? _userImageBase64;

// STEP-1
bool loadingIdentity = false;
String? lockedBodyBase64;

// STEP-2
bool applyingStyle = false;
String? styledImage;
String? _styledImageOriginal; // keeps original to allow re-cropping

ThemePreset? selectedTheme;
ThemeVariant? selectedVariant;

// History / Undo-Redo
final List<_GenerationHistoryEntry> _generationHistory = [];
int _historyIndex = -1; // -1 means no history yet

// Custom Prompt
final TextEditingController _promptController = TextEditingController();

// Favorites
static const _favKey = 'favorite_styles_v1';
final Set<String> favorites = {};

// Current generation saved state
bool _currentImageSaved = false;

// Advanced / Batch
bool showAdvanced = false;
bool batchEnabled = false;
int batchCount = 4;
bool mixVariants = true;

// Premium Service
final PremiumService _premiumService = PremiumService();

/// Whether user needs to upload an image (came in with no image)
bool get _needsUpload => _userImageBase64 == null && lockedBodyBase64 == null;

@override
void initState() {
super.initState();
_loadFavorites();
_initPremiumService();
_userImageBase64 = widget.userHeadshotBase64;
if (_userImageBase64 != null) {
loadingIdentity = true;
_runIdentityLock();
}
// Auto-open theme sheet if initial theme provided
if (widget.initialTheme != null) {
WidgetsBinding.instance.addPostFrameCallback((_) {
if (mounted) _openThemeSheet(widget.initialTheme!);
});
}
}

Future<void> _initPremiumService() async {
await _premiumService.initialize();
_premiumService.addListener(_onPremiumChanged);
if (mounted) setState(() {});
}

void _onPremiumChanged() {
if (mounted) setState(() {});
}

@override
void dispose() {
_premiumService.removeListener(_onPremiumChanged);
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

Future<void> _runIdentityLock() async {
if (_userImageBase64 == null) return;
try {
final res = await widget.generationService.runStep1IdentityLock(
userHeadshotBase64: _userImageBase64!,
);
if (!mounted) return;
setState(() {
lockedBodyBase64 = res.step1FullBodyBase64;
loadingIdentity = false;
});
} catch (e) {
debugPrint('Identity Lock Failed: $e');
if (mounted) {
setState(() => loadingIdentity = false);
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(content: Text('Failed to lock identity. Please try again.')),
);
}
}
}

Future<void> _uploadImage() async {
final picker = ImagePicker();
// Show option dialog
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
                  child: Text('Select Photo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.camera_alt_outlined, color: Colors.black),
                          title: const Text('Take Photo'),
                          onTap: () => Navigator.pop(ctx, 0),
                        ),
                        ListTile(
                          leading: const Icon(Icons.photo_library_outlined, color: Colors.black),
                          title: const Text('Choose from Gallery'),
                          onTap: () => Navigator.pop(ctx, 1),
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
_userImageBase64 = base64Encode(imageBytes!);
loadingIdentity = true;
});
_runIdentityLock();
}

bool _isLockedTheme(ThemePreset t) =>
t.isPremium && !widget.isPremiumUser;

String _buildPrompt(ThemePreset t, ThemeVariant? v) {
final custom = _promptController.text.trim();
return '''
${t.basePrompt}
${v?.prompt ?? ''}
${custom.isNotEmpty ? 'User instruction: $custom' : ''}
Preserve pose, proportions, full-body framing.
Ensure character is fully clothed (pants, skirt, or dress) and wearing shoes.
Modest, child-friendly outfit.
Do not crop or zoom.
''';
}

Future<void> _applySingleStyle() async {
if (selectedTheme == null || lockedBodyBase64 == null) return;

if (_isLockedTheme(selectedTheme!)) {
_showPremiumDialog();
return;
}

// Check daily limit for free users
if (!_premiumService.canGenerate) {
final subscribed = await PaywallSheet.show(
context,
message: 'You\'ve used all ${PremiumService.freeUserDailyLimit} free generations today. Subscribe for unlimited access!',
);
if (subscribed != true) return;
}

setState(() => applyingStyle = true);

try {
final prompt = _buildPrompt(selectedTheme!, selectedVariant);
final result = await widget.generationService.generateStyledOnly(
base64Image: lockedBodyBase64!,
prompt: prompt,
);

if (mounted) {
// Record the generation for daily limit tracking
await _premiumService.recordGeneration();

// Add to history
final historyEntry = _GenerationHistoryEntry(
imageBase64: result,
themeName: selectedTheme!.label,
variantName: selectedVariant?.label,
prompt: prompt,
timestamp: DateTime.now(),
);

// Remove any forward history if we were in the middle of history
if (_historyIndex < _generationHistory.length - 1) {
_generationHistory.removeRange(_historyIndex + 1, _generationHistory.length);
}

_generationHistory.add(historyEntry);
_historyIndex = _generationHistory.length - 1;

setState(() {
styledImage = result;
_styledImageOriginal = result;
applyingStyle = false;
_currentImageSaved = false;
});
}
} catch (e) {
debugPrint('Style Gen Failed: $e');
if (mounted) {
setState(() => applyingStyle = false);
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(content: Text('Failed to apply style.')),
);
}
}
}

// ---- CROPPING HELPERS ----
double? _cropAspect; // null = full (no crop), else width/height
double _cropFocus = 0; // -1 top, 0 center, 1 bottom

Future<String?> _cropBase64ToAspect({required String base64Image, required double aspect, required double focusY}) async {
try {
final Uint8List bytes = base64Decode(base64Image);
final ui.Codec codec = await ui.instantiateImageCodec(bytes);
final ui.FrameInfo frame = await codec.getNextFrame();
final ui.Image image = frame.image;

final int imgW = image.width;
final int imgH = image.height;

final double imgAspect = imgW / imgH;
double srcW, srcH;
if (imgAspect > aspect) {
// too wide -> crop width
srcH = imgH.toDouble();
srcW = srcH * aspect;
} else {
// too tall -> crop height
srcW = imgW.toDouble();
srcH = srcW / aspect;
}

final double dx = (imgW - srcW) / 2.0;
double dy;
final double maxDy = (imgH - srcH).toDouble();
// Map focusY [-1..1] to [0..maxDy]
dy = ((focusY + 1) / 2) * maxDy;
if (dy < 0) dy = 0;
if (dy > maxDy) dy = maxDy;

final ui.Rect srcRect = ui.Rect.fromLTWH(dx, dy, srcW, srcH);
final ui.PictureRecorder recorder = ui.PictureRecorder();
final ui.Canvas canvas = ui.Canvas(recorder);
final ui.Rect dstRect = ui.Rect.fromLTWH(0, 0, srcW, srcH);
final ui.Paint paint = ui.Paint();
canvas.drawImageRect(image, srcRect, dstRect, paint);
final ui.Picture picture = recorder.endRecording();
final ui.Image outImage = await picture.toImage(srcW.toInt(), srcH.toInt());
final ByteData? pngBytes = await outImage.toByteData(format: ui.ImageByteFormat.png);
if (pngBytes == null) return null;
return base64Encode(pngBytes.buffer.asUint8List());
} catch (e) {
debugPrint('Crop failed: $e');
return null;
}
}

void _openCropSheet() {
if (_styledImageOriginal == null) return;
showModalBottomSheet(
context: context,
isScrollControlled: true,
backgroundColor: Colors.white,
shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
builder: (_) {
double? tempAspect = _cropAspect; // working copy
double tempFocus = _cropFocus;
return StatefulBuilder(
builder: (context, setSheetState) {
Widget buildPreview() {
// For preview, simulate crop via FittedBox and ClipRect
final imageWidget = Image.memory(
base64Decode(_styledImageOriginal!),
fit: BoxFit.cover,
alignment: Alignment(0, tempFocus.clamp(-1, 1)),
);
if (tempAspect == null) {
return AspectRatio(
aspectRatio: 1,
child: FittedBox(
fit: BoxFit.contain,
child: SizedBox(
width: 300,
child: imageWidget,
),
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
Row(
children: const [
Expanded(
child: Text('Refine Crop', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
),
],
),
const SizedBox(height: 12),
SizedBox(height: 240, child: Center(child: buildPreview())),
const SizedBox(height: 16),
const Text('Aspect Ratio', style: TextStyle(fontWeight: FontWeight.w600)),
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
selected: tempAspect != null && (tempAspect! - 3 / 4).abs() < 0.0001,
onSelected: (_) => setSheetState(() => tempAspect = 3 / 4),
),
ChoiceChip(
label: const Text('9:16'),
selected: tempAspect != null && (tempAspect! - 9 / 16).abs() < 0.0001,
onSelected: (_) => setSheetState(() => tempAspect = 9 / 16),
),
]),
const SizedBox(height: 16),
const Text('Focus', style: TextStyle(fontWeight: FontWeight.w600)),
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
Row(children: [
Expanded(
child: OutlinedButton(
onPressed: () {
// Reset to original
setState(() {
styledImage = _styledImageOriginal;
_cropAspect = null;
_cropFocus = 0;
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
shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
),
onPressed: () async {
if (tempAspect == null) {
// No crop, just keep original
setState(() {
styledImage = _styledImageOriginal;
_cropAspect = null;
_cropFocus = tempFocus;
});
Navigator.pop(context);
return;
}
final cropped = await _cropBase64ToAspect(
base64Image: _styledImageOriginal!,
aspect: tempAspect!,
focusY: tempFocus,
);
if (!mounted) return;
if (cropped == null) {
ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cropping failed.')));
return;
}
setState(() {
styledImage = cropped;
_cropAspect = tempAspect;
_cropFocus = tempFocus;
});
Navigator.pop(context);
},
),
),
])
],
),
);
},
);
},
);
}

  Widget _buildUploadPrompt() {
    // Make this section resilient on very short screens by allowing scroll.
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
                child: Icon(Icons.person_add_alt_1_rounded, size: 40, color: Colors.grey[500]),
              ),
              const SizedBox(height: 12),
              Text(
                'Upload Your Photo',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey[800]),
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
                    label: const Text('Add Photo', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
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
          // If the available height is small, let the content scroll
          return constraints.maxHeight < 220
              ? SingleChildScrollView(physics: const BouncingScrollPhysics(), child: Center(child: content))
              : Center(child: content);
        },
      ),
    );
  }

void _toggleFavorite() async {
if (selectedTheme == null) return;
final key =
'${selectedTheme!.id}:${selectedVariant?.id ?? 'base'}';
if (favorites.contains(key)) {
favorites.remove(key);
} else {
favorites.add(key);
}
await _saveFavorites();
setState(() {});
}

void _resetIdentity() {
setState(() {
_userImageBase64 = null;
lockedBodyBase64 = null;
styledImage = null;
_styledImageOriginal = null;
loadingIdentity = false;
});
}

/// Save current styled image to favorites and optionally continue making more
Future<void> _saveToFavorites({bool makeAnother = false}) async {
if (styledImage == null) return;

if (!makeAnother && _currentImageSaved) {
ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Already saved!')));
return;
}

try {
final compressedBytes = await _compressFavoriteImage(base64Decode(styledImage!));
final newFavorite = FavoriteOutfit(
imageBytes: compressedBytes,
prompt: _buildPrompt(selectedTheme!, selectedVariant),
timestamp: DateTime.now(),
);

// Use efficient single-add
await FavoritesManager.addFavorite(newFavorite);

if (mounted) {
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(
content: Text('✓ Saved to Favorites!'),
duration: Duration(seconds: 2),
backgroundColor: Colors.green,
),
);

if (makeAnother) {
// Clear styled image but keep identity locked
setState(() {
styledImage = null;
_styledImageOriginal = null;
_cropAspect = null;
_cropFocus = 0;
_currentImageSaved = false;
});
} else {
setState(() => _currentImageSaved = true);
}
}
} catch (e) {
debugPrint('Failed to save favorite: $e');
if (mounted) {
ScaffoldMessenger.of(context).showSnackBar(
SnackBar(
content: Text('Failed to save${e.toString().contains('Quota') ? ': storage full, removed older items' : ''}'),
backgroundColor: Colors.redAccent,
),
);
}
}
}

// ---- HISTORY / UNDO-REDO ----
bool get _canUndo => _historyIndex > 0;
bool get _canRedo => _historyIndex < _generationHistory.length - 1;
bool get _hasHistory => _generationHistory.isNotEmpty;

void _undo() {
if (!_canUndo) return;
setState(() {
_historyIndex--;
final entry = _generationHistory[_historyIndex];
styledImage = entry.imageBase64;
_styledImageOriginal = entry.imageBase64;
_cropAspect = null;
_cropFocus = 0;
_currentImageSaved = false; // Reset on undo
});
}

void _redo() {
if (!_canRedo) return;
setState(() {
_historyIndex++;
final entry = _generationHistory[_historyIndex];
styledImage = entry.imageBase64;
_styledImageOriginal = entry.imageBase64;
_cropAspect = null;
_cropFocus = 0;
_currentImageSaved = false; // Reset on redo
});
}

void _restoreFromHistory(int index) {
if (index < 0 || index >= _generationHistory.length) return;
setState(() {
_historyIndex = index;
final entry = _generationHistory[index];
styledImage = entry.imageBase64;
_styledImageOriginal = entry.imageBase64;
_cropAspect = null;
_cropFocus = 0;
_currentImageSaved = false; // Reset on restore
});
Navigator.of(context).pop(); // Close history sheet
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

void _showPremiumDialog() {
showDialog(
context: context,
builder: (_) => AlertDialog(
title: const Text('Premium Theme'),
content: const Text(
'This style is part of a premium theme pack.',
),
actions: [
TextButton(
onPressed: () => Navigator.pop(context),
child: const Text('Not now'),
),
ElevatedButton(
onPressed: () => Navigator.pop(context),
child: const Text('Unlock Premium'),
),
],
),
);
}

void _openThemeSheet(ThemePreset theme) {
selectedTheme = theme;
// Keep selectedVariant null unless we want to remember last choice
// selectedVariant = null;
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
// HEADER
Row(
children: [
Expanded(
child: Text(
theme.label,
style: Theme.of(context)
.textTheme
.headlineSmall
?.copyWith(fontWeight: FontWeight.bold),
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

// STYLE SELECTION
const Text(
'Choose a style',
style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
),
const SizedBox(height: 12),

Wrap(
spacing: 10,
runSpacing: 10,
children: [
ChoiceChip(
label: const Text('Base'),
selected: selectedVariant == null,
onSelected: (_) {
setSheetState(() => selectedVariant = null);
},
),
...theme.variants.map((v) {
return ChoiceChip(
label: Text(v.label),
selected: selectedVariant?.id == v.id,
onSelected: (_) {
setSheetState(() => selectedVariant = v);
},
);
}),
],
),

const SizedBox(height: 24),

// APPLY STYLE
SizedBox(
width: double.infinity,
height: 56,
child: ElevatedButton(
onPressed: applyingStyle
? null
: () {
Navigator.pop(context); // Close sheet then apply
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
style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
),
),
),

const SizedBox(height: 16),

// ADVANCED OPTIONS
InkWell(
onTap: () {
setSheetState(() => showAdvanced = !showAdvanced);
},
borderRadius: BorderRadius.circular(8),
child: Padding(
padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4),
child: Row(
children: [
Text(
'Advanced Options',
style: TextStyle(
fontWeight: FontWeight.w600,
color: Theme.of(context).primaryColor,
),
),
const Spacer(),
Icon(
showAdvanced ? Icons.expand_less : Icons.expand_more,
color: Theme.of(context).primaryColor,
),
],
),
),
),

if (showAdvanced) ...[
const SizedBox(height: 12),
Container(
padding: const EdgeInsets.all(16),
decoration: BoxDecoration(
color: Colors.grey[50],
borderRadius: BorderRadius.circular(16),
border: Border.all(color: Colors.grey[200]!),
),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
const Text(
'Batch Generation',
style: TextStyle(fontWeight: FontWeight.bold),
),
const Text(
'Generate multiple variations at once',
style: TextStyle(fontSize: 12, color: Colors.grey),
),
SwitchListTile(
contentPadding: EdgeInsets.zero,
title: const Text('Enable Batch'),
value: batchEnabled,
onChanged: (v) {
setSheetState(() => batchEnabled = v);
},
),
if (batchEnabled) ...[
DropdownButtonFormField<int>(
value: batchCount,
items: const [
DropdownMenuItem(value: 4, child: Text('4 looks')),
DropdownMenuItem(value: 6, child: Text('6 looks')),
DropdownMenuItem(value: 9, child: Text('9 looks')),
DropdownMenuItem(value: 12, child: Text('12 looks')),
],
onChanged: (v) {
if (v != null) {
setSheetState(() => batchCount = v);
}
},
decoration: const InputDecoration(
labelText: 'How many looks?',
border: OutlineInputBorder(),
),
),
const SizedBox(height: 8),
SwitchListTile(
contentPadding: EdgeInsets.zero,
title: const Text('Mix variants automatically'),
value: mixVariants,
onChanged: (v) {
setSheetState(() => mixVariants = v);
},
),
],
],
),
),
],
const SizedBox(height: 16),
],
),
);
},
);
},
);
}

@override
Widget build(BuildContext context) {
// Show spinner if loading identity or applying style
final bool isLoading = loadingIdentity || applyingStyle;

return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Premium Studio'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        actions: [
          // Daily generations indicator (for free users)
          if (!_premiumService.isPremium && _premiumService.isInitialized)
            GestureDetector(
              onTap: () => PaywallSheet.show(context),
              child: Container(
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: _premiumService.dailyGenerationsRemaining > 0
                      ? LinearGradient(
                          colors: [Colors.purple.shade400, Colors.purple.shade600],
                        )
                      : const LinearGradient(
                          colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
                        ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _premiumService.dailyGenerationsRemaining > 0
                          ? Icons.auto_awesome
                          : Icons.star_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _premiumService.dailyGenerationsRemaining > 0
                          ? '${_premiumService.dailyGenerationsRemaining} left'
                          : 'Upgrade',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // Premium badge (for premium users)
          if (_premiumService.isPremium)
            Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
              // Main Content (no outer scroll to avoid Expanded + unbounded height conflict)
              Column(
                children: [
                  // Canvas Area with Promo Carousel above
                  Expanded(
                    child: styledImage == null
                        ? Column(
                            children: [
                              // Promo Carousel fills available space above canvas
                              _PromoCarousel(
                                onDiscoverThemeSelected: _openThemeSheet,
                              ),
                              // Canvas Area or Upload Prompt
                              Expanded(
                                child: Center(
                                  child: _needsUpload
                                      ? _buildUploadPrompt()
                                      : lockedBodyBase64 != null
                                          ? Padding(
                                              padding: const EdgeInsets.all(16.0),
                                              child: Stack(
                                                alignment: Alignment.topRight,
                                                children: [
                                                  StageImage(
                                                    base64: lockedBodyBase64!,
                                                  ),
                                                  Padding(
                                                    padding: const EdgeInsets.all(8.0),
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
                                              ),
                                            )
                                          : const SizedBox.shrink(),
                                ),
                              ),
                            ],
                          )
                        : Center(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: StageImage(
                                base64: styledImage!,
                              ),
                            ),
                          ),
                  ),

                  // Bottom Controls
                  Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                        // Post-Generation Controls OR Custom Prompt
                        if (styledImage != null)
                          Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Top row: Undo/Redo + History + Crop + Discard
                                Row(
                                  children: [
                                    // Undo button
                                    IconButton(
                                      onPressed: _canUndo ? _undo : null,
                                      icon: const Icon(Icons.undo_rounded, size: 20),
                                      tooltip: 'Undo',
                                      style: IconButton.styleFrom(
                                        foregroundColor: _canUndo ? Colors.purple : Colors.grey[400],
                                        backgroundColor: _canUndo ? Colors.purple.withValues(alpha: 0.1) : null,
                                      ),
                                    ),
                                    // Redo button
                                    IconButton(
                                      onPressed: _canRedo ? _redo : null,
                                      icon: const Icon(Icons.redo_rounded, size: 20),
                                      tooltip: 'Redo',
                                      style: IconButton.styleFrom(
                                        foregroundColor: _canRedo ? Colors.purple : Colors.grey[400],
                                        backgroundColor: _canRedo ? Colors.purple.withValues(alpha: 0.1) : null,
                                      ),
                                    ),
                                    // History button with count badge
                                    if (_hasHistory)
                                      Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          IconButton(
                                            onPressed: _openHistorySheet,
                                            icon: const Icon(Icons.history_rounded, size: 20),
                                            tooltip: 'History',
                                            style: IconButton.styleFrom(
                                              foregroundColor: Colors.purple,
                                              backgroundColor: Colors.purple.withValues(alpha: 0.1),
                                            ),
                                          ),
                                          Positioned(
                                            top: 4,
                                            right: 4,
                                            child: Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: const BoxDecoration(
                                                color: Colors.purple,
                                                shape: BoxShape.circle,
                                              ),
                                              child: Text(
                                                '${_generationHistory.length}',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    const Spacer(),
                                    TextButton.icon(
                                      onPressed: _openCropSheet,
                                      icon: const Icon(Icons.crop, size: 18),
                                      label: const Text('Refine'),
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.grey[700],
                                      ),
                                    ),
                                    TextButton.icon(
                                      onPressed: () {
                                        setState(() {
                                          styledImage = null;
                                          _styledImageOriginal = null;
                                          _cropAspect = null;
                                          _cropFocus = 0;
                                        });
                                      },
                                      icon: const Icon(Icons.delete_outline, size: 18),
                                      label: const Text('Discard'),
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.red[400],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                // Main action row: Save + Make Another
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () => _saveToFavorites(makeAnother: false),
                                        icon: Icon(_currentImageSaved ? Icons.favorite : Icons.favorite_border),
                                        label: Text(_currentImageSaved ? 'Saved' : 'Save'),
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(vertical: 14),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(14),
                                          ),
                                          side: const BorderSide(color: Colors.pink),
                                          foregroundColor: Colors.pink,
                                          backgroundColor: _currentImageSaved ? Colors.pink.withValues(alpha: 0.1) : null,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: () => _saveToFavorites(makeAnother: true),
                                        icon: const Icon(Icons.add_photo_alternate),
                                        label: const Text('Save & New'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.purple,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(vertical: 14),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(14),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                // Secondary action: Send to Studio
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      // Pass back both image and the prompt used to create it
                                      final prompt = _buildPrompt(selectedTheme!, selectedVariant);
                                      Navigator.pop(context, {
                                        'image': styledImage,
                                        'prompt': prompt,
                                      });
                                    },
                                    icon: const Icon(Icons.send),
                                    label: const Text('Send to Studio'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.black,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                // Share button
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => ShareHubPage(
                                            imageBase64: styledImage,
                                            prompt: selectedVariant?.prompt ?? selectedTheme?.label,
                                            isPremiumImage: true,
                                          ),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.share_rounded),
                                    label: const Text('Share Creation'),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      side: BorderSide(color: Colors.purple.shade300),
                                      foregroundColor: Colors.purple,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else ...[
                          // Custom Prompt Pill
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
                                      // Microphone placeholder
                                      ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Voice input not enabled in this demo')));
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Theme Strip
                          Container(
                            height: 140, // Height for the blocks + padding
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: themePresets.length,
                              itemBuilder: (_, i) {
                                final t = themePresets[i];
                                return GestureDetector(
                                  onTap: isLoading ? null : () => _openThemeSheet(t),
                                  child: Container(
                                    width: 90,
                                    margin: const EdgeInsets.only(right: 12),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      color: Colors.grey[900],
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.1),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        )
                                      ],
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        // Avatar Image
                                        if (t.assetPath != null)
                                          _FirebaseImage(
                                            path: t.assetPath!,
                                            fit: BoxFit.cover,
                                            fallback: Container(
                                              color: Colors.amber, // Fallback yellow
                                              child: const Icon(Icons.broken_image, color: Colors.black54),
                                            ),
                                          )
                                        else
                                          Container(
                                            color: Colors.amber,
                                            child: const Icon(Icons.person, color: Colors.black54),
                                          ),

                                        // Gradient Overlay for Text
                                        Positioned(
                                          bottom: 0,
                                          left: 0,
                                          right: 0,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: Alignment.topCenter,
                                                end: Alignment.bottomCenter,
                                                colors: [
                                                  Colors.transparent,
                                                  Colors.black.withValues(alpha: 0.9),
                                                ],
                                              ),
                                            ),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                if (t.isPremium)
                                                  const Icon(Icons.lock, size: 12, color: Colors.amber),
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
                        // Safe area spacing
                        SizedBox(height: MediaQuery.of(context).padding.bottom),
                      ],
                    ),
                  ),
                ],
              ),

              // Loading Overlay
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
}

class _PromoCarousel extends StatefulWidget {
final void Function(ThemePreset theme)? onDiscoverThemeSelected;

const _PromoCarousel({this.onDiscoverThemeSelected});

@override
State<_PromoCarousel> createState() => _PromoCarouselState();
}

class _PromoCarouselState extends State<_PromoCarousel> {
late final PageController _pageController;
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
subtitle: 'Unlock exclusive styles and unlimited generations',
icon: Icons.star_rounded,
gradient: [Color(0xFFffd700), Color(0xFFff8c00)],
action: 'Upgrade',
),
];

@override
void initState() {
super.initState();
_pageController = PageController(viewportFraction: 0.92);
_startAutoScroll();
}

void _startAutoScroll() {
Future.delayed(const Duration(seconds: 4), () {
if (!mounted) return;
final nextPage = (_currentPage + 1) % _promoItems.length;
_pageController.animateToPage(
nextPage,
duration: const Duration(milliseconds: 500),
curve: Curves.easeInOut,
);
_startAutoScroll();
});
}

@override
void dispose() {
_pageController.dispose();
super.dispose();
}

void _onPromoTap(int index) {
switch (index) {
case 0: // Share
Navigator.of(context).push(
MaterialPageRoute(builder: (_) => const ShareHubPage()),
);
break;
case 1: // Sofi Music
Navigator.of(context).push(
MaterialPageRoute(builder: (_) => const SofiMusicPage()),
);
break;
case 2: // Discover
Navigator.of(context).push<ThemePreset>(
MaterialPageRoute(
builder: (_) => DiscoverPage(
onThemeSelected: (theme) {
Navigator.of(context).pop(theme);
},
onStyleSelected: (style) {
// Style presets are for the main studio, not Premium
Navigator.of(context).pop();
ScaffoldMessenger.of(context).showSnackBar(
SnackBar(content: Text('Style "${style['label']}" works best in the main Studio')),
);
},
),
),
).then((selectedTheme) {
if (selectedTheme != null && mounted) {
widget.onDiscoverThemeSelected?.call(selectedTheme);
}
});
break;
case 3: // Favorites
Navigator.of(context).push(
MaterialPageRoute(builder: (_) => const FavoritesHubPage()),
);
break;
case 4: // Go Premium
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
onTap: () => _onPromoTap(index),
child: Container(
margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
decoration: BoxDecoration(
gradient: LinearGradient(
colors: item.gradient,
begin: Alignment.topLeft,
end: Alignment.bottomRight,
),
borderRadius: BorderRadius.circular(20),
boxShadow: [
BoxShadow(
color: item.gradient.first.withValues(alpha: 0.4),
blurRadius: 12,
offset: const Offset(0, 6),
),
],
),
child: Stack(
children: [
// Background pattern
Positioned(
right: -20,
bottom: -20,
child: Icon(
item.icon,
size: 120,
color: Colors.white.withValues(alpha: 0.15),
),
),
// Content
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
color: Colors.white.withValues(alpha: 0.9),
fontSize: 12,
),
),
const SizedBox(height: 8),
Container(
padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
color: Colors.white.withValues(alpha: 0.2),
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
// Page indicators
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

/// History entry for Premium Studio generations
class _GenerationHistoryEntry {
final String imageBase64;
final String themeName;
final String? variantName;
final String prompt;
final DateTime timestamp;

_GenerationHistoryEntry({
required this.imageBase64,
required this.themeName,
this.variantName,
required this.prompt,
required this.timestamp,
});
}

/// Premium-styled history sheet for browsing past generations
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
colors: [
Color(0xFF2D1B4E),
Color(0xFF1A1A2E),
],
),
borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
),
child: Column(
children: [
const SizedBox(height: 12),
// Drag handle
Container(
width: 40,
height: 4,
decoration: BoxDecoration(
color: Colors.white.withValues(alpha: 0.3),
borderRadius: BorderRadius.circular(2),
),
),
const SizedBox(height: 16),
// Header
Padding(
padding: const EdgeInsets.symmetric(horizontal: 20),
child: Row(
children: [
Container(
padding: const EdgeInsets.all(10),
decoration: BoxDecoration(
color: Colors.purple.withValues(alpha: 0.3),
borderRadius: BorderRadius.circular(12),
),
child: const Icon(Icons.history_rounded, color: Colors.white, size: 24),
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
color: Colors.white.withValues(alpha: 0.7),
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
// History Grid
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
// Show newest first
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
color: Colors.black.withValues(alpha: 0.3),
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
// Image
Image.memory(
base64Decode(entry.imageBase64),
fit: BoxFit.cover,
),
// Gradient overlay
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
Colors.black.withValues(alpha: 0.85),
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
color: Colors.white.withValues(alpha: 0.7),
fontSize: 11,
),
maxLines: 1,
overflow: TextOverflow.ellipsis,
),
const SizedBox(height: 2),
Text(
_formatTime(entry.timestamp),
style: TextStyle(
color: Colors.white.withValues(alpha: 0.5),
fontSize: 10,
),
),
],
),
),
),
// Current indicator
if (isCurrent)
Positioned(
top: 8,
right: 8,
child: Container(
padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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

/// Helper widget to load images from Firebase Storage
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
if (widget.path != oldWidget.path) {
_loadImage();
}
}

Future<void> _loadImage() async {
setState(() {
_loading = true;
_error = false;
});

try {
final url = await StorageService.instance.getDownloadUrlSafe(widget.path);
if (mounted) {
setState(() {
_url = url;
if (url == null) _error = true;
});
}
} catch (e) {
debugPrint('Failed to load image: $e');
if (mounted) setState(() => _error = true);
} finally {
if (mounted) setState(() => _loading = false);
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
child: CircularProgressIndicator(strokeWidth: 2),
),
),
);
}

if (_error || _url == null) {
return widget.fallback ?? const Center(child: Icon(Icons.broken_image, size: 18));
}

return Image.network(
_url!,
fit: widget.fit,
errorBuilder: (_, __, ___) => widget.fallback ?? const Center(child: Icon(Icons.broken_image)),
);
}
}
