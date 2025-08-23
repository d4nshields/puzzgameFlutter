/// Advanced Static Layer Renderer with Picture Caching
/// 
/// This implementation provides highly optimized rendering of static game elements
/// using ui.Picture caching, viewport culling, and level-of-detail systems.
/// Designed to maintain 60fps on mid-range devices.

import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Controller for managing static layer state and caching
class StaticLayerController extends ChangeNotifier {
  // Picture caches for different elements
  ui.Picture? _gridPicture;
  ui.Picture? _backgroundPicture;
  final Map<String, ui.Picture> _sectionPictures = {};
  final Map<String, ui.Picture> _effectPictures = {};
  
  // Cache metadata
  Size? _lastSize;
  Rect? _lastViewport;
  double _lastZoomLevel = 1.0;
  
  // Performance tracking
  final PerformanceTracker _performanceTracker = PerformanceTracker();
  
  // Cache invalidation flags
  bool _needsGridUpdate = true;
  bool _needsBackgroundUpdate = true;
  final Set<String> _dirtySection = {};
  
  // Level of detail settings
  LevelOfDetail _currentLOD = LevelOfDetail.high;
  
  // Debug flags
  bool debugShowGrid = false;
  bool debugShowCacheBounds = false;
  bool debugShowPerformanceOverlay = false;

  /// Mark grid for redraw
  void invalidateGrid() {
    _needsGridUpdate = true;
    notifyListeners();
  }

  /// Mark background for redraw
  void invalidateBackground() {
    _needsBackgroundUpdate = true;
    notifyListeners();
  }

  /// Mark a specific section as needing redraw
  void invalidateSection(String sectionId) {
    _dirtySection.add(sectionId);
    notifyListeners();
  }

  /// Add a newly completed section
  void onSectionCompleted(String sectionId, Rect bounds) {
    _dirtySection.add(sectionId);
    notifyListeners();
  }

  /// Update viewport for culling optimization
  void updateViewport(Rect viewport, double zoomLevel) {
    if (_lastViewport != viewport || _lastZoomLevel != zoomLevel) {
      _lastViewport = viewport;
      _lastZoomLevel = zoomLevel;
      _updateLevelOfDetail(zoomLevel);
      notifyListeners();
    }
  }

  /// Update level of detail based on zoom
  void _updateLevelOfDetail(double zoomLevel) {
    LevelOfDetail newLOD;
    if (zoomLevel < 0.5) {
      newLOD = LevelOfDetail.low;
    } else if (zoomLevel < 1.0) {
      newLOD = LevelOfDetail.medium;
    } else {
      newLOD = LevelOfDetail.high;
    }
    
    if (newLOD != _currentLOD) {
      _currentLOD = newLOD;
      // Invalidate caches that depend on LOD
      _needsGridUpdate = true;
      _dirtySection.addAll(_sectionPictures.keys);
    }
  }

  /// Get cached grid picture
  ui.Picture? getGridPicture(Size size) {
    if (_needsGridUpdate || _lastSize != size) {
      return null;
    }
    return _gridPicture;
  }

  /// Update cached grid picture
  void updateGridPicture(ui.Picture picture, Size size) {
    _gridPicture?.dispose();
    _gridPicture = picture;
    _lastSize = size;
    _needsGridUpdate = false;
  }

  /// Get cached section picture
  ui.Picture? getSectionPicture(String sectionId) {
    if (_dirtySection.contains(sectionId)) {
      return null;
    }
    return _sectionPictures[sectionId];
  }

  /// Update cached section picture
  void updateSectionPicture(String sectionId, ui.Picture picture) {
    _sectionPictures[sectionId]?.dispose();
    _sectionPictures[sectionId] = picture;
    _dirtySection.remove(sectionId);
  }

  /// Get performance metrics
  PerformanceMetrics getPerformanceMetrics() {
    return _performanceTracker.getMetrics();
  }

  /// Record paint time
  void recordPaintTime(Duration time) {
    _performanceTracker.recordPaintTime(time);
  }

  @override
  void dispose() {
    // Dispose all cached pictures
    _gridPicture?.dispose();
    _backgroundPicture?.dispose();
    _sectionPictures.values.forEach((p) => p.dispose());
    _effectPictures.values.forEach((p) => p.dispose());
    super.dispose();
  }
}

