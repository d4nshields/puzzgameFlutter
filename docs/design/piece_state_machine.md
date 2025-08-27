# Piece State Machine Implementation

## Overview

The Piece State Machine is a comprehensive state management system for puzzle pieces in Puzzle Nook. It implements hierarchical states, parallel state regions, event sourcing, and supports complex transitions with animations.

## Architecture

### Core Components

1. **PieceStateMachine**: Main state machine implementation
2. **TransitionValidator**: Rules engine for validating state transitions  
3. **TransitionAnimator**: Manages transition animations with curves
4. **TransitionRecorder**: Records analytics for transitions
5. **BatchTransitioner**: Handles transitions for multiple pieces

## State Types

The system defines the following states:

### Base States
- `idle`: Piece at rest, not being interacted with
- `hovering`: Mouse/finger is over the piece
- `selected`: Piece selected but not moved
- `dragging`: Piece being actively dragged

### Transition States
- `snapping`: Animating to snap position
- `magnetized`: Being attracted by magnetic field
- `returning`: Returning to tray or previous position

### Final States
- `placed`: Correctly placed but not locked
- `locked`: Locked in correct position

### Special States
- `celebrating`: Playing celebration animation
- `invalid`: In an invalid state/position

## Parallel State Regions

The system supports orthogonal state management through parallel regions:

- **interaction**: User interaction states
- **validation**: Position validation states
- **animation**: Animation states
- **physics**: Physics simulation states

## Event System

Events drive state transitions. Each event includes:
- Timestamp
- Piece ID
- Metadata

### Event Types

```dart
PieceHoverEvent       // Mouse enters piece
PieceUnhoverEvent     // Mouse leaves piece
PieceSelectEvent      // Piece selected
PieceDeselectEvent    // Piece deselected
PieceDragStartEvent   // Drag begins
PieceDragUpdateEvent  // Drag position update
PieceDragEndEvent     // Drag ends
PieceSnapEvent        // Snap to position
PieceMagnetizeEvent   // Magnetic attraction
PiecePlaceEvent       // Piece placed
PieceLockEvent        // Piece locked
PieceCelebrateEvent   // Celebration triggered
PieceInvalidateEvent  // Invalid state
PieceReturnEvent      // Return to tray
```

## Features

### 1. Hierarchical States

States can have parent-child relationships:
```dart
hovering -> parent: idle
dragging -> parent: selected
locked -> parent: placed
```

### 2. Guard Conditions

Transitions can have guard conditions that must be satisfied:
```dart
StateTransition(
  from: PieceStateType.idle,
  to: PieceStateType.hovering,
  guard: (machine, event) => !piece.isPlaced && !piece.isLocked,
)
```

### 3. Entry/Exit Actions

States define actions executed on entry and exit:
```dart
onEnter: (machine, event) {
  piece.setSelected(true);
  startGlowAnimation();
}
onExit: (machine, event) {
  piece.setSelected(false);
  stopGlowAnimation();
}
```

### 4. Event History & Undo

The system maintains event history for:
- Analytics and debugging
- Undo/rollback functionality
- State replay

```dart
machine.undo(steps: 3);  // Undo last 3 state changes
machine.rollback();       // Rollback to previous state
```

### 5. State Persistence

States can be exported and imported for persistence:
```dart
final state = machine.exportState();
// ... save to storage ...
machine.importState(state);
```

## Transition Validation

The `TransitionValidator` implements a rules engine with:

### Built-in Rules
- Cannot transition from locked state
- Cannot drag placed pieces
- Must select before dragging
- Can only celebrate when placed correctly
- Magnetization requires proximity
- Snap requires low velocity

### Custom Rules
```dart
validator.addRule(TransitionRule(
  id: 'custom_rule',
  description: 'Custom validation',
  condition: (machine, event) => customCheck(),
  priority: 100,  // Higher priority evaluated first
));
```

