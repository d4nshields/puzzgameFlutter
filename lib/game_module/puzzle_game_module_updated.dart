// Updated PuzzleGameModule with Memory Optimization Integration
// This file shows how to integrate the memory-optimized asset manager

import 'dart:math';
import 'package:puzzgame_flutter/core/domain/game_module_interface.dart';
import 'package:puzzgame_flutter/core/domain/services/settings_service.dart';
import 'package:puzzgame_flutter/core/infrastructure/service_locator.dart';
import 'package:puzzgame_flutter/game_module/services/puzzle_asset_manager.dart';
import 'package:puzzgame_flutter/game_module/services/enhanced_puzzle_asset_manager.dart';
import 'package:puzzgame_flutter/game_module/services/memory_optimized_asset_manager.dart';
import 'package:uuid/uuid.dart';

/// Enhanced PuzzleGameModule with Memory Optimization Support
/// Automatically detects and uses optimized assets when available
class MemoryOptimizedPuzzleGameModule implements GameModule {
  static const String _version = '2.0.0';
  
  PuzzleAssetManager? _assetManager;
  EnhancedPuzzleAssetManager? _enhancedAssetManager;
  MemoryOptimizedAssetManager? _memoryOptimizedAssetManager;
  bool _isInitialized = false;
  // ignore: unused_field
  bool _useMemoryOptimization = true;
  // ignore: unused_field
  bool _useEnhancedRendering = true;
  
  @override
  Future<bool> initialize() async {
    if (_isInitialized) return true;
    
    print('MemoryOptimizedPuzzleGameModule: Initializing with memory optimization...');
    
    // Initialize all asset managers
    _assetManager = PuzzleAssetManager();
    await _assetManager!.initialize();
    
    _enhancedAssetManager = EnhancedPuzzleAssetManager();
    await _enhancedAssetManager!.initialize();
    
    _memoryOptimizedAssetManager = MemoryOptimizedAssetManager();
    await _memoryOptimizedAssetManager!.initialize();
    
    // Register in service locator
    if (!serviceLocator.isRegistered<MemoryOptimizedAssetManager>()) {
      serviceLocator.registerSingleton<MemoryOptimizedAssetManager>(_memoryOptimizedAssetManager!);
    }
    
    _isInitialized = true;
    final puzzleCount = (await _memoryOptimizedAssetManager!.getAvailablePuzzles()).length;
    print('MemoryOptimizedPuzzleGameModule: Initialized with $puzzleCount puzzles');
    return true;
  }
  
  @override
  Future<GameSession> startGame({required int difficulty}) async {
    if (!_isInitialized) {
      throw Exception('Module must be initialized before starting a game');
    }
    
    final settingsService = serviceLocator<SettingsService>();
    final gridSize = settingsService.getGridSizeForDifficulty(difficulty);
    
    final session = MemoryOptimizedPuzzleGameSession(
      sessionId: const Uuid().v4(),
      difficulty: difficulty,
      gridSize: gridSize,
      memoryOptimizedAssetManager: _memoryOptimizedAssetManager!,
    );
    
    await session.initializePuzzle();
    return session;
  }
  
  @override
  Future<GameSession?> resumeGame({required String sessionId}) async {
    return null; // TODO: Implement
  }
  
  @override
  String get version => _version;
  
  MemoryOptimizedAssetManager? get memoryOptimizedAssetManager => _memoryOptimizedAssetManager;
}

/// Memory-optimized puzzle game session
class MemoryOptimizedPuzzleGameSession implements GameSession {
  MemoryOptimizedPuzzleGameSession({
    required String sessionId,
    required int difficulty,
    required int gridSize,
    required MemoryOptimizedAssetManager memoryOptimizedAssetManager,
  }) : _sessionId = sessionId,
       _difficulty = difficulty,
       _gridSize = gridSize,
       _memoryOptimizedAssetManager = memoryOptimizedAssetManager;

  final String _sessionId;
  final int _difficulty;
  final int _gridSize;
  final MemoryOptimizedAssetManager _memoryOptimizedAssetManager;
  
  int _score = 0;
  final int _level = 1;
  bool _isActive = true;
  final DateTime _startTime = DateTime.now();
  
