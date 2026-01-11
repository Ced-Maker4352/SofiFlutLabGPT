import 'package:flutter/foundation.dart' show ChangeNotifier, kIsWeb, defaultTargetPlatform, TargetPlatform, debugPrint;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/painting.dart';

/// Centralized performance flags to keep iPhone web stable while preserving polish elsewhere.
/// 
/// Includes aggressive memory cleanup for iOS Safari stability (A+B approach).
class PerformanceService extends ChangeNotifier {
  PerformanceService._internal();
  static final PerformanceService _instance = PerformanceService._internal();
  static PerformanceService get instance => _instance;

  static const String _prefKey = 'sofi_performance_mode';
  
  // Default: performance mode ON for iOS Web (where crashes are most likely)
  bool _performanceMode = kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  bool _initialized = false;

  bool get performanceMode => _performanceMode;
  bool get isInitialized => _initialized;

  /// Initialize and load saved preference. Safe to call multiple times.
  Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getBool(_prefKey);
      
      if (saved != null) {
        _performanceMode = saved;
        debugPrint('[PerformanceService] Loaded saved preference: $_performanceMode');
      } else {
        // First time - save the default
        await prefs.setBool(_prefKey, _performanceMode);
        debugPrint('[PerformanceService] No saved preference, using default: $_performanceMode');
      }
    } catch (e) {
      debugPrint('[PerformanceService] Failed to load preference: $e');
      // Keep the default value
    } finally {
      _initialized = true;
      notifyListeners();
    }
  }

  Future<void> setPerformanceMode(bool enabled) async {
    if (_performanceMode == enabled) return;
    
    _performanceMode = enabled;
    debugPrint('[PerformanceService] Performance mode set to: $enabled');
    notifyListeners();
    
    // Persist the change
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKey, enabled);
    } catch (e) {
      debugPrint('[PerformanceService] Failed to save preference: $e');
    }
  }
  
  /// Quick check if we're on iOS web (useful for conditional rendering)
  static bool get isIOSWeb => kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  
  /// Check if heavy effects should be disabled (performance mode ON or iOS web)
  bool get shouldDisableHeavyEffects => _performanceMode || isIOSWeb;
  
  // ---------------------------------------------------------------
  // A) AGGRESSIVE MEMORY CLEANUP (between generations)
  // ---------------------------------------------------------------
  
  /// Clear all cached images to free memory before/after heavy operations.
  /// Call this before starting a new generation and when generation completes.
  Future<void> clearImageCaches() async {
    debugPrint('[PerformanceService] 🧹 Clearing image caches...');
    
    // Clear Flutter's image cache
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    
    // Clear CachedNetworkImage cache (in-memory only, not disk)
    try {
      await CachedNetworkImage.evictFromCache(''); // This won't do much but forces cleanup
    } catch (e) {
      debugPrint('[PerformanceService] CachedNetworkImage evict error (ignorable): $e');
    }
    
    debugPrint('[PerformanceService] ✅ Image caches cleared');
  }
  
  /// Call before starting a generation to prepare memory.
  Future<void> prepareForGeneration() async {
    if (!isIOSWeb && !_performanceMode) return; // Only needed for constrained devices
    
    debugPrint('[PerformanceService] 🚀 Preparing for generation (memory cleanup)...');
    await clearImageCaches();
  }
  
  /// Call after generation completes to free up memory.
  Future<void> cleanupAfterGeneration() async {
    if (!isIOSWeb && !_performanceMode) return;
    
    debugPrint('[PerformanceService] 🏁 Post-generation cleanup...');
    // Small delay to let the result image render first
    await Future.delayed(const Duration(milliseconds: 500));
    await clearImageCaches();
  }
}
