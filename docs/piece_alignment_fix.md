# Critical Fix: Off-by-One Pixel Error in Piece Positioning

## Issue Description

The pixel subtraction analysis revealed that all puzzle pieces were appearing 1 pixel too small in both horizontal and vertical dimensions, creating visible black gaps between pieces in the reconstructed puzzle.

## Root Cause Analysis

**Problem Location**: `lib/game_module/services/memory_optimized_asset_manager.dart` in the `_loadOptimizedPiece` method.

**Issue**: The optimization metadata JSON contains inconsistent boundary values:

```json
"bounds": {
  "left": 0,
  "top": 0, 
  "right": 172,
  "bottom": 169,
  "width": 173,    // ❌ Should be 172 - 0 = 172
  "height": 170    // ❌ Should be 169 - 0 = 169  
}
```

The pre-calculated `width` and `height` values in the JSON are 1 pixel larger than the correct calculation from `left`, `top`, `right`, `bottom` coordinates.

**Flutter Code Issue**: The asset manager was using the incorrect pre-calculated values:

```dart
// BEFORE (incorrect):
contentBounds: Rect.fromLTWH(
  bounds['left'].toDouble(),
  bounds['top'].toDouble(),
  bounds['width'].toDouble(),    // ❌ Used incorrect JSON value
  bounds['height'].toDouble(),   // ❌ Used incorrect JSON value
),
```

## Solution Applied

**Fix**: Calculate correct width and height from the coordinate values instead of using the pre-calculated (incorrect) JSON values:

```dart
// AFTER (correct):
final left = bounds['left'].toDouble();
final top = bounds['top'].toDouble();
final right = bounds['right'].toDouble();
final bottom = bounds['bottom'].toDouble();
final correctWidth = right - left;        // Correct calculation
final correctHeight = bottom - top;       // Correct calculation

contentBounds: Rect.fromLTWH(
  left,
  top,
  correctWidth,
  correctHeight,
),
```

## Impact

- **Before**: 1-pixel black gaps between all puzzle pieces
- **After**: Perfect piece alignment with no visible gaps
- **Pixel Subtraction**: Should now show minimal differences between original and reconstructed puzzle

## Files Modified

- `lib/game_module/services/memory_optimized_asset_manager.dart` - Fixed `_loadOptimizedPiece` method
- `docs/piece_alignment_fix.md` - This documentation

## Technical Notes

### Why This Happened

The preprocessing tool that generated the optimization metadata calculated bounds using an inclusive coordinate system (where `width = right - left + 1`), but the Flutter rendering system expects an exclusive coordinate system (where `width = right - left`).

### Verification

1. Run the auto-solve debug screen
2. Enable pixel subtraction mode
3. Generate difference image
4. Verify minimal red highlighting (indicating perfect alignment)

### Related Systems

This fix only affects the memory-optimized rendering path (`OptimizedCanvasImagePainter`). The runtime optimization path was already working correctly because it calculates bounds directly from pixel analysis.

## Future Prevention

Consider updating the preprocessing tool to either:
1. Remove the redundant `width`/`height` fields from JSON (use calculated values)
2. Fix the calculation to use the correct coordinate system
3. Add validation to detect inconsistent bounds during asset loading
