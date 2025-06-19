import 'dart:math';

import 'package:flutter/material.dart';
import 'package:puzzgame_flutter/core/domain/game_module_interface.dart';
import 'package:puzzgame_flutter/core/domain/services/settings_service.dart';
import 'package:puzzgame_flutter/core/domain/services/error_reporting_service.dart';
import 'package:puzzgame_flutter/core/infrastructure/service_locator.dart';
import 'package:puzzgame_flutter/game_module/services/memory_optimized_asset_manager.dart';
import 'package:uuid/uuid.dart';

/// Simplified implementation of the GameModule interface for jigsaw puzzle game
/// Uses memory optimization by default (60-80% memory reduction)
class PuzzleGameModule implements GameModule {
  static const String _version = '2.1.0';
  
  MemoryOptimizedAssetManager? _assetManager;
  bool _isInitialized = false;
  
  @override
  Future<bool> initialize() async {
    if (_isInitialized) {
      print('PuzzleGameModule: Already initialized');
      return true;
    }
    
    print('PuzzleGameModule: Initializing memory-optimized puzzle game...');
    
    // Initialize memory-optimized asset manager
    _assetManager = MemoryOptimizedAssetManager();
    await _assetManager!.initialize();
    
    // Register asset manager in service locator for easy access
    if (!serviceLocator.isRegistered<MemoryOptimizedAssetManager>()) {
      serviceLocator.registerSingleton<MemoryOptimizedAssetManager>(_assetManager!);
    }
    
    _isInitialized = true;
    final puzzleCount = (await _assetManager!.getAvailablePuzzles()).length;
    print('PuzzleGameModule: Memory-optimized asset manager initialized with $puzzleCount puzzles');
    return true;
  }
  
  @override
  Future<GameSession> startGame({required int difficulty}) async {
    final errorReporting = serviceLocator<ErrorReportingService>();
    
    try {
      if (!_isInitialized || _assetManager == null) {
        throw Exception('PuzzleGameModule must be initialized before starting a game');
      }
      
      print('PuzzleGameModule: Starting new memory-optimized puzzle game with difficulty $difficulty');
      
      // Add breadcrumb for game start
      await errorReporting.addBreadcrumb(
        'Starting memory-optimized puzzle game',
        category: 'game_lifecycle',
        data: {
          'difficulty': difficulty,
        },
      );
      
      // Get grid size from settings service
      final settingsService = serviceLocator<SettingsService>();
      final gridSize = settingsService.getGridSizeForDifficulty(difficulty);
      
      print('PuzzleGameModule: Using ${gridSize}x$gridSize grid for difficulty $difficulty');
      
      // Create game session with memory optimization
      final session = PuzzleGameSession(
        sessionId: const Uuid().v4(),
        difficulty: difficulty,
        gridSize: gridSize,
        assetManager: _assetManager!,
      );
      
      await session._initializePuzzle();
      
      // Report successful game start
      await errorReporting.addBreadcrumb(
        'Puzzle game started successfully',
        category: 'game_lifecycle',
        data: {
          'session_id': session.sessionId,
          'grid_size': gridSize,
          'total_pieces': session.totalPieces,
        },
      );
      
      return session;
    } catch (e, stackTrace) {
      // Report the error with detailed context
      await errorReporting.reportException(
        e,
        stackTrace: stackTrace,
        context: 'game_start_failure',
        extra: {
          'difficulty': difficulty,
          'is_initialized': _isInitialized,
          'asset_manager_available': _assetManager != null,
        },
        tags: {
          'feature': 'puzzle_game',
          'operation': 'start_game',
        },
      );
      
      print('PuzzleGameModule: Failed to start game: $e');
      rethrow;
    }
  }
  
  @override
  Future<GameSession?> resumeGame({required String sessionId}) async {
    print('PuzzleGameModule: Attempting to resume puzzle game with session ID: $sessionId');
    // TODO: Implement session resumption with proper asset loading
    return null;
  }
  
  @override
  String get version => _version;
  
  /// Get memory-optimized asset manager for external access
  MemoryOptimizedAssetManager? get assetManager => _assetManager;
}

/// Simplified PuzzleGameSession with memory optimization always enabled
class PuzzleGameSession implements GameSession {
  
  PuzzleGameSession({
    required String sessionId,
    required int difficulty,
    required int gridSize,
    required MemoryOptimizedAssetManager assetManager,
  }) : _sessionId = sessionId,
       _difficulty = difficulty,
       _gridSize = gridSize,
       _assetManager = assetManager;

  // Core session data
  final String _sessionId;
  final int _difficulty;
  final int _gridSize;
  final MemoryOptimizedAssetManager _assetManager;
  
  int _score = 0;
  final int _level = 1;
  bool _isActive = true;
  final DateTime _startTime = DateTime.now();
  
  // Puzzle-specific state
  late List<PuzzlePiece> _allPieces;
  late List<PuzzlePiece> _trayPieces;
  final List<PuzzlePiece> _placedPieces = []; // Canvas-placed pieces
  late String _currentPuzzleId;
  late PuzzleCanvasInfo _canvasInfo;
  int _piecesPlaced = 0;
  bool _assetsLoaded = false;
  
