import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';

/// Base class for coordinate validation
abstract class CoordinateValidator {
  static bool isFinite(double value) => value.isFinite;
  static bool isInRange(double value, double min, double max) =>
      value >= min && value <= max;
  static bool isValidGridIndex(int value, int max) =>
      value >= 0 && value < max;
}

/// Immutable representation of a point in screen space (device pixels).
/// Takes into account the device pixel ratio for accurate positioning.
@immutable
class ScreenPoint {
  final double x;
  final double y;
  final double devicePixelRatio;

  const ScreenPoint({
    required this.x,
    required this.y,
    this.devicePixelRatio = 1.0,
  })  : assert(devicePixelRatio > 0, 'Device pixel ratio must be positive');

  /// Creates a screen point from logical pixels
  factory ScreenPoint.fromLogical({
    required double x,
    required double y,
    required double devicePixelRatio,
  }) {
    return ScreenPoint(
      x: x * devicePixelRatio,
      y: y * devicePixelRatio,
      devicePixelRatio: devicePixelRatio,
    );
  }

  /// Creates a screen point at the origin
  const ScreenPoint.origin({double devicePixelRatio = 1.0})
      : x = 0,
        y = 0,
        devicePixelRatio = devicePixelRatio;

  /// Creates a screen point from an Offset
  factory ScreenPoint.fromOffset(
    ui.Offset offset, {
    double devicePixelRatio = 1.0,
  }) {
    return ScreenPoint(
      x: offset.dx,
      y: offset.dy,
      devicePixelRatio: devicePixelRatio,
    );
  }

  /// Converts to logical pixels
  double get logicalX => x / devicePixelRatio;
  double get logicalY => y / devicePixelRatio;

  /// Converts to an Offset
  ui.Offset toOffset() => ui.Offset(x, y);

  /// Converts to logical Offset
  ui.Offset toLogicalOffset() => ui.Offset(logicalX, logicalY);

  /// Distance to another screen point
  double distanceTo(ScreenPoint other) {
    final dx = x - other.x;
    final dy = y - other.y;
    return math.sqrt(dx * dx + dy * dy);
  }

  /// Midpoint between this and another screen point
  ScreenPoint midpointTo(ScreenPoint other) {
    return ScreenPoint(
      x: (x + other.x) / 2,
      y: (y + other.y) / 2,
      devicePixelRatio: devicePixelRatio,
    );
  }

  /// Translates the point by the given offset
  ScreenPoint translate(double dx, double dy) {
    return ScreenPoint(
      x: x + dx,
      y: y + dy,
      devicePixelRatio: devicePixelRatio,
    );
  }

  /// Scales the point by the given factor
  ScreenPoint scale(double factor) {
    return ScreenPoint(
      x: x * factor,
      y: y * factor,
      devicePixelRatio: devicePixelRatio,
    );
  }

  /// Checks if the point is within the given bounds
  bool isWithinBounds(ui.Rect bounds) {
    return x >= bounds.left &&
        x <= bounds.right &&
        y >= bounds.top &&
        y <= bounds.bottom;
  }

  /// Validates if the coordinates are finite
  bool get isValid => x.isFinite && y.isFinite;

  /// Creates a copy with optional parameter overrides
  ScreenPoint copyWith({
    double? x,
    double? y,
    double? devicePixelRatio,
  }) {
    return ScreenPoint(
      x: x ?? this.x,
      y: y ?? this.y,
      devicePixelRatio: devicePixelRatio ?? this.devicePixelRatio,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ScreenPoint &&
        other.x == x &&
        other.y == y &&
        other.devicePixelRatio == devicePixelRatio;
  }

  @override
  int get hashCode => Object.hash(x, y, devicePixelRatio);

  @override
  String toString() {
    return 'ScreenPoint(x: ${x.toStringAsFixed(2)}, '
        'y: ${y.toStringAsFixed(2)}, '
        'dpr: ${devicePixelRatio.toStringAsFixed(2)}, '
        'logical: (${logicalX.toStringAsFixed(2)}, ${logicalY.toStringAsFixed(2)}))';
  }
}

/// Immutable representation of a point in canvas space (logical pixels).
/// Includes optional bounds checking for validation.
@immutable
class CanvasPoint {
  final double x;
  final double y;
  final ui.Rect? bounds;

