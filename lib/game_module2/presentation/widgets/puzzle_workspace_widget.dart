import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import '../../puzzle_game_module2.dart';
import '../../../game_module/puzzle_game_module.dart' show PuzzlePiece;
import '../../../game_module/services/memory_optimized_asset_manager.dart' show MemoryOptimizedPuzzleImage, OptimizedPieceMetadata;
import '../../../game_module/services/enhanced_puzzle_asset_manager.dart' show EnhancedCachedPuzzleImage, PieceBounds;
import '../../../game_module/services/puzzle_asset_manager.dart' show CachedPuzzleImage;
import '../../domain/value_objects/puzzle_coordinate.dart';
import '../../domain/value_objects/move_result.dart';

/// Widget that implements the workspace-based interaction model.
/// 
/// Version 7: Correctly renders optimized pieces at their proper positions
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
  
  // Debug mode flag
  bool get _showDebugInfo => kDebugMode || const String.fromEnvironment('DEBUG_TOOLS') == 'true';
  
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
    
    // Check if using optimized assets
    if (widget.gameSession.useMemoryOptimization) {
      final isOptimized = widget.gameSession.memoryOptimizedAssetManager.currentPuzzleIsOptimized;
      print('Using optimized assets: $isOptimized');
    }
    
    for (final piece in widget.gameSession.workspacePieces) {
      _workspacePiecePositions[piece.id] = Offset(
        100.0 + (_workspacePiecePositions.length * 50),
        100.0,
      );
    }
  }

  // Get exact piece bounds from metadata or runtime bounds
  Rect? _getPieceExactBounds(String pieceId) {
    try {
      if (widget.gameSession.useMemoryOptimization) {
        final assetManager = widget.gameSession.memoryOptimizedAssetManager;
        
        if (assetManager.currentPuzzleIsOptimized) {
          // Use optimized metadata for exact bounds
          final metadata = assetManager.getPieceMetadata(pieceId);
          if (metadata != null) {
            return metadata.contentBounds;
          }
        } else {
          // For non-optimized, we shouldn't use them anymore
          // Fall back to grid positioning
          return null;
        }
      }
    } catch (e) {
      print('Could not get exact bounds for piece $pieceId: $e');
    }
    return null;
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
            
            // Debug info (only in debug mode)
            if (_showDebugInfo && _isDragging)
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
      color: Colors.yellow[100]!.withOpacity(0.9),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('DEBUG: Dragging ${_draggedPiece!.id}'),
            Text('Target: R${_draggedPiece!.correctRow + 1}, C${_draggedPiece!.correctCol + 1}'),
            Text('Scale: ${_currentScale.toStringAsFixed(3)}'),
            if (widget.gameSession.useMemoryOptimization)
              Text('Optimized: ${widget.gameSession.memoryOptimizedAssetManager.currentPuzzleIsOptimized}'),
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
          color: Colors.white,
          border: Border.all(
            color: Colors.grey[300]!,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(7),
          child: Stack(
            clipBehavior: Clip.none, // Allow pieces to extend beyond bounds
            children: [
              // Subtle grid dots only in debug mode
              if (_showDebugInfo)
                CustomPaint(
                  size: Size(canvasSize.width * _currentScale, canvasSize.height * _currentScale),
                  painter: SubtleGridPainter(
                    gridSize: gridSize,
                    highlightedRow: _draggedPiece?.correctRow,
                    highlightedCol: _draggedPiece?.correctCol,
                  ),
                ),
              
              // Placed pieces with exact positioning from metadata
              ...widget.gameSession.placedPieces.map((piece) {
                return _buildPlacedPieceOptimized(piece);
              }),
              
              // Drop zones for each empty grid position
              for (int row = 0; row < gridSize; row++)
                for (int col = 0; col < gridSize; col++)
                  if (!_isPositionOccupied(row, col))
                    _buildDropZone(row, col),
            ],
          ),
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
          return true;
        },
        onAcceptWithDetails: (details) {
          final piece = details.data;
          
          if (piece.correctRow == row && piece.correctCol == col) {
            print('✓ CORRECT! Piece ${piece.id} placed at ($row, $col)');
            _placePieceDirectly(piece, row, col);
          } else {
            print('✗ Wrong position. Piece ${piece.id} goes to (${piece.correctRow}, ${piece.correctCol}), not ($row, $col)');
            HapticFeedback.lightImpact();
            
            if (!_showDebugInfo) {
              // Only show hint in non-debug mode
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Try another position'),
                  duration: const Duration(seconds: 1),
                  backgroundColor: Colors.orange,
                ),
              );
            }
          }
        },
        builder: (context, candidateData, rejectedData) {
          final hasCandidate = candidateData.isNotEmpty;
          final piece = hasCandidate ? candidateData.first : null;
          final isCorrectPosition = piece != null && 
                                   piece.correctRow == row && 
                                   piece.correctCol == col;
          
          // Only show visual feedback in debug mode or when correct
          if (!_showDebugInfo && !isCorrectPosition) {
            return const SizedBox.shrink();
          }
          
          return Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: hasCandidate 
                    ? (isCorrectPosition ? Colors.green.withOpacity(0.5) : Colors.red.withOpacity(0.3))
                    : Colors.transparent,
                width: hasCandidate ? 2 : 0,
              ),
              color: hasCandidate && isCorrectPosition
                  ? Colors.green.withOpacity(0.1)
                  : Colors.transparent,
            ),
          );
        },
      ),
    );
  }

  void _placePieceDirectly(PuzzlePiece piece, int row, int col) {
    setState(() {
      final workspace = widget.gameSession.workspaceController.workspace!;
      final domainPiece = workspace.pieces.firstWhere((p) => p.id == piece.id);
      
      final cellWidth = workspace.canvasSize.width / widget.gameSession.gridSize;
      final cellHeight = workspace.canvasSize.height / widget.gameSession.gridSize;
      
      final correctPosition = PuzzleCoordinate(
        x: col * cellWidth,
        y: row * cellHeight,
      );
      
      print('Placing piece ${piece.id} at position ($correctPosition)');
      
      final result = workspace.movePiece(piece.id, correctPosition);
      
      print('Move result: ${result.type}');
      
      if (result.type == MoveResultType.snapped) {
        HapticFeedback.heavyImpact();
        _workspacePiecePositions.remove(piece.id);
        
        widget.gameSession.workspaceController.notifyListeners();
        
        print('✓ Piece ${piece.id} successfully placed!');
        
        if (workspace.isCompleted) {
          print('🎉 PUZZLE COMPLETED!');
          widget.onGameCompleted?.call();
        }
      }
    });
  }

  Widget _buildPlacedPieceOptimized(PuzzlePiece piece) {
    // For optimized assets, we use the MemoryOptimizedPuzzleImage widget
    // which handles the positioning internally using the metadata
    if (widget.gameSession.useMemoryOptimization && 
        widget.gameSession.memoryOptimizedAssetManager.currentPuzzleIsOptimized) {
      
      // Get the metadata to know where to position this piece
      final metadata = widget.gameSession.memoryOptimizedAssetManager.getPieceMetadata(piece.id);
      
      if (metadata != null) {
        // The metadata contains the position on the original 2048x2048 canvas
        // We need to position the cropped image at these coordinates
        return Positioned(
          left: metadata.contentBounds.left * _currentScale,
          top: metadata.contentBounds.top * _currentScale,
          width: metadata.contentBounds.width * _currentScale,
          height: metadata.contentBounds.height * _currentScale,
          child: GestureDetector(
            onTap: _showDebugInfo ? () => _removePiece(piece) : null,
            child: MemoryOptimizedPuzzleImage(
              pieceId: piece.id,
              assetManager: piece.memoryOptimizedAssetManager,
              fit: BoxFit.fill,
              cropToContent: false, // Use the full cropped image
            ),
          ),
        );
      }
    }
    
    // Fallback for non-optimized assets (which we should avoid using)
    final canvasSize = widget.gameSession.canvasInfo.canvasSize;
    final gridSize = widget.gameSession.gridSize;
    final cellWidth = canvasSize.width / gridSize * _currentScale;
    final cellHeight = canvasSize.height / gridSize * _currentScale;
    
    // For non-optimized, just use grid positioning
    // But we should really only use optimized assets
    return Positioned(
      left: piece.correctCol * cellWidth,
      top: piece.correctRow * cellHeight,
      width: cellWidth,
      height: cellHeight,
      child: GestureDetector(
        onTap: _showDebugInfo ? () => _removePiece(piece) : null,
        child: Container(
          color: Colors.red.withOpacity(0.3), // Red to indicate we're using fallback
          child: Center(
            child: Text(
              'Non-optimized\n${piece.id}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 10),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPieceTray() {
    final sortedPieces = widget.gameSession.sortedTrayPieces;
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.grey[100]!,
            Colors.grey[200]!,
          ],
        ),
        border: Border(
          top: BorderSide(color: Colors.grey[300]!, width: 1),
        ),
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
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Text(
              '${sortedPieces.length} pieces remaining',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
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
    // Determine piece type for subtle coloring
    final gridSize = widget.gameSession.gridSize;
    final isCorner = (piece.correctRow == 0 || piece.correctRow == gridSize - 1) &&
                    (piece.correctCol == 0 || piece.correctCol == gridSize - 1);
    final isEdge = !isCorner && (
      piece.correctRow == 0 || piece.correctRow == gridSize - 1 ||
      piece.correctCol == 0 || piece.correctCol == gridSize - 1
    );
    
    // Subtle color coding
    final Color borderColor = isCorner 
        ? Colors.blue[400]! 
        : (isEdge ? Colors.blue[300]! : Colors.grey[400]!);
    
    return Draggable<PuzzlePiece>(
      data: piece,
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.blue, width: 2),
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
          child: _buildPieceImage(piece, fit: BoxFit.contain, inTray: true),
        ),
      ),
      childWhenDragging: Container(
        width: 80,
        height: 80,
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(4),
          color: Colors.grey[100],
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
          border: Border.all(color: borderColor, width: 1.5),
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
            _buildPieceImage(piece, fit: BoxFit.contain, inTray: true),
            // Only show position labels in debug mode
            if (_showDebugInfo)
              Positioned(
                bottom: 2,
                right: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                  decoration: BoxDecoration(
                    color: borderColor.withOpacity(0.8),
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
              child: _buildPieceImage(piece, fit: BoxFit.contain, inTray: true),
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
            child: _buildPieceImage(piece, fit: BoxFit.contain, inTray: true),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildPieceImage(PuzzlePiece piece, {BoxFit fit = BoxFit.cover, bool inTray = false}) {
    if (widget.gameSession.useMemoryOptimization) {
      return MemoryOptimizedPuzzleImage(
        pieceId: piece.id,
        assetManager: piece.memoryOptimizedAssetManager,
        fit: fit,
        cropToContent: inTray, // Crop to content in tray, show full when placed
      );
    } else if (widget.gameSession.useEnhancedRendering) {
      return EnhancedCachedPuzzleImage(
        pieceId: piece.id,
        assetManager: piece.enhancedAssetManager,
        fit: fit,
        cropToContent: inTray,
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
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Text(
              '${widget.gameSession.piecesPlaced}/${widget.gameSession.totalPieces}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
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
                if (_showDebugInfo)
                  IconButton(
                    icon: const Icon(Icons.bug_report),
                    onPressed: _toggleDebugInfo,
                    tooltip: 'Debug Info',
                    color: Colors.orange,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _toggleDebugInfo() {
    // This would toggle debug visualization if we had a local flag
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Debug mode is enabled'),
        duration: Duration(seconds: 1),
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
            _showDebugInfo 
                ? 'Next piece: Row ${hint.correctRow + 1}, Column ${hint.correctCol + 1}'
                : 'Try a corner or edge piece!',
          ),
          duration: const Duration(seconds: 3),
          backgroundColor: Colors.green,
        ),
      );
      
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
    });
  }

  double _calculateCanvasScale(Size canvasSize, Size availableSize) {
    final adjustedHeight = availableSize.height - 140;
    final scaleX = availableSize.width / canvasSize.width;
    final scaleY = adjustedHeight / canvasSize.height;
    return (scaleX < scaleY ? scaleX : scaleY) * 0.9;
  }
}

/// Subtle grid painter for debug mode only
class SubtleGridPainter extends CustomPainter {
  final int gridSize;
  final int? highlightedRow;
  final int? highlightedCol;

  SubtleGridPainter({
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
        ..color = Colors.green.withOpacity(0.15)
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
      
      // Draw border around highlighted cell
      final borderPaint = Paint()
        ..color = Colors.green.withOpacity(0.5)
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;
      
      canvas.drawRect(
        Rect.fromLTWH(
          highlightedCol! * cellWidth,
          highlightedRow! * cellHeight,
          cellWidth,
          cellHeight,
        ),
        borderPaint,
      );
    }
    
    // Draw subtle dots at grid intersections
    final dotPaint = Paint()
      ..color = Colors.grey[300]!
      ..style = PaintingStyle.fill;
    
    for (int row = 1; row < gridSize; row++) {
      for (int col = 1; col < gridSize; col++) {
        canvas.drawCircle(
          Offset(col * cellWidth, row * cellHeight),
          1.5,
          dotPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(SubtleGridPainter oldDelegate) {
    return oldDelegate.gridSize != gridSize ||
           oldDelegate.highlightedRow != highlightedRow ||
           oldDelegate.highlightedCol != highlightedCol;
  }
}
