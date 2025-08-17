import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../puzzle_game_module2.dart';
import '../../../game_module/puzzle_game_module.dart' show PuzzlePiece;
import '../../../game_module/services/memory_optimized_asset_manager.dart' show MemoryOptimizedPuzzleImage;
import '../../../game_module/services/enhanced_puzzle_asset_manager.dart' show EnhancedCachedPuzzleImage;
import '../../../game_module/services/puzzle_asset_manager.dart' show CachedPuzzleImage;

/// Widget that implements the workspace-based interaction model.
/// 
/// This widget replaces the flawed drop zone approach with proper
/// piece positioning and proximity-based snapping.
class PuzzleWorkspaceWidget extends StatefulWidget {
  final PuzzleGameSession2 gameSession;
  final VoidCallback? onGameCompleted;

  const PuzzleWorkspaceWidget({
    super.key,
    required this.gameSession,
    this.onGameCompleted,
  });

  @override
  State<PuzzleWorkspaceWidget> createState() => _PuzzleWorkspaceWidgetState();
}

class _PuzzleWorkspaceWidgetState extends State<PuzzleWorkspaceWidget> {
  // Track pieces on workspace
  final Map<String, Offset> _workspacePiecePositions = {};
  
  // Track dragging state
  PuzzlePiece? _draggedPiece;
  bool _isDragging = false;
  Offset? _lastDragPosition;
  
  @override
  void initState() {
    super.initState();
    // Initialize workspace piece positions
    _initializeWorkspacePieces();
  }
  
