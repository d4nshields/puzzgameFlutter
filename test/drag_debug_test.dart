import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzgame_flutter/game_module2/domain/services/piece_state_machine.dart';
import 'package:puzzgame_flutter/game_module2/domain/entities/puzzle_piece.dart';
import 'package:puzzgame_flutter/game_module2/domain/value_objects/puzzle_coordinate.dart';
import 'package:puzzgame_flutter/game_module2/domain/value_objects/piece_bounds.dart';

void main() {
  test('Debug: drag end distance calculation', () async {
    final testPiece = PuzzlePiece(
      id: 'test_piece_1',
      correctRow: 0,
      correctCol: 0,
      correctPosition: PuzzleCoordinate(x: 100, y: 100),
      bounds: PieceBounds(
        contentBounds: const ContentRect(
          left: 0,
          top: 0,
          right: 50,
          bottom: 50,
        ),
        paddedSize: const Size(60, 60),
        targetBounds: const ContentRect(
          left: 100,
          top: 100,
          right: 150,
          bottom: 150,
        ),
      ),
    );
    
    final stateMachine = PieceStateMachine(
      pieceId: 'test_piece_1',
      piece: testPiece,
      debugMode: true,
    );

    print('Initial state: ${stateMachine.currentState}');
    print('Correct position: ${testPiece.correctPosition}');
    
    // Select the piece
    await stateMachine.processEvent(PieceSelectEvent(
      pieceId: 'test_piece_1',
      position: PuzzleCoordinate(x: 50, y: 50),
    ));
    print('After select: ${stateMachine.currentState}');
    
    // Start dragging
    await stateMachine.processEvent(PieceDragStartEvent(
      pieceId: 'test_piece_1',
      startPosition: PuzzleCoordinate(x: 50, y: 50),
    ));
    print('After drag start: ${stateMachine.currentState}');
    
    // Drag update
    await stateMachine.processEvent(PieceDragUpdateEvent(
      pieceId: 'test_piece_1',
      position: PuzzleCoordinate(x: 75, y: 75),
      delta: PuzzleCoordinate(x: 25, y: 25),
      velocity: 100.0,
    ));
    print('After drag update: ${stateMachine.currentState}');
    print('Piece position after update: ${testPiece.currentPosition}');
    
    // Calculate distance before drag end
    final endPosition = PuzzleCoordinate(x: 95, y: 95);
    final distance = endPosition.distanceTo(testPiece.correctPosition);
    print('End position: $endPosition');
    print('Distance to correct: $distance');
    print('Should snap? ${distance <= 50.0}');
    
    // End drag
    final dragEndResult = await stateMachine.processEvent(PieceDragEndEvent(
      pieceId: 'test_piece_1',
      endPosition: endPosition,
      velocity: 50.0,
    ));
    
    print('Drag end result: $dragEndResult');
    print('After drag end: ${stateMachine.currentState}');
    print('Final piece position: ${testPiece.currentPosition}');
    print('State history: ${stateMachine.stateHistory}');
    print('Event history count: ${stateMachine.eventHistory.length}');
    
    // Check debug log
    print('\nDebug log:');
    for (final log in stateMachine.debugLog) {
      print(log);
    }
    
    // The state should be snapping since distance is ~7.07
    expect(distance < 50.0, true, reason: 'Distance should be less than 50');
    expect(stateMachine.currentState, PieceStateType.snapping, 
           reason: 'Should be in snapping state when close to correct position');
    
    stateMachine.dispose();
  });
}
