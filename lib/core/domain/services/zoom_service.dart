// Zoom Service Interface and Implementation
// File: lib/core/domain/services/zoom_service.dart

import 'package:flutter/material.dart';

/// Interface for managing zoom state across the game viewport and tray
/// This allows the main viewport and piece tray to stay synchronized
abstract class ZoomService extends ChangeNotifier {
  /// Current zoom level (1.0 = 100%, 2.0 = 200%, etc.)
  double get zoomLevel;
  
  /// Minimum allowed zoom level
  double get minZoom;
  
  /// Maximum allowed zoom level  
  double get maxZoom;
  
  /// Current pan offset for the viewport
  Offset get panOffset;
  
  /// Set zoom level programmatically
  void setZoom(double zoom);
  
  /// Adjust zoom by a relative amount (positive = zoom in, negative = zoom out)
  void adjustZoom(double delta);
  
  /// Set pan offset
  void setPanOffset(Offset offset);
  
  /// Reset zoom and pan to defaults
  void reset();
  
  /// Fit content to viewport (auto-zoom)
  void fitToViewport({required Size contentSize, required Size viewportSize});
}

/// Simple implementation of zoom service with reasonable defaults
class DefaultZoomService extends ChangeNotifier implements ZoomService {
  static const double _defaultZoom = 1.0;
  static const double _minZoom = 0.5;
  static const double _maxZoom = 3.0;
  static const double _zoomStep = 0.1;
  
  double _zoomLevel = _defaultZoom;
  Offset _panOffset = Offset.zero;
  
  @override
  double get zoomLevel => _zoomLevel;
  
  @override
  double get minZoom => _minZoom;
  
  @override
  double get maxZoom => _maxZoom;
  
  @override
  Offset get panOffset => _panOffset;
  
  @override
  void setZoom(double zoom) {
    final newZoom = zoom.clamp(_minZoom, _maxZoom);
    if (_zoomLevel != newZoom) {
      _zoomLevel = newZoom;
      notifyListeners();
    }
  }
  
  @override
  void adjustZoom(double delta) {
    setZoom(_zoomLevel + delta);
  }
  
  @override
  void setPanOffset(Offset offset) {
    if (_panOffset != offset) {
      _panOffset = offset;
      notifyListeners();
    }
  }
  
  @override
  void reset() {
    _zoomLevel = _defaultZoom;
    _panOffset = Offset.zero;
    notifyListeners();
  }
  
  @override
  void fitToViewport({required Size contentSize, required Size viewportSize}) {
    final scaleX = viewportSize.width / contentSize.width;
    final scaleY = viewportSize.height / contentSize.height;
    final scale = (scaleX < scaleY ? scaleX : scaleY).clamp(_minZoom, _maxZoom);
    
    setZoom(scale);
    setPanOffset(Offset.zero); // Center the content
  }
  
  /// Get zoom step for UI controls (how much to zoom per click/slide)
  double get zoomStep => _zoomStep;
}
