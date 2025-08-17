# Game Module 2 - Hexagonal Architecture Design

**Date**: 2025-08-16  
**Status**: In Development  
**Decision Makers**: Daniel (Platform Developer)

## Executive Summary

This document outlines the design and implementation of `game_module2`, a complete rewrite of the puzzle game mechanics using hexagonal architecture principles. The new module addresses critical issues with coordinate systems, zoom consistency, and user interaction while maintaining compatibility with existing assets.

## Key Problems Being Solved

### 1. Inconsistent Zoom Levels
**Current Issues:**
- Pieces in tray render at different scale than when dragged
- Placed pieces have different scale than pieces being moved
- Zoom service not properly integrated with all rendering contexts

**Solution in Module 2:**
- Single unified coordinate system in pixel units
- Zoom is purely a viewport transformation
- All piece representations maintain consistent internal coordinates

### 2. Coordinate System Confusion
**Current Issues:**
- Mix of grid coordinates, canvas coordinates, and screen coordinates
- Padded PNG assets with varying interpretations of size
- Content bounds vs. full bounds confusion

**Solution in Module 2:**
- All internal coordinates in original asset pixel units (e.g., 2048x2048)
- Clear separation between model coordinates and view transformations
- Explicit coordinate space documentation for each layer

### 3. Rigid Drag-and-Drop Interaction
**Current Issues:**
- One-shot drag-and-drop doesn't allow fine positioning
- No haptic feedback for alignment assistance
- Limited accessibility for low-vision users

**Solution in Module 2:**
- Workspace-based interaction where pieces can be freely moved
- Continuous manipulation with real-time feedback
- Haptic and audio cues for proximity and correct placement

## Hexagonal Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                     Presentation Layer                       │
│  ┌──────────────────────────────────────────────────────┐  │
│  │           WorkspaceWidget (UI Component)             │  │
│  │  - Gesture handling                                  │  │
│  │  - Viewport management                               │  │
│  │  - Visual feedback                                   │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                              ▲
                              │ Uses
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                     Application Layer                        │
│  ┌──────────────────────────────────────────────────────┐  │
│  │              Use Cases & Controllers                  │  │
│  │  - MovePieceUseCase                                  │  │
│  │  - CheckAlignmentUseCase                            │  │
│  │  - ProvideFeedbackUseCase                           │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                              ▲
                              │ Orchestrates
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                      Domain Layer                            │
│  ┌──────────────────────────────────────────────────────┐  │
│  │               Core Business Logic                     │  │
│  │  - PuzzlePiece (Entity)                             │  │
│  │  - PuzzleWorkspace (Aggregate)                      │  │
│  │  - PlacementRules (Value Object)                    │  │
│  │  - Coordinates (Value Object)                       │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │                    Port Interfaces                    │  │
│  │  - AssetRepository                                   │  │
│  │  - FeedbackService                                   │  │
│  │  - PersistenceRepository                             │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                              ▲
                              │ Implements
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                  Infrastructure Layer                        │
│  ┌──────────────────────────────────────────────────────┐  │
│  │                     Adapters                          │  │
│  │  - FlutterAssetAdapter                              │  │
│  │  - HapticFeedbackAdapter                            │  │
│  │  - AudioFeedbackAdapter                             │  │
│  │  - LocalStorageAdapter                              │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

## Core Domain Model

### 1. Coordinate System

```dart
/// Immutable value object representing position in puzzle coordinate space
/// All coordinates are in original asset pixel units (e.g., 2048x2048)
class PuzzleCoordinate {
  final double x;
  final double y;
  
  const PuzzleCoordinate({required this.x, required this.y});
  
  // Factory constructors for different coordinate spaces
  factory PuzzleCoordinate.fromGrid(int row, int col, double pieceSize) {
    return PuzzleCoordinate(
      x: col * pieceSize,
      y: row * pieceSize,
    );
  }
  
  double distanceTo(PuzzleCoordinate other) {
    final dx = x - other.x;
    final dy = y - other.y;
    return sqrt(dx * dx + dy * dy);
  }
}
```

### 2. Puzzle Piece Entity

