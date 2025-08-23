# Game Module 2 - Fixing Piece Placement with Irregular Shapes

**Date**: 2025-08-16  
**Author**: Dan (with AI assistance)  
**Status**: Problem Analysis & Solution Design

## Problem Summary

The puzzle pieces are not being accepted when dropped on their correct positions. The rectangular grid highlights show when dragging pieces over them, but the pieces snap back to the tray instead of being placed. This is due to a fundamental mismatch between:

1. **Visual Reality**: Jigsaw pieces have irregular shapes with tabs/blanks that extend beyond their logical grid cell
2. **Current Implementation**: Uses rectangular grid cells as drop targets

## Root Cause Analysis

### 1. Irregular Piece Shapes vs Grid Cells

Your documentation (`jigsaw_piece_overlaps_explanation.md`) correctly identifies that puzzle pieces have:
- **Tabs**: Extensions that protrude into neighboring cells (30-50 pixels)
- **Blanks**: Indentations that receive tabs from neighbors
- **Overlapping bounds**: Content extends beyond logical grid boundaries

Example from your metadata:
```
Piece 0_0: bounds right = 172px
Piece 0_1: bounds left = 132px  
Overlap = 40px (tabs interlocking)
```

### 2. Current Drop Target Implementation Issues

The current `_buildDropTargets` method in `puzzle_workspace_widget.dart`:
```dart
// Creates rectangular drop zones exactly matching grid cells
left: col * cellWidth,
top: row * cellHeight,
width: cellWidth,
height: cellHeight,
```

**Problems**:
1. **Hit Detection Mismatch**: The dragged piece's visual center might be over a neighboring cell due to tabs
2. **Visual Confusion**: Rectangular highlights don't match irregular piece shapes
3. **Precision Required**: User must position piece very precisely within the grid cell

### 3. Coordinate System Confusion

The workspace uses multiple coordinate systems:
- **Grid coordinates**: Row/column indices (0,0 to 14,14 for 15x15)
- **Canvas coordinates**: Pixel positions (0,0 to 2048,2048)
- **Screen coordinates**: Scaled for display
- **Piece content bounds**: Actual visual extents including tabs

## Proposed Solution

### Phase 1: Fix Immediate Placement Issue

#### 1.1 Improve Drop Target Hit Detection

Replace rigid grid-based drop targets with proximity-based placement:

