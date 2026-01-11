// lib/services/audio_service.dart

import 'dart:async';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:sofi_test_connect/services/remote_debug_logger.dart';

/// Centralized audio manager with Firebase Storage streaming support.
class AudioService {
  AudioService._internal();
  static final AudioService instance = AudioService._internal();

  // Firebase Storage paths for cloud audio (used with ref() method)
  static const Map<String, String> _cloudSounds = {
    'generate': 'audio/Fast sharp woosh.mp3',
    'success': 'audio/Magic zing.mp3',
    'error': 'audio/error_004.ogg',
    'startup': 'audio/Under Songs/copyright-free-musicroyalty-free-music100-free-music-437088.mp3',
    'music_bestill': 'audio/01 - Sofi Saint - Be Still.mp3',
    'music_allnight': 'audio/Sofi Saint - All Night  INSTRO.mp3',
    'music_notimeleft': 'audio/Sofi Saint NO TIME LEFT - No Time Left.mp3',
    // Generation tracks (rotating)
    'gen_track_0': 'audio/Under Songs/10 sec no-copyright-music-corporate-background-367221.mp3',
    'gen_track_1': 'audio/Under Songs/111no-copyright-music-181373.mp3',
    'gen_track_2': 'audio/Under Songs/background-corporate-music-short-version-65sec-no-copyright-music-378978.mp3',
    'gen_track_3': 'audio/Under Songs/pop-402324.mp3',
    'gen_track_4': 'audio/Under Songs/trap-drums-loop-sound-effect-311578.mp3',
  };

  // Cached download URLs
  final Map<String, String> _urlCache = {};

  // Local asset paths (fallback)
  static const String _dir = 'assets/audio/';
  
  // Initialize as empty to prevent playing missing assets by default
  String clickPath = '';
  String selectPath = '';
  String togglePath = '';
  String tickPath = '';
  String dropPath = '';
  String switchPath = '';
  String slideUpPath = '';
  String slideDownPath = '';
  String popPath = '';

  bool _initialized = false;
  bool _hasLocalAssets = false;
  bool _muted = false;
  double _volume = 0.65;
  bool _webAudioUnlocked = !kIsWeb; // Web needs a user gesture to unlock

  final List<AudioPlayer> _players = [];
  int _roundRobin = 0;

  // Dedicated players
  AudioPlayer? _loopPlayer;
  AudioPlayer? _musicPlayer;
  bool _isLooping = false;
  bool _isMusicPlaying = false;
  String? _currentMusicTrack;
  bool _ducking = false;
  
