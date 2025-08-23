import 'package:flutter/foundation.dart';
import 'puzzle_coordinate.dart';

/// Result of moving a puzzle piece in the workspace
@immutable
class MoveResult {
  final MoveResultType type;
  final PuzzleCoordinate? finalPosition;
  final double? proximityIntensity;
  final String? message;

  const MoveResult._({
    required this.type,
    this.finalPosition,
    this.proximityIntensity,
    this.message,
  });

  /// Piece was moved to a regular position
  factory MoveResult.moved({PuzzleCoordinate? position}) {
    return MoveResult._(
      type: MoveResultType.moved,
      finalPosition: position,
    );
  }

  /// Piece snapped to its correct position
  factory MoveResult.snapped(PuzzleCoordinate position) {
    return MoveResult._(
      type: MoveResultType.snapped,
      finalPosition: position,
      message: 'Piece placed correctly!',
    );
  }

  /// Piece is near its correct position
  factory MoveResult.near({
    required double intensity,
    PuzzleCoordinate? position,
  }) {
    assert(intensity >= 0.0 && intensity <= 1.0);
    return MoveResult._(
      type: MoveResultType.near,
      proximityIntensity: intensity,
      finalPosition: position,
    );
  }

  /// Move was blocked or invalid
  factory MoveResult.blocked({String? reason}) {
    return MoveResult._(
      type: MoveResultType.blocked,
      message: reason ?? 'Move blocked',
    );
  }

  bool get wasSuccessful => type != MoveResultType.blocked;
  bool get wasSnapped => type == MoveResultType.snapped;
  bool get isNearTarget => type == MoveResultType.near;

  @override
  String toString() {
    return 'MoveResult(type: $type, position: $finalPosition, intensity: $proximityIntensity)';
  }
}

/// Types of move results
enum MoveResultType {
  /// Piece was moved to a regular position
  moved,
  
  /// Piece snapped to its correct position
  snapped,
  
  /// Piece is near its correct position (triggers feedback)
  near,
  
  /// Move was blocked or invalid
  blocked,
}

/// Represents feedback intensity based on proximity
@immutable
class ProximityFeedback {
  final double distance;
  final double intensity;
  final FeedbackLevel level;

  const ProximityFeedback({
    required this.distance,
    required this.intensity,
    required this.level,
  });

  factory ProximityFeedback.fromDistance({
    required double distance,
    required double maxDistance,
  }) {
    if (distance <= 0) {
      return const ProximityFeedback(
        distance: 0,
        intensity: 1.0,
        level: FeedbackLevel.strong,
      );
    }

    if (distance >= maxDistance) {
      return ProximityFeedback(
        distance: distance,
        intensity: 0.0,
        level: FeedbackLevel.none,
      );
    }

    final intensity = 1.0 - (distance / maxDistance);
    final level = _calculateLevel(intensity);

    return ProximityFeedback(
      distance: distance,
      intensity: intensity,
      level: level,
    );
  }

  static FeedbackLevel _calculateLevel(double intensity) {
    if (intensity >= 0.8) return FeedbackLevel.strong;
    if (intensity >= 0.5) return FeedbackLevel.medium;
    if (intensity >= 0.2) return FeedbackLevel.light;
    return FeedbackLevel.none;
  }

  @override
  String toString() {
    return 'ProximityFeedback(distance: ${distance.toStringAsFixed(1)}, '
           'intensity: ${intensity.toStringAsFixed(2)}, level: $level)';
  }
}

/// Levels of feedback intensity
enum FeedbackLevel {
  none,
  light,
  medium,
  strong,
}