```dart
// In puzzle_workspace_widget.dart
Widget _buildCanvas(BoxConstraints constraints) {
  // ... existing code ...
  
  return Center(
    child: DragTarget<PuzzlePiece>(
      // Validate that the drop is within canvas bounds
      onWillAcceptWithDetails: (details) {
        // Get the render box to convert to local coordinates
        final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
        if (renderBox == null) return false;
        
        // Convert drop position to local coordinates relative to this widget
        final localPosition = renderBox.globalToLocal(details.offset);
        
        // Get scaled canvas bounds
        final scaledWidth = canvasSize.width * scale;
        final scaledHeight = canvasSize.height * scale;
        
        // Check if drop is within canvas bounds
        final isWithinBounds = localPosition.dx >= 0 &&
                               localPosition.dy >= 0 &&
                               localPosition.dx <= scaledWidth &&
                               localPosition.dy <= scaledHeight;
        
        return isWithinBounds;
      },
      onAcceptWithDetails: (details) {
        final piece = details.data;
        
        // Get the render box for coordinate conversion
        final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
        if (renderBox == null) return;
        
        // Convert drop position to local coordinates
        final localPosition = renderBox.globalToLocal(details.offset);
        
        // Validate bounds again for safety
        final scaledWidth = canvasSize.width * scale;
        final scaledHeight = canvasSize.height * scale;
        
        if (localPosition.dx < 0 || localPosition.dy < 0 ||
            localPosition.dx > scaledWidth || localPosition.dy > scaledHeight) {
          // Drop is outside canvas bounds - return piece to tray
          return;
        }
        
        // Convert local position to canvas coordinates by dividing by scale
        final canvasX = localPosition.dx / scale;
        final canvasY = localPosition.dy / scale;
        
        // Try to place piece at this canvas position
        _tryPlacePieceAtCanvasPosition(piece, canvasX, canvasY);
      },
      builder: (context, candidateData, rejectedData) {
        final isHighlighted = candidateData.isNotEmpty;
        
        return Container(
          width: canvasSize.width * scale,
          height: canvasSize.height * scale,
          decoration: BoxDecoration(
            color: Colors.grey[100],
            border: Border.all(
              color: isHighlighted ? Colors.blue : Colors.grey[400]!,
              width: isHighlighted ? 3 : 2,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Stack(
            clipBehavior: Clip.none, // Allow pieces to extend beyond canvas during drag
            children: [
              // Grid lines for guidance
              CustomPaint(
                size: Size(canvasSize.width * scale, canvasSize.height * scale),
                painter: GridPainter(gridSize: widget.gameSession.gridSize),
              ),
              
              // Placed pieces
              ...widget.gameSession.placedPieces.map((piece) {
                return _buildPlacedPiece(piece, scale);
              }),
              
              // Visual feedback for piece being dragged
              if (_isDragging && _draggedPiece != null)
                _buildGhostPiece(_draggedPiece!, scale),
            ],
          ),
        );
      },
    ),
  );
}

void _tryPlacePieceAtCanvasPosition(PuzzlePiece piece, double canvasX, double canvasY) {
  final gridSize = widget.gameSession.gridSize;
  final cellWidth = widget.gameSession.canvasInfo.canvasSize.width / gridSize;
  final cellHeight = widget.gameSession.canvasInfo.canvasSize.height / gridSize;
  
  // Calculate the piece's correct position center
  final correctCenterX = (piece.correctCol + 0.5) * cellWidth;
  final correctCenterY = (piece.correctRow + 0.5) * cellHeight;
  
  // Calculate distance from drop position to correct position
  final distance = math.sqrt(
    math.pow(canvasX - correctCenterX, 2) + 
    math.pow(canvasY - correctCenterY, 2)
  );
  
  // Use a generous snap threshold (considering piece size and tabs)
  final snapThreshold = math.min(cellWidth, cellHeight) * 0.4; // 40% of cell size
  
  if (distance <= snapThreshold) {
    // Snap to correct position
    setState(() {
      widget.gameSession.tryPlacePieceAt(
        piece,
        piece.correctCol * cellWidth,
        piece.correctRow * cellHeight,
      );
      HapticFeedback.heavyImpact();
      
      if (widget.gameSession.isCompleted) {
        widget.onGameCompleted?.call();
      }
    });
  } else {
    // Return to tray - piece not close enough
    HapticFeedback.lightImpact();
  }
}
```

#### 1.2 Add Visual Feedback During Drag

Show a ghost/preview of where the piece will snap:

```dart
Widget _buildGhostPiece(PuzzlePiece piece, double scale) {
  final cellWidth = widget.gameSession.canvasInfo.canvasSize.width / gridSize * scale;
  final cellHeight = widget.gameSession.canvasInfo.canvasSize.height / gridSize * scale;
  
  return Positioned(
    left: piece.correctCol * cellWidth,
    top: piece.correctRow * cellHeight,
    width: cellWidth,
    height: cellHeight,
    child: Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: Colors.green.withOpacity(0.5),
          width: 2,
        ),
        color: Colors.green.withOpacity(0.1),
      ),
      child: Opacity(
        opacity: 0.3,
        child: _buildPieceImage(piece, fit: BoxFit.contain),
      ),
    ),
  );
}
```

### Phase 2: Improve Visual Representation

#### 2.1 Remove Grid Cell Boundaries

Instead of showing rectangular grid cells, show only subtle grid points:

```dart
class GridPainter extends CustomPainter {
  final int gridSize;
  
  GridPainter({required this.gridSize});
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey[400]!
      ..strokeWidth = 2.0
      ..style = PaintingStyle.fill;
    
    final cellWidth = size.width / gridSize;
    final cellHeight = size.height / gridSize;
    
    // Draw dots at grid intersections instead of lines
    for (int row = 1; row < gridSize; row++) {
      for (int col = 1; col < gridSize; col++) {
        canvas.drawCircle(
          Offset(col * cellWidth, row * cellHeight),
          3.0, // Small dot
          paint,
        );
      }
    }
  }
  
  @override
  bool shouldRepaint(GridPainter oldDelegate) {
    return oldDelegate.gridSize != gridSize;
  }
}
```

#### 2.2 Proper Piece Rendering with Overlaps

When rendering placed pieces, account for their actual bounds:

