# Coordinate System Documentation

## Overview

The Puzzle Nook coordinate system provides high-performance transformations between four distinct coordinate spaces, enabling smooth drag-and-drop interactions, zoom/pan operations, and precise piece placement in the puzzle game.

## Architecture

### Coordinate Spaces

The system manages four coordinate spaces:

1. **Screen Space** (`ScreenPoint`)
   - Physical device pixels
   - Hardware-dependent coordinates
   - Used for touch/mouse input events
   - Example: A tap at pixel (400, 300) on a 2x Retina display

2. **Canvas Space** (`CanvasPoint`)
   - Logical pixels (Flutter's coordinate system)
   - Device-independent coordinates
   - Used for rendering and layout
   - Example: A widget positioned at logical point (200, 150)

3. **Grid Space** (`GridPoint`)
   - Integer coordinates representing puzzle grid cells
   - Used for game logic and piece placement
   - Bounded by grid dimensions (width × height)
   - Example: Puzzle piece at grid position (5, 3)

4. **Workspace Space** (`WorkspacePoint`)
   - Continuous coordinates for the larger drag area
   - Used for free-form piece movement outside the grid
   - Allows pieces to be temporarily placed anywhere
   - Example: A piece being dragged at workspace position (800.5, 600.3)

### Transformation Flow

```
Screen Space ←→ Canvas Space ←→ Grid Space
                    ↕
              Workspace Space
```

## Mathematical Foundation

### Transformation Matrices

All transformations use 4×4 matrices (Matrix4) for optimal performance:

#### Screen ↔ Canvas
```
Canvas = Screen × (1 / devicePixelRatio)
Screen = Canvas × devicePixelRatio
```

#### Canvas ↔ Grid
```
Grid = (Canvas - panOffset) / (gridCellSize × zoomLevel)
Canvas = Grid × (gridCellSize × zoomLevel) + panOffset
```

#### Canvas ↔ Workspace
```
Workspace = Canvas × (workspaceBounds.size / canvasSize) + workspaceBounds.topLeft
Canvas = (Workspace - workspaceBounds.topLeft) × (canvasSize / workspaceBounds.size)
```

### Performance Optimizations

1. **Matrix Caching**: Transformation matrices are computed once and cached until configuration changes
2. **Lazy Evaluation**: Matrices are only built when first needed
3. **Direct Transformations**: Composite transformations (e.g., Screen→Grid) are provided for common use cases
4. **Performance Monitoring**: Built-in timing metrics ensure < 0.1ms transformation times

## Usage Examples

### Basic Setup

```dart
import 'package:puzzgame_flutter/game_module2/domain/services/coordinate_system.dart';

// Create configuration
final config = CoordinateSystemConfig(
  devicePixelRatio: MediaQuery.of(context).devicePixelRatio,
  canvasSize: Size(800, 600),
  gridCellSize: 50.0,
  gridWidth: 10,
  gridHeight: 8,
  workspaceBounds: Rect.fromLTWH(0, 0, 1600, 1200),
  zoomLevel: 1.0,
  panOffset: Offset.zero,
);

// Initialize system
final coordSystem = CoordinateSystem(config);
```

### Handle Touch Input

```dart
// Convert touch position to grid coordinates
void onTapDown(TapDownDetails details) {
  final screenPoint = ScreenPoint(
    details.globalPosition.dx,
    details.globalPosition.dy,
  );
  
  final gridPoint = coordSystem.screenToGrid(screenPoint);
  if (gridPoint != null) {
    // Handle grid cell tap
    selectPieceAt(gridPoint);
  }
}
```

### Implement Drag and Drop

```dart
// Track piece dragging in workspace coordinates
void onPanUpdate(DragUpdateDetails details) {
  final screenPoint = ScreenPoint(
    details.globalPosition.dx,
    details.globalPosition.dy,
  );
  
  final workspacePoint = coordSystem.screenToWorkspace(screenPoint);
  updatePiecePosition(workspacePoint);
  
  // Check if piece is over a valid grid cell
  final gridPoint = coordSystem.workspaceToGrid(workspacePoint);
  if (gridPoint != null) {
    highlightGridCell(gridPoint);
  }
}
```

### Implement Zoom and Pan

```dart
// Zoom with pinch gesture
void onScaleUpdate(ScaleUpdateDetails details) {
  final focalPoint = CanvasPoint(
    details.localFocalPoint.dx,
    details.localFocalPoint.dy,
  );
  
  coordSystem.applyZoom(details.scale, focalPoint);
  
  // Also handle panning
  coordSystem.applyPan(details.focalPointDelta);
  
  setState(() {}); // Trigger rebuild
}
```

### Render Grid Pieces

```dart
// Convert grid positions to rendering coordinates
Widget buildPiece(GridPoint gridPos, PuzzlePiece piece) {
  final canvasPoint = coordSystem.gridToCanvas(gridPos);
  final bounds = coordSystem.gridCellToCanvasBounds(gridPos);
  
  return Positioned(
    left: bounds.left,
    top: bounds.top,
    width: bounds.width,
    height: bounds.height,
    child: PieceWidget(piece),
  );
}
```

## Advanced Features

### View Controls

```dart
// Center view on specific piece
coordSystem.centerOnGridPoint(GridPoint(5, 4));

// Fit entire puzzle in view
coordSystem.fitGridToView();

// Reset to default view
coordSystem.resetView();
```

### Performance Monitoring

```dart
// Check transformation performance
final stats = coordSystem.getPerformanceStats();
print('Average transformation time: ${stats["averageTransformationTimeUs"]}μs');
print('Meets target performance: ${stats["meetsTargetPerformance"]}');
```

### Dynamic Configuration Updates

```dart
// Update configuration when screen size changes
void onScreenResize(Size newSize) {
  final newConfig = CoordinateSystemConfig(
    devicePixelRatio: config.devicePixelRatio,
    canvasSize: newSize,
    gridCellSize: config.gridCellSize,
    gridWidth: config.gridWidth,
    gridHeight: config.gridHeight,
    workspaceBounds: Rect.fromLTWH(0, 0, newSize.width * 2, newSize.height * 2),
    zoomLevel: config.zoomLevel,
    panOffset: config.panOffset,
  );
  
  coordSystem.updateConfig(newConfig);
}
```

## Best Practices

### 1. Configuration Management
- Store configuration in a state management solution (Provider, Riverpod, etc.)
- Update configuration atomically to avoid inconsistent states
- Validate configuration parameters before applying

### 2. Performance
- Reuse coordinate system instances; don't create new ones frequently
- Batch transformations when possible
- Use composite transformations for direct conversions

### 3. Error Handling
- Always check for null when converting to grid coordinates
- Validate bounds before rendering
- Handle edge cases (empty grid, extreme zoom, etc.)

### 4. Testing
- Test all transformation pairs for round-trip accuracy
- Verify performance metrics in release mode
- Test edge cases and boundary conditions

## Integration with Game Module

### Piece Placement Logic

```dart
class PiecePlacementService {
  final CoordinateSystem _coordSystem;
  
  bool canPlacePiece(WorkspacePoint position, PuzzlePiece piece) {
    final gridPoint = _coordSystem.workspaceToGrid(position);
    if (gridPoint == null) return false;
    
    return isValidPlacement(gridPoint, piece);
  }
  
  void snapPieceToGrid(WorkspacePoint position, PuzzlePiece piece) {
    final gridPoint = _coordSystem.workspaceToGrid(position);
    if (gridPoint != null && canPlacePiece(position, piece)) {
      final snappedCanvas = _coordSystem.gridToCanvas(gridPoint);
      animatePieceTo(snappedCanvas);
    }
  }
}
```

### Rendering Pipeline

```dart
class PuzzleRenderer extends CustomPainter {
  final CoordinateSystem coordSystem;
  
  @override
  void paint(Canvas canvas, Size size) {
    // Update canvas size if needed
    if (coordSystem.config.canvasSize != size) {
      coordSystem.updateConfig(/*...*/);
    }
    
    // Render grid
    final gridBounds = coordSystem.getVisibleGridBounds();
    drawGrid(canvas, gridBounds);
    
    // Render pieces
    for (final piece in pieces) {
      final canvasPos = coordSystem.gridToCanvas(piece.gridPosition);
      drawPiece(canvas, canvasPos, piece);
    }
  }
}
```

## Troubleshooting

### Common Issues

1. **Pieces not aligning with grid**
   - Verify gridCellSize matches your piece dimensions
   - Check that pan offset is being applied correctly
   - Ensure zoom level is accounted for in calculations

2. **Touch input offset**
   - Confirm devicePixelRatio is set correctly
   - Use globalPosition for absolute coordinates
   - Account for app bar and status bar offsets

3. **Performance degradation**
   - Check that matrices are being cached properly
   - Avoid creating new coordinate systems frequently
   - Profile transformation times using built-in metrics

4. **Zoom/pan glitches**
   - Clamp zoom levels to reasonable ranges (0.1 - 10.0)
   - Apply pan limits to prevent scrolling too far
   - Use focal point correctly for zoom center

## API Reference

See the inline documentation in `coordinate_system.dart` for detailed API information.

## Testing

Run the comprehensive test suite:

```bash
flutter test test/game_module2/domain/services/coordinate_system_test.dart
```

The test suite covers:
- All transformation pairs
- Round-trip accuracy
- Performance benchmarks
- Edge cases and boundaries
- Configuration updates
- Zoom/pan operations
- View controls
