// import 'dart:math' as math; // Not used
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../puzzle_game_module2.dart';
import '../../../game_module/puzzle_game_module.dart' show PuzzlePiece;
import '../../../game_module/services/memory_optimized_asset_manager.dart' show MemoryOptimizedPuzzleImage;
import '../../../game_module/services/enhanced_puzzle_asset_manager.dart' show EnhancedCachedPuzzleImage;
import '../../../game_module/services/puzzle_asset_manager.dart' show CachedPuzzleImage;

/// Widget that implements the workspace-based interaction model.
/// 
/// Fixed version 3: Simplified coordinate system with direct grid-based placement
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
  
  // Store canvas scale for calculations
  double _currentScale = 1.0;
  
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
    print('Grid size: ${widget.gameSession.gridSize}x${widget.gameSession.gridSize}');
    print('Canvas size: ${widget.gameSession.canvasInfo.canvasSize}');
    
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
        final canvasSize = widget.gameSession.canvasInfo.canvasSize;
        _currentScale = _calculateCanvasScale(
          Size(canvasSize.width, canvasSize.height),
          constraints.biggest,
        );
        
        return Stack(
          children: [
            // Main canvas area
            _buildCanvas(constraints),
            
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
            
            // Debug info
            if (_isDragging)
              Positioned(
                top: 8,
                left: 8,
                child: _buildDebugInfo(),
              ),
          ],
        );
      },
    );
  }

  Widget _buildDebugInfo() {
    if (_draggedPiece == null) return const SizedBox.shrink();
    
    return Card(
      color: Colors.yellow[100],
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Dragging: ${_draggedPiece!.id}'),
            Text('Target: Row ${_draggedPiece!.correctRow + 1}, Col ${_draggedPiece!.correctCol + 1}'),
            Text('Grid: ${widget.gameSession.gridSize}x${widget.gameSession.gridSize}'),
            Text('Scale: ${_currentScale.toStringAsFixed(3)}'),
          ],
        ),
      ),
    );
  }

  Widget _buildCanvas(BoxConstraints constraints) {
    final canvasSize = widget.gameSession.canvasInfo.canvasSize;
    final gridSize = widget.gameSession.gridSize;
    
    return Center(
      child: Container(
        width: canvasSize.width * _currentScale,
        height: canvasSize.height * _currentScale,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          border: Border.all(
            color: _isDragging ? Colors.green : Colors.grey[400]!,
            width: _isDragging ? 3 : 2,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Grid visualization
            CustomPaint(
              size: Size(canvasSize.width * _currentScale, canvasSize.height * _currentScale),
              painter: GridPainter(
                gridSize: gridSize,
                highlightedRow: _draggedPiece?.correctRow,
                highlightedCol: _draggedPiece?.correctCol,
              ),
            ),
            
            // Placed pieces
            ...widget.gameSession.placedPieces.map((piece) {
              return _buildPlacedPiece(piece);
            }),
            
            // Drop zones for each empty grid position
            for (int row = 0; row < gridSize; row++)
              for (int col = 0; col < gridSize; col++)
                if (!_isPositionOccupied(row, col))
                  _buildDropZone(row, col),
          ],
        ),
      ),
    );
  }

  bool _isPositionOccupied(int row, int col) {
    return widget.gameSession.placedPieces.any(
      (p) => p.correctRow == row && p.correctCol == col,
    );
  }

  Widget _buildDropZone(int row, int col) {
    final canvasSize = widget.gameSession.canvasInfo.canvasSize;
    final gridSize = widget.gameSession.gridSize;
    final cellWidth = canvasSize.width / gridSize * _currentScale;
    final cellHeight = canvasSize.height / gridSize * _currentScale;
    
    return Positioned(
      left: col * cellWidth,
      top: row * cellHeight,
      width: cellWidth,
      height: cellHeight,
      child: DragTarget<PuzzlePiece>(
        onWillAcceptWithDetails: (details) {
          // Accept any piece, but we'll check if it's the right position
          return true;
        },
        onAcceptWithDetails: (details) {
          final piece = details.data;
          
          // Check if this is the correct position for this piece
          if (piece.correctRow == row && piece.correctCol == col) {
            print('✓ CORRECT! Piece ${piece.id} placed at ($row, $col)');
            _placePiece(piece, row, col);
          } else {
            print('✗ Wrong position. Piece ${piece.id} goes to (${piece.correctRow}, ${piece.correctCol}), not ($row, $col)');
            HapticFeedback.lightImpact();
            
            // Show hint
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('This piece goes in row ${piece.correctRow + 1}, column ${piece.correctCol + 1}'),
                duration: const Duration(seconds: 2),
                backgroundColor: Colors.orange,
              ),
            );
          }
        },
        builder: (context, candidateData, rejectedData) {
          final hasCandidate = candidateData.isNotEmpty;
          final piece = hasCandidate ? candidateData.first : null;
          final isCorrectPosition = piece != null && 
                                   piece.correctRow == row && 
                                   piece.correctCol == col;
          
          return Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: hasCandidate 
                    ? (isCorrectPosition ? Colors.green : Colors.red.withOpacity(0.5))
                    : Colors.transparent,
                width: hasCandidate ? 2 : 1,
              ),
              color: hasCandidate
                  ? (isCorrectPosition 
                      ? Colors.green.withOpacity(0.2)
                      : Colors.red.withOpacity(0.1))
                  : Colors.transparent,
            ),
            child: hasCandidate && isCorrectPosition
                ? Center(
                    child: Icon(
                      Icons.check_circle,
                      color: Colors.green.withOpacity(0.5),
                      size: cellWidth * 0.3,
                    ),
                  )
                : null,
          );
        },
      ),
    );
  }

  void _placePiece(PuzzlePiece piece, int row, int col) {
    setState(() {
      final canvasSize = widget.gameSession.canvasInfo.canvasSize;
      final gridSize = widget.gameSession.gridSize;
      final cellWidth = canvasSize.width / gridSize;
      final cellHeight = canvasSize.height / gridSize;
      
      // Place at exact grid position
      final placed = widget.gameSession.tryPlacePieceAt(
        piece,
        col * cellWidth,
        row * cellHeight,
      );
      
      if (placed) {
        HapticFeedback.heavyImpact();
        _workspacePiecePositions.remove(piece.id);
        
        if (widget.gameSession.isCompleted) {
          widget.onGameCompleted?.call();
        }
      }
    });
  }

  Widget _buildPlacedPiece(PuzzlePiece piece) {
    final canvasSize = widget.gameSession.canvasInfo.canvasSize;
    final gridSize = widget.gameSession.gridSize;
    final cellWidth = canvasSize.width / gridSize * _currentScale;
    final cellHeight = canvasSize.height / gridSize * _currentScale;
    
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
              color: Colors.blue.withOpacity(0.5),
              width: 2,
            ),
          ),
          child: Stack(
            children: [
              _buildPieceImage(piece, fit: BoxFit.contain),
              Positioned(
                top: 4,
                left: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '✓',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Pieces: ${sortedPieces.length}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 16),
                Text(
                  'Drag to matching grid position',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
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
    // Determine piece type for coloring
    final gridSize = widget.gameSession.gridSize;
    final isCorner = (piece.correctRow == 0 || piece.correctRow == gridSize - 1) &&
                    (piece.correctCol == 0 || piece.correctCol == gridSize - 1);
    final isEdge = !isCorner && (
      piece.correctRow == 0 || piece.correctRow == gridSize - 1 ||
      piece.correctCol == 0 || piece.correctCol == gridSize - 1
    );
    
    final Color labelColor = isCorner ? Colors.red : (isEdge ? Colors.orange : Colors.blue);
    
    return Draggable<PuzzlePiece>(
      data: piece,
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            border: Border.all(color: labelColor, width: 3),
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
              Positioned(
                bottom: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: labelColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'R${piece.correctRow + 1} C${piece.correctCol + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
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
        child: Center(
          child: Text(
            'R${piece.correctRow + 1}\nC${piece.correctCol + 1}',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
        ),
      ),
      onDragStarted: () {
        setState(() {
          _isDragging = true;
          _draggedPiece = piece;
        });
        HapticFeedback.lightImpact();
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
        });
      },
      child: Container(
        width: 80,
        height: 80,
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          border: Border.all(color: labelColor, width: 2),
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
            Positioned(
              bottom: 2,
              right: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                decoration: BoxDecoration(
                  color: labelColor,
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Text(
                  '${piece.correctRow + 1},${piece.correctCol + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
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
                IconButton(
                  icon: const Icon(Icons.grid_on),
                  onPressed: _showGridInfo,
                  tooltip: 'Grid Info',
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
        _draggedPiece = hint;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Next piece: Row ${hint.correctRow + 1}, Column ${hint.correctCol + 1} '
            '(Look for the piece labeled R${hint.correctRow + 1} C${hint.correctCol + 1})',
          ),
          duration: const Duration(seconds: 4),
          backgroundColor: Colors.green,
        ),
      );
      
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted) {
          setState(() {
            _draggedPiece = null;
          });
        }
      });
    }
  }

  void _showGridInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Grid Information'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Grid Size: ${widget.gameSession.gridSize}x${widget.gameSession.gridSize}'),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.3),
                    border: Border.all(color: Colors.red),
                  ),
                ),
                const SizedBox(width: 8),
                const Text('Corner pieces'),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.3),
                    border: Border.all(color: Colors.orange),
                  ),
                ),
                const SizedBox(width: 8),
                const Text('Edge pieces'),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.3),
                    border: Border.all(color: Colors.blue),
                  ),
                ),
                const SizedBox(width: 8),
                const Text('Middle pieces'),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Each piece shows its position:\nR = Row (1-${15})\nC = Column (1-${15})',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _reset() {
    setState(() {
      for (final piece in widget.gameSession.placedPieces.toList()) {
        widget.gameSession.removePiece(piece);
      }
      _workspacePiecePositions.clear();
      _isDragging = false;
      _draggedPiece = null;
    });
  }

  double _calculateCanvasScale(Size canvasSize, Size availableSize) {
    final adjustedHeight = availableSize.height - 140;
    final scaleX = availableSize.width / canvasSize.width;
    final scaleY = adjustedHeight / canvasSize.height;
    return (scaleX < scaleY ? scaleX : scaleY) * 0.9;
  }
}

