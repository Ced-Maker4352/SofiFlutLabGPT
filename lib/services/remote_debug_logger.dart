// lib/services/remote_debug_logger.dart
// TEMPORARY: Remote debug logging to Firebase - remove after debugging iOS crashes

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Severity levels for log entries
enum LogLevel { debug, info, warning, error, fatal }

/// Remote debug logger that sends logs to Firebase Firestore
/// for debugging iOS web preview crashes.
/// 
/// TO REMOVE: Delete this file and all RemoteDebugLogger calls after debugging.
class RemoteDebugLogger {
  RemoteDebugLogger._();
  static final RemoteDebugLogger instance = RemoteDebugLogger._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Session ID to group logs from the same app session
  late final String _sessionId;
  late final DateTime _sessionStart;
  
  // Device/platform info
  String _platform = 'unknown';
  String _deviceInfo = 'unknown';
  
  // Batching to reduce Firestore writes
  final List<Map<String, dynamic>> _logBuffer = [];
  Timer? _flushTimer;
  static const int _maxBufferSize = 10;
  static const Duration _flushInterval = Duration(seconds: 5);
  
  // Track if initialized
  bool _initialized = false;
  bool _permissionDeniedWarned = false;
  
  /// Initialize the logger - call once at app startup
  Future<void> initialize() async {
    if (_initialized) return;
    
    _sessionId = DateTime.now().millisecondsSinceEpoch.toString();
    _sessionStart = DateTime.now();
    
    // Detect platform
    if (kIsWeb) {
      _platform = 'web';
      // Try to detect iOS Safari/Chrome
      _deviceInfo = _detectWebBrowser();
    } else {
      _platform = defaultTargetPlatform.name;
      _deviceInfo = 'native-$_platform';
    }
    
    _initialized = true;
    
    // Start periodic flush timer
    _flushTimer = Timer.periodic(_flushInterval, (_) => _flushBuffer());
    
    // Log session start
    await log(LogLevel.info, 'SESSION_START', 'App session started', {
      'platform': _platform,
      'deviceInfo': _deviceInfo,
    });
  }
  
  String _detectWebBrowser() {
    // We can't directly access navigator.userAgent in pure Dart,
    // but we can detect iOS by checking platform characteristics
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return 'ios-web-preview';
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      return 'android-web-preview';
    }
    return 'web-browser';
  }
  
  /// Log an event to Firebase
  Future<void> log(
    LogLevel level,
    String event,
    String message, [
    Map<String, dynamic>? extra,
  ]) async {
    if (!_initialized) {
      debugPrint('[RemoteDebugLogger] Not initialized, skipping: $event');
      return;
    }
    
    final logEntry = {
      'sessionId': _sessionId,
      'timestamp': FieldValue.serverTimestamp(),
      'localTime': DateTime.now().toIso8601String(),
      'level': level.name,
      'event': event,
      'message': message,
      'platform': _platform,
      'deviceInfo': _deviceInfo,
      'sessionDuration': DateTime.now().difference(_sessionStart).inSeconds,
      if (extra != null) ...extra,
    };
    
    // Also print locally for Dreamflow debug console
    debugPrint('[RemoteLog:${level.name}] $event: $message');
    
    // Add to buffer
    _logBuffer.add(logEntry);
    
    // Flush immediately for errors/fatals, or if buffer is full
    if (level == LogLevel.error || level == LogLevel.fatal || _logBuffer.length >= _maxBufferSize) {
      await _flushBuffer();
    }
  }
  
  /// Flush buffered logs to Firestore
  Future<void> _flushBuffer() async {
    if (_logBuffer.isEmpty) return;
    
    final logsToSend = List<Map<String, dynamic>>.from(_logBuffer);
    _logBuffer.clear();
    
    try {
      final batch = _firestore.batch();
      final collection = _firestore.collection('debug_logs');
      
      for (final log in logsToSend) {
        batch.set(collection.doc(), log);
      }
      
      // Add timeout to prevent hanging (avoid onTimeout type pitfalls)
      await Future.any([
        batch.commit(),
        Future<void>.delayed(const Duration(seconds: 5), () {
          debugPrint('[RemoteDebugLogger] Batch commit timeout');
          throw TimeoutException('Firestore batch commit timed out');
        }),
      ]);
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('permission-denied')) {
        if (!_permissionDeniedWarned) {
          _permissionDeniedWarned = true;
          debugPrint('[RemoteDebugLogger] Firestore permission denied. Check rules for collection "debug_logs" and ensure the app is connected to the intended Firebase project.');
        }
      } else {
        debugPrint('[RemoteDebugLogger] Failed to flush logs: $e');
      }
      // Re-add logs to buffer if failed (but don't exceed limit)
      if (_logBuffer.length < _maxBufferSize * 2) {
        _logBuffer.insertAll(0, logsToSend);
      }
    }
  }
  
  /// Log a user interaction
  Future<void> logInteraction(String action, [Map<String, dynamic>? details]) =>
      log(LogLevel.info, 'USER_INTERACTION', action, details);
  
  /// Log a warning
  Future<void> logWarning(String message, [Map<String, dynamic>? details]) =>
      log(LogLevel.warning, 'WARNING', message, details);
  
  /// Log an error with stack trace
  Future<void> logError(String message, dynamic error, [StackTrace? stackTrace]) =>
      log(LogLevel.error, 'ERROR', message, {
        'error': error.toString(),
        'stackTrace': stackTrace?.toString().substring(0, (stackTrace.toString().length > 2000 ? 2000 : stackTrace.toString().length)),
      });
  
  /// Log a fatal crash
  Future<void> logFatal(String message, dynamic error, StackTrace? stackTrace) =>
      log(LogLevel.fatal, 'FATAL_CRASH', message, {
        'error': error.toString(),
        'stackTrace': stackTrace?.toString().substring(0, (stackTrace.toString().length > 2000 ? 2000 : stackTrace.toString().length)),
      });
  
  /// Log generation attempt
  Future<void> logGeneration(String status, {int? duration, String? error}) =>
      log(LogLevel.info, 'GENERATION', status, {
        if (duration != null) 'durationMs': duration,
        if (error != null) 'error': error,
      });
  
  /// Log mic/speech interaction
  Future<void> logMic(String status, [String? details]) =>
      log(LogLevel.info, 'MIC', status, {if (details != null) 'details': details});
  
  /// Log audio/TTS event
  Future<void> logAudio(String status, [String? details]) =>
      log(LogLevel.info, 'AUDIO_TTS', status, {if (details != null) 'details': details});
  
  /// Log category selection
  Future<void> logCategorySelection(String category, int option) =>
      log(LogLevel.debug, 'CATEGORY_SELECT', '$category: option $option');
  
  /// Log memory/performance warning
  Future<void> logPerformance(String metric, dynamic value) =>
      log(LogLevel.warning, 'PERFORMANCE', metric, {'value': value.toString()});
  
  /// Force flush all pending logs (call before app closes)
  Future<void> flush() async {
    await _flushBuffer();
  }
  
  /// Dispose the logger
  void dispose() {
    _flushTimer?.cancel();
    _flushBuffer();
  }
}
