// Enhanced Puzzle Game Widget with Zoom and Audio
// File: lib/game_module/widgets/enhanced_puzzle_game_widget.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:puzzgame_flutter/core/domain/services/audio_service.dart';
import 'package:puzzgame_flutter/core/domain/services/zoom_service.dart';
import 'package:puzzgame_flutter/core/infrastructure/service_locator.dart';
import 'package:puzzgame_flutter/game_module/puzzle_game_module.dart';
import 'package:puzzgame_flutter/game_module/services/puzzle_asset_manager.dart';
import 'package:puzzgame_flutter/game_module/widgets/zoom_control.dart';

/// Enhanced puzzle game widget with zoom, pan, and audio feedback
class EnhancedPuzzleGameWidget extends StatefulWidget {
  const EnhancedPuzzleGameWidget({
    super.key,
    required this.gameSession,
    this.onGameCompleted,
  });
  
  final PuzzleGameSession gameSession;
  final VoidCallback? onGameCompleted;
  
  @override
  State<EnhancedPuzzleGameWidget> createState() => _EnhancedPuzzleGameWidgetState();
}

class _EnhancedPuzzleGameWidgetState extends State<EnhancedPuzzleGameWidget> {
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
    
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[400]!),
          borderRadius: BorderRadius.circular(8),
          color: Colors.white,
        ),
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(), // Disable scrolling, use pan instead
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: widget.gameSession.gridSize,
            mainAxisSpacing: 1,
            crossAxisSpacing: 1,
          ),
          itemCount: widget.gameSession.totalPieces,
          itemBuilder: (context, index) {
            final row = index ~/ widget.gameSession.gridSize;
            final col = index % widget.gameSession.gridSize;
            final piece = widget.gameSession.puzzleGrid[row][col];
            
            return DragTarget<PuzzlePiece>(
              onWillAcceptWithDetails: (details) => details.data != null,
              onAcceptWithDetails: (details) => _placePiece(details.data, row, col),
              builder: (context, candidateData, rejectedData) {
                return GestureDetector(
                  onTap: () => _removePiece(row, col),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: candidateData.isNotEmpty ? Colors.blue : Colors.grey[300]!,
                        width: candidateData.isNotEmpty ? 2 : 0.5,
                      ),
                      color: piece != null ? null : Colors.grey[50],
                    ),
                    child: piece != null
                        ? CachedPuzzleImage(
                            pieceId: piece.id,
                            assetManager: piece.assetManager,
                            fit: BoxFit.cover,
                          )
                        : Center(
                            child: Text(
                              '${row}_$col',
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 8,
                              ),
                            ),
                          ),
                  ),
                );
              },
            );
          },
        ),
      ),
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
                  return Text(
                    '${widget.gameSession.trayPieces.length} pieces',
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
    if (widget.gameSession.trayPieces.isEmpty) {
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
    
    // Calculate piece size based on zoom level
    final baseSize = 60.0;
    final scaledSize = baseSize * _zoomService.zoomLevel;
    
    // Calculate layout based on orientation
    int piecesPerRow;
    if (isLandscape) {
      // In landscape, tray is vertical on the right, so fewer pieces per row
      final availableWidth = MediaQuery.of(context).size.width * 0.25; // Rough estimate for tray width
      piecesPerRow = (availableWidth / (scaledSize + 4)).floor().clamp(1, 3);
    } else {
      // In portrait, tray is horizontal at bottom, so more pieces per row
      final availableWidth = MediaQuery.of(context).size.width - 32; // Minus padding
      piecesPerRow = (availableWidth / (scaledSize + 4)).floor().clamp(3, 8);
    }
    
    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: piecesPerRow,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
        childAspectRatio: 1,
      ),
      itemCount: widget.gameSession.trayPieces.length,
      itemBuilder: (context, index) {
        final piece = widget.gameSession.trayPieces[index];
        final isSelected = _selectedPiece == piece;
        
        return Draggable<PuzzlePiece>(
          data: piece,
          feedback: Container(
            width: scaledSize,
            height: scaledSize,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.blue, width: 2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: CachedPuzzleImage(
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
              child: CachedPuzzleImage(
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
  
  // Event handlers with audio feedback
  
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
