import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'dart:async';
import 'package:puzzgame_flutter/core/application/game_use_cases.dart';
// import 'package:puzzgame_flutter/core/application/settings_providers.dart'; // Not used
import 'package:puzzgame_flutter/core/infrastructure/service_locator.dart';
import 'package:puzzgame_flutter/game_module/puzzle_game_module.dart';
import 'package:puzzgame_flutter/game_module/services/memory_optimized_asset_manager.dart';
import 'package:puzzgame_flutter/game_module/services/memory_optimized_asset_manager_painters.dart';
import 'package:puzzgame_flutter/presentation/screens/metadata_validation_screen.dart';
import 'package:puzzgame_flutter/presentation/screens/positioning_debug_screen.dart';

/// Auto-solve screen for debugging piece alignment and gaps with pixel subtraction
class AutoSolveScreen extends ConsumerStatefulWidget {
  const AutoSolveScreen({super.key});

  @override
  ConsumerState<AutoSolveScreen> createState() => _AutoSolveScreenState();
}

class _AutoSolveScreenState extends ConsumerState<AutoSolveScreen> {
  PuzzleGameSession? _gameSession;
  bool _isLoading = true;
  bool _isAutoSolving = false;
  bool _pixelSubtractionMode = false;
  bool _isGeneratingDifference = false;
  double _currentZoom = 1.0;
  final TransformationController _transformationController = TransformationController();
  
  // For pixel subtraction
  ui.Image? _originalPreviewImage;
  ui.Image? _capturedPuzzleImage;
  ui.Image? _differenceImage;
  final GlobalKey _puzzleCanvasKey = GlobalKey();
  
  // Extreme zoom settings for pixel-level analysis
  static const double _minZoom = 0.1;
  static const double _maxZoom = 50.0; // 50x zoom for pixel analysis
  
  @override
  void initState() {
    super.initState();
    _initializeGame();
  }
  
