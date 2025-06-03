import 'dart:math';

import 'package:flutter/material.dart';
import 'package:puzzgame_flutter/core/domain/game_module_interface.dart';
import 'package:puzzgame_flutter/core/domain/services/settings_service.dart';
import 'package:puzzgame_flutter/core/infrastructure/service_locator.dart';
import 'package:puzzgame_flutter/game_module/services/puzzle_asset_manager.dart';
import 'package:uuid/uuid.dart';

/// Implementation of the GameModule interface for jigsaw puzzle game
/// Now with integrated high-performance asset management
class PuzzleGameModule implements GameModule {
  static const String _version = '1.0.0';
  
  late final PuzzleAssetManager _assetManager;
  
  @override
  Future<bool> initialize() async {
    print('PuzzleGameModule: Initializing puzzle game...');
    
    // Initialize asset manager
    _assetManager = PuzzleAssetManager();
    await _assetManager.initialize();
    
    // Register asset manager in service locator for easy access
    if (!serviceLocator.isRegistered<PuzzleAssetManager>()) {
      serviceLocator.registerSingleton<PuzzleAssetManager>(_assetManager);
    }
    
    print('PuzzleGameModule: Asset manager initialized with ${(await _assetManager.getAvailablePuzzles()).length} puzzles');
    return true;
  }
  
  @override
  Future<GameSession> startGame({required int difficulty}) async {
    print('PuzzleGameModule: Starting new puzzle game with difficulty $difficulty');
    
    // Get grid size from settings service
    final settingsService = serviceLocator<SettingsService>();
    final gridSize = settingsService.getGridSizeForDifficulty(difficulty);
    
    print('PuzzleGameModule: Using ${gridSize}x$gridSize grid for difficulty $difficulty');
    
    // Create game session with asset manager
    final session = PuzzleGameSession(
      sessionId: const Uuid().v4(),
      difficulty: difficulty,
      gridSize: gridSize,
      assetManager: _assetManager,
    );
    
    await session._initializePuzzle();
    return session;
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
  PuzzleAssetManager get assetManager => _assetManager;
}

/// Enhanced PuzzleGameSession with asset manager integration
class PuzzleGameSession implements GameSession {
  
  PuzzleGameSession({
    required String sessionId,
    required int difficulty,
    required int gridSize,
    required PuzzleAssetManager assetManager,
  }) : _sessionId = sessionId,
       _difficulty = difficulty,
       _gridSize = gridSize,
       _assetManager = assetManager;

  // Core session data
  final String _sessionId;
  final int _difficulty;
  final int _gridSize;
  final PuzzleAssetManager _assetManager;
  
  int _score = 0;
  final int _level = 1;
  bool _isActive = true;
  final DateTime _startTime = DateTime.now();
  
  // Puzzle-specific state
  late List<PuzzlePiece> _allPieces;
  late List<PuzzlePiece> _trayPieces;
  late List<List<PuzzlePiece?>> _puzzleGrid;
  late String _currentPuzzleId;
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
  String get currentPuzzleId => _currentPuzzleId;
  bool get isCompleted => _piecesPlaced == totalPieces;
  bool get assetsLoaded => _assetsLoaded;
  DateTime get startTime => _startTime;
  PuzzleAssetManager get assetManager => _assetManager;
  
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
    
    // Load all assets for this puzzle/grid size combination
    await _assetManager.loadPuzzleGridSize(_currentPuzzleId, gridSizeStr);
    
    // Create puzzle pieces with asset manager references
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
    
    // Initialize empty puzzle grid
    _puzzleGrid = List.generate(
      _gridSize,
      (row) => List.generate(_gridSize, (col) => null),
    );
    
    // Shuffle pieces for the tray
    _trayPieces = List.from(_allPieces);
    _trayPieces.shuffle(Random());
    
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
    
    // Recreate pieces for new grid size
    _allPieces = [];
    for (int row = 0; row < newGridSize; row++) {
      for (int col = 0; col < newGridSize; col++) {
        final piece = PuzzlePiece(
          id: '${row}_$col',
          correctRow: row,
          correctCol: col,
          assetManager: _assetManager,
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

  /// Attempt to place a piece at the specified grid position
  /// Returns true if placement was successful
  bool tryPlacePiece(PuzzlePiece piece, int targetRow, int targetCol) {
    if (!_isActive || !_assetsLoaded) return false;
    
    // Check if the position is correct
    if (piece.correctRow != targetRow || piece.correctCol != targetCol) {
      print('PuzzleGameSession: Incorrect placement attempt for piece ${piece.id}');
      return false;
    }
    
    // Check if position is already occupied
    if (_puzzleGrid[targetRow][targetCol] != null) {
      print('PuzzleGameSession: Position ($targetRow, $targetCol) already occupied');
      return false;
    }
    
    // Place the piece
    _puzzleGrid[targetRow][targetCol] = piece;
    _trayPieces.remove(piece);
    _piecesPlaced++;
    
    // Calculate score based on difficulty and time
    final timeBonusMultiplier = _calculateTimeBonusMultiplier();
    final basePoints = 10 * _difficulty;
    final points = (basePoints * timeBonusMultiplier).round();
    _score += points;
    
    print('PuzzleGameSession: Placed piece ${piece.id} at ($targetRow, $targetCol). Score: +$points');
    
    // Check if puzzle is completed
    if (isCompleted) {
      _onPuzzleCompleted();
    }
    
    return true;
  }
  
  /// Remove a piece from the puzzle grid back to the tray
  void removePieceFromGrid(int row, int col) {
    if (!_isActive || !_assetsLoaded) return;
    
    final piece = _puzzleGrid[row][col];
    if (piece != null) {
      _puzzleGrid[row][col] = null;
      _trayPieces.add(piece);
      _piecesPlaced--;
      
      // Shuffle tray to avoid giving hints
      _trayPieces.shuffle(Random());
      
      print('PuzzleGameSession: Removed piece ${piece.id} from grid');
    }
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
    
    // Save state would include:
    // - Current puzzle ID
    // - Grid state (which pieces are placed where)
    // - Tray state (which pieces remain)
    // - Score, time, etc.
    
    return true;
  }
}

/// Enhanced puzzle piece with asset manager integration
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
  final PuzzleAssetManager assetManager;
  
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
                        ? CachedPuzzleImage(
                            pieceId: piece.id,
                            assetManager: piece.assetManager,
                            fit: BoxFit.cover,
                          )
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
                    child: CachedPuzzleImage(
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
                      child: CachedPuzzleImage(
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