/// Static layer painter with advanced caching
class StaticLayerPainter extends CustomPainter {
  final StaticLayerController controller;
  final GameState gameState;
  final Rect viewport;
  final double zoomLevel;
  
  // Cached Paint objects
  static final Map<String, Paint> _paintCache = {};
  
  // Performance monitoring
  final Stopwatch _paintStopwatch = Stopwatch();
  
  StaticLayerPainter({
    required this.controller,
    required this.gameState,
    required this.viewport,
    this.zoomLevel = 1.0,
  }) : super(repaint: controller);

  @override
  void paint(Canvas canvas, Size size) {
    _paintStopwatch.reset();
    _paintStopwatch.start();
    
    // Update viewport in controller
    controller.updateViewport(viewport, zoomLevel);
    
    // Apply viewport clipping for performance
    canvas.save();
    canvas.clipRect(viewport);
    
    // Draw layers in order
    _drawBackground(canvas, size);
    _drawGrid(canvas, size);
    _drawCompletedSections(canvas, size);
    _drawEffects(canvas, size);
    
    // Debug visualizations
    if (controller.debugShowCacheBounds) {
      _drawDebugCacheBounds(canvas, size);
    }
    
    if (controller.debugShowPerformanceOverlay) {
      _drawPerformanceOverlay(canvas, size);
    }
    
    canvas.restore();
    
    // Record performance metrics
    _paintStopwatch.stop();
    controller.recordPaintTime(_paintStopwatch.elapsed);
  }

  /// Draw background with caching
  void _drawBackground(Canvas canvas, Size size) {
    var picture = controller._backgroundPicture;
    
    if (picture == null || controller._needsBackgroundUpdate) {
      final recorder = ui.PictureRecorder();
      final recordingCanvas = Canvas(recorder);
      
      _recordBackground(recordingCanvas, size);
      
      picture = recorder.endRecording();
      controller._backgroundPicture?.dispose();
      controller._backgroundPicture = picture;
      controller._needsBackgroundUpdate = false;
    }
    
    canvas.drawPicture(picture);
  }

  /// Record background to picture
  void _recordBackground(Canvas canvas, Size size) {
    // Gradient background
    final rect = Offset.zero & size;
    final gradient = ui.Gradient.linear(
      Offset.zero,
      Offset(size.width, size.height),
      [
        const Color(0xFF1a1a2e),
        const Color(0xFF16213e),
        const Color(0xFF0f0f1e),
      ],
      [0.0, 0.5, 1.0],
    );
    
    final paint = _getCachedPaint('background_gradient')
      ..shader = gradient
      ..style = PaintingStyle.fill;
    
    canvas.drawRect(rect, paint);
    
    // Add subtle texture based on LOD
    if (controller._currentLOD != LevelOfDetail.low) {
      _drawBackgroundTexture(canvas, size);
    }
    
    // Add vignette effect
    _drawVignette(canvas, size);
  }

