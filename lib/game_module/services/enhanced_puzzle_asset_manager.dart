// Enhanced Puzzle Asset Management System with Transparent Padding Removal
// File: lib/game_module/services/enhanced_puzzle_asset_manager.dart

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Enhanced asset manager that processes pieces to remove transparent padding
/// and provides optimized rendering for zoom-aware piece display
class EnhancedPuzzleAssetManager {
  static const String _assetBasePath = 'assets/puzzles/';
  
  // Current loaded puzzle state
  String? _currentPuzzleId;
  String? _currentGridSize;
  
  // Memory-efficient caches (only current grid size)
  final Map<String, ui.Image> _originalImageCache = {}; // Only cache original padded images
  final Map<String, PieceBounds> _pieceBoundsCache = {};
  final Map<String, Uint8List> _pieceDataCache = {};
  ui.Image? _fullPuzzleImage;
  String? _outlineSvg;
  
  // Preloading futures to avoid duplicate loading
  final Map<String, Future<void>> _loadingFutures = {};
  
  // Available puzzles metadata (lightweight)
  final Map<String, PuzzleMetadata> _availablePuzzles = {};
  bool _initialized = false;

  /// Initialize the asset manager and discover available puzzles
  Future<void> initialize() async {
    if (_initialized) return;
    
    // Discover available puzzles from bundled assets
    await _discoverBundledPuzzles();
    _initialized = true;
  }

  /// Get list of available puzzles for selection UI
  Future<List<PuzzleMetadata>> getAvailablePuzzles() async {
    await initialize();
    return _availablePuzzles.values.toList();
  }

  /// Get metadata for a specific puzzle
  PuzzleMetadata? getPuzzleMetadata(String puzzleId) {
    return _availablePuzzles[puzzleId];
  }

  /// Get canvas information for a specific puzzle/grid size
  Future<PuzzleCanvasInfo> getCanvasInfo(String puzzleId, String gridSize) async {
    return await PuzzleCanvasInfo.loadFromAssets(puzzleId, gridSize);
  }

  /// Preload and cache all assets for a specific puzzle and grid size
  /// This processes pieces to remove transparent padding and cache bounds
  Future<void> loadPuzzleGridSize(String puzzleId, String gridSize) async {
    final cacheKey = '${puzzleId}_$gridSize';
    
    // Avoid duplicate loading
    if (_loadingFutures.containsKey(cacheKey)) {
      return _loadingFutures[cacheKey]!;
    }

    // If this is already the current loaded puzzle/grid, no need to reload
    if (_currentPuzzleId == puzzleId && _currentGridSize == gridSize) {
      return;
    }

    final completer = Completer<void>();
    _loadingFutures[cacheKey] = completer.future;

    try {
      // Clear previous cache to free memory
      await _clearCurrentCache();

      // Load puzzle metadata
      final metadata = _availablePuzzles[puzzleId];
      if (metadata == null) {
        throw Exception('Puzzle $puzzleId not found');
      }

      if (!metadata.availableGridSizes.contains(gridSize)) {
        throw Exception('Grid size $gridSize not available for puzzle $puzzleId');
      }

      // Parse grid dimensions
      final dimensions = gridSize.split('x');
      final rows = int.parse(dimensions[0]);
      final cols = int.parse(dimensions[1]);

      // Batch load all piece images with enhanced processing
      await _loadAllPieceImagesWithProcessing(puzzleId, gridSize, rows, cols);
      
      // Load full puzzle image (for preview)
      await _loadFullPuzzleImage(puzzleId);
      
      // Load outline SVG if available
      await _loadOutlineSvg(puzzleId, gridSize);

      // Update current state
      _currentPuzzleId = puzzleId;
      _currentGridSize = gridSize;

      debugPrint('EnhancedPuzzleAssetManager: Loaded $puzzleId $gridSize with ${_originalImageCache.length} processed pieces');
      completer.complete();
    } catch (e) {
      completer.completeError(e);
      rethrow;
    } finally {
      _loadingFutures.remove(cacheKey);
    }
  }