  const CanvasPoint({
    required this.x,
    required this.y,
    this.bounds,
  });

  /// Creates a canvas point at the origin
  const CanvasPoint.origin()
      : x = 0,
        y = 0,
        bounds = null;

  /// Creates a canvas point at the center of the given size
  factory CanvasPoint.center(ui.Size size) {
    return CanvasPoint(
      x: size.width / 2,
      y: size.height / 2,
    );
  }

  /// Creates a canvas point from an Offset
  factory CanvasPoint.fromOffset(ui.Offset offset, {ui.Rect? bounds}) {
    return CanvasPoint(
      x: offset.dx,
      y: offset.dy,
      bounds: bounds,
    );
  }

  /// Creates a canvas point from a Size (using width as x, height as y)
  factory CanvasPoint.fromSize(ui.Size size, {ui.Rect? bounds}) {
    return CanvasPoint(
      x: size.width,
      y: size.height,
      bounds: bounds,
    );
  }

  /// Creates a bounded canvas point, clamping to bounds if necessary
  factory CanvasPoint.bounded({
    required double x,
    required double y,
    required ui.Rect bounds,
  }) {
    return CanvasPoint(
      x: x.clamp(bounds.left, bounds.right),
      y: y.clamp(bounds.top, bounds.bottom),
      bounds: bounds,
    );
  }

  /// Converts to an Offset
  ui.Offset toOffset() => ui.Offset(x, y);

  /// Converts to a Size
  ui.Size toSize() => ui.Size(x, y);

  /// Checks if the point is within its bounds (if set)
  bool get isWithinBounds {
    if (bounds == null) return true;
    return x >= bounds!.left &&
        x <= bounds!.right &&
        y >= bounds!.top &&
        y <= bounds!.bottom;
  }

  /// Validates if the coordinates are finite
  bool get isValid => x.isFinite && y.isFinite;

  /// Distance to another canvas point
  double distanceTo(CanvasPoint other) {
    final dx = x - other.x;
    final dy = y - other.y;
    return math.sqrt(dx * dx + dy * dy);
  }

  /// Manhattan distance to another canvas point
  double manhattanDistanceTo(CanvasPoint other) {
    return (x - other.x).abs() + (y - other.y).abs();
  }

  /// Midpoint between this and another canvas point
  CanvasPoint midpointTo(CanvasPoint other) {
    return CanvasPoint(
      x: (x + other.x) / 2,
      y: (y + other.y) / 2,
      bounds: bounds,
    );
  }

  /// Translates the point by the given offset
  CanvasPoint translate(double dx, double dy) {
    return CanvasPoint(
      x: x + dx,
      y: y + dy,
      bounds: bounds,
    );
  }

  /// Scales the point by the given factor
  CanvasPoint scale(double factor) {
    return CanvasPoint(
      x: x * factor,
      y: y * factor,
      bounds: bounds,
    );
  }

  /// Rotates the point around a center by the given angle in radians
  CanvasPoint rotateAround(CanvasPoint center, double angleRadians) {
    final cos = math.cos(angleRadians);
    final sin = math.sin(angleRadians);
    final dx = x - center.x;
    final dy = y - center.y;
    
    return CanvasPoint(
      x: center.x + (dx * cos - dy * sin),
      y: center.y + (dx * sin + dy * cos),
      bounds: bounds,
    );
  }

  /// Clamps the point to its bounds (if set)
  CanvasPoint clampToBounds() {
    if (bounds == null) return this;
    return CanvasPoint(
      x: x.clamp(bounds!.left, bounds!.right),
      y: y.clamp(bounds!.top, bounds!.bottom),
      bounds: bounds,
    );
  }

