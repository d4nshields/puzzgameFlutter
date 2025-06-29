// Desktop Window Configuration for Portrait Layout
// File: lib/core/infrastructure/desktop_window_config.dart

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Configuration for desktop window to force portrait layout
class DesktopWindowConfig {
  // Portrait dimensions that match phone layout
  static const double portraitWidth = 480.0;
  static const double portraitHeight = 800.0;
  static const double minWidth = 360.0;
  static const double minHeight = 640.0;
  
  /// Check if running on desktop platform
  static bool get isDesktop {
    return !kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS);
  }
  
  /// Check if running specifically on Linux
  static bool get isLinux {
    return !kIsWeb && Platform.isLinux;
  }
  
  /// Get recommended window size for portrait layout
  static Map<String, double> get portraitWindowSize {
    return {
      'width': portraitWidth,
      'height': portraitHeight,
      'minWidth': minWidth,
      'minHeight': minHeight,
    };
  }
  
  /// Initialize desktop window configuration if needed
  static Future<void> initialize() async {
    if (!isDesktop) return;
    
    // Note: Window configuration is handled in native code (my_application.cc)
    // This class provides constants and utilities for consistent sizing
    
    if (kDebugMode) {
      print('DesktopWindowConfig: Portrait layout initialized for desktop');
      print('DesktopWindowConfig: Window size ${portraitWidth}x$portraitHeight');
    }
  }
}

/// Extension to help detect orientation programmatically
extension OrientationHelper on Size {
  /// Check if the current size represents portrait orientation
  bool get isPortrait => height > width;
  
  /// Check if the current size represents landscape orientation
  bool get isLandscape => width > height;
  
  /// Get aspect ratio string for debugging
  String get aspectRatioString {
    final ratio = width / height;
    return '${width.toInt()}x${height.toInt()} (${ratio.toStringAsFixed(2)}:1)';
  }
}
