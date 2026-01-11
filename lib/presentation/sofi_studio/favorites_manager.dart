import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/favorite_outfit.dart';
import 'package:sofi_test_connect/services/storage_service.dart';

/// Cloud-first Favorites Manager
/// - Full images live in Firebase Storage (users/<uid>/favorites/)
/// - Local prefs store tiny JSON pointers: [{"path":"...","url":"...", "timestamp":"...","prompt":"..."}]
/// - On load, prioritize using the signed URL to avoid CORS/network issues with raw downloads
class FavoritesManager {
  static const String _keyPaths = "sofi_favorite_paths_v2";
  static const String _legacyKey = "sofi_favorite_outfits";
  static const int _maxFavorites = 200;

  static Future<String?> _ensureUid() async {
    try {
      final auth = FirebaseAuth.instance;
      if (auth.currentUser == null) {
        await auth.signInAnonymously();
        debugPrint('[FavoritesManager] Signed in anonymously');
      }
      return auth.currentUser?.uid;
    } catch (e) {
      debugPrint('[FavoritesManager] Auth error: $e');
      return null;
    }
  }

  /// Load all favorites.
  /// Uses public URLs if available to avoid downloading bytes immediately.
  static Future<List<FavoriteOutfit>> load() async {
    final prefs = await SharedPreferences.getInstance();

    // Clean legacy if it exists
    if (prefs.containsKey(_legacyKey)) {
      try {
        await prefs.remove(_legacyKey);
        debugPrint('[FavoritesManager] Cleaned legacy key');
      } catch (e) {
        debugPrint('[FavoritesManager] Failed to clean legacy: $e');
      }
    }

    final raw = prefs.getString(_keyPaths);
    if (raw == null) return [];

    final List list = jsonDecode(raw);
    final pointers = list.map((item) => _FavoritePointer.fromJson(item)).toList();

    final List<FavoriteOutfit> outfits = [];
    for (final ptr in pointers) {
      // 1. If we have a URL, use it directly (lightweight)
      if (ptr.url != null) {
        outfits.add(FavoriteOutfit(
          imageBytes: null, // Don't download yet
          imageUrl: ptr.url,
          timestamp: ptr.timestamp,
          prompt: ptr.prompt,
        ));
        continue;
      }

      // 2. Fallback: Download images from cloud if no URL stored (legacy pointers)
      try {
        final bytes = await StorageService.instance.downloadBytes(ptr.path);
        outfits.add(FavoriteOutfit(
          imageBytes: bytes,
          imageUrl: null, // We have bytes
          timestamp: ptr.timestamp,
          prompt: ptr.prompt,
        ));
      } catch (e) {
        debugPrint('[FavoritesManager] Failed to download ${ptr.path}: $e');
        // Try to get URL as last resort?
        try {
          final url = await StorageService.instance.getDownloadUrl(ptr.path);
          outfits.add(FavoriteOutfit(
            imageBytes: null,
            imageUrl: url,
            timestamp: ptr.timestamp,
            prompt: ptr.prompt,
          ));
        } catch (e2) {
          debugPrint('[FavoritesManager] Failed to recover URL for ${ptr.path}: $e2');
        }
      }
    }
    return outfits;
  }

