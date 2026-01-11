import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;

// Platform-aware file reading: on IO, read bytes from path; on Web, throw.
import 'platform_file_bytes_stub.dart'
    if (dart.library.io) 'platform_file_bytes_io.dart'
    if (dart.library.html) 'platform_file_bytes_web.dart';

/// A small helper around Firebase Storage for uploads, downloads and management.
class StorageService {
  StorageService._();

  static final StorageService instance = StorageService._();
  final FirebaseStorage _storage = FirebaseStorage.instance;
  
  /// Cache for download URLs to avoid repeated Firebase calls
  final Map<String, String> _urlCache = {};
  
  /// Track pending URL requests to avoid duplicate concurrent fetches
  final Map<String, Future<String?>> _pendingRequests = {};
  
  /// Whether drawer URLs have been pre-cached
  bool _drawerUrlsCached = false;

  /// Upload raw bytes to the given [path]. Returns the public download URL.
  Future<String> uploadBytes(Uint8List data, {required String path, String? contentType, Map<String, String>? customMetadata}) async {
    try {
      debugPrint('[Storage] Uploading ${data.length} bytes to $path');
      final ref = _storage.ref().child(path);
      final metadata = SettableMetadata(contentType: contentType, customMetadata: customMetadata);
      await ref.putData(data, metadata);
      final url = await ref.getDownloadURL();
      debugPrint('[Storage] Uploaded to $path, url: $url');
      return url;
    } catch (e, st) {
      debugPrint('[Storage] uploadBytes failed: $e\n$st');
      rethrow;
    }
  }

  /// Upload a local file by path. Returns the public download URL.
  Future<String> uploadFilePath(String filePath, {required String path, String? contentType, Map<String, String>? customMetadata}) async {
    try {
      debugPrint('[Storage] Uploading file $filePath to $path');
      final ref = _storage.ref().child(path);
      final metadata = SettableMetadata(contentType: contentType, customMetadata: customMetadata);
      final data = await readFileBytes(filePath);
      await ref.putData(data, metadata);
      final url = await ref.getDownloadURL();
      debugPrint('[Storage] Uploaded to $path, url: $url');
      return url;
    } catch (e, st) {
      debugPrint('[Storage] uploadFilePath failed: $e\n$st');
      rethrow;
    }
  }

  /// Get a public download URL for an existing object.
  /// Uses caching to avoid repeated Firebase calls.
  /// Deduplicates concurrent requests for the same path.
  Future<String> getDownloadUrl(String path) async {
    // Check cache first
    if (_urlCache.containsKey(path)) {
      return _urlCache[path]!;
    }
    
    // If there's already a pending request for this path, wait for it
    if (_pendingRequests.containsKey(path)) {
      final result = await _pendingRequests[path];
      if (result != null) return result;
      throw Exception('Failed to get URL for $path');
    }
    
    // Create a new request and store it
    final future = _fetchUrlInternal(path);
    _pendingRequests[path] = future;
    
    try {
      final result = await future;
      if (result != null) return result;
      throw Exception('Failed to get URL for $path');
    } finally {
      _pendingRequests.remove(path);
    }
  }
  
  Future<String?> _fetchUrlInternal(String path) async {
    try {
      final ref = _storage.ref().child(path);
      final url = await ref.getDownloadURL();
      _urlCache[path] = url; // Cache the URL
      return url;
    } catch (e) {
      debugPrint('[Storage] getDownloadUrl failed for $path: $e');
      return null;
    }
  }
  
  /// Get a public download URL, returning null on error instead of throwing.
  Future<String?> getDownloadUrlSafe(String path) async {
    // Check cache first (immediate return)
    if (_urlCache.containsKey(path)) return _urlCache[path]!;

    // If there's already a pending request, wait for it
    if (_pendingRequests.containsKey(path)) return await _pendingRequests[path];

    // Try primary path
    final primary = _fetchUrlInternal(path);
    _pendingRequests[path] = primary;
    String? url;
    try {
      url = await primary;
    } finally {
      _pendingRequests.remove(path);
    }

    if (url != null) return url;

    // Fallback attempts: handle common legacy/storage mismatches without breaking callers
    for (final alt in _generateAlternatePaths(path)) {
      // Skip if already cached
      if (_urlCache.containsKey(alt)) {
        final cached = _urlCache[alt]!;
        // Cache under original key too for future lookups
        _urlCache[path] = cached;
        debugPrint('[Storage] Using cached fallback for $path => $alt');
        return cached;
      }

      // Deduplicate concurrent fallback fetches
      if (_pendingRequests.containsKey(alt)) {
        final res = await _pendingRequests[alt];
        if (res != null) {
          _urlCache[path] = res; // cache under original as well
          debugPrint('[Storage] Fallback resolved $path => $alt');
          return res;
        }
        continue;
      }

      final future = _fetchUrlInternal(alt);
      _pendingRequests[alt] = future;
      try {
        final res = await future;
        if (res != null) {
          // Cache under both original and alternate
          _urlCache[path] = res;
          debugPrint('[Storage] Fallback matched $path => $alt');
          return res;
        }
      } finally {
        _pendingRequests.remove(alt);
      }
    }

    // Still not found
    debugPrint('[Storage] No URL for $path after fallbacks');
    return null;
  }
  
