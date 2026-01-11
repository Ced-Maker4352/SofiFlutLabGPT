import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:firebase_storage/firebase_storage.dart';

class SofiMusicPage extends StatefulWidget {
  const SofiMusicPage({super.key});

  @override
  State<SofiMusicPage> createState() => _SofiMusicPageState();
}

class _SofiMusicPageState extends State<SofiMusicPage> with SingleTickerProviderStateMixin {
  // Sofi Saint tracks (cloud paths)
  final List<Map<String, String>> _tracks = [
    {'title': 'All Night (Instrumental)', 'artist': 'Sofi Saint', 'cloudPath': 'audio/Sofi Saint - All Night  INSTRO.mp3', 'duration': '3:42'},
    {'title': 'No Time Left', 'artist': 'Sofi Saint', 'cloudPath': 'audio/Sofi Saint NO TIME LEFT - No Time Left.mp3', 'duration': '4:15'},
    {'title': 'Be Still', 'artist': 'Sofi Saint', 'cloudPath': 'audio/01 - Sofi Saint - Be Still.mp3', 'duration': '3:58'},
  ];

  // Cached download URLs
  final Map<int, String> _urlCache = {};
  final Map<int, bool> _loadingTracks = {};

  // Featured playlists (visual/mood boards)
  final List<Map<String, String>> _playlists = [
    {'title': 'Runway Energy', 'subtitle': 'High BPM for High Fashion', 'image': 'assets/images/High_fashion_runway_model_energy_pink_1766290025297.jpg', 'duration': '45 min'},
    {'title': 'Lo-Fi Studio', 'subtitle': 'Chill beats to design to', 'image': 'assets/images/Abstract_album_art_chill_lo-fi_lilac_1766290024247.png', 'duration': '1 hr 20 min'},
    {'title': 'Deep Focus', 'subtitle': 'Ambient waves for concentration', 'image': 'assets/images/Deep_focus_abstract_waves_blue_1766290025987.png', 'duration': '2 hrs'},
    {'title': 'Neon Nights', 'subtitle': 'Cyberpunk synthwave', 'image': 'assets/images/Cyberpunk_city_night_neon_turquoise_1766290027120.jpg', 'duration': '55 min'},
  ];

  late final AudioPlayer _player;
  late final AnimationController _rotationController;
  int _currentTrackIndex = -1;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _showNowPlaying = false;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _rotationController = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat();

    _player.playerStateStream.listen((state) {
      if (!mounted) return;
      setState(() => _isPlaying = state.playing);
      if (state.playing) {
        _rotationController.repeat();
      } else {
        _rotationController.stop();
      }
    });

    _player.positionStream.listen((pos) {
      if (!mounted) return;
      setState(() => _position = pos);
    });

    _player.durationStream.listen((dur) {
      if (!mounted) return;
      setState(() => _duration = dur ?? Duration.zero);
    });

