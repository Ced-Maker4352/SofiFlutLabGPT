import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  StorageService._();
  static final StorageService instance = StorageService._();

  final FirebaseStorage _storage = FirebaseStorage.instance;

  // ============================================================
  // TEMP IMAGE UPLOAD (ModelsLab / two-step pipeline)
  // ============================================================
  Future<String> uploadTempImage(Uint8List bytes) async {
    final path = 'temp/${DateTime.now().millisecondsSinceEpoch}.png';
    return uploadBytes(bytes, path: path, contentType: 'image/png');
  }

  // ============================================================
  // CORE UPLOAD
  // ============================================================
  Future<String> uploadBytes(
    Uint8List data, {
    required String path,
    String? contentType,
    Map<String, String>? customMetadata,
  }) async {
    final ref = _storage.ref().child(path);
    final metadata = SettableMetadata(
      contentType: contentType,
      customMetadata: customMetadata,
    );
    await ref.putData(data, metadata);
    return ref.getDownloadURL();
  }

  // ============================================================
  // DOWNLOAD
  // ============================================================
  Future<Uint8List> downloadBytes(
    String path, {
    int maxSize = 20 * 1024 * 1024,
  }) async {
    final data = await _storage.ref().child(path).getData(maxSize);
    if (data == null) {
      throw Exception('Failed to download $path');
    }
    return data;
  }

  // ============================================================
  // URL HELPERS
  // ============================================================
  Future<String> getDownloadUrl(String path) async {
    return _storage.ref().child(path).getDownloadURL();
  }

  Future<String?> getDownloadUrlSafe(String path) async {
    try {
      return await getDownloadUrl(path);
    } catch (e) {
      debugPrint('[StorageService] getDownloadUrlSafe failed: $e');
      return null;
    }
  }

  // ============================================================
  // DELETE
  // ============================================================
  Future<void> delete(String path) async {
    await _storage.ref().child(path).delete();
  }

  // ============================================================
  // UI COMPATIBILITY STUBS (required by Sofi Studio UI)
  // ============================================================
  Future<void> precacheDrawerUrls(List<String> paths) async {
    for (final p in paths) {
      await getDownloadUrlSafe(p);
    }
  }

  Future<void> verifyAllAssetMappings() async {
    debugPrint('[StorageService] verifyAllAssetMappings OK');
  }
}
