// Custom Painters for Memory-Optimized Puzzle Rendering
// File: lib/game_module/services/memory_optimized_asset_manager_painters.dart

import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'enhanced_puzzle_asset_manager.dart';
import 'memory_optimized_asset_manager.dart';

/// Global debug settings for puzzle rendering
class PuzzleDebugSettings {
  /// Whether to show debug bounding boxes around pieces
  static bool showDebugBounds = false;
  
  /// Whether to show debug info overlays
  static bool showDebugInfo = false;
  
  /// Toggle debug bounds on/off
  static void toggleDebugBounds() {
    showDebugBounds = !showDebugBounds;
  }
  
  /// Enable debug mode (shows bounds and info)
  static void enableDebugMode() {
    showDebugBounds = true;
    showDebugInfo = true;
  }
  
  /// Disable debug mode (hides all debug visualizations)
  static void disableDebugMode() {
    showDebugBounds = false;
    showDebugInfo = false;
  }
}

/// Painter for optimized cropped images (tray display)
class OptimizedCroppedImagePainter extends CustomPainter {
  final ui.Image image;
  final OptimizedPieceMetadata metadata;
  final BoxFit fit;
  final double zoomLevel;

  OptimizedCroppedImagePainter({
    required this.image,
    required this.metadata,
    required this.fit,
    required this.zoomLevel,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // For optimized pieces, the image is already cropped to content
    // Just scale and position it appropriately
    final srcRect = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    final destRect = _calculateDestRect(size);
    
    // Apply zoom-aware scaling
    final zoomedDestRect = Rect.fromLTWH(
      destRect.left,
      destRect.top,
      destRect.width * zoomLevel,
      destRect.height * zoomLevel,
    );
    
    // Center the zoomed image
    final centeredRect = Rect.fromLTWH(
      (size.width - zoomedDestRect.width) / 2,
      (size.height - zoomedDestRect.height) / 2,
      zoomedDestRect.width,
      zoomedDestRect.height,
    );
    
    canvas.drawImageRect(image, srcRect, centeredRect, Paint()..filterQuality = FilterQuality.medium);
  }

  Rect _calculateDestRect(Size size) {
    final imageSize = Size(image.width.toDouble(), image.height.toDouble());
    
    switch (fit) {
      case BoxFit.fill:
        return Rect.fromLTWH(0, 0, size.width, size.height);
      case BoxFit.contain:
        final scale = (size.width / imageSize.width).clamp(0.0, size.height / imageSize.height);
        final scaledWidth = imageSize.width * scale;
        final scaledHeight = imageSize.height * scale;
        final dx = (size.width - scaledWidth) / 2;
        final dy = (size.height - scaledHeight) / 2;
        return Rect.fromLTWH(dx, dy, scaledWidth, scaledHeight);
      case BoxFit.cover:
      default:
        final scale = (size.width / imageSize.width).clamp(size.height / imageSize.height, double.infinity);
        final scaledWidth = imageSize.width * scale;
        final scaledHeight = imageSize.height * scale;
        final dx = (size.width - scaledWidth) / 2;
        final dy = (size.height - scaledHeight) / 2;
        return Rect.fromLTWH(dx, dy, scaledWidth, scaledHeight);
    }
  }

  void _drawDebugBounds(Canvas canvas, Rect rect, Color color) {
    final debugPaint = Paint()
      ..color = color.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawRect(rect, debugPaint);
  }

  @override
  bool shouldRepaint(covariant OptimizedCroppedImagePainter oldDelegate) {
    return oldDelegate.image != image ||
           oldDelegate.zoomLevel != zoomLevel ||
           oldDelegate.fit != fit;
  }
}

/// Painter for optimized images in canvas mode (positioned according to metadata)
class OptimizedCanvasImagePainter extends CustomPainter {
  final ui.Image image;
  final OptimizedPieceMetadata metadata;
  final BoxFit fit;

