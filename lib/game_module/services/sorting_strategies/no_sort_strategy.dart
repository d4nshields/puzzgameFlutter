// lib/game_module/services/sorting_strategies/no_sort_strategy.dart

import 'package:puzzgame_flutter/game_module/puzzle_game_module.dart';
import 'package:puzzgame_flutter/game_module/services/sorting_strategies/sorting_strategy.dart';

/// Default sorting strategy that maintains the original order
/// 
/// This strategy preserves the existing behavior where pieces
/// are displayed in their original shuffled order.
class NoSortStrategy implements PieceSortingStrategy {
  @override
  List<PuzzlePiece> sortPieces(List<PuzzlePiece> pieces, int gridSize) {
    // Return a copy of the original list without any sorting
    return List.from(pieces);
  }
  
  @override
  String get name => 'No Sorting';
  
  @override
  String get description => 'Pieces are displayed in their original shuffled order';
}