  /// Draw background texture
  void _drawBackgroundTexture(Canvas canvas, Size size) {
    final paint = _getCachedPaint('texture')
      ..color = Colors.white.withOpacity(0.02)
      ..blendMode = BlendMode.screen;
    
    // Create noise pattern based on LOD
    final density = controller._currentLOD == LevelOfDetail.high ? 500 : 250;
    final random = math.Random(42); // Fixed seed for consistency
    
    for (int i = 0; i < density; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final radius = random.nextDouble() * 1.5 + 0.5;
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  /// Draw vignette effect
  void _drawVignette(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.7;
    
    final gradient = ui.Gradient.radial(
      center,
      radius,
      [
        Colors.transparent,
        Colors.black.withOpacity(0.3),
      ],
      [0.7, 1.0],
    );
    
    final paint = _getCachedPaint('vignette')
      ..shader = gradient
      ..blendMode = BlendMode.multiply;
    
    canvas.drawRect(Offset.zero & size, paint);
  }

  /// Draw grid with caching and viewport culling
  void _drawGrid(Canvas canvas, Size size) {
    if (!gameState.showGrid) return;
    
    var picture = controller.getGridPicture(size);
    
    if (picture == null) {
      final recorder = ui.PictureRecorder();
      final recordingCanvas = Canvas(recorder);
      
      _recordGrid(recordingCanvas, size);
      
      picture = recorder.endRecording();
      controller.updateGridPicture(picture, size);
    }
    
    canvas.drawPicture(picture);
  }

  /// Record grid to picture with LOD support
  void _recordGrid(Canvas canvas, Size size) {
    final gridSize = _getGridSizeForLOD();
    final visibleBounds = _getVisibleGridBounds(size, gridSize);
    
    final paint = _getCachedPaint('grid')
      ..color = Colors.white.withOpacity(_getGridOpacityForLOD())
      ..strokeWidth = _getGridStrokeWidthForLOD()
      ..style = PaintingStyle.stroke;
    
    // Draw vertical lines (with culling)
    for (int i = visibleBounds.left; i <= visibleBounds.right; i++) {
      final x = i * gridSize;
      if (x >= viewport.left && x <= viewport.right) {
        canvas.drawLine(
          Offset(x, visibleBounds.top * gridSize),
          Offset(x, visibleBounds.bottom * gridSize),
          paint,
        );
      }
    }
    
    // Draw horizontal lines (with culling)
    for (int i = visibleBounds.top; i <= visibleBounds.bottom; i++) {
      final y = i * gridSize;
      if (y >= viewport.top && y <= viewport.bottom) {
        canvas.drawLine(
          Offset(visibleBounds.left * gridSize, y),
          Offset(visibleBounds.right * gridSize, y),
          paint,
        );
      }
    }
    
    // Draw intersection points for high LOD
    if (controller._currentLOD == LevelOfDetail.high) {
      _drawGridIntersections(canvas, visibleBounds, gridSize);
    }
  }

  /// Get grid size based on LOD
  double _getGridSizeForLOD() {
    switch (controller._currentLOD) {
      case LevelOfDetail.low:
        return 100.0;
      case LevelOfDetail.medium:
        return 50.0;
      case LevelOfDetail.high:
        return 25.0;
    }
  }

  /// Get grid opacity based on LOD
  double _getGridOpacityForLOD() {
    switch (controller._currentLOD) {
      case LevelOfDetail.low:
        return 0.05;
      case LevelOfDetail.medium:
        return 0.08;
      case LevelOfDetail.high:
        return 0.1;
    }
  }

  /// Get grid stroke width based on LOD
  double _getGridStrokeWidthForLOD() {
    switch (controller._currentLOD) {
      case LevelOfDetail.low:
        return 0.5;
      case LevelOfDetail.medium:
        return 0.75;
      case LevelOfDetail.high:
        return 1.0;
    }
  }

  /// Calculate visible grid bounds for culling
  GridBounds _getVisibleGridBounds(Size size, double gridSize) {
    final left = math.max(0, (viewport.left / gridSize).floor());
    final top = math.max(0, (viewport.top / gridSize).floor());
    final right = math.min(
      (size.width / gridSize).ceil(),
      (viewport.right / gridSize).ceil(),
    );
    final bottom = math.min(
      (size.height / gridSize).ceil(),
      (viewport.bottom / gridSize).ceil(),
    );
    
    return GridBounds(left: left, top: top, right: right, bottom: bottom);
  }

  /// Draw grid intersection points
  void _drawGridIntersections(Canvas canvas, GridBounds bounds, double gridSize) {
    final paint = _getCachedPaint('grid_intersections')
      ..color = Colors.white.withOpacity(0.15)
      ..style = PaintingStyle.fill;
    
    for (int i = bounds.left; i <= bounds.right; i++) {
      for (int j = bounds.top; j <= bounds.bottom; j++) {
        final point = Offset(i * gridSize, j * gridSize);
        if (viewport.contains(point)) {
          canvas.drawCircle(point, 1.5, paint);
        }
      }
    }
  }

  /// Draw completed sections with caching
  void _drawCompletedSections(Canvas canvas, Size size) {
    for (final sectionId in gameState.completedSections) {
      final bounds = _getSectionBounds(sectionId, size);
      if (bounds != null && viewport.overlaps(bounds)) {
        _drawCompletedSection(canvas, sectionId, bounds);
      }
    }
  }

  /// Draw a single completed section
  void _drawCompletedSection(Canvas canvas, String sectionId, Rect bounds) {
    var picture = controller.getSectionPicture(sectionId);
    
    if (picture == null) {
      final recorder = ui.PictureRecorder();
      final recordingCanvas = Canvas(recorder);
      
      _recordCompletedSection(recordingCanvas, bounds);
      
      picture = recorder.endRecording();
      controller.updateSectionPicture(sectionId, picture);
    }
    
    canvas.save();
    canvas.translate(bounds.left, bounds.top);
    canvas.drawPicture(picture);
    canvas.restore();
  }

  /// Record completed section to picture
  void _recordCompletedSection(Canvas canvas, Rect bounds) {
    final localBounds = Rect.fromLTWH(0, 0, bounds.width, bounds.height);
    
    // Glow effect (only for high/medium LOD)
    if (controller._currentLOD != LevelOfDetail.low) {
      final glowPaint = _getCachedPaint('section_glow')
        ..color = Colors.greenAccent.withOpacity(0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10)
        ..style = PaintingStyle.fill;
      
      canvas.drawRRect(
        RRect.fromRectAndRadius(localBounds, const Radius.circular(8)),
        glowPaint,
      );
    }
    
    // Background
    final backgroundPaint = _getCachedPaint('section_background')
      ..color = Colors.green.withOpacity(0.1)
      ..style = PaintingStyle.fill;
    
    canvas.drawRRect(
      RRect.fromRectAndRadius(localBounds, const Radius.circular(8)),
      backgroundPaint,
    );
    
    // Border
    final borderPaint = _getCachedPaint('section_border')
      ..color = Colors.greenAccent.withOpacity(0.5)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    
    canvas.drawRRect(
      RRect.fromRectAndRadius(localBounds, const Radius.circular(8)),
      borderPaint,
    );
    
    // Success pattern (only for high LOD)
    if (controller._currentLOD == LevelOfDetail.high) {
      _drawSuccessPattern(canvas, localBounds);
    }
  }

  /// Draw success pattern in completed section
  void _drawSuccessPattern(Canvas canvas, Rect bounds) {
    final paint = _getCachedPaint('success_pattern')
      ..color = Colors.greenAccent.withOpacity(0.1)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    
    // Draw diagonal lines
    const spacing = 10.0;
    final path = Path();
    
    for (double i = -bounds.height; i < bounds.width + bounds.height; i += spacing) {
      path.moveTo(i, 0);
      path.lineTo(i + bounds.height, bounds.height);
    }
    
    canvas.save();
    canvas.clipRect(bounds);
    canvas.drawPath(path, paint);
    canvas.restore();
  }

  /// Draw background effects
  void _drawEffects(Canvas canvas, Size size) {
    // Magnetic field visualization (only when zoomed in)
    if (zoomLevel > 1.5 && controller._currentLOD == LevelOfDetail.high) {
      _drawMagneticField(canvas, size);
    }
    
    // Ambient particles
    if (controller._currentLOD != LevelOfDetail.low) {
      _drawAmbientParticles(canvas, size);
    }
  }

  /// Draw magnetic field visualization
  void _drawMagneticField(Canvas canvas, Size size) {
    final paint = _getCachedPaint('magnetic_field')
      ..color = Colors.blueAccent.withOpacity(0.05)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;
    
    const gridSpacing = 30.0;
    final visibleBounds = _getVisibleGridBounds(size, gridSpacing);
    
    // Draw warped grid to represent field
    for (int i = visibleBounds.left; i <= visibleBounds.right; i++) {
      final path = Path();
      for (int j = visibleBounds.top; j <= visibleBounds.bottom; j++) {
        final x = i * gridSpacing;
        final y = j * gridSpacing;
        
        // Add wave distortion
        final waveX = x + math.sin(y / 50) * 5;
        
        if (j == visibleBounds.top) {
          path.moveTo(waveX, y);
        } else {
          path.lineTo(waveX, y);
        }
      }
      canvas.drawPath(path, paint);
    }
  }

  /// Draw ambient particles
  void _drawAmbientParticles(Canvas canvas, Size size) {
    final paint = _getCachedPaint('ambient_particles')
      ..color = Colors.white.withOpacity(0.3);
    
    // Use time-based seed for animation
    final time = DateTime.now().millisecondsSinceEpoch / 1000.0;
    final particleCount = controller._currentLOD == LevelOfDetail.high ? 20 : 10;
    
    for (int i = 0; i < particleCount; i++) {
      final phase = (time + i * 0.1) % 10.0;
      final opacity = math.sin(phase * math.pi / 5.0).abs();
      
      final x = (math.sin(i * 1.7) + 1) * size.width / 2;
      final y = (phase / 10.0) * size.height;
      
      paint.color = Colors.white.withOpacity(opacity * 0.3);
      canvas.drawCircle(Offset(x, y), 2.0, paint);
    }
  }

  /// Get section bounds (placeholder - should be provided by game state)
  Rect? _getSectionBounds(String sectionId, Size size) {
    // This should be provided by the actual game state
    // For now, using a simple grid layout
    final index = gameState.completedSections.indexOf(sectionId);
    if (index < 0) return null;
    
    const columns = 4;
    const padding = 10.0;
    final sectionWidth = (size.width - padding * (columns + 1)) / columns;
    final sectionHeight = sectionWidth * 0.75;
    
    final col = index % columns;
    final row = index ~/ columns;
    
    final x = padding + col * (sectionWidth + padding);
    final y = padding + row * (sectionHeight + padding);
    
    return Rect.fromLTWH(x, y, sectionWidth, sectionHeight);
  }

  /// Draw debug cache bounds
  void _drawDebugCacheBounds(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red.withOpacity(0.3)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    
    // Draw viewport bounds
    canvas.drawRect(viewport, paint);
    
    // Draw cached section bounds
    paint.color = Colors.blue.withOpacity(0.3);
    for (final sectionId in gameState.completedSections) {
      final bounds = _getSectionBounds(sectionId, size);
      if (bounds != null) {
        canvas.drawRect(bounds, paint);
      }
    }
    
    // Draw grid bounds
    paint.color = Colors.green.withOpacity(0.3);
    final gridSize = _getGridSizeForLOD();
    final gridBounds = _getVisibleGridBounds(size, gridSize);
    canvas.drawRect(
      Rect.fromLTRB(
        gridBounds.left * gridSize,
        gridBounds.top * gridSize,
        gridBounds.right * gridSize,
        gridBounds.bottom * gridSize,
      ),
      paint,
    );
  }

  /// Draw performance overlay
  void _drawPerformanceOverlay(Canvas canvas, Size size) {
    final metrics = controller.getPerformanceMetrics();
    
    // Background for text
    final backgroundPaint = Paint()
      ..color = Colors.black.withOpacity(0.7)
      ..style = PaintingStyle.fill;
    
    final overlayRect = Rect.fromLTWH(10, 10, 200, 100);
    canvas.drawRRect(
      RRect.fromRectAndRadius(overlayRect, const Radius.circular(8)),
      backgroundPaint,
    );
    
    // Draw performance text
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        style: const TextStyle(color: Colors.white, fontSize: 12),
        children: [
          TextSpan(text: 'FPS: ${metrics.fps.toStringAsFixed(1)}\n'),
          TextSpan(text: 'Paint: ${metrics.averagePaintTime.inMicroseconds}μs\n'),
          TextSpan(text: 'Cache hits: ${metrics.cacheHitRate.toStringAsFixed(1)}%\n'),
          TextSpan(text: 'LOD: ${controller._currentLOD.name}\n'),
          TextSpan(text: 'Sections: ${gameState.completedSections.length}'),
        ],
      ),
    );
    
    textPainter.layout(maxWidth: 180);
    textPainter.paint(canvas, const Offset(20, 20));
  }

