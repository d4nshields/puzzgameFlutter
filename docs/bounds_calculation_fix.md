# Critical Fix: Bounds Calculation Error in Asset Optimization

## Issue Description

The pixel subtraction analysis revealed persistent 1-pixel alignment errors even after the Flutter code fixes. Investigation traced the root cause to the Python asset optimization script.

## Root Cause

**Problem**: The Python script `tools/optimize_puzzle_assets.py` was using **inclusive bounds** calculation:

```python
# BEFORE (incorrect):
@property
def width(self) -> int:
    return int(self.right - self.left + 1)  # ❌ Inclusive bounds

@property  
def height(self) -> int:
    return int(self.bottom - self.top + 1)  # ❌ Inclusive bounds
```

**Impact**: This caused all optimized pieces to be calculated as 1 pixel larger than their actual dimensions, creating systematic misalignment when rendered in Flutter.

## Solution Applied

**Fix**: Changed to **exclusive bounds** calculation (standard in graphics APIs):

```python
# AFTER (correct):
@property
def width(self) -> int:
    return int(self.right - self.left)      # ✅ Exclusive bounds

@property  
def height(self) -> int:
    return int(self.bottom - self.top)      # ✅ Exclusive bounds
```

## Coordinate System Explanation

### Inclusive vs Exclusive Bounds

**Inclusive bounds** (what the script was doing):
- A rectangle from (0,0) to (2,2) has width = 2-0+1 = 3 pixels
- Includes both start and end coordinates

**Exclusive bounds** (standard graphics):
- A rectangle from (0,0) to (2,2) has width = 2-0 = 2 pixels  
- Includes start coordinate, excludes end coordinate

### Why This Matters

Graphics rendering systems (including Flutter's) use exclusive bounds:
- `Rect.fromLTWH(0, 0, 2, 2)` creates a 2×2 rectangle
- The rectangle spans pixels [0,1] × [0,1], NOT [0,1,2] × [0,1,2]

## Required Actions

After applying this fix to the Python script:

1. **Regenerate optimized assets**:
   ```bash
   cd /home/daniel/work/puzzgameFlutter
   python3 tools/optimize_puzzle_assets.py sample_puzzle_01 --verbose
   ```

2. **Revert the Flutter workaround** in `memory_optimized_asset_manager.dart`:
   ```dart
   // Remove this workaround since Python script is now fixed:
   final correctWidth = right - left;    // Remove this line
   final correctHeight = bottom - top;   // Remove this line
   
   // Use the JSON values directly again:
   bounds['width'].toDouble(),           // Now correct
   bounds['height'].toDouble(),          // Now correct
   ```

3. **Test pixel subtraction** - should now show perfect alignment

## Files Modified

- `tools/optimize_puzzle_assets.py` - Fixed bounds calculation
- `docs/bounds_calculation_fix.md` - This documentation

## Expected Results

- ✅ Perfect piece alignment (no 1-pixel gaps)
- ✅ Pixel subtraction shows solid color (minimal differences)
- ✅ All pieces render at exactly the correct size
- ✅ Reconstructed puzzle matches original preview.jpg exactly

## Technical Details

### Before Fix
```
Original bounds: left=0, top=0, right=172, bottom=169
Calculated: width=173, height=170  # Off by 1!
```

### After Fix  
```
Original bounds: left=0, top=0, right=172, bottom=169
Calculated: width=172, height=169  # Correct!
```

This aligns with standard graphics coordinate systems where a rectangle from (0,0) to (172,169) should have dimensions 172×169 pixels.