  /// Get a cached original padded piece image (synchronous - call after loadPuzzleGridSize)
  ui.Image? getCachedPieceImage(String pieceId) {
    return _originalImageCache[pieceId];
  }

  /// Get a cached original padded piece image for canvas placement (synchronous - call after loadPuzzleGridSize)
  ui.Image? getCachedOriginalPieceImage(String pieceId) {
    return _originalImageCache[pieceId];
  }

  /// Get the bounds information for a piece (non-transparent area)
  PieceBounds? getPieceBounds(String pieceId) {
    return _pieceBoundsCache[pieceId];
  }

  /// Get the cached full puzzle image
  ui.Image? getCachedFullPuzzleImage() {
    return _fullPuzzleImage;
  }

  /// Get the cached outline SVG
  String? getCachedOutlineSvg() {
    return _outlineSvg;
  }

  /// Check if a specific puzzle/grid size combination is currently loaded
  bool isLoaded(String puzzleId, String gridSize) {
    return _currentPuzzleId == puzzleId && _currentGridSize == gridSize;
  }

  /// Get current loaded puzzle info
  String? get currentPuzzleId => _currentPuzzleId;
  String? get currentGridSize => _currentGridSize;

  /// Clear all caches to free memory
  Future<void> clearCache() async {
    await _clearCurrentCache();
    _currentPuzzleId = null;
    _currentGridSize = null;
  }

  /// Dispose resources
  void dispose() {
    _clearCurrentCache();
    _availablePuzzles.clear();
    _loadingFutures.clear();
  }

  // Private implementation methods

  Future<void> _discoverBundledPuzzles() async {
    // Hardcoded puzzle discovery for now - in production this could read from a manifest
    const knownPuzzles = ['sample_puzzle_01'];
    
    debugPrint('EnhancedPuzzleAssetManager: Discovering puzzles: $knownPuzzles');
    
    for (final puzzleId in knownPuzzles) {
      try {
        debugPrint('EnhancedPuzzleAssetManager: Loading metadata for puzzle $puzzleId');
        final metadata = await _loadPuzzleMetadata(puzzleId);
        _availablePuzzles[puzzleId] = metadata;
        debugPrint('EnhancedPuzzleAssetManager: Successfully loaded puzzle $puzzleId with grid sizes: ${metadata.availableGridSizes}');
      } catch (e) {
        debugPrint('EnhancedPuzzleAssetManager: Failed to load metadata for puzzle $puzzleId: $e');
      }
    }
    
    debugPrint('EnhancedPuzzleAssetManager: Total puzzles discovered: ${_availablePuzzles.length}');
  }

