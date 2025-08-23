import 'dart:async';
import 'dart:ui' as ui;
import 'package:uuid/uuid.dart';

import '../../core/domain/game_module_interface.dart';
import '../../core/domain/services/settings_service.dart';
import '../../core/domain/services/error_reporting_service.dart';
import '../../core/infrastructure/service_locator.dart';
import '../../game_module/puzzle_game_module.dart' show PuzzlePiece;
import '../../game_module/services/puzzle_asset_manager.dart';
import '../../game_module/services/enhanced_puzzle_asset_manager.dart';
import '../../game_module/services/memory_optimized_asset_manager.dart';

import 'application/workspace_controller.dart';
import 'domain/value_objects/puzzle_coordinate.dart';
import 'infrastructure/adapters/flutter_asset_adapter.dart';
import 'infrastructure/adapters/flutter_feedback_adapter.dart';
import 'infrastructure/adapters/local_storage_adapter.dart';

/// Type of puzzle piece based on position
enum PieceType { corner, edge, middle }

/// Implementation of GameModule using the new game_module2 architecture.
/// 
/// This module provides a drop-in replacement for PuzzleGameModule with
/// improved architecture and proper piece placement mechanics.
class PuzzleGameModule2 implements GameModule {
  static const String _version = '2.0.0';
  
  // Infrastructure adapters
  late final FlutterAssetAdapter _assetAdapter;
  late final FlutterFeedbackAdapter _feedbackAdapter;
  late final LocalStorageAdapter _storageAdapter;
  
  // Legacy asset managers for compatibility
  PuzzleAssetManager? _legacyAssetManager;
  EnhancedPuzzleAssetManager? _enhancedAssetManager;
  MemoryOptimizedAssetManager? _memoryOptimizedAssetManager;
  
  bool _isInitialized = false;

  @override
  Future<bool> initialize() async {
    if (_isInitialized) {
      print('PuzzleGameModule2: Already initialized');
      return true;
    }
    
    print('PuzzleGameModule2: Initializing with hexagonal architecture...');
    
    try {
      // Initialize infrastructure adapters
      _assetAdapter = FlutterAssetAdapter();
      _feedbackAdapter = FlutterFeedbackAdapter();
      _storageAdapter = LocalStorageAdapter();
      
      await _feedbackAdapter.initialize();
      await _storageAdapter.initialize();
      
      // Initialize legacy asset managers for UI compatibility
      _legacyAssetManager = PuzzleAssetManager();
      await _legacyAssetManager!.initialize();
      
      _enhancedAssetManager = EnhancedPuzzleAssetManager();
      await _enhancedAssetManager!.initialize();
      
      _memoryOptimizedAssetManager = MemoryOptimizedAssetManager();
      await _memoryOptimizedAssetManager!.initialize();
      
      // Register asset managers for compatibility with existing UI
      if (!serviceLocator.isRegistered<PuzzleAssetManager>()) {
        serviceLocator.registerSingleton<PuzzleAssetManager>(_legacyAssetManager!);
      }
      if (!serviceLocator.isRegistered<EnhancedPuzzleAssetManager>()) {
        serviceLocator.registerSingleton<EnhancedPuzzleAssetManager>(_enhancedAssetManager!);
      }
      if (!serviceLocator.isRegistered<MemoryOptimizedAssetManager>()) {
        serviceLocator.registerSingleton<MemoryOptimizedAssetManager>(_memoryOptimizedAssetManager!);
      }
      
      _isInitialized = true;
      print('PuzzleGameModule2: Initialization complete');
      return true;
      
    } catch (e, stack) {
      print('PuzzleGameModule2: Initialization failed: $e\n$stack');
      return false;
    }
  }

