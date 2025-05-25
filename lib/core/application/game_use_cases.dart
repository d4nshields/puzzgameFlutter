import 'package:puzzgame_flutter/core/domain/game_module_interface.dart';

/// Use case for starting a new game
///
/// This class is part of the application layer in hexagonal architecture
/// and orchestrates the interaction between the domain and infrastructure.
class StartGameUseCase {
  
  StartGameUseCase(this._gameModule);
  final GameModule _gameModule;
  
  /// Executes the use case to start a new game
  ///
  /// [difficulty] - The difficulty level of the game
  /// Returns a [GameSession] when successful
  Future<GameSession> execute({required int difficulty}) async {
    // Ensure the game module is initialized
    final isInitialized = await _gameModule.initialize();
    
    if (!isInitialized) {
      throw Exception('Failed to initialize game module');
    }
    
    // Start the game with the specified difficulty
    return _gameModule.startGame(difficulty: difficulty);
  }
}

/// Use case for resuming a saved game
class ResumeGameUseCase {
  
  ResumeGameUseCase(this._gameModule);
  final GameModule _gameModule;
  
  /// Executes the use case to resume a saved game
  ///
  /// [sessionId] - The ID of the saved game session
  /// Returns a [GameSession] when successful, null if not found
  Future<GameSession?> execute({required String sessionId}) async {
    // Ensure the game module is initialized
    final isInitialized = await _gameModule.initialize();
    
    if (!isInitialized) {
      throw Exception('Failed to initialize game module');
    }
    
    // Try to resume the game with the specified session ID
    return _gameModule.resumeGame(sessionId: sessionId);
  }
}

/// Use case for ending a game session
class EndGameUseCase {
  /// Executes the use case to end a game session
  ///
  /// [gameSession] - The active game session to end
  /// Returns the final [GameResult]
  Future<GameResult> execute({required GameSession gameSession}) async {
    return gameSession.endGame();
  }
}