  // Cycle through generation tracks
  static const int _totalGenTracks = 5;
  int _currentGenTrackIndex = 0;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final manifest = await rootBundle.loadString('AssetManifest.json');
      _hasLocalAssets = manifest.contains('assets/audio/');
      if (_hasLocalAssets) {
        String pick(List<String> candidates) {
          for (final c in candidates) {
            if (manifest.contains(c)) return c;
          }
          return '';
        }
        
        // Only set path if the file actually exists in manifest
        clickPath = pick(['${_dir}click.mp3', '${_dir}click_004.ogg', '${_dir}click_005.ogg']);
        selectPath = pick(['${_dir}select_001.ogg', '${_dir}select.ogg']);
        togglePath = pick(['${_dir}toggle_002.ogg', '${_dir}toggle.ogg']);
        tickPath = pick(['${_dir}tick_001.ogg', '${_dir}tick.ogg']);
        dropPath = pick(['${_dir}drop_001.ogg', '${_dir}drop.ogg']);
        switchPath = pick(['${_dir}switch_002.ogg', '${_dir}switch.ogg']);
        slideUpPath = pick(['${_dir}slide_up.mp3', '${_dir}slide_up.ogg', '${_dir}swipe_up.mp3']);
        slideDownPath = pick(['${_dir}slide_down.mp3', '${_dir}slide_down.ogg', '${_dir}swipe_down.mp3']);
        popPath = pick(['${_dir}pop.mp3', '${_dir}pop.ogg', '${_dir}pop_001.mp3']);
      }
      debugPrint('[Audio] Local assets: $_hasLocalAssets');
    } catch (e) {
      _hasLocalAssets = false;
      debugPrint('[Audio] Init failed: $e');
    }
    for (var i = 0; i < 4; i++) {
      _players.add(AudioPlayer());
    }
    _loopPlayer = AudioPlayer();
    _musicPlayer = AudioPlayer();

    // Configure platform audio contexts (helps iOS play through silent switch)
    // iOS-optimized configuration for best audio experience
    try {
      await AudioPlayer.global.setAudioContext(AudioContext(
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: {
            AVAudioSessionOptions.mixWithOthers,
            AVAudioSessionOptions.duckOthers,
          },
        ),
        android: AudioContextAndroid(
          isSpeakerphoneOn: false,
          stayAwake: false,
          contentType: AndroidContentType.music,
          usageType: AndroidUsageType.media,
          audioFocus: AndroidAudioFocus.gainTransientMayDuck,
        ),
      ));
      debugPrint('[Audio] AudioContext configured for iOS');
    } catch (e) {
      debugPrint('[Audio] Failed to set AudioContext: $e');
    }

    // Pre-fetch cloud URLs in background
    _prefetchCloudUrls();
  }

  /// Pre-fetch all cloud audio URLs for faster playback
  Future<void> _prefetchCloudUrls() async {
    for (final key in _cloudSounds.keys) {
      _getCloudUrl(key); // Fire and forget
    }
  }

  /// Get cached or fetch download URL for cloud sound
  Future<String?> _getCloudUrl(String soundKey) async {
    if (_urlCache.containsKey(soundKey)) {
      return _urlCache[soundKey];
    }
    final path = _cloudSounds[soundKey];
    if (path == null) return null;
    try {
      // Use ref() with path for proper path handling (handles spaces/special chars)
      final ref = FirebaseStorage.instance.ref(path);
      final url = await ref.getDownloadURL();
      _urlCache[soundKey] = url;
      debugPrint('[Audio] Cached URL for $soundKey: $url');
      return url;
    } catch (e) {
      debugPrint('[Audio] Failed to get URL for $soundKey: $e');
      return null;
    }
  }

  AudioPlayer _nextPlayer() {
    final p = _players[_roundRobin];
    _roundRobin = (_roundRobin + 1) % _players.length;
    return p;
  }

  /// Play local asset sound
  Future<void> _playLocal(String assetPath, {double? volumeOverride}) async {
    await _ensureInitialized();
    // Verify path is not empty and assets exist
    if (!_hasLocalAssets || _muted || assetPath.isEmpty) return;
    if (kIsWeb && !_webAudioUnlocked) {
      debugPrint('[Audio] Web audio locked. Skipping local play.');
      return;
    }
    
    try {
      final player = _nextPlayer();
      await player.setVolume(volumeOverride ?? _volume);
      await player.play(AssetSource(assetPath.replaceFirst('assets/', '')));
    } catch (e) {
      debugPrint('[Audio] Play local failed: $e');
      unawaited(RemoteDebugLogger.instance.logAudio('PLAY_LOCAL_ERROR', '$assetPath: $e'));
    }
  }

  /// Play cloud sound by key
  Future<void> _playCloud(String soundKey, {double? volumeOverride}) async {
    await _ensureInitialized();
    if (_muted) return;
    if (kIsWeb && !_webAudioUnlocked) {
      debugPrint('[Audio] Web audio locked. Skipping cloud play: $soundKey');
      return;
    }
    try {
      final url = await _getCloudUrl(soundKey);
      if (url == null) return;
      final player = _nextPlayer();
      await player.setVolume(volumeOverride ?? _volume);
      await player.play(UrlSource(url));
    } catch (e) {
      debugPrint('[Audio] Play cloud failed: $e');
      unawaited(RemoteDebugLogger.instance.logAudio('PLAY_CLOUD_ERROR', '$soundKey: $e'));
    }
  }

  // === UI Sound Effects (local) ===
  Future<void> playClick() => _playLocal(clickPath);
  Future<void> playSelect() => _playLocal(selectPath, volumeOverride: _volume * 0.7);
  Future<void> playTabSwitch() => _playLocal(switchPath, volumeOverride: _volume * 0.5);
  Future<void> playToggle() => _playLocal(togglePath, volumeOverride: _volume * 0.6);
  Future<void> playTick() => _playLocal(tickPath, volumeOverride: _volume * 0.4);
  Future<void> playDrop() => _playLocal(dropPath, volumeOverride: _volume * 0.5);
  Future<void> playSlideUp() => _playLocal(slideUpPath, volumeOverride: _volume * 0.5);
  Future<void> playSlideDown() => _playLocal(slideDownPath, volumeOverride: _volume * 0.5);
  Future<void> playPop() => _playLocal(popPath, volumeOverride: _volume * 0.6);

  // === Generation Sound Effects (cloud) ===
  Future<void> playGenerateStart() => _playCloud('generate', volumeOverride: _volume * 0.8);
  Future<void> playSuccess() => _playCloud('success', volumeOverride: _volume * 0.9);
  Future<void> playError() => _playCloud('error', volumeOverride: _volume * 0.7);
  
  /// Play startup music for 10 seconds
  Future<void> playStartup() async {
    await _ensureInitialized();
    if (_muted) return;
    if (kIsWeb && !_webAudioUnlocked) {
      debugPrint('[Audio] Web audio locked. Startup music suppressed until unlock.');
      return;
    }
    try {
      final url = await _getCloudUrl('startup');
      if (url == null) return;
      final player = _nextPlayer();
      await player.setVolume(_volume * 0.7);
      await player.play(UrlSource(url));
      // Stop after 10 seconds
      Future.delayed(const Duration(seconds: 10), () {
        player.stop();
      });
    } catch (e) {
      debugPrint('[Audio] Startup music failed: $e');
    }
  }

  /// Start generation music (cycles through 5 tracks)
  Future<void> startGenerationLoop() async {
    await _ensureInitialized();
    if (_muted || _isLooping) return;
    try {
      // Get the current track in the cycle
      final trackKey = 'gen_track_$_currentGenTrackIndex';
      final url = await _getCloudUrl(trackKey);
      if (url == null) return;
      
      debugPrint('[Audio] Playing generation track $_currentGenTrackIndex');
      _isLooping = true;
      await _loopPlayer?.setReleaseMode(ReleaseMode.loop);
      await _loopPlayer?.setVolume(_volume * 0.25);
      await _loopPlayer?.play(UrlSource(url));
      
      // Advance to next track for next generation
      _currentGenTrackIndex = (_currentGenTrackIndex + 1) % _totalGenTracks;
    } catch (e) {
      debugPrint('[Audio] Loop start failed: $e');
    }
  }

  /// Stop ambient loop
  Future<void> stopGenerationLoop() async {
    if (!_isLooping) return;
    _isLooping = false;
    try {
      await _loopPlayer?.stop();
    } catch (e) {
      debugPrint('[Audio] Loop stop failed: $e');
    }
  }

  // === Background Music (cloud) ===
  
  /// Available music tracks
  static const List<String> musicTracks = ['music_bestill', 'music_allnight', 'music_notimeleft'];
  static const Map<String, String> musicNames = {
    'music_bestill': 'Be Still',
    'music_allnight': 'All Night (Instrumental)',
    'music_notimeleft': 'No Time Left',
  };

  /// Play background music track
  Future<void> playMusic(String trackKey) async {
    await _ensureInitialized();
    if (_muted) return;
    try {
      // Stop current if playing different track
      if (_isMusicPlaying && _currentMusicTrack != trackKey) {
        await _musicPlayer?.stop();
      }

      final url = await _getCloudUrl(trackKey);
      if (url == null) {
        debugPrint('[Audio] Music track not found: $trackKey');
        return;
      }

      _currentMusicTrack = trackKey;
      _isMusicPlaying = true;
      await _musicPlayer?.setReleaseMode(ReleaseMode.loop);
      await _musicPlayer?.setVolume(_volume * 0.4);
      await _musicPlayer?.play(UrlSource(url));
      debugPrint('[Audio] Playing music: ${musicNames[trackKey]}');
    } catch (e) {
      debugPrint('[Audio] Music play failed: $e');
    }
  }

  /// Stop background music
  Future<void> stopMusic() async {
    if (!_isMusicPlaying) return;
    _isMusicPlaying = false;
    _currentMusicTrack = null;
    try {
      await _musicPlayer?.stop();
    } catch (e) {
      debugPrint('[Audio] Music stop failed: $e');
    }
  }

  /// Pause background music
  Future<void> pauseMusic() async {
    if (!_isMusicPlaying) return;
    try {
      await _musicPlayer?.pause();
    } catch (e) {
      debugPrint('[Audio] Music pause failed: $e');
    }
  }

  /// Resume background music
  Future<void> resumeMusic() async {
    if (!_isMusicPlaying || _currentMusicTrack == null) return;
    try {
      await _musicPlayer?.resume();
    } catch (e) {
      debugPrint('[Audio] Music resume failed: $e');
    }
  }

  /// Set music volume (0.0 - 1.0)
  Future<void> setMusicVolume(double v) async {
    try {
      await _musicPlayer?.setVolume((v * 0.4).clamp(0.0, 1.0));
    } catch (e) {
      debugPrint('[Audio] Set music volume failed: $e');
    }
  }

  bool get isMusicPlaying => _isMusicPlaying;
  String? get currentMusicTrack => _currentMusicTrack;


  void setMuted(bool muted) {
    _muted = muted;
    if (muted) {
      stopMusic();
      stopGenerationLoop();
    }
  }

  void setVolume(double v) => _volume = v.clamp(0.0, 1.0);
  bool get isMuted => _muted;
  double get volume => _volume;
  bool get isWebAudioUnlocked => _webAudioUnlocked;

  /// Temporarily reduce music/loop volume during TTS or other focus audio
  Future<void> setDucking(bool duck) async {
    if (_ducking == duck) return;
    _ducking = duck;
    try {
      if (duck) {
        await _musicPlayer?.setVolume((_volume * 0.12).clamp(0.0, 1.0));
        await _loopPlayer?.setVolume((_volume * 0.08).clamp(0.0, 1.0));
      } else {
        // Restore nominal volumes
        if (_isMusicPlaying) {
          await _musicPlayer?.setVolume((_volume * 0.4).clamp(0.0, 1.0));
        }
        if (_isLooping) {
          await _loopPlayer?.setVolume((_volume * 0.25).clamp(0.0, 1.0));
        }
      }
    } catch (e) {
      debugPrint('[Audio] Ducking failed: $e');
    }
  }

  /// Dispose all players
  Future<void> dispose() async {
    for (final p in _players) {
      await p.dispose();
    }
    await _loopPlayer?.dispose();
    await _musicPlayer?.dispose();
  }

  /// On the web (especially iOS Safari), audio playback is blocked until
  /// a user gesture triggers a play. Call this from any tap to unlock.
  Future<void> unlockWebAudio() async {
    await _ensureInitialized();
    if (!kIsWeb || _webAudioUnlocked) return;
    try {
      // Try to play a very short, low-volume sound to satisfy the gesture
      // Use any available local or cloud sound
      String? url = await _getCloudUrl('success');
      final player = _nextPlayer();
      await player.setVolume(0.0001); // practically silent
      if (url != null) {
        await player.play(UrlSource(url));
      } else if (_hasLocalAssets && clickPath.isNotEmpty) {
        await player.play(AssetSource(clickPath.replaceFirst('assets/', '')));
      }
      // Pause immediately after starting
      await player.pause();
      _webAudioUnlocked = true;
      debugPrint('[Audio] Web audio unlocked');
    } catch (e) {
      debugPrint('[Audio] Web audio unlock failed: $e');
    }
  }
}
