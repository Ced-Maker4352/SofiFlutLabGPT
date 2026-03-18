import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
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
import '../../constants/mood_image_paths.dart';
import '../../services/user_preferences_service.dart';

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
                // ─────────────── TOP: Centered Toggles ───────────────
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Center(
                    child: ListenableBuilder(
                      listenable: UserPreferencesService.instance,
                      builder: (context, _) {
                        final isDollMode = UserPreferencesService.instance.isDollMode;
                        final isMaleMode = UserPreferencesService.instance.isMaleMode;
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  isDollMode ? 'Doll' : 'Human',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isDollMode ? SofiStudioTheme.purple : SofiStudioTheme.charcoal.withOpacity(0.7),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                SizedBox(
                                  height: 24,
                                  child: FittedBox(
                                    child: CupertinoSwitch(
                                      value: isDollMode,
                                      activeColor: SofiStudioTheme.purple,
                                      onChanged: (val) {
                                        UserPreferencesService.instance.setDollMode(val);
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 40),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  isMaleMode ? 'Boy' : 'Girl',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isMaleMode ? Colors.blueAccent : SofiStudioTheme.charcoal.withOpacity(0.7),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                SizedBox(
                                  height: 24,
                                  child: FittedBox(
                                    child: CupertinoSwitch(
                                      value: isMaleMode,
                                      activeColor: Colors.blueAccent,
                                      onChanged: (val) {
                                        UserPreferencesService.instance.setMaleMode(val);
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // ─────────────── CAMERA PREVIEW AREA (Edge-to-Edge) ───────────────
                Expanded(
                  child: GestureDetector(
                    onTap: _pickSelfie,
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: theme.headerColor.withOpacity(0.3),
                      ),
                      child: _selfieBytes != null
                          ? Image.memory(
                              _selfieBytes!,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 140,
                                  height: 180,
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: SofiStudioTheme.purple
                                          .withOpacity(0.5),
                                      width: 2,
                                    ),
                                    borderRadius: BorderRadius.circular(70),
                                  ),
                                  child: Center(
                                    child: Icon(
                                      Icons.person_outline,
                                      size: 80,
                                      color: SofiStudioTheme.purple
                                          .withOpacity(0.4),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  'Tap to add your selfie',
                                  style: TextStyle(
                                    color: DarkModeColors.darkOnBackground
                                        .withOpacity(0.7),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),

                // ─────────────── BOTTOM: Seamless Pickers ───────────────
                /// MODE ICONS
                MoodIconRow(
                  selected: _selectedMode,
                  onSelect: (mode) async {
                    final premium = PremiumService();
                    await premium.initialize();

                    if (mode.isPremium && !premium.isPremium) {
                      final isSubscribed = await PaywallSheet.show(context);
                      if (isSubscribed != true) return;
                      await premium.initialize();
                    }

                    if (!mounted) return;
                    setState(() => _selectedMode = mode);
                  },
                ),

                /// MOOD GRID (Seamless)
                Expanded(
                  child: GridView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: _moods.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 0,
                      crossAxisSpacing: 0,
                      childAspectRatio: 1.2,
                    ),
                    itemBuilder: (context, index) {
                      final mood = _moods[index];
                      final isSelected = mood == _selectedMood;

                      final List<Color> bgGradient;
                      switch (mood) {
                        case 'Bold': bgGradient = [Color(0xFFFF512F), Color(0xFFDD2476)]; break;
                        case 'Happy': bgGradient = [SofiStudioTheme.yellow, Color(0xFFF7971E)]; break;
                        case 'Calm': bgGradient = [Color(0xFF4CB8C4), Color(0xFF3CD3AD)]; break;
                        case 'Confident': bgGradient = [Color(0xFF8A2387), Color(0xFFE94057)]; break;
                        case 'Creative': bgGradient = [Color(0xFFa18cd1), Color(0xFFfbc2eb)]; break;
                        case 'Soft': bgGradient = [Color(0xFFff9a9e), Color(0xFFfecfef)]; break;
                        case 'Powerful': bgGradient = [Color(0xFF00c6fb), Color(0xFF005bea)]; break;
                        case 'Mysterious': bgGradient = [Color(0xFF304352), Color(0xFFd7d2cc)]; break;
                        default: bgGradient = [Color(0xFFA770EF), Color(0xFFCF8BF3)];
                      }

                      return GestureDetector(
                        onTap: () {
                          if (!mounted) return;
                          setState(() => _selectedMood = mood);
                          // 🚀 AUTO-GEN: If selfie is present, auto-continue
                          if (_selfieBytes != null && _selfieBytes!.isNotEmpty) {
                            Future.delayed(const Duration(milliseconds: 150), () {
                              if (mounted) _continue();
                            });
                          }
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: isSelected ? Colors.white : Colors.white.withOpacity(0.1),
                              width: isSelected ? 2 : 0,
                            ),
                          ),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: MoodImagePaths.paths.containsKey(mood) ? 
                                        [Colors.transparent, Colors.transparent] : bgGradient,
                                  ),
                                ),
                                child: MoodImagePaths.paths.containsKey(mood)
                                    ? Image.asset(
                                        MoodImagePaths.paths[mood]!,
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      Colors.black.withOpacity(0.4),
                                      Colors.black.withOpacity(0.7),
                                    ],
                                  ),
                                ),
                              ),
                              Center(
                                child: Text(
                                  mood,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: mood == 'Happy' ? SofiStudioTheme.charcoal : Colors.white,
                                    fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                                    fontSize: 16,
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

                const SizedBox(height: 12),

                /// Transform Button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _selectedMood == null ? null : _continue,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _selectedMood != null 
                            ? SofiStudioTheme.purple.withOpacity(0.8)
                            : SofiStudioTheme.purple.withOpacity(0.3),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Transform My Look',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
          // Back Button
          Positioned(
            top: 12,
            left: 12,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          // Loading overlay
          if (_isGenerating)
            Positioned.fill(
              child: Container(
                color: DarkModeColors.darkBackground.withOpacity(0.85),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: SofiStudioTheme.purple),
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
