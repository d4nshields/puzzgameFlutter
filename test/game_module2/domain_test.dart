import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzgame_flutter/game_module2/domain/entities/puzzle_piece.dart';
import 'package:puzzgame_flutter/game_module2/domain/entities/puzzle_workspace.dart';
import 'package:puzzgame_flutter/game_module2/domain/value_objects/puzzle_coordinate.dart';
import 'package:puzzgame_flutter/game_module2/domain/value_objects/piece_bounds.dart';
import 'package:puzzgame_flutter/game_module2/domain/value_objects/move_result.dart';

void main() {
  group('PuzzleWorkspace', () {
    late PuzzleWorkspace workspace;
    late List<PuzzlePiece> pieces;

    setUp(() {
      // Create test pieces for a 2x2 grid
      pieces = [
        PuzzlePiece(
          id: '0_0',
          correctRow: 0,
          correctCol: 0,
          correctPosition: const PuzzleCoordinate(x: 0, y: 0),
          bounds: PieceBounds(
            contentBounds: const ContentRect(left: 0, top: 0, right: 100, bottom: 100),
            paddedSize: const Size(200, 200),
            targetBounds: const ContentRect(left: 0, top: 0, right: 100, bottom: 100),
          ),
        ),
        PuzzlePiece(
          id: '0_1',
          correctRow: 0,
          correctCol: 1,
          correctPosition: const PuzzleCoordinate(x: 100, y: 0),
          bounds: PieceBounds(
            contentBounds: const ContentRect(left: 100, top: 0, right: 200, bottom: 100),
            paddedSize: const Size(200, 200),
            targetBounds: const ContentRect(left: 100, top: 0, right: 200, bottom: 100),
          ),
        ),
        PuzzlePiece(
          id: '1_0',
          correctRow: 1,
          correctCol: 0,
          correctPosition: const PuzzleCoordinate(x: 0, y: 100),
          bounds: PieceBounds(
            contentBounds: const ContentRect(left: 0, top: 100, right: 100, bottom: 200),
            paddedSize: const Size(200, 200),
            targetBounds: const ContentRect(left: 0, top: 100, right: 100, bottom: 200),
          ),
        ),
        PuzzlePiece(
          id: '1_1',
          correctRow: 1,
          correctCol: 1,
          correctPosition: const PuzzleCoordinate(x: 100, y: 100),
          bounds: PieceBounds(
            contentBounds: const ContentRect(left: 100, top: 100, right: 200, bottom: 200),
            paddedSize: const Size(200, 200),
            targetBounds: const ContentRect(left: 100, top: 100, right: 200, bottom: 200),
          ),
        ),
      ];

      workspace = PuzzleWorkspace(
        id: 'test_workspace',
        puzzleId: 'test_puzzle',
        gridSize: '2x2',
        canvasSize: const Size(200, 200),
        pieces: pieces,
        config: const PlacementConfig(
          snapDistance: 20.0,
          feedbackDistance: 40.0,
        ),
      );
    });

    test('initializes with all pieces in tray', () {
      expect(workspace.trayPieces.length, equals(4));
      expect(workspace.placedPieces.length, equals(0));
      expect(workspace.workspacePieces.length, equals(0));
    });

    test('moves piece from tray to workspace', () {
      final piece = workspace.pickUpPiece('0_0');
      
      expect(piece, isNotNull);
      expect(workspace.trayPieces.length, equals(3));
      expect(workspace.workspacePieces.length, equals(1));
    });

    test('snaps piece when moved close to correct position', () {
      workspace.pickUpPiece('0_0');
      
      // Move piece close to correct position (within snap distance of 20)
      final result = workspace.movePiece('0_0', const PuzzleCoordinate(x: 15, y: 10));
      
      expect(result.type, equals(MoveResultType.snapped));
      expect(result.finalPosition, equals(const PuzzleCoordinate(x: 0, y: 0)));
      expect(workspace.placedPieces.length, equals(1));
    });

    test('provides proximity feedback when near but not snapping', () {
      workspace.pickUpPiece('0_0');
      
      // Move piece near but outside snap distance (between 20 and 40)
      final result = workspace.movePiece('0_0', const PuzzleCoordinate(x: 30, y: 0));
      
      expect(result.type, equals(MoveResultType.near));
      expect(result.proximityIntensity, isNotNull);
      expect(result.proximityIntensity! > 0, isTrue);
      expect(result.proximityIntensity! < 1, isTrue);
      expect(workspace.placedPieces.length, equals(0));
    });

    test('regular move when far from correct position', () {
      workspace.pickUpPiece('0_0');
      
      // Move piece far from correct position (beyond feedback distance of 40)
      final result = workspace.movePiece('0_0', const PuzzleCoordinate(x: 150, y: 150));
      
      expect(result.type, equals(MoveResultType.moved));
      expect(result.proximityIntensity, isNull);
      expect(workspace.workspacePieces.length, equals(1));
    });

    test('detects puzzle completion', () {
      // Place all pieces
      workspace.pickUpPiece('0_0');
      workspace.movePiece('0_0', const PuzzleCoordinate(x: 5, y: 5));
      
      workspace.pickUpPiece('0_1');
      workspace.movePiece('0_1', const PuzzleCoordinate(x: 105, y: 5));
      
      workspace.pickUpPiece('1_0');
      workspace.movePiece('1_0', const PuzzleCoordinate(x: 5, y: 105));
      
      expect(workspace.isCompleted, isFalse);
      
      workspace.pickUpPiece('1_1');
      final result = workspace.movePiece('1_1', const PuzzleCoordinate(x: 105, y: 105));
      
      expect(result.type, equals(MoveResultType.snapped));
      expect(workspace.isCompleted, isTrue);
      expect(workspace.completedAt, isNotNull);
    });

    test('calculates score based on performance', () {
      // Complete puzzle quickly with minimal moves
      workspace.pickUpPiece('0_0');
      workspace.movePiece('0_0', const PuzzleCoordinate(x: 0, y: 0));
      
      workspace.pickUpPiece('0_1');
      workspace.movePiece('0_1', const PuzzleCoordinate(x: 100, y: 0));
      
      workspace.pickUpPiece('1_0');
      workspace.movePiece('1_0', const PuzzleCoordinate(x: 0, y: 100));
      
      workspace.pickUpPiece('1_1');
      workspace.movePiece('1_1', const PuzzleCoordinate(x: 100, y: 100));
      
      final score = workspace.calculateScore();
      
      expect(score, greaterThan(0));
      expect(score, lessThanOrEqualTo(1000)); // Base score minus time penalty
    });

    test('provides hints for unplaced pieces', () {
      final hint = workspace.getHint();
      
      expect(hint, isNotNull);
      expect(workspace.hintsUsed, equals(1));
    });

    test('resets workspace to initial state', () {
      // Place some pieces
      workspace.pickUpPiece('0_0');
      workspace.movePiece('0_0', const PuzzleCoordinate(x: 0, y: 0));
      
      workspace.pickUpPiece('0_1');
      workspace.movePiece('0_1', const PuzzleCoordinate(x: 150, y: 50));
      
      expect(workspace.placedCount, equals(1));
      expect(workspace.moveCount, greaterThan(0));
      
      // Reset
      workspace.reset();
      
      expect(workspace.trayPieces.length, equals(4));
      expect(workspace.placedPieces.length, equals(0));
      expect(workspace.workspacePieces.length, equals(0));
      expect(workspace.moveCount, equals(0));
    });

    test('prevents moving already placed pieces', () {
      workspace.pickUpPiece('0_0');
      workspace.movePiece('0_0', const PuzzleCoordinate(x: 0, y: 0));
      
      // Try to move the placed piece
      final result = workspace.movePiece('0_0', const PuzzleCoordinate(x: 50, y: 50));
      
      expect(result.type, equals(MoveResultType.blocked));
      expect(result.message, contains('already placed'));
    });

    test('serializes and deserializes workspace', () {
      // Set up some state
      workspace.pickUpPiece('0_0');
      workspace.movePiece('0_0', const PuzzleCoordinate(x: 0, y: 0));
      
      workspace.pickUpPiece('0_1');
      workspace.movePiece('0_1', const PuzzleCoordinate(x: 150, y: 50));
      
      // Serialize
      final json = workspace.toJson();
      
      // Deserialize
      final restored = PuzzleWorkspace.fromJson(json);
      
      expect(restored.id, equals(workspace.id));
      expect(restored.placedCount, equals(workspace.placedCount));
      expect(restored.moveCount, equals(workspace.moveCount));
      expect(restored.pieces.length, equals(workspace.pieces.length));
    });
  });

  group('PuzzleCoordinate', () {
    test('calculates distance correctly', () {
      const coord1 = PuzzleCoordinate(x: 0, y: 0);
      const coord2 = PuzzleCoordinate(x: 3, y: 4);
      
      expect(coord1.distanceTo(coord2), equals(5.0));
    });

    test('checks proximity correctly', () {
      const coord1 = PuzzleCoordinate(x: 100, y: 100);
      const coord2 = PuzzleCoordinate(x: 110, y: 100);
      
      expect(coord1.isNear(coord2, threshold: 15), isTrue);
      expect(coord1.isNear(coord2, threshold: 5), isFalse);
    });

    test('translates correctly', () {
      const coord = PuzzleCoordinate(x: 100, y: 200);
      final translated = coord.translate(dx: 50, dy: -30);
      
      expect(translated.x, equals(150));
      expect(translated.y, equals(170));
    });
  });

  group('ProximityFeedback', () {
    test('calculates feedback intensity based on distance', () {
      final feedback1 = ProximityFeedback.fromDistance(
        distance: 0,
        maxDistance: 100,
      );
      expect(feedback1.intensity, equals(1.0));
      expect(feedback1.level, equals(FeedbackLevel.strong));

      final feedback2 = ProximityFeedback.fromDistance(
        distance: 50,
        maxDistance: 100,
      );
      expect(feedback2.intensity, equals(0.5));
      expect(feedback2.level, equals(FeedbackLevel.medium));

      final feedback3 = ProximityFeedback.fromDistance(
        distance: 100,
        maxDistance: 100,
      );
      expect(feedback3.intensity, equals(0.0));
      expect(feedback3.level, equals(FeedbackLevel.none));
    });
  });
}
