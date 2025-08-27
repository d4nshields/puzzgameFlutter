import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../domain/services/piece_state_machine.dart';
import '../domain/services/state_transitions.dart';
import '../domain/entities/puzzle_piece.dart';
import '../domain/value_objects/puzzle_coordinate.dart';
import '../debug/state_machine_visualizer.dart';

/// Example integration of state machine with workspace controller
/// 
/// This demonstrates how to wire the state machine into your existing
/// workspace controller for managing puzzle piece interactions.
class StateMachineIntegration {
  // State machines for all pieces
  final Map<String, PieceStateMachine> _stateMachines = {};
  
  // Transition system components
  late final TransitionValidator _validator;
  late final TransitionAnimator _animator;
  late final TransitionRecorder _recorder;
  late final BatchTransitioner _batchTransitioner;
  
  // Debug mode flag
  bool _debugMode = false;
  
  StateMachineIntegration({
    required TickerProvider tickerProvider,
    bool debugMode = false,
  }) : _debugMode = debugMode {
    // Initialize transition system
    _validator = TransitionValidator(debugMode: debugMode);
    _animator = TransitionAnimator(tickerProvider: tickerProvider);
    _recorder = TransitionRecorder();
    _batchTransitioner = BatchTransitioner(
      validator: _validator,
      animator: _animator,
      recorder: _recorder,
    );
  }
  
  /// Initialize state machine for a puzzle piece
  void initializePiece(PuzzlePiece piece) {
    if (_stateMachines.containsKey(piece.id)) {
      return; // Already initialized
    }
    
    final stateMachine = PieceStateMachine(
      pieceId: piece.id,
      piece: piece,
      debugMode: _debugMode,
    );
    
    // Set up animation callback
    stateMachine.onAnimationRequired = _handleAnimationRequest;
    
    // Subscribe to state changes
    stateMachine.stateChangeStream.listen((state) {
      _handleStateChange(piece.id, state);
    });
    
    _stateMachines[piece.id] = stateMachine;
  }
  
  /// Handle user hovering over a piece
  Future<void> handlePieceHover(String pieceId) async {
    final machine = _stateMachines[pieceId];
    if (machine == null) return;
    
    await machine.processEvent(PieceHoverEvent(pieceId: pieceId));
  }
  
  /// Handle user unhovering a piece
  Future<void> handlePieceUnhover(String pieceId) async {
    final machine = _stateMachines[pieceId];
    if (machine == null) return;
    
    await machine.processEvent(PieceUnhoverEvent(pieceId: pieceId));
  }
  
  /// Handle piece selection
  Future<void> handlePieceSelect(String pieceId, PuzzleCoordinate position) async {
    final machine = _stateMachines[pieceId];
    if (machine == null) return;
    
    // Validate the transition
    final event = PieceSelectEvent(pieceId: pieceId, position: position);
    final validation = _validator.validate(machine, event);
    
    if (!validation.isValid) {
      debugPrint('Selection blocked: ${validation.errorMessage}');
      return;
    }
    
    await machine.processEvent(event);
  }
  
  /// Handle drag start
  Future<void> handleDragStart(String pieceId, PuzzleCoordinate startPosition) async {
    final machine = _stateMachines[pieceId];
    if (machine == null) return;
    
    await machine.processEvent(PieceDragStartEvent(
      pieceId: pieceId,
      startPosition: startPosition,
    ));
  }
  
  /// Handle drag update
  Future<void> handleDragUpdate(
    String pieceId,
    PuzzleCoordinate position,
    PuzzleCoordinate delta,
    double velocity,
  ) async {
    final machine = _stateMachines[pieceId];
    if (machine == null) return;
    
    await machine.processEvent(PieceDragUpdateEvent(
      pieceId: pieceId,
      position: position,
      delta: delta,
      velocity: velocity,
    ));
    
    // Check for magnetic field influence
    _checkMagneticInfluence(machine, position);
  }
  
  /// Handle drag end
  Future<void> handleDragEnd(
    String pieceId,
    PuzzleCoordinate endPosition,
    double velocity,
  ) async {
    final machine = _stateMachines[pieceId];
    if (machine == null) return;
    
    final piece = machine.piece;
    
    // Check if piece should snap
    if (piece.canSnapToPosition(snapDistance: 50.0) && velocity < 500.0) {
      await _executeSnap(machine, piece.correctPosition);
    } else {
      await machine.processEvent(PieceDragEndEvent(
        pieceId: pieceId,
        endPosition: endPosition,
        velocity: velocity,
      ));
    }
  }
  
