import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import '../../puzzle_game_module2.dart';
import '../../../game_module/puzzle_game_module.dart' show PuzzlePiece;
import '../../../game_module/services/memory_optimized_asset_manager.dart' show MemoryOptimizedPuzzleImage;
import '../../../game_module/services/puzzle_asset_manager.dart' show CachedPuzzleImage;

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
  
  // GlobalKey for overlay Stack to convert coordinates
  final GlobalKey _overlayKey = GlobalKey();
  
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

  /// Convert global drag position to local Stack coordinates
  Offset _globalToLocal(Offset globalPosition) {
    final RenderBox? overlayBox = _overlayKey.currentContext?.findRenderObject() as RenderBox?;
    if (overlayBox != null) {
      // Convert global position to local Stack coordinates
      final localPosition = overlayBox.globalToLocal(globalPosition);
      // Account for scale when converting positions
      return localPosition;
    }
    // Fallback to global position if conversion fails
    return globalPosition;
  }
  
  /// Convert local position to canvas coordinates accounting for scale
  Offset _localToCanvas(Offset localPosition) {
    // Divide by current scale to get actual canvas coordinates
    return Offset(
      localPosition.dx / _currentScale,
      localPosition.dy / _currentScale,
    );
  }
  
  /// Handle piece drop with proper coordinate conversion
  void _handlePieceDrop(DragTargetDetails<PuzzlePiece> details, int row, int col) {
    final piece = details.data;
    
    // Convert global position to local Stack coordinates
    final localPosition = _globalToLocal(details.offset);
    
    // Convert to canvas coordinates accounting for scale
    final canvasPosition = _localToCanvas(localPosition);
    
    // Store position for workspace pieces if needed
    if (_workspacePiecePositions.containsKey(piece.id)) {
      _workspacePiecePositions[piece.id] = localPosition;
    }
    
    // Process the drop
    if (piece.correctRow == row && piece.correctCol == col) {
      print('✓ CORRECT! Piece ${piece.id} placed at ($row, $col)');
      print('  Drop position: local=$localPosition, canvas=$canvasPosition');
      _placePieceDirectly(piece, row, col);
    } else {
      print('✗ Wrong position. Piece ${piece.id} goes to (${piece.correctRow}, ${piece.correctCol})');
      HapticFeedback.lightImpact();
      
      if (!_showDebugInfo) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Try another position'),
            duration: Duration(seconds: 1),
            backgroundColor: Colors.orange,
          ),
        );
      }
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
        
        // Calculate dynamic tray height based on largest piece height
        double maxPieceHeight = 100; // Default
        if (widget.gameSession.useMemoryOptimization && 
            widget.gameSession.memoryOptimizedAssetManager.currentPuzzleIsOptimized) {
          // Find the tallest piece to determine tray height
          for (final piece in widget.gameSession.trayPieces) {
            final metadata = widget.gameSession.memoryOptimizedAssetManager.getPieceMetadata(piece.id);
            if (metadata != null) {
              final height = metadata.contentBounds.height * _currentScale;
              // Cap at 100 for practical display
              maxPieceHeight = math.max(maxPieceHeight, math.min(height, 100));
            }
          }
        }
        final trayHeight = maxPieceHeight + 40; // Add padding for labels
        
        return Stack(
          key: _overlayKey,
          children: [
            // Main canvas area
            _buildCanvas(constraints),
            
            // Piece tray at bottom
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: trayHeight.clamp(120, 150), // Min 120, max 150
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
          _handlePieceDrop(details, row, col);
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
                width: 2,
              ),
              borderRadius: BorderRadius.circular(4),
              color: hasCandidate && isCorrectPosition 
                  ? Colors.green.withOpacity(0.1)
                  : Colors.transparent,
            ),
          );
        },
      ),
    );
  }

  /// Build workspace pieces that can be dragged around
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
          feedback: _buildDragFeedback(piece),
          childWhenDragging: Container(
            width: 80,
            height: 80,
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
          onDragEnd: (details) {
            // FIXED: Convert global coordinates to local Stack coordinates
            final RenderBox? overlayBox = _overlayKey.currentContext?.findRenderObject() as RenderBox?;
            if (overlayBox != null) {
              // Properly convert to local coordinates
              final localPosition = overlayBox.globalToLocal(details.offset);
              setState(() {
                _workspacePiecePositions[pieceId] = localPosition;
              });
            } else {
              // Fallback if we can't get the overlay box
              setState(() {
                _workspacePiecePositions[pieceId] = details.offset;
              });
            }
          },
          onDragCompleted: () {
            setState(() {
              _isDragging = false;
              _draggedPiece = null;
            });
          },
          onDraggableCanceled: (velocity, offset) {
            // FIXED: Convert global offset to local coordinates
            final RenderBox? overlayBox = _overlayKey.currentContext?.findRenderObject() as RenderBox?;
            if (overlayBox != null) {
              final localPosition = overlayBox.globalToLocal(offset);
              setState(() {
                _workspacePiecePositions[pieceId] = localPosition;
                _isDragging = false;
                _draggedPiece = null;
              });
            } else {
              setState(() {
                _workspacePiecePositions[pieceId] = offset;
                _isDragging = false;
                _draggedPiece = null;
              });
            }
          },
          child: _buildWorkspacePiece(piece),
        ),
      );
    }).toList();
  }
  
  /// Build the tray with draggable pieces
  Widget _buildPieceTray() {
    final sortedPieces = widget.gameSession.sortedTrayPieces;
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              'Pieces (${sortedPieces.length})',
              style: const TextStyle(fontWeight: FontWeight.bold),
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
  
  /// Build a single tray piece
  Widget _buildTrayPiece(PuzzlePiece piece) {
    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: Draggable<PuzzlePiece>(
        data: piece,
        feedback: _buildDragFeedback(piece),
        childWhenDragging: Container(
          width: 80,
          height: 80,
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
        onDragEnd: (details) {
          setState(() {
            _isDragging = false;
            _draggedPiece = null;
          });
        },
        onDragCompleted: () {
          setState(() {
            _isDragging = false;
            _draggedPiece = null;
          });
        },
        child: _buildTrayPieceDisplay(piece),
      ),
    );
  }
  
  /// Build drag feedback widget
  Widget _buildDragFeedback(PuzzlePiece piece) {
    return Container(
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
    );
  }
  
  /// Build workspace piece display
  Widget _buildWorkspacePiece(PuzzlePiece piece) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.blue[300]!),
        borderRadius: BorderRadius.circular(4),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(1, 1),
          ),
        ],
      ),
      child: _buildPieceImage(piece, fit: BoxFit.contain, inTray: false),
    );
  }
  
  /// Build tray piece display
  Widget _buildTrayPieceDisplay(PuzzlePiece piece) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[400]!),
        borderRadius: BorderRadius.circular(4),
        color: Colors.white,
      ),
      child: _buildPieceImage(piece, fit: BoxFit.contain, inTray: true),
    );
  }
  
  /// Build placed piece on canvas with optimized positioning
  Widget _buildPlacedPieceOptimized(PuzzlePiece piece) {
    final canvasSize = widget.gameSession.canvasInfo.canvasSize;
    final gridSize = widget.gameSession.gridSize;
    final cellWidth = canvasSize.width / gridSize * _currentScale;
    final cellHeight = canvasSize.height / gridSize * _currentScale;
    
    // Get exact bounds if available
    final exactBounds = _getPieceExactBounds(piece.id);
    
    if (exactBounds != null && widget.gameSession.useMemoryOptimization) {
      // Use exact positioning from metadata
      return Positioned(
        left: exactBounds.left * _currentScale,
        top: exactBounds.top * _currentScale,
        width: exactBounds.width * _currentScale,
        height: exactBounds.height * _currentScale,
        child: GestureDetector(
          onTap: () => _removePiece(piece),
          child: _buildPieceImage(piece, fit: BoxFit.fill, inTray: false),
        ),
      );
    } else {
      // Fallback to grid-based positioning
      return Positioned(
        left: piece.correctCol * cellWidth,
        top: piece.correctRow * cellHeight,
        width: cellWidth,
        height: cellHeight,
        child: GestureDetector(
          onTap: () => _removePiece(piece),
          child: _buildPieceImage(piece, fit: BoxFit.contain, inTray: false),
        ),
      );
    }
  }
  
  /// Place a piece directly at its correct position
  void _placePieceDirectly(PuzzlePiece piece, int row, int col) {
    setState(() {
      // Remove from workspace if it was there
      _workspacePiecePositions.remove(piece.id);
      
      // Place the piece
      final placed = widget.gameSession.tryPlacePieceAt(
        piece,
        col * (widget.gameSession.canvasInfo.canvasSize.width / widget.gameSession.gridSize),
        row * (widget.gameSession.canvasInfo.canvasSize.height / widget.gameSession.gridSize),
      );
      
      if (placed) {
        HapticFeedback.heavyImpact();
        print('✓ Piece ${piece.id} successfully placed!');
        
        // Check if puzzle is completed
        if (widget.gameSession.isCompleted) {
          print('🎉 PUZZLE COMPLETED!');
          widget.onGameCompleted?.call();
        }
      }
    });
  }

  Widget _buildPieceImage(PuzzlePiece piece, {required BoxFit fit, required bool inTray}) {
    if (widget.gameSession.useMemoryOptimization) {
      return MemoryOptimizedPuzzleImage(
        pieceId: piece.id,
        assetManager: widget.gameSession.memoryOptimizedAssetManager,
        fit: fit,
        cropToContent: inTray,
      );
    } else {
      // Fallback to basic cached image
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
    // Reserve space for the tray (using maximum tray height)
    final adjustedHeight = availableSize.height - 150;
    final scaleX = availableSize.width / canvasSize.width;
    final scaleY = adjustedHeight / canvasSize.height;
    // Use the smaller scale to ensure canvas fits, with a bit of padding
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
