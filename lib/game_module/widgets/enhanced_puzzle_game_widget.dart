// Enhanced Puzzle Game Widget with Zoom and Audio
// File: lib/game_module/widgets/enhanced_puzzle_game_widget.dart

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puzzgame_flutter/core/application/settings_providers.dart';
import 'package:puzzgame_flutter/core/domain/services/audio_service.dart';
import 'package:puzzgame_flutter/core/domain/services/zoom_service.dart';
import 'package:puzzgame_flutter/core/domain/services/error_reporting_service.dart';
import 'package:puzzgame_flutter/core/infrastructure/service_locator.dart';
import 'package:puzzgame_flutter/game_module/puzzle_game_module.dart';
import 'package:puzzgame_flutter/game_module/services/puzzle_asset_manager.dart';
import 'package:puzzgame_flutter/game_module/services/enhanced_puzzle_asset_manager.dart';
import 'package:puzzgame_flutter/game_module/services/memory_optimized_asset_manager.dart';
import 'package:puzzgame_flutter/game_module/widgets/zoom_control.dart';
import 'package:puzzgame_flutter/game_module/widgets/tray_scroll_stick.dart';
import 'package:puzzgame_flutter/core/infrastructure/desktop_window_config.dart';

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
  late final ZoomService _zoomService;
  late final AudioService _audioService;
  late final ErrorReportingService _errorReporting;
  PuzzlePiece? _selectedPiece;
  bool _isLoading = false;
  final TransformationController _transformationController = TransformationController();
  
  // Scroll controller for pieces tray accessibility
  final ScrollController _trayScrollController = ScrollController();
  
  @override
  void initState() {
    super.initState();
    _initializeServices();
  }
  
  void _initializeServices() {
    try {
      // Initialize zoom service
      _zoomService = DefaultZoomService();
      
      // Get services from service locator
      _audioService = serviceLocator<AudioService>();
      _errorReporting = serviceLocator<ErrorReportingService>();
      
      _audioService.initialize();
      
      // Listen to zoom service changes and update the transformation
      _zoomService.addListener(_updateTransformation);
      
      // Report successful widget initialization
      _errorReporting.addBreadcrumb(
        'Enhanced puzzle widget initialized',
        category: 'ui_lifecycle',
        data: {
          'session_id': widget.gameSession.sessionId,
          'grid_size': widget.gameSession.gridSize,
        },
      );
    } catch (e, stackTrace) {
      print('Failed to initialize enhanced puzzle widget services: $e');
      
      // Try to report the error even if error service failed to initialize
      try {
        _errorReporting.reportException(
          e,
          stackTrace: stackTrace,
          context: 'enhanced_widget_initialization',
          extra: {
            'widget_type': 'EnhancedPuzzleGameWidget',
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
    _trayScrollController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final orientation = MediaQuery.of(context).orientation;
    final screenSize = MediaQuery.of(context).size;
    final isLandscape = orientation == Orientation.landscape;
    
    // Debug info for desktop portrait layout
    if (DesktopWindowConfig.isDesktop && kDebugMode) {
      print('Enhanced Puzzle Widget: Size=${screenSize.aspectRatioString}, '
           'Orientation=$orientation, IsLandscape=$isLandscape');
    }
    
    if (isLandscape) {
      return _buildLandscapeLayout();
    } else {
      return _buildPortraitLayout();
    }
  }
  
  Widget _buildPortraitLayout() {
    return Column(
      children: [
        // Compact game info
        _buildGameInfo(),
        
        const SizedBox(height: 4),
        
        // Main game area with zoom controls (maximized space for phones)
        Expanded(
          flex: 4,
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
        
        const SizedBox(height: 4),
        
        // Pieces tray below in portrait
        Expanded(
          child: _buildScaledPiecesTray(),
        ),
        
        const SizedBox(height: 4),
        
        // Compact control buttons
        _buildControlButtons(),
      ],
    );
  }
  
  Widget _buildLandscapeLayout() {
    return Column(
      children: [
        // Compact game info
        _buildGameInfo(),
        
        const SizedBox(height: 4),
        
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
                          padding: const EdgeInsets.all(12),
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
              
              const SizedBox(width: 4),
              
              // Pieces tray on the right side in landscape
              Expanded(
                flex: 1,
                child: _buildScaledPiecesTray(),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 4),
        
        // Compact control buttons
        _buildControlButtons(),
      ],
    );
  }
  
  Widget _buildGameInfo() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Text('Score: ${widget.gameSession.score}', style: const TextStyle(fontSize: 13)),
          Text('${widget.gameSession.piecesPlaced}/${widget.gameSession.totalPieces}', style: const TextStyle(fontSize: 13)),
          ListenableBuilder(
            listenable: _zoomService,
            builder: (context, child) {
              return Text('${(_zoomService.zoomLevel * 100).round()}%', style: const TextStyle(fontSize: 13));
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
          padding: const EdgeInsets.all(12),
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
    
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[400]!),
        borderRadius: BorderRadius.circular(8),
        color: Colors.white,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final canvasInfo = widget.gameSession.canvasInfo;
          
          // For memory-optimized rendering, we want to use native pixel coordinates
          // to avoid scaling artifacts that create gaps
          if (widget.gameSession.useMemoryOptimization) {
          // Calculate scale for display but render pieces at exact pixel coordinates
          final scale = _calculateCanvasScale(canvasInfo.canvasSize, constraints.biggest);
          final displaySize = canvasInfo.canvasSize * scale;
          
          return Center(
          child: SizedBox(
          width: displaySize.width,
          height: displaySize.height,
          child: Stack(
          children: [
            // Custom painter for rendering all pieces
          CustomPaint(
            size: displaySize,
            painter: MemoryOptimizedPuzzlePainter(
                pieces: widget.gameSession.placedPieces,
                canvasSize: canvasInfo.canvasSize,
                  displaySize: displaySize,
                  ),
                  ),
                      // Drop zone overlay (now properly inside Stack)
                      _buildDropZoneOverlay(displaySize),
                    ],
                  ),
                ),
              );
          } else {
            // Legacy scaled rendering for non-memory-optimized mode
            final scale = _calculateCanvasScale(canvasInfo.canvasSize, constraints.biggest);
            final scaledSize = canvasInfo.canvasSize * scale;
            
            return Center(
              child: SizedBox(
                width: scaledSize.width,
                height: scaledSize.height,
                child: Stack(
                  children: [
                    // Canvas background
                    Container(
                      width: scaledSize.width,
                      height: scaledSize.height,
                      color: Colors.grey[50],
                      child: Center(
                        child: Text(
                          'Canvas ${canvasInfo.canvasSize.width.toInt()}x${canvasInfo.canvasSize.height.toInt()}',
                          style: TextStyle(
                            color: Colors.grey[300],
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    
                    // Placed pieces - each PNG is layered at full canvas scale
                    ...widget.gameSession.placedPieces.map((piece) =>
                      _buildCanvasPiece(piece, scaledSize)
                    ),
                    
                    // Drop zone overlay for drag targets
                    _buildDropZoneOverlay(scaledSize),
                  ],
                ),
              ),
            );
          }
        },
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
            child: Stack(
              children: [
                // Main tray grid with scroll controller
                ListenableBuilder(
                  listenable: _zoomService,
                  builder: (context, child) {
                    return _buildTrayGridWithScroll();
                  },
                ),
                
                // Accessible scroll stick positioned on the right edge
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: _buildAccessibleScrollStick(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTrayGrid() {
    // This method is replaced by _buildTrayGridWithScroll for accessibility
    return _buildTrayGridWithScroll();
  }
  
  Widget _buildTrayGridWithScroll() {
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
    // Leave space for scroll stick (30px)
    int piecesPerRow;
    if (isLandscape) {
      // In landscape, tray is vertical on the right side
      final availableWidth = MediaQuery.of(context).size.width * 0.25 - 32 - 30; // Minus scroll stick
      piecesPerRow = (availableWidth / totalCellSize).floor().clamp(1, 3);
    } else {
      // In portrait, tray is horizontal at bottom
      final availableWidth = MediaQuery.of(context).size.width - 32 - 30; // Minus scroll stick
      piecesPerRow = (availableWidth / totalCellSize).floor().clamp(2, 8);
    }
    
    // Ensure we don't have more columns than pieces
    piecesPerRow = piecesPerRow.clamp(1, sortedPieces.length);
    
    return Container(
      margin: const EdgeInsets.only(right: 30), // Space for scroll stick
      child: GridView.builder(
        controller: _trayScrollController,
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
            feedback: Container(
              width: zoomedPieceSize,
              height: zoomedPieceSize,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.blue, width: 2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: widget.gameSession.useMemoryOptimization
                  ? MemoryOptimizedPuzzleImage(
                      pieceId: piece.id,
                      assetManager: piece.memoryOptimizedAssetManager,
                      fit: BoxFit.contain,
                      zoomLevel: 1.0, // Don't double-apply zoom to feedback
                      cropToContent: true, // Crop for feedback display
                    )
                  : widget.gameSession.useEnhancedRendering
                      ? EnhancedCachedPuzzleImage(
                          pieceId: piece.id,
                          assetManager: piece.enhancedAssetManager,
                          fit: BoxFit.contain,
                          zoomLevel: 1.0, // Don't double-apply zoom to feedback
                          cropToContent: true, // Crop for feedback display
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
                child: widget.gameSession.useMemoryOptimization
                    ? MemoryOptimizedPuzzleImage(
                        pieceId: piece.id,
                        assetManager: piece.memoryOptimizedAssetManager,
                        fit: BoxFit.contain,
                        zoomLevel: 1.0, // Don't apply zoom here - grid cells handle sizing
                        cropToContent: true, // Crop for tray display
                      )
                    : widget.gameSession.useEnhancedRendering
                        ? EnhancedCachedPuzzleImage(
                            pieceId: piece.id,
                            assetManager: piece.enhancedAssetManager,
                            fit: BoxFit.contain,
                            zoomLevel: 1.0, // Don't apply zoom here - grid cells handle sizing
                            cropToContent: true, // Crop for tray display
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
      ),
    );
  }
  
  Widget _buildAccessibleScrollStick() {
    // Get sorted pieces for scroll stick calculations
    final sortingService = ref.watch(pieceSortingServiceProvider);
    final sortedPieces = sortingService.sortPieces(
      widget.gameSession.trayPieces,
      widget.gameSession.gridSize,
    );
    
    final orientation = MediaQuery.of(context).orientation;
    final isLandscape = orientation == Orientation.landscape;
    
    // Calculate visible item count based on grid layout
    final baseSize = 60.0;
    final zoomedPieceSize = baseSize * _zoomService.zoomLevel;
    final cellPadding = 4.0;
    final totalCellSize = zoomedPieceSize + cellPadding;
    
    int piecesPerRow;
    if (isLandscape) {
      final availableWidth = MediaQuery.of(context).size.width * 0.25 - 32 - 30;
      piecesPerRow = (availableWidth / totalCellSize).floor().clamp(1, 3);
    } else {
      final availableWidth = MediaQuery.of(context).size.width - 32 - 30;
      piecesPerRow = (availableWidth / totalCellSize).floor().clamp(2, 8);
    }
    
    // Calculate approximate visible rows
    final trayHeight = isLandscape 
        ? MediaQuery.of(context).size.height * 0.3 
        : MediaQuery.of(context).size.height * 0.2;
    final visibleRows = (trayHeight / totalCellSize).floor();
    final visibleItemCount = visibleRows * piecesPerRow;
    
    return TrayScrollStick(
      scrollController: _trayScrollController,
      itemCount: sortedPieces.length,
      visibleItemCount: visibleItemCount,
      stickWidth: 25.0, // Wider for better phone visibility
      stickHeight: 80.0, // Tall enough for easy thumb control
      onScrollChanged: () {
        // Optional: Add audio feedback for scroll
        _audioService.playUIClick();
        
        // Optional: Provide haptic feedback
        HapticFeedback.selectionClick();
      },
    );
  }
  
  Widget _buildControlButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // More compact buttons with smaller text and icons
          ElevatedButton.icon(
            onPressed: _getHint,
            icon: const Icon(Icons.lightbulb_outline, size: 16),
            label: const Text('Hint', style: TextStyle(fontSize: 12)),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: const Size(0, 32),
            ),
          ),
          ElevatedButton.icon(
            onPressed: widget.gameSession.isActive ? _pauseGame : _resumeGame,
            icon: Icon(widget.gameSession.isActive ? Icons.pause : Icons.play_arrow, size: 16),
            label: Text(widget.gameSession.isActive ? 'Pause' : 'Resume', style: const TextStyle(fontSize: 12)),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: const Size(0, 32),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => _zoomService.reset(),
            icon: const Icon(Icons.center_focus_strong, size: 16),
            label: const Text('Reset', style: TextStyle(fontSize: 12)),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: const Size(0, 32),
            ),
          ),
        ],
      ),
    );
  }
  
  // Event handlers with audio feedback
  
  /// Place piece at a specific position with precision checking
  void _placePieceAtPosition(PuzzlePiece piece, Offset position, Size canvasSize) async {
    setState(() {
      // This will be updated after the async call
    });
    
    try {
      final result = await widget.gameSession.tryPlacePieceAtPosition(piece, position, canvasSize);
      
      setState(() {
        switch (result) {
          case PlacementResult.success:
            _selectedPiece = null;
            _audioService.playPieceCorrect();
            HapticFeedback.lightImpact();
            
            _errorReporting.addBreadcrumb(
              'Piece placed correctly',
              category: 'game_action',
              data: {
                'piece_id': piece.id,
                'position': '${position.dx}, ${position.dy}',
                'session_id': widget.gameSession.sessionId,
              },
            );
            
            // Check if puzzle is completed
            if (widget.gameSession.isCompleted) {
              _audioService.playPuzzleCompleted();
              _errorReporting.addBreadcrumb(
                'Puzzle completed',
                category: 'game_lifecycle',
                data: {
                  'session_id': widget.gameSession.sessionId,
                  'final_score': widget.gameSession.score,
                },
              );
              _showCompletionDialog();
            }
            break;
            
          case PlacementResult.incorrectPosition:
            _audioService.playPieceIncorrect();
            HapticFeedback.mediumImpact();
            
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Try placing the piece closer to its correct position'),
                duration: Duration(seconds: 2),
                backgroundColor: Colors.orange,
              ),
            );
            break;
            
          case PlacementResult.alreadyPlaced:
            _audioService.playPieceIncorrect();
            HapticFeedback.mediumImpact();
            
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('This piece is already placed!'),
                duration: Duration(seconds: 1),
                backgroundColor: Colors.orange,
              ),
            );
            break;
        }
      });
    } catch (e, stackTrace) {
      _errorReporting.reportException(
        e,
        stackTrace: stackTrace,
        context: 'piece_placement_error',
        extra: {
          'piece_id': piece.id,
          'position': '${position.dx}, ${position.dy}',
          'session_id': widget.gameSession.sessionId,
        },
      );
      
      setState(() {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('An error occurred while placing the piece'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.red,
          ),
        );
      });
    }
  }
  
  /// Legacy method for backward compatibility
  void _placePieceOnCanvas(PuzzlePiece piece) {
    setState(() {
      try {
        final success = widget.gameSession.placePiece(piece);
        
        if (success) {
          _selectedPiece = null;
          _audioService.playPieceCorrect();
          
          // Add haptic feedback for correct placement
          HapticFeedback.lightImpact();
          
          // Report successful piece placement
          _errorReporting.addBreadcrumb(
            'Piece placed successfully',
            category: 'game_action',
            data: {
              'piece_id': piece.id,
              'session_id': widget.gameSession.sessionId,
              'pieces_remaining': widget.gameSession.piecesRemaining,
            },
          );
          
          // Check if puzzle is completed
          if (widget.gameSession.isCompleted) {
            _audioService.playPuzzleCompleted();
            
            // Report puzzle completion
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
          
          // Show error feedback
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Piece already placed!'),
              duration: Duration(seconds: 1),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e, stackTrace) {
        // Report piece placement error
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
        
        // Show user-friendly error message
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
  
  /// Remove an incorrectly placed piece back to the tray
  void _removeIncorrectPiece(PuzzlePiece piece) {
    setState(() {
      widget.gameSession.removeIncorrectPiece(piece);
      _audioService.playUIClick();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Piece ${piece.id} returned to tray'),
          duration: const Duration(seconds: 1),
          backgroundColor: Colors.blue,
        ),
      );
    });
  }
  
  // Legacy method for backward compatibility
  void _removePieceAtPosition(int row, int col) {
    setState(() {
      widget.gameSession.removePieceFromGrid(row, col);
      _audioService.playUIClick();
    });
  }
  
  /// Build a canvas piece at native pixel coordinates (for memory optimization)
  Widget _buildNativeCanvasPiece(PuzzlePiece piece, Size nativeCanvasSize) {
    return Positioned.fill(
      child: GestureDetector(
        onTap: () => _removePiece(piece),
        child: SizedBox(
          width: nativeCanvasSize.width,
          height: nativeCanvasSize.height,
          child: MemoryOptimizedPuzzleImage(
            pieceId: piece.id,
            assetManager: piece.memoryOptimizedAssetManager,
            width: nativeCanvasSize.width,
            height: nativeCanvasSize.height,
            fit: BoxFit.fill, // Use exact native size
            zoomLevel: 1.0,   // No zoom - native coordinates
            cropToContent: false, // Use positioned cropped content
          ),
        ),
      ),
    );
  }
  
  /// Build drop zone overlay at native coordinates
  Widget _buildNativeDropZoneOverlay(Size nativeCanvasSize) {
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
  
  /// Build a canvas piece (full padded PNG) - legacy method
  Widget _buildCanvasPiece(PuzzlePiece piece, Size scaledCanvasSize) {
    return Positioned.fill(
      child: GestureDetector(
        onTap: () => _removePiece(piece),
        child: SizedBox(
          width: scaledCanvasSize.width,
          height: scaledCanvasSize.height,
          child: widget.gameSession.useMemoryOptimization
              ? MemoryOptimizedPuzzleImage(
                  pieceId: piece.id,
                  assetManager: piece.memoryOptimizedAssetManager,
                  width: scaledCanvasSize.width,
                  height: scaledCanvasSize.height,
                  fit: BoxFit.fill, // Use exact size - no scaling needed
                  zoomLevel: 1.0,   // Scale handled by container size
                  cropToContent: false, // Use full padded PNG for canvas
                )
              : widget.gameSession.useEnhancedRendering
                  ? EnhancedCachedPuzzleImage(
                      pieceId: piece.id,
                      assetManager: piece.enhancedAssetManager,
                      width: scaledCanvasSize.width,
                      height: scaledCanvasSize.height,
                      fit: BoxFit.fill, // Use exact size - no scaling needed
                      zoomLevel: 1.0,   // Scale handled by container size
                      cropToContent: false, // Use full padded PNG
                    )
                  : CachedPuzzleImage(
                      pieceId: piece.id,
                      assetManager: piece.assetManager,
                      width: scaledCanvasSize.width,
                      height: scaledCanvasSize.height,
                      fit: BoxFit.fill, // Use exact size
                    ),
        ),
      ),
    );
  }
  
  /// Build drop zone overlay for canvas
  Widget _buildDropZoneOverlay(Size canvasSize) {
    return Positioned.fill(
      child: DragTarget<PuzzlePiece>(
        onWillAcceptWithDetails: (details) => details.data != null,
        onAcceptWithDetails: (details) => _placePieceAtPosition(details.data, details.offset, canvasSize),
        builder: (context, candidateData, rejectedData) {
          return Stack(
            children: [
              // Main drop zone
              Container(
                decoration: candidateData.isNotEmpty
                    ? BoxDecoration(
                        border: Border.all(color: Colors.blue, width: 3),
                        color: Colors.blue.withOpacity(0.1),
                      )
                    : null,
              ),
              // Render incorrectly placed pieces with red outline
              ...widget.gameSession.incorrectlyPlacedPieces.map((incorrectPiece) => 
                _buildIncorrectPiece(incorrectPiece, canvasSize)
              ),
            ],
          );
        },
      ),
    );
  }
  
  /// Build an incorrectly placed piece with red outline
  Widget _buildIncorrectPiece(IncorrectlyPlacedPiece incorrectPiece, Size canvasSize) {
    final piece = incorrectPiece.piece;
    final position = incorrectPiece.placedPosition;
    
    // Calculate piece display size
    final pieceSize = canvasSize.width / widget.gameSession.gridSize * 0.8; // Slightly smaller for visual clarity
    
    return Positioned(
      left: position.dx - pieceSize / 2,
      top: position.dy - pieceSize / 2,
      child: GestureDetector(
        onTap: () => _removeIncorrectPiece(piece),
        child: Container(
          width: pieceSize,
          height: pieceSize,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.red, width: 3),
            borderRadius: BorderRadius.circular(4),
            color: Colors.red.withOpacity(0.1),
          ),
          child: widget.gameSession.useMemoryOptimization
              ? MemoryOptimizedPuzzleImage(
                  pieceId: piece.id,
                  assetManager: piece.memoryOptimizedAssetManager,
                  fit: BoxFit.contain,
                  cropToContent: true,
                )
              : widget.gameSession.useEnhancedRendering
                  ? EnhancedCachedPuzzleImage(
                      pieceId: piece.id,
                      assetManager: piece.enhancedAssetManager,
                      fit: BoxFit.contain,
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
  }
  
  /// Calculate scale to fit canvas in available space
  double _calculateCanvasScale(Size canvasSize, Size availableSize) {
    final scaleX = availableSize.width / canvasSize.width;
    final scaleY = availableSize.height / canvasSize.height;
    
    // Use the smaller scale to ensure entire canvas fits
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

/// Custom painter that renders all memory-optimized pieces in a single paint operation
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
      final assetManager = piece.memoryOptimizedAssetManager;
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
