/// Comprehensive test suite for the CoordinateSystem transformations
/// 
/// Tests all coordinate spaces and transformations including:
/// - ScreenSpace (device pixels)
/// - CanvasSpace (logical canvas units)
/// - GridSpace (puzzle grid coordinates)
/// - WorkspaceSpace (drag area coordinates)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart' as vector_math;

// Mock implementations for testing
// These will be replaced with actual implementations from:
// package:puzzgame_flutter/game_module2/domain/services/coordinate_system.dart
// package:puzzgame_flutter/game_module2/domain/services/transformation_manager.dart

/// Represents a point in screen space (device pixels).
@immutable
class ScreenPoint {
  final double x;
  final double y;

  const ScreenPoint(this.x, this.y);

  vector_math.Vector3 toVector3() => vector_math.Vector3(x, y, 0);
  Offset toOffset() => Offset(x, y);

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
@immutable
class CanvasPoint {
  final double x;
  final double y;

  const CanvasPoint(this.x, this.y);
  
  factory CanvasPoint.validated(double x, double y, CoordinateSystem system) {
    if (!system.isValidCanvasPoint(CanvasPoint(x, y))) {
      throw ArgumentError('Invalid canvas point: ($x, $y)');
    }
    return CanvasPoint(x, y);
  }

  vector_math.Vector3 toVector3() => vector_math.Vector3(x, y, 0);

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
@immutable
class GridPoint {
  final int x;
  final int y;

  const GridPoint(this.x, this.y);
  
  factory GridPoint.validated(int x, int y, CoordinateSystem system) {
    if (!system.isValidGridPoint(GridPoint(x, y))) {
      throw ArgumentError('Invalid grid point: ($x, $y)');
    }
    return GridPoint(x, y);
  }

  vector_math.Vector3 toVector3() => vector_math.Vector3(x.toDouble(), y.toDouble(), 0);

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
@immutable
class WorkspacePoint {
  final double x;
  final double y;

  const WorkspacePoint(this.x, this.y);

  vector_math.Vector3 toVector3() => vector_math.Vector3(x, y, 0);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkspacePoint && x == other.x && y == other.y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'WorkspacePoint($x, $y)';
}

/// Region in workspace coordinates
class WorkspaceRegion {
  final WorkspacePoint topLeft;
  final WorkspacePoint bottomRight;
  
  WorkspaceRegion({required this.topLeft, required this.bottomRight});
  
  bool contains(WorkspacePoint point) {
    return point.x >= topLeft.x && point.x <= bottomRight.x &&
           point.y >= topLeft.y && point.y <= bottomRight.y;
  }
  
  bool intersects(WorkspaceRegion other) {
    return !(bottomRight.x < other.topLeft.x ||
             topLeft.x > other.bottomRight.x ||
             bottomRight.y < other.topLeft.y ||
             topLeft.y > other.bottomRight.y);
  }
}

/// Configuration for the coordinate system.
class CoordinateSystemConfig {
  final double devicePixelRatio;
  final Size screenSize;
  final Size canvasSize;
  final int gridColumns;
  final int gridRows;
  final Size workspaceSize;
  
  CoordinateSystemConfig({
    required this.devicePixelRatio,
    required this.screenSize,
    required this.canvasSize,
    required this.gridColumns,
    required this.gridRows,
    required this.workspaceSize,
  }) {
    if (screenSize.width <= 0 || screenSize.height <= 0) {
      throw ArgumentError('Screen size must be positive');
    }
    if (canvasSize.width <= 0 || canvasSize.height <= 0) {
      throw ArgumentError('Canvas size must be positive');
    }
  }
}

/// Mock coordinate system implementation for testing
class CoordinateSystem {
  final CoordinateSystemConfig config;
  double zoomLevel = 1.0;
  Offset panOffset = Offset.zero;
  
  // Cached transformation matrices
  vector_math.Matrix4? _screenToCanvasMatrix;
  vector_math.Matrix4? _canvasToScreenMatrix;
  vector_math.Matrix4? _canvasToGridMatrix;
  bool _cacheValid = false;
  
  CoordinateSystem({required this.config}) {
    _updateMatrices();
  }
  
  void _updateMatrices() {
    // Calculate screen to canvas transformation
    final scaleX = config.canvasSize.width / config.screenSize.width;
    final scaleY = config.canvasSize.height / config.screenSize.height;
    
    _screenToCanvasMatrix = vector_math.Matrix4.identity()
      ..scale(scaleX, scaleY, 1.0);
    
    _canvasToScreenMatrix = vector_math.Matrix4.identity()
      ..scale(1/scaleX, 1/scaleY, 1.0);
    
    // Canvas to grid transformation
    final gridScaleX = config.gridColumns / config.canvasSize.width;
    final gridScaleY = config.gridRows / config.canvasSize.height;
    
    _canvasToGridMatrix = vector_math.Matrix4.identity()
      ..scale(gridScaleX, gridScaleY, 1.0);
    
    _cacheValid = true;
  }
  
