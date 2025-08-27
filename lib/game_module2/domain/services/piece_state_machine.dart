import 'dart:async';
import 'package:flutter/foundation.dart';
import '../entities/puzzle_piece.dart';
import '../value_objects/puzzle_coordinate.dart';

/// Represents all possible states a puzzle piece can be in
enum PieceStateType {
  // Base states
  idle,         // Piece is at rest, not interacted with
  hovering,     // Mouse/finger is over the piece
  selected,     // Piece has been selected but not moved
  dragging,     // Piece is being actively dragged
  
  // Transition states
  snapping,     // Piece is animating to snap position
  magnetized,   // Piece is being attracted by magnetic field
  returning,    // Piece is returning to tray or previous position
  
  // Final states
  placed,       // Piece is correctly placed but not locked
  locked,       // Piece is locked in correct position
  
  // Special states
  celebrating,  // Piece is playing celebration animation
  invalid,      // Piece is in an invalid state/position
}

/// Represents parallel state regions for orthogonal state management
enum StateRegion {
  interaction,  // User interaction states
  validation,   // Position validation states
  animation,    // Animation states
  physics,      // Physics simulation states
}

/// Base class for all state machine events
abstract class PieceEvent {
  final DateTime timestamp;
  final String pieceId;
  final Map<String, dynamic> metadata;

  PieceEvent({
    required this.pieceId,
    DateTime? timestamp,
    Map<String, dynamic>? metadata,
  }) : 
    timestamp = timestamp ?? DateTime.now(),
    metadata = metadata ?? {};

  Map<String, dynamic> toJson() => {
    'type': runtimeType.toString(),
    'timestamp': timestamp.toIso8601String(),
    'pieceId': pieceId,
    'metadata': metadata,
  };
}

// Event definitions
class PieceHoverEvent extends PieceEvent {
  PieceHoverEvent({required super.pieceId, super.metadata});
}

class PieceUnhoverEvent extends PieceEvent {
  PieceUnhoverEvent({required super.pieceId, super.metadata});
}

class PieceSelectEvent extends PieceEvent {
  final PuzzleCoordinate position;
  PieceSelectEvent({required super.pieceId, required this.position, super.metadata});
}

class PieceDeselectEvent extends PieceEvent {
  PieceDeselectEvent({required super.pieceId, super.metadata});
}

class PieceDragStartEvent extends PieceEvent {
  final PuzzleCoordinate startPosition;
  PieceDragStartEvent({required super.pieceId, required this.startPosition, super.metadata});
}

class PieceDragUpdateEvent extends PieceEvent {
  final PuzzleCoordinate position;
  final PuzzleCoordinate delta;
  final double velocity;
  
  PieceDragUpdateEvent({
    required super.pieceId,
    required this.position,
    required this.delta,
    required this.velocity,
    super.metadata,
  });
}

class PieceDragEndEvent extends PieceEvent {
  final PuzzleCoordinate endPosition;
  final double velocity;
  
  PieceDragEndEvent({
    required super.pieceId,
    required this.endPosition,
    required this.velocity,
    super.metadata,
  });
}

class PieceSnapEvent extends PieceEvent {
  final PuzzleCoordinate targetPosition;
  final Duration duration;
  
  PieceSnapEvent({
    required super.pieceId,
    required this.targetPosition,
    required this.duration,
    super.metadata,
  });
}

class PieceMagnetizeEvent extends PieceEvent {
  final PuzzleCoordinate magnetPosition;
  final double strength;
  
  PieceMagnetizeEvent({
    required super.pieceId,
    required this.magnetPosition,
    required this.strength,
    super.metadata,
  });
}

class PiecePlaceEvent extends PieceEvent {
  final bool isCorrect;
  PiecePlaceEvent({required super.pieceId, required this.isCorrect, super.metadata});
}

class PieceLockEvent extends PieceEvent {
  PieceLockEvent({required super.pieceId, super.metadata});
}

class PieceCelebrateEvent extends PieceEvent {
  final String celebrationType;
  PieceCelebrateEvent({required super.pieceId, required this.celebrationType, super.metadata});
}

class PieceInvalidateEvent extends PieceEvent {
  final String reason;
  PieceInvalidateEvent({required super.pieceId, required this.reason, super.metadata});
}

