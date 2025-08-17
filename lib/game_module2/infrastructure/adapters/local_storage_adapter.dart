import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/ports/persistence_repository.dart';
import '../../domain/entities/puzzle_workspace.dart';

/// Local storage implementation of the PersistenceRepository port.
/// 
/// This adapter uses SharedPreferences for simple key-value storage.
/// For production, consider using a more robust solution like SQLite.
class LocalStorageAdapter implements PersistenceRepository {
  static const String _workspacePrefix = 'puzzle_workspace_';
  static const String _summaryPrefix = 'puzzle_summary_';
  static const String _progressPrefix = 'puzzle_progress_';
  static const String _workspaceListKey = 'puzzle_workspace_list';
  
  late SharedPreferences _prefs;
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    _prefs = await SharedPreferences.getInstance();
    _isInitialized = true;
  }

  void _ensureInitialized() {
    if (!_isInitialized) {
      throw StateError('LocalStorageAdapter must be initialized before use');
    }
  }

  @override
  Future<void> saveWorkspace(PuzzleWorkspace workspace) async {
    _ensureInitialized();
    
    try {
      // Save the full workspace
      final json = workspace.toJson();
      final jsonString = jsonEncode(json);
      await _prefs.setString('$_workspacePrefix${workspace.id}', jsonString);
      
      // Save summary for quick listing
      final summary = WorkspaceSummary(
        id: workspace.id,
        puzzleId: workspace.puzzleId,
        gridSize: workspace.gridSize,
        piecesPlaced: workspace.placedCount,
        totalPieces: workspace.totalPieces,
        lastModified: DateTime.now(),
        playTime: workspace.sessionDuration,
        isCompleted: workspace.isCompleted,
      );
      
      await _saveSummary(summary);
      
      // Update workspace list
      await _addToWorkspaceList(workspace.id);
      
      print('LocalStorageAdapter: Saved workspace ${workspace.id}');
    } catch (e) {
      print('LocalStorageAdapter: Failed to save workspace: $e');
      throw Exception('Failed to save workspace: $e');
    }
  }

  @override
  Future<PuzzleWorkspace?> loadWorkspace(String workspaceId) async {
    _ensureInitialized();
    
    try {
      final jsonString = _prefs.getString('$_workspacePrefix$workspaceId');
      if (jsonString == null) return null;
      
      final json = jsonDecode(jsonString);
      return PuzzleWorkspace.fromJson(json);
    } catch (e) {
      print('LocalStorageAdapter: Failed to load workspace: $e');
      return null;
    }
  }

  @override
  Future<List<WorkspaceSummary>> listSavedWorkspaces() async {
    _ensureInitialized();
    
    try {
      final workspaceIds = _getWorkspaceList();
      final summaries = <WorkspaceSummary>[];
      
      for (final id in workspaceIds) {
        final summary = await _loadSummary(id);
        if (summary != null) {
          summaries.add(summary);
        }
      }
      
      // Sort by last modified date (newest first)
      summaries.sort((a, b) => b.lastModified.compareTo(a.lastModified));
      
      return summaries;
    } catch (e) {
      print('LocalStorageAdapter: Failed to list workspaces: $e');
      return [];
    }
  }

  @override
  Future<bool> deleteWorkspace(String workspaceId) async {
    _ensureInitialized();
    
    try {
      // Remove workspace data
      await _prefs.remove('$_workspacePrefix$workspaceId');
      
      // Remove summary
      await _prefs.remove('$_summaryPrefix$workspaceId');
      
      // Remove progress
      await _prefs.remove('$_progressPrefix$workspaceId');
      
      // Update workspace list
      await _removeFromWorkspaceList(workspaceId);
      
      print('LocalStorageAdapter: Deleted workspace $workspaceId');
      return true;
    } catch (e) {
      print('LocalStorageAdapter: Failed to delete workspace: $e');
      return false;
    }
  }

  @override
  Future<bool> workspaceExists(String workspaceId) async {
    _ensureInitialized();
    return _prefs.containsKey('$_workspacePrefix$workspaceId');
  }

  @override
  Future<void> saveProgress(String workspaceId, WorkspaceProgress progress) async {
    _ensureInitialized();
    
    try {
      final json = progress.toJson();
      final jsonString = jsonEncode(json);
      await _prefs.setString('$_progressPrefix$workspaceId', jsonString);
      
      // Update summary's last modified time
      final summary = await _loadSummary(workspaceId);
      if (summary != null) {
        final updatedSummary = WorkspaceSummary(
          id: summary.id,
          puzzleId: summary.puzzleId,
          gridSize: summary.gridSize,
          piecesPlaced: progress.placedPieceIds.length,
          totalPieces: summary.totalPieces,
          lastModified: DateTime.now(),
          playTime: summary.playTime,
          isCompleted: summary.isCompleted,
        );
        await _saveSummary(updatedSummary);
      }
    } catch (e) {
      print('LocalStorageAdapter: Failed to save progress: $e');
    }
  }

  @override
  Future<WorkspaceProgress?> loadProgress(String workspaceId) async {
    _ensureInitialized();
    
    try {
      final jsonString = _prefs.getString('$_progressPrefix$workspaceId');
      if (jsonString == null) return null;
      
      final json = jsonDecode(jsonString);
      return WorkspaceProgress.fromJson(json);
    } catch (e) {
      print('LocalStorageAdapter: Failed to load progress: $e');
      return null;
    }
  }

  @override
  Future<void> clearAll() async {
    _ensureInitialized();
    
    try {
      final workspaceIds = _getWorkspaceList();
      
      for (final id in workspaceIds) {
        await deleteWorkspace(id);
      }
      
      // Clear the workspace list
      await _prefs.remove(_workspaceListKey);
      
      print('LocalStorageAdapter: Cleared all saved data');
    } catch (e) {
      print('LocalStorageAdapter: Failed to clear all data: $e');
    }
  }

  @override
  Future<StorageStats> getStorageStats() async {
    _ensureInitialized();
    
    try {
      final workspaceIds = _getWorkspaceList();
      if (workspaceIds.isEmpty) {
        return StorageStats(
          savedWorkspaceCount: 0,
          totalBytesUsed: 0,
          oldestWorkspace: DateTime.now(),
          newestWorkspace: DateTime.now(),
        );
      }
      
      int totalBytes = 0;
      DateTime? oldest;
      DateTime? newest;
      
      for (final id in workspaceIds) {
        // Estimate size of stored data
        final workspaceData = _prefs.getString('$_workspacePrefix$id');
        if (workspaceData != null) {
          totalBytes += workspaceData.length * 2; // Approximate UTF-16 encoding
        }
        
        // Get timestamps from summaries
        final summary = await _loadSummary(id);
        if (summary != null) {
          if (oldest == null || summary.lastModified.isBefore(oldest)) {
            oldest = summary.lastModified;
          }
          if (newest == null || summary.lastModified.isAfter(newest)) {
            newest = summary.lastModified;
          }
        }
      }
      
      return StorageStats(
        savedWorkspaceCount: workspaceIds.length,
        totalBytesUsed: totalBytes,
        oldestWorkspace: oldest ?? DateTime.now(),
        newestWorkspace: newest ?? DateTime.now(),
      );
    } catch (e) {
      print('LocalStorageAdapter: Failed to get storage stats: $e');
      return StorageStats(
        savedWorkspaceCount: 0,
        totalBytesUsed: 0,
        oldestWorkspace: DateTime.now(),
        newestWorkspace: DateTime.now(),
      );
    }
  }

  // Private helper methods
  
  List<String> _getWorkspaceList() {
    final listJson = _prefs.getString(_workspaceListKey);
    if (listJson == null) return [];
    
    try {
      return List<String>.from(jsonDecode(listJson));
    } catch (e) {
      return [];
    }
  }
  
  Future<void> _addToWorkspaceList(String workspaceId) async {
    final list = _getWorkspaceList();
    if (!list.contains(workspaceId)) {
      list.add(workspaceId);
      await _prefs.setString(_workspaceListKey, jsonEncode(list));
    }
  }
  
  Future<void> _removeFromWorkspaceList(String workspaceId) async {
    final list = _getWorkspaceList();
    list.remove(workspaceId);
    await _prefs.setString(_workspaceListKey, jsonEncode(list));
  }
  
  Future<void> _saveSummary(WorkspaceSummary summary) async {
    final json = summary.toJson();
    final jsonString = jsonEncode(json);
    await _prefs.setString('$_summaryPrefix${summary.id}', jsonString);
  }
  
  Future<WorkspaceSummary?> _loadSummary(String workspaceId) async {
    try {
      final jsonString = _prefs.getString('$_summaryPrefix$workspaceId');
      if (jsonString == null) return null;
      
      final json = jsonDecode(jsonString);
      return WorkspaceSummary.fromJson(json);
    } catch (e) {
      return null;
    }
  }
}
