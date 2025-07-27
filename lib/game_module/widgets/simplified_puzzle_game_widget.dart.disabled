// Simplified Puzzle Game Widget with Memory Optimization
// File: lib/game_module/widgets/simplified_puzzle_game_widget.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puzzgame_flutter/core/application/settings_providers.dart';
import 'package:puzzgame_flutter/core/domain/services/audio_service.dart';
import 'package:puzzgame_flutter/core/domain/services/zoom_service.dart';
import 'package:puzzgame_flutter/core/domain/services/error_reporting_service.dart';
import 'package:puzzgame_flutter/core/infrastructure/service_locator.dart';
import 'package:puzzgame_flutter/game_module/puzzle_game_module_simplified.dart';
import 'package:puzzgame_flutter/game_module/services/memory_optimized_asset_manager.dart';
import 'package:puzzgame_flutter/game_module/widgets/zoom_control.dart';

/// Simplified puzzle game widget with memory optimization always enabled
/// Removes unnecessary conditional paths and asset manager complexity
class SimplifiedPuzzleGameWidget extends ConsumerStatefulWidget {
  const SimplifiedPuzzleGameWidget({
    super.key,
    required this.gameSession,
    this.onGameCompleted,
  });
  
  final PuzzleGameSession gameSession;
  final VoidCallback? onGameCompleted;
  
  @override
  ConsumerState<SimplifiedPuzzleGameWidget> createState() => _SimplifiedPuzzleGameWidgetState();
}

class _SimplifiedPuzzleGameWidgetState extends ConsumerState<SimplifiedPuzzleGameWidget> {
  late final ZoomService _zoomService;
  late final AudioService _audioService;
  late final ErrorReportingService _errorReporting;
  PuzzlePiece? _selectedPiece;
  final TransformationController _transformationController = TransformationController();
  
  @override
  void initState() {
    super.initState();
    _initializeServices();
  }
  
