// test/game_module/services/easy_sort_strategy_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:puzzgame_flutter/game_module/puzzle_game_module.dart';
import 'package:puzzgame_flutter/game_module/services/sorting_strategies/easy_sort_strategy.dart';
import 'package:puzzgame_flutter/game_module/services/puzzle_asset_manager.dart';
import 'package:puzzgame_flutter/game_module/services/enhanced_puzzle_asset_manager.dart';

void main() {
  group('EasySortStrategy', () {
    late EasySortStrategy strategy;
    late PuzzleAssetManager mockAssetManager;
    late EnhancedPuzzleAssetManager mockEnhancedAssetManager;

    setUp(() {
      strategy = EasySortStrategy();
      // Create mock asset managers - in a real test you'd use proper mocks
      mockAssetManager = PuzzleAssetManager();
      mockEnhancedAssetManager = EnhancedPuzzleAssetManager();
    });

    test('should have correct name and description', () {
      expect(strategy.name, equals('Easy Sorting'));
      expect(strategy.description, equals('Corners first, then edges, then middle pieces'));
    });

    test('should sort 3x3 grid pieces correctly', () {
      // Create a 3x3 grid of pieces
      final pieces = <PuzzlePiece>[];
      
      // Add pieces in random order: middle, edge, corner, edge, middle, corner, edge, middle, corner
      pieces.addAll([
        // Middle piece
        PuzzlePiece(id: '1_1', correctRow: 1, correctCol: 1, 
                   assetManager: mockAssetManager, enhancedAssetManager: mockEnhancedAssetManager),
        // Edge piece
        PuzzlePiece(id: '0_1', correctRow: 0, correctCol: 1, 
                   assetManager: mockAssetManager, enhancedAssetManager: mockEnhancedAssetManager),
        // Corner piece
        PuzzlePiece(id: '0_0', correctRow: 0, correctCol: 0, 
                   assetManager: mockAssetManager, enhancedAssetManager: mockEnhancedAssetManager),
        // Edge piece
        PuzzlePiece(id: '1_0', correctRow: 1, correctCol: 0, 
                   assetManager: mockAssetManager, enhancedAssetManager: mockEnhancedAssetManager),
        // Middle piece (if we had larger grid)
        // Corner piece
        PuzzlePiece(id: '2_2', correctRow: 2, correctCol: 2, 
                   assetManager: mockAssetManager, enhancedAssetManager: mockEnhancedAssetManager),
        // Edge piece
        PuzzlePiece(id: '2_1', correctRow: 2, correctCol: 1, 
                   assetManager: mockAssetManager, enhancedAssetManager: mockEnhancedAssetManager),
        // Corner piece
        PuzzlePiece(id: '0_2', correctRow: 0, correctCol: 2, 
                   assetManager: mockAssetManager, enhancedAssetManager: mockEnhancedAssetManager),
        // Edge piece
        PuzzlePiece(id: '1_2', correctRow: 1, correctCol: 2, 
                   assetManager: mockAssetManager, enhancedAssetManager: mockEnhancedAssetManager),
        // Corner piece
        PuzzlePiece(id: '2_0', correctRow: 2, correctCol: 0, 
                   assetManager: mockAssetManager, enhancedAssetManager: mockEnhancedAssetManager),
      ]);

      final sortedPieces = strategy.sortPieces(pieces, 3);

      // Verify the sorting: corners first, then edges, then middle
      expect(sortedPieces.length, equals(9));

      // First 4 should be corners
      final corners = sortedPieces.take(4).toList();
      expect(corners.map((p) => p.id).toSet(), 
             equals({'0_0', '0_2', '2_0', '2_2'}));

      // Next 4 should be edges
      final edges = sortedPieces.skip(4).take(4).toList();
      expect(edges.map((p) => p.id).toSet(), 
             equals({'0_1', '1_0', '1_2', '2_1'}));

      // Last 1 should be middle
      final middle = sortedPieces.skip(8).toList();
      expect(middle.map((p) => p.id).toSet(), 
             equals({'1_1'}));
    });

    test('should handle empty list', () {
      final sortedPieces = strategy.sortPieces([], 3);
      expect(sortedPieces, isEmpty);
    });

    test('should handle single piece', () {
      final pieces = [
        PuzzlePiece(id: '0_0', correctRow: 0, correctCol: 0, 
                   assetManager: mockAssetManager, enhancedAssetManager: mockEnhancedAssetManager),
      ];

      final sortedPieces = strategy.sortPieces(pieces, 1);
      expect(sortedPieces.length, equals(1));
      expect(sortedPieces.first.id, equals('0_0'));
    });

    test('should correctly identify corner pieces in 4x4 grid', () {
      final pieces = <PuzzlePiece>[
        // All 4 corners of 4x4 grid (0-3 indices)
        PuzzlePiece(id: '0_0', correctRow: 0, correctCol: 0, 
                   assetManager: mockAssetManager, enhancedAssetManager: mockEnhancedAssetManager),
        PuzzlePiece(id: '0_3', correctRow: 0, correctCol: 3, 
                   assetManager: mockAssetManager, enhancedAssetManager: mockEnhancedAssetManager),
        PuzzlePiece(id: '3_0', correctRow: 3, correctCol: 0, 
                   assetManager: mockAssetManager, enhancedAssetManager: mockEnhancedAssetManager),
        PuzzlePiece(id: '3_3', correctRow: 3, correctCol: 3, 
                   assetManager: mockAssetManager, enhancedAssetManager: mockEnhancedAssetManager),
        // One edge piece
        PuzzlePiece(id: '0_1', correctRow: 0, correctCol: 1, 
                   assetManager: mockAssetManager, enhancedAssetManager: mockEnhancedAssetManager),
        // One middle piece  
        PuzzlePiece(id: '1_1', correctRow: 1, correctCol: 1, 
                   assetManager: mockAssetManager, enhancedAssetManager: mockEnhancedAssetManager),
      ];

      final sortedPieces = strategy.sortPieces(pieces, 4);

      // First 4 should be the corners
      final corners = sortedPieces.take(4).toList();
      expect(corners.map((p) => p.id).toSet(), 
             equals({'0_0', '0_3', '3_0', '3_3'}));
    });
  });
}
