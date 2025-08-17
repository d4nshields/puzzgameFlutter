import 'dart:async';
import 'package:flutter/foundation.dart';
import '../domain/entities/puzzle_workspace.dart';
import '../domain/entities/puzzle_piece.dart';
import '../domain/value_objects/puzzle_coordinate.dart';
import '../domain/ports/asset_repository.dart';
import '../domain/ports/feedback_service.dart';
import '../domain/ports/persistence_repository.dart';
import 'use_cases/move_piece_use_case.dart';

/// Controller that manages the puzzle workspace and coordinates use cases.
/// 
/// This is the main entry point for the presentation layer to interact
/// with the domain logic.
class WorkspaceController extends ChangeNotifier {
  // Dependencies
  final AssetRepository assetRepository;
  final FeedbackService feedbackService;
  final PersistenceRepository? persistenceRepository;
  
  // State
  PuzzleWorkspace? _workspace;
  MovePieceUseCase? _movePieceUseCase;
  bool _isLoading = false;
  String? _error;
  
  // Auto-save timer
  Timer? _autoSaveTimer;
  
  // Drag state
  String? _draggingPieceId;

  WorkspaceController({
    required this.assetRepository,
    required this.feedbackService,
    this.persistenceRepository,
  });

  // Getters
  PuzzleWorkspace? get workspace => _workspace;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasWorkspace => _workspace != null;
  bool get isCompleted => _workspace?.isCompleted ?? false;
  String? get draggingPieceId => _draggingPieceId;
  
  // Computed properties
  int get placedCount => _workspace?.placedCount ?? 0;
  int get totalPieces => _workspace?.totalPieces ?? 0;
  double get completionPercentage => _workspace?.completionPercentage ?? 0.0;
  Duration get sessionDuration => _workspace?.sessionDuration ?? Duration.zero;
  int get score => _workspace?.calculateScore() ?? 0;

