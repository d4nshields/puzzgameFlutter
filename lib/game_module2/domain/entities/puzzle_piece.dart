import '../value_objects/puzzle_coordinate.dart';
import '../value_objects/piece_bounds.dart';

/// Core domain entity representing a puzzle piece.
/// 
/// This entity is independent of rendering or UI concerns and represents
/// the pure business logic of a puzzle piece.
class PuzzlePiece {
  /// Unique identifier for this piece
  final String id;
  
  /// Grid position (row, column) where this piece belongs
  final int correctRow;
  final int correctCol;
  
  /// The exact position where this piece should be placed (in pixel coordinates)
  final PuzzleCoordinate correctPosition;
  
  /// The bounds of this piece (content and padding)
  final PieceBounds bounds;
  
  /// Current position of the piece in the workspace (null if in tray)
  PuzzleCoordinate? _currentPosition;
  
  /// Whether this piece has been placed in its correct position
  bool _isPlaced = false;
  
  /// Whether this piece is currently selected
  bool _isSelected = false;
  
  /// Timestamp when the piece was picked up (for scoring)
  DateTime? _pickupTime;
  
  /// Timestamp when the piece was correctly placed
  DateTime? _placementTime;

  PuzzlePiece({
    required this.id,
    required this.correctRow,
    required this.correctCol,
    required this.correctPosition,
    required this.bounds,
    PuzzleCoordinate? initialPosition,
  }) : _currentPosition = initialPosition;

  // Getters
  PuzzleCoordinate? get currentPosition => _currentPosition;
  bool get isPlaced => _isPlaced;
  bool get isSelected => _isSelected;
  bool get isInTray => _currentPosition == null;
  DateTime? get pickupTime => _pickupTime;
  DateTime? get placementTime => _placementTime;

  /// Duration the piece was being manipulated (for scoring)
  Duration? get manipulationDuration {
    if (_pickupTime == null) return null;
    final endTime = _placementTime ?? DateTime.now();
    return endTime.difference(_pickupTime!);
  }

  /// Check if the piece is near its correct position
  bool isNearCorrectPosition({required double threshold}) {
    if (_currentPosition == null) return false;
    return _currentPosition!.distanceTo(correctPosition) <= threshold;
  }

  /// Check if the piece can snap to its correct position
  bool canSnapToPosition({required double snapDistance}) {
    return isNearCorrectPosition(threshold: snapDistance);
  }

  /// Calculate the distance from current position to correct position
  double? get distanceToCorrect {
    if (_currentPosition == null) return null;
    return _currentPosition!.distanceTo(correctPosition);
  }

  /// Move the piece to a new position
  void moveTo(PuzzleCoordinate position) {
    if (_isPlaced) {
      throw StateError('Cannot move a placed piece');
    }
    _currentPosition = position;
    
    // Track pickup time for scoring
    if (_pickupTime == null && !isInTray) {
      _pickupTime = DateTime.now();
    }
  }

  /// Return the piece to the tray
  void returnToTray() {
    _currentPosition = null;
    _isPlaced = false;
    _isSelected = false;
    _pickupTime = null;
    _placementTime = null;
  }

  /// Place the piece at its correct position
  void placeCorrectly() {
    _currentPosition = correctPosition;
    _isPlaced = true;
    _isSelected = false;
    _placementTime = DateTime.now();
  }

  /// Snap the piece to a specific position (usually its correct position)
  void snapTo(PuzzleCoordinate position) {
    _currentPosition = position;
    if (position == correctPosition) {
      placeCorrectly();
    }
  }

  /// Select or deselect the piece
  void setSelected(bool selected) {
    _isSelected = selected;
  }

  /// Check if this piece overlaps with another at their current positions
  bool overlapsWithAtCurrentPosition(PuzzlePiece other) {
    if (_currentPosition == null || other._currentPosition == null) {
      return false;
    }
    
    // Calculate the bounds at current positions
    final myBounds = bounds.contentBounds.translate(
      dx: _currentPosition!.x,
      dy: _currentPosition!.y,
    );
    
    final otherBounds = other.bounds.contentBounds.translate(
      dx: other._currentPosition!.x,
      dy: other._currentPosition!.y,
    );
    
    return myBounds.overlaps(otherBounds);
  }

  /// Create a copy of this piece with optional modifications
  PuzzlePiece copyWith({
    PuzzleCoordinate? currentPosition,
    bool? isPlaced,
    bool? isSelected,
  }) {
    final copy = PuzzlePiece(
      id: id,
      correctRow: correctRow,
      correctCol: correctCol,
      correctPosition: correctPosition,
      bounds: bounds,
      initialPosition: currentPosition ?? _currentPosition,
    );
    
    copy._isPlaced = isPlaced ?? _isPlaced;
    copy._isSelected = isSelected ?? _isSelected;
    copy._pickupTime = _pickupTime;
    copy._placementTime = _placementTime;
    
    return copy;
  }

  /// Convert to JSON for serialization
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'correctRow': correctRow,
      'correctCol': correctCol,
      'correctPosition': correctPosition.toJson(),
      'bounds': bounds.toJson(),
      'currentPosition': _currentPosition?.toJson(),
      'isPlaced': _isPlaced,
      'isSelected': _isSelected,
      'pickupTime': _pickupTime?.toIso8601String(),
      'placementTime': _placementTime?.toIso8601String(),
    };
  }

  /// Create from JSON for deserialization
  factory PuzzlePiece.fromJson(Map<String, dynamic> json) {
    final piece = PuzzlePiece(
      id: json['id'],
      correctRow: json['correctRow'],
      correctCol: json['correctCol'],
      correctPosition: PuzzleCoordinate.fromJson(json['correctPosition']),
      bounds: PieceBounds.fromJson(json['bounds']),
      initialPosition: json['currentPosition'] != null
          ? PuzzleCoordinate.fromJson(json['currentPosition'])
          : null,
    );
    
    piece._isPlaced = json['isPlaced'] ?? false;
    piece._isSelected = json['isSelected'] ?? false;
    piece._pickupTime = json['pickupTime'] != null
        ? DateTime.parse(json['pickupTime'])
        : null;
    piece._placementTime = json['placementTime'] != null
        ? DateTime.parse(json['placementTime'])
        : null;
    
    return piece;
  }

  @override
  String toString() {
    return 'PuzzlePiece(id: $id, grid: [$correctRow,$correctCol], '
           'placed: $_isPlaced, position: $_currentPosition)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PuzzlePiece && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
