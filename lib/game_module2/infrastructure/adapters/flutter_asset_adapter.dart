import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import '../../domain/ports/asset_repository.dart';
import '../../domain/value_objects/piece_bounds.dart';

/// Flutter implementation of the AssetRepository port.
/// 
/// This adapter loads puzzle assets from the Flutter asset bundle,
/// handling the transformation from file system to domain objects.
class FlutterAssetAdapter implements AssetRepository {
  static const String _assetBasePath = 'assets/puzzles/';
  
  // Caches to avoid reloading
  final Map<String, PuzzleMetadata> _metadataCache = {};
  final Map<String, ui.Image> _imageCache = {};
  final Map<String, PieceAssetData> _pieceDataCache = {};
  
  @override
  Future<PuzzleMetadata> loadPuzzleMetadata(String puzzleId) async {
    // Check cache
    if (_metadataCache.containsKey(puzzleId)) {
      return _metadataCache[puzzleId]!;
    }
    
    final basePath = '$_assetBasePath$puzzleId';
    
    try {
      // Try to load manifest.json
      final manifestPath = '$basePath/manifest.json';
      final manifestJson = await rootBundle.loadString(manifestPath);
      final manifest = json.decode(manifestJson);
      
      final metadata = PuzzleMetadata(
        id: puzzleId,
        name: manifest['name'] ?? puzzleId,
        description: manifest['description'],
        availableGridSizes: _discoverGridSizes(puzzleId),
        previewImagePath: manifest['previewImage'],
        additionalData: manifest['metadata'],
      );
      
      _metadataCache[puzzleId] = metadata;
      return metadata;
      
    } catch (e) {
      // Fallback: discover available grid sizes
      final gridSizes = _discoverGridSizes(puzzleId);
      
      final metadata = PuzzleMetadata(
        id: puzzleId,
        name: puzzleId.replaceAll('_', ' ').toUpperCase(),
        availableGridSizes: gridSizes,
      );
      
      _metadataCache[puzzleId] = metadata;
      return metadata;
    }
  }

  @override
  Future<List<PieceAssetData>> loadPuzzleAssets(
    String puzzleId, 
    String gridSize,
  ) async {
    final cacheKey = '${puzzleId}_$gridSize';
    
    // Check if already loaded
    final cached = _pieceDataCache.entries
        .where((e) => e.key.startsWith(cacheKey))
        .map((e) => e.value)
        .toList();
    
    if (cached.isNotEmpty) {
      return cached;
    }
    
    final layoutPath = '$_assetBasePath$puzzleId/layouts/$gridSize';
    
    // Load layout metadata
    final layoutJson = await rootBundle.loadString('$layoutPath/layout.ipuz.json');
    final layout = json.decode(layoutJson);
    
    // Get canvas dimensions
    final canvasWidth = layout['canvas']['width'].toDouble();
    final canvasHeight = layout['canvas']['height'].toDouble();
    final paddedSize = Size(canvasWidth, canvasHeight);
    
    // Parse grid dimensions
    final dims = gridSize.split('x');
    final rows = int.parse(dims[0]);
    final cols = int.parse(dims[1]);
    
    // Check for optimized metadata
    List<PieceAssetData> pieces = [];
    
    try {
      // Try to load optimization metadata if available
      final metadataPath = '$layoutPath/optimization_metadata.json';
      final metadataJson = await rootBundle.loadString(metadataPath);
      final metadata = json.decode(metadataJson);
      
      // Load pieces from optimized metadata
      final piecesData = metadata['pieces'] as Map<String, dynamic>;
      
      for (final entry in piecesData.entries) {
        final pieceId = entry.key;
        final pieceData = entry.value;
        
        // Parse row and column from piece ID (format: "row_col")
        final parts = pieceId.split('_');
        final row = int.parse(parts[0]);
        final col = int.parse(parts[1]);
        
        // Extract bounds from metadata
        final boundsData = pieceData['bounds'];
        final contentBounds = ContentRect(
          left: boundsData['left'].toDouble(),
          top: boundsData['top'].toDouble(),
          right: boundsData['right'].toDouble(),
          bottom: boundsData['bottom'].toDouble(),
        );
        
        // Calculate target bounds (where piece should be placed)
        final pieceWidth = canvasWidth / cols;
        final pieceHeight = canvasHeight / rows;
        final targetBounds = ContentRect(
          left: (col * pieceWidth).toDouble(),
          top: (row * pieceHeight).toDouble(),
          right: ((col + 1) * pieceWidth).toDouble(),
          bottom: ((row + 1) * pieceHeight).toDouble(),
        );
        
        final bounds = PieceBounds(
          contentBounds: contentBounds,
          paddedSize: paddedSize,
          targetBounds: targetBounds,
        );
        
        final assetData = PieceAssetData(
          pieceId: pieceId,
          row: row,
          col: col,
          bounds: bounds,
          imagePath: '$layoutPath/pieces/$pieceId.png',
          metadata: pieceData,
        );
        
        pieces.add(assetData);
        _pieceDataCache['${cacheKey}_$pieceId'] = assetData;
      }
      
    } catch (e) {
      // Fallback: Generate piece data without optimization metadata
      for (int row = 0; row < rows; row++) {
        for (int col = 0; col < cols; col++) {
          final pieceId = '${row}_$col';
          
          // Estimate bounds (will use full padded image)
          final pieceWidth = canvasWidth / cols;
          final pieceHeight = canvasHeight / rows;
          
          final contentBounds = ContentRect(
            left: (col * pieceWidth).toDouble(),
            top: (row * pieceHeight).toDouble(),
            right: ((col + 1) * pieceWidth).toDouble(),
            bottom: ((row + 1) * pieceHeight).toDouble(),
          );
          
          final bounds = PieceBounds(
            contentBounds: contentBounds,
            paddedSize: paddedSize,
            targetBounds: contentBounds,
          );
          
          final assetData = PieceAssetData(
            pieceId: pieceId,
            row: row,
            col: col,
            bounds: bounds,
            imagePath: '$layoutPath/pieces/$pieceId.png',
          );
          
          pieces.add(assetData);
          _pieceDataCache['${cacheKey}_$pieceId'] = assetData;
        }
      }
    }
    
    return pieces;
  }

