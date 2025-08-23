import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:vector_math/vector_math_64.dart';

/// Represents a point in screen space (device pixels).
/// This is the physical pixel coordinate on the device.
@immutable
class ScreenPoint {
  final double x;
  final double y;

  const ScreenPoint(this.x, this.y);

  Vector3 toVector3() => Vector3(x, y, 0);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScreenPoint && x == other.x && y == other.y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'ScreenPoint($x, $y)';
}

/// Represents a point in canvas space (logical units).
/// This is device-independent and uses Flutter's logical pixels.
@immutable
class CanvasPoint {
  final double x;
  final double y;

  const CanvasPoint(this.x, this.y);

  Vector3 toVector3() => Vector3(x, y, 0);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CanvasPoint && x == other.x && y == other.y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'CanvasPoint($x, $y)';
}

/// Represents a point in grid space (puzzle grid coordinates).
/// Integer coordinates representing grid cells.
@immutable
class GridPoint {
  final int x;
  final int y;

  const GridPoint(this.x, this.y);

  Vector3 toVector3() => Vector3(x.toDouble(), y.toDouble(), 0);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GridPoint && x == other.x && y == other.y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'GridPoint($x, $y)';
}

/// Represents a point in workspace space (drag area coordinates).
/// This is the coordinate system for the larger workspace where pieces can be dragged.
@immutable
class WorkspacePoint {
  final double x;
  final double y;

  const WorkspacePoint(this.x, this.y);

  Vector3 toVector3() => Vector3(x, y, 0);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkspacePoint && x == other.x && y == other.y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'WorkspacePoint($x, $y)';
}

/// Configuration for the coordinate system.
class CoordinateSystemConfig {
  /// Device pixel ratio (e.g., 2.0 for Retina displays)
  final double devicePixelRatio;

  /// Size of the canvas in logical pixels
  final ui.Size canvasSize;

  /// Size of each grid cell in canvas units
  final double gridCellSize;

  /// Number of grid cells horizontally
  final int gridWidth;

  /// Number of grid cells vertically
  final int gridHeight;

  /// Workspace bounds in canvas units
  final ui.Rect workspaceBounds;

  /// Current zoom level (1.0 = 100%)
  final double zoomLevel;

  /// Current pan offset in canvas units
  final ui.Offset panOffset;

