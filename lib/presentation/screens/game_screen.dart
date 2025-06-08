import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puzzgame_flutter/core/application/game_use_cases.dart';
import 'package:puzzgame_flutter/core/application/settings_providers.dart';
import 'package:puzzgame_flutter/core/domain/game_module_interface.dart';
import 'package:puzzgame_flutter/core/infrastructure/service_locator.dart';
import 'package:puzzgame_flutter/game_module/puzzle_game_module.dart';
import 'package:puzzgame_flutter/game_module/services/puzzle_asset_manager.dart';
import 'package:puzzgame_flutter/game_module/widgets/puzzle_selection_widget.dart';
import 'package:puzzgame_flutter/game_module/widgets/enhanced_puzzle_game_widget.dart';

/// Provider for game session state that automatically restarts when difficulty changes
final gameSessionProvider = AsyncNotifierProvider<GameSessionNotifier, GameSession?>(() {
  return GameSessionNotifier();
});

/// Notifier for managing game session with automatic restarts
class GameSessionNotifier extends AsyncNotifier<GameSession?> {
  @override
  Future<GameSession?> build() async {
    // Watch difficulty changes to automatically restart game
    final difficulty = await ref.watch(difficultyProvider.future);
    
    try {
      final startGameUseCase = serviceLocator<StartGameUseCase>();
      final gameSession = await startGameUseCase.execute(difficulty: difficulty);
      
      print('Game started/restarted with difficulty $difficulty');
      return gameSession;
    } catch (e) {
      print('Error starting game: $e');
      rethrow;
    }
  }
  