  void _initializeWorkspacePieces() {
    // Debug: Check piece states
    print('=== INITIALIZING WORKSPACE WIDGET ===');
    print('Total pieces: ${widget.gameSession.totalPieces}');
    print('Tray pieces: ${widget.gameSession.trayPieces.length}');
    print('Placed pieces: ${widget.gameSession.placedPieces.length}');
    print('Workspace pieces: ${widget.gameSession.workspacePieces.length}');
    
    // Place any pieces that are already on the workspace
    for (final piece in widget.gameSession.workspacePieces) {
      // Spread them out initially
      _workspacePiecePositions[piece.id] = Offset(
        100.0 + (_workspacePiecePositions.length * 50),
        100.0,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            // Main canvas area with single drop target
            _buildCanvasWithDropTarget(constraints),
            
            // Piece tray at bottom
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 120,
              child: _buildPieceTray(),
            ),
            
            // Floating workspace pieces
            ..._buildWorkspacePieces(constraints),
            
            // Control buttons
            Positioned(
              top: 8,
              right: 8,
              child: _buildControls(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCanvasWithDropTarget(BoxConstraints constraints) {
    final canvasSize = widget.gameSession.canvasInfo.canvasSize;
    final scale = _calculateCanvasScale(
      Size(canvasSize.width, canvasSize.height),
      constraints.biggest,
    );
    
    return Center(
      child: DragTarget<PuzzlePiece>(
        // Accept drops anywhere on canvas
        onWillAcceptWithDetails: (details) => true,
        onAcceptWithDetails: (details) {
          _handlePieceDrop(details.data, details.offset, scale);
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
              clipBehavior: Clip.none,
              children: [
                // Grid dots for subtle guidance
                CustomPaint(
                  size: Size(canvasSize.width * scale, canvasSize.height * scale),
                  painter: ImprovedGridPainter(
                    gridSize: widget.gameSession.gridSize,
                    showDots: true, // Use dots instead of lines
                  ),
                ),
                
                // Placed pieces with proper positioning
                ...widget.gameSession.placedPieces.map((piece) {
                  return _buildPlacedPieceWithBounds(piece, scale);
                }),
                
                // Ghost preview when dragging near correct position
                if (_isDragging && _draggedPiece != null)
                  _buildGhostPreview(_draggedPiece!, scale),
              ],
            ),
          );
        },
      ),
    );
  }

  void _handlePieceDrop(PuzzlePiece piece, Offset dropOffset, double scale) {
    // Get the canvas widget's position
    final RenderBox? canvasBox = context.findRenderObject() as RenderBox?;
    if (canvasBox == null) return;
    
    // Convert global drop position to local canvas position
    final globalDropPosition = dropOffset;
    final localPosition = canvasBox.globalToLocal(globalDropPosition);
    
    // Get canvas center position on screen
    final canvasCenter = canvasBox.localToGlobal(
      Offset(canvasBox.size.width / 2, canvasBox.size.height / 2)
    );
    
    // Calculate the canvas bounds
    final canvasSize = widget.gameSession.canvasInfo.canvasSize;
    final scaledCanvasWidth = canvasSize.width * scale;
    final scaledCanvasHeight = canvasSize.height * scale;
    
    // Calculate drop position relative to canvas origin
    final canvasOriginX = canvasCenter.dx - scaledCanvasWidth / 2;
    final canvasOriginY = canvasCenter.dy - scaledCanvasHeight / 2;
    
    final relativeX = globalDropPosition.dx - canvasOriginX;
    final relativeY = globalDropPosition.dy - canvasOriginY;
    
    // Convert to canvas coordinates (unscaled)
    final canvasX = relativeX / scale;
    final canvasY = relativeY / scale;
    
    print('Drop position - Canvas: ($canvasX, $canvasY), Scale: $scale');
    
    // Try to place piece at this position
    _tryPlacePieceAtCanvasPosition(piece, canvasX, canvasY);
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
    
    // Use a generous snap threshold (50% of cell size to account for tabs)
    final snapThreshold = math.min(cellWidth, cellHeight) * 0.5;
    
    print('Piece ${piece.id} - Correct: ($correctCenterX, $correctCenterY), Distance: $distance, Threshold: $snapThreshold');
    
    setState(() {
      if (distance <= snapThreshold) {
        // Snap to correct position
        final placed = widget.gameSession.tryPlacePieceAt(
          piece,
          piece.correctCol * cellWidth,
          piece.correctRow * cellHeight,
        );
        
        if (placed) {
          HapticFeedback.heavyImpact();
          _workspacePiecePositions.remove(piece.id);
          
          print('Piece ${piece.id} placed successfully!');
          
          if (widget.gameSession.isCompleted) {
            widget.onGameCompleted?.call();
          }
        }
      } else {
        // Piece not close enough - return to tray or workspace
        HapticFeedback.lightImpact();
        print('Piece ${piece.id} not close enough to correct position');
      }
      
      // Clear drag state
      _isDragging = false;
      _draggedPiece = null;
      _lastDragPosition = null;
    });
  }

  Widget _buildGhostPreview(PuzzlePiece piece, double scale) {
    if (_lastDragPosition == null) return const SizedBox.shrink();
    
    final gridSize = widget.gameSession.gridSize;
    final canvasSize = widget.gameSession.canvasInfo.canvasSize;
    final cellWidth = canvasSize.width / gridSize * scale;
    final cellHeight = canvasSize.height / gridSize * scale;
    
    // Check if piece is near its correct position
    // This is a simplified check - you might want to use actual drag position
    final correctCenterX = (piece.correctCol + 0.5) * cellWidth;
    final correctCenterY = (piece.correctRow + 0.5) * cellHeight;
    
    return Positioned(
      left: piece.correctCol * cellWidth,
      top: piece.correctRow * cellHeight,
      width: cellWidth,
      height: cellHeight,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          border: Border.all(
            color: Colors.green.withOpacity(0.6),
            width: 3,
          ),
          borderRadius: BorderRadius.circular(4),
          color: Colors.green.withOpacity(0.1),
        ),
        child: Center(
          child: Opacity(
            opacity: 0.3,
            child: _buildPieceImage(piece, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }

  Widget _buildPlacedPieceWithBounds(PuzzlePiece piece, double scale) {
    final canvasSize = widget.gameSession.canvasInfo.canvasSize;
    final gridSize = widget.gameSession.gridSize;
    final cellWidth = canvasSize.width / gridSize * scale;
    final cellHeight = canvasSize.height / gridSize * scale;
    
    // For now, use grid-based positioning
    // TODO: Get actual bounds from metadata when available
    return Positioned(
      left: piece.correctCol * cellWidth,
      top: piece.correctRow * cellHeight,
      width: cellWidth,
      height: cellHeight,
      child: GestureDetector(
        onTap: () => _removePiece(piece),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: Colors.blue.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: _buildPieceImage(piece, fit: BoxFit.contain),
        ),
      ),
    );
  }

  Widget _buildPieceTray() {
    final sortedPieces = widget.gameSession.sortedTrayPieces;
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[200],
        border: Border.all(color: Colors.grey[400]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(4.0),
            child: Text(
              'Piece Tray (${sortedPieces.length} pieces)',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              itemCount: sortedPieces.length,
              itemBuilder: (context, index) {
                final piece = sortedPieces[index];
                return _buildTrayPiece(piece);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrayPiece(PuzzlePiece piece) {
    return Draggable<PuzzlePiece>(
      data: piece,
      feedback: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.blue, width: 3),
          borderRadius: BorderRadius.circular(8),
          color: Colors.white.withOpacity(0.95),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(2, 2),
            ),
          ],
        ),
        child: _buildPieceImage(piece, fit: BoxFit.contain),
      ),
      childWhenDragging: Container(
        width: 80,
        height: 80,
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(4),
          color: Colors.grey[300],
        ),
      ),
      onDragStarted: () {
        setState(() {
          _isDragging = true;
          _draggedPiece = piece;
        });
        HapticFeedback.lightImpact();
      },
      onDragEnd: (details) {
        setState(() {
          _lastDragPosition = details.offset;
        });
      },
      onDragCompleted: () {
        setState(() {
          _isDragging = false;
          _draggedPiece = null;
        });
      },
      onDraggableCanceled: (velocity, offset) {
        setState(() {
          _isDragging = false;
          _draggedPiece = null;
          _lastDragPosition = null;
        });
      },
      child: Container(
        width: 80,
        height: 80,
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(4),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 2,
              offset: const Offset(1, 1),
            ),
          ],
        ),
        child: _buildPieceImage(piece, fit: BoxFit.contain),
      ),
    );
  }

  List<Widget> _buildWorkspacePieces(BoxConstraints constraints) {
    return _workspacePiecePositions.entries.map((entry) {
      final pieceId = entry.key;
      final position = entry.value;
      final piece = widget.gameSession.pieces.firstWhere((p) => p.id == pieceId);
      
      return Positioned(
        left: position.dx,
        top: position.dy,
        child: Draggable<PuzzlePiece>(
          data: piece,
          feedback: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.blue, width: 3),
              borderRadius: BorderRadius.circular(8),
              color: Colors.white.withOpacity(0.95),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(2, 2),
                ),
              ],
            ),
            child: _buildPieceImage(piece, fit: BoxFit.contain),
          ),
          onDragStarted: () {
            setState(() {
              _isDragging = true;
              _draggedPiece = piece;
            });
          },
          onDragEnd: (details) {
            // Update piece position
            setState(() {
              _workspacePiecePositions[pieceId] = details.offset;
              _lastDragPosition = details.offset;
            });
          },
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.blue),
              borderRadius: BorderRadius.circular(4),
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 2,
                  offset: const Offset(1, 1),
                ),
              ],
            ),
            child: _buildPieceImage(piece, fit: BoxFit.contain),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildPieceImage(PuzzlePiece piece, {BoxFit fit = BoxFit.cover}) {
    // Use the appropriate asset manager based on settings
    if (widget.gameSession.useMemoryOptimization) {
      return MemoryOptimizedPuzzleImage(
        pieceId: piece.id,
        assetManager: piece.memoryOptimizedAssetManager,
        fit: fit,
        cropToContent: true,
      );
    } else if (widget.gameSession.useEnhancedRendering) {
      return EnhancedCachedPuzzleImage(
        pieceId: piece.id,
        assetManager: piece.enhancedAssetManager,
        fit: fit,
        cropToContent: true,
      );
    } else {
      return CachedPuzzleImage(
        pieceId: piece.id,
        assetManager: piece.assetManager,
        fit: fit,
      );
    }
  }

  Widget _buildControls() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Text(
              '${widget.gameSession.piecesPlaced}/${widget.gameSession.totalPieces}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.lightbulb_outline),
                  onPressed: _requestHint,
                  tooltip: 'Hint',
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _reset,
                  tooltip: 'Reset',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _removePiece(PuzzlePiece piece) {
    setState(() {
      widget.gameSession.removePiece(piece);
      HapticFeedback.lightImpact();
    });
  }

  void _requestHint() {
    final hint = widget.gameSession.getHint();
    if (hint != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Try piece ${hint.id} at position (${hint.correctRow + 1}, ${hint.correctCol + 1})'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _reset() {
    setState(() {
      // Reset all pieces to tray
      for (final piece in widget.gameSession.placedPieces.toList()) {
        widget.gameSession.removePiece(piece);
      }
      _workspacePiecePositions.clear();
      _isDragging = false;
      _draggedPiece = null;
      _lastDragPosition = null;
    });
  }

  double _calculateCanvasScale(Size canvasSize, Size availableSize) {
    // Leave room for the tray
    final adjustedHeight = availableSize.height - 140;
    final scaleX = availableSize.width / canvasSize.width;
    final scaleY = adjustedHeight / canvasSize.height;
    return (scaleX < scaleY ? scaleX : scaleY) * 0.9; // 90% to add padding
  }
}

/// Improved grid painter with dots option
class ImprovedGridPainter extends CustomPainter {
  final int gridSize;
  final bool showDots;

  ImprovedGridPainter({
    required this.gridSize,
    this.showDots = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cellWidth = size.width / gridSize;
    final cellHeight = size.height / gridSize;

    if (showDots) {
      // Draw dots at grid intersections
      final paint = Paint()
        ..color = Colors.grey[400]!
        ..style = PaintingStyle.fill;
      
      for (int row = 1; row < gridSize; row++) {
        for (int col = 1; col < gridSize; col++) {
          canvas.drawCircle(
            Offset(col * cellWidth, row * cellHeight),
            2.0, // Small dot
            paint,
          );
        }
      }
    } else {
      // Draw grid lines
      final paint = Paint()
        ..color = Colors.grey[300]!
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;

      // Draw vertical lines
      for (int i = 1; i < gridSize; i++) {
        canvas.drawLine(
          Offset(i * cellWidth, 0),
          Offset(i * cellWidth, size.height),
          paint,
        );
      }

      // Draw horizontal lines
      for (int i = 1; i < gridSize; i++) {
        canvas.drawLine(
          Offset(0, i * cellHeight),
          Offset(size.width, i * cellHeight),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(ImprovedGridPainter oldDelegate) {
    return oldDelegate.gridSize != gridSize || oldDelegate.showDots != showDots;
  }
}