  /// Linear interpolation to another point
  CanvasPoint lerp(CanvasPoint other, double t) {
    return CanvasPoint(
      x: x + (other.x - x) * t,
      y: y + (other.y - y) * t,
      bounds: bounds,
    );
  }

  /// Creates a copy with optional parameter overrides
  CanvasPoint copyWith({
    double? x,
    double? y,
    ui.Rect? bounds,
  }) {
    return CanvasPoint(
      x: x ?? this.x,
      y: y ?? this.y,
      bounds: bounds ?? this.bounds,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CanvasPoint &&
        other.x == x &&
        other.y == y &&
        other.bounds == bounds;
  }

  @override
  int get hashCode => Object.hash(x, y, bounds);

  @override
  String toString() {
    final boundsStr = bounds != null
        ? ', bounds: [${bounds!.left.toStringAsFixed(1)}, '
            '${bounds!.top.toStringAsFixed(1)}, '
            '${bounds!.right.toStringAsFixed(1)}, '
            '${bounds!.bottom.toStringAsFixed(1)}]'
        : '';
    return 'CanvasPoint(${x.toStringAsFixed(2)}, ${y.toStringAsFixed(2)}$boundsStr)';
  }
}

/// Immutable representation of a position in grid space.
/// Includes validation for grid boundaries.
@immutable
class GridPosition {
  final int x;
  final int y;
  final int? maxX;
  final int? maxY;

  const GridPosition({
    required this.x,
    required this.y,
    this.maxX,
    this.maxY,
  })  : assert(x >= 0, 'Grid x must be non-negative'),
        assert(y >= 0, 'Grid y must be non-negative'),
        assert(maxX == null || x < maxX, 'Grid x must be less than maxX'),
        assert(maxY == null || y < maxY, 'Grid y must be less than maxY');

  /// Creates a grid position at the origin
  const GridPosition.origin({int? maxX, int? maxY})
      : x = 0,
        y = 0,
        maxX = maxX,
        maxY = maxY;

  /// Creates a grid position at the center of the grid
  factory GridPosition.center({required int width, required int height}) {
    return GridPosition(
      x: width ~/ 2,
      y: height ~/ 2,
      maxX: width,
      maxY: height,
    );
  }

  /// Creates a grid position from a linear index
  factory GridPosition.fromIndex({
    required int index,
    required int width,
    int? height,
  }) {
    return GridPosition(
      x: index % width,
      y: index ~/ width,
      maxX: width,
      maxY: height,
    );
  }

  /// Converts to a linear index
  int toIndex(int width) => y * width + x;

  /// Checks if the position is within the specified bounds
  bool isWithinBounds({required int width, required int height}) {
    return x >= 0 && x < width && y >= 0 && y < height;
  }

  /// Checks if this position is valid within its max bounds
  bool get isValid {
    if (maxX != null && x >= maxX!) return false;
    if (maxY != null && y >= maxY!) return false;
    return x >= 0 && y >= 0;
  }

  /// Manhattan distance to another grid position
  int manhattanDistanceTo(GridPosition other) {
    return (x - other.x).abs() + (y - other.y).abs();
  }

  /// Chebyshev distance (chess king moves) to another grid position
  int chebyshevDistanceTo(GridPosition other) {
    return math.max((x - other.x).abs(), (y - other.y).abs());
  }

  /// Gets all adjacent positions (4-connected)
  List<GridPosition> get adjacent {
    return [
      GridPosition(x: x, y: y - 1, maxX: maxX, maxY: maxY), // up
      GridPosition(x: x + 1, y: y, maxX: maxX, maxY: maxY), // right
      GridPosition(x: x, y: y + 1, maxX: maxX, maxY: maxY), // down
      GridPosition(x: x - 1, y: y, maxX: maxX, maxY: maxY), // left
    ].where((pos) => pos.isValid).toList();
  }