  /// Manually restart the game
  Future<void> restartGame() async {
    state = const AsyncValue.loading();
    
    try {
      final difficulty = await ref.read(difficultyProvider.future);
      final startGameUseCase = serviceLocator<StartGameUseCase>();
      final gameSession = await startGameUseCase.execute(difficulty: difficulty);
      
      state = AsyncValue.data(gameSession);
      print('Game manually restarted with difficulty $difficulty');
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }
  
  /// End the current game
  Future<void> endGame() async {
    final currentSession = state.value;
    if (currentSession != null) {
      final endGameUseCase = serviceLocator<EndGameUseCase>();
      await endGameUseCase.execute(gameSession: currentSession);
    }
    
    state = const AsyncValue.data(null);
  }
}

/// Game screen that hosts the Puzzle Bazaar game with reactive settings
class GameScreen extends ConsumerWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch game session and settings
    final gameSessionAsync = ref.watch(gameSessionProvider);
    final difficultyAsync = ref.watch(difficultyProvider);
    final gridSize = ref.watch(gridSizeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Puzzle Bazaar'),
        actions: [
          // Puzzle selection button
          IconButton(
            icon: const Icon(Icons.palette),
            onPressed: () => _showPuzzleSelection(context, ref),
            tooltip: 'Select Puzzle',
          ),
          // Show difficulty in app bar
          if (difficultyAsync.hasValue)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getDifficultyColor(difficultyAsync.value!),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _getDifficultyName(difficultyAsync.value!),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.pushNamed(context, '/settings');
            },
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              ref.read(gameSessionProvider.notifier).endGame();
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: _buildBody(context, ref, gameSessionAsync, difficultyAsync, gridSize),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<GameSession?> gameSessionAsync,
    AsyncValue<int> difficultyAsync,
    int gridSize,
  ) {
    // Handle loading state
    if (gameSessionAsync.isLoading || difficultyAsync.isLoading) {
      return Column(
        children: [
          // Show loading info
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 12),
                Text(
                  gameSessionAsync.isLoading 
                    ? 'Starting game...' 
                    : 'Loading settings...',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Colors.blue[700],
                  ),
                ),
              ],
            ),
          ),
          const Expanded(
            child: Center(
              child: CircularProgressIndicator(),
            ),
          ),
        ],
      );
    }

    // Handle error state
    if (gameSessionAsync.hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              'Failed to start game: ${gameSessionAsync.error}',
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                ref.read(gameSessionProvider.notifier).restartGame();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final gameSession = gameSessionAsync.value;
    final difficulty = difficultyAsync.value ?? 2;

    if (gameSession == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'No active game session',
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => _showPuzzleSelection(context, ref),
              icon: const Icon(Icons.palette),
              label: const Text('Select Puzzle'),
            ),
          ],
        ),
      );
    }

    // Check if this is a puzzle game session
    if (gameSession is PuzzleGameSession) {
      return Column(
        children: [
          // Show current puzzle info
          _buildPuzzleInfo(context, gameSession, difficulty, gridSize, ref),
          
          // Enhanced puzzle game widget with zoom and audio
          Expanded(
            child: EnhancedPuzzleGameWidget(
              gameSession: gameSession,
              onGameCompleted: () => _onPuzzleCompleted(context, ref),
            ),
          ),
        ],
      );
    }

    // Fallback to placeholder for other game types
    return _buildPlaceholderUI(context, ref, gameSession, difficulty, gridSize);
  }

  String _getDifficultyName(int difficulty) {
    switch (difficulty) {
      case 1: return 'Easy';
      case 2: return 'Medium';
      case 3: return 'Hard';
      default: return 'Medium';
    }
  }

  Color _getDifficultyColor(int difficulty) {
    switch (difficulty) {
      case 1: return Colors.green;
      case 2: return Colors.orange;
      case 3: return Colors.red;
      default: return Colors.orange;
    }
  }

  Widget _buildPuzzleInfo(
    BuildContext context,
    PuzzleGameSession gameSession,
    int difficulty,
    int gridSize,
    WidgetRef ref,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _getDifficultyColor(difficulty).withOpacity(0.1),
            _getDifficultyColor(difficulty).withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _getDifficultyColor(difficulty).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          // Puzzle info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Puzzle: ${_formatPuzzleName(gameSession.currentPuzzleId)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  'Grid: ${gameSession.gridSize}×${gameSession.gridSize} (${gameSession.totalPieces} pieces)',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          
          // Quick actions
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: () => _showPuzzleSelection(context, ref),
                icon: const Icon(Icons.palette),
                tooltip: 'Change Puzzle',
                iconSize: 20,
              ),
              IconButton(
                onPressed: () => _restartCurrentPuzzle(context, ref),
                icon: const Icon(Icons.refresh),
                tooltip: 'Restart Puzzle',
                iconSize: 20,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Event handlers

  Future<void> _showPuzzleSelection(BuildContext context, WidgetRef ref) async {
    try {
      // Get the asset manager from the game module
      if (!serviceLocator.isRegistered<PuzzleAssetManager>()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Asset manager not initialized')),
        );
        return;
      }
      
      final assetManager = serviceLocator<PuzzleAssetManager>();
      
      // Get current session info for pre-selection
      final currentSession = ref.read(gameSessionProvider).value;
      String? currentPuzzleId;
      String? currentGridSize;
      
      if (currentSession is PuzzleGameSession) {
        currentPuzzleId = currentSession.currentPuzzleId;
        currentGridSize = '${currentSession.gridSize}x${currentSession.gridSize}';
      }

      await PuzzleSelectionDialog.show(
        context,
        assetManager,
        (puzzleId, gridSize) async {
          // Handle puzzle selection
          await _startNewGame(ref, puzzleId, gridSize);
        },
        currentPuzzleId: currentPuzzleId,
        currentGridSize: currentGridSize,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to show puzzle selection: $e')),
      );
    }
  }

  Future<void> _startNewGame(WidgetRef ref, String puzzleId, String gridSize) async {
    try {
      // Extract difficulty from grid size
      final dimensions = gridSize.split('x');
      final size = int.parse(dimensions[0]);
      
      // This is a simplified approach - in a more complete implementation,
      // you might want to update your settings service with the new grid size
      // and then restart the game. For now, we'll just restart.
      
      await ref.read(gameSessionProvider.notifier).restartGame();
      
    } catch (e) {
      debugPrint('Failed to start new game: $e');
    }
  }

  Future<void> _restartCurrentPuzzle(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restart Puzzle'),
        content: const Text('Are you sure you want to restart the current puzzle? Your progress will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Restart'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(gameSessionProvider.notifier).restartGame();
    }
  }

  /// Handle puzzle completion
  void _onPuzzleCompleted(BuildContext context, WidgetRef ref) {
    _showCompletionCelebration(context);
    
    // TODO: Add logic for progression to next level/puzzle
    // TODO: Save high score
    // TODO: Unlock achievements
  }

  void _onGridSizeChanged(BuildContext context, WidgetRef ref, int newGridSize) {
    // Handle grid size change if needed
    debugPrint('Grid size changed to: $newGridSize');
  }

  void _onPuzzleChanged(BuildContext context, WidgetRef ref, String newPuzzleId) {
    // Handle puzzle change if needed
    debugPrint('Puzzle changed to: $newPuzzleId');
  }

  // Utility methods

  String _formatPuzzleName(String puzzleId) {
    return puzzleId
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) => word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  /// Show celebration for puzzle completion
  void _showCompletionCelebration(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.celebration, color: Colors.amber),
            SizedBox(width: 8),
            Text('Congratulations! Puzzle completed!'),
          ],
        ),
        duration: Duration(seconds: 3),
        backgroundColor: Colors.green,
      ),
    );
  }

  /// Placeholder UI for non-puzzle game sessions
  Widget _buildPlaceholderUI(
    BuildContext context,
    WidgetRef ref,
    GameSession gameSession,
    int difficulty,
    int gridSize,
  ) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          AspectRatio(
            aspectRatio: 1,
            child: Image.asset(
              'assets/images/reassembled.png',
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Colors.grey[300],
                  child: const Icon(
                    Icons.image_not_supported,
                    size: 64,
                    color: Colors.grey,
                  ),
                );
              },
            ),
          ),
          const Text(
            'Game in Progress',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Text('Session ID: ${gameSession.sessionId}'),
          const SizedBox(height: 8),
          Text('Level: ${gameSession.level}'),
          const SizedBox(height: 8),
          Text('Score: ${gameSession.score}'),
          const SizedBox(height: 8),
          Text('Difficulty: ${_getDifficultyName(difficulty)} ($gridSize×$gridSize)'),
          const SizedBox(height: 30),
          const Text(
            'Game Module Placeholder',
            style: TextStyle(fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 50),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: () {
                  ref.read(gameSessionProvider.notifier).restartGame();
                },
                child: const Text('Restart Game'),
              ),
              ElevatedButton(
                onPressed: () {
                  ref.read(gameSessionProvider.notifier).endGame();
                  Navigator.pop(context);
                },
                child: const Text('End Game'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