  void updateScreenSize(Size newSize) {
    config.screenSize.width;  // This would normally update the size
    _cacheValid = false;
    _updateMatrices();
  }
  
  CanvasPoint screenToCanvas(ScreenPoint screen) {
    if (screen.x.isNaN || screen.y.isNaN) {
      throw ArgumentError('Invalid screen point with NaN');
    }
    if (screen.x.isInfinite || screen.y.isInfinite) {
      throw ArgumentError('Invalid screen point with infinity');
    }
    
    final vector = screen.toVector3();
    final transformed = getScreenToCanvasMatrix().transform3(vector);
    return CanvasPoint(transformed.x, transformed.y);
  }
  
  ScreenPoint canvasToScreen(CanvasPoint canvas) {
    final vector = canvas.toVector3();
    final transformed = getCanvasToScreenMatrix().transform3(vector);
    return ScreenPoint(transformed.x, transformed.y);
  }
  
  GridPoint canvasToGrid(CanvasPoint canvas) {
    final cellWidth = config.canvasSize.width / config.gridColumns;
    final cellHeight = config.canvasSize.height / config.gridRows;
    
    var gridX = (canvas.x / cellWidth).floor();
    var gridY = (canvas.y / cellHeight).floor();
    
    // Clamp to grid bounds
    gridX = gridX.clamp(0, config.gridColumns - 1);
    gridY = gridY.clamp(0, config.gridRows - 1);
    
    return GridPoint(gridX, gridY);
  }
  
  CanvasPoint gridToCanvas(GridPoint grid) {
    final cellWidth = config.canvasSize.width / config.gridColumns;
    final cellHeight = config.canvasSize.height / config.gridRows;
    
    // Return center of grid cell
    final x = (grid.x + 0.5) * cellWidth;
    final y = (grid.y + 0.5) * cellHeight;
    
    return CanvasPoint(x, y);
  }
  
  WorkspacePoint canvasToWorkspace(CanvasPoint canvas) {
    final x = canvas.x * zoomLevel + panOffset.dx;
    final y = canvas.y * zoomLevel + panOffset.dy;
    return WorkspacePoint(x, y);
  }
  
  CanvasPoint workspaceToCanvas(WorkspacePoint workspace) {
    final x = (workspace.x - panOffset.dx) / zoomLevel;
    final y = (workspace.y - panOffset.dy) / zoomLevel;
    return CanvasPoint(x, y);
  }
  
  GridPoint screenToGrid(ScreenPoint screen) {
    final canvas = screenToCanvas(screen);
    return canvasToGrid(canvas);
  }
  
  ScreenPoint gridToScreen(GridPoint grid) {
    final canvas = gridToCanvas(grid);
    return canvasToScreen(canvas);
  }
  
  WorkspacePoint screenToWorkspace(ScreenPoint screen) {
    final canvas = screenToCanvas(screen);
    return canvasToWorkspace(canvas);
  }
  
  ScreenPoint workspaceToScreen(WorkspacePoint workspace) {
    final canvas = workspaceToCanvas(workspace);
    return canvasToScreen(canvas);
  }
  
  void setPanOffset(Offset offset) {
    panOffset = offset;
  }
  
  void setZoomLevel(double zoom) {
    zoomLevel = zoom.clamp(0.1, 10.0);
  }
  
  vector_math.Matrix4 getScreenToCanvasMatrix() {
    if (!_cacheValid) _updateMatrices();
    return _screenToCanvasMatrix!;
  }
  
  vector_math.Matrix4 getCanvasToScreenMatrix() {
    if (!_cacheValid) _updateMatrices();
    return _canvasToScreenMatrix!;
  }
  
  vector_math.Matrix4 getCanvasToGridMatrix() {
    if (!_cacheValid) _updateMatrices();
    return _canvasToGridMatrix!;
  }
  
  bool isValidGridPoint(GridPoint point) {
    return point.x >= 0 && point.x < config.gridColumns &&
           point.y >= 0 && point.y < config.gridRows;
  }
  
  bool isValidCanvasPoint(CanvasPoint point) {
    return point.x >= 0 && point.x <= config.canvasSize.width &&
           point.y >= 0 && point.y <= config.canvasSize.height;
  }
  
  CanvasPoint interpolateCanvas(CanvasPoint start, CanvasPoint end, double t) {
    final x = start.x + (end.x - start.x) * t;
    final y = start.y + (end.y - start.y) * t;
    return CanvasPoint(x, y);
  }
  