    // Pre-fetch URLs in background
    _prefetchUrls();
  }

  Future<void> _prefetchUrls() async {
    for (int i = 0; i < _tracks.length; i++) {
      _getTrackUrl(i); // Fire and forget
    }
  }

  Future<String?> _getTrackUrl(int index) async {
    if (_urlCache.containsKey(index)) return _urlCache[index];
    final cloudPath = _tracks[index]['cloudPath'];
    if (cloudPath == null) return null;
    try {
      // Use ref() with path instead of refFromURL() for proper path handling
      final ref = FirebaseStorage.instance.ref(cloudPath);
      final url = await ref.getDownloadURL();
      _urlCache[index] = url;
      debugPrint('[SofiMusic] Cached URL for track $index: ${_tracks[index]['title']} -> $url');
      return url;
    } catch (e) {
      debugPrint('[SofiMusic] Failed to get URL for track $index (${_tracks[index]['title']}): $e');
      return null;
    }
  }

  @override
  void dispose() {
    _player.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  Future<void> _playTrack(int index) async {
    if (_loadingTracks[index] == true) return;

    setState(() => _loadingTracks[index] = true);

    try {
      // Clear cached URL to force fresh fetch (helps debug issues)
      _urlCache.remove(index);
      
      final url = await _getTrackUrl(index);
      if (url == null) {
        if (!mounted) return;
        setState(() => _loadingTracks[index] = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not load track: ${_tracks[index]['title']}'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      debugPrint('[SofiMusic] Playing track $index: "${_tracks[index]['title']}"');
      debugPrint('[SofiMusic] URL: $url');
      
      // Stop current playback before setting new URL
      await _player.stop();
      await _player.setUrl(url);
      await _player.play();
      
      if (!mounted) return;
      setState(() {
        _currentTrackIndex = index;
        _loadingTracks[index] = false;
      });
    } catch (e) {
      debugPrint('[SofiMusic] Error playing track $index: $e');
      if (!mounted) return;
      setState(() => _loadingTracks[index] = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not play track: ${_tracks[index]['title']}'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _toggleTrack(int index) async {
    if (_currentTrackIndex == index && _isPlaying) {
      await _player.pause();
    } else if (_currentTrackIndex == index && !_isPlaying) {
      await _player.play();
    } else {
      await _playTrack(index);
    }
  }

  Future<void> _skipNext() async {
    if (_currentTrackIndex < _tracks.length - 1) {
      await _playTrack(_currentTrackIndex + 1);
    } else {
      await _playTrack(0);
    }
  }

  Future<void> _skipPrevious() async {
    if (_position.inSeconds > 3) {
      await _player.seek(Duration.zero);
    } else if (_currentTrackIndex > 0) {
      await _playTrack(_currentTrackIndex - 1);
    } else {
      await _playTrack(_tracks.length - 1);
    }
  }

  String _formatDuration(Duration d) => '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Sofi Music', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.search_rounded), onPressed: () {}),
          const SizedBox(width: 8),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A0A2E), Color(0xFF0D0D0D), Colors.black],
            stops: [0.0, 0.4, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: _showNowPlaying ? _buildNowPlayingView() : _buildLibraryView(),
              ),
              if (_currentTrackIndex != -1) _buildMiniPlayer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLibraryView() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      // Sofi Saint Section
      _buildSectionHeader('Sofi Saint', icon: Icons.verified, iconColor: const Color(0xFFE040FB)),
      const SizedBox(height: 12),
      ..._tracks.asMap().entries.map((e) => _buildTrackTile(e.key)),
      const SizedBox(height: 32),

      // Featured Vibe
      _buildSectionHeader('Featured Vibe', subtitle: 'Exclusive'),
      const SizedBox(height: 12),
      _buildHeroCard(_playlists[0]),
      const SizedBox(height: 32),

      // Your Mixes
      _buildSectionHeader('Your Mixes'),
      const SizedBox(height: 16),
      SizedBox(
        height: 200,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _playlists.length - 1,
          separatorBuilder: (_, __) => const SizedBox(width: 16),
          itemBuilder: (_, i) => _buildPlaylistCard(_playlists[i + 1]),
        ),
      ),
      const SizedBox(height: 32),

      // All Playlists
      _buildSectionHeader('All Playlists'),
      const SizedBox(height: 12),
      ..._playlists.map(_buildPlaylistRow),
      const SizedBox(height: 100),
    ],
  );

  Widget _buildSectionHeader(String title, {String? subtitle, IconData? icon, Color? iconColor}) => Row(
    children: [
      Text(title, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
      if (icon != null) ...[
        const SizedBox(width: 8),
        Icon(icon, size: 20, color: iconColor ?? Colors.white),
      ],
      const Spacer(),
      if (subtitle != null)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFFE040FB), Color(0xFF7C4DFF)]),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(subtitle, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
        ),
    ],
  );

  Widget _buildTrackTile(int index) {
    final track = _tracks[index];
    final isCurrent = index == _currentTrackIndex;
    final isActive = isCurrent && _isPlaying;
    final isLoading = _loadingTracks[index] == true;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        gradient: isCurrent
            ? LinearGradient(colors: [const Color(0xFF7C4DFF).withValues(alpha: 0.3), const Color(0xFFE040FB).withValues(alpha: 0.1)])
            : null,
        color: isCurrent ? null : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrent ? const Color(0xFFE040FB).withValues(alpha: 0.5) : Colors.transparent,
          width: isCurrent ? 1 : 0,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isActive ? [const Color(0xFFE040FB), const Color(0xFF7C4DFF)] : [Colors.purple.withValues(alpha: 0.3), Colors.purple.withValues(alpha: 0.1)],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: isActive
              ? const _EqualizerAnimation()
              : const Icon(Icons.music_note_rounded, color: Colors.white70, size: 24),
        ),
        title: Text(track['title']!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: isCurrent ? const Color(0xFFE040FB) : Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
        subtitle: Row(
          children: [
            Text(track['artist']!, style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13)),
            const SizedBox(width: 8),
            Text(track['duration']!, style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12)),
          ],
        ),
        trailing: isLoading
            ? const SizedBox(width: 40, height: 40, child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFE040FB))))
            : IconButton(
                icon: Icon(isActive ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded, color: isCurrent ? const Color(0xFFE040FB) : Colors.white70, size: 40),
                onPressed: () => _toggleTrack(index),
              ),
        onTap: () => _toggleTrack(index),
      ),
    );
  }

  Widget _buildHeroCard(Map<String, String> playlist) => GestureDetector(
    onTap: () => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${playlist['title']} - Coming Soon!'), behavior: SnackBarBehavior.floating, backgroundColor: const Color(0xFF7C4DFF)),
    ),
    child: Container(
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        image: DecorationImage(image: AssetImage(playlist['image']!), fit: BoxFit.cover, colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: 0.3), BlendMode.darken)),
        boxShadow: [BoxShadow(color: const Color(0xFFE040FB).withValues(alpha: 0.3), blurRadius: 24, offset: const Offset(0, 12))],
      ),
      child: Stack(
        children: [
          // Gradient overlay
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withValues(alpha: 0.8)],
              ),
            ),
          ),
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(playlist['title']!, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold, height: 1.1)),
                const SizedBox(height: 4),
                Text(playlist['subtitle']!, style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 14)),
              ],
            ),
          ),
          Positioned(
            bottom: 20,
            right: 20,
            child: Container(
              decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [Color(0xFFE040FB), Color(0xFF7C4DFF)])),
              child: const Padding(padding: EdgeInsets.all(12), child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28)),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildPlaylistCard(Map<String, String> playlist) => GestureDetector(
    onTap: () {},
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            image: DecorationImage(image: AssetImage(playlist['image']!), fit: BoxFit.cover),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 6))],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: 140,
          child: Text(playlist['title']!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        Text(playlist['duration']!, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
      ],
    ),
  );

  Widget _buildPlaylistRow(Map<String, String> playlist) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    child: ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), image: DecorationImage(image: AssetImage(playlist['image']!), fit: BoxFit.cover)),
      ),
      title: Text(playlist['title']!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      subtitle: Text(playlist['subtitle']!, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13)),
      trailing: Text(playlist['duration']!, style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12)),
    ),
  );

  Widget _buildMiniPlayer() {
    final track = _tracks[_currentTrackIndex];
    final progress = _duration.inMilliseconds > 0 ? _position.inMilliseconds / _duration.inMilliseconds : 0.0;

    return GestureDetector(
      onTap: () => setState(() => _showNowPlaying = true),
      onVerticalDragEnd: (d) {
        if (d.primaryVelocity != null && d.primaryVelocity! < -200) setState(() => _showNowPlaying = true);
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF2D1B4E), Color(0xFF1A1A2E)]),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: const Color(0xFFE040FB).withValues(alpha: 0.2), blurRadius: 16, offset: const Offset(0, 4))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Progress bar
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: LinearProgressIndicator(value: progress, backgroundColor: Colors.white.withValues(alpha: 0.1), valueColor: const AlwaysStoppedAnimation(Color(0xFFE040FB)), minHeight: 3),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Album art
                  AnimatedBuilder(
                    animation: _rotationController,
                    builder: (_, child) => Transform.rotate(
                      angle: _isPlaying ? _rotationController.value * 2 * 3.14159 : 0,
                      child: child,
                    ),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(colors: [Color(0xFFE040FB), Color(0xFF7C4DFF)]),
                        boxShadow: [BoxShadow(color: const Color(0xFFE040FB).withValues(alpha: 0.4), blurRadius: 8)],
                      ),
                      child: const Icon(Icons.music_note_rounded, color: Colors.white, size: 24),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Track info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(track['title']!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text(track['artist']!, style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12)),
                      ],
                    ),
                  ),
                  // Controls
                  IconButton(icon: const Icon(Icons.skip_previous_rounded), color: Colors.white70, iconSize: 28, onPressed: _skipPrevious),
                  Container(
                    decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [Color(0xFFE040FB), Color(0xFF7C4DFF)])),
                    child: IconButton(
                      icon: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
                      color: Colors.white,
                      iconSize: 28,
                      onPressed: () => _toggleTrack(_currentTrackIndex),
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.skip_next_rounded), color: Colors.white70, iconSize: 28, onPressed: _skipNext),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNowPlayingView() => Container(
    padding: const EdgeInsets.all(24),
    child: Column(
      children: [
        // Drag indicator
        GestureDetector(
          onTap: () => setState(() => _showNowPlaying = false),
          child: Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)),
          ),
        ),

        // Album art
        Expanded(
          flex: 3,
          child: Center(
            child: AnimatedBuilder(
              animation: _rotationController,
              builder: (_, child) => Transform.rotate(
                angle: _isPlaying ? _rotationController.value * 2 * 3.14159 : 0,
                child: child,
              ),
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFE040FB), Color(0xFF7C4DFF), Color(0xFF1A0A2E)],
                  ),
                  boxShadow: [BoxShadow(color: const Color(0xFFE040FB).withValues(alpha: 0.4), blurRadius: 40, spreadRadius: 4)],
                ),
                child: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF1A0A2E),
                    border: Border.all(color: const Color(0xFFE040FB).withValues(alpha: 0.3), width: 2),
                  ),
                  child: const Center(child: Icon(Icons.music_note_rounded, color: Colors.white, size: 80)),
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 32),

        // Track info
        if (_currentTrackIndex != -1) ...[
          Text(_tracks[_currentTrackIndex]['title']!, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(_tracks[_currentTrackIndex]['artist']!, style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 16)),
        ],

        const SizedBox(height: 32),

        // Progress bar
        Column(
          children: [
            SliderTheme(
              data: SliderThemeData(
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                activeTrackColor: const Color(0xFFE040FB),
                inactiveTrackColor: Colors.white.withValues(alpha: 0.2),
                thumbColor: Colors.white,
                overlayColor: const Color(0xFFE040FB).withValues(alpha: 0.2),
              ),
              child: Slider(
                value: _duration.inMilliseconds > 0 ? _position.inMilliseconds / _duration.inMilliseconds : 0.0,
                onChanged: (v) => _player.seek(Duration(milliseconds: (v * _duration.inMilliseconds).toInt())),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_formatDuration(_position), style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12)),
                  Text(_formatDuration(_duration), style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12)),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Controls
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(icon: const Icon(Icons.shuffle_rounded), color: Colors.white54, iconSize: 28, onPressed: () {}),
            const SizedBox(width: 16),
            IconButton(icon: const Icon(Icons.skip_previous_rounded), color: Colors.white, iconSize: 40, onPressed: _skipPrevious),
            const SizedBox(width: 16),
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(colors: [Color(0xFFE040FB), Color(0xFF7C4DFF)]),
                boxShadow: [BoxShadow(color: const Color(0xFFE040FB).withValues(alpha: 0.5), blurRadius: 20)],
              ),
              child: IconButton(
                icon: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
                color: Colors.white,
                iconSize: 48,
                padding: const EdgeInsets.all(16),
                onPressed: () => _toggleTrack(_currentTrackIndex),
              ),
            ),
            const SizedBox(width: 16),
            IconButton(icon: const Icon(Icons.skip_next_rounded), color: Colors.white, iconSize: 40, onPressed: _skipNext),
            const SizedBox(width: 16),
            IconButton(icon: const Icon(Icons.repeat_rounded), color: Colors.white54, iconSize: 28, onPressed: () {}),
          ],
        ),

        const SizedBox(height: 24),
      ],
    ),
  );
}

/// Animated equalizer bars for currently playing track
class _EqualizerAnimation extends StatefulWidget {
  const _EqualizerAnimation();

  @override
  State<_EqualizerAnimation> createState() => _EqualizerAnimationState();
}

class _EqualizerAnimationState extends State<_EqualizerAnimation> with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;
  late final List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(3, (i) => AnimationController(vsync: this, duration: Duration(milliseconds: 300 + i * 100))..repeat(reverse: true));
    _animations = _controllers.map((c) => Tween<double>(begin: 0.3, end: 1.0).animate(CurvedAnimation(parent: c, curve: Curves.easeInOut))).toList();
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: List.generate(3, (i) => AnimatedBuilder(
      animation: _animations[i],
      builder: (_, __) => Container(
        width: 4,
        height: 20 * _animations[i].value,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(2)),
      ),
    )),
  );
}
