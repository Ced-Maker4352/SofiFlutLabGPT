import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sofi_test_connect/services/storage_service.dart';

/// Cloud-first storage for Sofi Studio history and favorites.
/// - Full images are uploaded to Firebase Storage
/// - Local SharedPreferences store only storage paths (small strings)
/// - Legacy localStorage blobs are ignored/cleaned to prevent QuotaExceeded errors
class CustomDollStorage {
  // Legacy keys (previous implementation)
  static const String _legacyKeyLast = 'custom_doll_last';
  static const String _legacyKeyHistory = 'custom_doll_history';
  static const String _legacyKeyFavorites = 'custom_doll_favorites';

  // New keys (paths only)
  static const String _keyHistoryPaths = 'custom_doll_history_paths';
  static const String _keyFavoritesPaths = 'custom_doll_favorites_paths';
  static const int _maxHistory = 20;
  static const int _maxFavorites = 200;

  static Future<String?> _ensureUid() async {
    try {
      final auth = FirebaseAuth.instance;
      if (auth.currentUser == null) {
        await auth.signInAnonymously();
        debugPrint('[CustomDollStorage] Signed in anonymously');
      }
      return auth.currentUser?.uid;
    } catch (e) {
      debugPrint('[CustomDollStorage] Auth error: $e');
      return null;
    }
  }

  /// Upload latest image to cloud and record its storage path in local pointers list.
  static Future<void> saveLast(Uint8List bytes, {String? prompt}) async {
    final uid = await _ensureUid();
    if (uid == null) return;

    final ts = DateTime.now();
    final fileName = _tsName(ts);
    final path = 'users/$uid/generations/$fileName';

    try {
      await StorageService.instance.uploadBytes(
        bytes,
        path: path,
        contentType: 'image/png',
        customMetadata: {
          'created_at': ts.toIso8601String(),
          if (prompt != null) 'prompt': prompt,
        },
      );
    } catch (e) {
      debugPrint('[CustomDollStorage] upload saveLast failed: $e');
    }

    final prefs = await SharedPreferences.getInstance();
    // Clean legacy big blobs first to free up space
    await _cleanupLegacyIfAny(prefs);
    final paths = List<String>.from(prefs.getStringList(_keyHistoryPaths) ?? const []);
    paths.add(path);
    while (paths.length > _maxHistory) {
      paths.removeAt(0);
    }

    await _persistStringListSafe(prefs, _keyHistoryPaths, paths);
  }

  /// Save current image as a favorite (cloud path pointer locally).
  static Future<void> saveFavorite(Uint8List bytes, {String? prompt}) async {
    final uid = await _ensureUid();
    if (uid == null) return;
    final ts = DateTime.now();
    final fileName = _tsName(ts);
    final path = 'users/$uid/favorites/$fileName';

    try {
      await StorageService.instance.uploadBytes(
        bytes,
        path: path,
        contentType: 'image/png',
        customMetadata: {
          'created_at': ts.toIso8601String(),
          if (prompt != null) 'prompt': prompt,
        },
      );
    } catch (e) {
      debugPrint('[CustomDollStorage] upload saveFavorite failed: $e');
    }

    final prefs = await SharedPreferences.getInstance();
    await _cleanupLegacyIfAny(prefs);
    final paths = List<String>.from(prefs.getStringList(_keyFavoritesPaths) ?? const []);
    paths.add(path);
    while (paths.length > _maxFavorites) {
      paths.removeAt(0);
    }
    await _persistStringListSafe(prefs, _keyFavoritesPaths, paths);
  }

  /// Load recent history images from cloud based on pointers stored locally.
  /// Downloads in reverse order (newest first) so the last image appears quickly.
  static Future<List<Uint8List>> loadHistory({int maxItems = _maxHistory}) async {
    final prefs = await SharedPreferences.getInstance();
    final paths = List<String>.from(prefs.getStringList(_keyHistoryPaths) ?? const []);

    // If no new pointers exist, try legacy local blobs (fallback)
    if (paths.isEmpty) {
      final legacy = prefs.getStringList(_legacyKeyHistory) ?? const [];
      if (legacy.isNotEmpty) {
        debugPrint('[CustomDollStorage] Using legacy local history (will be cleaned)');
        try {
          return legacy.map(_legacyStringToBytes).toList();
        } catch (e) {
          debugPrint('[CustomDollStorage] Legacy decode failed: $e');
          return [];
        }
      }
      return [];
    }

    // Get only the most recent paths up to maxItems
    final recent = paths.length > maxItems ? paths.sublist(paths.length - maxItems) : paths;
    
    // Download newest first (reversed), then reverse back for correct order
    final List<Uint8List> images = [];
    final reversedPaths = recent.reversed.toList();
    
    for (final path in reversedPaths) {
      try {
        final data = await StorageService.instance.downloadBytes(path);
        images.insert(0, data); // Insert at beginning to maintain order
      } catch (e) {
        debugPrint('[CustomDollStorage] download failed for $path: $e');
      }
    }
    return images;
  }

  /// Delete the matching image from cloud and pointer list.
  static Future<void> deleteFromHistory(Uint8List bytes) async {
    final prefs = await SharedPreferences.getInstance();
    final paths = List<String>.from(prefs.getStringList(_keyHistoryPaths) ?? const []);
    if (paths.isEmpty) return;

    // Try to find by comparing bytes
    String? matchPath;
    for (final p in paths) {
      try {
        final data = await StorageService.instance.downloadBytes(p, maxSize: 20 * 1024 * 1024);
        if (_bytesEqual(data, bytes)) {
          matchPath = p;
          break;
        }
      } catch (_) {}
    }

    if (matchPath != null) {
      try {
        await StorageService.instance.delete(matchPath);
      } catch (e) {
        debugPrint('[CustomDollStorage] delete cloud failed for $matchPath: $e');
      }
      paths.remove(matchPath);
      await _persistStringListSafe(prefs, _keyHistoryPaths, paths);
    }
  }

  // ---------- Helpers ----------
  static String _tsName(DateTime ts) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${ts.year}${two(ts.month)}${two(ts.day)}_${two(ts.hour)}${two(ts.minute)}${two(ts.second)}.png';
  }

  static Future<void> _persistStringListSafe(SharedPreferences prefs, String key, List<String> list) async {
    // Attempt to persist, trimming on quota errors (web localStorage)
    var working = List<String>.from(list);
    while (true) {
      try {
        await prefs.setStringList(key, working);
        return;
      } catch (e) {
        debugPrint('[CustomDollStorage] setStringList quota hit on $key: $e');
        if (working.isEmpty) rethrow;
        working.removeAt(0); // drop oldest and retry
      }
    }
  }

  static Future<void> _cleanupLegacyIfAny(SharedPreferences prefs) async {
    try {
      if (prefs.containsKey(_legacyKeyHistory)) {
        await prefs.remove(_legacyKeyHistory);
      }
      if (prefs.containsKey(_legacyKeyFavorites)) {
        await prefs.remove(_legacyKeyFavorites);
      }
      if (prefs.containsKey(_legacyKeyLast)) {
        await prefs.remove(_legacyKeyLast);
      }
    } catch (e) {
      debugPrint('[CustomDollStorage] cleanup legacy failed: $e');
    }
  }

  // Legacy decode for previously stored String.fromCharCodes encoding
  static Uint8List _legacyStringToBytes(String s) => Uint8List.fromList(s.codeUnits);

  static bool _bytesEqual(Uint8List a, Uint8List b) {
    if (identical(a, b)) return true;
    if (a.lengthInBytes != b.lengthInBytes) return false;
    for (int i = 0; i < a.lengthInBytes; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
