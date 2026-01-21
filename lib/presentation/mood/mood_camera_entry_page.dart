import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';

class MoodCameraEntryPage extends StatefulWidget {
  const MoodCameraEntryPage({super.key});

  @override
  State<MoodCameraEntryPage> createState() => _MoodCameraEntryPageState();
}

class _MoodCameraEntryPageState extends State<MoodCameraEntryPage> {
  CameraController? _cameraController;
  bool _cameraReady = false;
  bool _isGenerating = false;
  String? _selectedMood;

  final List<String> _moods = [
    'Bold',
    'Happy',
    'Calm',
    'Confident',
    'Creative',
    'Soft',
    'Powerful',
    'Mysterious',
  ];

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) return;

    final cameras = await availableCameras();
    final frontCamera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
    );

    _cameraController = CameraController(
      frontCamera,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    await _cameraController!.initialize();
    if (!mounted) return;

    setState(() => _cameraReady = true);
  }

  void _onMoodSelected(String mood) {
    if (_isGenerating) return;

    setState(() {
      _selectedMood = mood;
      _isGenerating = true;
    });

    _startGeneration();
  }

  Future<void> _startGeneration() async {
    // 🔮 PLACEHOLDER for ModelsLab trigger
    // You will connect this to your existing generation pipeline

    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) return;

    // TODO: Navigate to your generation/loading/result screen
    // Example:
    // Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => GenerationPage(mood: _selectedMood)));

    setState(() {
      _isGenerating = false;
    });
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 📷 CAMERA PREVIEW
          if (_cameraReady && _cameraController != null)
            Positioned.fill(
              child: CameraPreview(_cameraController!),
            )
          else
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),

          // 🌫️ DARK OVERLAY
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.4),
            ),
          ),

          // 🎯 MAIN CONTENT
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 24),

                // 🔑 PROMPT
                const Text(
                  "What's your mood today?",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(height: 12),

                const Text(
                  'Tap one. We’ll do the rest.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                ),

                const Spacer(),

                // 🎭 MOOD GRID
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
                        onTap: () => _onMoodSelected(mood),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
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
                              color: isSelected
                                  ? Colors.black
                                  : Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),

          // ⏳ GENERATING OVERLAY
          if (_isGenerating)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.6),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'Creating your look…',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
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
}