  @override
  Future<GameSession> startGame({required int difficulty}) async {
    if (!_isInitialized) {
      throw Exception('PuzzleGameModule2 must be initialized before starting a game');
    }
    
    print('PuzzleGameModule2: Starting new game with difficulty $difficulty');
    
    final errorReporting = serviceLocator<ErrorReportingService>();
    
    try {
      // Get grid size from settings
      final settingsService = serviceLocator<SettingsService>();
      final gridSize = settingsService.getGridSizeForDifficulty(difficulty);
      
      print('PuzzleGameModule2: Using ${gridSize}x$gridSize grid for difficulty $difficulty');
      
      // Create the domain workspace
      final workspaceController = await _createWorkspace(
        puzzleId: 'sample_puzzle_01',
        gridSize: '${gridSize}x$gridSize',
      );
      
      // Load puzzle assets into the legacy asset managers
      print('PuzzleGameModule2: Loading puzzle assets...');
      await _legacyAssetManager!.loadPuzzleGridSize('sample_puzzle_01', '${gridSize}x$gridSize');
      await _enhancedAssetManager!.loadPuzzleGridSize('sample_puzzle_01', '${gridSize}x$gridSize');
      await _memoryOptimizedAssetManager!.loadPuzzleGridSize('sample_puzzle_01', '${gridSize}x$gridSize');
      print('PuzzleGameModule2: Puzzle assets loaded');
      
      // Create a game session that's compatible with existing UI
      final session = PuzzleGameSession2(
        sessionId: const Uuid().v4(),
        difficulty: difficulty,
        gridSize: gridSize,
        workspaceController: workspaceController,
        legacyAssetManager: _legacyAssetManager!,
        enhancedAssetManager: _enhancedAssetManager!,
        memoryOptimizedAssetManager: _memoryOptimizedAssetManager!,
      );
      
      await errorReporting.addBreadcrumb(
        'Started new game with module2',
        category: 'game_lifecycle',
        data: {
          'difficulty': difficulty,
          'gridSize': '${gridSize}x$gridSize',
          'module_version': _version,
        },
      );
      
      return session;
      
    } catch (e, stack) {
      await errorReporting.reportException(
        e,
        stackTrace: stack,
        context: 'game_module2_start_game',
        extra: {'difficulty': difficulty},
      );
      rethrow;
    }
  }

  @override
  Future<GameSession?> resumeGame({required String sessionId}) async {
    if (!_isInitialized) {
      throw Exception('PuzzleGameModule2 must be initialized before resuming a game');
    }
    
    try {
      // Try to load saved workspace
      final summaries = await _storageAdapter.listSavedWorkspaces();
      summaries.firstWhere(
        (s) => s.id == sessionId,
        orElse: () => throw Exception('Session not found'),
      );
      
      // Create workspace controller and load the saved state
      final workspaceController = WorkspaceController(
        assetRepository: _assetAdapter,
        feedbackService: _feedbackAdapter,
        persistenceRepository: _storageAdapter,
      );
      
      await workspaceController.resumeWorkspace(sessionId);
      
      // Create compatible game session
      final workspace = workspaceController.workspace!;
      final dims = workspace.gridSize.split('x');
      final gridSize = int.parse(dims[0]);
      
      return PuzzleGameSession2(
        sessionId: sessionId,
        difficulty: _getDifficultyFromGridSize(gridSize),
        gridSize: gridSize,
        workspaceController: workspaceController,
        legacyAssetManager: _legacyAssetManager!,
        enhancedAssetManager: _enhancedAssetManager!,
        memoryOptimizedAssetManager: _memoryOptimizedAssetManager!,
      );
      
    } catch (e) {
      print('PuzzleGameModule2: Failed to resume game: $e');
      return null;
    }
  }

  @override
  String get version => _version;

  // Private helper methods
  
  Future<WorkspaceController> _createWorkspace(
    {required String puzzleId, required String gridSize}
  ) async {
    final controller = WorkspaceController(
      assetRepository: _assetAdapter,
      feedbackService: _feedbackAdapter,
      persistenceRepository: _storageAdapter,
    );
    
    await controller.initializeWorkspace(
      puzzleId: puzzleId,
      gridSize: gridSize,
    );
    
    return controller;
  }
  
  int _getDifficultyFromGridSize(int gridSize) {
    if (gridSize <= 8) return 1;  // Easy
    if (gridSize <= 12) return 2; // Medium
    return 3; // Hard
  }
}

/// Game session implementation that bridges the new architecture with existing UI.
/// 
/// This class extends the original PuzzleGameSession to maintain compatibility
/// while using the new domain model internally.
class PuzzleGameSession2 extends GameSession {
  final String _sessionId;
  final int difficulty;
  final int gridSize;
  final WorkspaceController workspaceController;
  
