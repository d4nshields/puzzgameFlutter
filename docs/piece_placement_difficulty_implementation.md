# Piece Placement Difficulty Implementation

## Date: 2025-07-14
## Status: Implementation Plan
## Decision: Add precision difficulty dial for piece placement mechanics

## Context

Currently, the puzzle game allows players to drop pieces anywhere on the puzzle canvas and they automatically snap to the correct position. This makes the game too easy and removes the spatial reasoning challenge that makes jigsaw puzzles engaging.

## Requirements

1. **Difficulty Dial**: A setting that controls piece placement precision
   - **"Drop Anywhere" (Current)**: Pieces auto-place correctly regardless of drop position
   - **"Exact Placement"**: Pieces must be dropped precisely over their correct location
   - **Gradual levels between**: Allow for tolerance zones of varying sizes

2. **Visual & Audio Feedback**: 
   - Red outline for incorrect placement
   - Sound effects for success/failure
   - Piece remains where dropped if incorrect (not returned to tray)

3. **Precision Mechanics**:
   - Calculate drop position relative to piece's correct location
   - Allow tolerance based on difficulty setting
   - Support pickup and re-placement of incorrectly placed pieces

## Architecture Changes

### 1. Settings Service Extension
Add new placement difficulty setting:
```dart
// New setting for placement precision (0.0 = anywhere, 1.0 = exact)
Future<double> getPlacementPrecision();
Future<void> setPlacementPrecision(double precision);
```

### 2. Piece Placement Logic
Update game session to support precision validation:
```dart
class PuzzleGameSession {
  // New method for precision-based placement
  PlacementResult tryPlacePieceAtPosition(
    PuzzlePiece piece, 
    Offset dropPosition, 
    Size canvasSize
  );
}

enum PlacementResult {
  success,
  incorrectPosition,
  alreadyPlaced,
}
```

### 3. Enhanced Game Widget Updates
Modify drag/drop handling:
- Track drop positions
- Validate placement based on precision setting
- Handle incorrect placements with visual feedback
- Allow re-pickup of incorrectly placed pieces

### 4. Visual Feedback System
```dart
class IncorrectPieceRenderer {
  // Renders pieces with red outline when incorrectly placed
  // Allows tap-to-pickup for re-placement
}
```

## Implementation Details

### Precision Calculation
```dart
bool isPlacementCorrect(
  PuzzlePiece piece, 
  Offset dropPosition, 
  Size canvasSize, 
  double precisionSetting
) {
  // Calculate piece's correct position in canvas coordinates
  final correctPosition = calculateCorrectPosition(piece, canvasSize);
  
  // Calculate tolerance based on precision setting
  final tolerance = (1.0 - precisionSetting) * (canvasSize.width / gridSize) * 0.5;
  
  // Check if drop position is within tolerance
  final distance = (dropPosition - correctPosition).distance;
  return distance <= tolerance;
}
```

### Settings UI Enhancement
Add placement precision slider to settings screen:
- Visual representation of tolerance zones
- Preview of difficulty levels
- Clear labels and descriptions

## User Experience

1. **Progressive Difficulty**: Players can start with forgiving placement and gradually increase precision
2. **Visual Learning**: Red outlines teach correct piece positions
3. **Non-Punitive**: Incorrect pieces stay on canvas for re-adjustment
4. **Accessibility**: Audio cues support visual feedback

## Technical Considerations

### Canvas Coordinate Mapping
- Convert drop positions from widget coordinates to canvas coordinates
- Account for zoom and pan transformations
- Handle different screen sizes and orientations

### Performance
- Minimize recalculations during drag operations
- Cache correct positions for pieces
- Efficient hit-testing for tolerance zones

### State Management
- Track incorrectly placed pieces separately from correctly placed
- Maintain piece positions for save/restore functionality
- Update completion logic to only count correctly placed pieces

## Backward Compatibility

- Default precision setting maintains current "drop anywhere" behavior
- Existing save files continue to work
- Progressive enhancement - doesn't break existing functionality

## Testing Strategy

1. **Unit Tests**: Precision calculation algorithms
2. **Widget Tests**: Drag/drop interaction with different precision levels
3. **Integration Tests**: End-to-end placement scenarios
4. **User Testing**: Verify difficulty progression feels natural

## Implementation Priority

1. **Phase 1**: Core placement precision logic
2. **Phase 2**: Visual feedback (red outlines)
3. **Phase 3**: Audio feedback integration
4. **Phase 4**: Settings UI enhancement
5. **Phase 5**: Advanced features (animation, haptics)

## Success Metrics

- Players can successfully progress from easy to hard placement difficulty
- Visual feedback clearly indicates incorrect placements
- No performance degradation during drag operations
- Maintains accessibility for users with different motor skills
