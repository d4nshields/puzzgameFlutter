import 'dart:math';

import 'package:flutter/material.dart';
import 'package:puzzgame_flutter/core/domain/game_module_interface.dart';
import 'package:puzzgame_flutter/core/domain/services/settings_service.dart';
import 'package:puzzgame_flutter/core/domain/services/error_reporting_service.dart';
import 'package:puzzgame_flutter/core/infrastructure/service_locator.dart';
import 'package:puzzgame_flutter/core/domain/services/game_session_tracking_service.dart';
import 'package:puzzgame_flutter/core/domain/services/auth_service.dart';
import 'package:puzzgame_flutter/game_module/services/puzzle_asset_manager.dart';
import 'package:puzzgame_flutter/game_module/services/enhanced_puzzle_asset_manager.dart';
import 'package:puzzgame_flutter/game_module/services/memory_optimized_asset_manager.dart';
import 'package:uuid/uuid.dart';

/// Implementation of the GameModule interface for jigsaw puzzle game
/// Now with integrated memory optimization for large grids
class PuzzleGameModule implements GameModule {
  static const String _version = '2.0.0';
  
  PuzzleAssetManager? _assetManager;
  EnhancedPuzzleAssetManager? _enhancedAssetManager;
  MemoryOptimizedAssetManager? _memoryOptimizedAssetManager;
  bool _isInitialized = false;
  bool _useEnhancedRendering = true; // Flag to enable enhanced rendering
  bool _useMemoryOptimization = true; // Flag to enable memory optimization
  
  @override
  Future<bool> initialize() async {
    if (_isInitialized) {
      print('PuzzleGameModule: Already initialized');
      return true;
    }
    
    print('PuzzleGameModule: Initializing puzzle game with memory optimization...');
    
    // Initialize asset managers
    _assetManager = PuzzleAssetManager();
    await _assetManager!.initialize();
    
    _enhancedAssetManager = EnhancedPuzzleAssetManager();
    await _enhancedAssetManager!.initialize();
    
    _memoryOptimizedAssetManager = MemoryOptimizedAssetManager();
    await _memoryOptimizedAssetManager!.initialize();
    
    // Register asset managers in service locator for easy access
    if (!serviceLocator.isRegistered<PuzzleAssetManager>()) {
      serviceLocator.registerSingleton<PuzzleAssetManager>(_assetManager!);
    }
    if (!serviceLocator.isRegistered<EnhancedPuzzleAssetManager>()) {
      serviceLocator.registerSingleton<EnhancedPuzzleAssetManager>(_enhancedAssetManager!);
    }
    if (!serviceLocator.isRegistered<MemoryOptimizedAssetManager>()) {
      serviceLocator.registerSingleton<MemoryOptimizedAssetManager>(_memoryOptimizedAssetManager!);
    }
    
    _isInitialized = true;
    final puzzleCount = (await _memoryOptimizedAssetManager!.getAvailablePuzzles()).length;
    print('PuzzleGameModule: Memory-optimized asset manager initialized with $puzzleCount puzzles');
    print('PuzzleGameModule: Enhanced rendering enabled: $_useEnhancedRendering');
    print('PuzzleGameModule: Memory optimization enabled: $_useMemoryOptimization');
    return true;
  }
  
