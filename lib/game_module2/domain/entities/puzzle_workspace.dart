import 'dart:math' as math;
import 'dart:ui';
import 'puzzle_piece.dart';
import '../value_objects/puzzle_coordinate.dart';
import '../value_objects/move_result.dart';

/// Aggregate root managing the puzzle workspace state.
/// 
/// This is the single source of truth for puzzle state and enforces
/// all business rules related to piece placement and interaction.
class PuzzleWorkspace {
  /// Unique identifier for this workspace/session
  final String id;
  
  /// The puzzle being solved
  final String puzzleId;
  
  /// Grid dimensions (e.g., "8x8", "12x12", "15x15")
  final String gridSize;
  
  /// Canvas size in pixel units (e.g., 2048x2048)
  final Size canvasSize;
  
  /// All pieces in this puzzle
  final List<PuzzlePiece> _pieces;
  
  /// Configuration for piece placement
  final PlacementConfig config;
  
  /// Timestamp when the workspace was created
  final DateTime createdAt;
  
  /// Timestamp when the puzzle was completed (if applicable)
  DateTime? completedAt;
  
  /// Number of moves made
  int _moveCount = 0;
  
  /// Number of hints used
  int _hintsUsed = 0;

  PuzzleWorkspace({
    required this.id,
    required this.puzzleId,
    required this.gridSize,
    required this.canvasSize,
    required List<PuzzlePiece> pieces,
    PlacementConfig? config,
    DateTime? createdAt,
  })  : _pieces = pieces,
        config = config ?? const PlacementConfig(),
        createdAt = createdAt ?? DateTime.now();

  // Getters
  List<PuzzlePiece> get pieces => List.unmodifiable(_pieces);
  List<PuzzlePiece> get trayPieces => _pieces.where((p) => p.isInTray).toList();
  List<PuzzlePiece> get workspacePieces => _pieces.where((p) => !p.isInTray && !p.isPlaced).toList();
  List<PuzzlePiece> get placedPieces => _pieces.where((p) => p.isPlaced).toList();
  
  int get totalPieces => _pieces.length;
  int get placedCount => placedPieces.length;
  int get remainingCount => totalPieces - placedCount;
  double get completionPercentage => (placedCount / totalPieces) * 100;
  bool get isCompleted => placedCount == totalPieces;
  int get moveCount => _moveCount;
  int get hintsUsed => _hintsUsed;
  
  /// Calculate the duration of the puzzle session
  Duration get sessionDuration {
    final endTime = completedAt ?? DateTime.now();
    return endTime.difference(createdAt);
  }

  /// Move a piece to a new position in workspace coordinates
  MoveResult movePiece(String pieceId, PuzzleCoordinate newPosition) {
    final piece = _findPiece(pieceId);
    if (piece == null) {
      return MoveResult.blocked(reason: 'Piece not found');
    }
    
    if (piece.isPlaced) {
      return MoveResult.blocked(reason: 'Piece is already placed');
    }
    
    // Check for collisions with other pieces (optional)
    if (config.preventOverlap) {
      final collision = _checkCollisionAt(piece, newPosition);
      if (collision != null) {
        return MoveResult.blocked(
          reason: 'Position blocked by piece ${collision.id}',
        );
      }
    }
    
    // Move the piece
    piece.moveTo(newPosition);
    _moveCount++;
    
    // Check if piece can snap to correct position
    if (piece.canSnapToPosition(snapDistance: config.snapDistance)) {
      piece.placeCorrectly();
      
      // Check for puzzle completion
      if (isCompleted) {
        completedAt = DateTime.now();
      }
      
      return MoveResult.snapped(piece.correctPosition);
    }
    
    // Check if near correct position for feedback
    final distance = piece.distanceToCorrect ?? double.infinity;
    if (distance <= config.feedbackDistance) {
      final intensity = 1.0 - (distance / config.feedbackDistance);
      return MoveResult.near(
        intensity: intensity,
        position: newPosition,
      );
    }
    
    return MoveResult.moved(position: newPosition);
  }