  late List<MemoryOptimizedPuzzlePiece> _allPieces;
  late List<MemoryOptimizedPuzzlePiece> _trayPieces;
  final List<MemoryOptimizedPuzzlePiece> _placedPieces = [];
  late String _currentPuzzleId;
  int _piecesPlaced = 0;
  bool _assetsLoaded = false;
  
  @override
  String get sessionId => _sessionId;
  @override
  int get score => _score;
  @override
  int get level => _level;
  @override
  bool get isActive => _isActive;
  
  int get gridSize => _gridSize;
  int get totalPieces => _gridSize * _gridSize;
  int get piecesPlaced => _piecesPlaced;
  List<MemoryOptimizedPuzzlePiece> get trayPieces => List.unmodifiable(_trayPieces);
  List<MemoryOptimizedPuzzlePiece> get placedPieces => List.unmodifiable(_placedPieces);
  bool get isCompleted => _piecesPlaced == totalPieces;
  bool get assetsLoaded => _assetsLoaded;
  MemoryOptimizedAssetManager get memoryOptimizedAssetManager => _memoryOptimizedAssetManager;
  
  Future<void> initializePuzzle() async {
    final availablePuzzles = await _memoryOptimizedAssetManager.getAvailablePuzzles();
    if (availablePuzzles.isEmpty) {
      throw Exception('No puzzles available');
    }
    
    _currentPuzzleId = availablePuzzles.first.id;
    final gridSizeStr = '${_gridSize}x$_gridSize';
    
    // Load memory-optimized assets
    await _memoryOptimizedAssetManager.loadPuzzleGridSize(_currentPuzzleId, gridSizeStr);
    
    // Create puzzle pieces
    _allPieces = [];
    for (int row = 0; row < _gridSize; row++) {
      for (int col = 0; col < _gridSize; col++) {
        final piece = MemoryOptimizedPuzzlePiece(
          id: '${row}_$col',
          correctRow: row,
          correctCol: col,
          memoryOptimizedAssetManager: _memoryOptimizedAssetManager,
        );
        _allPieces.add(piece);
      }
    }
    
    _trayPieces = List.from(_allPieces);
    _trayPieces.shuffle(Random());
    _placedPieces.clear();
    _piecesPlaced = 0;
    _assetsLoaded = true;
    
    print('MemoryOptimizedPuzzleGameSession: Initialized ${_allPieces.length} pieces');
  }
  
  bool placePiece(MemoryOptimizedPuzzlePiece piece) {
    if (!_isActive || !_assetsLoaded || _placedPieces.contains(piece)) return false;
    
    _placedPieces.add(piece);
    _trayPieces.remove(piece);
    _piecesPlaced++;
    _score += 10 * _difficulty;
    
    if (isCompleted) {
      _score += 100 * _difficulty; // Completion bonus
    }
    
    return true;
  }
  
  void removePiece(MemoryOptimizedPuzzlePiece piece) {
    if (_placedPieces.remove(piece)) {
      _trayPieces.add(piece);
      _piecesPlaced--;
      _trayPieces.shuffle(Random());
    }
  }
  
  @override
  Future<void> pauseGame() async {
    _isActive = false;
  }
  
  @override
  Future<void> resumeSession() async {
    _isActive = true;
  }
  
  @override
  Future<GameResult> endGame() async {
    _isActive = false;
    final playTime = DateTime.now().difference(_startTime);
    
    return GameResult(
      sessionId: _sessionId,
      finalScore: _score,
      maxLevel: _level,
      playTime: playTime,
      completed: isCompleted,
    );
  }
  
  @override
  Future<bool> saveGame() async {
    return true; // TODO: Implement persistence
  }
}

/// Memory-optimized puzzle piece
class MemoryOptimizedPuzzlePiece {
  const MemoryOptimizedPuzzlePiece({
    required this.id,
    required this.correctRow,
    required this.correctCol,
    required this.memoryOptimizedAssetManager,
  });
  
  final String id;
  final int correctRow;
  final int correctCol;
  final MemoryOptimizedAssetManager memoryOptimizedAssetManager;
  
  @override
  String toString() => 'MemoryOptimizedPuzzlePiece(id: $id, pos: ($correctRow, $correctCol))';
}