  // Getters
  @override
  String get sessionId => _sessionId;
  @override
  int get score => _score;
  @override
  int get level => _level;
  @override
  bool get isActive => _isActive;
  
  // Puzzle-specific getters
  int get gridSize => _gridSize;
  int get totalPieces => _gridSize * _gridSize;
  int get piecesPlaced => _piecesPlaced;
  int get piecesRemaining => totalPieces - _piecesPlaced;
  List<PuzzlePiece> get trayPieces => List.unmodifiable(_trayPieces);
  List<PuzzlePiece> get placedPieces => List.unmodifiable(_placedPieces);
  String get currentPuzzleId => _currentPuzzleId;
  PuzzleCanvasInfo get canvasInfo => _canvasInfo;
  bool get isCompleted => _piecesPlaced == totalPieces;
  bool get assetsLoaded => _assetsLoaded;
  DateTime get startTime => _startTime;
  MemoryOptimizedAssetManager get memoryOptimizedAssetManager => _assetManager;
  
  // Legacy compatibility getters (always return memory-optimized values)
  bool get useMemoryOptimization => true;
  bool get useEnhancedRendering => false; // Not needed anymore
  
  /// Initialize the puzzle with memory-optimized asset loading
  Future<void> _initializePuzzle() async {
    print('PuzzleGameSession: Initializing ${_gridSize}x$_gridSize puzzle');
    
    // Select a puzzle (for now, use the first available)
    final availablePuzzles = await _assetManager.getAvailablePuzzles();
    if (availablePuzzles.isEmpty) {
      throw Exception('No puzzles available');
    }
    
    _currentPuzzleId = availablePuzzles.first.id;
    final gridSizeStr = '${_gridSize}x$_gridSize';
    
    // Check if the selected grid size is available
    final puzzleMetadata = _assetManager.getPuzzleMetadata(_currentPuzzleId);
    if (puzzleMetadata == null || !puzzleMetadata.availableGridSizes.contains(gridSizeStr)) {
      throw Exception('Grid size $gridSizeStr not available for puzzle $_currentPuzzleId');
    }
    
    print('PuzzleGameSession: Loading assets for puzzle $_currentPuzzleId, grid size $gridSizeStr');
    
    // Load memory-optimized assets (auto-detects optimized assets)
    await _assetManager.loadPuzzleGridSize(_currentPuzzleId, gridSizeStr);
    print('PuzzleGameSession: Memory-optimized assets loaded');
    
    // Load canvas info
    _canvasInfo = await _assetManager.getCanvasInfo(_currentPuzzleId, gridSizeStr);
    
    // Create puzzle pieces with memory-optimized asset manager
    _allPieces = [];
    for (int row = 0; row < _gridSize; row++) {
      for (int col = 0; col < _gridSize; col++) {
        final piece = PuzzlePiece(
          id: '${row}_$col',
          correctRow: row,
          correctCol: col,
          assetManager: _assetManager,
        );
        _allPieces.add(piece);
      }
    }
    
    // Shuffle pieces for the tray
    _trayPieces = List.from(_allPieces);
    _trayPieces.shuffle(Random());
    
    // Clear placed pieces
    _placedPieces.clear();
    
    _piecesPlaced = 0;
    _assetsLoaded = true;
    
    print('PuzzleGameSession: Puzzle initialized with ${_allPieces.length} pieces');
  }
  
  /// Switch to a different puzzle
  Future<void> switchPuzzle(String newPuzzleId) async {
    if (newPuzzleId == _currentPuzzleId) return;
    
    print('PuzzleGameSession: Switching to puzzle $newPuzzleId');
    
    // Verify puzzle exists
    final puzzleMetadata = _assetManager.getPuzzleMetadata(newPuzzleId);
    if (puzzleMetadata == null) {
      throw Exception('Puzzle $newPuzzleId not found');
    }
    
    // Check if current grid size is available for new puzzle
    final gridSizeStr = '${_gridSize}x$_gridSize';
    if (!puzzleMetadata.availableGridSizes.contains(gridSizeStr)) {
      throw Exception('Grid size $gridSizeStr not available for puzzle $newPuzzleId');
    }
    
    // Reset game state
    _allPieces.clear();
    _trayPieces.clear();
    _piecesPlaced = 0;
    _assetsLoaded = false;
    
    // Update puzzle ID and reload assets
    _currentPuzzleId = newPuzzleId;
    await _assetManager.loadPuzzleGridSize(_currentPuzzleId, gridSizeStr);
    
    // Recreate pieces for new puzzle
    _allPieces = [];
    for (int row = 0; row < _gridSize; row++) {
      for (int col = 0; col < _gridSize; col++) {
        final piece = PuzzlePiece(
          id: '${row}_$col',
          correctRow: row,
          correctCol: col,
          assetManager: _assetManager,
        );
        _allPieces.add(piece);
      }
    }
    
    // Reinitialize tray
    _trayPieces = List.from(_allPieces);
    _trayPieces.shuffle(Random());
    
    _assetsLoaded = true;
    print('PuzzleGameSession: Successfully switched to puzzle $newPuzzleId');
  }

