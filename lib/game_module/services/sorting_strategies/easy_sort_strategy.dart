// lib/game_module/services/sorting_strategies/easy_sort_strategy.dart

import 'package:puzzgame_flutter/game_module/puzzle_game_module.dart';
import 'package:puzzgame_flutter/game_module/services/sorting_strategies/sorting_strategy.dart';

/// Easy sorting strategy that prioritizes pieces by type
/// 
/// This strategy sorts pieces in the following priority order:
/// 1. Corner pieces (highest priority)
/// 2. Edge pieces (medium priority) 
/// 3. Middle pieces (lowest priority)
/// 
/// Within each category, pieces maintain their relative shuffled order.
class EasySortStrategy implements PieceSortingStrategy {
  @override
  List<PuzzlePiece> sortPieces(List<PuzzlePiece> pieces, int gridSize) {
    final maxIndex = gridSize - 1;
    
    // Classify pieces into categories
    final cornerPieces = <PuzzlePiece>[];
    final edgePieces = <PuzzlePiece>[];
    final middlePieces = <PuzzlePiece>[];
    
    for (final piece in pieces) {
      final pieceType = _classifyPiece(piece, maxIndex);
      
      switch (pieceType) {
        case PieceType.corner:
          cornerPieces.add(piece);
          break;
        case PieceType.edge:
          edgePieces.add(piece);
          break;
        case PieceType.middle:
          middlePieces.add(piece);
          break;
      }
    }
    
    // Return sorted list: corners first, then edges, then middle
    return [
      ...cornerPieces,
      ...edgePieces,
      ...middlePieces,
    ];
  }
  
  /// Classify a puzzle piece based on its correct position in the grid
  PieceType _classifyPiece(PuzzlePiece piece, int maxIndex) {
    final row = piece.correctRow;
    final col = piece.correctCol;
    
    // Check if it's a corner piece
    if (_isCornerPiece(row, col, maxIndex)) {
      return PieceType.corner;
    }
    
    // Check if it's an edge piece
    if (_isEdgePiece(row, col, maxIndex)) {
      return PieceType.edge;
    }
    
    // Otherwise it's a middle piece
    return PieceType.middle;
  }
  
  /// Check if a piece is at a corner position
  bool _isCornerPiece(int row, int col, int maxIndex) {
    return (row == 0 || row == maxIndex) && (col == 0 || col == maxIndex);
  }
  
  /// Check if a piece is at an edge position (but not corner)
  bool _isEdgePiece(int row, int col, int maxIndex) {
    // Edge piece if on any border but not already identified as corner
    final isOnBorder = row == 0 || row == maxIndex || col == 0 || col == maxIndex;
    final isCorner = _isCornerPiece(row, col, maxIndex);
    
    return isOnBorder && !isCorner;
  }
  
  @override
  String get name => 'Easy Sorting';
  
  @override
  String get description => 'Corners first, then edges, then middle pieces';
}

/// Enum to represent the type of puzzle piece based on its position
enum PieceType {
  corner,
  edge,
  middle,
}
