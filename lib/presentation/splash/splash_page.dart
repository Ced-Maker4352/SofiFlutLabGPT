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
    Timer(const Duration(seconds: 10), () async {
      if (!mounted) return;
      setState(() => _minimumTimeElapsed = true);
      await _checkAndNavigate();
    });
  }

  Future<void> _initializeVideo() async {
    const videoPath = 'videos/Sofi app intro 2.mp4';

    try {
      final ref = FirebaseStorage.instance.ref(videoPath);
      final downloadUrl = await ref.getDownloadURL()
          .timeout(const Duration(seconds: 15));

      _controller = VideoPlayerController.networkUrl(Uri.parse(downloadUrl));
      _hasController = true;

      await _controller.initialize()
          .timeout(const Duration(seconds: 25));
      if (!mounted) return;

      setState(() => _isInitialized = true);
      _controller
        ..setLooping(false)
        ..setVolume(kIsWeb ? 0.0 : 1.0)
        ..play()
        ..addListener(_videoListener);
    } catch (e) {
      debugPrint('[Splash] Video load failed or timed out: $e');
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
    if (!_isInitialized && !kIsWeb) {
       return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: SofiStudioTheme.yellow)),
      );
    }

    Widget content = Stack(
      fit: StackFit.expand,
      children: [
        // 1. VIDEO LAYER
        if (_hasController)
          ValueListenableBuilder(
            valueListenable: _controller,
            builder: (context, VideoPlayerValue value, child) {
              if (value.isInitialized) {
                return FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: value.size.width,
                    height: value.size.height,
                    child: VideoPlayer(_controller),
                  ),
                );
              } else {
                return Container(color: Colors.black);
              }
            },
          )
        else
          Container(color: Colors.black),

        // 2. DIMMER/GRADIENT (Optional, but helps text readability)
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.3),
                Colors.transparent,
                Colors.black.withOpacity(0.4),
              ],
            ),
          ),
        ),

        // 3. TEXT LAYER
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Sofi Saint',
                style: TextStyle(
                  fontSize: 56,
                  fontWeight: FontWeight.w900,
                  color: SofiStudioTheme.yellow,
                  shadows: [
                    Shadow(
                      blurRadius: 15,
                      color: Colors.black.withOpacity(0.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Imagine Create Become',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.white, // Changed from purple for better contrast
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    if (kIsWeb && _needsWebAudioUnlock) {
      content = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _handleAudioUnlock,
        child: content,
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: content,
    );
  }
}
