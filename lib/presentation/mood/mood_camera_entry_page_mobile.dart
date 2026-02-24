import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'mood_mode.dart';
import '../../widgets/mood_icon_row.dart';
import '../../services/premium_service.dart';
import '../../theme.dart';
import '../sofi_studio/sofi_studio_theme.dart';
import '../../services/theme_manager.dart';
import '../../presentation/premium/paywall_sheet.dart';

class MoodCameraEntryPageImpl extends StatefulWidget {
  const MoodCameraEntryPageImpl({super.key});

  @override
  State<MoodCameraEntryPageImpl> createState() =>
      _MoodCameraEntryPageImplState();
}

class _MoodCameraEntryPageImplState extends State<MoodCameraEntryPageImpl> {
  final ImagePicker _picker = ImagePicker();

  bool _isGenerating = false;

  /// FUNCTIONAL mood (this triggers auto-generation)
  String? _selectedMood;

  /// VISUAL mode (human / doll / premium)
  MoodMode _selectedMode = MoodMode.human;

  Uint8List? _selfieBytes;

  final List<String> _moods = const [
    'Bold',
    'Happy',
    'Calm',
    'Confident',
    'Creative',
    'Soft',
    'Powerful',
    'Mysterious',
  ];

  Future<void> _pickSelfie() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 92,
    );
    if (file == null) return;

    final bytes = await file.readAsBytes();
    if (!mounted) return;

    setState(() => _selfieBytes = bytes);
  }

  Future<void> _continue() async {
    if (_isGenerating || _selectedMood == null) return;

    if (!mounted) return;
    setState(() => _isGenerating = true);

    await Future.delayed(const Duration(milliseconds: 300));

    if (!mounted) return;

    Navigator.of(context).pop({
      'mood': _selectedMood, // REQUIRED for auto-gen
      'mode': _selectedMode.id, // additive
      'selfieBytes': _selfieBytes,
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeManager.instance.current;
    return Scaffold(
      backgroundColor: theme.backgroundColor,
      body: Stack(
        children: [
          // Gradient background matching Studio page
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    theme.backgroundColor,
                    theme.headerColor,
                    theme.backgroundColor,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // ─────────────── TOP: Logo & Title ───────────────
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      // Logo
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          'https://firebasestorage.googleapis.com/v0/b/sofi-saint-app.firebasestorage.app/o/images%2Fdolls%2Fspecial%2Fthumbs%2Fspecial_01_base_thumb.png?alt=media',
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: theme.accentColor.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.image,
                                  color: theme.headerTextColor
                                      .withValues(alpha: 0.5)),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Title & Subtitle
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ShaderMask(
                              shaderCallback: (bounds) => LinearGradient(
                                colors: [
                                  SofiStudioTheme.purple,
                                  SofiStudioTheme.blue
                                ],
                              ).createShader(bounds),
                              child: const Text(
                                "How are you feeling today?",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Pick a mood. Add a selfie if you want — we'll transform your look.",
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.headerTextColor
                                    .withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ─────────────── CAMERA PREVIEW AREA ───────────────
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: GestureDetector(
                      onTap: _pickSelfie,
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: theme.headerColor.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: theme.accentColor.withValues(alpha: 0.5),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: theme.accentColor.withValues(alpha: 0.2),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: _selfieBytes != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(22),
                                child: Image.memory(
                                  _selfieBytes!,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: double.infinity,
                                ),
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Face outline guide
                                  Container(
                                    width: 140,
                                    height: 180,
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: SofiStudioTheme.purple
                                            .withValues(alpha: 0.5),
                                        width: 2,
                                        strokeAlign:
                                            BorderSide.strokeAlignCenter,
                                      ),
                                      borderRadius: BorderRadius.circular(70),
                                    ),
                                    child: Center(
                                      child: Icon(
                                        Icons.person_outline,
                                        size: 80,
                                        color: SofiStudioTheme.purple
                                            .withValues(alpha: 0.4),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  Text(
                                    'Tap to add your selfie',
                                    style: TextStyle(
                                      color: DarkModeColors.darkOnBackground
                                          .withValues(alpha: 0.7),
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Position your face in the frame',
                                    style: TextStyle(
                                      color: DarkModeColors.darkOnBackground
                                          .withValues(alpha: 0.5),
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // ─────────────── BOTTOM: All Controls ───────────────
                /// MODE ICONS
                MoodIconRow(
                  selected: _selectedMode,
                  onSelect: (mode) async {
                    final premium = PremiumService();
                    await premium.initialize();

                    if (mode.isPremium) {
                      if (!premium.canUseDailyPreview()) {
                        PaywallSheet.show(context);
                        return;
                      }
                    }

                    if (!mounted) return;
                    setState(() => _selectedMode = mode);
                  },
                ),

                const SizedBox(height: 16),

                /// MOOD GRID
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _moods.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 2.4,
                    ),
                    itemBuilder: (context, index) {
                      final mood = _moods[index];
                      final isSelected = mood == _selectedMood;

                      return GestureDetector(
                        onTap: () {
                          if (!mounted) return;
                          setState(() => _selectedMood = mood);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          decoration: BoxDecoration(
                            gradient: isSelected
                                ? SofiStudioTheme.brandGradient
                                : null,
                            color:
                                isSelected ? null : DarkModeColors.darkSurface,
                            borderRadius: BorderRadius.circular(20),
                            border: isSelected
                                ? null
                                : Border.all(
                                    color: SofiStudioTheme.purple
                                        .withValues(alpha: 0.3),
                                    width: 1,
                                  ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            mood,
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : DarkModeColors.darkOnBackground,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 12),

                /// Upload Selfie Button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    height: 44,
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _pickSelfie,
                      icon: Icon(
                        _selfieBytes == null
                            ? Icons.add_a_photo_outlined
                            : Icons.check_circle,
                        size: 18,
                      ),
                      label: Text(
                        _selfieBytes == null
                            ? 'Upload Selfie'
                            : 'Selfie Added ✓',
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _selfieBytes == null
                            ? theme.headerTextColor
                            : BrandColors.neonCyan,
                        side: BorderSide(
                          color: _selfieBytes == null
                              ? SofiStudioTheme.purple.withValues(alpha: 0.4)
                              : BrandColors.neonCyan.withValues(alpha: 0.6),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                /// Transform Button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: _selectedMood != null
                            ? SofiStudioTheme.brandGradient
                            : LinearGradient(
                                colors: [
                                  SofiStudioTheme.purple.withValues(alpha: 0.3),
                                  SofiStudioTheme.blue.withValues(alpha: 0.3),
                                ],
                              ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: _selectedMood != null
                            ? [
                                BoxShadow(
                                  color: SofiStudioTheme.purple
                                      .withValues(alpha: 0.4),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : null,
                      ),
                      child: ElevatedButton(
                        onPressed: _selectedMood == null ? null : _continue,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shadowColor: Colors.transparent,
                          disabledBackgroundColor: Colors.transparent,
                          disabledForegroundColor:
                              Colors.white.withValues(alpha: 0.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Transform My Look',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),

          // Loading overlay
          if (_isGenerating)
            Positioned.fill(
              child: Container(
                color: DarkModeColors.darkBackground.withValues(alpha: 0.85),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(
                          color: SofiStudioTheme.purple),
                      const SizedBox(height: 14),
                      Text(
                        'Creating your look…',
                        style: TextStyle(
                          color: DarkModeColors.darkOnBackground,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
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
}