```dart
Widget _buildPlacedPiece(PuzzlePiece piece, double scale) {
  // Get the actual piece bounds from metadata
  final metadata = widget.gameSession.getPieceMetadata(piece.id);
  
  if (metadata != null && metadata.hasBounds) {
    // Use actual content bounds for positioning
    return Positioned(
      left: metadata.contentBounds.left * scale,
      top: metadata.contentBounds.top * scale,
      width: metadata.contentBounds.width * scale,
      height: metadata.contentBounds.height * scale,
      child: GestureDetector(
        onTap: () => _removePiece(piece),
        child: _buildPieceImage(piece, fit: BoxFit.fill),
      ),
    );
  } else {
    // Fallback to grid-based positioning
    final canvasSize = widget.gameSession.canvasInfo.canvasSize;
    final gridSize = widget.gameSession.gridSize;
    final cellWidth = canvasSize.width / gridSize * scale;
    final cellHeight = canvasSize.height / gridSize * scale;
    
    return Positioned(
      left: piece.correctCol * cellWidth,
      top: piece.correctRow * cellHeight,
      width: cellWidth,
      height: cellHeight,
      child: GestureDetector(
        onTap: () => _removePiece(piece),
        child: _buildPieceImage(piece, fit: BoxFit.contain),
      ),
    );
  }
}
```

### Phase 3: Enhanced Interaction Model

#### 3.1 Workspace-Based Interaction

Instead of discrete drag-and-drop, implement continuous manipulation:

```dart
class WorkspaceInteractionMixin {
  // Track piece being manipulated
  String? _activePieceId;
  Offset? _dragOffset;
  
  void handlePiecePickup(String pieceId, Offset startPosition) {
    _activePieceId = pieceId;
    _dragOffset = startPosition;
    
    // Visual feedback
    HapticFeedback.selectionClick();
  }
  
  void handlePieceDrag(Offset currentPosition) {
    if (_activePieceId == null) return;
    
    // Update piece position in workspace coordinates
    final canvasPosition = screenToCanvas(currentPosition);
    
    // Check proximity to correct position
    final proximity = checkProximityToCorrect(_activePieceId!, canvasPosition);
    
    // Provide graduated feedback
    if (proximity < 0.3) {
      HapticFeedback.heavyImpact(); // Very close
    } else if (proximity < 0.5) {
      HapticFeedback.mediumImpact(); // Getting closer
    } else if (proximity < 0.7) {
      HapticFeedback.lightImpact(); // In vicinity
    }
  }
  
  void handlePieceDrop(Offset dropPosition) {
    if (_activePieceId == null) return;
    
    final canvasPosition = screenToCanvas(dropPosition);
    final placed = tryPlacePiece(_activePieceId!, canvasPosition);
    
    if (placed) {
      HapticFeedback.heavyImpact();
      // Play success sound
    } else {
      // Piece remains floating on workspace
      // User can adjust and try again
    }
    
    _activePieceId = null;
    _dragOffset = null;
  }
}
```

## Implementation Priority

1. **Immediate Fix** (Phase 1.1): Implement proximity-based placement
   - Solves the current blocking issue
   - Minimal code changes
   - Can be tested immediately

2. **Visual Improvements** (Phase 2): Better visual representation
   - Improves user experience
   - Makes piece placement more intuitive
   - Can be done incrementally

3. **Enhanced Interaction** (Phase 3): Full workspace model
   - Long-term improvement
   - Better accessibility
   - More natural interaction

## Testing Checklist

- [ ] Pieces can be placed when dropped near correct position
- [ ] Snap threshold is appropriate for piece size
- [ ] Visual feedback shows where piece will snap
- [ ] Haptic feedback works correctly
- [ ] Pieces with tabs/blanks align properly
- [ ] Grid visualization doesn't interfere with piece shapes
- [ ] Performance remains smooth with large puzzles

## Configuration Options

Add to settings:

```dart
class PuzzleSettings {
  // Snap sensitivity (0.1 = very precise, 0.5 = very forgiving)
  double snapSensitivity = 0.4;
  
  // Show grid lines vs dots
  GridStyle gridStyle = GridStyle.dots;
  
  // Show ghost piece when dragging
  bool showPlacementPreview = true;
  
  // Haptic feedback intensity
  HapticIntensity hapticLevel = HapticIntensity.medium;
}
```

## Conclusion

The core issue is that the current implementation treats puzzle pieces as perfect rectangles that fit exactly into grid cells, when in reality they have irregular shapes with overlapping bounds. The solution is to:

1. Use proximity-based placement instead of rigid grid cells
2. Account for piece tabs/blanks in hit detection
3. Provide better visual and haptic feedback
4. Eventually move to a workspace model where pieces can be freely positioned

This approach maintains the architectural improvements of game_module2 while fixing the immediate usability issue.