import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform;
import 'package:google_fonts/google_fonts.dart';
import 'package:sofi_test_connect/presentation/sofi_studio/sofi_studio_theme.dart';
import 'package:sofi_test_connect/services/audio_service.dart';
import 'package:sofi_test_connect/services/performance_service.dart';
import 'package:sofi_test_connect/services/storage_service.dart';

class GenerationLoader extends StatefulWidget {
  // Pre-define BorderRadius constants (Flutter Web crash fix)
  static const _radius24 = BorderRadius.all(Radius.circular(24));
  static const _radius16 = BorderRadius.all(Radius.circular(16));
  
  final List<Uint8List> historyImages;
  final List<String> premiumAssetPaths;

  const GenerationLoader({
    super.key,
    required this.historyImages,
    required this.premiumAssetPaths,
  });

  @override
  State<GenerationLoader> createState() => _GenerationLoaderState();
}

class _GenerationLoaderState extends State<GenerationLoader> with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  Timer? _timer;
  
  // Animation controllers
  late final AnimationController _pulseController;
  late final AnimationController _shimmerController;
  late final Animation<double> _pulseAnimation;
  
  // Combine sources into a unified list (NOT late final - can be rebuilt)
  List<_LoaderItem> _items = [];
  bool _itemsPrepared = false;
  
  // Status messages that cycle
  final List<String> _statusMessages = [
    'Creating Magic...',
    'Designing your look...',
    'Adding final touches...',
    'Almost there...',
    'Styling in progress...',
  ];
  int _currentMessageIndex = 0;
  Timer? _messageTimer;

  bool get _isIOSWeb => kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void initState() {
    super.initState();
    _prepareItems();
    
    // Pulse animation for the spinner
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
    
    // Shimmer animation
    _shimmerController = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))..repeat();
    
    // Start ambient sound loop
    AudioService.instance.startGenerationLoop();
    
    // Cycle status messages
    _messageTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) {
        setState(() => _currentMessageIndex = (_currentMessageIndex + 1) % _statusMessages.length);
      }
    });
    
    // Start auto-scroll after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startAutoScroll();
    });
  }

  void _prepareItems() {
    // Only prepare once to avoid "already initialized" errors
    if (_itemsPrepared) return;
    _itemsPrepared = true;
    
    final tempList = <_LoaderItem>[];
    
    // 1. Add history images
    for (final bytes in widget.historyImages.reversed) {
      tempList.add(_LoaderItem(bytes: bytes));
    }
    
    // 2. Supplement with premium assets if history is low
    // These are Firebase Storage paths, not local assets
    if (tempList.length < 10) {
      int premiumIndex = 0;
      while (tempList.length < 10 && widget.premiumAssetPaths.isNotEmpty) {
        tempList.add(_LoaderItem(
          assetPath: widget.premiumAssetPaths[premiumIndex % widget.premiumAssetPaths.length],
          isStoragePath: true,
        ));
        premiumIndex++;
      }
    }
    
    // iOS Web memory guard: keep the loader very light (max 6 items)
    final maxItems = _isIOSWeb ? 6 : tempList.length;
    _items = tempList.take(maxItems).toList();
  }

  void _startAutoScroll() {
    if (_items.isEmpty) return;
    
    // Constant speed scroll
    // We animate a small distance repeatedly to create smooth motion
    const double speed = 50.0; // pixels per second
    const Duration tick = Duration(milliseconds: 16); // ~60fps
    
    // Simple approach: linear animation to max extent, then jump back?
    // Infinite list view is better.
    
    _timer = Timer.periodic(tick, (timer) {
      if (!_scrollController.hasClients) return;
      
      // Calculate new offset
      // We rely on the infinite list builder, so we just keep scrolling right forever
      double newOffset = _scrollController.offset + (speed * tick.inMilliseconds / 1000);
      _scrollController.jumpTo(newOffset);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _messageTimer?.cancel();
    _pulseController.dispose();
    _shimmerController.dispose();
    _scrollController.dispose();
    // Stop ambient sound
    AudioService.instance.stopGenerationLoop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Use the centralized performance check
    final disableEffects = PerformanceService.instance.shouldDisableHeavyEffects;

    // Minimal mode: eliminate image loading entirely (prevents iOS Web reloads)
    if (disableEffects || _items.isEmpty) {
      return Container(
        decoration: const BoxDecoration(color: Colors.black87),
        alignment: Alignment.center,
        child: _buildSpinnerSection(),
      );
    }

    // Rich mode (non-iOS web, and performance mode off)
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.7),
            Colors.black.withValues(alpha: 0.5),
            Colors.black.withValues(alpha: 0.7),
          ],
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            height: _isIOSWeb ? 200 : 240,
            child: ListView.builder(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              itemBuilder: (context, index) {
                final item = _items[index % _items.length];
                return _buildCard(item);
              },
            ),
          ),
          _buildSpinnerSection(),
        ],
      ),
    );
  }
  
  Widget _buildSpinnerSection() {
    final disableEffects = PerformanceService.instance.shouldDisableHeavyEffects;
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Pulsing spinner container
        ScaleTransition(
          scale: _pulseAnimation,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  SofiStudioTheme.purple.withValues(alpha: 0.8),
                  SofiStudioTheme.purple.withValues(alpha: 0.5),
                ],
              ),
              shape: BoxShape.circle,
              // Disable shadows in performance mode
              boxShadow: disableEffects ? null : [
                BoxShadow(
                  color: SofiStudioTheme.purple.withValues(alpha: 0.4),
                  blurRadius: 30,
                  spreadRadius: 8,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: const SizedBox(
              width: 44, 
              height: 44, 
              child: CircularProgressIndicator(strokeWidth: 3.5, color: Colors.white),
            ),
          ),
        ),
        const SizedBox(height: 20),
        // Animated status text
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(animation),
              child: child,
            ),
          ),
          child: Container(
            key: ValueKey(_currentMessageIndex),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: GenerationLoader._radius24,
              // Disable borders in performance mode (iOS Web crash guard)
              border: disableEffects ? null : Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome, size: 16, color: Colors.white.withValues(alpha: 0.9)),
                const SizedBox(width: 8),
                Text(
                  _statusMessages[_currentMessageIndex],
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCard(_LoaderItem item) {
    final disableEffects = PerformanceService.instance.shouldDisableHeavyEffects;
    
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        final shimmerValue = _shimmerController.value;
        return Container(
          width: disableEffects ? 140 : 160,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: GenerationLoader._radius16,
            // Disable shadows in performance mode
            boxShadow: disableEffects ? null : [
              BoxShadow(
                color: SofiStudioTheme.purple.withValues(alpha: 0.15 + shimmerValue * 0.1),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              item.bytes != null
                  ? Image.memory(item.bytes!, fit: BoxFit.cover)
                  : item.isStoragePath
                      ? _StorageImage(item: item)
                      : Image.asset(item.assetPath!, fit: BoxFit.cover),
              // Subtle shimmer overlay (disabled in performance mode)
              if (!disableEffects)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment(-1.5 + shimmerValue * 3, 0),
                        end: Alignment(-0.5 + shimmerValue * 3, 0),
                        colors: [
                          Colors.white.withValues(alpha: 0.0),
                          Colors.white.withValues(alpha: 0.15),
                          Colors.white.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _LoaderItem {
  final Uint8List? bytes;
  final String? assetPath;
  final bool isStoragePath;
  String? cachedUrl;
  
  _LoaderItem({this.bytes, this.assetPath, this.isStoragePath = false});
}

/// Helper widget to load images from Firebase Storage for the loader
class _StorageImage extends StatefulWidget {
  final _LoaderItem item;

  const _StorageImage({required this.item});

  @override
  State<_StorageImage> createState() => _StorageImageState();
}

class _StorageImageState extends State<_StorageImage> {
  String? _url;
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _loadUrl();
  }

  Future<void> _loadUrl() async {
    // Use cached URL if available
    if (widget.item.cachedUrl != null) {
      if (mounted) {
        setState(() {
          _url = widget.item.cachedUrl;
          _loading = false;
        });
      }
      return;
    }

    try {
      final url = await StorageService.instance.getDownloadUrl(widget.item.assetPath!);
      widget.item.cachedUrl = url; // Cache for future use
      if (mounted) {
        setState(() {
          _url = url;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('[GenerationLoader] Failed to load storage image: $e');
      if (mounted) {
        setState(() {
          _error = true;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        color: Colors.grey.shade200,
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (_error || _url == null) {
      return Container(
        color: Colors.grey.shade300,
        child: const Center(child: Icon(Icons.broken_image, size: 24, color: Colors.grey)),
      );
    }
    return Image.network(
      _url!,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        color: Colors.grey.shade300,
        child: const Center(child: Icon(Icons.broken_image, size: 24, color: Colors.grey)),
      ),
    );
  }
}