  @override
  Future<ui.Image> loadPieceImage(
    String puzzleId,
    String gridSize,
    String pieceId,
  ) async {
    final cacheKey = '${puzzleId}_${gridSize}_$pieceId';
    
    // Check cache
    if (_imageCache.containsKey(cacheKey)) {
      return _imageCache[cacheKey]!;
    }
    
    final imagePath = '$_assetBasePath$puzzleId/layouts/$gridSize/pieces/$pieceId.png';
    
    // Load image data
    final data = await rootBundle.load(imagePath);
    final bytes = data.buffer.asUint8List();
    
    // Decode image
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    
    // Cache and return
    _imageCache[cacheKey] = image;
    return image;
  }

  @override
  Future<PieceBounds> getPieceBounds(
    String puzzleId,
    String gridSize,
    String pieceId,
  ) async {
    final cacheKey = '${puzzleId}_${gridSize}_$pieceId';
    
    final assetData = _pieceDataCache[cacheKey];
    if (assetData != null) {
      return assetData.bounds;
    }
    
    // Load all assets if not cached
    final assets = await loadPuzzleAssets(puzzleId, gridSize);
    final piece = assets.firstWhere((a) => a.pieceId == pieceId);
    return piece.bounds;
  }

  @override
  Future<ui.Image> loadPreviewImage(String puzzleId) async {
    final cacheKey = '${puzzleId}_preview';
    
    if (_imageCache.containsKey(cacheKey)) {
      return _imageCache[cacheKey]!;
    }
    
    // Try different possible preview locations
    final possiblePaths = [
      '$_assetBasePath$puzzleId/preview.png',
      '$_assetBasePath$puzzleId/preview.jpg',
      '$_assetBasePath$puzzleId/full.png',
      '$_assetBasePath$puzzleId/full.jpg',
    ];
    
    for (final path in possiblePaths) {
      try {
        final data = await rootBundle.load(path);
        final bytes = data.buffer.asUint8List();
        
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        final image = frame.image;
        
        _imageCache[cacheKey] = image;
        return image;
      } catch (_) {
        // Try next path
      }
    }
    
    throw Exception('No preview image found for puzzle $puzzleId');
  }

  @override
  Future<List<PuzzleMetadata>> getAvailablePuzzles() async {
    // For now, hardcode known puzzles
    // In production, this would read from a manifest or API
    const knownPuzzles = ['sample_puzzle_01'];
    
    final puzzles = <PuzzleMetadata>[];
    for (final puzzleId in knownPuzzles) {
      try {
        final metadata = await loadPuzzleMetadata(puzzleId);
        puzzles.add(metadata);
      } catch (e) {
        print('Failed to load puzzle $puzzleId: $e');
      }
    }
    
    return puzzles;
  }

  @override
  Future<bool> isPuzzleAvailable(String puzzleId) async {
    try {
      await loadPuzzleMetadata(puzzleId);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> downloadPuzzle(String puzzleId) async {
    // In this implementation, all puzzles are bundled with the app
    // In production, this would download from a server
    throw UnimplementedError('Puzzle downloading not implemented');
  }

  /// Discover available grid sizes for a puzzle
  List<String> _discoverGridSizes(String puzzleId) {
    // For now, return standard sizes
    // In production, this would scan the asset directory
    return ['8x8', '12x12', '15x15'];
  }

  /// Clear all caches
  void clearCache() {
    _metadataCache.clear();
    _imageCache.clear();
    _pieceDataCache.clear();
  }
}
