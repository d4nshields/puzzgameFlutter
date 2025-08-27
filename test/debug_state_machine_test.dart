import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzgame_flutter/game_module2/domain/services/piece_state_machine.dart';
import 'package:puzzgame_flutter/game_module2/domain/services/state_transitions.dart';
import 'package:puzzgame_flutter/game_module2/domain/entities/puzzle_piece.dart';
import 'package:puzzgame_flutter/game_module2/domain/value_objects/puzzle_coordinate.dart';
import 'package:puzzgame_flutter/game_module2/domain/value_objects/piece_bounds.dart';

void main() {
  test('Debug: should handle drag sequence correctly', () async {
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
    
    expect(stateMachine.currentState, PieceStateType.dragging);
    
    // Drag update
    await stateMachine.processEvent(PieceDragUpdateEvent(
      pieceId: 'test_piece_1',
      position: PuzzleCoordinate(x: 75, y: 75),
      delta: PuzzleCoordinate(x: 25, y: 25),
      velocity: 100.0,
    ));
    print('After drag update: ${stateMachine.currentState}');
    print('Piece position: ${testPiece.currentPosition}');
    
    expect(testPiece.currentPosition?.x, 75);
    expect(testPiece.currentPosition?.y, 75);
    
    // End drag
    await stateMachine.processEvent(PieceDragEndEvent(
      pieceId: 'test_piece_1',
      endPosition: PuzzleCoordinate(x: 95, y: 95),
      velocity: 50.0,
    ));
    
    print('After drag end: ${stateMachine.currentState}');
    print('State history: ${stateMachine.stateHistory}');
    print('Debug log:');
    stateMachine.debugLog.forEach(print);
    
    // Should transition based on position
    // Since we're close to correct position (100, 100), it might snap
    final validState = stateMachine.currentState == PieceStateType.idle ||
                      stateMachine.currentState == PieceStateType.snapping;
    print('Valid state check: $validState (current: ${stateMachine.currentState})');
    expect(validState, true);
    
    stateMachine.dispose();
  });

  test('Debug: should not transition from locked state', () async {
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
    
    // Select at correct position
    await stateMachine.processEvent(PieceSelectEvent(
      pieceId: 'test_piece_1',
      position: PuzzleCoordinate(x: 100, y: 100),
    ));
    print('After select: ${stateMachine.currentState}');
    
    // Place the piece correctly
    testPiece.moveTo(PuzzleCoordinate(x: 100, y: 100));
    await stateMachine.processEvent(PiecePlaceEvent(
      pieceId: 'test_piece_1',
      isCorrect: true,
    ));
    print('After place: ${stateMachine.currentState}');
    
    // Lock the piece
    await stateMachine.processEvent(PieceLockEvent(pieceId: 'test_piece_1'));
    print('After lock: ${stateMachine.currentState}');
    
    expect(stateMachine.currentState, PieceStateType.locked);
    
    // Try to drag - should fail
    final dragResult = await stateMachine.processEvent(PieceDragStartEvent(
      pieceId: 'test_piece_1',
      startPosition: PuzzleCoordinate(x: 100, y: 100),
    ));
    
    print('Drag result: $dragResult');
    print('State after drag attempt: ${stateMachine.currentState}');
    print('Debug log:');
    stateMachine.debugLog.forEach(print);
    
    expect(dragResult, false);
    expect(stateMachine.currentState, PieceStateType.locked);
    
    stateMachine.dispose();
  });

  test('Debug: should verify state sequence', () async {
    final machine = TransitionTestUtils.createMockMachine();
    
    print('Initial state: ${machine.currentState}');
    print('Initial history: ${machine.stateHistory}');
    
    // Process some events
    await machine.processEvent(PieceHoverEvent(pieceId: 'test_piece'));
    print('After hover: ${machine.currentState}');
    print('History: ${machine.stateHistory}');
    
    await machine.processEvent(PieceSelectEvent(
      pieceId: 'test_piece',
      position: PuzzleCoordinate(x: 50, y: 50),
    ));
    print('After select: ${machine.currentState}');
    print('History: ${machine.stateHistory}');
    
    // Verify sequence
    final expectedSequence = [PieceStateType.idle, PieceStateType.hovering, PieceStateType.selected];
    print('Expected sequence: $expectedSequence');
    
    final isValid = TransitionTestUtils.verifyStateSequence(
      machine,
      expectedSequence,
    );
    
    print('Sequence valid: $isValid');
    print('Debug log:');
    machine.debugLog.forEach(print);
    
    expect(isValid, true);
    
    machine.dispose();
  });
}