  const CoordinateSystemConfig({
    required this.devicePixelRatio,
    required this.canvasSize,
    required this.gridCellSize,
    required this.gridWidth,
    required this.gridHeight,
    required this.workspaceBounds,
    this.zoomLevel = 1.0,
    this.panOffset = ui.Offset.zero,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CoordinateSystemConfig &&
          devicePixelRatio == other.devicePixelRatio &&
          canvasSize == other.canvasSize &&
          gridCellSize == other.gridCellSize &&
          gridWidth == other.gridWidth &&
          gridHeight == other.gridHeight &&
          workspaceBounds == other.workspaceBounds &&
          zoomLevel == other.zoomLevel &&
          panOffset == other.panOffset;

  @override
  int get hashCode => Object.hash(
        devicePixelRatio,
        canvasSize,
        gridCellSize,
        gridWidth,
        gridHeight,
        workspaceBounds,
        zoomLevel,
        panOffset,
      );
}

/// High-performance coordinate system for transforming between different spaces.
/// 
/// This system handles four coordinate spaces:
/// 1. **Screen Space**: Physical device pixels
/// 2. **Canvas Space**: Logical pixels (device-independent)
/// 3. **Grid Space**: Integer grid coordinates for puzzle pieces
/// 4. **Workspace Space**: Continuous coordinates for the drag area
/// 
/// All transformations use Matrix4 for optimal performance and are cached
/// when possible to achieve < 0.1ms transformation times.
class CoordinateSystem {
  CoordinateSystemConfig _config;
  
  // Cached transformation matrices
  Matrix4? _screenToCanvasMatrix;
  Matrix4? _canvasToScreenMatrix;
  Matrix4? _canvasToGridMatrix;
  Matrix4? _gridToCanvasMatrix;
  Matrix4? _canvasToWorkspaceMatrix;
  Matrix4? _workspaceToCanvasMatrix;
  
  // Performance tracking
  final _transformationTimes = <Duration>[];
  static const int _maxTimeSamples = 100;

  CoordinateSystem(this._config) {
    _buildTransformationMatrices();
  }

  /// Updates the configuration and rebuilds transformation matrices.
  void updateConfig(CoordinateSystemConfig newConfig) {
    if (_config == newConfig) return;
    _config = newConfig;
    _invalidateCache();
    _buildTransformationMatrices();
  }

  /// Gets the current configuration.
  CoordinateSystemConfig get config => _config;

  /// Invalidates all cached transformation matrices.
  void _invalidateCache() {
    _screenToCanvasMatrix = null;
    _canvasToScreenMatrix = null;
    _canvasToGridMatrix = null;
    _gridToCanvasMatrix = null;
    _canvasToWorkspaceMatrix = null;
    _workspaceToCanvasMatrix = null;
  }

  /// Builds all transformation matrices.
  /// 
  /// Mathematical explanation:
  /// - Screen ↔ Canvas: Scale by devicePixelRatio
  /// - Canvas ↔ Grid: Scale by gridCellSize, apply zoom and pan
  /// - Canvas ↔ Workspace: Translate and scale to workspace bounds
  void _buildTransformationMatrices() {
    final stopwatch = Stopwatch()..start();

    // Screen to Canvas: Divide by device pixel ratio
    _screenToCanvasMatrix = Matrix4.identity()
      ..scale(1.0 / _config.devicePixelRatio, 1.0 / _config.devicePixelRatio);

    // Canvas to Screen: Multiply by device pixel ratio
    _canvasToScreenMatrix = Matrix4.identity()
      ..scale(_config.devicePixelRatio, _config.devicePixelRatio);

    // Note: Canvas to Grid transformations are now done directly in the methods
    // for better accuracy and to avoid matrix multiplication issues
    _canvasToGridMatrix = null;
    _gridToCanvasMatrix = null;

    // Canvas to Workspace: Map canvas to workspace bounds
    final workspaceScaleX = _config.workspaceBounds.width / _config.canvasSize.width;
    final workspaceScaleY = _config.workspaceBounds.height / _config.canvasSize.height;
    
    _canvasToWorkspaceMatrix = Matrix4.identity()
      ..translate(_config.workspaceBounds.left, _config.workspaceBounds.top)
      ..scale(workspaceScaleX, workspaceScaleY);

    // Workspace to Canvas: Inverse of above
    _workspaceToCanvasMatrix = Matrix4.identity()
      ..scale(1.0 / workspaceScaleX, 1.0 / workspaceScaleY)
      ..translate(-_config.workspaceBounds.left, -_config.workspaceBounds.top);

    stopwatch.stop();
    _recordTransformationTime(stopwatch.elapsed);
  }

  /// Records transformation time for performance monitoring.
  void _recordTransformationTime(Duration duration) {
    _transformationTimes.add(duration);
    if (_transformationTimes.length > _maxTimeSamples) {
      _transformationTimes.removeAt(0);
    }
  }

  /// Gets the average transformation time in microseconds.
  double get averageTransformationTimeUs {
    if (_transformationTimes.isEmpty) return 0;
    final totalUs = _transformationTimes
        .map((d) => d.inMicroseconds)
        .reduce((a, b) => a + b);
    return totalUs / _transformationTimes.length;
  }

  /// Transforms a point using the given matrix.
  Vector3 _transformPoint(Vector3 point, Matrix4 matrix) {
    final stopwatch = Stopwatch()..start();
    final transformed = matrix.transformed3(point);
    stopwatch.stop();
    _recordTransformationTime(stopwatch.elapsed);
    return transformed;
  }

  // Screen ↔ Canvas transformations

  /// Converts a screen point (device pixels) to canvas point (logical pixels).
  CanvasPoint screenToCanvas(ScreenPoint point) {
    _screenToCanvasMatrix ??= Matrix4.identity()
      ..scale(1.0 / _config.devicePixelRatio, 1.0 / _config.devicePixelRatio);
    
    final transformed = _transformPoint(point.toVector3(), _screenToCanvasMatrix!);
    return CanvasPoint(transformed.x, transformed.y);
  }

  /// Converts a canvas point (logical pixels) to screen point (device pixels).
  ScreenPoint canvasToScreen(CanvasPoint point) {
    _canvasToScreenMatrix ??= Matrix4.identity()
      ..scale(_config.devicePixelRatio, _config.devicePixelRatio);
    
    final transformed = _transformPoint(point.toVector3(), _canvasToScreenMatrix!);
    return ScreenPoint(transformed.x, transformed.y);
  }

  // Canvas ↔ Grid transformations

  /// Converts a canvas point to grid coordinates.
  /// Returns null if the point is outside the valid grid bounds.
  GridPoint? canvasToGrid(CanvasPoint point) {
    // Apply pan offset first, then scale
    final adjustedX = (point.x - _config.panOffset.dx) / (_config.gridCellSize * _config.zoomLevel);
    final adjustedY = (point.y - _config.panOffset.dy) / (_config.gridCellSize * _config.zoomLevel);
    
    final gridX = adjustedX.floor();
    final gridY = adjustedY.floor();

    // Validate grid bounds
    if (gridX < 0 || gridX >= _config.gridWidth ||
        gridY < 0 || gridY >= _config.gridHeight) {
      return null;
    }

    return GridPoint(gridX, gridY);
  }

  /// Converts a grid point to canvas coordinates.
  /// Returns the center of the grid cell in canvas space.
  CanvasPoint gridToCanvas(GridPoint point) {
    // Add 0.5 to get the center of the grid cell
    final centerX = (point.x + 0.5) * _config.gridCellSize * _config.zoomLevel + _config.panOffset.dx;
    final centerY = (point.y + 0.5) * _config.gridCellSize * _config.zoomLevel + _config.panOffset.dy;
    
    return CanvasPoint(centerX, centerY);
  }

  /// Gets the canvas bounds of a grid cell.
  ui.Rect gridCellToCanvasBounds(GridPoint point) {
    final cellSize = _config.gridCellSize * _config.zoomLevel;
    final left = point.x * cellSize + _config.panOffset.dx;
    final top = point.y * cellSize + _config.panOffset.dy;
    
    return ui.Rect.fromLTWH(
      left,
      top,
      cellSize,
      cellSize,
    );
  }

  // Canvas ↔ Workspace transformations

  /// Converts a canvas point to workspace coordinates.
  WorkspacePoint canvasToWorkspace(CanvasPoint point) {
    _canvasToWorkspaceMatrix ??= Matrix4.identity()
      ..translate(_config.workspaceBounds.left, _config.workspaceBounds.top)
      ..scale(
        _config.workspaceBounds.width / _config.canvasSize.width,
        _config.workspaceBounds.height / _config.canvasSize.height,
      );
    
    final transformed = _transformPoint(point.toVector3(), _canvasToWorkspaceMatrix!);
    return WorkspacePoint(transformed.x, transformed.y);
  }

  /// Converts a workspace point to canvas coordinates.
  CanvasPoint workspaceToCanvas(WorkspacePoint point) {
    _workspaceToCanvasMatrix ??= Matrix4.identity()
      ..scale(
        _config.canvasSize.width / _config.workspaceBounds.width,
        _config.canvasSize.height / _config.workspaceBounds.height,
      )
      ..translate(-_config.workspaceBounds.left, -_config.workspaceBounds.top);
    
    final transformed = _transformPoint(point.toVector3(), _workspaceToCanvasMatrix!);
    return CanvasPoint(transformed.x, transformed.y);
  }

  // Composite transformations (for convenience)

  /// Converts screen coordinates directly to grid coordinates.
  GridPoint? screenToGrid(ScreenPoint point) {
    final canvasPoint = screenToCanvas(point);
    return canvasToGrid(canvasPoint);
  }

  /// Converts grid coordinates directly to screen coordinates.
  ScreenPoint gridToScreen(GridPoint point) {
    final canvasPoint = gridToCanvas(point);
    return canvasToScreen(canvasPoint);
  }

  /// Converts screen coordinates directly to workspace coordinates.
  WorkspacePoint screenToWorkspace(ScreenPoint point) {
    final canvasPoint = screenToCanvas(point);
    return canvasToWorkspace(canvasPoint);
  }

  /// Converts workspace coordinates directly to screen coordinates.
  ScreenPoint workspaceToScreen(WorkspacePoint point) {
    final canvasPoint = workspaceToCanvas(point);
    return canvasToScreen(canvasPoint);
  }

  /// Converts grid coordinates directly to workspace coordinates.
  WorkspacePoint gridToWorkspace(GridPoint point) {
    final canvasPoint = gridToCanvas(point);
    return canvasToWorkspace(canvasPoint);
  }

  /// Converts workspace coordinates to grid coordinates.
  GridPoint? workspaceToGrid(WorkspacePoint point) {
    final canvasPoint = workspaceToCanvas(point);
    return canvasToGrid(canvasPoint);
  }

  // Utility methods

  /// Checks if a screen point is within the valid canvas bounds.
  bool isPointInCanvas(ScreenPoint point) {
    final canvasPoint = screenToCanvas(point);
    return canvasPoint.x >= 0 &&
        canvasPoint.x < _config.canvasSize.width &&
        canvasPoint.y >= 0 &&
        canvasPoint.y < _config.canvasSize.height;
  }

  /// Checks if a canvas point is within the valid grid bounds.
  bool isPointInGrid(CanvasPoint point) {
    final gridPoint = canvasToGrid(point);
    return gridPoint != null;
  }

  /// Gets the visible grid bounds in canvas space.
  ui.Rect getVisibleGridBounds() {
    final gridWidth = _config.gridWidth * _config.gridCellSize * _config.zoomLevel;
    final gridHeight = _config.gridHeight * _config.gridCellSize * _config.zoomLevel;
    
    return ui.Rect.fromLTWH(
      _config.panOffset.dx,
      _config.panOffset.dy,
      gridWidth,
      gridHeight,
    );
  }

  /// Applies zoom centered at a specific canvas point.
  void applyZoom(double zoomDelta, CanvasPoint center) {
    final oldZoom = _config.zoomLevel;
    final newZoom = (oldZoom * zoomDelta).clamp(0.1, 10.0);
    
    if (newZoom == oldZoom) return;

    // Calculate the grid position at the center point before zoom
    final gridX = (center.x - _config.panOffset.dx) / (_config.gridCellSize * oldZoom);
    final gridY = (center.y - _config.panOffset.dy) / (_config.gridCellSize * oldZoom);
    
    // Calculate new pan to keep the same grid position at the center point
    final newPanX = center.x - gridX * _config.gridCellSize * newZoom;
    final newPanY = center.y - gridY * _config.gridCellSize * newZoom;

    updateConfig(CoordinateSystemConfig(
      devicePixelRatio: _config.devicePixelRatio,
      canvasSize: _config.canvasSize,
      gridCellSize: _config.gridCellSize,
      gridWidth: _config.gridWidth,
      gridHeight: _config.gridHeight,
      workspaceBounds: _config.workspaceBounds,
      zoomLevel: newZoom,
      panOffset: ui.Offset(newPanX, newPanY),
    ));
  }

  /// Applies pan by the given delta in canvas units.
  void applyPan(ui.Offset delta) {
    final newPanOffset = _config.panOffset + delta;
    
    updateConfig(CoordinateSystemConfig(
      devicePixelRatio: _config.devicePixelRatio,
      canvasSize: _config.canvasSize,
      gridCellSize: _config.gridCellSize,
      gridWidth: _config.gridWidth,
      gridHeight: _config.gridHeight,
      workspaceBounds: _config.workspaceBounds,
      zoomLevel: _config.zoomLevel,
      panOffset: newPanOffset,
    ));
  }

  /// Resets zoom and pan to default values.
  void resetView() {
    updateConfig(CoordinateSystemConfig(
      devicePixelRatio: _config.devicePixelRatio,
      canvasSize: _config.canvasSize,
      gridCellSize: _config.gridCellSize,
      gridWidth: _config.gridWidth,
      gridHeight: _config.gridHeight,
      workspaceBounds: _config.workspaceBounds,
      zoomLevel: 1.0,
      panOffset: ui.Offset.zero,
    ));
  }

  /// Centers the view on a specific grid point.
  void centerOnGridPoint(GridPoint point) {
    // Calculate where the grid point would be without pan
    final gridCenterX = (point.x + 0.5) * _config.gridCellSize * _config.zoomLevel;
    final gridCenterY = (point.y + 0.5) * _config.gridCellSize * _config.zoomLevel;
    
    final centerX = _config.canvasSize.width / 2;
    final centerY = _config.canvasSize.height / 2;
    
    final newPanOffset = ui.Offset(
      centerX - gridCenterX,
      centerY - gridCenterY,
    );

    updateConfig(CoordinateSystemConfig(
      devicePixelRatio: _config.devicePixelRatio,
      canvasSize: _config.canvasSize,
      gridCellSize: _config.gridCellSize,
      gridWidth: _config.gridWidth,
      gridHeight: _config.gridHeight,
      workspaceBounds: _config.workspaceBounds,
      zoomLevel: _config.zoomLevel,
      panOffset: newPanOffset,
    ));
  }

  /// Fits the entire grid in the canvas view.
  void fitGridToView() {
    final gridPixelWidth = _config.gridWidth * _config.gridCellSize;
    final gridPixelHeight = _config.gridHeight * _config.gridCellSize;
    
    final scaleX = _config.canvasSize.width / gridPixelWidth;
    final scaleY = _config.canvasSize.height / gridPixelHeight;
    final newZoom = math.min(scaleX, scaleY) * 0.9; // 90% to add some padding
    
    final centeredPanX = (_config.canvasSize.width - gridPixelWidth * newZoom) / 2;
    final centeredPanY = (_config.canvasSize.height - gridPixelHeight * newZoom) / 2;

    updateConfig(CoordinateSystemConfig(
      devicePixelRatio: _config.devicePixelRatio,
      canvasSize: _config.canvasSize,
      gridCellSize: _config.gridCellSize,
      gridWidth: _config.gridWidth,
      gridHeight: _config.gridHeight,
      workspaceBounds: _config.workspaceBounds,
      zoomLevel: newZoom,
      panOffset: ui.Offset(centeredPanX, centeredPanY),
    ));
  }

  /// Gets performance statistics.
  Map<String, dynamic> getPerformanceStats() {
    return {
      'averageTransformationTimeUs': averageTransformationTimeUs,
      'sampleCount': _transformationTimes.length,
      'meetsTargetPerformance': averageTransformationTimeUs < 100, // < 0.1ms
    };
  }
}