  /// Get cached URL immediately without network request.
  /// Returns null if not in cache.
  String? getCachedUrl(String path) => _urlCache[path];

  /// Generate alternate candidate paths for common legacy variations.
  /// Examples handled:
  /// - .jpg <-> .png
  /// - images/posses/... <-> images/poses/...
  /// - pose_XX <-> poses_XX filename stems
  List<String> _generateAlternatePaths(String path) {
    final alts = <String>{};

    String swapExt(String p, String from, String to) =>
        p.toLowerCase().endsWith(from) ? p.substring(0, p.length - from.length) + to : p;

    // 1) Extension swap
    final pngFromJpg = swapExt(path, '.jpg', '.png');
    final jpgFromPng = swapExt(path, '.png', '.jpg');
    if (pngFromJpg != path) alts.add(pngFromJpg);
    if (jpgFromPng != path) alts.add(jpgFromPng);

    // 2) Folder typo: posses -> poses, and reverse just in case
    if (path.contains('/posses/')) alts.add(path.replaceFirst('/posses/', '/poses/'));
    if (path.contains('/poses/')) alts.add(path.replaceFirst('/poses/', '/posses/'));
    // 2b) Background folder case variations
    if (path.contains('/Background/')) alts.add(path.replaceFirst('/Background/', '/background/'));
    if (path.contains('/background/')) alts.add(path.replaceFirst('/background/', '/Background/'));

    // 3) Filename stem: pose_ -> poses_ and reverse
    final lastSlash = path.lastIndexOf('/');
    if (lastSlash != -1) {
      final dir = path.substring(0, lastSlash + 1);
      final file = path.substring(lastSlash + 1);
      if (file.startsWith('pose_')) alts.add('$dir${'poses_'}${file.substring('pose_'.length)}');
      if (file.startsWith('poses_')) alts.add('$dir${'pose_'}${file.substring('poses_'.length)}');

      // 4) Premium dolls: try common naming variations for thumbs
      if (dir.contains('/special/thumbs/')) {
        // Without _base in the filename
        if (file.contains('_base_thumb')) {
          alts.add('$dir${file.replaceFirst('_base_thumb', '_thumb')}');
          alts.add('$dir${file.replaceFirst('_base_thumb', '')}');
        }
        // Try without the thumbs/ directory
        final noThumbsDir = dir.replaceFirst('/thumbs/', '/');
        alts.add('$noThumbsDir$file');
        // Try flattened into images/dolls/
        final flattened = dir.replaceFirst('/special/thumbs/', '/');
        alts.add('$flattened$file');
      }

      // 5) Premium stage: try without /stage/ folder and without _base infix
      if (dir.contains('/special/stage/')) {
        final noStageDir = dir.replaceFirst('/stage/', '/');
        alts.add('$noStageDir$file');
        if (file.contains('_base_')) {
          final withoutBase = file.replaceFirst('_base_', '_');
          alts.add('$dir$withoutBase');
          alts.add('$noStageDir$withoutBase');
        }
      }

      // 6) Base thumbs: allow base_XX_thumb naming
      if (dir.contains('/base/thumbs/') && file.contains('_base_thumb')) {
        alts.add('$dir${file.replaceFirst('_base_thumb', '_thumb')}');
      }

      // 7) Base stage mapping variations
      // a) If given legacy 'images/dolls/doll_X_base.png', try new structured path
      final legacyDollMatch = RegExp(r'^doll_(\d+)_base\.png$').firstMatch(file);
      if (legacyDollMatch != null) {
        final i = int.tryParse(legacyDollMatch.group(1)!);
        if (i != null) {
          final num = i.toString().padLeft(2, '0');
          alts.add('images/dolls/base/stage/base_${num}_base_stage.png');
        }
      }

      // b) If given structured '.../base/stage/base_XX_base_stage.png', try legacy flat path
      if (dir.contains('/base/stage/') && file.startsWith('base_') && file.endsWith('_base_stage.png')) {
        final match = RegExp(r'^base_(\d{2})_base_stage\.png$').firstMatch(file);
        if (match != null) {
          final numStr = match.group(1)!;
          final i = int.tryParse(numStr);
          if (i != null) {
            alts.add('images/dolls/doll_${i}_base.png');
          }
        }
      }
    }

    // 7) Combine folder and stem corrections together
    if (path.contains('/posses/')) {
      final p2 = path.replaceFirst('/posses/', '/poses/');
      final last = p2.lastIndexOf('/');
      if (last != -1) {
        final dir = p2.substring(0, last + 1);
        final file = p2.substring(last + 1);
        if (file.startsWith('pose_')) alts.add('$dir${'poses_'}${file.substring('pose_'.length)}');
      }
    }

    return alts.toList(growable: false);
  }
  