  /// Get or create cached Paint object
  Paint _getCachedPaint(String key) {
    return _paintCache.putIfAbsent(key, () => Paint());
  }

  @override
  bool shouldRepaint(StaticLayerPainter oldDelegate) {
    return oldDelegate.gameState != gameState ||
           oldDelegate.viewport != viewport ||
           oldDelegate.zoomLevel != zoomLevel ||
           controller._needsGridUpdate ||
           controller._needsBackgroundUpdate ||
           controller._dirtySection.isNotEmpty;
  }
}

/// Level of detail settings
enum LevelOfDetail {
  low,    // Minimal details, larger grid, no effects
  medium, // Moderate details, standard grid, basic effects
  high,   // Full details, fine grid, all effects
}

/// Grid bounds for culling
class GridBounds {
  final int left;
  final int top;
  final int right;
  final int bottom;

  const GridBounds({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });
}

/// Performance tracking
class PerformanceTracker {
  final Queue<Duration> _paintTimes = Queue();
  final Queue<DateTime> _frameTimestamps = Queue();
  static const int maxSamples = 60;
  
  int _cacheHits = 0;
  int _cacheMisses = 0;

  void recordPaintTime(Duration time) {
    _paintTimes.add(time);
    _frameTimestamps.add(DateTime.now());
    
    // Maintain max samples
    while (_paintTimes.length > maxSamples) {
      _paintTimes.removeFirst();
      _frameTimestamps.removeFirst();
    }
  }

