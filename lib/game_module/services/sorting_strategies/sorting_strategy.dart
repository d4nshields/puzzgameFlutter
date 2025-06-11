// lib/game_module/services/sorting_strategies/sorting_strategy.dart

import 'package:puzzgame_flutter/game_module/puzzle_game_module.dart';

/// Abstract strategy interface for sorting puzzle pieces
/// 
/// This interface allows for different sorting algorithms to be implemented
/// and easily swapped based on user preferences or game requirements.
abstract class PieceSortingStrategy {
  /// Sort a list of puzzle pieces based on the strategy's algorithm
  /// 
  /// [pieces] - The list of pieces to sort
  /// [gridSize] - The size of the puzzle grid (gridSize x gridSize)
  /// 
  /// Returns a new sorted list without modifying the original
  List<PuzzlePiece> sortPieces(List<PuzzlePiece> pieces, int gridSize);
  
  /// Human-readable name for this sorting strategy
  String get name;
  
  /// Description of how this strategy sorts pieces
  String get description;
}