/// Custom grid painter with highlighting
class GridPainter extends CustomPainter {
  final int gridSize;
  final int? highlightedRow;
  final int? highlightedCol;

  GridPainter({
    required this.gridSize,
    this.highlightedRow,
    this.highlightedCol,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cellWidth = size.width / gridSize;
    final cellHeight = size.height / gridSize;
    
    // Highlight target cell if dragging
    if (highlightedRow != null && highlightedCol != null) {
      final highlightPaint = Paint()
        ..color = Colors.green.withOpacity(0.2)
        ..style = PaintingStyle.fill;
      
      canvas.drawRect(
        Rect.fromLTWH(
          highlightedCol! * cellWidth,
          highlightedRow! * cellHeight,
          cellWidth,
          cellHeight,
        ),
        highlightPaint,
      );
    }
    
    // Draw grid lines
    final linePaint = Paint()
      ..color = Colors.grey[400]!
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    for (int i = 0; i <= gridSize; i++) {
      // Vertical lines
      canvas.drawLine(
        Offset(i * cellWidth, 0),
        Offset(i * cellWidth, size.height),
        linePaint,
      );
      
      // Horizontal lines
      canvas.drawLine(
        Offset(0, i * cellHeight),
        Offset(size.width, i * cellHeight),
        linePaint,
      );
    }
    
    // Draw row/column labels on edges
    final textStyle = TextStyle(
      color: Colors.grey[600],
      fontSize: 10,
    );
    
    for (int i = 0; i < gridSize; i++) {
      // Column labels (top)
      final colPainter = TextPainter(
        text: TextSpan(text: '${i + 1}', style: textStyle),
        textDirection: TextDirection.ltr,
      );
      colPainter.layout();
      colPainter.paint(
        canvas,
        Offset(i * cellWidth + cellWidth / 2 - colPainter.width / 2, 2),
      );
      
      // Row labels (left)
      final rowPainter = TextPainter(
        text: TextSpan(text: '${i + 1}', style: textStyle),
        textDirection: TextDirection.ltr,
      );
      rowPainter.layout();
      rowPainter.paint(
        canvas,
        Offset(2, i * cellHeight + cellHeight / 2 - rowPainter.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(GridPainter oldDelegate) {
    return oldDelegate.gridSize != gridSize ||
           oldDelegate.highlightedRow != highlightedRow ||
           oldDelegate.highlightedCol != highlightedCol;
  }
}
