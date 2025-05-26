import 'dart:math';

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'package:puzzgame_flutter/core/domain/game_module_interface.dart';

/// Implementation of the GameModule interface for jigsaw puzzle game
///
/// This class serves as the adapter to the puzzle game implementation
/// following the hexagonal architecture pattern.
class PuzzleGameModule implements GameModule {
  static const String _version = '1.0.0';
  
  @override
  Future<bool> initialize() async {
    print('PuzzleGameModule: Initializing puzzle game...');
    // TODO: Add puzzle pack validation, asset loading verification
    await Future.delayed(const Duration(milliseconds: 500));
    return true;
  }
  
  @override
  Future<GameSession> startGame({required int difficulty}) async {
    print('PuzzleGameModule: Starting new puzzle game with difficulty $difficulty');
    
    // Map difficulty to grid size
    final gridSize = _getDifficultyGridSize(difficulty);
    
    // Create and return a new puzzle game session
    final session = PuzzleGameSession(
      sessionId: const Uuid().v4(),
      difficulty: difficulty,
      gridSize: gridSize,
    );
    
    await session._initializePuzzle();
    return session;
  }
  
  @override
  Future<GameSession?> resumeGame({required String sessionId}) async {
    // TODO: Implement puzzle session resumption from saved state
    print('PuzzleGameModule: Attempting to resume puzzle game with session ID: $sessionId');
    return null; // Not implemented yet
  }
  
  @override
  String get version => _version;
  
  /// Maps difficulty level to grid size
  int _getDifficultyGridSize(int difficulty) {
    switch (difficulty) {
      case 1: return 8;   // Easy: 8x8 = 64 pieces
      case 2: return 16;  // Medium: 16x16 = 256 pieces  
      case 3: return 32;  // Hard: 32x32 = 1024 pieces
      default: return 16; // Default to medium
    }
  }
}

/// Implementation of the GameSession interface for the puzzle game
class PuzzleGameSession extends Equatable implements GameSession {
  
  PuzzleGameSession({
    required String sessionId,
    required int difficulty,
    required int gridSize,
  }) : _sessionId = sessionId,
       _difficulty = difficulty,
       _gridSize = gridSize;

  // Core session data
  final String _sessionId;
  final int _difficulty;
  final int _gridSize;
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
  
  // Getters for GameSession interface
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
  DateTime get startTime => _startTime; // Add public getter for start time
  
  /// Initialize the puzzle with pieces
  Future<void> _initializePuzzle() async {
    print('PuzzleGameSession: Initializing ${_gridSize}x$_gridSize puzzle');
    
    // TODO: Replace with actual puzzle pack selection logic
    _currentPuzzleId = 'sample_puzzle_01';
    
    // Create all puzzle pieces
    _allPieces = [];
    for (int row = 0; row < _gridSize; row++) {
      for (int col = 0; col < _gridSize; col++) {
        final piece = PuzzlePiece(
          id: '${row}_$col',
          correctRow: row,
          correctCol: col,
          assetPath: 'assets/puzzles/$_currentPuzzleId/layouts/${_gridSize}x$_gridSize/pieces/${row}_$col.png',
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
  }
  
  /// Attempt to place a piece at the specified grid position
  /// Returns true if placement was successful
  bool tryPlacePiece(PuzzlePiece piece, int targetRow, int targetCol) {
    if (!_isActive) return false;
    
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
    if (!_isActive) return;
    
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
    if (_trayPieces.isEmpty) return null;
    
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
  
  @override
  List<Object?> get props => [
    _sessionId, 
    _score, 
    _level, 
    _isActive, 
    _difficulty,
    _piecesPlaced,
    _currentPuzzleId,
  ];
}

/// Represents a single puzzle piece
class PuzzlePiece extends Equatable {
  const PuzzlePiece({
    required this.id,
    required this.correctRow,
    required this.correctCol,
    required this.assetPath,
  });
  
  /// Unique identifier for this piece (typically "row_col")
  final String id;
  
  /// The correct row position in the solved puzzle (0-indexed)
  final int correctRow;
  
  /// The correct column position in the solved puzzle (0-indexed)  
  final int correctCol;
  
  /// Path to the piece image asset
  final String assetPath;
  
  @override
  List<Object?> get props => [id, correctRow, correctCol, assetPath];
  
  @override
  String toString() => 'PuzzlePiece(id: $id, correctPos: ($correctRow, $correctCol))';
}

/// Widget that renders the puzzle game UI
/// This should be integrated into your GameScreen
class PuzzleGameWidget extends StatefulWidget {
  const PuzzleGameWidget({
    super.key,
    required this.gameSession,
    this.onGameCompleted,
  });
  
  final PuzzleGameSession gameSession;
  final VoidCallback? onGameCompleted;
  
  @override
  State<PuzzleGameWidget> createState() => _PuzzleGameWidgetState();
}

class _PuzzleGameWidgetState extends State<PuzzleGameWidget> {
  PuzzlePiece? _selectedPiece;
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Game info header
        _buildGameInfo(),
        
        const SizedBox(height: 16),
        
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
            mainAxisSpacing: widget.gameSession.gridSize > 16 ? 1 : 2, // Tighter spacing for large grids
            crossAxisSpacing: widget.gameSession.gridSize > 16 ? 1 : 2,
          ),
          itemCount: widget.gameSession.totalPieces,
          // Add caching for performance with large grids
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
                        width: candidateData.isNotEmpty ? 2 : 0.5, // Thinner borders for large grids
                      ),
                      color: piece != null ? null : Colors.grey[50],
                    ),
                    child: piece != null
                        ? Image.asset(
                            piece.assetPath,
                            fit: BoxFit.cover,
                            // Add caching and optimize for large grids
                            cacheWidth: widget.gameSession.gridSize > 16 ? 64 : null,
                            cacheHeight: widget.gameSession.gridSize > 16 ? 64 : null,
                            errorBuilder: (context, error, stackTrace) {
                              // Fallback when asset is not found
                              return Container(
                                color: Colors.blue[200],
                                child: widget.gameSession.gridSize <= 16 
                                    ? Center(
                                        child: Text(
                                          piece.id,
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      )
                                    : null, // No text for very small cells
                              );
                            },
                          )
                        : widget.gameSession.gridSize <= 16
                            ? Center(
                                child: Text(
                                  '${row}_$col',
                                  style: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: widget.gameSession.gridSize > 8 ? 8 : 10,
                                  ),
                                ),
                              )
                            : null, // No text labels for 32x32 grid
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
                    child: Image.asset(
                      piece.assetPath,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.blue[200],
                          child: Center(child: Text(piece.id)),
                        );
                      },
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
                      child: Image.asset(
                        piece.assetPath,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.blue[200],
                            child: Center(
                              child: Text(
                                piece.id,
                                style: const TextStyle(fontSize: 10),
                              ),
                            ),
                          );
                        },
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