  // Legacy asset managers for UI compatibility
  final PuzzleAssetManager legacyAssetManager;
  final EnhancedPuzzleAssetManager enhancedAssetManager;
  final MemoryOptimizedAssetManager memoryOptimizedAssetManager;
  
  // Bridge to legacy UI
  late final List<PuzzlePiece> _legacyPieces;
  late final PuzzleCanvasInfo _canvasInfo;
  final DateTime _startTime = DateTime.now();

  PuzzleGameSession2({
    required String sessionId,
    required this.difficulty,
    required this.gridSize,
    required this.workspaceController,
    required this.legacyAssetManager,
    required this.enhancedAssetManager,
    required this.memoryOptimizedAssetManager,
  }) : _sessionId = sessionId {
    _initializeLegacyBridge();
  }

  void _initializeLegacyBridge() {
    final workspace = workspaceController.workspace!;
    
    print('=== INITIALIZING GAME SESSION ===');
    print('Workspace pieces count: ${workspace.pieces.length}');
    print('Pieces in tray: ${workspace.pieces.where((p) => p.isInTray).length}');
    print('Pieces placed: ${workspace.pieces.where((p) => p.isPlaced).length}');
    
    // Create canvas info for UI
    _canvasInfo = PuzzleCanvasInfo(
      canvasSize: ui.Size(workspace.canvasSize.width, workspace.canvasSize.height),
    );
    
    // Create legacy piece objects that wrap domain pieces
    _legacyPieces = workspace.pieces.map((domainPiece) {
      return PuzzlePiece(
        id: domainPiece.id,
        correctRow: domainPiece.correctRow,
        correctCol: domainPiece.correctCol,
        assetManager: legacyAssetManager,
        enhancedAssetManager: enhancedAssetManager,
        memoryOptimizedAssetManager: memoryOptimizedAssetManager,
      );
    }).toList();
  }

  @override
  String get sessionId => _sessionId;

  @override
  int get score => workspaceController.score;

  @override
  int get level => 1; // Single level for puzzles

  @override
  bool get isActive => !isPaused;

  // Extended properties for puzzle UI
  bool get isPaused => _isPaused;
  bool _isPaused = false;
  
  DateTime get startTime => _startTime;
  
  String get currentPuzzleId => workspaceController.workspace?.puzzleId ?? 'sample_puzzle_01';
  
  bool get assetsLoaded => true; // Assets loaded during workspace creation
  
  bool get useEnhancedRendering => true;
  bool get useMemoryOptimization => true;
  
  PuzzleCanvasInfo get canvasInfo => _canvasInfo;
  
  List<PuzzlePiece> get pieces => _legacyPieces;
  
  /// Determine the type of piece based on its grid position
  PieceType getPieceType(int row, int col, int gridSize) {
    final isTopEdge = row == 0;
    final isBottomEdge = row == gridSize - 1;
    final isLeftEdge = col == 0;
    final isRightEdge = col == gridSize - 1;
    
    final edgeCount = (isTopEdge ? 1 : 0) + 
                     (isBottomEdge ? 1 : 0) + 
                     (isLeftEdge ? 1 : 0) + 
                     (isRightEdge ? 1 : 0);
    
    if (edgeCount == 2) return PieceType.corner;
    if (edgeCount == 1) return PieceType.edge;
    return PieceType.middle;
  }
  
  /// Get sorted tray pieces (corners, edges, middles)
  List<PuzzlePiece> get sortedTrayPieces {
    final tray = trayPieces.toList();
    
    // Sort by type: corners first, then edges, then middle pieces
    tray.sort((a, b) {
      final workspace = workspaceController.workspace!;
      final pieceA = workspace.pieces.firstWhere((p) => p.id == a.id);
      final pieceB = workspace.pieces.firstWhere((p) => p.id == b.id);
      
      final typeA = getPieceType(pieceA.correctRow, pieceA.correctCol, gridSize);
      final typeB = getPieceType(pieceB.correctRow, pieceB.correctCol, gridSize);
      
      // Compare by type priority
      return typeA.index.compareTo(typeB.index);
    });
    
    return tray;
  }
  
