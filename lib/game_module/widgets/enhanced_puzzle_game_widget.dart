// Enhanced Puzzle Game Widget with Zoom and Audio
// File: lib/game_module/widgets/enhanced_puzzle_game_widget.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puzzgame_flutter/core/application/settings_providers.dart';
import 'package:puzzgame_flutter/core/domain/services/audio_service.dart';
import 'package:puzzgame_flutter/core/domain/services/zoom_service.dart';
import 'package:puzzgame_flutter/core/infrastructure/service_locator.dart';
import 'package:puzzgame_flutter/game_module/puzzle_game_module.dart';
import 'package:puzzgame_flutter/game_module/services/puzzle_asset_manager.dart';
import 'package:puzzgame_flutter/game_module/services/enhanced_puzzle_asset_manager.dart';
import 'package:puzzgame_flutter/game_module/widgets/zoom_control.dart';

/// Enhanced puzzle game widget with zoom, pan, and audio feedback
class EnhancedPuzzleGameWidget extends ConsumerStatefulWidget {
  const EnhancedPuzzleGameWidget({
    super.key,
    required this.gameSession,
    this.onGameCompleted,
  });
  
  final PuzzleGameSession gameSession;
  final VoidCallback? onGameCompleted;
  
  @override
  ConsumerState<EnhancedPuzzleGameWidget> createState() => _EnhancedPuzzleGameWidgetState();
}

class _EnhancedPuzzleGameWidgetState extends ConsumerState<EnhancedPuzzleGameWidget> {
  // ==================== CONFIGURATION ====================
  // Adjust these values to fine-tune piece placement behavior
  
  /// Tolerance in pixels for piece drop accuracy (scaled with zoom)
  /// Higher values = more forgiving placement, lower values = more precise
  static const double _dropAccuracyTolerance = 80.0;
  
  /// Whether to enable snap-to-position when pieces are dropped close enough
  static const bool _useSnapToPosition = true;
  
  /// Whether to enable detailed console debugging for drop actions
  static const bool _enableDropDebugging = true;
  
  /// Whether to show visual debug overlays (red/green lines)
  static const bool _showDebugVisuals = false;
  
  /// Whether to show simplified drag target outlines for positioning verification
  static const bool _showTargetOutlines = true;
  
  /// Corner pieces to focus debugging on
  static const Set<String> _debugTargetPieces = {'0_0', '0_7', '7_0', '7_7'};
  static const Set<String> _debugTargetPositions = {'(0, 0)', '(0, 7)', '(7, 0)', '(7, 7)'};
  
  /// Helper method to check if we should debug this piece/position
  bool _shouldDebugPiece(String pieceId) => _debugTargetPieces.contains(pieceId);
  bool _shouldDebugPosition(int row, int col) => _debugTargetPositions.contains('($row, $col)');
  
  /// Whether to only accept pieces in their correct positions (vs any position)
  static const bool _enforceCorrectPositionOnly = true;
  
  // ==================== STATE VARIABLES ====================
  
  late final ZoomService _zoomService;
  late final AudioService _audioService;
  PuzzlePiece? _selectedPiece;
  bool _isLoading = false;
  final TransformationController _transformationController = TransformationController();
  
  @override
  void initState() {
    super.initState();
    _initializeServices();
  }
  
  void _initializeServices() {
    // Initialize zoom service
    _zoomService = DefaultZoomService();
    
    // Get audio service from service locator
    _audioService = serviceLocator<AudioService>();
    _audioService.initialize();
    
    // Listen to zoom service changes and update the transformation
    _zoomService.addListener(_updateTransformation);
  }
  
  void _updateTransformation() {
    final matrix = Matrix4.identity()
      ..scale(_zoomService.zoomLevel)
      ..translate(_zoomService.panOffset.dx, _zoomService.panOffset.dy);
    _transformationController.value = matrix;
  }
  
  @override
  void dispose() {
    _zoomService.removeListener(_updateTransformation);
    _zoomService.dispose();
    _transformationController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final orientation = MediaQuery.of(context).orientation;
    final isLandscape = orientation == Orientation.landscape;
    
    if (isLandscape) {
      return _buildLandscapeLayout();
    } else {
      return _buildPortraitLayout();
    }
  }
  