  /// Add a single favorite efficiently (uploads only this one, updates pointers)
  static Future<void> addFavorite(FavoriteOutfit outfit) async {
    final uid = await _ensureUid();
    if (uid == null) {
      debugPrint('[FavoritesManager] Cannot save without auth');
      return;
    }

    if (outfit.imageBytes == null) {
      debugPrint('[FavoritesManager] Cannot add favorite without bytes (unless duplicate?)');
      return;
    }

    final ts = outfit.timestamp;
    final fileName = _tsName(ts);
    final path = 'users/$uid/favorites/$fileName';
    String? downloadUrl;

    // 1. Upload to cloud
    try {
      downloadUrl = await StorageService.instance.uploadBytes(
        outfit.imageBytes!,
        path: path,
        contentType: 'image/png',
        customMetadata: {
          'created_at': ts.toIso8601String(),
          if (outfit.prompt.isNotEmpty) 'prompt': outfit.prompt,
        },
      );
    } catch (e) {
      debugPrint('[FavoritesManager] Upload failed for $fileName: $e');
      rethrow;
    }

    // 2. Update local pointers
    final prefs = await SharedPreferences.getInstance();
    List<_FavoritePointer> pointers = [];
    final raw = prefs.getString(_keyPaths);

    if (raw != null) {
      try {
        final List list = jsonDecode(raw);
        pointers = list.map((item) => _FavoritePointer.fromJson(item)).toList();
      } catch (e) {
        debugPrint('[FavoritesManager] Error parsing existing pointers: $e');
      }
    }

    // Insert new pointer at start
    pointers.insert(0, _FavoritePointer(
      path: path,
      url: downloadUrl,
      timestamp: ts,
      prompt: outfit.prompt,
    ));

    // Trim to max
    if (pointers.length > _maxFavorites) {
      pointers = pointers.take(_maxFavorites).toList();
    }

    // Save back to prefs
    final encoded = jsonEncode(pointers.map((p) => p.toJson()).toList());
    await prefs.setString(_keyPaths, encoded);
  }

  /// Save all favorites: upload images to cloud (if bytes present) and store pointers locally
  static Future<void> saveAll(List<FavoriteOutfit> outfits) async {
    final uid = await _ensureUid();
    if (uid == null) {
      debugPrint('[FavoritesManager] Cannot save without auth');
      return;
    }

    final trimmed = outfits.take(_maxFavorites).toList();
    final List<_FavoritePointer> pointers = [];

    for (final outfit in trimmed) {
      final ts = outfit.timestamp;
      final fileName = _tsName(ts);
      final path = 'users/$uid/favorites/$fileName';
      String? url = outfit.imageUrl;

      // Upload to cloud (idempotent if already exists)
      if (outfit.imageBytes != null) {
        try {
          url = await StorageService.instance.uploadBytes(
            outfit.imageBytes!,
            path: path,
            contentType: 'image/png',
            customMetadata: {
              'created_at': ts.toIso8601String(),
              if (outfit.prompt.isNotEmpty) 'prompt': outfit.prompt,
            },
          );
        } catch (e) {
          debugPrint('[FavoritesManager] Upload failed for $fileName: $e');
        }
      } else if (url == null) {
        // No bytes and no URL? Try to fetch URL
        try {
          url = await StorageService.instance.getDownloadUrl(path);
        } catch (e) {
          debugPrint('[FavoritesManager] Could not find URL for $fileName: $e');
        }
      }

      if (url != null || outfit.imageBytes != null) {
        // Only save pointer if we have a valid reference (URL or we just uploaded it)
        pointers.add(_FavoritePointer(
          path: path,
          url: url, // Might be null if upload failed, but we preserve path
          timestamp: ts,
          prompt: outfit.prompt,
        ));
      }
    }

    // Save pointers locally
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(pointers.map((p) => p.toJson()).toList());
    try {
      await prefs.setString(_keyPaths, encoded);
    } catch (e) {
      debugPrint('[FavoritesManager] Failed to save pointers: $e');
    }
  }

  static Future<void> save(List<FavoriteOutfit> outfits) => saveAll(outfits);

  static String _tsName(DateTime ts) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${ts.year}${two(ts.month)}${two(ts.day)}_${two(ts.hour)}${two(ts.minute)}${two(ts.second)}.png';
  }
}

/// Lightweight pointer stored in local prefs (no image bytes)
class _FavoritePointer {
  final String path;
  final String? url;
  final DateTime timestamp;
  final String prompt;

  _FavoritePointer({
    required this.path,
    this.url,
    required this.timestamp,
    required this.prompt,
  });

  Map<String, dynamic> toJson() => {
    'path': path,
    if (url != null) 'url': url,
    'timestamp': timestamp.toIso8601String(),
    'prompt': prompt,
  };

  factory _FavoritePointer.fromJson(Map<String, dynamic> json) => _FavoritePointer(
    path: json['path'] as String,
    url: json['url'] as String?,
    timestamp: DateTime.parse(json['timestamp'] as String),
    prompt: json['prompt'] as String? ?? '',
  );
}
