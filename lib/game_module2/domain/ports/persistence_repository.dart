import '../entities/puzzle_workspace.dart';

/// Port interface for persisting and retrieving puzzle workspace state.
/// 
/// This interface defines how the domain layer interacts with storage,
/// hiding implementation details about databases, file systems, etc.
abstract class PersistenceRepository {
  /// Save the current workspace state
  Future<void> saveWorkspace(PuzzleWorkspace workspace);
  
  /// Load a previously saved workspace
  Future<PuzzleWorkspace?> loadWorkspace(String workspaceId);
  
  /// List all saved workspaces
  Future<List<WorkspaceSummary>> listSavedWorkspaces();
  
  /// Delete a saved workspace
  Future<bool> deleteWorkspace(String workspaceId);
  
  /// Check if a workspace exists
  Future<bool> workspaceExists(String workspaceId);
  
  /// Save workspace progress (lighter weight than full save)
  Future<void> saveProgress(String workspaceId, WorkspaceProgress progress);
  
  /// Load workspace progress
  Future<WorkspaceProgress?> loadProgress(String workspaceId);
  
  /// Clear all saved data
  Future<void> clearAll();
  
  /// Get storage statistics
  Future<StorageStats> getStorageStats();
}

/// Summary information about a saved workspace
class WorkspaceSummary {
  final String id;
  final String puzzleId;
  final String gridSize;
  final int piecesPlaced;
  final int totalPieces;
  final DateTime lastModified;
  final Duration playTime;
  final bool isCompleted;

  const WorkspaceSummary({
    required this.id,
    required this.puzzleId,
    required this.gridSize,
    required this.piecesPlaced,
    required this.totalPieces,
    required this.lastModified,
    required this.playTime,
    required this.isCompleted,
  });

  double get completionPercentage => (piecesPlaced / totalPieces) * 100;

  factory WorkspaceSummary.fromJson(Map<String, dynamic> json) {
    return WorkspaceSummary(
      id: json['id'],
      puzzleId: json['puzzleId'],
      gridSize: json['gridSize'],
      piecesPlaced: json['piecesPlaced'],
      totalPieces: json['totalPieces'],
      lastModified: DateTime.parse(json['lastModified']),
      playTime: Duration(seconds: json['playTimeSeconds']),
      isCompleted: json['isCompleted'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'puzzleId': puzzleId,
      'gridSize': gridSize,
      'piecesPlaced': piecesPlaced,
      'totalPieces': totalPieces,
      'lastModified': lastModified.toIso8601String(),
      'playTimeSeconds': playTime.inSeconds,
      'isCompleted': isCompleted,
    };
  }
}

/// Lightweight progress data for frequent saves
class WorkspaceProgress {
  final String workspaceId;
  final List<String> placedPieceIds;
  final Map<String, PiecePosition> piecePositions;
  final int moveCount;
  final int hintsUsed;
  final DateTime timestamp;

  const WorkspaceProgress({
    required this.workspaceId,
    required this.placedPieceIds,
    required this.piecePositions,
    required this.moveCount,
    required this.hintsUsed,
    required this.timestamp,
  });

  factory WorkspaceProgress.fromJson(Map<String, dynamic> json) {
    return WorkspaceProgress(
      workspaceId: json['workspaceId'],
      placedPieceIds: List<String>.from(json['placedPieceIds']),
      piecePositions: (json['piecePositions'] as Map<String, dynamic>)
          .map((key, value) => MapEntry(key, PiecePosition.fromJson(value))),
      moveCount: json['moveCount'],
      hintsUsed: json['hintsUsed'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'workspaceId': workspaceId,
      'placedPieceIds': placedPieceIds,
      'piecePositions': piecePositions
          .map((key, value) => MapEntry(key, value.toJson())),
      'moveCount': moveCount,
      'hintsUsed': hintsUsed,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

/// Position data for a piece
class PiecePosition {
  final double x;
  final double y;
  final bool isPlaced;

  const PiecePosition({
    required this.x,
    required this.y,
    required this.isPlaced,
  });

  factory PiecePosition.fromJson(Map<String, dynamic> json) {
    return PiecePosition(
      x: json['x'],
      y: json['y'],
      isPlaced: json['isPlaced'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'x': x,
      'y': y,
      'isPlaced': isPlaced,
    };
  }
}

/// Storage statistics
class StorageStats {
  final int savedWorkspaceCount;
  final int totalBytesUsed;
  final DateTime oldestWorkspace;
  final DateTime newestWorkspace;

  const StorageStats({
    required this.savedWorkspaceCount,
    required this.totalBytesUsed,
    required this.oldestWorkspace,
    required this.newestWorkspace,
  });

  String get formattedSize {
    if (totalBytesUsed < 1024) return '$totalBytesUsed B';
    if (totalBytesUsed < 1024 * 1024) {
      return '${(totalBytesUsed / 1024).toStringAsFixed(1)} KB';
    }
    return '${(totalBytesUsed / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
