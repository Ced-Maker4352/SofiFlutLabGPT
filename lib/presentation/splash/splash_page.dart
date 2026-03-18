import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'package:video_player/video_player.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'package:sofi_test_connect/services/audio_service.dart';

// Mood entry
import 'package:sofi_test_connect/presentation/mood/mood_camera_entry_page.dart';
import 'package:sofi_test_connect/presentation/sofi_studio/sofi_studio_theme.dart';
import 'package:sofi_test_connect/services/remote_debug_logger.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  late VideoPlayerController _controller;

  bool _isInitialized = false;
  bool _minimumTimeElapsed = false;
  bool _hasNavigated = false;
  bool _hasController = false;
  bool _needsWebAudioUnlock = false;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    _startMinimumTimer();
    await _ensureFirebaseAuth();
    if (!mounted) return;

    if (kIsWeb) {
      if (!AudioService.instance.isWebAudioUnlocked) {
        setState(() => _needsWebAudioUnlock = true);
      } else {
        unawaited(AudioService.instance.playStartup());
      }
    } else {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) AudioService.instance.playStartup();
      });
    }

    await _initializeVideo();
  }

  Future<void> _ensureFirebaseAuth() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        await FirebaseAuth.instance.signInAnonymously();
      }
    } catch (_) {}
  }

  void _startMinimumTimer() {
    // Show splash for at least 3 seconds, then navigate once ready.
    Timer(const Duration(seconds: 3), () async {
      if (!mounted) return;
      setState(() => _minimumTimeElapsed = true);
      // If video failed or initialized, we can move on.
      if (!_hasController || _isInitialized) {
        await _checkAndNavigate();
      }
    });

    // Safety: absolute maximum splash time is 8 seconds.
    Timer(const Duration(seconds: 8), () async {
      if (!mounted || _hasNavigated) return;
      await _checkAndNavigate();
    });
  }

  Future<void> _initializeVideo() async {
    const videoPath = 'videos/Sofi app intro 2.mp4';

    try {
      final ref = FirebaseStorage.instance.ref(videoPath);
      final downloadUrl = await ref.getDownloadURL()
          .timeout(const Duration(seconds: 4)); // Fast or fallback

      _controller = VideoPlayerController.networkUrl(Uri.parse(downloadUrl));
      _hasController = true;

      await _controller.initialize()
          .timeout(const Duration(seconds: 6)); // Fast or fallback
      if (!mounted) return;

      setState(() => _isInitialized = true);
      _controller
        ..setLooping(false)
        ..setVolume(kIsWeb ? 0.0 : 1.0)
        ..play()
        ..addListener(_videoListener);
        
      debugPrint('[Splash] Video playing');
      RemoteDebugLogger.instance.logInfo('SPLASH_VIDEO', 'Video playing');
    } catch (e) {
      debugPrint('[Splash] Video load failed or timed out: $e');
      RemoteDebugLogger.instance.logError('[Splash] Video failure', e);
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _hasController = false; // Ensure we go to fallback
        });
      }
      // Safety: ensure navigation happens if timer is already up
      if (_minimumTimeElapsed) {
        await _checkAndNavigate();
      }
    }
  }

  void _videoListener() async {
    if (_hasController &&
        _controller.value.position >= _controller.value.duration &&
        _controller.value.duration > Duration.zero) {
      await _checkAndNavigate();
    }
  }

  /// ✅ THIS IS THE FIX
  Future<void> _checkAndNavigate() async {
    if (!_minimumTimeElapsed || _hasNavigated || !mounted) return;
    _hasNavigated = true;

    // Replace Splash with Mood Page
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const MoodCameraEntryPage(),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  Future<void> _handleAudioUnlock() async {
    if (!kIsWeb || !_needsWebAudioUnlock) return;
    await AudioService.instance.unlockWebAudio();
    if (!mounted) return;
    setState(() => _needsWebAudioUnlock = false);
    unawaited(AudioService.instance.playStartup());
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
    // We no longer return a black screen with a spinner.
    // We always return the Scaffold with branding, and the video/spinner happens inside the Stack.

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. VIDEO LAYER (Using ValueListenableBuilder for real-time state)
          if (_hasController)
            ValueListenableBuilder(
              valueListenable: _controller,
              builder: (context, VideoPlayerValue value, child) {
                if (value.isInitialized) {
                  return Center(
                    child: SizedBox.expand(
                      child: FittedBox(
                        fit: BoxFit.cover,
                        clipBehavior: Clip.hardEdge,
                        child: SizedBox(
                          width: value.size.width,
                          height: value.size.height,
                          child: VideoPlayer(_controller),
                        ),
                      ),
                    ),
                  );
                } else {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFFFFCC00),
                      strokeWidth: 2,
                    ),
                  );
                }
              },
            )
          else if (!_isInitialized)
            const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFFFCC00),
                strokeWidth: 2,
              ),
            ),

          // 2. DIMMER OVERLAY (Ensures text contrast regardless of video)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.6),
                    Colors.black.withOpacity(0.2),
                    Colors.black.withOpacity(0.7),
                  ],
                ),
              ),
            ),
          ),

          // 3. BRANDING LAYER
          SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 3),
                  // App Title
                  Text(
                    'Sofi Saint',
                    style: TextStyle(
                      fontSize: 68,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFFFFCC00),
                      letterSpacing: -1.5,
                      shadows: [
                        Shadow(
                          color: Colors.black.withOpacity(0.9),
                          offset: const Offset(0, 4),
                          blurRadius: 30,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Tagline
                  const Text(
                    'IMAGINE • CREATE • BECOME',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 5.0,
                    ),
                  ),
                  const Spacer(flex: 2),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