  /// Execute snap animation
  Future<void> _executeSnap(
    PieceStateMachine machine,
    PuzzleCoordinate targetPosition,
  ) async {
    // Start snap animation
    await machine.processEvent(PieceSnapEvent(
      pieceId: machine.pieceId,
      targetPosition: targetPosition,
      duration: const Duration(milliseconds: 200),
    ));
    
    // Animate the snap
    await _animator.animateSpring(
      transitionId: '${machine.pieceId}_snap',
      target: 1.0,
      stiffness: 300.0,
      damping: 20.0,
      onComplete: () async {
        // Place the piece
        await machine.processEvent(PiecePlaceEvent(
          pieceId: machine.pieceId,
          isCorrect: true,
        ));
        
        // Trigger celebration
        await machine.processEvent(PieceCelebrateEvent(
          pieceId: machine.pieceId,
          celebrationType: 'placement',
        ));
        
        // Lock after celebration
        Future.delayed(const Duration(seconds: 2), () async {
          await machine.processEvent(PieceLockEvent(
            pieceId: machine.pieceId,
          ));
        });
      },
    );
  }
  
  /// Check for magnetic field influence
  void _checkMagneticInfluence(
    PieceStateMachine machine,
    PuzzleCoordinate position,
  ) {
    final piece = machine.piece;
    final distance = position.distanceTo(piece.correctPosition);
    
    if (distance < 150.0) {
      final strength = 1.0 - (distance / 150.0);
      if (strength > 0.3 && !machine.isInState(PieceStateType.magnetized)) {
        machine.processEvent(PieceMagnetizeEvent(
          pieceId: machine.pieceId,
          magnetPosition: piece.correctPosition,
          strength: strength,
        ));
      }
    } else if (machine.isInState(PieceStateType.magnetized)) {
      // Exit magnetization
      machine.processEvent(PieceDragUpdateEvent(
        pieceId: machine.pieceId,
        position: position,
        delta: PuzzleCoordinate.zero,
        velocity: 0,
      ));
    }
  }
  
  /// Handle animation requests from state machine
  void _handleAnimationRequest(
    PieceStateType from,
    PieceStateType to,
    Duration duration,
  ) {
    debugPrint('Animation requested: $from -> $to (${duration.inMilliseconds}ms)');
    
    // You can trigger specific animations based on the transition
    switch (to) {
      case PieceStateType.selected:
        // Trigger selection animation
        break;
      case PieceStateType.snapping:
        // Trigger snap animation
        break;
      case PieceStateType.celebrating:
        // Trigger celebration animation
        break;
      case PieceStateType.locked:
        // Trigger lock animation
        break;
      default:
        break;
    }
  }
  
  /// Handle state changes
  void _handleStateChange(String pieceId, PieceStateType newState) {
    debugPrint('Piece $pieceId changed to state: $newState');
    
    // Record the transition
    _recorder.record(TransitionRecord(
      timestamp: DateTime.now(),
      pieceId: pieceId,
      fromState: _stateMachines[pieceId]?.stateHistory.lastOrNull ?? PieceStateType.idle,
      toState: newState,
      duration: Duration.zero,
      successful: true,
    ));
    
    // You can trigger UI updates or other actions based on state changes
    switch (newState) {
      case PieceStateType.locked:
        // Check for puzzle completion
        _checkPuzzleCompletion();
        break;
      case PieceStateType.invalid:
        // Show error feedback
        break;
      default:
        break;
    }
  }
  
  /// Check if puzzle is complete
  void _checkPuzzleCompletion() {
    final allLocked = _stateMachines.values.every(
      (machine) => machine.isInState(PieceStateType.locked),
    );
    
    if (allLocked) {
      debugPrint('Puzzle completed!');
      _triggerCompletionCelebration();
    }
  }
  
  /// Trigger completion celebration for all pieces
  Future<void> _triggerCompletionCelebration() async {
    await _batchTransitioner.executeTransitions(
      _stateMachines.values.toList(),
      (pieceId) => PieceCelebrateEvent(
        pieceId: pieceId,
        celebrationType: 'completion',
      ),
      parallel: false,
      staggerDelay: const Duration(milliseconds: 50),
    );
  }
  
  /// Reset a piece to initial state
  Future<void> resetPiece(String pieceId) async {
    final machine = _stateMachines[pieceId];
    if (machine == null) return;
    
    await machine.processEvent(PieceReturnEvent(
      pieceId: pieceId,
      targetPosition: null, // Return to tray
    ));
  }
  