  /// Gets all adjacent positions including diagonals (8-connected)
  List<GridPosition> get adjacentWithDiagonals {
    final positions = <GridPosition>[];
    for (int dx = -1; dx <= 1; dx++) {
      for (int dy = -1; dy <= 1; dy++) {
        if (dx == 0 && dy == 0) continue;
        final newX = x + dx;
        final newY = y + dy;
        if (newX >= 0 && newY >= 0) {
          if (maxX == null || newX < maxX!) {
            if (maxY == null || newY < maxY!) {
              positions.add(GridPosition(
                x: newX,
                y: newY,
                maxX: maxX,
                maxY: maxY,
              ));
            }
          }
        }
      }
    }
    return positions;
  }

  /// Translates the position by the given offset
  GridPosition? translate(int dx, int dy) {
    final newX = x + dx;
    final newY = y + dy;
    
    if (newX < 0 || newY < 0) return null;
    if (maxX != null && newX >= maxX!) return null;
    if (maxY != null && newY >= maxY!) return null;
    
    return GridPosition(
      x: newX,
      y: newY,
      maxX: maxX,
      maxY: maxY,
    );
  }

  /// Creates a copy with optional parameter overrides
  GridPosition copyWith({
    int? x,
    int? y,
    int? maxX,
    int? maxY,
  }) {
    return GridPosition(
      x: x ?? this.x,
      y: y ?? this.y,
      maxX: maxX ?? this.maxX,
      maxY: maxY ?? this.maxY,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GridPosition &&
        other.x == x &&
        other.y == y &&
        other.maxX == maxX &&
        other.maxY == maxY;
  }

  @override
  int get hashCode => Object.hash(x, y, maxX, maxY);

  @override
  String toString() {
    final boundsStr = (maxX != null || maxY != null)
        ? ' (max: ${maxX ?? '∞'}, ${maxY ?? '∞'})'
        : '';
    return 'GridPosition($x, $y)$boundsStr';
  }
}

/// Immutable representation of a region in workspace.
/// Supports intersection detection and area calculations.
@immutable
class WorkspaceRegion {
  final ui.Rect bounds;
  final String? id;
  final Map<String, dynamic> metadata;

  const WorkspaceRegion({
    required this.bounds,
    this.id,
    this.metadata = const {},
  });

  /// Creates a workspace region from center and size
  factory WorkspaceRegion.fromCenter({
    required ui.Offset center,
    required ui.Size size,
    String? id,
    Map<String, dynamic> metadata = const {},
  }) {
    return WorkspaceRegion(
      bounds: ui.Rect.fromCenter(
        center: center,
        width: size.width,
        height: size.height,
      ),
      id: id,
      metadata: metadata,
    );
  }

  /// Creates a workspace region from two points
  factory WorkspaceRegion.fromPoints({
    required ui.Offset topLeft,
    required ui.Offset bottomRight,
    String? id,
    Map<String, dynamic> metadata = const {},
  }) {
    return WorkspaceRegion(
      bounds: ui.Rect.fromPoints(topLeft, bottomRight),
      id: id,
      metadata: metadata,
    );
  }

  /// Creates an empty workspace region
  static const WorkspaceRegion empty = WorkspaceRegion(
    bounds: ui.Rect.zero,
  );

  /// Creates an infinite workspace region
  static const WorkspaceRegion infinite = WorkspaceRegion(
    bounds: ui.Rect.fromLTRB(
      double.negativeInfinity,
      double.negativeInfinity,
      double.infinity,
      double.infinity,
    ),
  );

  /// Gets the center of the region
  ui.Offset get center => bounds.center;

  /// Gets the size of the region
  ui.Size get size => bounds.size;

  /// Gets the area of the region
  double get area => bounds.width * bounds.height;

  /// Gets the perimeter of the region
  double get perimeter => 2 * (bounds.width + bounds.height);

  /// Gets the aspect ratio of the region
  double get aspectRatio => bounds.width / bounds.height;

  /// Checks if the region is empty
  bool get isEmpty => bounds.isEmpty;

  /// Checks if the region is infinite
  bool get isInfinite => bounds.isInfinite;

  /// Checks if the region is finite
  bool get isFinite => bounds.isFinite;