```dart
/// Core domain entity representing a puzzle piece
/// Independent of rendering or UI concerns
class PuzzlePiece {
  final String id;
  final PuzzleCoordinate correctPosition;  // Where it should be placed
  final Size contentBounds;                // Actual content size (with tabs)
  final Size paddedBounds;                 // Full PNG dimensions
  
  PuzzleCoordinate? currentPosition;       // Where it currently is (null if in tray)
  bool isPlaced = false;
  
  bool isNearCorrectPosition({required double threshold}) {
    if (currentPosition == null) return false;
    return currentPosition!.distanceTo(correctPosition) <= threshold;
  }
  
  bool canSnapToPosition({required double snapDistance}) {
    return isNearCorrectPosition(threshold: snapDistance);
  }
}
```

### 3. Puzzle Workspace Aggregate

```dart
/// Aggregate root managing the puzzle workspace state
/// This is the single source of truth for puzzle state
class PuzzleWorkspace {
  final String puzzleId;
  final Size canvasSize;  // In pixel units (e.g., 2048x2048)
  final List<PuzzlePiece> pieces;
  final Map<String, PuzzleCoordinate> piecePositions;
  
  // Placement configuration
  final double snapDistance = 50.0;      // Pixels within which pieces snap
  final double feedbackDistance = 100.0; // Pixels within which feedback starts
  
  /// Move a piece to a new position in workspace coordinates
  MoveResult movePiece(String pieceId, PuzzleCoordinate newPosition) {
    final piece = pieces.firstWhere((p) => p.id == pieceId);
    
    // Check if piece can snap to correct position
    piece.currentPosition = newPosition;
    
    if (piece.canSnapToPosition(snapDistance: snapDistance)) {
      piece.currentPosition = piece.correctPosition;
      piece.isPlaced = true;
      return MoveResult.snapped(piece.correctPosition);
    }
    
    // Check if near correct position for feedback
    final distance = piece.currentPosition!.distanceTo(piece.correctPosition);
    if (distance <= feedbackDistance) {
      final intensity = 1.0 - (distance / feedbackDistance);
      return MoveResult.near(intensity: intensity);
    }
    
    return MoveResult.moved();
  }
  
  /// Remove a placed piece back to tray
  void removePiece(String pieceId) {
    final piece = pieces.firstWhere((p) => p.id == pieceId);
    piece.currentPosition = null;
    piece.isPlaced = false;
    piecePositions.remove(pieceId);
  }
  
  bool get isCompleted => pieces.every((p) => p.isPlaced);
  int get placedCount => pieces.where((p) => p.isPlaced).length;
}
```

## Port Interfaces

### Asset Repository Port

```dart
/// Port interface for loading puzzle assets
/// Implementation details hidden from domain layer
abstract class AssetRepository {
  Future<PuzzleAssetData> loadPuzzle(String puzzleId, String gridSize);
  Future<ui.Image> loadPieceImage(String puzzleId, String pieceId);
  Future<PieceBounds> getPieceBounds(String puzzleId, String pieceId);
}
```

### Feedback Service Port

```dart
/// Port interface for providing user feedback
abstract class FeedbackService {
  void provideHaptic(HapticIntensity intensity);
  void playSound(SoundType type);
  void showVisualHint(VisualHint hint);
}

enum HapticIntensity { light, medium, heavy }
enum SoundType { pickup, move, near, snap, complete }
```

## Application Layer Use Cases

### Move Piece Use Case

```dart
class MovePieceUseCase {
  final PuzzleWorkspace workspace;
  final FeedbackService feedback;
  
  void execute(String pieceId, PuzzleCoordinate newPosition) {
    final result = workspace.movePiece(pieceId, newPosition);
    
    switch (result.type) {
      case MoveResultType.snapped:
        feedback.provideHaptic(HapticIntensity.heavy);
        feedback.playSound(SoundType.snap);
        break;
      case MoveResultType.near:
        // Intensity based on proximity
        final haptic = result.intensity > 0.7 
            ? HapticIntensity.medium 
            : HapticIntensity.light;
        feedback.provideHaptic(haptic);
        feedback.playSound(SoundType.near);
        break;
      case MoveResultType.moved:
        // No feedback for regular moves
        break;
    }
  }
}
```

## Presentation Layer

### Workspace Widget