  Future<PuzzleMetadata> _loadPuzzleMetadata(String puzzleId) async {
    final basePath = '$_assetBasePath$puzzleId';
    debugPrint('EnhancedPuzzleAssetManager: Loading metadata for $puzzleId at $basePath');
    
    // Try to load manifest.json first
    String? manifestJson;
    try {
      manifestJson = await rootBundle.loadString('$basePath/manifest.json');
      debugPrint('EnhancedPuzzleAssetManager: Found manifest for $puzzleId');
    } catch (e) {
      debugPrint('EnhancedPuzzleAssetManager: No manifest found for $puzzleId: $e');
    }

    // Discover available grid sizes by checking layout directories
    final availableGridSizes = <String>[];
    // Check the grid sizes that match your actual assets
    const possibleGridSizes = ['8x8', '12x12', '15x15'];
    
    debugPrint('EnhancedPuzzleAssetManager: Checking grid sizes for $puzzleId');
    
    for (final gridSize in possibleGridSizes) {
      try {
        // Try to load the first piece to verify the grid size exists
        final testPath = '$basePath/layouts/${gridSize}_optimized/pieces/0_0.png';
        debugPrint('EnhancedPuzzleAssetManager: Testing path: $testPath');
        
        // Test if we can load the asset
        final data = await rootBundle.load(testPath);
        if (data.lengthInBytes > 0) {
          availableGridSizes.add(gridSize);
          debugPrint('EnhancedPuzzleAssetManager: ✅ Found grid size $gridSize for $puzzleId (${data.lengthInBytes} bytes)');
        }
      } catch (e) {
        debugPrint('EnhancedPuzzleAssetManager: ❌ Grid size $gridSize not available for $puzzleId: $e');
      }
    }

    if (availableGridSizes.isEmpty) {
      debugPrint('EnhancedPuzzleAssetManager: ❌ No valid grid sizes found for puzzle $puzzleId');
      debugPrint('EnhancedPuzzleAssetManager: Checked paths:');
      for (final gridSize in possibleGridSizes) {
        debugPrint('  - $basePath/layouts/$gridSize/pieces/0_0.png');
      }
      throw Exception('No valid grid sizes found for puzzle $puzzleId');
    }

    debugPrint('EnhancedPuzzleAssetManager: ✅ Found ${availableGridSizes.length} grid sizes for $puzzleId: $availableGridSizes');

    // Load preview image
    ui.Image? previewImage;
    try {
      final previewData = await rootBundle.load('$basePath/preview.jpg');
      final codec = await ui.instantiateImageCodec(previewData.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      previewImage = frame.image;
      debugPrint('EnhancedPuzzleAssetManager: ✅ Loaded preview image for $puzzleId');
    } catch (e) {
      debugPrint('EnhancedPuzzleAssetManager: ⚠️ No preview image found for $puzzleId: $e');
    }

    return PuzzleMetadata(
      id: puzzleId,
      name: _formatPuzzleName(puzzleId),
      availableGridSizes: availableGridSizes,
      previewImage: previewImage,
      manifest: manifestJson,
    );
  }

  Future<void> _loadAllPieceImagesWithProcessing(String puzzleId, String gridSize, int rows, int cols) async {
    final basePath = '$_assetBasePath$puzzleId/layouts/${gridSize}_optimized/pieces';
    
    // Create loading futures for all pieces
    final List<Future<void>> loadingFutures = [];
    
    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < cols; col++) {
        final pieceId = '${row}_$col';
        final assetPath = '$basePath/$pieceId.png';
        
        loadingFutures.add(_loadAndProcessSinglePieceImage(pieceId, assetPath));
      }
    }