  @override
  Future<GameSession> startGame({required int difficulty}) async {
    final errorReporting = serviceLocator<ErrorReportingService>();
    
    try {
      if (!_isInitialized || _memoryOptimizedAssetManager == null) {
        throw Exception('PuzzleGameModule must be initialized before starting a game');
      }
      
      print('PuzzleGameModule: Starting new memory-optimized puzzle game with difficulty $difficulty');
      
      // Add breadcrumb for game start
      await errorReporting.addBreadcrumb(
        'Starting new memory-optimized puzzle game',
        category: 'game_lifecycle',
        data: {
          'difficulty': difficulty,
          'enhanced_rendering': _useEnhancedRendering,
          'memory_optimization': _useMemoryOptimization,
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
        enhancedAssetManager: _enhancedAssetManager!,
        memoryOptimizedAssetManager: _memoryOptimizedAssetManager!, // Add memory-optimized manager
        useEnhancedRendering: _useEnhancedRendering,
        useMemoryOptimization: _useMemoryOptimization, // Add flag
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
          'enhanced_rendering': _useEnhancedRendering,
          'is_initialized': _isInitialized,
          'asset_manager_available': _assetManager != null,
          'enhanced_asset_manager_available': _enhancedAssetManager != null,
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
  
  /// Get asset manager for external access
  PuzzleAssetManager? get assetManager => _assetManager;
  
  /// Get enhanced asset manager for external access
  EnhancedPuzzleAssetManager? get enhancedAssetManager => _enhancedAssetManager;
  
  /// Get memory-optimized asset manager for external access
  MemoryOptimizedAssetManager? get memoryOptimizedAssetManager => _memoryOptimizedAssetManager;
  
  /// Check if enhanced rendering is enabled
  bool get useEnhancedRendering => _useEnhancedRendering;
  
  /// Check if memory optimization is enabled
  bool get useMemoryOptimization => _useMemoryOptimization;
  
  /// Toggle enhanced rendering mode
  void setEnhancedRendering(bool enabled) {
    _useEnhancedRendering = enabled;
    print('PuzzleGameModule: Enhanced rendering ${enabled ? 'enabled' : 'disabled'}');
  }
  
  /// Toggle memory optimization mode
  void setMemoryOptimization(bool enabled) {
    _useMemoryOptimization = enabled;
    print('PuzzleGameModule: Memory optimization ${enabled ? 'enabled' : 'disabled'}');
  }
}

/// Enhanced PuzzleGameSession with asset manager integration
class PuzzleGameSession implements GameSession {
  
  PuzzleGameSession({
    required String sessionId,
    required int difficulty,
    required int gridSize,
    required PuzzleAssetManager assetManager,
    required EnhancedPuzzleAssetManager enhancedAssetManager,
    required MemoryOptimizedAssetManager memoryOptimizedAssetManager,
    required bool useEnhancedRendering,
    required bool useMemoryOptimization,
  }) : _sessionId = sessionId,
       _difficulty = difficulty,
       _gridSize = gridSize,
       _assetManager = assetManager,
       _enhancedAssetManager = enhancedAssetManager,
       _memoryOptimizedAssetManager = memoryOptimizedAssetManager,
       _useEnhancedRendering = useEnhancedRendering,
       _useMemoryOptimization = useMemoryOptimization;

  // Core session data
  final String _sessionId;
  final int _difficulty;
  final int _gridSize;
  final PuzzleAssetManager _assetManager;
  final EnhancedPuzzleAssetManager _enhancedAssetManager;
  final MemoryOptimizedAssetManager _memoryOptimizedAssetManager;
  final bool _useEnhancedRendering;
  final bool _useMemoryOptimization;
  
  int _score = 0;
  final int _level = 1;
  bool _isActive = true;
  final DateTime _startTime = DateTime.now();
  
  // Puzzle-specific state
  late List<PuzzlePiece> _allPieces;
  late List<PuzzlePiece> _trayPieces;
  late List<List<PuzzlePiece?>> _puzzleGrid;
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
  List<List<PuzzlePiece?>> get puzzleGrid => _puzzleGrid.map(List<PuzzlePiece?>.from).toList();
  List<PuzzlePiece> get placedPieces => List.unmodifiable(_placedPieces); // Canvas-placed pieces
  String get currentPuzzleId => _currentPuzzleId;
  PuzzleCanvasInfo get canvasInfo => _canvasInfo;
  bool get isCompleted => _piecesPlaced == totalPieces;
  bool get assetsLoaded => _assetsLoaded;
  DateTime get startTime => _startTime;
  PuzzleAssetManager get assetManager => _assetManager;
  EnhancedPuzzleAssetManager get enhancedAssetManager => _enhancedAssetManager;
  MemoryOptimizedAssetManager get memoryOptimizedAssetManager => _memoryOptimizedAssetManager;
  bool get useEnhancedRendering => _useEnhancedRendering;
  bool get useMemoryOptimization => _useMemoryOptimization;
  
  /// Initialize the puzzle with high-performance asset loading
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
    
    // Load assets using the appropriate manager based on settings
    if (_useMemoryOptimization) {
      // Use memory-optimized asset manager (auto-detects optimized assets)
      await _memoryOptimizedAssetManager.loadPuzzleGridSize(_currentPuzzleId, gridSizeStr);
      print('PuzzleGameSession: Memory-optimized assets loaded');
    } else if (_useEnhancedRendering) {
      // Use enhanced asset manager (runtime optimization)
      await _enhancedAssetManager.loadPuzzleGridSize(_currentPuzzleId, gridSizeStr);
      print('PuzzleGameSession: Enhanced assets loaded');
    } else {
      // Use basic asset manager
      await _assetManager.loadPuzzleGridSize(_currentPuzzleId, gridSizeStr);
      print('PuzzleGameSession: Basic assets loaded');
    }
    
    // Load canvas info
    _canvasInfo = await _enhancedAssetManager.getCanvasInfo(_currentPuzzleId, gridSizeStr);
    
    // Create puzzle pieces with asset manager references
    _allPieces = [];
    for (int row = 0; row < _gridSize; row++) {
      for (int col = 0; col < _gridSize; col++) {
        final piece = PuzzlePiece(
          id: '${row}_$col',
          correctRow: row,
          correctCol: col,
          assetManager: _assetManager,
          enhancedAssetManager: _enhancedAssetManager,
          memoryOptimizedAssetManager: _memoryOptimizedAssetManager,
        );
        _allPieces.add(piece);
      }
    }
    
    // Initialize empty puzzle grid
    _puzzleGrid = List.generate(
      _gridSize,
      (row) => List.generate(_gridSize, (col) => null),
    );
    
    // Shuffle pieces for the tray
    _trayPieces = List.from(_allPieces);
    _trayPieces.shuffle(Random());
    
    // Clear placed pieces
    _placedPieces.clear();
    
    _piecesPlaced = 0;
    _assetsLoaded = true;
    
    print('PuzzleGameSession: Puzzle initialized with ${_allPieces.length} pieces');
  }
  
  /// Switch to a different grid size for the same puzzle
  Future<void> switchGridSize(int newGridSize) async {
    if (newGridSize == _gridSize) return;
    
    print('PuzzleGameSession: Switching to grid size ${newGridSize}x$newGridSize');
    
    // Reset game state
    _allPieces.clear();
    _trayPieces.clear();
    _puzzleGrid.clear();
    _piecesPlaced = 0;
    _assetsLoaded = false;
    
    // Update grid size and reload assets
    // Note: This would require updating _gridSize if it wasn't final
    // For now, this demonstrates the concept
    final gridSizeStr = '${newGridSize}x$newGridSize';
    
    // Verify grid size is available
    final puzzleMetadata = _assetManager.getPuzzleMetadata(_currentPuzzleId);
    if (puzzleMetadata == null || !puzzleMetadata.availableGridSizes.contains(gridSizeStr)) {
      throw Exception('Grid size $gridSizeStr not available for puzzle $_currentPuzzleId');
    }
    
    // Load new assets
    await _assetManager.loadPuzzleGridSize(_currentPuzzleId, gridSizeStr);
    
    // Also load enhanced assets if enhanced rendering is enabled
    if (_useEnhancedRendering) {
      await _enhancedAssetManager.loadPuzzleGridSize(_currentPuzzleId, gridSizeStr);
    }
    
    // Recreate pieces for new grid size
    _allPieces = [];
    for (int row = 0; row < newGridSize; row++) {
      for (int col = 0; col < newGridSize; col++) {
        final piece = PuzzlePiece(
          id: '${row}_$col',
          correctRow: row,
          correctCol: col,
          assetManager: _assetManager,
          enhancedAssetManager: _enhancedAssetManager,
          memoryOptimizedAssetManager: _memoryOptimizedAssetManager,
        );
        _allPieces.add(piece);
      }
    }
    
    // Reinitialize grid and tray
    _puzzleGrid = List.generate(
      newGridSize,
      (row) => List.generate(newGridSize, (col) => null),
    );
    
    _trayPieces = List.from(_allPieces);
    _trayPieces.shuffle(Random());
    
    _assetsLoaded = true;
    print('PuzzleGameSession: Successfully switched to ${newGridSize}x$newGridSize grid');
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
    _puzzleGrid.clear();
    _piecesPlaced = 0;
    _assetsLoaded = false;
    
    // Update puzzle ID and reload assets
    _currentPuzzleId = newPuzzleId;
    await _assetManager.loadPuzzleGridSize(_currentPuzzleId, gridSizeStr);
    
    // Also load enhanced assets if enhanced rendering is enabled
    if (_useEnhancedRendering) {
      await _enhancedAssetManager.loadPuzzleGridSize(_currentPuzzleId, gridSizeStr);
    }
    
    // Recreate pieces for new puzzle
    _allPieces = [];
    for (int row = 0; row < _gridSize; row++) {
      for (int col = 0; col < _gridSize; col++) {
        final piece = PuzzlePiece(
          id: '${row}_$col',
          correctRow: row,
          correctCol: col,
          assetManager: _assetManager,
          enhancedAssetManager: _enhancedAssetManager,
          memoryOptimizedAssetManager: _memoryOptimizedAssetManager,
        );
        _allPieces.add(piece);
      }
    }
    
    // Reinitialize grid and tray
    _puzzleGrid = List.generate(
      _gridSize,
      (row) => List.generate(_gridSize, (col) => null),
    );
    
    _trayPieces = List.from(_allPieces);
    _trayPieces.shuffle(Random());
    
    _assetsLoaded = true;
    print('PuzzleGameSession: Successfully switched to puzzle $newPuzzleId');
  }

  /// Place piece on canvas (PNG padding handles positioning)
  bool placePiece(PuzzlePiece piece) {
    if (!_isActive || !_assetsLoaded) return false;
    
    // Check if piece is already placed
    if (_placedPieces.contains(piece)) {
      print('PuzzleGameSession: Piece ${piece.id} already placed');
      return false;
    }
    
    // Always succeeds - PNG padding ensures correct placement
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
    // For now, just call the new placePiece method
    // This maintains compatibility with existing drag/drop code
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
    
    // Track puzzle completion
    final completionTime = DateTime.now().difference(_startTime);
    _trackGameEvent('puzzle_completed', {
      'completion_time_minutes': completionTime.inMinutes,
      'completion_time_seconds': completionTime.inSeconds,
      'final_score': _score,
      'completion_bonus': completionBonus,
      'puzzle_id': _currentPuzzleId,
      'grid_size': _gridSize,
      'total_pieces': totalPieces,
    });
    
    print('PuzzleGameSession: Completion bonus: +$completionBonus. Final score: $_score');
  }
  
  /// Get hint for next best piece to place
  PuzzlePiece? getHint() {
    if (_trayPieces.isEmpty || !_assetsLoaded) return null;
    
    // Find a piece that would fit in an empty spot
    for (int row = 0; row < _gridSize; row++) {
      for (int col = 0; col < _gridSize; col++) {
        if (_puzzleGrid[row][col] == null) {
          // Look for the piece that belongs here
          final targetPiece = _trayPieces.firstWhere(
            (piece) => piece.correctRow == row && piece.correctCol == col,
            orElse: () => _trayPieces.first,
          );
          return targetPiece;
        }
      }
    }
    
    return null;
  }
  
  // GameSession interface implementation
  @override
  Future<void> pauseGame() async {
    if (_isActive) {
      _isActive = false;
      print('PuzzleGameSession: Game paused');
      
      // Track pause event
      _trackGameEvent('pause', {
        'pieces_placed': _piecesPlaced,
        'current_score': _score,
        'play_time_minutes': DateTime.now().difference(_startTime).inMinutes,
      });
    }
  }
  
  @override
  Future<void> resumeSession() async {
    if (!_isActive) {
      _isActive = true;
      print('PuzzleGameSession: Game resumed');
      
      // Track resume event
      _trackGameEvent('resume', {
        'pieces_placed': _piecesPlaced,
        'current_score': _score,
        'play_time_minutes': DateTime.now().difference(_startTime).inMinutes,
      });
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
    
    // Save state would include:
    // - Current puzzle ID
    // - Grid state (which pieces are placed where)
    // - Tray state (which pieces remain)
    // - Score, time, etc.
    
    return true;
  }
  
  /// Track piece placement events
  void _trackPiecePlacement(PuzzlePiece piece, Offset position, bool correct, int points) {
    try {
      final trackingService = serviceLocator<GameSessionTrackingService>();
      
      trackingService.updateGameSession(
        sessionId: _sessionId,
        sessionData: {
          'last_piece_placed': {
            'piece_id': piece.id,
            'position': {'x': position.dx, 'y': position.dy},
            'correct': correct,
            'points_earned': points,
            'timestamp': DateTime.now().toIso8601String(),
            'pieces_placed_count': _piecesPlaced,
            'current_score': _score,
          },
          'game_progress': {
            'pieces_placed': _piecesPlaced,
            'total_pieces': totalPieces,
            'completion_percentage': (_piecesPlaced / totalPieces * 100).round(),
            'current_score': _score,
          },
        },
      );
    } catch (e) {
      print('Warning: Failed to track piece placement: $e');
    }
  }
  
  /// Track general game events
  void _trackGameEvent(String eventType, Map<String, dynamic> eventData) {
    try {
      final trackingService = serviceLocator<GameSessionTrackingService>();
      
      trackingService.updateGameSession(
        sessionId: _sessionId,
        sessionData: {
          'last_event': {
            'type': eventType,
            'data': eventData,
            'timestamp': DateTime.now().toIso8601String(),
          },
        },
      );
    } catch (e) {
      print('Warning: Failed to track game event: $e');
    }
  }
}

/// Enhanced puzzle piece with dual asset manager integration
class PuzzlePiece {
  const PuzzlePiece({
    required this.id,
    required this.correctRow,
    required this.correctCol,
    required this.assetManager,
    required this.enhancedAssetManager,
    required this.memoryOptimizedAssetManager,
  });
  
  final String id;
  final int correctRow;
  final int correctCol;
  final PuzzleAssetManager assetManager;
  final EnhancedPuzzleAssetManager enhancedAssetManager;
  final MemoryOptimizedAssetManager memoryOptimizedAssetManager;
  
  @override
  String toString() => 'PuzzlePiece(id: $id, correctPos: ($correctRow, $correctCol))';
}

/// High-performance puzzle game widget with optimized rendering
class PuzzleGameWidget extends StatefulWidget {
  const PuzzleGameWidget({
    super.key,
    required this.gameSession,
    this.onGameCompleted,
    this.onGridSizeChanged,
    this.onPuzzleChanged,
  });
  
  final PuzzleGameSession gameSession;
  final VoidCallback? onGameCompleted;
  final Function(int newGridSize)? onGridSizeChanged;
  final Function(String newPuzzleId)? onPuzzleChanged;
  
  @override
  State<PuzzleGameWidget> createState() => _PuzzleGameWidgetState();
}

class _PuzzleGameWidgetState extends State<PuzzleGameWidget> {
  PuzzlePiece? _selectedPiece;
  bool _isLoading = false;
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Game info with puzzle/grid size controls
        _buildGameInfo(),
        
        const SizedBox(height: 16),
        
        // Loading indicator or main game content
        if (_isLoading)
          const Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading puzzle assets...'),
                ],
              ),
            ),
          )
        else if (!widget.gameSession.assetsLoaded)
          const Expanded(
            child: Center(
              child: Text('Assets not loaded'),
            ),
          )
        else ...[
          // Main puzzle area
          Expanded(
            flex: 3,
            child: _buildPuzzleGrid(),
          ),
          
          const SizedBox(height: 16),
          
          // Pieces tray
          Expanded(
            child: _buildPiecesTray(),
          ),
          
          const SizedBox(height: 8),
          
          // Control buttons
          _buildControlButtons(),
        ],
      ],
    );
  }
  
  Widget _buildGameInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Text('Score: ${widget.gameSession.score}'),
          Text('Progress: ${widget.gameSession.piecesPlaced}/${widget.gameSession.totalPieces}'),
          Text('Level: ${widget.gameSession.level}'),
        ],
      ),
    );
  }
  
  Widget _buildPuzzleGrid() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8),
      ),
      child: AspectRatio(
        aspectRatio: 1,
        child: GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: widget.gameSession.gridSize,
            mainAxisSpacing: widget.gameSession.gridSize > 16 ? 1 : 2,
            crossAxisSpacing: widget.gameSession.gridSize > 16 ? 1 : 2,
          ),
          itemCount: widget.gameSession.totalPieces,
          cacheExtent: widget.gameSession.gridSize > 16 ? 1000 : 500,
          itemBuilder: (context, index) {
            final row = index ~/ widget.gameSession.gridSize;
            final col = index % widget.gameSession.gridSize;
            final piece = widget.gameSession.puzzleGrid[row][col];
            
            return DragTarget<PuzzlePiece>(
              onWillAcceptWithDetails: (details) => details.data != null,
              onAcceptWithDetails: (details) => _placePiece(details.data, row, col),
              builder: (context, candidateData, rejectedData) {
                return GestureDetector(
                  onTap: () => _removePiece(row, col),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: candidateData.isNotEmpty ? Colors.blue : Colors.grey[300]!,
                        width: candidateData.isNotEmpty ? 2 : 0.5,
                      ),
                      color: piece != null ? null : Colors.grey[50],
                    ),
                    child: piece != null
                        ? (widget.gameSession.useMemoryOptimization
                            ? MemoryOptimizedPuzzleImage(
                                pieceId: piece.id,
                                assetManager: piece.memoryOptimizedAssetManager,
                                fit: BoxFit.cover,
                                cropToContent: false, // Canvas mode
                              )
                            : widget.gameSession.useEnhancedRendering
                                ? EnhancedCachedPuzzleImage(
                                    pieceId: piece.id,
                                    assetManager: piece.enhancedAssetManager,
                                    fit: BoxFit.cover,
                                    cropToContent: false, // Canvas mode
                                  )
                                : CachedPuzzleImage(
                                    pieceId: piece.id,
                                    assetManager: piece.assetManager,
                                    fit: BoxFit.cover,
                                  ))
                        : widget.gameSession.gridSize <= 12
                            ? Center(
                                child: Text(
                                  '${row}_$col',
                                  style: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: widget.gameSession.gridSize > 8 ? 8 : 10,
                                  ),
                                ),
                              )
                            : null,
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
  
  Widget _buildPiecesTray() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pieces Tray',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: GridView.builder(
              scrollDirection: Axis.horizontal,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
              ),
              itemCount: widget.gameSession.trayPieces.length,
              itemBuilder: (context, index) {
                final piece = widget.gameSession.trayPieces[index];
                final isSelected = _selectedPiece == piece;
                
                return Draggable<PuzzlePiece>(
                  data: piece,
                  feedback: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.blue, width: 2),
                    ),
                    child: widget.gameSession.useMemoryOptimization
                    ? MemoryOptimizedPuzzleImage(
                    pieceId: piece.id,
                    assetManager: piece.memoryOptimizedAssetManager,
                    fit: BoxFit.cover,
                    cropToContent: true, // Tray mode - crop to content
                    )
                    : widget.gameSession.useEnhancedRendering
                    ? EnhancedCachedPuzzleImage(
                    pieceId: piece.id,
                    assetManager: piece.enhancedAssetManager,
                    fit: BoxFit.cover,
                    cropToContent: true, // Tray mode - crop to content
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
                      ),
                      child: widget.gameSession.useMemoryOptimization
                          ? MemoryOptimizedPuzzleImage(
                              pieceId: piece.id,
                              assetManager: piece.memoryOptimizedAssetManager,
                              fit: BoxFit.cover,
                              cropToContent: true, // Tray mode - crop to content
                            )
                          : widget.gameSession.useEnhancedRendering
                              ? EnhancedCachedPuzzleImage(
                                  pieceId: piece.id,
                                  assetManager: piece.enhancedAssetManager,
                                  fit: BoxFit.cover,
                                  cropToContent: true, // Tray mode - crop to content
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
          ),
        ],
      ),
    );
  }
  
  Widget _buildControlButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        ElevatedButton.icon(
          onPressed: _getHint,
          icon: const Icon(Icons.lightbulb_outline),
          label: const Text('Hint'),
        ),
        ElevatedButton.icon(
          onPressed: widget.gameSession.isActive ? _pauseGame : _resumeGame,
          icon: Icon(widget.gameSession.isActive ? Icons.pause : Icons.play_arrow),
          label: Text(widget.gameSession.isActive ? 'Pause' : 'Resume'),
        ),
      ],
    );
  }
  
  void _placePiece(PuzzlePiece piece, int row, int col) {
    setState(() {
      final success = widget.gameSession.tryPlacePiece(piece, row, col);
      if (success) {
        _selectedPiece = null;
        
        // Check if puzzle is completed
        if (widget.gameSession.isCompleted) {
          _showCompletionDialog();
        }
      } else {
        // Show error feedback
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This piece doesn\'t belong here!'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    });
  }
  
  void _removePiece(int row, int col) {
    setState(() {
      widget.gameSession.removePieceFromGrid(row, col);
    });
  }
  
  void _selectPiece(PuzzlePiece piece) {
    setState(() {
      _selectedPiece = _selectedPiece == piece ? null : piece;
    });
  }
  
  void _getHint() {
    final hintPiece = widget.gameSession.getHint();
    if (hintPiece != null) {
      setState(() {
        _selectedPiece = hintPiece;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Try placing piece ${hintPiece.id} at position (${hintPiece.correctRow}, ${hintPiece.correctCol})'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
  
  void _pauseGame() {
    widget.gameSession.pauseGame();
    setState(() {});
  }
  
  void _resumeGame() {
    widget.gameSession.resumeSession();
    setState(() {});
  }
  
  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Puzzle Completed!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.celebration, size: 64, color: Colors.amber),
            const SizedBox(height: 16),
            Text('Final Score: ${widget.gameSession.score}'),
            Text('Time: ${DateTime.now().difference(widget.gameSession.startTime).inMinutes} minutes'),
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
