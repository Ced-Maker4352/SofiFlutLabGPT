// lib/utils/ios_utils.dart
// iOS-specific utility functions for the Sofi Saint app

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// iOS utility class for platform-specific optimizations
class IOSUtils {
  IOSUtils._();
  
  /// Check if running on native iOS (not web preview)
  static bool get isNativeIOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  
  /// Check if running on iOS web (Safari)
  static bool get isIOSWeb => kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  
  /// Check if running on any iOS platform (native or web)
  static bool get isIOS => defaultTargetPlatform == TargetPlatform.iOS;
  
  /// Trigger iOS haptic feedback
  static void lightHaptic() {
    if (isNativeIOS) {
      HapticFeedback.lightImpact();
    }
  }
  
  /// Trigger iOS medium haptic feedback
  static void mediumHaptic() {
    if (isNativeIOS) {
      HapticFeedback.mediumImpact();
    }
  }
  
  /// Trigger iOS heavy haptic feedback
  static void heavyHaptic() {
    if (isNativeIOS) {
      HapticFeedback.heavyImpact();
    }
  }
  
  /// Trigger iOS selection haptic feedback
  static void selectionHaptic() {
    if (isNativeIOS) {
      HapticFeedback.selectionClick();
    }
  }
  
  /// Get bottom safe area padding for iPhone notch/home indicator
  static double getBottomSafeArea(double bottomPadding) {
    // iPhone X and later have a home indicator area
    // Add extra padding for consistent UX
    if (isNativeIOS && bottomPadding > 0) {
      return bottomPadding;
    }
    return 0;
  }
  
  /// Check if device has a notch (iPhone X and later)
  static bool hasNotch(double topPadding) {
    // iPhone X and later have top safe area > 20
    return isNativeIOS && topPadding > 20;
  }
}

/// iOS-specific keyboard handling mixin
mixin IOSKeyboardMixin {
  /// Dismiss keyboard on iOS
  void dismissKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
  }
}