  /// Checks if a point is contained within the region
  bool containsPoint(ui.Offset point) => bounds.contains(point);

  /// Checks if a canvas point is contained within the region
  bool containsCanvasPoint(CanvasPoint point) =>
      bounds.contains(point.toOffset());

  /// Checks if another region is completely contained within this region
  bool containsRegion(WorkspaceRegion other) {
    return bounds.contains(other.bounds.topLeft) &&
        bounds.contains(other.bounds.bottomRight);
  }

  /// Checks if this region intersects with another
  bool intersects(WorkspaceRegion other) => bounds.overlaps(other.bounds);

  /// Gets the intersection of this region with another
  WorkspaceRegion? intersection(WorkspaceRegion other) {
    final intersected = bounds.intersect(other.bounds);
    if (intersected.isEmpty) return null;
    return WorkspaceRegion(
      bounds: intersected,
      id: id,
      metadata: metadata,
    );
  }

  /// Gets the union of this region with another
  WorkspaceRegion union(WorkspaceRegion other) {
    return WorkspaceRegion(
      bounds: bounds.expandToInclude(other.bounds),
      id: id,
      metadata: metadata,
    );
  }

  /// Expands the region by the given amount
  WorkspaceRegion expand(double amount) {
    return WorkspaceRegion(
      bounds: bounds.inflate(amount),
      id: id,
      metadata: metadata,
    );
  }

  /// Contracts the region by the given amount
  WorkspaceRegion contract(double amount) {
    return expand(-amount);
  }

  /// Translates the region by the given offset
  WorkspaceRegion translate(ui.Offset offset) {
    return WorkspaceRegion(
      bounds: bounds.translate(offset.dx, offset.dy),
      id: id,
      metadata: metadata,
    );
  }

  /// Scales the region by the given factor
  WorkspaceRegion scale(double factor) {
    return WorkspaceRegion(
      bounds: ui.Rect.fromCenter(
        center: center,
        width: bounds.width * factor,
        height: bounds.height * factor,
      ),
      id: id,
      metadata: metadata,
    );
  }

  /// Calculates the overlap area with another region
  double overlapArea(WorkspaceRegion other) {
    final intersected = bounds.intersect(other.bounds);
    return intersected.isEmpty ? 0.0 : intersected.width * intersected.height;
  }

  /// Calculates the overlap percentage with another region
  double overlapPercentage(WorkspaceRegion other) {
    if (area == 0) return 0;
    return overlapArea(other) / area;
  }

  /// Splits the region into a grid of sub-regions
  List<WorkspaceRegion> split({required int rows, required int columns}) {
    final regions = <WorkspaceRegion>[];
    final cellWidth = bounds.width / columns;
    final cellHeight = bounds.height / rows;
    
    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < columns; col++) {
        regions.add(WorkspaceRegion(
          bounds: ui.Rect.fromLTWH(
            bounds.left + col * cellWidth,
            bounds.top + row * cellHeight,
            cellWidth,
            cellHeight,
          ),
          id: id != null ? '${id}_${row}_$col' : null,
          metadata: metadata,
        ));
      }
    }
    
    return regions;
  }

  /// Creates a copy with optional parameter overrides
  WorkspaceRegion copyWith({
    ui.Rect? bounds,
    String? id,
    Map<String, dynamic>? metadata,
  }) {
    return WorkspaceRegion(
      bounds: bounds ?? this.bounds,
      id: id ?? this.id,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WorkspaceRegion &&
        other.bounds == bounds &&
        other.id == id &&
        mapEquals(other.metadata, metadata);
  }

  @override
  int get hashCode => Object.hash(bounds, id, Object.hashAllUnordered(metadata.entries));

  @override
  String toString() {
    final idStr = id != null ? ', id: $id' : '';
    final metaStr = metadata.isNotEmpty ? ', metadata: $metadata' : '';
    return 'WorkspaceRegion('
        'bounds: [${bounds.left.toStringAsFixed(1)}, '
        '${bounds.top.toStringAsFixed(1)}, '
        '${bounds.right.toStringAsFixed(1)}, '
        '${bounds.bottom.toStringAsFixed(1)}], '
        'size: ${size.width.toStringAsFixed(1)}×${size.height.toStringAsFixed(1)}'
        '$idStr$metaStr)';
  }
}

/// Extension methods for ScreenPoint
extension ScreenPointExtensions on ScreenPoint {
  /// Adds two screen points
  ScreenPoint operator +(ScreenPoint other) {
    return ScreenPoint(
      x: x + other.x,
      y: y + other.y,
      devicePixelRatio: devicePixelRatio,
    );
  }