    // Wait for all pieces to load and process
    await Future.wait(loadingFutures);
  }

  Future<void> _loadAndProcessSinglePieceImage(String pieceId, String assetPath) async {
    try {
      // Load the raw image data
      final ByteData data = await rootBundle.load(assetPath);
      final Uint8List bytes = data.buffer.asUint8List();
      
      // Cache the raw data
      _pieceDataCache[pieceId] = bytes;
      
      // Decode to ui.Image for processing
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final originalImage = frame.image;
      
      // Process the image to find bounds and create cropped version
      final processingResult = await _processPieceImage(originalImage, pieceId);
      
      // Cache original padded image (single cache for both modes)
      _originalImageCache[pieceId] = originalImage;
      
      // Process to find bounds for smart cropping during render
      _pieceBoundsCache[pieceId] = processingResult.bounds;
      
      // Don't create separate cropped image - we'll crop during rendering
      
    } catch (e) {
      debugPrint('Failed to load and process piece image $pieceId: $e');
      rethrow;
    }
  }

  /// Process a piece image to find non-transparent bounds and create a cropped version
  Future<PieceProcessingResult> _processPieceImage(ui.Image originalImage, String pieceId) async {
    // Convert image to byte data for pixel analysis
    final byteData = await originalImage.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) {
      throw Exception('Failed to convert image to byte data for piece $pieceId');
    }
    
    final bytes = byteData.buffer.asUint8List();
    final width = originalImage.width;
    final height = originalImage.height;
    
    // Find the bounds of non-transparent pixels
    int minX = width;
    int minY = height;
    int maxX = -1;
    int maxY = -1;
    
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final pixelIndex = (y * width + x) * 4; // RGBA = 4 bytes per pixel
        final alpha = bytes[pixelIndex + 3]; // Alpha channel
        
        if (alpha > 0) { // Non-transparent pixel
          minX = minX < x ? minX : x;
          minY = minY < y ? minY : y;
          maxX = maxX > x ? maxX : x;
          maxY = maxY > y ? maxY : y;
        }
      }
    }
    
    // Handle edge case where piece is completely transparent
    if (maxX == -1) {
      debugPrint('Warning: Piece $pieceId appears to be completely transparent');
      final bounds = PieceBounds(
        originalSize: Size(width.toDouble(), height.toDouble()),
        contentRect: Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
        hasContent: false,
      );
      return PieceProcessingResult(bounds);
    }
    
    // Calculate content bounds with some padding to avoid clipping
    const paddingPixels = 2; // Small padding to ensure we don't clip piece edges
    final contentLeft = (minX - paddingPixels).clamp(0, width - 1);
    final contentTop = (minY - paddingPixels).clamp(0, height - 1);
    final contentRight = (maxX + paddingPixels).clamp(0, width - 1);
    final contentBottom = (maxY + paddingPixels).clamp(0, height - 1);
    
    final contentWidth = contentRight - contentLeft + 1;
    final contentHeight = contentBottom - contentTop + 1;
    
    debugPrint('Piece $pieceId: original=${width}x$height, content=${contentWidth}x$contentHeight at ($contentLeft,$contentTop)');
    
    // Create bounds information
    final bounds = PieceBounds(
      originalSize: Size(width.toDouble(), height.toDouble()),
      contentRect: Rect.fromLTWH(
        contentLeft.toDouble(), 
        contentTop.toDouble(), 
        contentWidth.toDouble(), 
        contentHeight.toDouble()
      ),
      hasContent: true,
    );
    
    return PieceProcessingResult(bounds);
  }

  Future<void> _loadFullPuzzleImage(String puzzleId) async {
    try {
      final basePath = '$_assetBasePath$puzzleId';
      final data = await rootBundle.load('$basePath/preview.jpg');
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      _fullPuzzleImage = frame.image;
    } catch (e) {
      debugPrint('Failed to load full puzzle image for $puzzleId: $e');
    }
  }

  Future<void> _loadOutlineSvg(String puzzleId, String gridSize) async {
    try {
      final basePath = '$_assetBasePath$puzzleId/layouts/${gridSize}_optimized';
      _outlineSvg = await rootBundle.loadString('$basePath/outline.svg');
    } catch (e) {
      debugPrint('Failed to load outline SVG for $puzzleId $gridSize: $e');
    }
  }

  Future<void> _clearCurrentCache() async {
    // Dispose ui.Image objects to free memory
    for (final image in _originalImageCache.values) {
      image.dispose();
    }
    _originalImageCache.clear();
    _pieceBoundsCache.clear();
    _pieceDataCache.clear();
    
    _fullPuzzleImage?.dispose();
    _fullPuzzleImage = null;
    _outlineSvg = null;
  }

  String _formatPuzzleName(String puzzleId) {
    return puzzleId
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) => word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }
}

/// Information about the bounds of a puzzle piece
class PieceBounds {
  final Size originalSize;
  final Rect contentRect;
  final bool hasContent;
  
  const PieceBounds({
    required this.originalSize,
    required this.contentRect,
    required this.hasContent,
  });
  
  /// Get the scale factor to fit the content in a given size while maintaining aspect ratio
  double getScaleFactorForSize(Size targetSize) {
    if (!hasContent) return 1.0;
    
    final scaleX = targetSize.width / contentRect.width;
    final scaleY = targetSize.height / contentRect.height;
    return (scaleX < scaleY ? scaleX : scaleY).clamp(0.1, 10.0);
  }
  
  /// Get the offset needed to center the content in a given size
  Offset getCenterOffset(Size targetSize, double scale) {
    if (!hasContent) return Offset.zero;
    
    final scaledWidth = contentRect.width * scale;
    final scaledHeight = contentRect.height * scale;
    
    final offsetX = (targetSize.width - scaledWidth) / 2;
    final offsetY = (targetSize.height - scaledHeight) / 2;
    
    return Offset(offsetX, offsetY);
  }
}

/// Result of piece image processing (no longer creates cropped image)
class PieceProcessingResult {
  final PieceBounds bounds;
  
  const PieceProcessingResult(this.bounds);
}