  void recordCacheHit() {
    _cacheHits++;
  }

  void recordCacheMiss() {
    _cacheMisses++;
  }

  PerformanceMetrics getMetrics() {
    final now = DateTime.now();
    
    // Calculate FPS
    double fps = 0;
    if (_frameTimestamps.length >= 2) {
      final oldestTime = _frameTimestamps.first;
      final duration = now.difference(oldestTime);
      if (duration.inMilliseconds > 0) {
        fps = (_frameTimestamps.length / duration.inSeconds).clamp(0, 120);
      }
    }
    
    // Calculate average paint time
    Duration averagePaintTime = Duration.zero;
    if (_paintTimes.isNotEmpty) {
      final totalMicroseconds = _paintTimes.fold<int>(
        0,
        (sum, time) => sum + time.inMicroseconds,
      );
      averagePaintTime = Duration(
        microseconds: totalMicroseconds ~/ _paintTimes.length,
      );
    }
    
    // Calculate cache hit rate
    final totalCacheAccess = _cacheHits + _cacheMisses;
    final cacheHitRate = totalCacheAccess > 0
        ? (_cacheHits / totalCacheAccess) * 100
        : 100.0;
    
    return PerformanceMetrics(
      fps: fps,
      averagePaintTime: averagePaintTime,
      cacheHitRate: cacheHitRate,
      samples: _paintTimes.length,
    );
  }