  /// Initialize a new puzzle workspace
  Future<void> initializeWorkspace({
    required String puzzleId,
    required String gridSize,
    String? workspaceId,
  }) async {
    _setLoading(true);
    _clearError();
    
    try {
      // Check if we should restore a saved workspace
      if (workspaceId != null && persistenceRepository != null) {
        final saved = await persistenceRepository!.loadWorkspace(workspaceId);
        if (saved != null) {
          _workspace = saved;
          _initializeUseCase();
          _startAutoSaveTimer();
          notifyListeners();
          return;
        }
      }
      
      // Load puzzle assets
      final metadata = await assetRepository.loadPuzzleMetadata(puzzleId);
      if (!metadata.availableGridSizes.contains(gridSize)) {
        throw Exception('Grid size $gridSize not available for puzzle $puzzleId');
      }
      
      final assets = await assetRepository.loadPuzzleAssets(puzzleId, gridSize);
      
      // Parse grid dimensions
      final dims = gridSize.split('x');
      final rows = int.parse(dims[0]);
      final cols = int.parse(dims[1]);
      
      // Determine canvas size from first asset
      final canvasSize = assets.first.bounds.paddedSize;
      
      // Create puzzle pieces from assets
      final pieces = assets.map((asset) {
        // Calculate correct position based on grid
        final pieceWidth = canvasSize.width / cols;
        final pieceHeight = canvasSize.height / rows;
        
        final correctPosition = PuzzleCoordinate(
          x: asset.col * pieceWidth,
          y: asset.row * pieceHeight,
        );
        
        return PuzzlePiece(
          id: asset.pieceId,
          correctRow: asset.row,
          correctCol: asset.col,
          correctPosition: correctPosition,
          bounds: asset.bounds,
        );
      }).toList();
      
      // Create workspace
      _workspace = PuzzleWorkspace(
        id: workspaceId ?? DateTime.now().millisecondsSinceEpoch.toString(),
        puzzleId: puzzleId,
        gridSize: gridSize,
        canvasSize: canvasSize,
        pieces: pieces,
      );
      
      _initializeUseCase();
      _startAutoSaveTimer();
      
    } catch (e) {
      _setError('Failed to initialize workspace: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Resume a saved workspace
  Future<void> resumeWorkspace(String workspaceId) async {
    if (persistenceRepository == null) {
      _setError('Persistence not available');
      return;
    }
    
    _setLoading(true);
    _clearError();
    
    try {
      final saved = await persistenceRepository!.loadWorkspace(workspaceId);
      if (saved == null) {
        throw Exception('Workspace not found');
      }
      
      _workspace = saved;
      _initializeUseCase();
      _startAutoSaveTimer();
      
    } catch (e) {
      _setError('Failed to resume workspace: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Start dragging a piece
  void startDragging(String pieceId, PuzzleCoordinate startPosition) {
    if (_workspace == null || _movePieceUseCase == null) return;
    
    _draggingPieceId = pieceId;
    
    // If piece is in tray, pick it up first
    final piece = _workspace!.pieces.firstWhere((p) => p.id == pieceId);
    if (piece.isInTray) {
      _workspace!.pickUpPiece(pieceId);
    }
    
    _movePieceUseCase!.startDragging(pieceId);
    notifyListeners();
  }

  /// Update piece position during drag
  Future<void> dragPiece(String pieceId, PuzzleCoordinate position) async {
    if (_workspace == null || _movePieceUseCase == null) return;
    if (_draggingPieceId != pieceId) return;
    
    await _movePieceUseCase!.execute(
      pieceId: pieceId,
      newPosition: position,
    );
    
    notifyListeners();
  }

  /// Stop dragging a piece
  void stopDragging(String pieceId) {
    if (_workspace == null || _movePieceUseCase == null) return;
    if (_draggingPieceId != pieceId) return;
    
    _movePieceUseCase!.stopDragging();
    _draggingPieceId = null;
    
    // Check if piece should return to tray (if not placed and far from any position)
    final piece = _workspace!.pieces.firstWhere((p) => p.id == pieceId);
    if (!piece.isPlaced && piece.currentPosition != null) {
      // Optional: Return to tray if dropped in invalid location
      // This is a UX decision - you might want to leave pieces on workspace
    }
    
    notifyListeners();
  }

  /// Return a piece to the tray
  void returnToTray(String pieceId) {
    if (_workspace == null) return;
    
    _workspace!.returnPieceToTray(pieceId);
    feedbackService.playSound(SoundType.uiTap);
    notifyListeners();
  }

  /// Remove a placed piece
  void removePlacedPiece(String pieceId) {
    if (_workspace == null) return;
    
    _workspace!.removePlacedPiece(pieceId);
    feedbackService.playSound(SoundType.pickup);
    notifyListeners();
  }

  /// Get a hint
  void requestHint() {
    if (_workspace == null) return;
    
    final hintPiece = _workspace!.getHint();
    if (hintPiece != null) {
      feedbackService.playSound(SoundType.hint);
      feedbackService.showVisualHint(
        VisualHint(
          type: HintType.highlightPiece,
          pieceId: hintPiece.id,
          duration: const Duration(seconds: 3),
        ),
      );
      
      // Also show target position
      feedbackService.showVisualHint(
        VisualHint(
          type: HintType.showTarget,
          pieceId: hintPiece.id,
          duration: const Duration(seconds: 3),
        ),
      );
    }
    
    notifyListeners();
  }

  /// Auto-solve edge pieces (accessibility feature)
  void autoSolveEdges() {
    if (_workspace == null) return;
    
    final count = _workspace!.autoSolveEdges();
    if (count > 0) {
      feedbackService.playSound(SoundType.snap);
      notifyListeners();
    }
  }

  /// Reset the puzzle
  void reset() {
    if (_workspace == null) return;
    
    _workspace!.reset();
    feedbackService.playSound(SoundType.uiTap);
    notifyListeners();
  }

  /// Save the current workspace
  Future<void> saveWorkspace() async {
    if (_workspace == null || persistenceRepository == null) return;
    
    try {
      await persistenceRepository!.saveWorkspace(_workspace!);
    } catch (e) {
      _setError('Failed to save workspace: $e');
    }
  }

  /// Delete a saved workspace
  Future<void> deleteWorkspace(String workspaceId) async {
    if (persistenceRepository == null) return;
    
    try {
      await persistenceRepository!.deleteWorkspace(workspaceId);
      
      // If deleting current workspace, clear it
      if (_workspace?.id == workspaceId) {
        _workspace = null;
        _movePieceUseCase = null;
        _stopAutoSaveTimer();
        notifyListeners();
      }
    } catch (e) {
      _setError('Failed to delete workspace: $e');
    }
  }

  /// Get list of saved workspaces
  Future<List<WorkspaceSummary>> getSavedWorkspaces() async {
    if (persistenceRepository == null) return [];
    
    try {
      return await persistenceRepository!.listSavedWorkspaces();
    } catch (e) {
      _setError('Failed to load saved workspaces: $e');
      return [];
    }
  }

  @override
  void dispose() {
    _stopAutoSaveTimer();
    super.dispose();
  }

  // Private helper methods
  
  void _initializeUseCase() {
    if (_workspace == null) return;
    
    _movePieceUseCase = MovePieceUseCase(
      workspace: _workspace!,
      feedbackService: feedbackService,
      persistenceRepository: persistenceRepository,
    );
  }

  void _startAutoSaveTimer() {
    if (_workspace == null || !_workspace!.config.autoSave) return;
    
    _stopAutoSaveTimer();
    
    _autoSaveTimer = Timer.periodic(
      Duration(seconds: _workspace!.config.autoSaveIntervalSeconds),
      (_) => saveWorkspace(),
    );
  }

  void _stopAutoSaveTimer() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = null;
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
  }
}