  /// Pick up a piece from the tray
  PuzzlePiece? pickUpPiece(String pieceId) {
    final piece = _findPiece(pieceId);
    if (piece == null || !piece.isInTray) {
      return null;
    }
    
    // Move piece to workspace at a default position
    // The UI will immediately update this position based on cursor
    piece.moveTo(PuzzleCoordinate(
      x: canvasSize.width / 2,
      y: canvasSize.height / 2,
    ));
    
    return piece;
  }

  /// Return a piece to the tray
  bool returnPieceToTray(String pieceId) {
    final piece = _findPiece(pieceId);
    if (piece == null || piece.isPlaced) {
      return false;
    }
    
    piece.returnToTray();
    return true;
  }

  /// Remove a placed piece back to workspace
  bool removePlacedPiece(String pieceId) {
    final piece = _findPiece(pieceId);
    if (piece == null || !piece.isPlaced) {
      return false;
    }
    
    // Move piece slightly away from its correct position
    final offset = PuzzleCoordinate(
      x: piece.correctPosition.x + config.snapDistance * 1.5,
      y: piece.correctPosition.y + config.snapDistance * 1.5,
    );
    
    piece.moveTo(offset);
    return true;
  }

  /// Select a piece
  void selectPiece(String pieceId) {
    // Deselect all other pieces
    for (final piece in _pieces) {
      piece.setSelected(piece.id == pieceId);
    }
  }

  /// Deselect all pieces
  void deselectAll() {
    for (final piece in _pieces) {
      piece.setSelected(false);
    }
  }

  /// Get a hint for the next piece to place
  PuzzlePiece? getHint() {
    // Find an unplaced piece, preferring edge pieces
    final unplacedPieces = _pieces.where((p) => !p.isPlaced).toList();
    if (unplacedPieces.isEmpty) return null;
    
    // Sort by distance from correct position (pieces already in workspace)
    // or prioritize edge pieces if in tray
    unplacedPieces.sort((a, b) {
      // Edge pieces have priority
      final aIsEdge = _isEdgePiece(a);
      final bIsEdge = _isEdgePiece(b);
      
      if (aIsEdge && !bIsEdge) return -1;
      if (!aIsEdge && bIsEdge) return 1;
      
      // Then sort by distance if in workspace
      final aDist = a.distanceToCorrect ?? double.infinity;
      final bDist = b.distanceToCorrect ?? double.infinity;
      
      return aDist.compareTo(bDist);
    });
    
    _hintsUsed++;
    return unplacedPieces.first;
  }

  /// Auto-solve a single piece (for accessibility)
  bool autoSolvePiece(String pieceId) {
    final piece = _findPiece(pieceId);
    if (piece == null || piece.isPlaced) {
      return false;
    }
    
    piece.placeCorrectly();
    _moveCount++;
    
    if (isCompleted) {
      completedAt = DateTime.now();
    }
    
    return true;
  }

  /// Auto-solve all edge pieces (for accessibility)
  int autoSolveEdges() {
    int solvedCount = 0;
    
    for (final piece in _pieces) {
      if (!piece.isPlaced && _isEdgePiece(piece)) {
        piece.placeCorrectly();
        solvedCount++;
      }
    }
    
    _moveCount += solvedCount;
    
    if (isCompleted) {
      completedAt = DateTime.now();
    }
    
    return solvedCount;
  }

  /// Reset the workspace to initial state
  void reset() {
    for (final piece in _pieces) {
      piece.returnToTray();
    }
    _moveCount = 0;
    _hintsUsed = 0;
    completedAt = null;
  }

  /// Calculate score based on performance
  int calculateScore() {
    if (!isCompleted) return 0;
    
    const baseScore = 1000;
    final timePenalty = sessionDuration.inSeconds; // -1 per second
    final movePenalty = (_moveCount - totalPieces) * 5; // -5 per extra move
    final hintPenalty = _hintsUsed * 50; // -50 per hint
    
    final score = baseScore - timePenalty - movePenalty - hintPenalty;
    return math.max(0, score); // Never negative
  }