  /// Subtracts two screen points
  ScreenPoint operator -(ScreenPoint other) {
    return ScreenPoint(
      x: x - other.x,
      y: y - other.y,
      devicePixelRatio: devicePixelRatio,
    );
  }

  /// Multiplies by a scalar
  ScreenPoint operator *(double scalar) {
    return ScreenPoint(
      x: x * scalar,
      y: y * scalar,
      devicePixelRatio: devicePixelRatio,
    );
  }

  /// Divides by a scalar
  ScreenPoint operator /(double scalar) {
    return ScreenPoint(
      x: x / scalar,
      y: y / scalar,
      devicePixelRatio: devicePixelRatio,
    );
  }

  /// Negates the point
  ScreenPoint operator -() {
    return ScreenPoint(
      x: -x,
      y: -y,
      devicePixelRatio: devicePixelRatio,
    );
  }
}

/// Extension methods for CanvasPoint
extension CanvasPointExtensions on CanvasPoint {
  /// Adds two canvas points
  CanvasPoint operator +(CanvasPoint other) {
    return CanvasPoint(
      x: x + other.x,
      y: y + other.y,
      bounds: bounds,
    );
  }

  /// Subtracts two canvas points
  CanvasPoint operator -(CanvasPoint other) {
    return CanvasPoint(
      x: x - other.x,
      y: y - other.y,
      bounds: bounds,
    );
  }

  /// Multiplies by a scalar
  CanvasPoint operator *(double scalar) {
    return CanvasPoint(
      x: x * scalar,
      y: y * scalar,
      bounds: bounds,
    );
  }

  /// Divides by a scalar
  CanvasPoint operator /(double scalar) {
    return CanvasPoint(
      x: x / scalar,
      y: y / scalar,
      bounds: bounds,
    );
  }

  /// Negates the point
  CanvasPoint operator -() {
    return CanvasPoint(
      x: -x,
      y: -y,
      bounds: bounds,
    );
  }

  /// Dot product with another canvas point
  double dot(CanvasPoint other) {
    return x * other.x + y * other.y;
  }

  /// Cross product magnitude with another canvas point (2D)
  double cross(CanvasPoint other) {
    return x * other.y - y * other.x;
  }

  /// Gets the magnitude (length) of the vector
  double get magnitude => math.sqrt(x * x + y * y);

  /// Gets the squared magnitude (avoids sqrt calculation)
  double get magnitudeSquared => x * x + y * y;

  /// Normalizes the vector to unit length
  CanvasPoint normalize() {
    final mag = magnitude;
    if (mag == 0) return this;
    return this / mag;
  }

  /// Gets the angle of the vector in radians
  double get angle => math.atan2(y, x);

  /// Reflects the point across a line defined by a normal
  CanvasPoint reflect(CanvasPoint normal) {
    final n = normal.normalize();
    final d = dot(n);
    return this - (n * (2 * d));
  }
}

/// Extension methods for GridPosition
extension GridPositionExtensions on GridPosition {
  /// Adds two grid positions
  GridPosition? operator +(GridPosition other) {
    return translate(other.x, other.y);
  }

  /// Subtracts two grid positions
  GridPosition? operator -(GridPosition other) {
    return translate(-other.x, -other.y);
  }

  /// Checks if this position is adjacent to another (4-connected)
  bool isAdjacentTo(GridPosition other) {
    final dx = (x - other.x).abs();
    final dy = (y - other.y).abs();
    return (dx == 1 && dy == 0) || (dx == 0 && dy == 1);
  }