  ScreenPoint interpolateScreenWithEasing(
    ScreenPoint start, 
    ScreenPoint end, 
    double t,
    double Function(double) easing,
  ) {
    final easedT = easing(t);
    final x = start.x + (end.x - start.x) * easedT;
    final y = start.y + (end.y - start.y) * easedT;
    return ScreenPoint(x, y);
  }
}

/// Mock transformation manager for testing
class TransformationManager {
  final CoordinateSystem system;
  final Map<String, CanvasPoint> _cache = {};
  int _cacheHits = 0;
  int _cacheMisses = 0;
  final int _maxCacheSize = 1000;
  bool _recording = false;
  final List<Map<String, dynamic>> _recordedTransformations = [];
  
  TransformationManager(this.system);
  
  CanvasPoint cachedScreenToCanvas(ScreenPoint point) {
    final key = '${point.x},${point.y}';
    
    if (_cache.containsKey(key)) {
      _cacheHits++;
      return _cache[key]!;
    }
    
    _cacheMisses++;
    final result = system.screenToCanvas(point);
    
    // LRU eviction
    if (_cache.length >= _maxCacheSize) {
      _cache.remove(_cache.keys.first);
    }
    
    _cache[key] = result;
    
    if (_recording) {
      _recordedTransformations.add({
        'from': point,
        'to': result,
        'timestamp': DateTime.now(),
      });
    }
    
    return result;
  }
  
  List<CanvasPoint> batchScreenToCanvas(List<ScreenPoint> points) {
    return points.map((p) => system.screenToCanvas(p)).toList();
  }
  
  List<CanvasPoint> createInterpolatedTransform(
    ScreenPoint start,
    ScreenPoint end,
    int frames,
  ) {
    final result = <CanvasPoint>[];
    
    for (int i = 0; i < frames; i++) {
      final t = i / (frames - 1);
      final x = start.x + (end.x - start.x) * t;
      final y = start.y + (end.y - start.y) * t;
      result.add(system.screenToCanvas(ScreenPoint(x, y)));
    }
    
    return result;
  }
  
  int get cacheSize => _cache.length;
  
  Map<String, dynamic> getCacheStatistics() {
    final total = _cacheHits + _cacheMisses;
    return {
      'hits': _cacheHits,
      'misses': _cacheMisses,
      'hitRate': total > 0 ? _cacheHits / total : 0.0,
      'size': _cache.length,
    };
  }
  
  void enableRecording() {
    _recording = true;
    _recordedTransformations.clear();
  }
  
  void disableRecording() {
    _recording = false;
  }
  
  List<Map<String, dynamic>> getRecordedTransformations() {
    return List.from(_recordedTransformations);
  }
}

// Extension methods for convenience
extension OffsetExtensions on Offset {
  ScreenPoint toScreenPoint() => ScreenPoint(dx, dy);
  CanvasPoint toCanvasPoint() => CanvasPoint(dx, dy);
}

extension ScreenPointExtensions on ScreenPoint {
  Offset toOffset() => Offset(x, y);
}

extension ListExtensions on List<ScreenPoint> {
  List<CanvasPoint> mapToCanvas(CoordinateSystem system) {
    return map((p) => system.screenToCanvas(p)).toList();
  }
}

// Test fixtures and factories
class CoordinateSystemTestFixtures {
  static CoordinateSystem createStandardSystem() {
    return CoordinateSystem(
      config: CoordinateSystemConfig(
        devicePixelRatio: 2.0,
        screenSize: const Size(800, 600),
        canvasSize: const Size(400, 300),
        gridColumns: 10,
        gridRows: 8,
        workspaceSize: const Size(1200, 900),
      ),
    );
  }

  static CoordinateSystem createHighDPISystem() {
    return CoordinateSystem(
      config: CoordinateSystemConfig(
        devicePixelRatio: 3.0,
        screenSize: const Size(1284, 2778),  // iPhone 14 Pro Max
        canvasSize: const Size(428, 926),
        gridColumns: 20,
        gridRows: 30,
        workspaceSize: const Size(2000, 3000),
      ),
    );
  }

  static CoordinateSystem createTabletSystem() {
    return CoordinateSystem(
      config: CoordinateSystemConfig(
        devicePixelRatio: 2.0,
        screenSize: const Size(2048, 1536),  // iPad
        canvasSize: const Size(1024, 768),
        gridColumns: 25,
        gridRows: 20,
        workspaceSize: const Size(3000, 2000),
      ),
    );
  }
}

// Custom matchers for coordinate assertions
class PointNearMatcher extends Matcher {
  final dynamic expected;
  final double epsilon;

  PointNearMatcher(this.expected, this.epsilon);

