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
/// Fixed version 2: Corrects coordinate conversion issues
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
  
  // Canvas render box for coordinate conversion
  GlobalKey _canvasKey = GlobalKey();
  
  @override
  void initState() {
    super.initState();
    _initializeWorkspacePieces();
  }
  
  void _initializeWorkspacePieces() {
    print('=== INITIALIZING WORKSPACE WIDGET ===');
    print('Total pieces: ${widget.gameSession.totalPieces}');
    print('Tray pieces: ${widget.gameSession.trayPieces.length}');
    print('Placed pieces: ${widget.gameSession.placedPieces.length}');
    print('Workspace pieces: ${widget.gameSession.workspacePieces.length}');
    
    for (final piece in widget.gameSession.workspacePieces) {
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
            // Main canvas area
            _buildCanvasArea(constraints),
            
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

  Widget _buildCanvasArea(BoxConstraints constraints) {
    final canvasSize = widget.gameSession.canvasInfo.canvasSize;
    final scale = _calculateCanvasScale(
      Size(canvasSize.width, canvasSize.height),
      constraints.biggest,
    );
    
    return Center(
      child: Container(
        key: _canvasKey,
        width: canvasSize.width * scale,
        height: canvasSize.height * scale,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          border: Border.all(
            color: _isDragging ? Colors.blue : Colors.grey[400]!,
            width: _isDragging ? 3 : 2,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: DragTarget<PuzzlePiece>(
          onWillAcceptWithDetails: (details) => true,
          onAcceptWithDetails: (details) {
            _handlePieceDrop(details.data, details.offset, scale);
          },
          builder: (context, candidateData, rejectedData) {
            return Stack(
              clipBehavior: Clip.none,
              children: [
                // Grid dots for subtle guidance
                CustomPaint(
                  size: Size(canvasSize.width * scale, canvasSize.height * scale),
                  painter: ImprovedGridPainter(
                    gridSize: widget.gameSession.gridSize,
                    showDots: true,
                  ),
                ),
                
                // Placed pieces
                ...widget.gameSession.placedPieces.map((piece) {
                  return _buildPlacedPiece(piece, scale);
                }),
                
                // Ghost preview for the piece being dragged
                if (_isDragging && _draggedPiece != null)
                  _buildGhostPreview(_draggedPiece!, scale),
              ],
            );
          },
        ),
      ),
    );
  }

  void _handlePieceDrop(PuzzlePiece piece, Offset globalDropPosition, double scale) {
    // Get the canvas widget's render box
    final RenderBox? canvasBox = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (canvasBox == null) {
      print('Error: Canvas render box not found');
      return;
    }
    
    // Convert global position to local canvas position
    final localPosition = canvasBox.globalToLocal(globalDropPosition);
    
    // Convert to unscaled canvas coordinates
    final canvasX = localPosition.dx / scale;
    final canvasY = localPosition.dy / scale;
    
    // Clamp to canvas bounds (important for edge pieces)
    final clampedX = canvasX.clamp(0, widget.gameSession.canvasInfo.canvasSize.width);
    final clampedY = canvasY.clamp(0, widget.gameSession.canvasInfo.canvasSize.height);
    
    print('Drop: Global(${globalDropPosition.dx.toStringAsFixed(1)}, ${globalDropPosition.dy.toStringAsFixed(1)}) '
          '-> Local(${localPosition.dx.toStringAsFixed(1)}, ${localPosition.dy.toStringAsFixed(1)}) '
          '-> Canvas(${clampedX.toStringAsFixed(1)}, ${clampedY.toStringAsFixed(1)})');
    
    _tryPlacePieceAtCanvasPosition(piece, clampedX, clampedY);
  }

  void _tryPlacePieceAtCanvasPosition(PuzzlePiece piece, double canvasX, double canvasY) {
    final gridSize = widget.gameSession.gridSize;
    final canvasWidth = widget.gameSession.canvasInfo.canvasSize.width;
    final canvasHeight = widget.gameSession.canvasInfo.canvasSize.height;
    final cellWidth = canvasWidth / gridSize;
    final cellHeight = canvasHeight / gridSize;
    
    // Calculate which grid cell was clicked
    final clickedCol = (canvasX / cellWidth).floor();
    final clickedRow = (canvasY / cellHeight).floor();
    
    // Check if this is the correct cell for this piece
    final isCorrectCell = (clickedCol == piece.correctCol && clickedRow == piece.correctRow);
    
    // Also check adjacent cells (for pieces with tabs that extend)
    final isAdjacentCell = (
      (clickedCol - piece.correctCol).abs() <= 1 && 
      (clickedRow - piece.correctRow).abs() <= 1
    );
    
    // Calculate the piece's correct position center
    final correctCenterX = (piece.correctCol + 0.5) * cellWidth;
    final correctCenterY = (piece.correctRow + 0.5) * cellHeight;
    
    // Calculate distance from drop position to correct position center
    final distance = math.sqrt(
      math.pow(canvasX - correctCenterX, 2) + 
      math.pow(canvasY - correctCenterY, 2)
    );
    
    // Use a very generous snap threshold
    // For edge/corner pieces, be even more generous
    final isEdgePiece = piece.correctCol == 0 || piece.correctCol == gridSize - 1 ||
                       piece.correctRow == 0 || piece.correctRow == gridSize - 1;
    final baseThreshold = math.min(cellWidth, cellHeight);
    final snapThreshold = isEdgePiece ? baseThreshold * 0.75 : baseThreshold * 0.6;
    
    print('Piece ${piece.id} (${piece.correctRow},${piece.correctCol}):');
    print('  Clicked cell: ($clickedRow,$clickedCol) - Correct: $isCorrectCell, Adjacent: $isAdjacentCell');
    print('  Drop at: ($canvasX, $canvasY)');
    print('  Correct center: ($correctCenterX, $correctCenterY)');
    print('  Distance: ${distance.toStringAsFixed(1)}, Threshold: ${snapThreshold.toStringAsFixed(1)}');
    
    setState(() {
      // Accept if in correct cell, adjacent cell with good distance, or within snap threshold
      if (isCorrectCell || (isAdjacentCell && distance <= snapThreshold) || distance <= snapThreshold) {
        // Snap to correct position
        final placed = widget.gameSession.tryPlacePieceAt(
          piece,
          piece.correctCol * cellWidth,
          piece.correctRow * cellHeight,
        );
        
        if (placed) {
          HapticFeedback.heavyImpact();
          _workspacePiecePositions.remove(piece.id);
          
          print('✓ Piece ${piece.id} PLACED successfully!');
          
          if (widget.gameSession.isCompleted) {
            widget.onGameCompleted?.call();
          }
        }
      } else {
        // Not close enough
        HapticFeedback.lightImpact();
        print('✗ Piece ${piece.id} not close enough');
        
        // Show hint about correct position
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Piece goes in row ${piece.correctRow + 1}, column ${piece.correctCol + 1}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      
      // Clear drag state
      _isDragging = false;
      _draggedPiece = null;
      _lastDragPosition = null;
    });
  }

  Widget _buildGhostPreview(PuzzlePiece piece, double scale) {
    final gridSize = widget.gameSession.gridSize;
    final canvasSize = widget.gameSession.canvasInfo.canvasSize;
    final cellWidth = canvasSize.width / gridSize * scale;
    final cellHeight = canvasSize.height / gridSize * scale;
    
    return Positioned(
      left: piece.correctCol * cellWidth,
      top: piece.correctRow * cellHeight,
      width: cellWidth,
      height: cellHeight,
      child: IgnorePointer(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            border: Border.all(
              color: Colors.green.withOpacity(0.8),
              width: 3,
            ),
            borderRadius: BorderRadius.circular(4),
            color: Colors.green.withOpacity(0.15),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Opacity(
                  opacity: 0.4,
                  child: Container(
                    width: cellWidth * 0.8,
                    height: cellHeight * 0.8,
                    child: _buildPieceImage(piece, fit: BoxFit.contain),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${piece.correctRow + 1},${piece.correctCol + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlacedPiece(PuzzlePiece piece, double scale) {
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
      feedback: Material(
        color: Colors.transparent,
        child: Container(
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
          child: Stack(
            children: [
              _buildPieceImage(piece, fit: BoxFit.contain),
              // Show piece position on feedback
              Positioned(
                bottom: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${piece.correctRow + 1},${piece.correctCol + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
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
        child: Stack(
          children: [
            _buildPieceImage(piece, fit: BoxFit.contain),
            // Show position in tray too
            Positioned(
              bottom: 2,
              right: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.grey[700],
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Text(
                  '${piece.correctRow + 1},${piece.correctCol + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                  ),
                ),
              ),
            ),
          ],
        ),
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
          feedback: Material(
            color: Colors.transparent,
            child: Container(
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
          ),
          onDragStarted: () {
            setState(() {
              _isDragging = true;
              _draggedPiece = piece;
            });
          },
          onDragEnd: (details) {
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
      setState(() {
        _draggedPiece = hint; // Highlight the hint piece
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Try piece at position: Row ${hint.correctRow + 1}, Column ${hint.correctCol + 1}'),
          duration: const Duration(seconds: 3),
        ),
      );
      
      // Clear highlight after 3 seconds
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _draggedPiece = null;
          });
        }
      });
    }
  }

  void _reset() {
    setState(() {
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
    final adjustedHeight = availableSize.height - 140;
    final scaleX = availableSize.width / canvasSize.width;
    final scaleY = adjustedHeight / canvasSize.height;
    return (scaleX < scaleY ? scaleX : scaleY) * 0.9;
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
            2.0,
            paint,
          );
        }
      }
      
      // Draw border dots more prominently
      final borderPaint = Paint()
        ..color = Colors.grey[600]!
        ..style = PaintingStyle.fill;
        
      // Top and bottom edges
      for (int col = 0; col <= gridSize; col++) {
        canvas.drawCircle(Offset(col * cellWidth, 0), 3.0, borderPaint);
        canvas.drawCircle(Offset(col * cellWidth, size.height), 3.0, borderPaint);
      }
      
      // Left and right edges
      for (int row = 1; row < gridSize; row++) {
        canvas.drawCircle(Offset(0, row * cellHeight), 3.0, borderPaint);
        canvas.drawCircle(Offset(size.width, row * cellHeight), 3.0, borderPaint);
      }
    } else {
      // Draw grid lines
      final paint = Paint()
        ..color = Colors.grey[300]!
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;

      for (int i = 1; i < gridSize; i++) {
        canvas.drawLine(
          Offset(i * cellWidth, 0),
          Offset(i * cellWidth, size.height),
          paint,
        );
      }

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