```dart
/// Main UI widget implementing the workspace interaction model
class PuzzleWorkspaceWidget extends StatefulWidget {
  final PuzzleWorkspace workspace;
  final ViewportController viewport;
  
  // ... implementation
}

/// Controls viewport transformations (zoom, pan)
/// Separate from domain logic
class ViewportController {
  double zoom = 1.0;
  Offset pan = Offset.zero;
  
  /// Convert workspace coordinates to screen coordinates
  Offset workspaceToScreen(PuzzleCoordinate coord) {
    return Offset(coord.x * zoom + pan.dx, coord.y * zoom + pan.dy);
  }
  
  /// Convert screen coordinates to workspace coordinates
  PuzzleCoordinate screenToWorkspace(Offset screenPos) {
    return PuzzleCoordinate(
      x: (screenPos.dx - pan.dx) / zoom,
      y: (screenPos.dy - pan.dy) / zoom,
    );
  }
}
```

## Implementation Strategy

### Phase 1: Core Domain (Week 1)
1. Implement coordinate system and value objects
2. Create PuzzlePiece and PuzzleWorkspace entities
3. Define port interfaces
4. Write comprehensive unit tests for domain logic

### Phase 2: Infrastructure Adapters (Week 2)
1. Implement FlutterAssetAdapter for loading puzzle assets
2. Create HapticFeedbackAdapter using Flutter's haptic feedback
3. Implement AudioFeedbackAdapter
4. Create LocalStorageAdapter for game state persistence

### Phase 3: Application Layer (Week 3)
1. Implement core use cases
2. Create workspace controller
3. Add game session management
4. Implement scoring and progress tracking

### Phase 4: Presentation Layer (Week 4)
1. Build WorkspaceWidget with gesture handling
2. Implement viewport controller with smooth zoom/pan
3. Create piece rendering with consistent scaling
4. Add visual feedback indicators

### Phase 5: Integration & Testing (Week 5)
1. Integrate with existing app infrastructure
2. Comprehensive integration testing
3. Performance optimization
4. User acceptance testing

## Key Design Decisions

### 1. Pixel-Unit Coordinates
All internal coordinates use original asset pixel units. This eliminates confusion and ensures consistency across all operations.

### 2. Workspace Interaction Model
Instead of discrete drag-and-drop, pieces can be freely moved around the workspace. This enables:
- Fine positioning control
- Better accessibility
- Natural interaction patterns
- Continuous feedback

### 3. Separation of Concerns
- **Domain**: Pure business logic, no Flutter dependencies
- **Application**: Use case orchestration
- **Infrastructure**: External service adapters
- **Presentation**: UI and gesture handling

### 4. Immutable Coordinates
Using immutable value objects for coordinates prevents accidental mutation and makes the system more predictable.

### 5. Explicit Coordinate Spaces
Each layer explicitly documents which coordinate space it operates in:
- Workspace coordinates (pixel units)
- Screen coordinates (device pixels)
- Normalized coordinates (0.0 to 1.0)

## Testing Strategy

### Unit Tests
- Domain logic (100% coverage target)
- Coordinate transformations
- Placement rules
- Workspace state management

### Integration Tests
- Asset loading pipeline
- Feedback system integration
- State persistence
- Gesture handling

### Performance Tests
- Large puzzle handling (15x15 grid)
- Smooth 60fps during manipulation
- Memory usage under 2GB
- Battery efficiency

### Acceptance Tests
- Piece placement accuracy
- Feedback responsiveness
- Visual consistency
- Accessibility features

## Migration Plan

1. Develop game_module2 in parallel with existing module
2. Feature flag to switch between implementations
3. A/B testing with subset of users
4. Gradual rollout based on metrics
5. Deprecate and remove game_module once stable

## Success Metrics

- **Zoom Consistency**: Same visual size across all contexts
- **Placement Accuracy**: 100% correct placement detection
- **Feedback Latency**: < 16ms haptic response
- **Memory Usage**: < 50% of current implementation
- **User Satisfaction**: Improved completion rates and ratings

## Conclusion

The game_module2 architecture addresses fundamental issues with the current implementation while providing a clean, maintainable, and extensible foundation for future enhancements. The hexagonal architecture ensures proper separation of concerns and makes the system easier to test and modify.
