/// Hybrid Rendering Pipeline for Puzzle Nook
/// 
/// This implementation provides a three-layer rendering architecture that combines
/// the best of Flutter widgets, custom painting, and game engine capabilities.
/// 
/// Architecture:
/// - Layer 1: StaticLayer (CustomPaint with Picture caching)
/// - Layer 2: DynamicLayer (Widgets with RepaintBoundary)
/// - Layer 3: EffectsLayer (Flame engine integration)
/// 
/// Features:
/// - Independent layer updates for optimal performance
/// - Dirty region tracking to minimize repaints
/// - Frame budget management (16ms target)
/// - Automatic quality adjustment based on performance
/// - RenderObject optimizations
/// - Performance monitoring and reporting

import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:vector_math/vector_math_64.dart' as vector_math;

// Import layer implementations
part 'layers/static_layer.dart';
part 'layers/dynamic_layer.dart';
part 'layers/effects_layer.dart';
part 'core/coordinate_system.dart';
part 'core/dirty_region_tracker.dart';
part 'core/frame_budget_manager.dart';
part 'core/performance_monitor.dart';
part 'core/quality_manager.dart';
part 'core/render_scheduler.dart';

/// Main hybrid renderer that orchestrates all rendering layers
class HybridRenderer extends StatefulWidget {
  final Size gameSize;
  final List<RenderablePiece> pieces;
  final GameState gameState;
  final RenderingConfig config;
  final ValueChanged<PerformanceMetrics>? onPerformanceUpdate;
  final VoidCallback? onFrameDropped;

  const HybridRenderer({
    super.key,
    required this.gameSize,
    required this.pieces,
    required this.gameState,
    this.config = const RenderingConfig(),
    this.onPerformanceUpdate,
    this.onFrameDropped,
  });

  @override
  State<HybridRenderer> createState() => _HybridRendererState();
}