## Animation Support

The `TransitionAnimator` provides:

### Curve-based Animations
```dart
animator.animate(
  transitionId: 'snap_animation',
  config: TransitionAnimation(
    curve: Curves.easeInOutCubic,
    duration: Duration(milliseconds: 300),
  ),
);
```

### Spring Physics
```dart
animator.animateSpring(
  transitionId: 'bounce',
  target: 1.0,
  stiffness: 200.0,
  damping: 15.0,
);
```

## Batch Operations

The `BatchTransitioner` handles multiple pieces:

### Parallel Execution
```dart
await batchTransitioner.executeTransitions(
  machines,
  (pieceId) => PieceHoverEvent(pieceId: pieceId),
  parallel: true,
);
```

### Sequential with Stagger
```dart
await batchTransitioner.executeTransitions(
  machines,
  eventGenerator,
  parallel: false,
  staggerDelay: Duration(milliseconds: 50),
);
```

### Composite Transitions
```dart
final composite = CompositeTransition(
  id: 'place_and_celebrate',
  sequence: [
    PieceStateType.placed,
    PieceStateType.celebrating,
    PieceStateType.locked,
  ],
);
await batchTransitioner.executeComposite(machine, composite);
```

## Analytics & Debugging

### Transition Recording
```dart
recorder.record(TransitionRecord(
  pieceId: 'piece_1',
  fromState: PieceStateType.idle,
  toState: PieceStateType.hovering,
  duration: Duration(milliseconds: 100),
  successful: true,
));
```

### Statistics
```dart
final stats = recorder.getStatistics();
// Returns: totalTransitions, successRate, averageDuration,
//          stateFrequency, transitionPairs
```

### Debug Visualization
```dart
final vizData = machine.getVisualizationData();
// Returns: currentState, parallelStates, availableTransitions,
//          recentEvents, timeInState
```

## Usage Example

```dart
// Create state machine
final machine = PieceStateMachine(
  pieceId: piece.id,
  piece: piece,
  debugMode: true,
);

// Listen to state changes
machine.stateChangeStream.listen((state) {
  updateUI(state);
});

// Process user interaction
await machine.processEvent(PieceHoverEvent(pieceId: piece.id));
await machine.processEvent(PieceSelectEvent(
  pieceId: piece.id,
  position: currentPosition,
));

// Handle drag
await machine.processEvent(PieceDragStartEvent(
  pieceId: piece.id,
  startPosition: startPos,
));

// Update during drag
await machine.processEvent(PieceDragUpdateEvent(
  pieceId: piece.id,
  position: newPos,
  delta: delta,
  velocity: velocity,
));

// End drag - automatic snap detection
await machine.processEvent(PieceDragEndEvent(
  pieceId: piece.id,
  endPosition: endPos,
  velocity: finalVelocity,
));

// Cleanup
machine.dispose();
```

## Testing Utilities

The system includes comprehensive testing utilities:

```dart
// Create mock machine
final machine = TransitionTestUtils.createMockMachine();

// Simulate drag gesture
await TransitionTestUtils.simulateDrag(
  machine,
  startPosition,
  endPosition,
  steps: 10,
);

// Verify state sequence
final valid = TransitionTestUtils.verifyStateSequence(
  machine,
  [PieceStateType.idle, PieceStateType.hovering, PieceStateType.selected],
);
```

## Performance Considerations

- State transitions: < 0.1ms
- Event processing: < 1ms
- Supports 200+ simultaneous pieces
- Memory usage: ~10KB per state machine
- History limited to 100 events by default

## Integration Points

The state machine integrates with:
- Gesture recognition system
- Magnetic field calculations
- Animation orchestrator
- Feedback controller
- Analytics system

## Future Enhancements

Potential improvements:
- State machine visualization UI
- Record and replay functionality
- Machine learning for transition prediction
- Network synchronization for multiplayer
- Advanced debugging tools
