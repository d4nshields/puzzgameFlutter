import 'package:puzzgame_flutter/core/domain/game_module_interface.dart';
import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

/// Implementation of the GameModule interface
///
/// This class serves as the adapter to the actual game implementation
/// following the hexagonal architecture pattern.
class NookGameModule implements GameModule {
  static const String _version = '1.0.0';
  
  @override
  Future<bool> initialize() async {
    // TODO: Implement actual game initialization
    print('NookGameModule: Initializing game...');
    await Future.delayed(const Duration(seconds: 1)); // Simulate initialization time
    return true;
  }
  
  @override
  Future<GameSession> startGame({required int difficulty}) async {
    print('NookGameModule: Starting new game with difficulty $difficulty');
    // Create and return a new game session
    final session = NookGameSession(
      sessionId: const Uuid().v4(),
      initialLevel: 1,
      difficulty: difficulty,
    );
    return session;
  }
  
  @override
  Future<GameSession?> resumeGame({required String sessionId}) async {
    // TODO: Implement game session resumption from saved state
    print('NookGameModule: Attempting to resume game with session ID: $sessionId');
    return null; // Not implemented yet
  }
  
  @override
  String get version => _version;
}

/// Implementation of the GameSession interface for the Nook game
class NookGameSession extends Equatable implements GameSession {
  final String _sessionId;
  final int _difficulty;
  int _score = 0;
  int _level;
  bool _isActive = true;
  final DateTime _startTime = DateTime.now();
  
  NookGameSession({
    required String sessionId,
    required int initialLevel,
    required int difficulty,
  }) : _sessionId = sessionId,
       _level = initialLevel,
       _difficulty = difficulty;
  
  @override
  String get sessionId => _sessionId;
  
  @override
  int get score => _score;
  
  @override
  int get level => _level;
  
  @override
  bool get isActive => _isActive;
  
  @override
  Future<void> pauseGame() async {
    if (_isActive) {
      _isActive = false;
      print('NookGameSession: Game paused');
    }
  }
  
  @override
  Future<void> resumeSession() async {
    if (!_isActive) {
      _isActive = true;
      print('NookGameSession: Game resumed');
    }
  }
  
  @override
  Future<GameResult> endGame() async {
    _isActive = false;
    final playTime = DateTime.now().difference(_startTime);
    
    // Create and return game results
    final result = GameResult(
      sessionId: _sessionId,
      finalScore: _score,
      maxLevel: _level,
      playTime: playTime,
      completed: true, // You may need logic to determine if game was actually completed
    );
    
    print('NookGameSession: Game ended with score: ${result.finalScore}');
    return result;
  }
  
  @override
  Future<bool> saveGame() async {
    // TODO: Implement game saving logic
    print('NookGameSession: Saving game state...');
    return true;
  }
  
  // Add methods to update game state
  void updateScore(int points) {
    _score += points;
  }
  
  void advanceLevel() {
    _level++;
  }
  
  @override
  List<Object?> get props => [_sessionId, _score, _level, _isActive, _difficulty];
}
