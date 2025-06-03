// High-Performance Puzzle Asset Management System
// File: lib/game_module/services/puzzle_asset_manager.dart

import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// High-performance puzzle asset manager optimized for memory and UI performance
/// Only loads one grid size at a time, with fast switching between grid sizes
class PuzzleAssetManager {
  static const String _assetBasePath = 'assets/puzzles/';
  
  // Current loaded puzzle state
  String? _currentPuzzleId;
  String? _currentGridSize;
  
  // Memory-efficient caches (only current grid size)
  final Map<String, ui.Image> _pieceImageCache = {};
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

  /// Preload and cache all assets for a specific puzzle and grid size
  /// This should be called when user selects a puzzle/grid size combination
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

      // Batch load all piece images
      await _loadAllPieceImages(puzzleId, gridSize, rows, cols);
      
      // Load full puzzle image (for preview)
      await _loadFullPuzzleImage(puzzleId);
      
      // Load outline SVG if available
      await _loadOutlineSvg(puzzleId, gridSize);

      // Update current state
      _currentPuzzleId = puzzleId;
      _currentGridSize = gridSize;

      completer.complete();
    } catch (e) {
      completer.completeError(e);
      rethrow;
    } finally {
      _loadingFutures.remove(cacheKey);
    }
  }

  /// Get a cached piece image (synchronous - call after loadPuzzleGridSize)
  ui.Image? getCachedPieceImage(String pieceId) {
    return _pieceImageCache[pieceId];
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
    
    for (final puzzleId in knownPuzzles) {
      try {
        final metadata = await _loadPuzzleMetadata(puzzleId);
        _availablePuzzles[puzzleId] = metadata;
      } catch (e) {
        debugPrint('Failed to load metadata for puzzle $puzzleId: $e');
      }
    }
  }

  Future<PuzzleMetadata> _loadPuzzleMetadata(String puzzleId) async {
    final basePath = '$_assetBasePath$puzzleId';
    
    // Try to load manifest.json first
    String? manifestJson;
    try {
      manifestJson = await rootBundle.loadString('$basePath/manifest.json');
    } catch (e) {
      debugPrint('No manifest found for $puzzleId');
    }

    // Discover available grid sizes by checking layout directories
    final availableGridSizes = <String>[];
    const possibleGridSizes = ['8x8', '12x12', '15x15', '16x16', '32x32'];
    
    for (final gridSize in possibleGridSizes) {
      try {
        // Check if this grid size exists by testing a piece file
        await rootBundle.load('$basePath/layouts/$gridSize/pieces/0_0.png');
        availableGridSizes.add(gridSize);
      } catch (e) {
        // Grid size not available
      }
    }

    if (availableGridSizes.isEmpty) {
      throw Exception('No valid grid sizes found for puzzle $puzzleId');
    }

    // Load preview image
    ui.Image? previewImage;
    try {
      final previewData = await rootBundle.load('$basePath/preview.jpg');
      final codec = await ui.instantiateImageCodec(previewData.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      previewImage = frame.image;
    } catch (e) {
      debugPrint('No preview image found for $puzzleId');
    }

    return PuzzleMetadata(
      id: puzzleId,
      name: _formatPuzzleName(puzzleId),
      availableGridSizes: availableGridSizes,
      previewImage: previewImage,
      manifest: manifestJson,
    );
  }

  Future<void> _loadAllPieceImages(String puzzleId, String gridSize, int rows, int cols) async {
    final basePath = '$_assetBasePath$puzzleId/layouts/$gridSize/pieces';
    
    // Create loading futures for all pieces
    final List<Future<void>> loadingFutures = [];
    
    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < cols; col++) {
        final pieceId = '${row}_$col';
        final assetPath = '$basePath/$pieceId.png';
        
        loadingFutures.add(_loadSinglePieceImage(pieceId, assetPath));
      }
    }

    // Wait for all pieces to load
    await Future.wait(loadingFutures);
  }

  Future<void> _loadSinglePieceImage(String pieceId, String assetPath) async {
    try {
      // Load the raw image data
      final ByteData data = await rootBundle.load(assetPath);
      final Uint8List bytes = data.buffer.asUint8List();
      
      // Cache the raw data
      _pieceDataCache[pieceId] = bytes;
      
      // Decode to ui.Image for immediate use
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      _pieceImageCache[pieceId] = frame.image;
      
    } catch (e) {
      debugPrint('Failed to load piece image $pieceId: $e');
      rethrow;
    }
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
      final basePath = '$_assetBasePath$puzzleId/layouts/$gridSize';
      _outlineSvg = await rootBundle.loadString('$basePath/outline.svg');
    } catch (e) {
      debugPrint('Failed to load outline SVG for $puzzleId $gridSize: $e');
    }
  }

  Future<void> _clearCurrentCache() async {
    // Dispose ui.Image objects to free memory
    for (final image in _pieceImageCache.values) {
      image.dispose();
    }
    _pieceImageCache.clear();
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

/// Lightweight metadata about a puzzle
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

/// High-performance cached image widget for puzzle pieces
class CachedPuzzleImage extends StatelessWidget {
  final String pieceId;
  final PuzzleAssetManager assetManager;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;

  const CachedPuzzleImage({
    super.key,
    required this.pieceId,
    required this.assetManager,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    final image = assetManager.getCachedPieceImage(pieceId);
    
    if (image != null) {
      return CustomPaint(
        size: Size(width ?? double.infinity, height ?? double.infinity),
        painter: _ImagePainter(image, fit),
      );
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

/// Custom painter for maximum performance image rendering
class _ImagePainter extends CustomPainter {
  final ui.Image image;
  final BoxFit fit;

  _ImagePainter(this.image, this.fit);

  @override
  void paint(Canvas canvas, Size size) {
    final srcRect = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    final destRect = _getDestRect(size);
    
    canvas.drawImageRect(image, srcRect, destRect, Paint());
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

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