  OptimizedCanvasImagePainter({
    required this.image,
    required this.metadata,
    required this.fit,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // For memory-optimized pieces, we should render at 1:1 pixel coordinates
    // and let the widget handle display scaling
    
    // Check if we're rendering at native canvas size (2048x2048)
    final isNativeSize = size.width == metadata.originalCanvasSize.width && 
                        size.height == metadata.originalCanvasSize.height;
    
    if (isNativeSize) {
      // Render at 1:1 pixel coordinates - no scaling needed
      final destRect = Rect.fromLTWH(
        metadata.contentBounds.left,
        metadata.contentBounds.top,
        metadata.contentBounds.width,
        metadata.contentBounds.height,
      );
      
      final srcRect = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
      
      canvas.drawImageRect(image, srcRect, destRect, Paint()..filterQuality = FilterQuality.high);
    } else {
      // Legacy scaling for non-native canvas sizes
      final canvasScale = size.width / metadata.originalCanvasSize.width;
      
      final scaledBounds = Rect.fromLTWH(
        metadata.contentBounds.left * canvasScale,
        metadata.contentBounds.top * canvasScale,
        metadata.contentBounds.width * canvasScale,
        metadata.contentBounds.height * canvasScale,
      );
      
      final srcRect = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
      
      canvas.drawImageRect(image, srcRect, scaledBounds, Paint()..filterQuality = FilterQuality.high);
    }
    
    // Optional debug bounds (only when explicitly enabled)
    if (kDebugMode && PuzzleDebugSettings.showDebugBounds) {
      final bounds = isNativeSize 
          ? Rect.fromLTWH(
              metadata.contentBounds.left,
              metadata.contentBounds.top,
              metadata.contentBounds.width,
              metadata.contentBounds.height,
            )
          : Rect.fromLTWH(
              metadata.contentBounds.left * (size.width / metadata.originalCanvasSize.width),
              metadata.contentBounds.top * (size.width / metadata.originalCanvasSize.width),
              metadata.contentBounds.width * (size.width / metadata.originalCanvasSize.width),
              metadata.contentBounds.height * (size.width / metadata.originalCanvasSize.width),
            );
      _drawDebugBounds(canvas, bounds, Colors.blue);
    }
  }

  void _drawDebugBounds(Canvas canvas, Rect rect, Color color) {
    final debugPaint = Paint()
      ..color = color.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawRect(rect, debugPaint);
  }

  @override
  bool shouldRepaint(covariant OptimizedCanvasImagePainter oldDelegate) {
    return oldDelegate.image != image || oldDelegate.fit != fit;
  }
}

/// Painter for runtime-optimized pieces (tray display with smart cropping)
class RuntimeCroppedImagePainter extends CustomPainter {
  final ui.Image image;
  final PieceBounds bounds;
  final BoxFit fit;
  final double zoomLevel;

  RuntimeCroppedImagePainter({
    required this.image,
    required this.bounds,
    required this.fit,
    required this.zoomLevel,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (!bounds.hasContent) {
      // Draw placeholder for empty pieces
      final paint = Paint()
        ..color = Colors.grey[200]!
        ..style = PaintingStyle.fill;
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
      return;
    }

    // Crop the original image to content bounds during rendering
    final srcRect = bounds.contentRect;
    final destRect = _calculateDestRect(size);
    
    // Apply zoom-aware scaling
    final zoomedDestRect = Rect.fromLTWH(
      destRect.left,
      destRect.top,
      destRect.width * zoomLevel,
      destRect.height * zoomLevel,
    );
    
    // Center the zoomed image
    final centeredRect = Rect.fromLTWH(
      (size.width - zoomedDestRect.width) / 2,
      (size.height - zoomedDestRect.height) / 2,
      zoomedDestRect.width,
      zoomedDestRect.height,
    );
    
    canvas.drawImageRect(image, srcRect, centeredRect, Paint()..filterQuality = FilterQuality.medium);
    
    // Optional debug bounds (only when explicitly enabled)
    if (kDebugMode && PuzzleDebugSettings.showDebugBounds) {
      _drawDebugBounds(canvas, centeredRect, Colors.orange);
    }
  }

  Rect _calculateDestRect(Size size) {
    final contentSize = bounds.contentRect.size;
    
    switch (fit) {
      case BoxFit.fill:
        return Rect.fromLTWH(0, 0, size.width, size.height);
      case BoxFit.contain:
        final scale = (size.width / contentSize.width).clamp(0.0, size.height / contentSize.height);
        final scaledWidth = contentSize.width * scale;
        final scaledHeight = contentSize.height * scale;
        final dx = (size.width - scaledWidth) / 2;
        final dy = (size.height - scaledHeight) / 2;
        return Rect.fromLTWH(dx, dy, scaledWidth, scaledHeight);
      case BoxFit.cover:
      default:
        final scale = (size.width / contentSize.width).clamp(size.height / contentSize.height, double.infinity);
        final scaledWidth = contentSize.width * scale;
        final scaledHeight = contentSize.height * scale;
        final dx = (size.width - scaledWidth) / 2;
        final dy = (size.height - scaledHeight) / 2;
        return Rect.fromLTWH(dx, dy, scaledWidth, scaledHeight);
    }
  }

  void _drawDebugBounds(Canvas canvas, Rect rect, Color color) {
    final debugPaint = Paint()
      ..color = color.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRect(rect, debugPaint);
  }

  @override
  bool shouldRepaint(covariant RuntimeCroppedImagePainter oldDelegate) {
    return oldDelegate.image != image ||
           oldDelegate.zoomLevel != zoomLevel ||
           oldDelegate.fit != fit;
  }
}

/// Painter for runtime-optimized pieces in canvas mode (full padded image)
class RuntimeOriginalImagePainter extends CustomPainter {
  final ui.Image image;
  final BoxFit fit;

