import 'dart:ui' as ui;
import '../value_objects/piece_bounds.dart';

/// Port interface for loading and managing puzzle assets.
/// 
/// This interface defines how the domain layer interacts with asset storage,
/// hiding implementation details about file systems, network sources, etc.
abstract class AssetRepository {
  /// Load metadata for a specific puzzle
  Future<PuzzleMetadata> loadPuzzleMetadata(String puzzleId);
  
  /// Load all pieces for a puzzle at a specific grid size
  Future<List<PieceAssetData>> loadPuzzleAssets(String puzzleId, String gridSize);
  
  /// Load a single piece image
  Future<ui.Image> loadPieceImage(String puzzleId, String gridSize, String pieceId);
  
  /// Get the bounds information for a piece
  Future<PieceBounds> getPieceBounds(String puzzleId, String gridSize, String pieceId);
  
  /// Load the full puzzle preview image
  Future<ui.Image> loadPreviewImage(String puzzleId);
  
  /// Get available puzzles
  Future<List<PuzzleMetadata>> getAvailablePuzzles();
  
  /// Check if a puzzle is available locally
  Future<bool> isPuzzleAvailable(String puzzleId);
  
  /// Download a puzzle if not available locally
  Future<void> downloadPuzzle(String puzzleId);
}

/// Metadata about a puzzle
class PuzzleMetadata {
  final String id;
  final String name;
  final String? description;
  final List<String> availableGridSizes;
  final String? previewImagePath;
  final Map<String, dynamic>? additionalData;

  const PuzzleMetadata({
    required this.id,
    required this.name,
    this.description,
    required this.availableGridSizes,
    this.previewImagePath,
    this.additionalData,
  });

  factory PuzzleMetadata.fromJson(Map<String, dynamic> json) {
    return PuzzleMetadata(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      availableGridSizes: List<String>.from(json['availableGridSizes']),
      previewImagePath: json['previewImagePath'],
      additionalData: json['additionalData'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'availableGridSizes': availableGridSizes,
      'previewImagePath': previewImagePath,
      'additionalData': additionalData,
    };
  }
}

/// Data for a single piece asset
class PieceAssetData {
  final String pieceId;
  final int row;
  final int col;
  final PieceBounds bounds;
  final String imagePath;
  final Map<String, dynamic>? metadata;

  const PieceAssetData({
    required this.pieceId,
    required this.row,
    required this.col,
    required this.bounds,
    required this.imagePath,
    this.metadata,
  });

  factory PieceAssetData.fromJson(Map<String, dynamic> json) {
    return PieceAssetData(
      pieceId: json['pieceId'],
      row: json['row'],
      col: json['col'],
      bounds: PieceBounds.fromJson(json['bounds']),
      imagePath: json['imagePath'],
      metadata: json['metadata'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pieceId': pieceId,
      'row': row,
      'col': col,
      'bounds': bounds.toJson(),
      'imagePath': imagePath,
      'metadata': metadata,
    };
  }
}