class _HybridRendererState extends State<HybridRenderer>
    with TickerProviderStateMixin {
  // Core systems
  late final CoordinateSystem _coordinateSystem;
  late final DirtyRegionTracker _dirtyRegionTracker;
  late final FrameBudgetManager _frameBudgetManager;
  late final PerformanceMonitor _performanceMonitor;
  late final QualityManager _qualityManager;
  late final RenderScheduler _renderScheduler;

  // Layer controllers
  late final StaticLayerController _staticLayerController;
  late final DynamicLayerController _dynamicLayerController;
  late final EffectsLayerController _effectsLayerController;

  // Performance tracking
  final _frameTimings = ListQueue<Duration>(100);
  Timer? _performanceReportTimer;
  int _frameCount = 0;
  int _droppedFrames = 0;

  @override
  void initState() {
    super.initState();
    _initializeSystems();
    _startPerformanceMonitoring();
  }

  void _initializeSystems() {
    // Initialize coordinate system
    _coordinateSystem = CoordinateSystem(
      screenSize: MediaQuery.sizeOf(context),
      gameSize: widget.gameSize,
    );

    // Initialize tracking systems
    _dirtyRegionTracker = DirtyRegionTracker();
    _frameBudgetManager = FrameBudgetManager(
      targetFrameTime: widget.config.targetFrameTime,
    );

    // Initialize performance monitoring
    _performanceMonitor = PerformanceMonitor(
      onMetricsUpdate: _handlePerformanceMetrics,
    );

    // Initialize quality management
    _qualityManager = QualityManager(
      initialQuality: widget.config.initialQuality,
      autoAdjust: widget.config.autoAdjustQuality,
    );

    // Initialize render scheduler
    _renderScheduler = RenderScheduler(
      frameBudgetManager: _frameBudgetManager,
      onScheduledRender: _performLayerRender,
    );

    // Initialize layer controllers
    _staticLayerController = StaticLayerController(
      coordinateSystem: _coordinateSystem,
      dirtyRegionTracker: _dirtyRegionTracker,
    );

    _dynamicLayerController = DynamicLayerController(
      coordinateSystem: _coordinateSystem,
      qualityManager: _qualityManager,
    );

    _effectsLayerController = EffectsLayerController(
      coordinateSystem: _coordinateSystem,
      qualityManager: _qualityManager,
    );
  }

  void _startPerformanceMonitoring() {
    // Monitor frame timings
    SchedulerBinding.instance.addPostFrameCallback(_onFrameComplete);

    // Start periodic performance reporting
    _performanceReportTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _reportPerformance(),
    );
  }

  void _onFrameComplete(Duration timestamp) {
    _frameCount++;

    // Track frame timing
    if (_frameTimings.length >= 100) {
      _frameTimings.removeFirst();
    }
    _frameTimings.add(timestamp);

    // Check for dropped frames
    if (timestamp > widget.config.targetFrameTime) {
      _droppedFrames++;
      widget.onFrameDropped?.call();

      // Adjust quality if dropping too many frames
      if (_droppedFrames > widget.config.maxDroppedFrames) {
        _qualityManager.decreaseQuality();
        _droppedFrames = 0;
      }
    }

    // Schedule next frame callback
    SchedulerBinding.instance.addPostFrameCallback(_onFrameComplete);
  }

  void _handlePerformanceMetrics(PerformanceMetrics metrics) {
    // Update quality based on performance
    _qualityManager.updateFromMetrics(metrics);

    // Notify external listeners
    widget.onPerformanceUpdate?.call(metrics);

    // Log performance issues
    if (metrics.fps < 30) {
      debugPrint('Performance warning: FPS dropped to ${metrics.fps}');
    }
  }

  void _reportPerformance() {
    if (_frameTimings.isEmpty) return;

    final averageFrameTime = _frameTimings.reduce((a, b) => a + b) ~/
        _frameTimings.length;
    final fps = _frameCount;
    
    final metrics = PerformanceMetrics(
      fps: fps,
      averageFrameTime: averageFrameTime,
      droppedFrames: _droppedFrames,
      memoryUsage: _getMemoryUsage(),
      quality: _qualityManager.currentQuality,
    );

    _performanceMonitor.recordMetrics(metrics);

    // Reset counters
    _frameCount = 0;
    _droppedFrames = 0;
  }

  double _getMemoryUsage() {
    // This is a placeholder - implement actual memory tracking
    // In production, use a proper memory profiling tool
    return 0.0;
  }

  void _performLayerRender(RenderLayer layer) {
    setState(() {
      switch (layer) {
        case RenderLayer.static:
          _staticLayerController.markNeedsRepaint();
          break;
        case RenderLayer.dynamic:
          _dynamicLayerController.updatePieces(widget.pieces);
          break;
        case RenderLayer.effects:
          _effectsLayerController.update();
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Update coordinate system if size changes
        _coordinateSystem.updateScreenSize(constraints.biggest);

        return Stack(
          children: [
            // Layer 1: Static background layer
            _buildStaticLayer(constraints),

            // Layer 2: Dynamic piece layer
            _buildDynamicLayer(constraints),

            // Layer 3: Effects layer
            _buildEffectsLayer(constraints),

            // Debug overlay (only in debug mode)
            if (kDebugMode && widget.config.showDebugOverlay)
              _buildDebugOverlay(),
          ],
        );
      },
    );
  }

  Widget _buildStaticLayer(BoxConstraints constraints) {
    return RepaintBoundary(
      child: CustomPaint(
        size: constraints.biggest,
        painter: StaticLayerPainter(
          controller: _staticLayerController,
          gameState: widget.gameState,
          quality: _qualityManager.currentQuality,
        ),
      ),
    );
  }

  Widget _buildDynamicLayer(BoxConstraints constraints) {
    return DynamicPieceLayer(
      controller: _dynamicLayerController,
      pieces: widget.pieces,
      coordinateSystem: _coordinateSystem,
      quality: _qualityManager.currentQuality,
      onPieceTransform: (pieceId, transform) {
        // Mark region as dirty
        final bounds = _calculatePieceBounds(pieceId, transform);
        _dirtyRegionTracker.markDirty(bounds);

        // Schedule update if needed
        _renderScheduler.scheduleUpdate(RenderLayer.dynamic);
      },
    );
  }

  Widget _buildEffectsLayer(BoxConstraints constraints) {
    return IgnorePointer(
      child: EffectsLayer(
        controller: _effectsLayerController,
        size: constraints.biggest,
        quality: _qualityManager.currentQuality,
      ),
    );
  }

  Widget _buildDebugOverlay() {
    return Positioned(
      top: 10,
      right: 10,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'FPS: ${_frameCount}',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
            Text(
              'Dropped: $_droppedFrames',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
            Text(
              'Quality: ${_qualityManager.currentQuality.name}',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
            Text(
              'Dirty Regions: ${_dirtyRegionTracker.dirtyRegionCount}',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Rect _calculatePieceBounds(String pieceId, Matrix4 transform) {
    // Calculate bounds of transformed piece
    // This is a simplified implementation - enhance based on actual piece data
    const pieceSize = Size(100, 100);
    final translation = transform.getTranslation();
    return Rect.fromLTWH(
      translation.x,
      translation.y,
      pieceSize.width,
      pieceSize.height,
    );
  }

  @override
  void dispose() {
    _performanceReportTimer?.cancel();
    _staticLayerController.dispose();
    _dynamicLayerController.dispose();
    _effectsLayerController.dispose();
    _performanceMonitor.dispose();
    super.dispose();
  }
}

/// Configuration for the hybrid renderer
class RenderingConfig {
  final Duration targetFrameTime;
  final QualityLevel initialQuality;
  final bool autoAdjustQuality;
  final int maxDroppedFrames;
  final bool showDebugOverlay;

  const RenderingConfig({
    this.targetFrameTime = const Duration(milliseconds: 16),
    this.initialQuality = QualityLevel.high,
    this.autoAdjustQuality = true,
    this.maxDroppedFrames = 5,
    this.showDebugOverlay = false,
  });
}

/// Quality levels for rendering
enum QualityLevel {
  low(0.5, 30, false, false),
  medium(0.75, 60, true, false),
  high(1.0, 60, true, true),
  ultra(1.0, 120, true, true);

  final double resolutionScale;
  final int targetFps;
  final bool enableShadows;
  final bool enableParticles;

  const QualityLevel(
    this.resolutionScale,
    this.targetFps,
    this.enableShadows,
    this.enableParticles,
  );
}

/// Render layers
enum RenderLayer {
  static,
  dynamic,
  effects,
}

/// Performance metrics
class PerformanceMetrics {
  final int fps;
  final Duration averageFrameTime;
  final int droppedFrames;
  final double memoryUsage;
  final QualityLevel quality;

  const PerformanceMetrics({
    required this.fps,
    required this.averageFrameTime,
    required this.droppedFrames,
    required this.memoryUsage,
    required this.quality,
  });
}

/// Base classes for game state and pieces
abstract class GameState {
  bool get showGrid;
  List<String> get completedSections;
  Map<String, dynamic> get metadata;
}

abstract class RenderablePiece {
  String get id;
  Offset get position;
  double get rotation;
  Size get size;
  bool get isSelected;
  bool get isPlaced;
  bool get isDragging;
}