/// Lightweight metadata about a puzzle (unchanged from original)
class PuzzleMetadata {
  final String id;
  final String name;
  final List<String> availableGridSizes;
  final ui.Image? previewImage;
  final String? manifest;

  const PuzzleMetadata({
    required this.id,
    required this.name,
    required this.availableGridSizes,
    this.previewImage,
    this.manifest,
  });

  void dispose() {
    previewImage?.dispose();
  }
}

/// Enhanced cached image widget for puzzle pieces with zoom-aware rendering
class EnhancedCachedPuzzleImage extends StatelessWidget {
  final String pieceId;
  final EnhancedPuzzleAssetManager assetManager;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double zoomLevel;
  final Widget? placeholder;
  final Widget? errorWidget;
  final bool cropToContent;

  const EnhancedCachedPuzzleImage({
    super.key,
    required this.pieceId,
    required this.assetManager,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.zoomLevel = 1.0,
    this.placeholder,
    this.errorWidget,
    this.cropToContent = true,
  });

  @override
  Widget build(BuildContext context) {
    final originalImage = assetManager.getCachedOriginalPieceImage(pieceId);
    final bounds = assetManager.getPieceBounds(pieceId);
    
    if (originalImage != null && bounds != null) {
      if (cropToContent) {
        // Use smart cropping painter for tray display
        return CustomPaint(
          size: Size(width ?? double.infinity, height ?? double.infinity),
          painter: SmartCroppedImagePainter(
            image: originalImage,
            bounds: bounds,
            fit: fit,
            zoomLevel: zoomLevel,
          ),
        );
      } else {
        // Use original padded image for canvas placement
        return CustomPaint(
          size: Size(width ?? double.infinity, height ?? double.infinity),
          painter: OriginalImagePainter(
            image: originalImage,
            fit: fit,
          ),
        );
      }
    }

    return errorWidget ?? 
           placeholder ??
           Container(
             width: width,
             height: height,
             color: Colors.grey[300],
             child: Center(
               child: Text(
                 pieceId,
                 style: const TextStyle(fontSize: 10),
               ),
             ),
           );
  }
}

/// Smart cropping painter that crops from original image during render
class SmartCroppedImagePainter extends CustomPainter {
  final ui.Image image;
  final PieceBounds bounds;
  final BoxFit fit;
  final double zoomLevel;

  SmartCroppedImagePainter({
    required this.image,
    required this.bounds,
    required this.fit,
    required this.zoomLevel,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (!bounds.hasContent) {
      // Draw placeholder for empty pieces
      final paint = Paint()
        ..color = Colors.grey[200]!
        ..style = PaintingStyle.fill;
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
      return;
    }

    // Crop the original image to content bounds during rendering
    final srcRect = bounds.contentRect; // Use content bounds as source
    final destRect = _calculateDestRect(size);
    
    // Apply zoom-aware scaling
    final zoomedDestRect = Rect.fromLTWH(
      destRect.left,
      destRect.top,
      destRect.width * zoomLevel,
      destRect.height * zoomLevel,
    );
    
    // Center the zoomed image
    final centeredRect = Rect.fromLTWH(
      (size.width - zoomedDestRect.width) / 2,
      (size.height - zoomedDestRect.height) / 2,
      zoomedDestRect.width,
      zoomedDestRect.height,
    );
    
    // Draw cropped content from original image
    canvas.drawImageRect(image, srcRect, centeredRect, Paint()..filterQuality = FilterQuality.medium);
    
    // Optional: Draw debug bounds
    if (kDebugMode) { // Set to true to see bounds in debug mode
      // _drawDebugBounds(canvas, centeredRect);
    }
  }

  Rect _calculateDestRect(Size size) {
    final contentSize = bounds.contentRect.size;
    
    switch (fit) {
      case BoxFit.fill:
        return Rect.fromLTWH(0, 0, size.width, size.height);
      case BoxFit.contain:
        final scale = (size.width / contentSize.width).clamp(0.0, size.height / contentSize.height);
        final scaledWidth = contentSize.width * scale;
        final scaledHeight = contentSize.height * scale;
        final dx = (size.width - scaledWidth) / 2;
        final dy = (size.height - scaledHeight) / 2;
        return Rect.fromLTWH(dx, dy, scaledWidth, scaledHeight);
      case BoxFit.cover:
      default:
        final scale = (size.width / contentSize.width).clamp(size.height / contentSize.height, double.infinity);
        final scaledWidth = contentSize.width * scale;
        final scaledHeight = contentSize.height * scale;
        final dx = (size.width - scaledWidth) / 2;
        final dy = (size.height - scaledHeight) / 2;
        return Rect.fromLTWH(dx, dy, scaledWidth, scaledHeight);
    }
  }

  // void _drawDebugBounds(Canvas canvas, Rect destRect) {
  //   final debugPaint = Paint()
  //     ..color = Colors.green.withOpacity(0.3)
  //     ..style = PaintingStyle.stroke
  //     ..strokeWidth = 1.0;
  //   canvas.drawRect(destRect, debugPaint);
  // }

  @override
  bool shouldRepaint(covariant SmartCroppedImagePainter oldDelegate) {
    return oldDelegate.image != image ||
           oldDelegate.zoomLevel != zoomLevel ||
           oldDelegate.fit != fit;
  }
}

/// Custom painter for original padded images (canvas mode)
class OriginalImagePainter extends CustomPainter {
  final ui.Image image;
  final BoxFit fit;