  /// Undo last action on a piece
  bool undoPieceAction(String pieceId) {
    final machine = _stateMachines[pieceId];
    if (machine == null) return false;
    
    return machine.undo();
  }
  
  /// Get statistics
  Map<String, dynamic> getStatistics() {
    return _recorder.getStatistics();
  }
  
  /// Get state machine for debugging
  PieceStateMachine? getStateMachine(String pieceId) {
    return _stateMachines[pieceId];
  }
  
  /// Build debug visualization widget
  Widget buildDebugVisualization() {
    return StateMachineDebugPanel(
      stateMachines: _stateMachines,
    );
  }
  
  /// Save state for persistence
  Map<String, dynamic> saveState() {
    final state = <String, dynamic>{};
    
    for (final entry in _stateMachines.entries) {
      state[entry.key] = entry.value.exportState();
    }
    
    return {
      'stateMachines': state,
      'statistics': _recorder.exportJson(),
    };
  }
  
  /// Restore state from persistence
  void restoreState(Map<String, dynamic> savedState) {
    final machines = savedState['stateMachines'] as Map<String, dynamic>?;
    
    if (machines != null) {
      for (final entry in machines.entries) {
        final machine = _stateMachines[entry.key];
        if (machine != null) {
          machine.importState(entry.value as Map<String, dynamic>);
        }
      }
    }
  }
  
  /// Dispose resources
  void dispose() {
    for (final machine in _stateMachines.values) {
      machine.dispose();
    }
    _stateMachines.clear();
    _animator.dispose();
    _recorder.dispose();
  }
}

/// Example usage in a widget
class StateMachineExampleWidget extends StatefulWidget {
  final List<PuzzlePiece> pieces;
  
  const StateMachineExampleWidget({
    Key? key,
    required this.pieces,
  }) : super(key: key);
  
  @override
  State<StateMachineExampleWidget> createState() => _StateMachineExampleWidgetState();
}

class _StateMachineExampleWidgetState extends State<StateMachineExampleWidget>
    with TickerProviderStateMixin {
  late StateMachineIntegration _integration;
  
  @override
  void initState() {
    super.initState();
    
    // Initialize integration
    _integration = StateMachineIntegration(
      tickerProvider: this,
      debugMode: true,
    );
    
    // Initialize state machines for all pieces
    for (final piece in widget.pieces) {
      _integration.initializePiece(piece);
    }
  }
  
  @override
  void dispose() {
    _integration.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Your game UI here
        GestureDetector(
          onPanStart: (details) {
            // Find piece at position and start drag
            final pieceId = _findPieceAt(details.localPosition);
            if (pieceId != null) {
              _integration.handlePieceSelect(
                pieceId,
                PuzzleCoordinate(
                  x: details.localPosition.dx,
                  y: details.localPosition.dy,
                ),
              );
              _integration.handleDragStart(
                pieceId,
                PuzzleCoordinate(
                  x: details.localPosition.dx,
                  y: details.localPosition.dy,
                ),
              );
            }
          },
          onPanUpdate: (details) {
            // Update drag position
            final pieceId = _selectedPieceId;
            if (pieceId != null) {
              _integration.handleDragUpdate(
                pieceId,
                PuzzleCoordinate(
                  x: details.localPosition.dx,
                  y: details.localPosition.dy,
                ),
                PuzzleCoordinate(
                  x: details.delta.dx,
                  y: details.delta.dy,
                ),
                details.delta.distance * 10, // Approximate velocity
              );
            }
          },
          onPanEnd: (details) {
            // End drag
            final pieceId = _selectedPieceId;
            if (pieceId != null) {
              _integration.handleDragEnd(
                pieceId,
                _lastPosition,
                100.0, // Default end velocity
              );
            }
          },
          child: Container(
            color: Colors.grey[900],
            child: const Center(
              child: Text(
                'Puzzle Game Area',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ),
        
        // Debug visualization overlay
        if (_debugMode)
          _integration.buildDebugVisualization(),
      ],
    );
  }
  
  String? _selectedPieceId;
  PuzzleCoordinate _lastPosition = PuzzleCoordinate.zero;
  final bool _debugMode = true;
  
  String? _findPieceAt(Offset position) {
    // Implementation to find piece at position
    // This would check bounds of all pieces
    return widget.pieces.firstOrNull?.id;
  }
}