class PieceReturnEvent extends PieceEvent {
  final PuzzleCoordinate? targetPosition;
  PieceReturnEvent({required super.pieceId, this.targetPosition, super.metadata});
}

/// Guard condition for state transitions
typedef GuardCondition = bool Function(PieceStateMachine machine, PieceEvent event);

/// Action to perform during state transitions
typedef TransitionAction = void Function(PieceStateMachine machine, PieceEvent event);

/// Represents a state transition
class StateTransition {
  final PieceStateType from;
  final PieceStateType to;
  final Type eventType;
  final GuardCondition? guard;
  final TransitionAction? onExit;
  final TransitionAction? onEnter;
  final Duration? animationDuration;
  
  StateTransition({
    required this.from,
    required this.to,
    required this.eventType,
    this.guard,
    this.onExit,
    this.onEnter,
    this.animationDuration,
  });
  
  bool canTransition(PieceStateMachine machine, PieceEvent event) {
    if (event.runtimeType != eventType) return false;
    return guard?.call(machine, event) ?? true;
  }
}

/// Hierarchical state definition
class HierarchicalState {
  final PieceStateType type;
  final PieceStateType? parent;
  final Set<PieceStateType> children;
  final StateRegion region;
  final TransitionAction? onEnter;
  final TransitionAction? onExit;
  final TransitionAction? onUpdate;
  
  HierarchicalState({
    required this.type,
    this.parent,
    Set<PieceStateType>? children,
    required this.region,
    this.onEnter,
    this.onExit,
    this.onUpdate,
  }) : children = children ?? {};
}

/// State machine context for maintaining state
class StateMachineContext {
  PieceStateType currentState;
  Map<StateRegion, PieceStateType> parallelStates;
  final List<PieceEvent> eventHistory;
  final List<PieceStateType> stateHistory;
  Map<String, dynamic> metadata;
  DateTime lastTransition;
  
  StateMachineContext({
    required this.currentState,
    Map<StateRegion, PieceStateType>? parallelStates,
    List<PieceEvent>? eventHistory,
    List<PieceStateType>? stateHistory,
    Map<String, dynamic>? metadata,
    DateTime? lastTransition,
  }) : 
    parallelStates = parallelStates ?? {},
    eventHistory = eventHistory ?? [],
    stateHistory = stateHistory ?? [],
    metadata = metadata ?? {},
    lastTransition = lastTransition ?? DateTime.now();
    
  StateMachineContext copy() {
    return StateMachineContext(
      currentState: currentState,
      parallelStates: Map.from(parallelStates),
      eventHistory: List.from(eventHistory),
      stateHistory: List.from(stateHistory),
      metadata: Map.from(metadata),
      lastTransition: lastTransition,
    );
  }
}

/// Main state machine implementation
class PieceStateMachine {
  final String pieceId;
  final PuzzlePiece piece;
  
  late StateMachineContext _context;
  final List<StateMachineContext> _contextHistory = [];
  final int maxHistorySize;
  
  // State definitions
  final Map<PieceStateType, HierarchicalState> _states = {};
  final List<StateTransition> _transitions = [];
  
  // Event handling
  final StreamController<PieceEvent> _eventController = StreamController<PieceEvent>.broadcast();
  final StreamController<PieceStateType> _stateChangeController = StreamController<PieceStateType>.broadcast();
  
  // Debug mode
  bool debugMode = false;
  final List<String> _debugLog = [];
  
  // Animation controller callback
  Function(PieceStateType from, PieceStateType to, Duration duration)? onAnimationRequired;
  
  PieceStateMachine({
    required this.pieceId,
    required this.piece,
    PieceStateType initialState = PieceStateType.idle,
    this.maxHistorySize = 100,
    this.debugMode = false,
  }) {
    _context = StateMachineContext(
      currentState: initialState,
      parallelStates: {
        StateRegion.interaction: PieceStateType.idle,
        StateRegion.validation: PieceStateType.idle,
        StateRegion.animation: PieceStateType.idle,
        StateRegion.physics: PieceStateType.idle,
      },
    );
    
    // Add initial state to history
    _context.stateHistory.add(initialState);
    
    _initializeStates();
    _initializeTransitions();
  }
  
