import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:sofi_test_connect/presentation/sofi_studio/sofi_studio_page.dart';

class InstructionalVideoPage extends StatefulWidget {
  const InstructionalVideoPage({super.key});

  @override
  State<InstructionalVideoPage> createState() => _InstructionalVideoPageState();
}

class _InstructionalVideoPageState extends State<InstructionalVideoPage> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _hasNavigated = false;
  bool _hasController = false;
  bool _awaitingUserGesture = kIsWeb; // Web/iOS Safari require gesture to play with sound
  // Removed unused _isPlaying flag

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    const gsUrl = 'gs://sofi-saint-app.firebasestorage.app/videos/Quick_Instructional_Video_Creation.mp4';

    try {
      final ref = FirebaseStorage.instance.refFromURL(gsUrl);
      final downloadUrl = await ref.getDownloadURL();

      _controller = VideoPlayerController.networkUrl(Uri.parse(downloadUrl));
      _hasController = true;

      await _controller.initialize();
      if (mounted) {
        setState(() => _isInitialized = true);
        _controller.setLooping(false);
        if (kIsWeb) {
          // Autoplay with sound is blocked on web/iOS Safari. Wait for tap.
          _controller.setVolume(1.0);
          _awaitingUserGesture = true;
          // Playback will start on user gesture
        } else {
          _controller.setVolume(1.0);
          await _controller.play();
        }

        _controller.addListener(_videoListener);
      }
    } catch (e) {
      debugPrint('Instructional video error: $e');
      // If video fails, navigate immediately
      _navigateToStudio();
    }
  }

  void _videoListener() {
    if (_hasController &&
        _controller.value.position >= _controller.value.duration &&
        _controller.value.duration > Duration.zero) {
      _navigateToStudio();
    }
  }

  void _navigateToStudio() {
    if (!_hasNavigated && mounted) {
      _hasNavigated = true;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const SofiStudioPage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              FadeTransition(opacity: animation, child: child),
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    }
  }

  void _skipVideo() {
    if (_hasController) {
      _controller.pause();
    }
    _navigateToStudio();
  }

  Future<void> _playWithSound() async {
    if (!_hasController) return;
    try {
      // Ensure volume is up and begin playback on user gesture
      await _controller.setVolume(1.0);
      await _controller.play();
      setState(() {
        _awaitingUserGesture = false;
      });
    } catch (e) {
      debugPrint('Failed to start instructional video with sound: $e');
    }
  }

  @override
  void dispose() {
    if (_hasController) {
      _controller.removeListener(_videoListener);
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (_isInitialized && _hasController)
            Center(
              child: AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              ),
            )
          else
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          // Play overlay for web/iOS policy (requires a tap to enable audio)
          if (_awaitingUserGesture && _isInitialized)
            Positioned.fill(
              child: Material(
                color: Colors.black.withValues(alpha: 0.5),
                child: InkWell(
                  onTap: _playWithSound,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.play_circle_fill, color: Colors.white, size: 72),
                        SizedBox(height: 12),
                        Text(
                          'Tap to play with sound',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          // Skip button
          Positioned(
            top: 40,
            right: 20,
            child: TextButton(
              onPressed: _skipVideo,
              style: TextButton.styleFrom(
                backgroundColor: Colors.black.withValues(alpha: 0.5),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: const Text(
                'Skip',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