  /// Clear the URL cache
  void clearCache() {
    _urlCache.clear();
    _drawerUrlsCached = false;
  }
  
  /// Whether drawer thumbnails have been pre-cached
  bool get drawerUrlsCached => _drawerUrlsCached;
  
  /// Pre-cache all drawer thumbnail URLs in batches to avoid overwhelming the network.
  /// Call this once during app initialization.
  Future<void> precacheDrawerUrls() async {
    if (_drawerUrlsCached) return;
    
    debugPrint('[Storage] Pre-caching drawer URLs...');
    final paths = <String>[];
    
    // Base dolls (10 dolls - thumbs and stage images)
    for (var i = 1; i <= 10; i++) {
      final num = i.toString().padLeft(2, '0');
      paths.add('images/dolls/base/thumbs/base_${num}_base_thumb.png');
      // Stage under base/stage to match thumbnails 1:1
      paths.add('images/dolls/base/stage/base_${num}_base_stage.png');
    }
    // Premium dolls (5 dolls - thumbs and stage images)
    for (var i = 1; i <= 5; i++) {
      final num = i.toString().padLeft(2, '0');
      paths.add('images/dolls/special/thumbs/special_${num}_base_thumb.png');
      // Correct stage path per provided structure
      paths.add('images/dolls/special/stage/special_${num}_base_stage.png');
    }
    // Full outfits (24)
    for (var i = 1; i <= 24; i++) {
      final num = i.toString().padLeft(2, '0');
      paths.add('images/full outfit/full_outfit_$num.jpg');
    }
    // Hair, Top, Bottom, Shoes, Accessories, Hats, Jewelry, Glasses (12 each)
    final categories = ['hair', 'top', 'bottom', 'shoes', 'accessories', 'hats', 'jewelry', 'glasses'];
    for (final cat in categories) {
      for (var i = 1; i <= 12; i++) {
        final num = i.toString().padLeft(2, '0');
        paths.add('images/$cat/${cat}_$num.jpg');
      }
    }
    // Poses (12)
    for (var i = 1; i <= 12; i++) {
      final num = i.toString().padLeft(2, '0');
      paths.add('images/posses/pose_$num.jpg');
    }
    // Backgrounds (12)
    for (var i = 1; i <= 12; i++) {
      final num = i.toString().padLeft(2, '0');
      paths.add('images/Background/background_$num.jpg');
    }
    
    // Batch process in groups of 5 to avoid overwhelming network
    const batchSize = 5;
    for (var i = 0; i < paths.length; i += batchSize) {
      final batch = paths.skip(i).take(batchSize).toList();
      await Future.wait(
        batch.map((p) => getDownloadUrlSafe(p)),
        eagerError: false,
      );
      // Small delay between batches
      if (i + batchSize < paths.length) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
    }
    
    _drawerUrlsCached = true;
    debugPrint('[Storage] Pre-cached ${_urlCache.length} drawer URLs');
  }

