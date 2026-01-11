import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:sofi_test_connect/presentation/splash/instructional_video_page.dart';
import 'package:sofi_test_connect/services/audio_service.dart';

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
    // Ensure auth completes BEFORE attempting to fetch the Storage URL
    _boot();
  }

  Future<void> _boot() async {
    _startMinimumTimer();
    await _ensureFirebaseAuth();
    if (!mounted) return;
    
    // Play buildup music on startup
    // Web needs user gesture first; native iOS plays immediately
    if (kIsWeb) {
      if (!AudioService.instance.isWebAudioUnlocked) {
        setState(() => _needsWebAudioUnlock = true);
      } else {
        unawaited(AudioService.instance.playStartup());
      }
    } else {
      // Native iOS: slight delay ensures audio context is fully ready
      // This prevents audio cutoff issues on iOS
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          AudioService.instance.playStartup();
        }
      });
    }
    
    await _initializeVideo();
  }

  Future<void> _ensureFirebaseAuth() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        await FirebaseAuth.instance.signInAnonymously();
        debugPrint('[Auth] Signed in anonymously');
      } else {
        debugPrint('[Auth] Already signed in: ${currentUser.uid}');
      }
    } catch (e) {
      debugPrint('[Auth] Failed to sign in: $e');
    }
  }

  void _startMinimumTimer() {
    // Ensure at least 10 seconds of splash display to match startup music
    Timer(const Duration(seconds: 10), () {
      if (mounted) {
        setState(() => _minimumTimeElapsed = true);
        _checkAndNavigate();
      }
    });
  }

  Future<void> _initializeVideo() async {
    // Firebase Storage gs:// URL provided by user
    const gsUrl =
        'gs://sofi-saint-app.firebasestorage.app/videos/Sofi app intro 2.mp4';

    try {
      final ref = FirebaseStorage.instance.refFromURL(gsUrl);
      final downloadUrl = await ref.getDownloadURL();

      _controller = VideoPlayerController.networkUrl(Uri.parse(downloadUrl));
      _hasController = true;

      await _controller.initialize();
      if (mounted) {
        setState(() => _isInitialized = true);
        _controller.setLooping(false);
        // Mute on web to satisfy autoplay policies
        _controller.setVolume(kIsWeb ? 0.0 : 1.0);
        _controller.play();

        // Listen for video completion
        _controller.addListener(_videoListener);
      }
    } catch (e) {
      debugPrint('Video initialization error: $e');
      // If video fails, wait for minimum time then navigate
      if (mounted) setState(() => _isInitialized = true);
    }
  }

  void _videoListener() {
    if (_hasController &&
        _controller.value.position >= _controller.value.duration &&
        _controller.value.duration > Duration.zero) {
      _checkAndNavigate();
    }
  }

  void _checkAndNavigate() {
    // Only navigate if minimum 10 seconds have passed
    if (_minimumTimeElapsed && !_hasNavigated && mounted) {
      _hasNavigated = true;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const InstructionalVideoPage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
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

  Future<void> _handleAudioUnlock() async {
    if (!kIsWeb || !_needsWebAudioUnlock) return;
    await AudioService.instance.unlockWebAudio();
    if (!mounted) return;
    setState(() => _needsWebAudioUnlock = false);
    // Start music right after unlock
    unawaited(AudioService.instance.playStartup());
  }

  @override
  Widget build(BuildContext context) {
    // On web, wrap entire screen in GestureDetector so any tap unlocks audio
    Widget body = _isInitialized && _hasController
        ? Stack(
            children: [
              SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _controller.value.size.width,
                    height: _controller.value.size.height,
                    child: VideoPlayer(_controller),
                  ),
                ),
              ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Sofi Saint',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 56,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFFFFD700),
                        letterSpacing: 1.5,
                        shadows: [
                          Shadow(
                            offset: const Offset(0, 0),
                            blurRadius: 10.0,
                            color: Colors.blue.shade900,
                          ),
                          Shadow(
                            offset: const Offset(0, 0),
                            blurRadius: 20.0,
                            color: Colors.blue,
                          ),
                          const Shadow(
                            offset: Offset(0, 0),
                            blurRadius: 30.0,
                            color: Colors.purple,
                          ),
                          const Shadow(
                            offset: Offset(0, 0),
                            blurRadius: 45.0,
                            color: Colors.purpleAccent,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Imagine Create Become',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.purpleAccent,
                        letterSpacing: 0.5,
                        shadows: [
                          const Shadow(
                            offset: Offset(0, 0),
                            blurRadius: 10.0,
                            color: Color(0xFFFFD700),
                          ),
                          Shadow(
                            offset: const Offset(0, 0),
                            blurRadius: 20.0,
                            color: Colors.yellow.shade700,
                          ),
                        ],
                      ),
                    ),
                    // Subtle hint to tap anywhere for sound (web only)
                    if (kIsWeb && _needsWebAudioUnlock) ...[
                      const SizedBox(height: 24),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.touch_app, color: Colors.white54, size: 18),
                          SizedBox(width: 6),
                          Text(
                            'Tap anywhere to enable sound',
                            style: TextStyle(color: Colors.white54, fontSize: 14),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          )
        : const Center(
            child: CircularProgressIndicator(
              color: Colors.white,
            ),
          );

    // Wrap in GestureDetector to unlock audio on any tap (web)
    if (kIsWeb && _needsWebAudioUnlock) {
      body = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _handleAudioUnlock,
        child: body,
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: body,
    );
  }
}
