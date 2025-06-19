# Pixel Subtraction Debug Feature

## Overview
The Auto-Solve Debug screen now includes a pixel subtraction feature to analyze piece alignment by comparing the reconstructed puzzle against the original image.

## Architecture Decision

### Problem Statement
The auto-solve feature shows that puzzle pieces are being placed according to their JSON metadata, but the result doesn't look exactly like the original image. To understand the exact patterns in apparent misalignment, we need pixel-level comparison.

### Solution: Pixel Subtraction Analysis

#### Feature Components

1. **Toggle Control**: A switch to enable/disable pixel subtraction mode
2. **Original Image Loading**: Loads `assets/puzzles/sample_puzzle_01/preview.jpg` at startup
3. **Puzzle Capture**: Uses `RepaintBoundary` to capture the current puzzle state as a `ui.Image`
4. **Pixel Difference Calculation**: Compares each pixel between original and captured images
5. **Visual Difference Display**: Shows misaligned areas highlighted in red

#### Implementation Details

##### Image Capture System
```dart
RepaintBoundary(
  key: _puzzleCanvasKey,
  child: // puzzle canvas
)

// Capture current state
final RenderObject? renderObject = _puzzleCanvasKey.currentContext?.findRenderObject();
final ui.Image image = await renderObject.toImage(pixelRatio: 1.0);
```

##### Pixel Difference Algorithm
- Converts both images to RGBA byte data
- Handles size differences by scaling coordinates
- Calculates absolute difference per color channel
- Applies threshold-based highlighting (difference > 10)
- Differences highlighted in red, unchanged areas show original

##### Visual Modes
- **Normal Mode**: Shows reconstructed puzzle with pieces
- **Pixel Subtraction Mode**: Shows difference image with misalignments highlighted

#### User Interface

##### Controls Panel
```
[Icon] Pixel Subtraction Analysis                    [Switch]
[Generate Diff Button] [Original: WxH] [Diff: Status]
```

##### Workflow
1. Auto-solve the puzzle completely
2. Toggle on "Pixel Subtraction Analysis"
3. Click "Generate Diff" to capture and compare
4. Use zoom controls to inspect highlighted areas
5. Zoom up to 50x for pixel-level analysis

#### Technical Implementation

##### Memory Management
- Properly disposes `ui.Image` objects in `dispose()`
- Clears difference image when toggling mode off
- Uses efficient pixel-level operations

##### Error Handling
- Validates image loading and capture steps
- Provides user feedback for failures
- Graceful fallbacks for missing assets

##### Performance Considerations
- Image processing done asynchronously
- UI feedback during generation process
- No impact on normal puzzle gameplay

#### Expected Debugging Insights

This feature will reveal:
1. **Piece positioning accuracy**: How well PNG padding places pieces
2. **Gap patterns**: Systematic spacing issues
3. **Edge alignment**: Border piece positioning
4. **Content drift**: Accumulated positioning errors

#### Usage Instructions

1. Navigate to Auto-Solve Debug screen
2. Wait for game initialization
3. Click auto-solve to place all pieces
4. Enable "Pixel Subtraction Analysis" toggle
5. Click "Generate Diff" to create difference image
6. Use zoom controls (up to 50x) to examine highlighted misalignments
7. Red areas indicate pixel differences above threshold
8. Original image areas with no differences remain unchanged

#### Files Modified

- `lib/presentation/screens/auto_solve_screen.dart`: Enhanced with pixel subtraction functionality
- `docs/pixel_subtraction_debug.md`: This documentation file

#### Dependencies

- Uses existing Flutter `dart:ui` library for image processing
- Leverages `RepaintBoundary` for widget-to-image capture
- No additional package dependencies required

#### Future Enhancements

- Adjustable difference threshold slider
- Statistical analysis of misalignment patterns
- Export functionality for difference images
- Batch analysis across multiple puzzle solutions

## Technical Notes

### Memory Management Considerations
- Each `ui.Image` object must be explicitly disposed to prevent memory leaks
- The difference image generation creates temporary large byte arrays
- Image capture is performed at natural resolution to maintain pixel accuracy

### Performance Characteristics
- Original image loading: One-time at screen initialization
- Puzzle capture: ~100-500ms depending on puzzle complexity
- Pixel difference calculation: ~200-1000ms for 15x15 grid
- UI remains responsive during processing with loading indicators

### Debugging Workflow
This feature enables a systematic approach to identifying misalignment issues:

1. **Visual Inspection**: Auto-solve and visually compare to original
2. **Pixel Analysis**: Enable subtraction mode to see exact differences
3. **Pattern Recognition**: Use zoom to identify systematic vs random misalignments
4. **Root Cause Analysis**: Determine if issues are in PNG generation, metadata, or rendering

### Integration with Existing Systems
- Builds on existing `MemoryOptimizedAssetManager` infrastructure
- Uses same puzzle loading and piece placement logic as normal gameplay
- Maintains compatibility with existing zoom and pan controls
- No changes required to core game mechanics
