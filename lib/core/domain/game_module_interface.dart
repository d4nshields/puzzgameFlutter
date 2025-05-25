/// Game module interface that defines the contract between the core app
/// and the game implementation.
///
/// This follows the hexagonal architecture pattern where the domain defines 
/// the interfaces (ports) that the infrastructure will implement (adapters).
abstract class GameModule {
  /// Initialize the game with necessary configurations
  /// 
  /// Returns true if initialization was successful
  Future<bool> initialize();
  
  /// Start a new game session
  /// 
  /// [difficulty] determines the game's difficulty level
  /// Returns a GameSession object that can be used to interact with the game
  Future<GameSession> startGame({required int difficulty});
  
  /// Resume a previously saved game session
  /// 
  /// [sessionId] is the unique identifier for the saved session
  /// Returns the resumed GameSession or null if not found
  Future<GameSession?> resumeGame({required String sessionId});
  
  /// Get the current version of the game module
  String get version;
}

/// Represents an active game session
///
/// This interface defines how the application can interact with
/// an ongoing game session.
abstract class GameSession {
  /// Unique identifier for this game session
  String get sessionId;
  
  /// Current score in the game
  int get score;
  
  /// Current level in the game
  int get level;
  
  /// Whether the game is currently active or paused
  bool get isActive;
  
  /// Pause the current game session
  Future<void> pauseGame();
  
  /// Resume a paused game session
  Future<void> resumeSession();
  
  /// End the current game session
  Future<GameResult> endGame();
  
  /// Save the current game state to be resumed later
  Future<bool> saveGame();
}

/// Contains the final results of a completed game session
class GameResult {

  const GameResult({
    required this.sessionId,
    required this.finalScore,
    required this.maxLevel,
    required this.playTime,
    required this.completed,
  });
  final String sessionId;
  final int finalScore;
  final int maxLevel;
  final Duration playTime;
  final bool completed;
}