  /// Convert to JSON for serialization
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'puzzleId': puzzleId,
      'gridSize': gridSize,
      'canvasSize': {
        'width': canvasSize.width,
        'height': canvasSize.height,
      },
      'pieces': _pieces.map((p) => p.toJson()).toList(),
      'config': config.toJson(),
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'moveCount': _moveCount,
      'hintsUsed': _hintsUsed,
    };
  }

  /// Create from JSON for deserialization
  factory PuzzleWorkspace.fromJson(Map<String, dynamic> json) {
    return PuzzleWorkspace(
      id: json['id'],
      puzzleId: json['puzzleId'],
      gridSize: json['gridSize'],
      canvasSize: Size(
        (json['canvasSize']['width'] as num).toDouble(),
        (json['canvasSize']['height'] as num).toDouble(),
      ),
      pieces: (json['pieces'] as List)
          .map((p) => PuzzlePiece.fromJson(p))
          .toList(),
      config: json['config'] != null 
          ? PlacementConfig.fromJson(json['config'])
          : const PlacementConfig(),
      createdAt: DateTime.parse(json['createdAt']),
    )
      ..completedAt = json['completedAt'] != null
          ? DateTime.parse(json['completedAt'])
          : null
      .._moveCount = json['moveCount'] ?? 0
      .._hintsUsed = json['hintsUsed'] ?? 0;
  }

  // Private helper methods
  
  PuzzlePiece? _findPiece(String pieceId) {
    try {
      return _pieces.firstWhere((p) => p.id == pieceId);
    } catch (_) {
      return null;
    }
  }

  PuzzlePiece? _checkCollisionAt(PuzzlePiece piece, PuzzleCoordinate position) {
    // Temporarily move piece to check collision
    final originalPosition = piece.currentPosition;
    piece.moveTo(position);
    
    PuzzlePiece? collision;
    for (final other in _pieces) {
      if (other.id != piece.id && 
          !other.isInTray &&
          piece.overlapsWithAtCurrentPosition(other)) {
        collision = other;
        break;
      }
    }
    
    // Restore original position
    if (originalPosition != null) {
      piece.moveTo(originalPosition);
    } else {
      piece.returnToTray();
    }
    
    return collision;
  }

  bool _isEdgePiece(PuzzlePiece piece) {
    final dims = gridSize.split('x');
    final maxRow = int.parse(dims[0]) - 1;
    final maxCol = int.parse(dims[1]) - 1;
    
    return piece.correctRow == 0 || 
           piece.correctRow == maxRow ||
           piece.correctCol == 0 || 
           piece.correctCol == maxCol;
  }
}

/// Configuration for piece placement behavior
class PlacementConfig {
  /// Distance within which pieces snap to correct position (in pixels)
  final double snapDistance;
  
  /// Distance within which feedback starts (in pixels)
  final double feedbackDistance;
  
  /// Whether to prevent pieces from overlapping
  final bool preventOverlap;
  
  /// Whether to auto-save progress
  final bool autoSave;
  
  /// Auto-save interval in seconds
  final int autoSaveIntervalSeconds;

  const PlacementConfig({
    this.snapDistance = 50.0,
    this.feedbackDistance = 100.0,
    this.preventOverlap = false,
    this.autoSave = true,
    this.autoSaveIntervalSeconds = 30,
  });

  Map<String, dynamic> toJson() {
    return {
      'snapDistance': snapDistance,
      'feedbackDistance': feedbackDistance,
      'preventOverlap': preventOverlap,
      'autoSave': autoSave,
      'autoSaveIntervalSeconds': autoSaveIntervalSeconds,
    };
  }

  factory PlacementConfig.fromJson(Map<String, dynamic> json) {
    return PlacementConfig(
      snapDistance: json['snapDistance'] != null 
          ? (json['snapDistance'] as num).toDouble() 
          : 50.0,
      feedbackDistance: json['feedbackDistance'] != null 
          ? (json['feedbackDistance'] as num).toDouble() 
          : 100.0,
      preventOverlap: json['preventOverlap'] as bool? ?? false,
      autoSave: json['autoSave'] as bool? ?? true,
      autoSaveIntervalSeconds: json['autoSaveIntervalSeconds'] as int? ?? 30,
    );
  }
}