  Widget _buildPortraitLayout() {
    return Column(
      children: [
        // Game info
        _buildGameInfo(),
        
        const SizedBox(height: 8),
        
        // Main game area with zoom controls (takes most space in portrait)
        Expanded(
          flex: 3,
          child: Stack(
            children: [
              // Main viewport with zoom and pan
              _buildZoomableGameArea(),
              
              // Zoom control positioned on the right edge
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: ZoomControl(
                  zoomService: _zoomService,
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 8),
        
        // Pieces tray below in portrait
        Expanded(
          child: _buildScaledPiecesTray(),
        ),
        
        const SizedBox(height: 8),
        
        // Control buttons
        _buildControlButtons(),
      ],
    );
  }
  
  Widget _buildLandscapeLayout() {
    return Column(
      children: [
        // Game info
        _buildGameInfo(),
        
        const SizedBox(height: 8),
        
        // Main content area - side by side in landscape
        Expanded(
          child: Row(
            children: [
              // Main game area with zoom controls (left side)
              Expanded(
                flex: 3,
                child: Stack(
                  children: [
                    // Main viewport with zoom and pan
                    Container(
                      margin: const EdgeInsets.only(right: 60), // Leave space for zoom control
                      child: InteractiveViewer(
                        transformationController: _transformationController,
                        minScale: _zoomService.minZoom,
                        maxScale: _zoomService.maxZoom,
                        onInteractionStart: (details) {
                          // Could add haptic feedback here
                        },
                        onInteractionUpdate: (details) {
                          _syncZoomFromInteractiveViewer();
                        },
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          child: _buildPuzzleGrid(),
                        ),
                      ),
                    ),
                    
                    // Zoom control positioned on the right edge
                    Positioned(
                      right: 0,
                      top: 0,
                      bottom: 0,
                      child: ZoomControl(
                        zoomService: _zoomService,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(width: 8),
              
              // Pieces tray on the right side in landscape
              Expanded(
                flex: 1,
                child: _buildScaledPiecesTray(),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 8),
        
        // Control buttons
        _buildControlButtons(),
      ],
    );
  }
  
  Widget _buildGameInfo() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Text('Score: ${widget.gameSession.score}'),
          Text('Progress: ${widget.gameSession.piecesPlaced}/${widget.gameSession.totalPieces}'),
          ListenableBuilder(
            listenable: _zoomService,
            builder: (context, child) {
              return Text('Zoom: ${(_zoomService.zoomLevel * 100).round()}%');
            },
          ),
        ],
      ),
    );
  }
  
  Widget _buildZoomableGameArea() {
    return Container(
      margin: const EdgeInsets.only(right: 60), // Leave space for zoom control
      child: InteractiveViewer(
        transformationController: _transformationController,
        minScale: _zoomService.minZoom,
        maxScale: _zoomService.maxZoom,
        onInteractionStart: (details) {
          // Could add haptic feedback here
        },
        onInteractionUpdate: (details) {
          _syncZoomFromInteractiveViewer();
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          child: _buildPuzzleGrid(),
        ),
      ),
    );
  }
  
  void _syncZoomFromInteractiveViewer() {
    // Sync the zoom service with the InteractiveViewer state
    final matrix = _transformationController.value;
    final scale = matrix.getMaxScaleOnAxis();
    if ((scale - _zoomService.zoomLevel).abs() > 0.01) {
      _zoomService.setZoom(scale);
    }
  }
  
  Widget _buildPuzzleGrid() {
    if (!widget.gameSession.assetsLoaded) {
      return const Center(child: CircularProgressIndicator());
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate the puzzle dimensions from original asset grid
        final puzzleDimensions = _calculateOriginalPuzzleDimensions();
        final availableSize = Size(constraints.maxWidth, constraints.maxHeight);
        
        // Calculate scale to fill the container while maintaining aspect ratio
        final scaleX = availableSize.width / puzzleDimensions.width;
        final scaleY = availableSize.height / puzzleDimensions.height;
        final scale = (scaleX < scaleY ? scaleX : scaleY);
        
        return Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[400]!),
            borderRadius: BorderRadius.circular(8),
            color: Colors.white,
          ),
          child: AspectRatio(
            aspectRatio: puzzleDimensions.width / puzzleDimensions.height,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Positioned pieces using original locations
                ..._buildPositionedPieces(scale),
                
                // Drag targets for empty positions
                ..._buildDragTargets(scale),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildScaledPiecesTray() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey[50],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Pieces Tray',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              ListenableBuilder(
                listenable: _zoomService,
                builder: (context, child) {
                  // Get sorted pieces count
                  final sortingService = ref.watch(pieceSortingServiceProvider);
                  final sortedPieces = sortingService.sortPieces(
                    widget.gameSession.trayPieces,
                    widget.gameSession.gridSize,
                  );
                  
                  return Text(
                    '${sortedPieces.length} pieces',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListenableBuilder(
              listenable: _zoomService,
              builder: (context, child) {
                return _buildTrayGrid();
              },
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTrayGrid() {
    // Get sorted pieces using the piece sorting service
    final sortingService = ref.watch(pieceSortingServiceProvider);
    final sortedPieces = sortingService.sortPieces(
      widget.gameSession.trayPieces,
      widget.gameSession.gridSize,
    );
    
    if (sortedPieces.isEmpty) {
      return const Center(
        child: Text(
          'All pieces placed!',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.green,
          ),
        ),
      );
    }
    
    final orientation = MediaQuery.of(context).orientation;
    final isLandscape = orientation == Orientation.landscape;
    
    // Calculate piece size based on zoom level - this determines the actual cell size
    final baseSize = 60.0;
    final zoomedPieceSize = baseSize * _zoomService.zoomLevel;
    final cellPadding = 4.0;
    final totalCellSize = zoomedPieceSize + cellPadding;
    
    // Calculate how many pieces can fit based on available space and zoomed piece size
    int piecesPerRow;
    if (isLandscape) {
      // In landscape, tray is vertical on the right side
      final availableWidth = MediaQuery.of(context).size.width * 0.25 - 32; // Tray width minus padding
      piecesPerRow = (availableWidth / totalCellSize).floor().clamp(1, 4);
    } else {
      // In portrait, tray is horizontal at bottom
      final availableWidth = MediaQuery.of(context).size.width - 32; // Screen width minus padding
      piecesPerRow = (availableWidth / totalCellSize).floor().clamp(2, 8);
    }
    
    // Ensure we don't have more columns than pieces
    piecesPerRow = piecesPerRow.clamp(1, sortedPieces.length);
    
    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: piecesPerRow,
        mainAxisSpacing: cellPadding,
        crossAxisSpacing: cellPadding,
        childAspectRatio: 1.0, // Keep pieces square
      ),
      itemCount: sortedPieces.length,
      itemBuilder: (context, index) {
        final piece = sortedPieces[index];
        final isSelected = _selectedPiece == piece;
        
        return Draggable<PuzzlePiece>(
          data: piece,
          onDragStarted: () {
            if (_enableDropDebugging && _shouldDebugPiece(piece.id)) {
              print('🚀 Started dragging piece ${piece.id}');
              print('   - Correct position: (${piece.correctRow}, ${piece.correctCol})');
            }
          },
          onDragEnd: (details) {
            if (_enableDropDebugging && _shouldDebugPiece(piece.id)) {
              print('🚀 Finished dragging piece ${piece.id}');
              print('   - Drop position: (${details.offset.dx}, ${details.offset.dy})');
              print('   - Was accepted: ${details.wasAccepted}');
            }
          },
          feedback: Container(
            width: zoomedPieceSize,
            height: zoomedPieceSize,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.blue, width: 2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: widget.gameSession.useEnhancedRendering
                ? EnhancedCachedPuzzleImage(
                    pieceId: piece.id,
                    assetManager: piece.enhancedAssetManager,
                    fit: BoxFit.contain,
                    zoomLevel: 1.0, // Don't double-apply zoom to feedback
                    cropToContent: true,
                  )
                : CachedPuzzleImage(
                    pieceId: piece.id,
                    assetManager: piece.assetManager,
                    fit: BoxFit.cover,
                  ),
          ),
          childWhenDragging: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          child: GestureDetector(
            onTap: () => _selectPiece(piece),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: isSelected ? Colors.blue : Colors.grey,
                  width: isSelected ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: widget.gameSession.useEnhancedRendering
                  ? EnhancedCachedPuzzleImage(
                      pieceId: piece.id,
                      assetManager: piece.enhancedAssetManager,
                      fit: BoxFit.contain,
                      zoomLevel: 1.0, // Don't apply zoom here - grid cells handle sizing
                      cropToContent: true,
                    )
                  : CachedPuzzleImage(
                      pieceId: piece.id,
                      assetManager: piece.assetManager,
                      fit: BoxFit.cover,
                    ),
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildControlButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        ElevatedButton.icon(
          onPressed: _getHint,
          icon: const Icon(Icons.lightbulb_outline),
          label: const Text('Hint'),
        ),
        ElevatedButton.icon(
          onPressed: widget.gameSession.isActive ? _pauseGame : _resumeGame,
          icon: Icon(widget.gameSession.isActive ? Icons.pause : Icons.play_arrow),
          label: Text(widget.gameSession.isActive ? 'Pause' : 'Resume'),
        ),
        ElevatedButton.icon(
          onPressed: () => _zoomService.reset(),
          icon: const Icon(Icons.center_focus_strong),
          label: const Text('Reset View'),
        ),
      ],
    );
  }
  
  // Event handlers with audio feedback and snap-to-position
  
  bool _willAcceptPiece(DragTargetDetails<PuzzlePiece?> details, int row, int col) {
    if (details.data == null) {
      if (_enableDropDebugging && _shouldDebugPosition(row, col)) {
        print('🎯 ❌ Rejecting: details.data is null');
      }
      return false;
    }
    
    final piece = details.data!;
    if (_enableDropDebugging && _shouldDebugPosition(row, col) && _shouldDebugPiece(piece.id)) {
      print('🎯 Checking piece ${piece.id} for position ($row, $col)');
      print('   - Piece correct position: (${piece.correctRow}, ${piece.correctCol})');
      print('   - Enforce correct position only: $_enforceCorrectPositionOnly');
    }
    
    if (_enforceCorrectPositionOnly) {
      final isCorrectPosition = piece.correctRow == row && piece.correctCol == col;
      if (_enableDropDebugging && _shouldDebugPosition(row, col) && _shouldDebugPiece(piece.id)) {
        print('🎯 Correct position check: $isCorrectPosition');
      }
      return isCorrectPosition;
    } else {
      if (_enableDropDebugging && _shouldDebugPosition(row, col) && _shouldDebugPiece(piece.id)) {
        print('🎯 Accepting any piece (lenient mode)');
      }
      return true;
    }
  }
  
  Future<void> _placePieceWithSnap(PuzzlePiece piece, int row, int col, double scale) async {
    if (_enableDropDebugging && _shouldDebugPiece(piece.id)) {
      print('🎯 _placePieceWithSnap called:');
      print('   - Piece: ${piece.id}');
      print('   - Target position: ($row, $col)');
      print('   - Piece correct position: (${piece.correctRow}, ${piece.correctCol})');
      print('   - Scale: $scale');
    }
    
    setState(() {
      final success = widget.gameSession.tryPlacePiece(piece, row, col);
      
      if (_enableDropDebugging) {
        print('🎯 Placement result: ${success ? "SUCCESS" : "FAILED"}');
      }
      
      if (success) {
        _selectedPiece = null;
        _audioService.playPieceCorrect();
        
        // Add haptic feedback for correct placement
        HapticFeedback.lightImpact();
        
        if (_enableDropDebugging) {
          print('🎯 ✅ Piece placed successfully, playing success audio');
        }
        
        // Check if puzzle is completed
        if (widget.gameSession.isCompleted) {
          _audioService.playPuzzleCompleted();
          _showCompletionDialog();
          if (_enableDropDebugging) {
            print('🎯 🎉 Puzzle completed!');
          }
        }
      } else {
        _audioService.playPieceIncorrect();
        HapticFeedback.mediumImpact();
        
        if (_enableDropDebugging) {
          print('🎯 ❌ Placement failed, playing error audio');
        }
        
        // Show error feedback
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This piece doesn\'t belong here!'),
            duration: Duration(seconds: 1),
            backgroundColor: Colors.red,
          ),
        );
      }
    });
  }
  
  Future<void> _placePiece(PuzzlePiece piece, int row, int col) async {
    setState(() {
      final success = widget.gameSession.tryPlacePiece(piece, row, col);
      
      if (success) {
        _selectedPiece = null;
        _audioService.playPieceCorrect();
        
        // Add haptic feedback for correct placement
        HapticFeedback.lightImpact();
        
        // Check if puzzle is completed
        if (widget.gameSession.isCompleted) {
          _audioService.playPuzzleCompleted();
          _showCompletionDialog();
        }
      } else {
        _audioService.playPieceIncorrect();
        HapticFeedback.mediumImpact();
        
        // Show error feedback
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This piece doesn\'t belong here!'),
            duration: Duration(seconds: 1),
            backgroundColor: Colors.red,
          ),
        );
      }
    });
  }
  
  void _removePiece(int row, int col) {
    setState(() {
      widget.gameSession.removePieceFromGrid(row, col);
      _audioService.playUIClick();
    });
  }
  
  void _selectPiece(PuzzlePiece piece) {
    setState(() {
      _selectedPiece = _selectedPiece == piece ? null : piece;
      _audioService.playPieceSelected();
    });
  }
  
  void _getHint() {
    final hintPiece = widget.gameSession.getHint();
    if (hintPiece != null) {
      setState(() {
        _selectedPiece = hintPiece;
      });
      
      _audioService.playUIClick();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Try placing piece ${hintPiece.id} at position (${hintPiece.correctRow}, ${hintPiece.correctCol})',
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
  
  void _pauseGame() {
    widget.gameSession.pauseGame();
    _audioService.playUIClick();
    setState(() {});
  }
  
  void _resumeGame() {
    widget.gameSession.resumeSession();
    _audioService.playUIClick();
    setState(() {});
  }
  
  Size _calculateOriginalPuzzleDimensions() {
    if (widget.gameSession.allPieces.isEmpty) {
      return const Size(400, 400); // fallback
    }
    
    // Instead of using just the first piece's original size,
    // calculate the actual bounds needed to contain all pieces
    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;
    
    // Check bounds of all pieces to find the true puzzle dimensions
    for (final piece in widget.gameSession.allPieces) {
      final bounds = piece.enhancedAssetManager.getPieceBounds(piece.id);
      if (bounds != null && bounds.hasContent) {
        // Calculate grid position for this piece
        final coords = piece.id.split('_');
        final row = int.parse(coords[0]);
        final col = int.parse(coords[1]);
        
        // Get the first piece's original size to calculate cell dimensions
        final firstPieceBounds = widget.gameSession.allPieces.first.enhancedAssetManager.getPieceBounds(widget.gameSession.allPieces.first.id);
        if (firstPieceBounds == null) continue;
        
        final cellWidth = firstPieceBounds.originalSize.width / widget.gameSession.gridSize;
        final cellHeight = firstPieceBounds.originalSize.height / widget.gameSession.gridSize;
        
        // Calculate where this piece's content extends
        final gridLeft = col * cellWidth;
        final gridTop = row * cellHeight;
        
        final contentLeft = gridLeft + bounds.contentRect.left;
        final contentTop = gridTop + bounds.contentRect.top;
        final contentRight = contentLeft + bounds.contentRect.width;
        final contentBottom = contentTop + bounds.contentRect.height;
        
        // Update overall bounds
        minX = minX < contentLeft ? minX : contentLeft;
        minY = minY < contentTop ? minY : contentTop;
        maxX = maxX > contentRight ? maxX : contentRight;
        maxY = maxY > contentBottom ? maxY : contentBottom;
      }
    }
    
    // If we couldn't calculate bounds, fall back to original method
    if (minX == double.infinity || maxX == double.negativeInfinity) {
      final firstPiece = widget.gameSession.allPieces.first;
      final bounds = firstPiece.enhancedAssetManager.getPieceBounds(firstPiece.id);
      if (bounds != null) {
        return bounds.originalSize;
      }
      return const Size(400, 400);
    }
    
    // Add some padding to ensure pieces don't get clipped
    const padding = 20.0;
    final width = (maxX - minX) + (padding * 2);
    final height = (maxY - minY) + (padding * 2);
    
    final calculatedSize = Size(width, height);
    
    if (_enableDropDebugging) {
      print('🎯 Calculated puzzle dimensions:');
      print('   - Content bounds: ($minX, $minY) to ($maxX, $maxY)');
      print('   - Content size: ${maxX - minX} x ${maxY - minY}');
      print('   - With padding: ${calculatedSize.width} x ${calculatedSize.height}');
    }
    
    return calculatedSize;
  }

  double _calculateGridScale(Size availableSize, Size originalSize) {
    final scaleX = availableSize.width / originalSize.width;
    final scaleY = availableSize.height / originalSize.height;
    return (scaleX < scaleY ? scaleX : scaleY) * 0.9; // 90% to leave margin
  }

  List<Widget> _buildPositionedPieces(double scale) {
    final List<Widget> positionedPieces = [];
    
    if (_enableDropDebugging) {
      print('🎯 Building positioned pieces with scale: $scale');
    }
    
    // Calculate cell dimensions and offset for grid-based positioning
    final puzzleDimensions = _calculateOriginalPuzzleDimensions();
    
    // Get reference bounds for cell calculation
    final firstPiece = widget.gameSession.allPieces.first;
    final firstBounds = firstPiece.enhancedAssetManager.getPieceBounds(firstPiece.id);
    if (firstBounds == null) return [];
    
    final cellWidth = firstBounds.originalSize.width / widget.gameSession.gridSize;
    final cellHeight = firstBounds.originalSize.height / widget.gameSession.gridSize;
    
    // Calculate the minimum content bounds to determine offset
    double minX = double.infinity;
    double minY = double.infinity;
    
    for (final piece in widget.gameSession.allPieces) {
      final bounds = piece.enhancedAssetManager.getPieceBounds(piece.id);
      if (bounds != null && bounds.hasContent) {
        final coords = piece.id.split('_');
        final row = int.parse(coords[0]);
        final col = int.parse(coords[1]);
        
        final gridLeft = col * cellWidth;
        final gridTop = row * cellHeight;
        final contentLeft = gridLeft + bounds.contentRect.left;
        final contentTop = gridTop + bounds.contentRect.top;
        
        minX = minX < contentLeft ? minX : contentLeft;
        minY = minY < contentTop ? minY : contentTop;
      }
    }
    
    // Add padding offset
    const padding = 20.0;
    final offsetX = -minX + padding;
    final offsetY = -minY + padding;
    
    for (int row = 0; row < widget.gameSession.gridSize; row++) {
      for (int col = 0; col < widget.gameSession.gridSize; col++) {
        final piece = widget.gameSession.puzzleGrid[row][col];
        if (piece != null) {
          final bounds = piece.enhancedAssetManager.getPieceBounds(piece.id);
          if (bounds != null && bounds.hasContent) {
            // Calculate grid-based position with offset
            final gridLeft = col * cellWidth;
            final gridTop = row * cellHeight;
            
            // Add the piece's content offset within its cell plus the overall offset
            final contentOffsetX = bounds.contentRect.left;
            final contentOffsetY = bounds.contentRect.top;
            
            final finalLeft = (gridLeft + contentOffsetX + offsetX) * scale;
            final finalTop = (gridTop + contentOffsetY + offsetY) * scale;
            
            final contentSize = bounds.getContentSize();
            final scaledWidth = contentSize.width * scale;
            final scaledHeight = contentSize.height * scale;
            
            if (_enableDropDebugging && _shouldDebugPiece(piece.id)) {
              print('🎯 Rendering positioned piece ${piece.id} at ($row, $col):');
              print('   - Grid position: ($row, $col)');
              print('   - Cell size: ${cellWidth} x $cellHeight');
              print('   - Grid offset: $gridLeft, $gridTop');
              print('   - Content offset within cell: $contentOffsetX, $contentOffsetY');
              print('   - Overall offset: $offsetX, $offsetY');
              print('   - Final position: $finalLeft, $finalTop');
              print('   - Content size: ${scaledWidth} x $scaledHeight');
              print('   - Scale: $scale');
            }
            
            positionedPieces.add(
              Positioned(
                left: finalLeft,
                top: finalTop,
                width: scaledWidth,
                height: scaledHeight,
                child: GestureDetector(
                  onTap: () => _removePiece(row, col),
                  child: widget.gameSession.useEnhancedRendering
                      ? EnhancedCachedPuzzleImage(
                          pieceId: piece.id,
                          assetManager: piece.enhancedAssetManager,
                          width: scaledWidth,
                          height: scaledHeight,
                          fit: BoxFit.contain,
                          zoomLevel: 1.0,
                          cropToContent: true,
                        )
                      : CachedPuzzleImage(
                          pieceId: piece.id,
                          assetManager: piece.assetManager,
                          fit: BoxFit.cover,
                        ),
                ),
              ),
            );
          } else {
            if (_enableDropDebugging && _shouldDebugPiece(piece.id)) {
              print('🎯 ❌ Piece ${piece.id} has no bounds or no content!');
            }
          }
        }
      }
    }
    
    if (_enableDropDebugging) {
      print('🎯 Total positioned pieces rendered: ${positionedPieces.length}');
    }
    
    return positionedPieces;
  }

  List<Widget> _buildDragTargets(double scale) {
    final List<Widget> dragTargets = [];
    
    if (_enableDropDebugging) {
      print('🎯 Building drag targets with scale: $scale');
      print('🎯 Grid size: ${widget.gameSession.gridSize}');
      print('🎯 Total pieces: ${widget.gameSession.allPieces.length}');
      print('🎯 Available viewport size: ${MediaQuery.of(context).size}');
      
      // Check what the puzzle dimensions calculation gives us
      final puzzleDimensions = _calculateOriginalPuzzleDimensions();
      print('🎯 Calculated puzzle dimensions: ${puzzleDimensions.width} x ${puzzleDimensions.height}');
      print('🎯 Scaled puzzle size: ${puzzleDimensions.width * scale} x ${puzzleDimensions.height * scale}');
    }
    
    // Calculate cell dimensions and offset for grid-based positioning
    final firstPiece = widget.gameSession.allPieces.first;
    final firstBounds = firstPiece.enhancedAssetManager.getPieceBounds(firstPiece.id);
    if (firstBounds == null) return [];
    
    final cellWidth = firstBounds.originalSize.width / widget.gameSession.gridSize;
    final cellHeight = firstBounds.originalSize.height / widget.gameSession.gridSize;
    
    // Calculate the minimum content bounds to determine offset (same as in _buildPositionedPieces)
    double minX = double.infinity;
    double minY = double.infinity;
    
    for (final piece in widget.gameSession.allPieces) {
      final bounds = piece.enhancedAssetManager.getPieceBounds(piece.id);
      if (bounds != null && bounds.hasContent) {
        final coords = piece.id.split('_');
        final row = int.parse(coords[0]);
        final col = int.parse(coords[1]);
        
        final gridLeft = col * cellWidth;
        final gridTop = row * cellHeight;
        final contentLeft = gridLeft + bounds.contentRect.left;
        final contentTop = gridTop + bounds.contentRect.top;
        
        minX = minX < contentLeft ? minX : contentLeft;
        minY = minY < contentTop ? minY : contentTop;
      }
    }
    
    // Add padding offset
    const padding = 20.0;
    final offsetX = -minX + padding;
    final offsetY = -minY + padding;
    
    for (int row = 0; row < widget.gameSession.gridSize; row++) {
      for (int col = 0; col < widget.gameSession.gridSize; col++) {
        if (widget.gameSession.puzzleGrid[row][col] == null) {
          // Calculate grid-based position for drag target with offset
          final gridLeft = col * cellWidth;
          final gridTop = row * cellHeight;
          
          final finalLeft = (gridLeft + offsetX) * scale;
          final finalTop = (gridTop + offsetY) * scale;
          final scaledCellWidth = cellWidth * scale;
          final scaledCellHeight = cellHeight * scale;
          
          // Expand the drop target area for better accuracy, but limit to cell size
          final tolerance = (_dropAccuracyTolerance * scale).clamp(0.0, scaledCellWidth * 0.3).toDouble();
          
          final expandedLeft = finalLeft - tolerance;
          final expandedTop = finalTop - tolerance;
          final expandedWidth = scaledCellWidth + (tolerance * 2);
          final expandedHeight = scaledCellHeight + (tolerance * 2);
          
          if (_enableDropDebugging && _shouldDebugPosition(row, col)) {
            print('🎯 Creating drag target for position ($row, $col):');
            print('   - Grid position: ($row, $col)');
            print('   - Cell size: ${cellWidth} x $cellHeight');
            print('   - Grid offset: $gridLeft, $gridTop');
            print('   - Overall offset: $offsetX, $offsetY');
            print('   - Final grid position: $finalLeft, $finalTop');
            print('   - Scale: $scale');
            print('   - Tolerance: $tolerance pixels');
            print('   - Expanded area: $expandedLeft, $expandedTop, $expandedWidth x $expandedHeight');
          }
            
          dragTargets.add(
            Positioned(
              left: expandedLeft,
              top: expandedTop,
              width: expandedWidth,
              height: expandedHeight,
              child: DragTarget<PuzzlePiece>(
                onWillAcceptWithDetails: (details) {
                  final result = _willAcceptPiece(details, row, col);
                  if (_enableDropDebugging && _shouldDebugPosition(row, col) && details.data != null) {
                    print('🎯 onWillAccept for ($row, $col): piece=${details.data?.id}, result=$result');
                  }
                  return result;
                },
                onAcceptWithDetails: (details) {
                  if (_enableDropDebugging && _shouldDebugPosition(row, col)) {
                    print('🎯 onAccept for ($row, $col): piece=${details.data.id}');
                  }
                  _placePieceWithSnap(details.data, row, col, scale);
                },
                builder: (context, candidateData, rejectedData) {
                  final isHighlighted = candidateData.isNotEmpty;
                  
                  if (_enableDropDebugging && isHighlighted) {
                    print('🎯 Highlighting drag target ($row, $col) - piece over target');
                  }
                  
                  return Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isHighlighted 
                            ? Colors.blue.withOpacity(0.7) 
                            : (_showTargetOutlines && kDebugMode && _shouldDebugPosition(row, col)
                                ? Colors.purple.withOpacity(0.3) 
                                : Colors.transparent),
                        width: isHighlighted ? 2 : (_showTargetOutlines && kDebugMode && _shouldDebugPosition(row, col) ? 1 : 0),
                      ),
                      color: isHighlighted 
                          ? Colors.blue.withOpacity(0.1)
                          : Colors.transparent,
                      borderRadius: isHighlighted ? BorderRadius.circular(4) : null,
                    ),
                    // Show simplified target outline or full debug info
                    child: _showTargetOutlines && kDebugMode && !_showDebugVisuals && _shouldDebugPosition(row, col)
                        ? Center(
                            child: Text(
                              '${row}_$col',
                              style: TextStyle(
                                color: Colors.purple[600],
                                fontSize: (8 * scale).clamp(6, 12),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        : (_showDebugVisuals && kDebugMode) ? Stack(
                      children: [
                        // Original target area (for debugging)
                        Positioned(
                          left: tolerance,
                          top: tolerance,
                          width: scaledCellWidth,
                          height: scaledCellHeight,
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Colors.red.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                '${row}_$col',
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 8 * scale,
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Tolerance area indicator
                        if (isHighlighted)
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Colors.green.withOpacity(0.5),
                                  width: 1,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ) : null,
                  );
                },
              ),
            ),
          );
        }
      }
    }
    
    if (_enableDropDebugging) {
      print('🎯 Created ${dragTargets.length} drag targets total');
      
      // Check if specific problematic targets were created
      final emptyPositions = <String>[];
      for (int row = 0; row < widget.gameSession.gridSize; row++) {
        for (int col = 0; col < widget.gameSession.gridSize; col++) {
          if (widget.gameSession.puzzleGrid[row][col] == null) {
            emptyPositions.add('($row, $col)');
          }
        }
      }
      print('🎯 Empty positions that should have drag targets: $emptyPositions');
    }
    
    return dragTargets;
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.celebration, color: Colors.amber, size: 32),
            SizedBox(width: 8),
            Text('Puzzle Completed!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star, size: 64, color: Colors.amber),
            const SizedBox(height: 16),
            Text(
              'Final Score: ${widget.gameSession.score}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Time: ${DateTime.now().difference(widget.gameSession.startTime).inMinutes} minutes',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              widget.onGameCompleted?.call();
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }
}
