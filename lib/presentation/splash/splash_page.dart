import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'package:video_player/video_player.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'package:sofi_test_connect/services/audio_service.dart';

// ✅ CORRECT + FINAL import (facade file)
import 'package:sofi_test_connect/presentation/mood/mood_camera_entry_page.dart';

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

    // 🔊 Audio handling
    if (kIsWeb) {
      if (!AudioService.instance.isWebAudioUnlocked) {
        setState(() => _needsWebAudioUnlock = true);
      } else {
        unawaited(AudioService.instance.playStartup());
      }
    } else {
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
    Timer(const Duration(seconds: 10), () {
      if (!mounted) return;
      setState(() => _minimumTimeElapsed = true);
      _checkAndNavigate();
    });
  }

  Future<void> _initializeVideo() async {
    const gsUrl =
        'gs://sofi-saint-app.firebasestorage.app/videos/Sofi app intro 2.mp4';

    try {
      final ref = FirebaseStorage.instance.refFromURL(gsUrl);
      final downloadUrl = await ref.getDownloadURL();

      _controller = VideoPlayerController.networkUrl(Uri.parse(downloadUrl));
      _hasController = true;

      await _controller.initialize();
      if (!mounted) return;

      setState(() => _isInitialized = true);
      _controller
        ..setLooping(false)
        ..setVolume(kIsWeb ? 0.0 : 1.0)
        ..play()
        ..addListener(_videoListener);
    } catch (e) {
      debugPrint('[Splash] Video init failed: $e');
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
    if (_minimumTimeElapsed && !_hasNavigated && mounted) {
      _hasNavigated = true;

      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const MoodCameraEntryPage(),
          transitionsBuilder: (_, animation, __, child) =>
              FadeTransition(opacity: animation, child: child),
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    }
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
                      style: TextStyle(
                        fontSize: 56,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFFFFD700),
                        letterSpacing: 1.5,
                        shadows: [
                          Shadow(
                            offset: Offset.zero,
                            blurRadius: 20,
                            color: Colors.purpleAccent,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Imagine Create Become',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.purpleAccent,
                      ),
                    ),
                    if (kIsWeb && _needsWebAudioUnlock) ...[
                      const SizedBox(height: 24),
                      const Text(
                        'Tap anywhere to enable sound',
                        style: TextStyle(color: Colors.white54),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          )
        : const Center(child: CircularProgressIndicator());

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
