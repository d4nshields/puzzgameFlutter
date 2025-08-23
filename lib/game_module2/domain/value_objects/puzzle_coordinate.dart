import 'dart:math';

/// Immutable value object representing a position in puzzle coordinate space.
/// All coordinates are in original asset pixel units (e.g., 2048x2048).
/// 
/// This is the fundamental coordinate system used throughout the domain layer.
/// View layers are responsible for transforming these coordinates to screen space.
class PuzzleCoordinate {
  final double x;
  final double y;

  const PuzzleCoordinate({
    required this.x,
    required this.y,
  });

  /// Creates a coordinate from grid position and piece size
  factory PuzzleCoordinate.fromGrid({
    required int row,
    required int col,
    required double pieceSize,
  }) {
    return PuzzleCoordinate(
      x: col * pieceSize,
      y: row * pieceSize,
    );
  }

  /// Creates a coordinate at the origin
  static const PuzzleCoordinate zero = PuzzleCoordinate(x: 0, y: 0);

  /// Calculate the Euclidean distance to another coordinate
  double distanceTo(PuzzleCoordinate other) {
    final dx = x - other.x;
    final dy = y - other.y;
    return sqrt(dx * dx + dy * dy);
  }

  /// Calculate the Manhattan distance to another coordinate
  double manhattanDistanceTo(PuzzleCoordinate other) {
    return (x - other.x).abs() + (y - other.y).abs();
  }

  /// Check if this coordinate is within a threshold distance of another
  bool isNear(PuzzleCoordinate other, {required double threshold}) {
    return distanceTo(other) <= threshold;
  }

  /// Add an offset to this coordinate
  PuzzleCoordinate translate({double dx = 0, double dy = 0}) {
    return PuzzleCoordinate(x: x + dx, y: y + dy);
  }

  /// Scale this coordinate by a factor
  PuzzleCoordinate scale(double factor) {
    return PuzzleCoordinate(x: x * factor, y: y * factor);
  }

  /// Interpolate between this coordinate and another
  PuzzleCoordinate lerp(PuzzleCoordinate other, double t) {
    return PuzzleCoordinate(
      x: x + (other.x - x) * t,
      y: y + (other.y - y) * t,
    );
  }

  /// Clamp this coordinate within bounds
  PuzzleCoordinate clamp({
    required double minX,
    required double maxX,
    required double minY,
    required double maxY,
  }) {
    return PuzzleCoordinate(
      x: x.clamp(minX, maxX),
      y: y.clamp(minY, maxY),
    );
  }

  /// Convert to a map for serialization
  Map<String, dynamic> toJson() {
    return {
      'x': x,
      'y': y,
    };
  }

  /// Create from a map for deserialization
  factory PuzzleCoordinate.fromJson(Map<String, dynamic> json) {
    return PuzzleCoordinate(
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PuzzleCoordinate && other.x == x && other.y == y;
  }

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'PuzzleCoordinate(x: $x, y: $y)';
}
