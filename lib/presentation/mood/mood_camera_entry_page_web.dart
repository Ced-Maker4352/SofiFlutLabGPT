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
import '../sofi_studio/sofi_studio_page.dart';

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

    final selfieBytes = _selfieBytes;
    final mood = _selectedMood!;
    final mode = _selectedMode;

    // Direct push to Studio (keeping Mood page in history)
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) {
          return SofiStudioPage(
            onControllerReady: (controller) {
              controller.enterFromMoodFlow(
                selfie: selfieBytes ?? Uint8List(0), // Controller handles null or empty
                mood: mood,
                mode: mode,
              );
            },
          );
        },
      ),
    );

    if (mounted) {
      setState(() => _isGenerating = false);
    }
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
                        }),
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

                    if (mode.isPremium && !premium.isPremium) {
                      final isSubscribed = await PaywallSheet.show(context);
                      if (isSubscribed != true) {
                        return; // User cancelled or failed to subscribe
                      }
                      // If they subscribed, refresh premium state
                      await premium.initialize();
                    }

                    if (!mounted) return;
                    setState(() => _selectedMode = mode);
                  },
                ),

                const SizedBox(height: 16),

                /// MOOD GRID
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                        // MOOD GRID (Stylish & Visual)
                        child: Expanded(
                          child: GridView.builder(
                            itemCount: _moods.length,
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 16,
                              crossAxisSpacing: 16,
                              childAspectRatio: 0.85, // Taller for stacked icon + text
                            ),
                            itemBuilder: (context, index) {
                              final mood = _moods[index];
                              final isSelected = mood == _selectedMood;

                              // Map moods to modern, youth-friendly icons
                              final IconData iconInfo;
                              final List<Color> bgGradient;

                              switch (mood) {
                                case 'Bold':
                                  iconInfo = Icons.local_fire_department_rounded;
                                  bgGradient = [Color(0xFFFF512F), Color(0xFFDD2476)]; // Vibrant Orange/Pink
                                  break;
                                case 'Happy':
                                  iconInfo = Icons.emoji_emotions_rounded;
                                  bgGradient = [Color(0xFFFFD700), Color(0xFFF7971E)]; // Sunny Yellow
                                  break;
                                case 'Calm':
                                  iconInfo = Icons.spa_rounded;
                                  bgGradient = [Color(0xFF4CB8C4), Color(0xFF3CD3AD)]; // Minty Teal
                                  break;
                                case 'Confident':
                                  iconInfo = Icons.star_rounded;
                                  bgGradient = [Color(0xFF8A2387), Color(0xFFE94057)]; // Deep Purple to Pink
                                  break;
                                case 'Creative':
                                  iconInfo = Icons.color_lens_rounded;
                                  bgGradient = [Color(0xFFa18cd1), Color(0xFFfbc2eb)]; // Pastel Purple/Pink
                                  break;
                                case 'Soft':
                                  iconInfo = Icons.favorite_rounded;
                                  bgGradient = [Color(0xFFff9a9e), Color(0xFFfecfef)]; // Soft Rose
                                  break;
                                case 'Powerful':
                                  iconInfo = Icons.bolt_rounded;
                                  bgGradient = [Color(0xFF00c6fb), Color(0xFF005bea)]; // Electric Blue
                                  break;
                                case 'Mysterious':
                                  iconInfo = Icons.dark_mode_rounded;
                                  bgGradient = [Color(0xFF304352), Color(0xFFd7d2cc)]; // Midnight Silver
                                  break;
                                default:
                                  iconInfo = Icons.auto_awesome_rounded;
                                  bgGradient = [Color(0xFFA770EF), Color(0xFFCF8BF3)]; // Default Purple
                              }

                              return GestureDetector(
                                onTap: () {
                                  if (!mounted) return;
                                  setState(() => _selectedMood = mood);
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  curve: Curves.easeOutBack, // Playful bounce
                                  decoration: BoxDecoration(
                                    gradient: isSelected
                                        ? LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: bgGradient,
                                          )
                                        : null,
                                    color: isSelected
                                        ? null
                                        : DarkModeColors.darkSurface.withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: isSelected
                                          ? Colors.white.withValues(alpha: 0.8)
                                          : Colors.white.withValues(alpha: 0.1),
                                      width: isSelected ? 2 : 1,
                                    ),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: bgGradient.first.withValues(alpha: 0.4),
                                              blurRadius: 12,
                                              spreadRadius: 2,
                                              offset: const Offset(0, 4),
                                            ),
                                          ]
                                        : [],
                                  ),
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          // ICON
                                          Icon(
                                            iconInfo,
                                            size: 40, // Slightly larger on web
                                            color: isSelected
                                                ? Colors.white
                                                : Colors.white.withValues(alpha: 0.5),
                                          ),
                                          const SizedBox(height: 8),
                                          // TEXT
                                          Text(
                                            mood,
                                            textAlign: TextAlign.center,
                                            maxLines: 1,
                                            overflow: TextOverflow.clip,
                                            style: TextStyle(
                                              color: isSelected
                                                  ? Colors.white
                                                  : Colors.white.withValues(alpha: 0.5),
                                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                              fontSize: 14, // Larger on web
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (isSelected)
                                        Positioned(
                                          top: 8,
                                          right: 8,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              shape: BoxShape.circle,
                                            ),
                                            padding: EdgeInsets.all(4),
                                            child: Icon(
                                              Icons.check,
                                              size: 14,
                                              color: bgGradient.first,
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
