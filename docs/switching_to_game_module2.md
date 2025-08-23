# Switching from game_module to game_module2

**Date**: 2025-08-16  
**Status**: Ready for Integration

## Overview

The `game_module2` is now ready as a drop-in replacement for the original `game_module`. It fixes the critical piece placement issue and provides a better architecture.

## Key Improvements

### 1. Fixed Piece Placement
- **Old**: Single drop zone covering entire canvas - pieces auto-snap regardless of drop position
- **New**: Individual drop targets for each grid position - pieces only snap when dropped on correct cell

### 2. Workspace Model
- **Old**: Pieces either in tray or placed, no intermediate state
- **New**: Pieces can exist on workspace, allowing free movement before placement

### 3. Clean Architecture
- **Old**: Mixed concerns, UI logic in domain
- **New**: Hexagonal architecture with clear separation of concerns

## Integration Steps

### Step 1: Update Service Locator

In `lib/core/infrastructure/service_locator.dart`, change:

```dart
// OLD
import 'package:puzzgame_flutter/game_module/puzzle_game_module.dart';

void setupDependencies() {
  // ...
  
  // Register Game Module - using PuzzleGameModule for jigsaw puzzle gameplay
  serviceLocator.registerSingleton<GameModule>(PuzzleGameModule());
  
  // ...
}
```

To:

```dart
// NEW
import 'package:puzzgame_flutter/game_module2/puzzle_game_module2.dart';

void setupDependencies() {
  // ...
  
  // Register Game Module - using PuzzleGameModule2 with fixed piece placement
  serviceLocator.registerSingleton<GameModule>(PuzzleGameModule2());
  
  // ...
}
```

### Step 2: Update Game Screen (Optional)

The existing `GameScreen` should work as-is because `PuzzleGameSession2` is compatible with `PuzzleGameSession`. However, for the best experience, update the widget:

In `lib/presentation/screens/game_screen.dart`:

```dart
// Check if using new module
if (gameSession is PuzzleGameSession2) {
  return Column(
    children: [
      _buildPuzzleInfo(context, gameSession, difficulty, gridSize, ref),
      
      // Use new workspace widget for proper piece placement
      Expanded(
        child: PuzzleWorkspaceWidget(
          gameSession: gameSession,
          onGameCompleted: () => _onPuzzleCompleted(context, ref),
        ),
      ),
    ],
  );
} else if (gameSession is PuzzleGameSession) {
  // Fallback to old widget if needed
  return Column(
    children: [
      _buildPuzzleInfo(context, gameSession, difficulty, gridSize, ref),
      
      Expanded(
        child: EnhancedPuzzleGameWidget(
          gameSession: gameSession,
          onGameCompleted: () => _onPuzzleCompleted(context, ref),
        ),
      ),
    ],
  );
}
```

### Step 3: Add Import

Add the new widget import:

```dart
import 'package:puzzgame_flutter/game_module2/presentation/widgets/puzzle_workspace_widget.dart';
import 'package:puzzgame_flutter/game_module2/puzzle_game_module2.dart' show PuzzleGameSession2;
```

## Testing the Switch

### 1. Build and Run
```bash
flutter clean
flutter pub get
flutter run
```

### 2. Verify Piece Placement
- Drag a piece from the tray
- Drop it anywhere on the canvas
- **Expected**: Piece only snaps if dropped on its correct grid cell
- **Old Behavior**: Piece would snap regardless of drop position

### 3. Check Workspace Behavior
- Pieces can be placed on workspace without snapping
- Multiple pieces can exist on workspace simultaneously
- Pieces only snap when close to correct position

## Rollback Plan

If issues arise, simply revert the service locator change:

```dart
// Revert to original
serviceLocator.registerSingleton<GameModule>(PuzzleGameModule());
```

## Feature Comparison

| Feature | game_module | game_module2 |
|---------|------------|--------------|
| Piece Placement | Auto-snaps anywhere | Only snaps at correct position |
| Drop Zones | Single full canvas | Individual per grid cell |
| Workspace | Not supported | Pieces can float on workspace |
| Architecture | Mixed concerns | Hexagonal architecture |
| Haptic Feedback | Basic | Proximity-based intensity |
| Memory Usage | Dual image cache | Optimized single cache |
| Testability | Limited | Full domain testing |

## Known Differences

### Visual
- game_module2 shows grid lines for guidance
- Piece tray is at bottom instead of side
- Cleaner visual feedback for valid drop zones

### Behavioral
- Pieces must be dropped on correct cell to place
- Workspace pieces can be freely moved
- Better haptic feedback based on proximity

## Migration Benefits

1. **Actual Challenge**: Puzzles are now challenging as pieces must be placed correctly
2. **Better UX**: Clear visual feedback for valid placements
3. **Cleaner Code**: Maintainable architecture with clear separation
4. **Better Testing**: Domain logic can be unit tested
5. **Future Ready**: Easy to add features like rotation, multi-select, etc.

## Performance Notes

- Memory usage is similar or better due to optimized caching
- Rendering performance is equivalent
- Haptic feedback is throttled to prevent battery drain

## Troubleshooting

### Issue: Pieces won't place
- **Cause**: Piece must be dropped on exact grid cell
- **Solution**: Look for green highlight when dragging

### Issue: Missing piece images
- **Cause**: Asset managers not initialized
- **Solution**: Ensure `initialize()` is called on module

### Issue: Workspace pieces disappear
- **Cause**: State management issue
- **Solution**: Check that PuzzleWorkspaceWidget is not being rebuilt

## Next Steps

After successful integration:

1. Remove old game_module code
2. Update tests to use new module
3. Add rotation support (optional)
4. Implement piece clustering (optional)
5. Add animation transitions

## Conclusion

The switch to game_module2 fixes the critical piece placement issue where pieces would auto-snap regardless of drop position. The new module provides a proper puzzle-solving experience with pieces that only snap when placed in their correct positions.