  /// Initialize hierarchical state definitions
  void _initializeStates() {
    // Base interaction states
    _states[PieceStateType.idle] = HierarchicalState(
      type: PieceStateType.idle,
      region: StateRegion.interaction,
      onEnter: (machine, event) => _logDebug('Entering idle state'),
    );
    
    _states[PieceStateType.hovering] = HierarchicalState(
      type: PieceStateType.hovering,
      parent: PieceStateType.idle,
      region: StateRegion.interaction,
      onEnter: (machine, event) {
        _logDebug('Entering hovering state');
        machine._context.metadata['hoverStartTime'] = DateTime.now();
      },
      onExit: (machine, event) {
        final duration = DateTime.now().difference(
          machine._context.metadata['hoverStartTime'] as DateTime
        );
        _logDebug('Exiting hovering state after ${duration.inMilliseconds}ms');
      },
    );
    
    _states[PieceStateType.selected] = HierarchicalState(
      type: PieceStateType.selected,
      region: StateRegion.interaction,
      onEnter: (machine, event) {
        _logDebug('Piece selected');
        piece.setSelected(true);
      },
      onExit: (machine, event) {
        piece.setSelected(false);
      },
    );
    
    _states[PieceStateType.dragging] = HierarchicalState(
      type: PieceStateType.dragging,
      parent: PieceStateType.selected,
      region: StateRegion.interaction,
      onEnter: (machine, event) {
        _logDebug('Started dragging');
        machine._context.metadata['dragStartPosition'] = piece.currentPosition;
        machine._context.metadata['dragStartTime'] = DateTime.now();
      },
      onUpdate: (machine, event) {
        if (event is PieceDragUpdateEvent) {
          piece.moveTo(event.position);
          // Temporarily disabled automatic magnetization as it interferes with state transitions
          // _checkMagneticField(event.position);
        }
      },
      onExit: (machine, event) {
        final duration = DateTime.now().difference(
          machine._context.metadata['dragStartTime'] as DateTime
        );
        _logDebug('Stopped dragging after ${duration.inMilliseconds}ms');
      },
    );
    
    // Transition states
    _states[PieceStateType.snapping] = HierarchicalState(
      type: PieceStateType.snapping,
      region: StateRegion.animation,
      onEnter: (machine, event) {
        if (event is PieceSnapEvent) {
          _logDebug('Snapping to position: ${event.targetPosition}');
          onAnimationRequired?.call(
            machine._context.currentState,
            PieceStateType.snapping,
            event.duration,
          );
        }
      },
    );
    
    _states[PieceStateType.magnetized] = HierarchicalState(
      type: PieceStateType.magnetized,
      region: StateRegion.physics,
      onEnter: (machine, event) {
        if (event is PieceMagnetizeEvent) {
          _logDebug('Magnetized with strength: ${event.strength}');
          machine._context.metadata['magnetStrength'] = event.strength;
        }
      },
    );
    
    _states[PieceStateType.returning] = HierarchicalState(
      type: PieceStateType.returning,
      region: StateRegion.animation,
      onEnter: (machine, event) {
        _logDebug('Returning piece to tray/position');
        final duration = const Duration(milliseconds: 300);
        onAnimationRequired?.call(
          machine._context.currentState,
          PieceStateType.returning,
          duration,
        );
      },
    );
    
    // Final states
    _states[PieceStateType.placed] = HierarchicalState(
      type: PieceStateType.placed,
      region: StateRegion.validation,
      onEnter: (machine, event) {
        _logDebug('Piece placed correctly');
        piece.placeCorrectly();
      },
    );
    
    _states[PieceStateType.locked] = HierarchicalState(
      type: PieceStateType.locked,
      parent: PieceStateType.placed,
      region: StateRegion.validation,
      onEnter: (machine, event) {
        _logDebug('Piece locked in position');
        machine._context.metadata['lockedTime'] = DateTime.now();
      },
    );
    
    // Special states
    _states[PieceStateType.celebrating] = HierarchicalState(
      type: PieceStateType.celebrating,
      region: StateRegion.animation,
      onEnter: (machine, event) {
        if (event is PieceCelebrateEvent) {
          _logDebug('Celebrating: ${event.celebrationType}');
          final duration = const Duration(seconds: 2);
          onAnimationRequired?.call(
            machine._context.currentState,
            PieceStateType.celebrating,
            duration,
          );
        }
      },
    );
    
    _states[PieceStateType.invalid] = HierarchicalState(
      type: PieceStateType.invalid,
      region: StateRegion.validation,
      onEnter: (machine, event) {
        if (event is PieceInvalidateEvent) {
          _logDebug('Invalid state: ${event.reason}');
          machine._context.metadata['invalidReason'] = event.reason;
        }
      },
    );
  }
  
