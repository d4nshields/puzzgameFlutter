import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'puzzle_coordinate.dart';

/// Immutable value object representing the bounds of a puzzle piece.
/// 
/// Distinguishes between:
/// - Content bounds: The actual visible content including tabs/blanks
/// - Padded bounds: The full PNG dimensions with transparent padding
/// 
/// All measurements are in original asset pixel units.
@immutable
class PieceBounds {
  /// The bounds of the actual content (non-transparent pixels)
  final ContentRect contentBounds;
  
  /// The full dimensions of the padded PNG
  final Size paddedSize;
  
  /// The position where this piece should be placed when correct
  final ContentRect targetBounds;

  const PieceBounds({
    required this.contentBounds,
    required this.paddedSize,
    required this.targetBounds,
  });

  /// Check if content bounds overlap with another piece's bounds
  bool overlaps(PieceBounds other) {
    return contentBounds.overlaps(other.contentBounds);
  }

  /// Calculate the overlap area with another piece
  double overlapArea(PieceBounds other) {
    return contentBounds.overlapArea(other.contentBounds);
  }

  /// Convert to JSON for serialization
  Map<String, dynamic> toJson() {
    return {
      'contentBounds': contentBounds.toJson(),
      'paddedSize': {
        'width': paddedSize.width,
        'height': paddedSize.height,
      },
      'targetBounds': targetBounds.toJson(),
    };
  }

  /// Create from JSON for deserialization
  factory PieceBounds.fromJson(Map<String, dynamic> json) {
    return PieceBounds(
      contentBounds: ContentRect.fromJson(json['contentBounds']),
      paddedSize: Size(
        (json['paddedSize']['width'] as num).toDouble(),
        (json['paddedSize']['height'] as num).toDouble(),
      ),
      targetBounds: ContentRect.fromJson(json['targetBounds']),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PieceBounds &&
        other.contentBounds == contentBounds &&
        other.paddedSize == paddedSize &&
        other.targetBounds == targetBounds;
  }

  @override
  int get hashCode => Object.hash(contentBounds, paddedSize, targetBounds);

  @override
  String toString() {
    return 'PieceBounds(content: $contentBounds, padded: $paddedSize, target: $targetBounds)';
  }
}

/// Immutable rectangle representing content bounds
@immutable
class ContentRect {
  final double left;
  final double top;
  final double right;
  final double bottom;

  const ContentRect({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  }) : assert(right >= left),
       assert(bottom >= top);

  double get width => right - left;
  double get height => bottom - top;
  double get area => width * height;

  /// Get the center point of this rectangle
  PuzzleCoordinate get center {
    return PuzzleCoordinate(
      x: left + width / 2,
      y: top + height / 2,
    );
  }

  /// Check if this rectangle contains a point
  bool containsPoint(PuzzleCoordinate point) {
    return point.x >= left &&
           point.x <= right &&
           point.y >= top &&
           point.y <= bottom;
  }

  /// Check if this rectangle overlaps with another
  bool overlaps(ContentRect other) {
    return left < other.right &&
           right > other.left &&
           top < other.bottom &&
           bottom > other.top;
  }

  /// Calculate the intersection with another rectangle
  ContentRect? intersection(ContentRect other) {
    if (!overlaps(other)) return null;
    
    return ContentRect(
      left: left > other.left ? left : other.left,
      top: top > other.top ? top : other.top,
      right: right < other.right ? right : other.right,
      bottom: bottom < other.bottom ? bottom : other.bottom,
    );
  }

  /// Calculate the area of overlap with another rectangle
  double overlapArea(ContentRect other) {
    final intersect = intersection(other);
    return intersect?.area ?? 0.0;
  }

  /// Translate this rectangle by an offset
  ContentRect translate({double dx = 0, double dy = 0}) {
    return ContentRect(
      left: left + dx,
      top: top + dy,
      right: right + dx,
      bottom: bottom + dy,
    );
  }

  /// Scale this rectangle by a factor
  ContentRect scale(double factor) {
    return ContentRect(
      left: left * factor,
      top: top * factor,
      right: right * factor,
      bottom: bottom * factor,
    );
  }

  /// Convert to JSON for serialization
  Map<String, dynamic> toJson() {
    return {
      'left': left,
      'top': top,
      'right': right,
      'bottom': bottom,
    };
  }

  /// Create from JSON for deserialization
  factory ContentRect.fromJson(Map<String, dynamic> json) {
    return ContentRect(
      left: (json['left'] as num).toDouble(),
      top: (json['top'] as num).toDouble(),
      right: (json['right'] as num).toDouble(),
      bottom: (json['bottom'] as num).toDouble(),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ContentRect &&
        other.left == left &&
        other.top == top &&
        other.right == right &&
        other.bottom == bottom;
  }

  @override
  int get hashCode => Object.hash(left, top, right, bottom);

  @override
  String toString() {
    return 'ContentRect(l: $left, t: $top, r: $right, b: $bottom, w: $width, h: $height)';
  }
}


