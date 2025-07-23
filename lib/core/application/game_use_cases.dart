import 'package:puzzgame_flutter/core/domain/game_module_interface.dart';
import 'package:puzzgame_flutter/core/domain/services/game_session_tracking_service.dart';
import 'package:puzzgame_flutter/core/domain/services/auth_service.dart';
import 'package:puzzgame_flutter/core/infrastructure/service_locator.dart';

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
    final gameSession = await _gameModule.startGame(difficulty: difficulty);
    
    // Track the game session start
    try {
      final trackingService = serviceLocator<GameSessionTrackingService>();
      final authService = serviceLocator<AuthService>();
      final currentUser = authService.currentUser;
      
      await trackingService.startGameSession(
        gameSession: gameSession,
        user: currentUser,
        gameType: 'puzzle_nook',
        initialSessionData: {
          'difficulty': difficulty,
          'started_via': 'game_screen',
        },
      );
    } catch (e) {
      print('Warning: Failed to track game session start: $e');
      // Don't throw - game should continue even if tracking fails
    }
    
    return gameSession;
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
    // End the game and get results
    final gameResult = await gameSession.endGame();
    
    // Track the game session end
    try {
      final trackingService = serviceLocator<GameSessionTrackingService>();
      final authService = serviceLocator<AuthService>();
      final currentUser = authService.currentUser;
      
      await trackingService.endGameSession(
        sessionId: gameSession.sessionId,
        gameResult: gameResult,
        user: currentUser,
        finalSessionData: {
          'ended_via': 'end_game_use_case',
          'final_state': 'completed',
        },
      );
    } catch (e) {
      print('Warning: Failed to track game session end: $e');
      // Don't throw - we still want to return the game result
    }
    
    return gameResult;
  }
}