  /// Initialize state transitions with guards and actions
  void _initializeTransitions() {
    // Idle transitions
    _transitions.add(StateTransition(
      from: PieceStateType.idle,
      to: PieceStateType.hovering,
      eventType: PieceHoverEvent,
      guard: (machine, event) => !machine.piece.isPlaced && !machine.piece.isLocked && !machine.isInState(PieceStateType.locked),
    ));
    
    _transitions.add(StateTransition(
      from: PieceStateType.hovering,
      to: PieceStateType.idle,
      eventType: PieceUnhoverEvent,
    ));
    
    // Selection transitions
    _transitions.add(StateTransition(
      from: PieceStateType.hovering,
      to: PieceStateType.selected,
      eventType: PieceSelectEvent,
      guard: (machine, event) => !piece.isPlaced && !machine.isInState(PieceStateType.locked),
      animationDuration: const Duration(milliseconds: 100),
    ));
    
    _transitions.add(StateTransition(
      from: PieceStateType.idle,
      to: PieceStateType.selected,
      eventType: PieceSelectEvent,
      guard: (machine, event) => !piece.isPlaced && !machine.isInState(PieceStateType.locked),
      animationDuration: const Duration(milliseconds: 100),
    ));
    
    _transitions.add(StateTransition(
      from: PieceStateType.selected,
      to: PieceStateType.idle,
      eventType: PieceDeselectEvent,
    ));
    
    // Dragging transitions
    _transitions.add(StateTransition(
      from: PieceStateType.selected,
      to: PieceStateType.dragging,
      eventType: PieceDragStartEvent,
      guard: (machine, event) => !machine.piece.isLocked,
    ));
    
    // Check for snapping first (without modifying position in guard)
    _transitions.add(StateTransition(
      from: PieceStateType.dragging,
      to: PieceStateType.snapping,
      eventType: PieceDragEndEvent,
      guard: (machine, event) {
        final dragEnd = event as PieceDragEndEvent;
        // Calculate distance without modifying position
        final distance = dragEnd.endPosition.distanceTo(machine.piece.correctPosition);
        machine._logDebug('Checking snap: endPos=${dragEnd.endPosition}, correctPos=${machine.piece.correctPosition}, distance=$distance');
        return distance <= 50.0;
      },
      onEnter: (machine, event) {
        final dragEnd = event as PieceDragEndEvent;
        machine.piece.moveTo(dragEnd.endPosition);
        machine._logDebug('Snapping: moved to ${dragEnd.endPosition}');
      },
      animationDuration: const Duration(milliseconds: 200),
    ));
    
    // Default drag end to idle (no guard - this is the fallback)
    _transitions.add(StateTransition(
      from: PieceStateType.dragging,
      to: PieceStateType.idle,
      eventType: PieceDragEndEvent,
      // No guard - this is the default if snapping guard fails
      onEnter: (machine, event) {
        final dragEnd = event as PieceDragEndEvent;
        machine.piece.moveTo(dragEnd.endPosition);
        final distance = dragEnd.endPosition.distanceTo(machine.piece.correctPosition);
        machine._logDebug('Idle (default): moved to ${dragEnd.endPosition}, distance was $distance');
      },
    ));
    
    _transitions.add(StateTransition(
      from: PieceStateType.snapping,
      to: PieceStateType.placed,
      eventType: PiecePlaceEvent,
      guard: (machine, event) {
        final placeEvent = event as PiecePlaceEvent;
        return placeEvent.isCorrect;
      },
    ));
    
    // Magnetization transitions
    _transitions.add(StateTransition(
      from: PieceStateType.dragging,
      to: PieceStateType.magnetized,
      eventType: PieceMagnetizeEvent,
      guard: (machine, event) {
        final magnetEvent = event as PieceMagnetizeEvent;
        return magnetEvent.strength > 0.3;
      },
    ));
    
    _transitions.add(StateTransition(
      from: PieceStateType.magnetized,
      to: PieceStateType.dragging,
      eventType: PieceDragUpdateEvent,
      guard: (machine, event) {
        final strength = machine._context.metadata['magnetStrength'] as double? ?? 0;
        return strength < 0.3;
      },
    ));
    
    // Add transitions from magnetized state for drag end
    _transitions.add(StateTransition(
      from: PieceStateType.magnetized,
      to: PieceStateType.snapping,
      eventType: PieceDragEndEvent,
      guard: (machine, event) {
        final dragEnd = event as PieceDragEndEvent;
        final distance = dragEnd.endPosition.distanceTo(machine.piece.correctPosition);
        machine._logDebug('Magnetized->Snapping: distance=$distance');
        return distance <= 50.0;
      },
      onEnter: (machine, event) {
        final dragEnd = event as PieceDragEndEvent;
        machine.piece.moveTo(dragEnd.endPosition);
      },
      animationDuration: const Duration(milliseconds: 200),
    ));
    
    _transitions.add(StateTransition(
      from: PieceStateType.magnetized,
      to: PieceStateType.idle,
      eventType: PieceDragEndEvent,
      // No guard - fallback
      onEnter: (machine, event) {
        final dragEnd = event as PieceDragEndEvent;
        machine.piece.moveTo(dragEnd.endPosition);
        machine._logDebug('Magnetized->Idle: fallback transition');
      },
    ));
    
    // Placement transitions
    _transitions.add(StateTransition(
      from: PieceStateType.selected,
      to: PieceStateType.placed,
      eventType: PiecePlaceEvent,
      guard: (machine, event) {
        final placeEvent = event as PiecePlaceEvent;
        return placeEvent.isCorrect && machine.piece.isAtCorrectPosition();
      },
    ));
    
    _transitions.add(StateTransition(
      from: PieceStateType.placed,
      to: PieceStateType.locked,
      eventType: PieceLockEvent,
      animationDuration: const Duration(milliseconds: 500),
    ));
    
    _transitions.add(StateTransition(
      from: PieceStateType.placed,
      to: PieceStateType.celebrating,
      eventType: PieceCelebrateEvent,
    ));
    
    _transitions.add(StateTransition(
      from: PieceStateType.celebrating,
      to: PieceStateType.locked,
      eventType: PieceLockEvent,
      animationDuration: const Duration(milliseconds: 300),
    ));
    
    // Return transitions
    _transitions.add(StateTransition(
      from: PieceStateType.dragging,
      to: PieceStateType.returning,
      eventType: PieceReturnEvent,
    ));
    
    _transitions.add(StateTransition(
      from: PieceStateType.invalid,
      to: PieceStateType.returning,
      eventType: PieceReturnEvent,
    ));
    
    _transitions.add(StateTransition(
      from: PieceStateType.returning,
      to: PieceStateType.idle,
      eventType: PieceDragEndEvent,
    ));
    
    // Invalid state transitions
    _transitions.add(StateTransition(
      from: PieceStateType.dragging,
      to: PieceStateType.invalid,
      eventType: PieceInvalidateEvent,
    ));
    
    _transitions.add(StateTransition(
      from: PieceStateType.selected,
      to: PieceStateType.invalid,
      eventType: PieceInvalidateEvent,
    ));
  }
  