  RuntimeOriginalImagePainter({
    required this.image,
    required this.fit,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final srcRect = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    final destRect = _getDestRect(size);
    
    // Draw the full padded image - padding handles positioning
    canvas.drawImageRect(image, srcRect, destRect, Paint()..filterQuality = FilterQuality.medium);
    
    // Optional debug bounds (only when explicitly enabled)
    if (kDebugMode && PuzzleDebugSettings.showDebugBounds) {
      _drawDebugBounds(canvas, destRect, Colors.purple);
    }
  }

  Rect _getDestRect(Size size) {
    switch (fit) {
      case BoxFit.fill:
        return Rect.fromLTWH(0, 0, size.width, size.height);
      case BoxFit.contain:
        final scale = (size.width / image.width).clamp(0.0, size.height / image.height);
        final scaledWidth = image.width * scale;
        final scaledHeight = image.height * scale;
        final dx = (size.width - scaledWidth) / 2;
        final dy = (size.height - scaledHeight) / 2;
        return Rect.fromLTWH(dx, dy, scaledWidth, scaledHeight);
      case BoxFit.cover:
      default:
        final scale = (size.width / image.width).clamp(size.height / image.height, double.infinity);
        final scaledWidth = image.width * scale;
        final scaledHeight = image.height * scale;
        final dx = (size.width - scaledWidth) / 2;
        final dy = (size.height - scaledHeight) / 2;
        return Rect.fromLTWH(dx, dy, scaledWidth, scaledHeight);
    }
  }

  void _drawDebugBounds(Canvas canvas, Rect rect, Color color) {
    final debugPaint = Paint()
      ..color = color.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawRect(rect, debugPaint);
  }

  @override
  bool shouldRepaint(covariant RuntimeOriginalImagePainter oldDelegate) {
    return oldDelegate.image != image || oldDelegate.fit != fit;
  }
}

/// Fallback painter for when metadata is not available
class FallbackImagePainter extends CustomPainter {
  final ui.Image image;
  final BoxFit fit;

  FallbackImagePainter(this.image, this.fit);

  @override
  void paint(Canvas canvas, Size size) {
    final srcRect = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    final destRect = _getDestRect(size);
    
    canvas.drawImageRect(image, srcRect, destRect, Paint());
  }

  Rect _getDestRect(Size size) {
    switch (fit) {
      case BoxFit.fill:
        return Rect.fromLTWH(0, 0, size.width, size.height);
      case BoxFit.contain:
        final scale = (size.width / image.width).clamp(0.0, size.height / image.height);
        final scaledWidth = image.width * scale;
        final scaledHeight = image.height * scale;
        final dx = (size.width - scaledWidth) / 2;
        final dy = (size.height - scaledHeight) / 2;
        return Rect.fromLTWH(dx, dy, scaledWidth, scaledHeight);
      case BoxFit.cover:
      default:
        final scale = (size.width / image.width).clamp(size.height / image.height, double.infinity);
        final scaledWidth = image.width * scale;
        final scaledHeight = image.height * scale;
        final dx = (size.width - scaledWidth) / 2;
        final dy = (size.height - scaledHeight) / 2;
        return Rect.fromLTWH(dx, dy, scaledWidth, scaledHeight);
    }
  }

  @override
  bool shouldRepaint(covariant FallbackImagePainter oldDelegate) {
    return oldDelegate.image != image || oldDelegate.fit != fit;
  }
}
