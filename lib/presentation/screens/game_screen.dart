import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puzzgame_flutter/core/application/game_use_cases.dart';
import 'package:puzzgame_flutter/core/domain/game_module_interface.dart';
import 'package:puzzgame_flutter/core/domain/services/settings_service.dart';
import 'package:puzzgame_flutter/core/infrastructure/service_locator.dart';
import 'package:puzzgame_flutter/game_module/puzzle_game_module.dart';

/// Provider for game session state
final gameSessionProvider = StateProvider<GameSession?>((ref) => null);

/// Game screen that hosts the Nook game
class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  bool _isLoading = true;
  String _errorMessage = '';
  
  @override
  void initState() {
    super.initState();
    _startGame();
  }
  
  Future<void> _startGame() async {
    try {
      // Get settings service to determine difficulty
      final settingsService = serviceLocator<SettingsService>();
      final difficulty = await settingsService.getDifficulty();
      
      // Get the start game use case from service locator
      final startGameUseCase = serviceLocator<StartGameUseCase>();
      
      // Start game with user's preferred difficulty
      final gameSession = await startGameUseCase.execute(difficulty: difficulty);
      
      // Update the provider with the new game session
      ref.read(gameSessionProvider.notifier).state = gameSession;
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to start game: ${e.toString()}';
      });
    }
  }
  
  Future<void> _endGame() async {
    final gameSession = ref.read(gameSessionProvider);
    if (gameSession != null) {
      final endGameUseCase = serviceLocator<EndGameUseCase>();
      await endGameUseCase.execute(gameSession: gameSession);
      
      // Clear the game session
      ref.read(gameSessionProvider.notifier).state = null;
      
      // Navigate back to home screen
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final gameSession = ref.watch(gameSessionProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nook'),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: _endGame,
          ),
        ],
      ),
      body: _buildBody(gameSession),
    );
  }
  
  Widget _buildBody(GameSession? gameSession) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    
    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _errorMessage,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _errorMessage = '';
                });
                _startGame();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    
    if (gameSession == null) {
      return const Center(
        child: Text('No active game session'),
      );
    }
    
    // Check if this is a puzzle game session
    if (gameSession is PuzzleGameSession) {
      return PuzzleGameWidget(
        gameSession: gameSession,
        onGameCompleted: _onPuzzleCompleted,
      );
    }
    
    // Fallback to placeholder for other game types (like NookGameModule)
    return _buildPlaceholderUI(gameSession);
  }
  
  /// Handle puzzle completion
  void _onPuzzleCompleted() {
    _showCompletionCelebration();
    
    // TODO: Add logic for progression to next level/puzzle
    // TODO: Save high score
    // TODO: Unlock achievements
  }
  
  /// Show celebration for puzzle completion
  void _showCompletionCelebration() {
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
  Widget _buildPlaceholderUI(GameSession gameSession) {
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
          const SizedBox(height: 30),
          const Text(
            'Game Module Placeholder',
            style: TextStyle(fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 50),
          ElevatedButton(
            onPressed: _endGame,
            child: const Text('End Game'),
          ),
        ],
      ),
    );
  }
}