  void reset() {
    _paintTimes.clear();
    _frameTimestamps.clear();
    _cacheHits = 0;
    _cacheMisses = 0;
  }
}

/// Performance metrics data
class PerformanceMetrics {
  final double fps;
  final Duration averagePaintTime;
  final double cacheHitRate;
  final int samples;

  const PerformanceMetrics({
    required this.fps,
    required this.averagePaintTime,
    required this.cacheHitRate,
    required this.samples,
  });
}

/// Game state interface (should be implemented by actual game)
abstract class GameState {
  bool get showGrid;
  List<String> get completedSections;
  Map<String, dynamic> get metadata;
}

/// Static layer widget for easy integration
class StaticLayer extends StatefulWidget {
  final Size size;
  final GameState gameState;
  final Rect viewport;
  final double zoomLevel;
  final bool debugMode;

  const StaticLayer({
    super.key,
    required this.size,
    required this.gameState,
    required this.viewport,
    this.zoomLevel = 1.0,
    this.debugMode = false,
  });

  @override
  State<StaticLayer> createState() => _StaticLayerState();
}

class _StaticLayerState extends State<StaticLayer> {
  late final StaticLayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = StaticLayerController();
    
    // Configure debug mode
    if (widget.debugMode) {
      _controller.debugShowGrid = true;
      _controller.debugShowCacheBounds = true;
      _controller.debugShowPerformanceOverlay = true;
    }
  }

  @override
  void didUpdateWidget(StaticLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Check for completed section changes
    if (oldWidget.gameState.completedSections.length != 
        widget.gameState.completedSections.length) {
      // Find new sections
      final newSections = widget.gameState.completedSections
          .where((s) => !oldWidget.gameState.completedSections.contains(s));
      
      for (final section in newSections) {
        final bounds = _getSectionBounds(section);
        if (bounds != null) {
          _controller.onSectionCompleted(section, bounds);
        }
      }
    }
    
    // Update grid visibility
    if (oldWidget.gameState.showGrid != widget.gameState.showGrid) {
      _controller.invalidateGrid();
    }
  }

  Rect? _getSectionBounds(String sectionId) {
    // This should be provided by the actual game state
    // Using placeholder implementation from painter
    final index = widget.gameState.completedSections.indexOf(sectionId);
    if (index < 0) return null;
    
    const columns = 4;
    const padding = 10.0;
    final sectionWidth = (widget.size.width - padding * (columns + 1)) / columns;
    final sectionHeight = sectionWidth * 0.75;
    
    final col = index % columns;
    final row = index ~/ columns;
    
    final x = padding + col * (sectionWidth + padding);
    final y = padding + row * (sectionHeight + padding);
    
    return Rect.fromLTWH(x, y, sectionWidth, sectionHeight);
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: widget.size,
        painter: StaticLayerPainter(
          controller: _controller,
          gameState: widget.gameState,
          viewport: widget.viewport,
          zoomLevel: widget.zoomLevel,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