  /// Process an event through the state machine
  Future<bool> processEvent(PieceEvent event) async {
    try {
      _logDebug('Processing event: ${event.runtimeType} for state: ${_context.currentState}');
      
      // Record event in history
      _context.eventHistory.add(event);
      if (_context.eventHistory.length > maxHistorySize) {
        _context.eventHistory.removeAt(0);
      }
      
      // Check if we can handle this event in the current state without transition
      final currentStateObj = _states[_context.currentState];
      if (currentStateObj?.onUpdate != null) {
        // Try to handle the event in the current state
        if (event is PieceDragUpdateEvent && _context.currentState == PieceStateType.dragging) {
          currentStateObj!.onUpdate!(this, event);
          _eventController.add(event);
          return true;
        }
      }
      
      // Find valid transition
      final transition = _findTransition(event);
      if (transition == null) {
        _logDebug('No valid transition found for event: ${event.runtimeType}');
        return false;
      }
      
      // Save state for potential rollback
      _saveContextSnapshot();
      
      // Execute transition
      await _executeTransition(transition, event);
      
      // Notify listeners
      _eventController.add(event);
      _stateChangeController.add(_context.currentState);
      
      return true;
    } catch (e, stack) {
      _logDebug('Error processing event: $e\n$stack');
      rollback();
      return false;
    }
  }
  
