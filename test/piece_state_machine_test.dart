import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/scheduler.dart';
import 'package:puzzgame_flutter/game_module2/domain/services/piece_state_machine.dart';
import 'package:puzzgame_flutter/game_module2/domain/services/state_transitions.dart';
import 'package:puzzgame_flutter/game_module2/domain/entities/puzzle_piece.dart';
import 'package:puzzgame_flutter/game_module2/domain/value_objects/puzzle_coordinate.dart';
import 'package:puzzgame_flutter/game_module2/domain/value_objects/piece_bounds.dart';

void main() {
  group('PieceStateMachine', () {
    late PuzzlePiece testPiece;
    late PieceStateMachine stateMachine;
    
    setUp(() {
      testPiece = PuzzlePiece(
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
      
      stateMachine = PieceStateMachine(
        pieceId: 'test_piece_1',
        piece: testPiece,
        debugMode: true,
      );
    });
    
    tearDown(() {
      stateMachine.dispose();
    });
    
    test('should initialize with idle state', () {
      expect(stateMachine.currentState, PieceStateType.idle);
      expect(stateMachine.parallelStates[StateRegion.interaction], PieceStateType.idle);
    });
    
    test('should transition from idle to hovering', () async {
      final event = PieceHoverEvent(pieceId: 'test_piece_1');
      final result = await stateMachine.processEvent(event);
      
      expect(result, true);
      expect(stateMachine.currentState, PieceStateType.hovering);
    });
    
    test('should transition from hovering to selected', () async {
      // First hover
      await stateMachine.processEvent(PieceHoverEvent(pieceId: 'test_piece_1'));
      
      // Then select
      final selectEvent = PieceSelectEvent(
        pieceId: 'test_piece_1',
        position: PuzzleCoordinate(x: 50, y: 50),
      );
      final result = await stateMachine.processEvent(selectEvent);
      
      expect(result, true);
      expect(stateMachine.currentState, PieceStateType.selected);
      expect(testPiece.isSelected, true);
    });
    
    test('should handle drag sequence correctly', () async {
      // Select the piece
      await stateMachine.processEvent(PieceSelectEvent(
        pieceId: 'test_piece_1',
        position: PuzzleCoordinate(x: 50, y: 50),
      ));
      
      // Start dragging
      await stateMachine.processEvent(PieceDragStartEvent(
        pieceId: 'test_piece_1',
        startPosition: PuzzleCoordinate(x: 50, y: 50),
      ));
      
      expect(stateMachine.currentState, PieceStateType.dragging);
      
      // Drag update
      await stateMachine.processEvent(PieceDragUpdateEvent(
        pieceId: 'test_piece_1',
        position: PuzzleCoordinate(x: 75, y: 75),
        delta: PuzzleCoordinate(x: 25, y: 25),
        velocity: 100.0,
      ));
      
      expect(testPiece.currentPosition?.x, 75);
      expect(testPiece.currentPosition?.y, 75);
      
      // End drag
      await stateMachine.processEvent(PieceDragEndEvent(
        pieceId: 'test_piece_1',
        endPosition: PuzzleCoordinate(x: 95, y: 95),
        velocity: 50.0,
      ));
      
      // Should transition based on position
      // Since we're close to correct position (100, 100), it might snap
      expect(
        stateMachine.currentState == PieceStateType.idle ||
        stateMachine.currentState == PieceStateType.snapping,
        true,
      );
    });
    
    test('should maintain event history', () async {
      await stateMachine.processEvent(PieceHoverEvent(pieceId: 'test_piece_1'));
      await stateMachine.processEvent(PieceSelectEvent(
        pieceId: 'test_piece_1',
        position: PuzzleCoordinate(x: 50, y: 50),
      ));
      
      expect(stateMachine.eventHistory.length, 2);
      expect(stateMachine.eventHistory[0] is PieceHoverEvent, true);
      expect(stateMachine.eventHistory[1] is PieceSelectEvent, true);
    });
    
    test('should support state rollback', () async {
      // Create state changes
      await stateMachine.processEvent(PieceHoverEvent(pieceId: 'test_piece_1'));
      expect(stateMachine.currentState, PieceStateType.hovering);
      
      await stateMachine.processEvent(PieceSelectEvent(
        pieceId: 'test_piece_1',
        position: PuzzleCoordinate(x: 50, y: 50),
      ));
      expect(stateMachine.currentState, PieceStateType.selected);
      
      // Rollback
      final rollbackSuccess = stateMachine.rollback();
      expect(rollbackSuccess, true);
      expect(stateMachine.currentState, PieceStateType.hovering);
      
      // Rollback again
      stateMachine.rollback();
      expect(stateMachine.currentState, PieceStateType.idle);
    });
    
    test('should support undo functionality', () async {
      // Create multiple state changes
      await stateMachine.processEvent(PieceHoverEvent(pieceId: 'test_piece_1'));
      await stateMachine.processEvent(PieceSelectEvent(
        pieceId: 'test_piece_1',
        position: PuzzleCoordinate(x: 50, y: 50),
      ));
      await stateMachine.processEvent(PieceDragStartEvent(
        pieceId: 'test_piece_1',
        startPosition: PuzzleCoordinate(x: 50, y: 50),
      ));
      
      expect(stateMachine.currentState, PieceStateType.dragging);
      
      // Undo 2 steps
      final undoResult = stateMachine.undo(steps: 2);
      expect(undoResult, true);
      expect(stateMachine.currentState, PieceStateType.hovering);
    });
    
    test('should handle parallel states correctly', () async {
      // Select and start dragging
      await stateMachine.processEvent(PieceSelectEvent(
        pieceId: 'test_piece_1',
        position: PuzzleCoordinate(x: 50, y: 50),
      ));
      await stateMachine.processEvent(PieceDragStartEvent(
        pieceId: 'test_piece_1',
        startPosition: PuzzleCoordinate(x: 50, y: 50),
      ));
      
      // Check parallel states
      expect(stateMachine.parallelStates[StateRegion.interaction], PieceStateType.dragging);
      
      // Trigger magnetization (requires position near correct position)
      testPiece.moveTo(PuzzleCoordinate(x: 95, y: 95)); // Near correct position
      await stateMachine.processEvent(PieceMagnetizeEvent(
        pieceId: 'test_piece_1',
        magnetPosition: PuzzleCoordinate(x: 100, y: 100),
        strength: 0.8,
      ));
      
      // Physics region should be magnetized
      expect(stateMachine.isStateActive(PieceStateType.magnetized), true);
    });
    
    test('should export and import state correctly', () async {
      // Create some state
      await stateMachine.processEvent(PieceHoverEvent(pieceId: 'test_piece_1'));
      await stateMachine.processEvent(PieceSelectEvent(
        pieceId: 'test_piece_1',
        position: PuzzleCoordinate(x: 50, y: 50),
      ));
      
      stateMachine.setMetadata('testKey', 'testValue');
      
      // Export state
      final exported = stateMachine.exportState();
      expect(exported['pieceId'], 'test_piece_1');
      expect(exported['currentState'], contains('selected'));
      expect(exported['metadata']['testKey'], 'testValue');
      
      // Create new machine and import
      final newMachine = PieceStateMachine(
        pieceId: 'test_piece_1',
        piece: testPiece,
      );
      
      newMachine.importState(exported);
      expect(newMachine.currentState, PieceStateType.selected);
      expect(newMachine.metadata['testKey'], 'testValue');
      
      newMachine.dispose();
    });
    
    test('should provide visualization data', () async {
      await stateMachine.processEvent(PieceHoverEvent(pieceId: 'test_piece_1'));
      
      final vizData = stateMachine.getVisualizationData();
      
      expect(vizData['currentState'], contains('hovering'));
      expect(vizData['availableTransitions'], isA<List>());
      expect(vizData['recentEvents'], isA<List>());
      expect(vizData['timeInState'], isA<int>());
      expect(vizData['historySize'], isA<int>());
    });
    
    test('should not transition from locked state', () async {
      // Force piece into locked state by manipulating internal state
      // (In real usage, this would happen through proper transitions)
      await stateMachine.processEvent(PieceSelectEvent(
        pieceId: 'test_piece_1',
        position: PuzzleCoordinate(x: 100, y: 100),
      ));
      
      // Place the piece correctly
      testPiece.moveTo(PuzzleCoordinate(x: 100, y: 100));
      await stateMachine.processEvent(PiecePlaceEvent(
        pieceId: 'test_piece_1',
        isCorrect: true,
      ));
      
      // Lock the piece
      await stateMachine.processEvent(PieceLockEvent(pieceId: 'test_piece_1'));
      
      expect(stateMachine.currentState, PieceStateType.locked);
      
      // Try to drag - should fail
      final dragResult = await stateMachine.processEvent(PieceDragStartEvent(
        pieceId: 'test_piece_1',
        startPosition: PuzzleCoordinate(x: 100, y: 100),
      ));
      
      expect(dragResult, false);
      expect(stateMachine.currentState, PieceStateType.locked);
    });
  });
  
  group('TransitionValidator', () {
    late TransitionValidator validator;
    late PieceStateMachine machine;
    late PuzzlePiece testPiece;
    
    setUp(() {
      validator = TransitionValidator(debugMode: true);
      
      testPiece = PuzzlePiece(
        id: 'test_piece',
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
      
      machine = PieceStateMachine(
        pieceId: 'test_piece',
        piece: testPiece,
      );
    });
    
    tearDown(() {
      machine.dispose();
    });
    
    test('should validate transitions correctly', () {
      // Valid transition: idle to hovering
      final hoverEvent = PieceHoverEvent(pieceId: 'test_piece');
      final result1 = validator.validate(machine, hoverEvent);
      expect(result1.isValid, true);
      
      // Invalid transition: drag without selection
      final dragEvent = PieceDragStartEvent(
        pieceId: 'test_piece',
        startPosition: PuzzleCoordinate(x: 50, y: 50),
      );
      final result2 = validator.validate(machine, dragEvent);
      expect(result2.isValid, false);
      expect(result2.errorMessage, contains('must be selected'));
    });
    
    test('should respect rule priorities', () {
      // Add a high-priority rule
      validator.addRule(TransitionRule(
        id: 'test_high_priority',
        description: 'Test high priority rule',
        condition: (machine, event) => false,
        priority: 200,
      ));
      
      final event = PieceHoverEvent(pieceId: 'test_piece');
      final result = validator.validate(machine, event);
      
      expect(result.isValid, false);
      expect(result.errorMessage, contains('Test high priority'));
    });
    
    test('should enable and disable rules', () {
      validator.setRuleEnabled('no_transition_from_locked', false);
      
      // Force locked state
      machine.processEvent(PieceSelectEvent(
        pieceId: 'test_piece',
        position: PuzzleCoordinate(x: 100, y: 100),
      ));
      testPiece.placeCorrectly();
      machine.processEvent(PieceLockEvent(pieceId: 'test_piece'));
      
      // With rule disabled, validation should pass
      final event = PieceHoverEvent(pieceId: 'test_piece');
      final result = validator.validate(machine, event);
      
      // Note: Other rules might still block this, but the locked rule won't
      expect(result.metadata['failedRules'], isNot(contains('locked')));
    });
  });
  
  group('BatchTransitioner', () {
    late TransitionValidator validator;
    late TransitionRecorder recorder;
    late BatchTransitioner batchTransitioner;
    late List<PieceStateMachine> machines;
    
    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
    });
    
    setUp(() {
      validator = TransitionValidator();
      recorder = TransitionRecorder();
      
      // Create a test ticker provider
      final tickerProvider = TestVSync();
      final animator = TransitionAnimator(tickerProvider: tickerProvider);
      
      batchTransitioner = BatchTransitioner(
        validator: validator,
        animator: animator,
        recorder: recorder,
      );
      
      // Create multiple state machines
      machines = List.generate(3, (index) {
        final piece = PuzzlePiece(
          id: 'piece_$index',
          correctRow: index,
          correctCol: 0,
          correctPosition: PuzzleCoordinate(x: 100.0 * index, y: 100),
          bounds: PieceBounds(
            contentBounds: const ContentRect(
              left: 0,
              top: 0,
              right: 50,
              bottom: 50,
            ),
            paddedSize: const Size(60, 60),
            targetBounds: ContentRect(
              left: 100.0 * index,
              top: 100,
              right: 100.0 * index + 50,
              bottom: 150,
            ),
          ),
        );
        
        return PieceStateMachine(
          pieceId: 'piece_$index',
          piece: piece,
        );
      });
    });
    
    tearDown(() {
      for (final machine in machines) {
        machine.dispose();
      }
      recorder.dispose();
    });
    
    test('should execute batch transitions in parallel', () async {
      final result = await batchTransitioner.executeTransitions(
        machines,
        (pieceId) => PieceHoverEvent(pieceId: pieceId),
        parallel: true,
      );
      
      expect(result.allSuccessful, true);
      expect(result.successCount, 3);
      expect(result.failureCount, 0);
      
      // All machines should be in hovering state
      for (final machine in machines) {
        expect(machine.currentState, PieceStateType.hovering);
      }
    });
    
    test('should execute batch transitions sequentially with stagger', () async {
      final startTime = DateTime.now();
      
      final result = await batchTransitioner.executeTransitions(
        machines,
        (pieceId) => PieceHoverEvent(pieceId: pieceId),
        parallel: false,
        staggerDelay: const Duration(milliseconds: 50),
      );
      
      final endTime = DateTime.now();
      final duration = endTime.difference(startTime);
      
      expect(result.allSuccessful, true);
      // Should take at least 100ms (2 delays of 50ms)
      expect(duration.inMilliseconds, greaterThanOrEqualTo(100));
    });
    
    test('should handle composite transitions', () async {
      final composite = CompositeTransition(
        id: 'test_composite',
        sequence: [
          PieceStateType.hovering,
          PieceStateType.selected,
        ],
        durations: {
          PieceStateType.hovering: const Duration(milliseconds: 10),
          PieceStateType.selected: const Duration(milliseconds: 10),
        },
        parallel: false,
      );
      
      final result = await batchTransitioner.executeComposite(
        machines[0],
        composite,
      );
      
      expect(result, true);
      expect(machines[0].currentState, PieceStateType.selected);
    });
    
    test('should record transition analytics', () async {
      await batchTransitioner.executeTransitions(
        machines,
        (pieceId) => PieceHoverEvent(pieceId: pieceId),
      );
      
      final stats = recorder.getStatistics();
      
      expect(stats['totalTransitions'], 3);
      expect(stats['successfulTransitions'], 3);
      expect(stats['successRate'], 1.0);
    });
  });
  
  group('TransitionTestUtils', () {
    test('should create mock machine', () {
      final machine = TransitionTestUtils.createMockMachine(
        pieceId: 'mock_piece',
        initialState: PieceStateType.hovering,
      );
      
      expect(machine.pieceId, 'mock_piece');
      expect(machine.currentState, PieceStateType.hovering);
      expect(machine.debugMode, true);
      
      machine.dispose();
    });
    
    test('should create event sequence', () {
      final events = TransitionTestUtils.createEventSequence(
        'test_piece',
        [
          PieceHoverEvent,
          PieceSelectEvent,
          PieceDragStartEvent,
          PieceDragEndEvent,
        ],
      );
      
      expect(events.length, 4);
      expect(events[0], isA<PieceHoverEvent>());
      expect(events[1], isA<PieceSelectEvent>());
      expect(events[2], isA<PieceDragStartEvent>());
      expect(events[3], isA<PieceDragEndEvent>());
    });
    
    test('should verify state sequence', () async {
      final machine = TransitionTestUtils.createMockMachine();
      
      // Process some events
      await machine.processEvent(PieceHoverEvent(pieceId: 'test_piece'));
      await machine.processEvent(PieceSelectEvent(
        pieceId: 'test_piece',
        position: PuzzleCoordinate(x: 50, y: 50),
      ));
      
      // Verify sequence
      final isValid = TransitionTestUtils.verifyStateSequence(
        machine,
        [PieceStateType.idle, PieceStateType.hovering, PieceStateType.selected],
      );
      
      expect(isValid, true);
      
      machine.dispose();
    });
    
    test('should simulate drag gesture', () async {
      final machine = TransitionTestUtils.createMockMachine();
      
      await TransitionTestUtils.simulateDrag(
        machine,
        PuzzleCoordinate(x: 0, y: 0),
        PuzzleCoordinate(x: 100, y: 100),
        5,
      );
      
      // Should have gone through the drag sequence
      expect(machine.stateHistory, contains(PieceStateType.selected));
      expect(machine.stateHistory, contains(PieceStateType.dragging));
      
      machine.dispose();
    });
  });
}

/// Test ticker provider for animations
class TestVSync extends TickerProvider {
  @override
  Ticker createTicker(TickerCallback onTick) {
    return Ticker(onTick);
  }
}