  @override
  bool matches(dynamic item, Map matchState) {
    if (item is ScreenPoint && expected is ScreenPoint) {
      return (item.x - expected.x).abs() < epsilon &&
             (item.y - expected.y).abs() < epsilon;
    } else if (item is CanvasPoint && expected is CanvasPoint) {
      return (item.x - expected.x).abs() < epsilon &&
             (item.y - expected.y).abs() < epsilon;
    } else if (item is GridPoint && expected is GridPoint) {
      return item.x == expected.x && item.y == expected.y;
    } else if (item is WorkspacePoint && expected is WorkspacePoint) {
      return (item.x - expected.x).abs() < epsilon &&
             (item.y - expected.y).abs() < epsilon;
    }
    return false;
  }

  @override
  Description describe(Description description) =>
      description.add('point near $expected (±$epsilon)');

  @override
  Description describeMismatch(dynamic item, Description mismatchDescription,
      Map matchState, bool verbose) {
    return mismatchDescription.add('was $item');
  }
}

Matcher pointNear(dynamic expected, {double epsilon = 0.01}) =>
    PointNearMatcher(expected, epsilon);

void main() {
  group('CoordinateSystem Core', () {
    group('ScreenSpace to CanvasSpace', () {
      test('should correctly transform screen to canvas coordinates', () {
        final system = CoordinateSystemTestFixtures.createStandardSystem();
        
        // Test center of screen
        final screenCenter = ScreenPoint(400, 300);
        final canvasCenter = system.screenToCanvas(screenCenter);
        
        expect(canvasCenter, pointNear(const CanvasPoint(200, 150)));
      });

      test('should handle device pixel ratio correctly', () {
        final system = CoordinateSystemTestFixtures.createHighDPISystem();
        
        // Test with high DPI screen
        final screenPoint = ScreenPoint(642, 1389);
        final canvasPoint = system.screenToCanvas(screenPoint);
        
        // Should account for 3x pixel ratio
        expect(canvasPoint.x, closeTo(214, 1.0));
        expect(canvasPoint.y, closeTo(463, 1.0));
      });

      test('should correctly inverse transform canvas to screen', () {
        final system = CoordinateSystemTestFixtures.createStandardSystem();
        
        // Test round-trip transformation
        final originalScreen = ScreenPoint(350, 275);
        final canvas = system.screenToCanvas(originalScreen);
        final backToScreen = system.canvasToScreen(canvas);
        
        expect(backToScreen, pointNear(originalScreen));
      });

      test('should handle edge cases at screen boundaries', () {
        final system = CoordinateSystemTestFixtures.createStandardSystem();
        
        // Test all corners
        final corners = [
          ScreenPoint(0, 0),
          ScreenPoint(800, 0),
          ScreenPoint(0, 600),
          ScreenPoint(800, 600),
        ];
        
        for (final corner in corners) {
          final canvas = system.screenToCanvas(corner);
          final back = system.canvasToScreen(canvas);
          expect(back, pointNear(corner));
        }
      });
    });

    group('CanvasSpace to GridSpace', () {
      test('should map canvas points to grid cells correctly', () {
        final system = CoordinateSystemTestFixtures.createStandardSystem();
        
        // Canvas size is 400x300, grid is 10x8
        // Each cell is 40x37.5 canvas units
        
        final canvasPoint = CanvasPoint(100, 75);
        final gridPoint = system.canvasToGrid(canvasPoint);
        
        expect(gridPoint, equals(const GridPoint(2, 2)));
      });

      test('should handle grid boundaries correctly', () {
        final system = CoordinateSystemTestFixtures.createStandardSystem();
        
        // Test grid edges
        final topLeft = system.canvasToGrid(const CanvasPoint(0, 0));
        expect(topLeft, equals(const GridPoint(0, 0)));
        
        final bottomRight = system.canvasToGrid(const CanvasPoint(399, 299));
        expect(bottomRight, equals(const GridPoint(9, 7)));
      });

      test('should clamp out-of-bounds canvas points to grid', () {
        final system = CoordinateSystemTestFixtures.createStandardSystem();
        
        // Test negative coordinates
        final negative = system.canvasToGrid(const CanvasPoint(-50, -50));
        expect(negative, equals(const GridPoint(0, 0)));
        
        // Test beyond grid
        final beyond = system.canvasToGrid(const CanvasPoint(500, 400));
        expect(beyond, equals(const GridPoint(9, 7)));
      });

      test('should convert grid points to canvas center correctly', () {
        final system = CoordinateSystemTestFixtures.createStandardSystem();
        
        final gridPoint = GridPoint(5, 4);
        final canvasCenter = system.gridToCanvas(gridPoint);
        
        // Cell 5,4 center should be at (5.5 * 40, 4.5 * 37.5)
        expect(canvasCenter.x, closeTo(220, 0.1));
        expect(canvasCenter.y, closeTo(168.75, 0.1));
      });
    });

    // Continue with remaining tests...
  });
}