  /// Optional diagnostic to self-check mapping between prompts/descriptions and thumbnails.
  /// It only attempts to resolve download URLs (no bytes), and logs missing entries.
  Future<void> verifyAllAssetMappings() async {
    debugPrint('[Storage] Verifying asset mappings (thumbs ↔ prompts, dolls ↔ stages)...');

    // 1) Dolls
    for (var i = 1; i <= 10; i++) {
      final num = i.toString().padLeft(2, '0');
      final thumb = 'images/dolls/base/thumbs/base_${num}_base_thumb.png';
      final stage = 'images/dolls/base/stage/base_${num}_base_stage.png';
      final t = await getDownloadUrlSafe(thumb);
      final s = await getDownloadUrlSafe(stage);
      if (t == null) debugPrint('[Verify] Missing base doll thumb: $thumb');
      if (s == null) debugPrint('[Verify] Missing base doll stage: $stage');
    }
    for (var i = 1; i <= 5; i++) {
      final num = i.toString().padLeft(2, '0');
      final thumb = 'images/dolls/special/thumbs/special_${num}_base_thumb.png';
      final stage = 'images/dolls/special/stage/special_${num}_base_stage.png';
      final t = await getDownloadUrlSafe(thumb);
      final s = await getDownloadUrlSafe(stage);
      if (t == null) debugPrint('[Verify] Missing premium doll thumb: $thumb');
      if (s == null) debugPrint('[Verify] Missing premium doll stage: $stage');
    }

    // 2) Categories (12 each)
    Future<void> verifyCat(String folder, String stem, int count) async {
      for (var i = 1; i <= count; i++) {
        final num = i.toString().padLeft(2, '0');
        final p = 'images/$folder/${stem}_$num.jpg';
        final url = await getDownloadUrlSafe(p);
        if (url == null) debugPrint('[Verify] Missing $folder thumb: $p');
      }
    }
    await verifyCat('hair', 'hair', 12);
    await verifyCat('top', 'top', 12);
    await verifyCat('bottom', 'bottom', 12);
    await verifyCat('shoes', 'shoes', 12);
    await verifyCat('accessories', 'accessories', 12);
    await verifyCat('hats', 'hats', 12);
    await verifyCat('jewelry', 'jewelry', 12);
    await verifyCat('glasses', 'glasses', 12);

    // 3) Poses
    for (var i = 1; i <= 12; i++) {
      final num = i.toString().padLeft(2, '0');
      final p = 'images/posses/pose_$num.jpg';
      final url = await getDownloadUrlSafe(p);
      if (url == null) debugPrint('[Verify] Missing poses thumb: $p');
    }

    // 4) Backgrounds
    for (var i = 1; i <= 12; i++) {
      final num = i.toString().padLeft(2, '0');
      final p = 'images/Background/background_$num.jpg';
      final url = await getDownloadUrlSafe(p);
      if (url == null) debugPrint('[Verify] Missing Background thumb: $p');
    }

    // 5) Full outfits (24)
    for (var i = 1; i <= 24; i++) {
      final num = i.toString().padLeft(2, '0');
      final p = 'images/full outfit/full_outfit_$num.jpg';
      final url = await getDownloadUrlSafe(p);
      if (url == null) debugPrint('[Verify] Missing full outfit thumb: $p');
    }

    debugPrint('[Storage] Verification pass complete.');
  }

  /// Download bytes for an existing object by storage [path].
  /// Provide [maxSize] to cap memory usage; defaults to 15MB.
  Future<Uint8List> downloadBytes(String path, {int maxSize = 15 * 1024 * 1024}) async {
    try {
      debugPrint('[Storage] downloadBytes $path (maxSize=$maxSize)');
      final ref = _storage.ref().child(path);

      // On web, ref.getData() can throw type errors. Use HTTP fetch instead.
      if (kIsWeb) {
        final url = await ref.getDownloadURL();
        debugPrint('[Storage] Fetching via HTTP: $url');
        final response = await http.get(Uri.parse(url));
        if (response.statusCode != 200) {
          throw Exception('HTTP ${response.statusCode} for $path');
        }
        return response.bodyBytes;
      }

      // Native platforms can use getData directly
      final data = await ref.getData(maxSize);
      if (data == null) {
        throw Exception('No data returned for $path');
      }
      return data;
    } catch (e, st) {
      debugPrint('[Storage] downloadBytes failed: $e\n$st');
      rethrow;
    }
  }

  /// List object paths under a prefix (directory-like path).
  Future<List<String>> listPaths(String prefix) async {
    try {
      final ref = _storage.ref().child(prefix);
      final result = await ref.listAll();
      final files = <String>[...result.items.map((i) => i.fullPath)];
      debugPrint('[Storage] listPaths for $prefix => ${files.length} items');
      return files;
    } catch (e, st) {
      debugPrint('[Storage] listPaths failed: $e\n$st');
      rethrow;
    }
  }

  /// Delete an object at [path].
  Future<void> delete(String path) async {
    try {
      debugPrint('[Storage] delete $path');
      final ref = _storage.ref().child(path);
      await ref.delete();
    } catch (e, st) {
      debugPrint('[Storage] delete failed: $e\n$st');
      rethrow;
    }
  }
}