  List<PuzzlePiece> get trayPieces {
    final workspace = workspaceController.workspace!;
    return _legacyPieces.where((piece) {
      final domainPiece = workspace.pieces.firstWhere((p) => p.id == piece.id);
      return domainPiece.isInTray;
    }).toList();
  }
  
  List<PuzzlePiece> get placedPieces {
    final workspace = workspaceController.workspace!;
    return _legacyPieces.where((piece) {
      final domainPiece = workspace.pieces.firstWhere((p) => p.id == piece.id);
      return domainPiece.isPlaced;
    }).toList();
  }
  
  List<PuzzlePiece> get workspacePieces {
    final workspace = workspaceController.workspace!;
    return _legacyPieces.where((piece) {
      final domainPiece = workspace.pieces.firstWhere((p) => p.id == piece.id);
      return !domainPiece.isInTray && !domainPiece.isPlaced;
    }).toList();
  }
  
  int get totalPieces => _legacyPieces.length;
  int get piecesPlaced => placedPieces.length;
  int get piecesRemaining => totalPieces - piecesPlaced;
  
  bool get isCompleted => workspaceController.isCompleted;

  /// Place a piece - this is called by the UI's drop zone
  bool placePiece(PuzzlePiece piece) {
    // This should NOT auto-place! 
    // In game_module2, pieces need to be explicitly positioned
    // This method is for compatibility but shouldn't be used
    print('Warning: placePiece called without position - this should not happen in module2');
    return false;
  }
  
  /// Try to place a piece at specific coordinates (new method for module2)
  bool tryPlacePieceAt(PuzzlePiece piece, double x, double y) {
    final workspace = workspaceController.workspace!;
    final domainPiece = workspace.pieces.firstWhere((p) => p.id == piece.id);
    
    // Convert to puzzle coordinates
    final position = PuzzleCoordinate(x: x, y: y);
    
    // Check if close enough to snap
    final distance = position.distanceTo(domainPiece.correctPosition);
    const snapThreshold = 50.0; // pixels
    
    if (distance <= snapThreshold) {
      // Snap to correct position
      workspaceController.dragPiece(piece.id, domainPiece.correctPosition);
      return true;
    }
    
    // Not close enough - piece stays where dropped
    workspaceController.dragPiece(piece.id, position);
    return false;
  }
  
  /// Remove a piece from its placed position
  void removePiece(PuzzlePiece piece) {
    workspaceController.removePlacedPiece(piece.id);
  }
  
  /// Legacy method for compatibility
  void removePieceFromGrid(int row, int col) {
    // Find piece at this grid position
    final workspace = workspaceController.workspace!;
    final targetPiece = workspace.pieces.firstWhere(
      (p) => p.correctRow == row && p.correctCol == col && p.isPlaced,
      orElse: () => throw Exception('No placed piece at position'),
    );
    
    workspaceController.removePlacedPiece(targetPiece.id);
  }
  
  /// Get a hint
  PuzzlePiece? getHint() {
    workspaceController.requestHint();
    final workspace = workspaceController.workspace!;
    final hintPiece = workspace.getHint();
    
    if (hintPiece != null) {
      return _legacyPieces.firstWhere((p) => p.id == hintPiece.id);
    }
    return null;
  }

  @override
  Future<void> pauseGame() async {
    _isPaused = true;
    await workspaceController.saveWorkspace();
  }

  @override
  Future<void> resumeSession() async {
    _isPaused = false;
  }

  @override
  Future<GameResult> endGame() async {
    await workspaceController.saveWorkspace();
    
    return GameResult(
      sessionId: sessionId,
      finalScore: score,
      maxLevel: 1,
      playTime: DateTime.now().difference(_startTime),
      completed: isCompleted,
    );
  }

  @override
  Future<bool> saveGame() async {
    try {
      await workspaceController.saveWorkspace();
      return true;
    } catch (e) {
      print('Failed to save game: $e');
      return false;
    }
  }
}

/// Canvas information for UI rendering
class PuzzleCanvasInfo {
  final ui.Size canvasSize;
  
  const PuzzleCanvasInfo({required this.canvasSize});
}