  void _initializeServices() {
    try {
      _zoomService = DefaultZoomService();
      _audioService = serviceLocator<AudioService>();
      _errorReporting = serviceLocator<ErrorReportingService>();
      
      _audioService.initialize();
      _zoomService.addListener(_updateTransformation);
      
      _errorReporting.addBreadcrumb(
        'Simplified puzzle widget initialized',
        category: 'ui_lifecycle',
        data: {
          'session_id': widget.gameSession.sessionId,
          'grid_size': widget.gameSession.gridSize,
        },
      );
    } catch (e, stackTrace) {
      print('Failed to initialize puzzle widget services: $e');
      
      try {
        _errorReporting.reportException(
          e,
          stackTrace: stackTrace,
          context: 'widget_initialization',
          extra: {
            'widget_type': 'SimplifiedPuzzleGameWidget',
            'session_id': widget.gameSession.sessionId,
          },
        );
      } catch (reportingError) {
        print('Failed to report widget initialization error: $reportingError');
      }
    }
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
        _buildGameInfo(),
        const SizedBox(height: 8),
        Expanded(
          flex: 3,
          child: Stack(
            children: [
              _buildZoomableGameArea(),
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: ZoomControl(zoomService: _zoomService),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(child: _buildPiecesTray()),
        const SizedBox(height: 8),
        _buildControlButtons(),
      ],
    );
  }
  
  Widget _buildLandscapeLayout() {
    return Column(
      children: [
        _buildGameInfo(),
        const SizedBox(height: 8),
        Expanded(
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Stack(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(right: 60),
                      child: InteractiveViewer(
                        transformationController: _transformationController,
                        minScale: _zoomService.minZoom,
                        maxScale: _zoomService.maxZoom,
                        onInteractionUpdate: (details) => _syncZoomFromInteractiveViewer(),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          child: _buildPuzzleGrid(),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      top: 0,
                      bottom: 0,
                      child: ZoomControl(zoomService: _zoomService),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(flex: 1, child: _buildPiecesTray()),
            ],
          ),
        ),
        const SizedBox(height: 8),
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
      margin: const EdgeInsets.only(right: 60),
      child: InteractiveViewer(
        transformationController: _transformationController,
        minScale: _zoomService.minZoom,
        maxScale: _zoomService.maxZoom,
        onInteractionUpdate: (details) => _syncZoomFromInteractiveViewer(),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: _buildPuzzleGrid(),
        ),
      ),
    );
  }
  
  void _syncZoomFromInteractiveViewer() {
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
    
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[400]!),
        borderRadius: BorderRadius.circular(8),
        color: Colors.white,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final canvasInfo = widget.gameSession.canvasInfo;
          
          // Always use memory-optimized rendering (simplified from conditional logic)
          final scale = _calculateCanvasScale(canvasInfo.canvasSize, constraints.biggest);
          final displaySize = canvasInfo.canvasSize * scale;
          
          return Center(
            child: SizedBox(
              width: displaySize.width,
              height: displaySize.height,
              child: Stack(
                children: [
                  // Memory-optimized custom painter
                  CustomPaint(
                    size: displaySize,
                    painter: MemoryOptimizedPuzzlePainter(
                      pieces: widget.gameSession.placedPieces,
                      canvasSize: canvasInfo.canvasSize,
                      displaySize: displaySize,
                    ),
                  ),
                  // Drop zone overlay
                  _buildDropZoneOverlay(displaySize),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildPiecesTray() {
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
              builder: (context, child) => _buildTrayGrid(),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTrayGrid() {
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
    
    // Calculate piece size based on zoom level
    final baseSize = 60.0;
    final zoomedPieceSize = baseSize * _zoomService.zoomLevel;
    final cellPadding = 4.0;
    final totalCellSize = zoomedPieceSize + cellPadding;
    
    // Calculate pieces per row based on available space
    int piecesPerRow;
    if (isLandscape) {
      final availableWidth = MediaQuery.of(context).size.width * 0.25 - 32;
      piecesPerRow = (availableWidth / totalCellSize).floor().clamp(1, 4);
    } else {
      final availableWidth = MediaQuery.of(context).size.width - 32;
      piecesPerRow = (availableWidth / totalCellSize).floor().clamp(2, 8);
    }
    
    piecesPerRow = piecesPerRow.clamp(1, sortedPieces.length);
    
    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: piecesPerRow,
        mainAxisSpacing: cellPadding,
        crossAxisSpacing: cellPadding,
        childAspectRatio: 1.0,
      ),
      itemCount: sortedPieces.length,
      itemBuilder: (context, index) {
        final piece = sortedPieces[index];
        final isSelected = _selectedPiece == piece;
        
        return Draggable<PuzzlePiece>(
          data: piece,
          feedback: Container(
            width: zoomedPieceSize,
            height: zoomedPieceSize,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.blue, width: 2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: MemoryOptimizedPuzzleImage(
              pieceId: piece.id,
              assetManager: piece.assetManager,
              fit: BoxFit.contain,
              zoomLevel: 1.0,
              cropToContent: true,
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
              child: MemoryOptimizedPuzzleImage(
                pieceId: piece.id,
                assetManager: piece.assetManager,
                fit: BoxFit.contain,
                zoomLevel: 1.0,
                cropToContent: true,
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
  
  // Event handlers
  
  void _placePieceOnCanvas(PuzzlePiece piece) {
    setState(() {
      try {
        final success = widget.gameSession.placePiece(piece);
        
        if (success) {
          _selectedPiece = null;
          _audioService.playPieceCorrect();
          HapticFeedback.lightImpact();
          
          _errorReporting.addBreadcrumb(
            'Piece placed successfully',
            category: 'game_action',
            data: {
              'piece_id': piece.id,
              'session_id': widget.gameSession.sessionId,
              'pieces_remaining': widget.gameSession.piecesRemaining,
            },
          );
          
          if (widget.gameSession.isCompleted) {
            _audioService.playPuzzleCompleted();
            
            _errorReporting.addBreadcrumb(
              'Puzzle completed',
              category: 'game_lifecycle',
              data: {
                'session_id': widget.gameSession.sessionId,
                'final_score': widget.gameSession.score,
                'completion_time_minutes': DateTime.now().difference(widget.gameSession.startTime).inMinutes,
              },
            );
            
            _showCompletionDialog();
          }
        } else {
          _audioService.playPieceIncorrect();
          HapticFeedback.mediumImpact();
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Piece already placed!'),
              duration: Duration(seconds: 1),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e, stackTrace) {
        _errorReporting.reportException(
          e,
          stackTrace: stackTrace,
          context: 'piece_placement_error',
          extra: {
            'piece_id': piece.id,
            'session_id': widget.gameSession.sessionId,
            'pieces_placed': widget.gameSession.piecesPlaced,
          },
          tags: {
            'feature': 'puzzle_gameplay',
            'action': 'place_piece',
          },
        );
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('An error occurred while placing the piece'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.red,
          ),
        );
      }
    });
  }
  
  void _removePiece(PuzzlePiece piece) {
    setState(() {
      widget.gameSession.removePiece(piece);
      _audioService.playUIClick();
    });
  }
  
  Widget _buildDropZoneOverlay(Size canvasSize) {
    return Positioned.fill(
      child: DragTarget<PuzzlePiece>(
        onWillAcceptWithDetails: (details) => details.data != null,
        onAcceptWithDetails: (details) => _placePieceOnCanvas(details.data),
        builder: (context, candidateData, rejectedData) {
          return Container(
            decoration: candidateData.isNotEmpty
                ? BoxDecoration(
                    border: Border.all(color: Colors.blue, width: 3),
                    color: Colors.blue.withOpacity(0.1),
                  )
                : null,
          );
        },
      ),
    );
  }
  
  double _calculateCanvasScale(Size canvasSize, Size availableSize) {
    final scaleX = availableSize.width / canvasSize.width;
    final scaleY = availableSize.height / canvasSize.height;
    return scaleX < scaleY ? scaleX : scaleY;
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
          content: Text('Try placing piece ${hintPiece.id}'),
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

/// Custom painter for memory-optimized rendering
class MemoryOptimizedPuzzlePainter extends CustomPainter {
  final List<PuzzlePiece> pieces;
  final Size canvasSize;
  final Size displaySize;
  
  MemoryOptimizedPuzzlePainter({
    required this.pieces,
    required this.canvasSize,
    required this.displaySize,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    // Draw background
    final backgroundPaint = Paint()..color = Colors.grey[50]!;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), backgroundPaint);
    
    // Calculate scale from native canvas to display
    final scaleX = displaySize.width / canvasSize.width;
    final scaleY = displaySize.height / canvasSize.height;
    
    // Render each piece at its exact position
    for (final piece in pieces) {
      final assetManager = piece.assetManager;
      final metadata = assetManager.getPieceMetadata(piece.id);
      final image = assetManager.getCachedPieceImage(piece.id);
      
      if (metadata != null && image != null) {
        // Calculate exact pixel position on display
        final destRect = Rect.fromLTWH(
          metadata.contentBounds.left * scaleX,
          metadata.contentBounds.top * scaleY,
          metadata.contentBounds.width * scaleX,
          metadata.contentBounds.height * scaleY,
        );
        
        final srcRect = Rect.fromLTWH(
          0, 0, 
          image.width.toDouble(), 
          image.height.toDouble()
        );
        
        // Draw with high quality filtering
        canvas.drawImageRect(
          image, 
          srcRect, 
          destRect, 
          Paint()..filterQuality = FilterQuality.high
        );
      }
    }
  }
  
  @override
  bool shouldRepaint(covariant MemoryOptimizedPuzzlePainter oldDelegate) {
    return oldDelegate.pieces.length != pieces.length ||
           oldDelegate.canvasSize != canvasSize ||
           oldDelegate.displaySize != displaySize;
  }
}