  /// Checks if this position is diagonal to another
  bool isDiagonalTo(GridPosition other) {
    final dx = (x - other.x).abs();
    final dy = (y - other.y).abs();
    return dx == 1 && dy == 1;
  }

  /// Gets the direction to another grid position
  GridDirection? directionTo(GridPosition other) {
    final dx = other.x - x;
    final dy = other.y - y;
    
    if (dx == 0 && dy == -1) return GridDirection.up;
    if (dx == 1 && dy == 0) return GridDirection.right;
    if (dx == 0 && dy == 1) return GridDirection.down;
    if (dx == -1 && dy == 0) return GridDirection.left;
    if (dx == 1 && dy == -1) return GridDirection.upRight;
    if (dx == 1 && dy == 1) return GridDirection.downRight;
    if (dx == -1 && dy == 1) return GridDirection.downLeft;
    if (dx == -1 && dy == -1) return GridDirection.upLeft;
    
    return null;
  }

  /// Moves in the specified direction
  GridPosition? move(GridDirection direction) {
    switch (direction) {
      case GridDirection.up:
        return translate(0, -1);
      case GridDirection.upRight:
        return translate(1, -1);
      case GridDirection.right:
        return translate(1, 0);
      case GridDirection.downRight:
        return translate(1, 1);
      case GridDirection.down:
        return translate(0, 1);
      case GridDirection.downLeft:
        return translate(-1, 1);
      case GridDirection.left:
        return translate(-1, 0);
      case GridDirection.upLeft:
        return translate(-1, -1);
    }
  }
}

/// Direction enumeration for grid movement
enum GridDirection {
  up,
  upRight,
  right,
  downRight,
  down,
  downLeft,
  left,
  upLeft,
}

/// Extension methods for WorkspaceRegion lists
extension WorkspaceRegionListExtensions on List<WorkspaceRegion> {
  /// Finds all regions that contain the given point
  List<WorkspaceRegion> containingPoint(ui.Offset point) {
    return where((region) => region.containsPoint(point)).toList();
  }

  /// Finds all regions that intersect with the given region
  List<WorkspaceRegion> intersecting(WorkspaceRegion region) {
    return where((r) => r.intersects(region)).toList();
  }

  /// Calculates the bounding box of all regions
  WorkspaceRegion? get boundingBox {
    if (isEmpty) return null;
    
    var left = double.infinity;
    var top = double.infinity;
    var right = double.negativeInfinity;
    var bottom = double.negativeInfinity;
    
    for (final region in this) {
      if (region.bounds.isFinite) {
        left = math.min(left, region.bounds.left);
        top = math.min(top, region.bounds.top);
        right = math.max(right, region.bounds.right);
        bottom = math.max(bottom, region.bounds.bottom);
      }
    }
    
    if (left.isInfinite || top.isInfinite || 
        right.isInfinite || bottom.isInfinite) {
      return null;
    }
    
    return WorkspaceRegion(
      bounds: ui.Rect.fromLTRB(left, top, right, bottom),
    );
  }

  /// Calculates the total area of all regions (counting overlaps)
  double get totalArea {
    return fold(0.0, (sum, region) => sum + region.area);
  }

  /// Merges overlapping regions
  List<WorkspaceRegion> mergeOverlapping() {
    if (isEmpty) return [];
    
    final merged = <WorkspaceRegion>[];
    final processed = <bool>[for (var _ in this) false];
    
    for (int i = 0; i < length; i++) {
      if (processed[i]) continue;
      
      var current = this[i];
      processed[i] = true;
      
      bool foundOverlap;
      do {
        foundOverlap = false;
        for (int j = i + 1; j < length; j++) {
          if (processed[j]) continue;
          
          if (current.intersects(this[j])) {
            current = current.union(this[j]);
            processed[j] = true;
            foundOverlap = true;
          }
        }
      } while (foundOverlap);
      
      merged.add(current);
    }
    
    return merged;
  }
}
