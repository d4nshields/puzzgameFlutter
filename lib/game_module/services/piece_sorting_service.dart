// lib/game_module/services/piece_sorting_service.dart

import 'package:puzzgame_flutter/game_module/puzzle_game_module.dart';
import 'package:puzzgame_flutter/game_module/services/sorting_strategies/sorting_strategy.dart';
import 'package:puzzgame_flutter/game_module/services/sorting_strategies/no_sort_strategy.dart';
import 'package:puzzgame_flutter/game_module/services/sorting_strategies/easy_sort_strategy.dart';

/// Service for managing puzzle piece sorting strategies
/// 
/// This service provides a clean interface for applying different
/// sorting algorithms to puzzle pieces based on user preferences.
class PieceSortingService {
  PieceSortingStrategy _currentStrategy = NoSortStrategy();
  
  /// Get the currently active sorting strategy
  PieceSortingStrategy get currentStrategy => _currentStrategy;
  
  /// Set the sorting strategy based on easy sorting preference
  /// 
  /// [easySortingEnabled] - If true, uses EasySortStrategy, otherwise NoSortStrategy
  void setEasySorting(bool easySortingEnabled) {
    _currentStrategy = easySortingEnabled 
        ? EasySortStrategy() 
        : NoSortStrategy();
  }
  
  /// Sort pieces using the current strategy
  /// 
  /// [pieces] - The list of pieces to sort
  /// [gridSize] - The size of the puzzle grid
  /// 
  /// Returns a new sorted list without modifying the original
  List<PuzzlePiece> sortPieces(List<PuzzlePiece> pieces, int gridSize) {
    return _currentStrategy.sortPieces(pieces, gridSize);
  }
  
  /// Get all available sorting strategies
  /// 
  /// This method can be used in the future for more advanced
  /// sorting preference UIs that allow selection from multiple strategies.
  List<PieceSortingStrategy> getAvailableStrategies() {
    return [
      NoSortStrategy(),
      EasySortStrategy(),
    ];
  }
  
  /// Set sorting strategy directly by strategy instance
  /// 
  /// This allows for future extensibility where users might
  /// select from multiple sorting algorithms.
  void setStrategy(PieceSortingStrategy strategy) {
    _currentStrategy = strategy;
  }
}