  OriginalImagePainter({
    required this.image,
    required this.fit,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final srcRect = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    final destRect = _getDestRect(size);
    
    // Draw the full padded image - padding handles positioning
    canvas.drawImageRect(image, srcRect, destRect, Paint()..filterQuality = FilterQuality.medium);
    
    // Optional: Draw debug bounds
    if (kDebugMode) { // Set to true to see bounds in debug mode
      // _drawDebugBounds(canvas, destRect);
    }
  }

  Rect _getDestRect(Size size) {
    switch (fit) {
      case BoxFit.fill:
        return Rect.fromLTWH(0, 0, size.width, size.height);
      case BoxFit.contain:
        final scale = (size.width / image.width).clamp(0.0, size.height / image.height);
        final scaledWidth = image.width * scale;
        final scaledHeight = image.height * scale;
        final dx = (size.width - scaledWidth) / 2;
        final dy = (size.height - scaledHeight) / 2;
        return Rect.fromLTWH(dx, dy, scaledWidth, scaledHeight);
      case BoxFit.cover:
      default:
        final scale = (size.width / image.width).clamp(size.height / image.height, double.infinity);
        final scaledWidth = image.width * scale;
        final scaledHeight = image.height * scale;
        final dx = (size.width - scaledWidth) / 2;
        final dy = (size.height - scaledHeight) / 2;
        return Rect.fromLTWH(dx, dy, scaledWidth, scaledHeight);
    }
  }

  // void _drawDebugBounds(Canvas canvas, Rect destRect) {
  //   final debugPaint = Paint()
  //     ..color = Colors.blue.withOpacity(0.3)
  //     ..style = PaintingStyle.stroke
  //     ..strokeWidth = 2.0;
  //   canvas.drawRect(destRect, debugPaint);
  // }

  @override
  bool shouldRepaint(covariant OriginalImagePainter oldDelegate) {
    return oldDelegate.image != image || oldDelegate.fit != fit;
  }
}

/// Canvas information for puzzle layout
class PuzzleCanvasInfo {
  final Size canvasSize;
  
  const PuzzleCanvasInfo({required this.canvasSize});
  
  static Future<PuzzleCanvasInfo> loadFromAssets(String puzzleId, String gridSize) async {
    final layoutPath = 'assets/puzzles/$puzzleId/layouts/${gridSize}_optimized/layout.ipuz.json';
    final jsonString = await rootBundle.loadString(layoutPath);
    final jsonData = json.decode(jsonString);
    
    final canvas = jsonData['canvas'];
    return PuzzleCanvasInfo(
      canvasSize: Size(canvas['width'].toDouble(), canvas['height'].toDouble()),
    );
  }
}

/// Parameters for rendering calculations
class RenderParameters {
  final double scale;
  
  const RenderParameters({required this.scale});
}