  /// Find a valid transition for the given event
  StateTransition? _findTransition(PieceEvent event) {
    // Block all transitions from locked state except unlock events
    if (_context.currentState == PieceStateType.locked) {
      _logDebug('Blocking transition from locked state for event: ${event.runtimeType}');
      return null;
    }
    
    // Find all matching transitions
    final matchingTransitions = _transitions.where(
      (transition) => 
        transition.from == _context.currentState &&
        transition.eventType == event.runtimeType
    ).toList();
    
    _logDebug('Found ${matchingTransitions.length} potential transitions for ${event.runtimeType} from ${_context.currentState}');
    
    // Check guards in order
    for (final transition in matchingTransitions) {
      if (transition.canTransition(this, event)) {
        _logDebug('Transition found: ${transition.from} -> ${transition.to}');
        return transition;
      } else {
        _logDebug('Guard failed for transition: ${transition.from} -> ${transition.to}');
      }
    }
    
    _logDebug('No valid transition found');
    return null;
  }
  
  /// Execute a state transition
  Future<void> _executeTransition(StateTransition transition, PieceEvent event) async {
    final fromState = _states[transition.from];
    final toState = _states[transition.to];
    
    _logDebug('Transitioning from ${transition.from} to ${transition.to}');
    
    // Exit current state
    fromState?.onExit?.call(this, event);
    transition.onExit?.call(this, event);
    
    // Update state history (record all state transitions)
    _context.stateHistory.add(_context.currentState);
    if (_context.stateHistory.length > maxHistorySize) {
      _context.stateHistory.removeAt(0);
    }
    
    _context.currentState = transition.to;
    _context.lastTransition = DateTime.now();
    
    // Update parallel states
    if (toState != null) {
      _context.parallelStates[toState.region] = transition.to;
    }
    
    // Enter new state
    transition.onEnter?.call(this, event);
    toState?.onEnter?.call(this, event);
    
    // Handle animation if required
    if (transition.animationDuration != null && onAnimationRequired != null) {
      onAnimationRequired!(transition.from, transition.to, transition.animationDuration!);
    }
    
    // Handle update action if present
    toState?.onUpdate?.call(this, event);
  }
  
  /// Save current context for undo functionality
  void _saveContextSnapshot() {
    _contextHistory.add(_context.copy());
    if (_contextHistory.length > maxHistorySize) {
      _contextHistory.removeAt(0);
    }
  }
  
  /// Rollback to previous state
  bool rollback() {
    if (_contextHistory.isEmpty) {
      _logDebug('No history available for rollback');
      return false;
    }
    
    final previousContext = _contextHistory.removeLast();
    _context = previousContext;
    
    _logDebug('Rolled back to state: ${_context.currentState}');
    _stateChangeController.add(_context.currentState);
    
    return true;
  }
  
  /// Undo last n state changes
  bool undo({int steps = 1}) {
    int undone = 0;
    for (int i = 0; i < steps && _contextHistory.isNotEmpty; i++) {
      if (rollback()) {
        undone++;
      }
    }
    
    _logDebug('Undone $undone state changes');
    return undone > 0;
  }
  
  /// Get current state
  PieceStateType get currentState => _context.currentState;
  
  /// Get parallel states
  Map<StateRegion, PieceStateType> get parallelStates => 
    Map.unmodifiable(_context.parallelStates);
  
  /// Get state in specific region
  PieceStateType? getStateInRegion(StateRegion region) =>
    _context.parallelStates[region];
  
  /// Check if in specific state
  bool isInState(PieceStateType state) => _context.currentState == state;
  
  /// Check if state is active in any region
  bool isStateActive(PieceStateType state) {
    if (_context.currentState == state) return true;
    return _context.parallelStates.values.contains(state);
  }
  
  /// Get event history
  List<PieceEvent> get eventHistory => List.unmodifiable(_context.eventHistory);
  
