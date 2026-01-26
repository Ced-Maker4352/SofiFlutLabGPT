import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'mood_mode.dart';
import '../../widgets/mood_icon_row.dart';
import '../../services/premium_service.dart';

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

    setState(() => _isGenerating = true);

    await Future.delayed(const Duration(milliseconds: 300));

    if (!mounted) return;

    Navigator.of(context).pop({
      'mood': _selectedMood,            // REQUIRED for auto-gen
      'mode': _selectedMode.id,         // additive
      'selfieBytes': _selfieBytes,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 24),
            const Text(
              "How are you feeling today?",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Pick a mood. Add a selfie if you want — we'll transform your look.",
              style: TextStyle(color: Colors.white70),
            ),

            const SizedBox(height: 20),

            /// MODE ICONS (NEW — ADDITIVE)
            MoodIconRow(
              selected: _selectedMode,
              onSelect: (mode) async {
                final premium = PremiumService();
                await premium.initialize();

                if (mode.isPremium) {
                  if (!premium.canUseDailyPreview()) {
                    premium.showPaywall(context);
                    return;
                  }
                }

                setState(() => _selectedMode = mode);
              },
            ),

            const SizedBox(height: 24),

            /// MOOD GRID (RESTORED — FUNCTIONAL)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.builder(
                shrinkWrap: true,
                itemCount: _moods.length,
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 2.2,
                ),
                itemBuilder: (context, index) {
                  final mood = _moods[index];
                  final isSelected = mood == _selectedMood;

                  return GestureDetector(
                    onTap: () => setState(() => _selectedMood = mood),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.purpleAccent
                            : Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        mood,
                        style: TextStyle(
                          color:
                              isSelected ? Colors.black : Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: OutlinedButton(
                onPressed: _pickSelfie,
                child: Text(
                  _selfieBytes == null
                      ? 'Upload Selfie (Optional)'
                      : 'Selfie Selected',
                ),
              ),
            ),

            const SizedBox(height: 12),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ElevatedButton(
                onPressed: _selectedMood == null ? null : _continue,
                child: const Text('Transform My Look'),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