  /// Place piece on canvas (memory-optimized positioning)
  bool placePiece(PuzzlePiece piece) {
    if (!_isActive || !_assetsLoaded) return false;
    
    // Check if piece is already placed
    if (_placedPieces.contains(piece)) {
      print('PuzzleGameSession: Piece ${piece.id} already placed');
      return false;
    }
    
    // Always succeeds - memory optimization handles positioning
    _placedPieces.add(piece);
    _trayPieces.remove(piece);
    _piecesPlaced++;
    
    // Calculate score based on difficulty and time
    final timeBonusMultiplier = _calculateTimeBonusMultiplier();
    final basePoints = 10 * _difficulty;
    final points = (basePoints * timeBonusMultiplier).round();
    _score += points;
    
    print('PuzzleGameSession: Placed piece ${piece.id} on canvas. Score: +$points');
    
    // Check if puzzle is completed
    if (isCompleted) {
      _onPuzzleCompleted();
    }
    
    return true;
  }
  
  /// Legacy method for backward compatibility with grid-based placement
  bool tryPlacePiece(PuzzlePiece piece, int targetRow, int targetCol) {
    return placePiece(piece);
  }
  
  /// Remove piece from canvas back to tray
  void removePiece(PuzzlePiece piece) {
    if (!_isActive || !_assetsLoaded) return;
    
    if (_placedPieces.remove(piece)) {
      _trayPieces.add(piece);
      _piecesPlaced--;
      _trayPieces.shuffle(Random());
      
      print('PuzzleGameSession: Removed piece ${piece.id} from canvas');
    }
  }
  
  /// Legacy method for backward compatibility with grid-based removal
  void removePieceFromGrid(int row, int col) {
    if (!_isActive || !_assetsLoaded) return;
    
    // Find piece at this grid position and remove it
    final pieceId = '${row}_$col';
    final piece = _placedPieces.firstWhere(
      (p) => p.id == pieceId,
      orElse: () => _allPieces.firstWhere((p) => p.id == pieceId),
    );
    
    removePiece(piece);
  }
  
  /// Calculate time bonus multiplier (faster completion = higher bonus)
  double _calculateTimeBonusMultiplier() {
    final elapsedMinutes = DateTime.now().difference(_startTime).inMinutes;
    // Scale expected time based on puzzle complexity
    final expectedMinutes = (_gridSize * _gridSize / 10).round(); // Roughly 10 pieces per minute
    
    if (elapsedMinutes <= expectedMinutes) {
      return 2; // Double points for fast completion
    } else if (elapsedMinutes <= expectedMinutes * 2) {
      return 1.5; // 50% bonus for reasonable time
    } else {
      return 1; // Base points for slow completion
    }
  }
  
  /// Handle puzzle completion
  void _onPuzzleCompleted() {
    print('PuzzleGameSession: Puzzle completed!');
    
    // Completion bonus
    final completionBonus = 100 * _difficulty;
    _score += completionBonus;
    
    // TODO: Trigger completion effects, save high score, etc.
    print('PuzzleGameSession: Completion bonus: +$completionBonus. Final score: $_score');
  }
  
  /// Get hint for next best piece to place
  PuzzlePiece? getHint() {
    if (_trayPieces.isEmpty || !_assetsLoaded) return null;
    
    // Return a random piece as hint (simplified logic)
    return _trayPieces.first;
  }
  
  // GameSession interface implementation
  @override
  Future<void> pauseGame() async {
    if (_isActive) {
      _isActive = false;
      print('PuzzleGameSession: Game paused');
    }
  }
  
  @override
  Future<void> resumeSession() async {
    if (!_isActive) {
      _isActive = true;
      print('PuzzleGameSession: Game resumed');
    }
  }
  
  @override
  Future<GameResult> endGame() async {
    _isActive = false;
    final playTime = DateTime.now().difference(_startTime);
    
    final result = GameResult(
      sessionId: _sessionId,
      finalScore: _score,
      maxLevel: _level,
      playTime: playTime,
      completed: isCompleted,
    );
    
    print('PuzzleGameSession: Game ended. Completed: ${result.completed}, Score: ${result.finalScore}');
    return result;
  }
  
  @override
  Future<bool> saveGame() async {
    // TODO: Implement game state persistence
    print('PuzzleGameSession: Saving game state...');
    return true;
  }
}

/// Simplified puzzle piece with only memory-optimized asset manager
class PuzzlePiece {
  const PuzzlePiece({
    required this.id,
    required this.correctRow,
    required this.correctCol,
    required this.assetManager,
  });
  
  final String id;
  final int correctRow;
  final int correctCol;
  final MemoryOptimizedAssetManager assetManager;
  
  // Legacy compatibility getters
  MemoryOptimizedAssetManager get memoryOptimizedAssetManager => assetManager;
  
  @override
  String toString() => 'PuzzlePiece(id: $id, correctPos: ($correctRow, $correctCol))';
}