  Future<void> _initializeGame() async {
    try {
      setState(() => _isLoading = true);
      
      // Get the highest difficulty for maximum pieces
      final difficulty = 3; // Hard difficulty for 15x15 grid
      final startGameUseCase = serviceLocator<StartGameUseCase>();
      final gameSession = await startGameUseCase.execute(difficulty: difficulty);
      
      if (gameSession is PuzzleGameSession) {
        setState(() {
          _gameSession = gameSession;
          _isLoading = false;
        });
        
        // Load the original preview image for pixel subtraction
        await _loadOriginalPreviewImage();
        
        print('AutoSolveScreen: Game initialized with ${gameSession.totalPieces} pieces');
      } else {
        throw Exception('Expected PuzzleGameSession but got ${gameSession.runtimeType}');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to initialize game: $e')),
        );
      }
    }
  }
  
  Future<void> _loadOriginalPreviewImage() async {
    try {
      final session = _gameSession!;
      final puzzleId = session.currentPuzzleId;
      
      // Load the original preview.jpg from assets
      final assetPath = 'assets/puzzles/$puzzleId/preview.jpg';
      final ByteData data = await rootBundle.load(assetPath);
      final Uint8List bytes = data.buffer.asUint8List();
      
      // Decode to ui.Image
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      _originalPreviewImage = frame.image;
      
      print('AutoSolveScreen: Loaded original preview image ${_originalPreviewImage!.width}x${_originalPreviewImage!.height}');
    } catch (e) {
      print('AutoSolveScreen: Failed to load original preview image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load original image: $e')),
        );
      }
    }
  }
  
  Future<void> _autoSolvePuzzle() async {
    if (_gameSession == null || _isAutoSolving) return;
    
    setState(() => _isAutoSolving = true);
    
    try {
      print('AutoSolveScreen: Starting auto-solve for ${_gameSession!.totalPieces} pieces');
      
      // Get all pieces in correct order (row by row)
      final allPieces = <PuzzlePiece>[];
      for (int row = 0; row < _gameSession!.gridSize; row++) {
        for (int col = 0; col < _gameSession!.gridSize; col++) {
          final pieceId = '${row}_$col';
          final piece = _gameSession!.trayPieces.firstWhere(
            (p) => p.id == pieceId,
            orElse: () => throw Exception('Piece $pieceId not found in tray'),
          );
          allPieces.add(piece);
        }
      }
      
      // Place all pieces with a small delay to show the process
      for (int i = 0; i < allPieces.length; i++) {
        final piece = allPieces[i];
        
        // Place the piece
        final success = _gameSession!.placePiece(piece);
        if (!success) {
          print('AutoSolveScreen: Failed to place piece ${piece.id}');
        } else {
          print('AutoSolveScreen: Placed piece ${piece.id} (${i + 1}/${allPieces.length})');
        }
        
        // Update UI every 10 pieces or at the end
        if (i % 10 == 0 || i == allPieces.length - 1) {
          setState(() {});
          // Small delay to see the progress
          await Future.delayed(const Duration(milliseconds: 50));
        }
      }
      
      print('AutoSolveScreen: Auto-solve completed! All pieces placed.');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Auto-solve completed! Use zoom to inspect piece alignment.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
      
    } catch (e) {
      print('AutoSolveScreen: Auto-solve failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Auto-solve failed: $e')),
        );
      }
    } finally {
      setState(() => _isAutoSolving = false);
    }
  }
  
  Future<void> _generatePixelDifference() async {
    if (_originalPreviewImage == null || _gameSession == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Original image not loaded or no game session')),
      );
      return;
    }
    
    setState(() => _isGeneratingDifference = true);
    
    try {
      // Capture the current puzzle state as an image
      await _capturePuzzleImage();
      
      if (_capturedPuzzleImage == null) {
        throw Exception('Failed to capture puzzle image');
      }
      
      // Generate difference image
      _differenceImage = await _createPixelDifferenceImage(
        _originalPreviewImage!,
        _capturedPuzzleImage!,
      );
      
      setState(() {});
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pixel difference generated! Areas of misalignment are highlighted.'),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 3),
          ),
        );
      }
      
    } catch (e) {
      print('AutoSolveScreen: Failed to generate pixel difference: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate difference: $e')),
        );
      }
    } finally {
      setState(() => _isGeneratingDifference = false);
    }
  }
  
  Future<void> _capturePuzzleImage() async {
    try {
      // Find the puzzle canvas render object
      final RenderObject? renderObject = _puzzleCanvasKey.currentContext?.findRenderObject();
      if (renderObject is! RenderRepaintBoundary) {
        throw Exception('Puzzle canvas is not a RenderRepaintBoundary');
      }
      
      // Capture the image at the natural size
      final ui.Image image = await renderObject.toImage(pixelRatio: 1.0);
      _capturedPuzzleImage = image;
      
      print('AutoSolveScreen: Captured puzzle image ${image.width}x${image.height}');
    } catch (e) {
      print('AutoSolveScreen: Failed to capture puzzle image: $e');
      rethrow;
    }
  }
  
  Future<ui.Image> _createPixelDifferenceImage(ui.Image original, ui.Image captured) async {
    // Convert both images to RGBA byte data
    final originalData = await original.toByteData(format: ui.ImageByteFormat.rawRgba);
    final capturedData = await captured.toByteData(format: ui.ImageByteFormat.rawRgba);
    
    if (originalData == null || capturedData == null) {
      throw Exception('Failed to convert images to byte data');
    }
    
    // Determine the output size (use the smaller dimensions)
    final outputWidth = original.width < captured.width ? original.width : captured.width;
    final outputHeight = original.height < captured.height ? original.height : captured.height;
    
    // Create output buffer
    final outputData = Uint8List(outputWidth * outputHeight * 4);
    
    final originalBytes = originalData.buffer.asUint8List();
    final capturedBytes = capturedData.buffer.asUint8List();
    
    // Calculate difference for each pixel
    for (int y = 0; y < outputHeight; y++) {
      for (int x = 0; x < outputWidth; x++) {
        final outputIndex = (y * outputWidth + x) * 4;
        
        // Get pixel coordinates for both images (handle scaling)
        final origX = (x * original.width / outputWidth).floor();
        final origY = (y * original.height / outputHeight).floor();
        final capX = (x * captured.width / outputWidth).floor();
        final capY = (y * captured.height / outputHeight).floor();
        
        final origIndex = (origY * original.width + origX) * 4;
        final capIndex = (capY * captured.width + capX) * 4;
        
        // Get RGB values
        final origR = originalBytes[origIndex];
        final origG = originalBytes[origIndex + 1];
        final origB = originalBytes[origIndex + 2];
        
        final capR = capturedBytes[capIndex];
        final capG = capturedBytes[capIndex + 1];
        final capB = capturedBytes[capIndex + 2];
        
        // Calculate absolute difference
        final diffR = (origR - capR).abs();
        final diffG = (origG - capG).abs();
        final diffB = (origB - capB).abs();
        
        // Calculate overall difference magnitude
        final diffMagnitude = (diffR + diffG + diffB) / 3;
        
        // Enhance visibility of differences
        if (diffMagnitude > 10) { // Threshold for visible difference
          // Highlight differences in red
          outputData[outputIndex] = 255; // Red
          outputData[outputIndex + 1] = (255 - diffMagnitude).clamp(0, 255).toInt(); // Green (reduced)
          outputData[outputIndex + 2] = (255 - diffMagnitude).clamp(0, 255).toInt(); // Blue (reduced)
          outputData[outputIndex + 3] = 255; // Alpha
        } else {
          // Show original image for areas with no significant difference
          outputData[outputIndex] = origR;
          outputData[outputIndex + 1] = origG;
          outputData[outputIndex + 2] = origB;
          outputData[outputIndex + 3] = 255; // Alpha
        }
      }
    }
    
    // Create image from processed data
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      outputData,
      outputWidth,
      outputHeight,
      ui.PixelFormat.rgba8888,
      (ui.Image result) => completer.complete(result),
    );
    
    return completer.future;
  }
  
  void _resetZoom() {
    _transformationController.value = Matrix4.identity();
    setState(() => _currentZoom = 1.0);
  }
  
  void _zoomIn() {
    final newZoom = (_currentZoom * 1.5).clamp(_minZoom, _maxZoom);
    _applyZoom(newZoom);
  }
  
  void _zoomOut() {
    final newZoom = (_currentZoom / 1.5).clamp(_minZoom, _maxZoom);
    _applyZoom(newZoom);
  }
  
  void _applyZoom(double zoom) {
    final matrix = Matrix4.identity()..scale(zoom);
    _transformationController.value = matrix;
    setState(() => _currentZoom = zoom);
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Auto-Solve Debug'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        actions: [
          if (_gameSession != null) ...[
            IconButton(
              onPressed: _isAutoSolving ? null : _autoSolvePuzzle,
              icon: _isAutoSolving 
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.play_arrow),
              tooltip: 'Auto-Solve',
            ),
            IconButton(
              onPressed: () => _initializeGame(),
              icon: const Icon(Icons.refresh),
              tooltip: 'Reset Puzzle',
            ),
            IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const MetadataValidationScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.data_object),
              tooltip: 'Validate Metadata',
            ),
            IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PositioningDebugScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.grid_on),
              tooltip: 'Debug Positioning',
            ),
            IconButton(
              onPressed: () {
                setState(() {
                  PuzzleDebugSettings.toggleDebugBounds();
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      PuzzleDebugSettings.showDebugBounds 
                        ? 'Debug bounds enabled' 
                        : 'Debug bounds disabled'
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              icon: Icon(
                PuzzleDebugSettings.showDebugBounds 
                  ? Icons.bug_report 
                  : Icons.bug_report_outlined
              ),
              tooltip: 'Toggle Debug Bounds',
            ),
          ],
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Initializing puzzle...'),
                ],
              ),
            )
          : _gameSession == null
              ? const Center(child: Text('Failed to load puzzle'))
              : Column(
                  children: [
                    // Info panel
                    _buildInfoPanel(),
                    
                    // Pixel subtraction controls
                    _buildPixelSubtractionControls(),
                    
                    // Zoom controls
                    _buildZoomControls(),
                    
                    // Main puzzle view with extreme zoom
                    Expanded(
                      child: _buildZoomablePuzzleView(),
                    ),
                  ],
                ),
    );
  }
  
  Widget _buildInfoPanel() {
    final session = _gameSession!;
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.grey[100],
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Text('Grid: ${session.gridSize}×${session.gridSize}'),
          Text('Pieces: ${session.piecesPlaced}/${session.totalPieces}'),
          Text('Zoom: ${_currentZoom.toStringAsFixed(1)}x'),
          if (session.useMemoryOptimization)
            const Text('Mode: Memory Optimized', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
  
  Widget _buildPixelSubtractionControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.blue[50],
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.compare, color: Colors.blue),
              const SizedBox(width: 8),
              const Text('Pixel Subtraction Analysis', style: TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              Switch(
                value: _pixelSubtractionMode,
                onChanged: (value) {
                  setState(() {
                    _pixelSubtractionMode = value;
                    if (!value) {
                      // Clear difference image when turning off
                      _differenceImage?.dispose();
                      _differenceImage = null;
                    }
                  });
                },
              ),
            ],
          ),
          if (_pixelSubtractionMode) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: _isGeneratingDifference ? null : _generatePixelDifference,
                  icon: _isGeneratingDifference 
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.analytics),
                  label: const Text('Generate Diff'),
                ),
                Text(
                  _originalPreviewImage != null 
                    ? 'Original: ${_originalPreviewImage!.width}×${_originalPreviewImage!.height}'
                    : 'Original: Not loaded',
                  style: TextStyle(
                    fontSize: 12,
                    color: _originalPreviewImage != null ? Colors.green : Colors.red,
                  ),
                ),
                Text(
                  _capturedPuzzleImage != null 
                    ? 'Captured: ${_capturedPuzzleImage!.width}×${_capturedPuzzleImage!.height}'
                    : 'Captured: Not captured',
                  style: TextStyle(
                    fontSize: 12,
                    color: _capturedPuzzleImage != null ? Colors.orange : Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Text(
                  _differenceImage != null 
                    ? 'Diff: ${_differenceImage!.width}×${_differenceImage!.height}'
                    : 'Diff: Not generated',
                  style: TextStyle(
                    fontSize: 12,
                    color: _differenceImage != null ? Colors.green : Colors.grey,
                  ),
                ),
                if (_gameSession != null)
                  Text(
                    'Canvas: ${_gameSession!.canvasInfo.canvasSize.width.toInt()}×${_gameSession!.canvasInfo.canvasSize.height.toInt()}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.blue,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildZoomControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.grey[200],
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          ElevatedButton.icon(
            onPressed: _zoomOut,
            icon: const Icon(Icons.zoom_out),
            label: const Text('Zoom Out'),
          ),
          ElevatedButton.icon(
            onPressed: _resetZoom,
            icon: const Icon(Icons.center_focus_strong),
            label: const Text('Reset'),
          ),
          ElevatedButton.icon(
            onPressed: _zoomIn,
            icon: const Icon(Icons.zoom_in),
            label: const Text('Zoom In'),
          ),
          Text('Range: ${_minZoom}x - ${_maxZoom}x'),
        ],
      ),
    );
  }
  
  Widget _buildZoomablePuzzleView() {
    return InteractiveViewer(
      transformationController: _transformationController,
      minScale: _minZoom,
      maxScale: _maxZoom,
      onInteractionUpdate: (details) {
        // Sync zoom level display
        final matrix = _transformationController.value;
        final scale = matrix.getMaxScaleOnAxis();
        if ((scale - _currentZoom).abs() > 0.01) {
          setState(() => _currentZoom = scale);
        }
      },
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.white,
        child: Center(
          child: _buildPuzzleCanvas(),
        ),
      ),
    );
  }
  
  Widget _buildPuzzleCanvas() {
    final session = _gameSession!;
    
    return LayoutBuilder(
      builder: (context, constraints) {
        // Use the canvas info to get the exact puzzle dimensions
        final canvasInfo = session.canvasInfo;
        final canvasSize = canvasInfo.canvasSize;
        
        // Scale to fit the available space while maintaining aspect ratio
        final scale = (constraints.maxWidth / canvasSize.width)
            .clamp(0.0, constraints.maxHeight / canvasSize.height);
        
        final scaledWidth = canvasSize.width * scale;
        final scaledHeight = canvasSize.height * scale;
        
        return RepaintBoundary(
          key: _puzzleCanvasKey,
          child: Container(
            width: scaledWidth,
            height: scaledHeight,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black, width: 2),
              color: Colors.white,
            ),
            child: Stack(
              children: [
                // Show appropriate image based on mode
                if (_pixelSubtractionMode && _differenceImage != null) ...[
                  // Show pixel difference image
                  _buildDifferenceImageDisplay(scaledWidth, scaledHeight),
                ] else ...[
                  // Show normal puzzle view
                  _buildCanvasGrid(scaledWidth, scaledHeight),
                  
                  // All placed pieces
                  ...session.placedPieces.map((piece) => 
                    _buildCanvasPiece(piece, Size(scaledWidth, scaledHeight))
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildDifferenceImageDisplay(double width, double height) {
    return CustomPaint(
      size: Size(width, height),
      painter: DifferenceImagePainter(_differenceImage!),
    );
  }
  
  Widget _buildCanvasGrid(double width, double height) {
    final session = _gameSession!;
    return CustomPaint(
      size: Size(width, height),
      painter: GridPainter(
        gridSize: session.gridSize,
        strokeWidth: 0.5,
        color: Colors.grey[300]!,
      ),
    );
  }
  
  Widget _buildCanvasPiece(PuzzlePiece piece, Size scaledCanvasSize) {
    return Positioned.fill(
      child: SizedBox(
        width: scaledCanvasSize.width,
        height: scaledCanvasSize.height,
        child: session.useMemoryOptimization
            ? MemoryOptimizedPuzzleImage(
                pieceId: piece.id,
                assetManager: piece.memoryOptimizedAssetManager,
                width: scaledCanvasSize.width,
                height: scaledCanvasSize.height,
                fit: BoxFit.fill,
                cropToContent: false, // Use full padded PNG for canvas
              )
            : Container(
                color: Colors.red.withOpacity(0.3),
                child: Center(
                  child: Text(
                    piece.id,
                    style: const TextStyle(fontSize: 8),
                  ),
                ),
              ),
      ),
    );
  }
  
  PuzzleGameSession get session => _gameSession!;
  
  @override
  void dispose() {
    _originalPreviewImage?.dispose();
    _capturedPuzzleImage?.dispose();
    _differenceImage?.dispose();
    super.dispose();
  }
}

/// Custom painter for drawing a reference grid
class GridPainter extends CustomPainter {
  final int gridSize;
  final double strokeWidth;
  final Color color;
  
  GridPainter({
    required this.gridSize,
    required this.strokeWidth,
    required this.color,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
    
    final cellWidth = size.width / gridSize;
    final cellHeight = size.height / gridSize;
    
    // Draw vertical lines
    for (int i = 0; i <= gridSize; i++) {
      final x = i * cellWidth;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }
    
    // Draw horizontal lines
    for (int i = 0; i <= gridSize; i++) {
      final y = i * cellHeight;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }
  }
  
  @override
  bool shouldRepaint(covariant GridPainter oldDelegate) {
    return oldDelegate.gridSize != gridSize ||
           oldDelegate.strokeWidth != strokeWidth ||
           oldDelegate.color != color;
  }
}

/// Custom painter for displaying the pixel difference image
class DifferenceImagePainter extends CustomPainter {
  final ui.Image image;
  
  DifferenceImagePainter(this.image);
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..filterQuality = FilterQuality.none; // Preserve pixel details
    
    final srcRect = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    final dstRect = Rect.fromLTWH(0, 0, size.width, size.height);
    
    canvas.drawImageRect(image, srcRect, dstRect, paint);
  }
  
  @override
  bool shouldRepaint(covariant DifferenceImagePainter oldDelegate) {
    return oldDelegate.image != image;
  }
}