  /// Get state history
  List<PieceStateType> get stateHistory => List.unmodifiable(_context.stateHistory);
  
  /// Get metadata
  Map<String, dynamic> get metadata => Map.unmodifiable(_context.metadata);
  
  /// Set metadata value
  void setMetadata(String key, dynamic value) {
    _context.metadata[key] = value;
  }
  
  /// Get time in current state
  Duration get timeInCurrentState => 
    DateTime.now().difference(_context.lastTransition);
  
  /// Stream of events
  Stream<PieceEvent> get eventStream => _eventController.stream;
  
  /// Stream of state changes
  Stream<PieceStateType> get stateChangeStream => _stateChangeController.stream;
  
  /// Log debug message
  void _logDebug(String message) {
    if (debugMode) {
      final timestamp = DateTime.now().toIso8601String();
      final logMessage = '[$timestamp] [Piece:$pieceId] $message';
      _debugLog.add(logMessage);
      debugPrint(logMessage);
    }
  }
  
  /// Get debug log
  List<String> get debugLog => List.unmodifiable(_debugLog);
  
  /// Clear debug log
  void clearDebugLog() => _debugLog.clear();
  
  /// Export state for persistence
  Map<String, dynamic> exportState() {
    return {
      'pieceId': pieceId,
      'currentState': _context.currentState.toString(),
      'parallelStates': _context.parallelStates.map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      ),
      'metadata': _context.metadata,
      'lastTransition': _context.lastTransition.toIso8601String(),
      'eventHistory': _context.eventHistory.map((e) => e.toJson()).toList(),
      'stateHistory': _context.stateHistory.map((s) => s.toString()).toList(),
    };
  }
  
  /// Import state from persistence
  void importState(Map<String, dynamic> data) {
    try {
      _context = StateMachineContext(
        currentState: PieceStateType.values.firstWhere(
          (s) => s.toString() == data['currentState'],
        ),
        parallelStates: (data['parallelStates'] as Map<String, dynamic>).map(
          (key, value) => MapEntry(
            StateRegion.values.firstWhere((r) => r.toString() == key),
            PieceStateType.values.firstWhere((s) => s.toString() == value),
          ),
        ),
        metadata: data['metadata'] ?? {},
        lastTransition: DateTime.parse(data['lastTransition']),
        eventHistory: [], // Events are not fully reconstructed for simplicity
        stateHistory: (data['stateHistory'] as List).map(
          (s) => PieceStateType.values.firstWhere((state) => state.toString() == s),
        ).toList(),
      );
      
      _logDebug('State imported successfully');
    } catch (e) {
      _logDebug('Error importing state: $e');
    }
  }
  
  /// Get visualization data for debug UI
  Map<String, dynamic> getVisualizationData() {
    return {
      'currentState': currentState.toString(),
      'parallelStates': parallelStates.map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      ),
      'availableTransitions': _transitions
        .where((t) => t.from == currentState)
        .map((t) => {
          'to': t.to.toString(),
          'event': t.eventType.toString(),
          'hasGuard': t.guard != null,
        })
        .toList(),
      'recentEvents': eventHistory.take(10).map((e) => {
        'type': e.runtimeType.toString(),
        'timestamp': e.timestamp.toIso8601String(),
      }).toList(),
      'timeInState': timeInCurrentState.inMilliseconds,
      'historySize': _contextHistory.length,
    };
  }
  
  /// Dispose of resources
  void dispose() {
    _eventController.close();
    _stateChangeController.close();
    _debugLog.clear();
    _contextHistory.clear();
  }
}

/// Factory for creating state machines with common configurations
class PieceStateMachineFactory {
  static PieceStateMachine create({
    required String pieceId,
    required PuzzlePiece piece,
    bool debugMode = false,
    int maxHistorySize = 100,
  }) {
    return PieceStateMachine(
      pieceId: pieceId,
      piece: piece,
      debugMode: debugMode,
      maxHistorySize: maxHistorySize,
    );
  }
  
  /// Create a state machine for testing
  static PieceStateMachine createForTesting({
    required String pieceId,
    required PuzzlePiece piece,
  }) {
    return PieceStateMachine(
      pieceId: pieceId,
      piece: piece,
      debugMode: true,
      maxHistorySize: 50,
    );
  }
}
