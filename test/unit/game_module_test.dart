import 'package:flutter_test/flutter_test.dart';
import 'package:puzzgame_flutter/core/domain/game_module_interface.dart';
import 'package:puzzgame_flutter/game_module/puzzle_bazaar_game_module.dart';

void main() {
  group('PuzzleBazaarGameModule Tests', () {
    late PuzzleBazaarGameModule gameModule;
    
    setUp(() {
      gameModule = PuzzleBazaarGameModule();
    });
    
    test('initialize returns true', () async {
      final result = await gameModule.initialize();
      expect(result, true);
    });
    
    test('startGame creates a valid GameSession', () async {
      final session = await gameModule.startGame(difficulty: 2);
      
      expect(session, isA<GameSession>());
      expect(session.level, 1);
      expect(session.score, 0);
      expect(session.isActive, true);
      expect(session.sessionId.isNotEmpty, true);
    });
    
    test('resumeGame returns null for now', () async {
      final session = await gameModule.resumeGame(sessionId: 'test-id');
      expect(session, null);
    });
    
    test('version is not empty', () {
      expect(gameModule.version.isNotEmpty, true);
    });
  });
  
  group('PuzzleBazaarGameSession Tests', () {
    late PuzzleBazaarGameSession gameSession;
    
    setUp(() {
      gameSession = PuzzleBazaarGameSession(
        sessionId: 'test-session',
        initialLevel: 1,
        difficulty: 2,
      );
    });
    
    test('session is active when created', () {
      expect(gameSession.isActive, true);
    });
    
    test('pauseGame sets isActive to false', () async {
      await gameSession.pauseGame();
      expect(gameSession.isActive, false);
    });
    
    test('resumeSession sets isActive to true', () async {
      await gameSession.pauseGame();
      await gameSession.resumeSession();
      expect(gameSession.isActive, true);
    });
    
    test('endGame returns valid GameResult', () async {
      final result = await gameSession.endGame();
      
      expect(result, isA<GameResult>());
      expect(result.sessionId, 'test-session');
      expect(result.finalScore, 0);
      expect(result.maxLevel, 1);
      expect(result.completed, true);
    });
    
    test('updateScore increases score correctly', () {
      gameSession.updateScore(10);
      expect(gameSession.score, 10);
      
      gameSession.updateScore(5);
      expect(gameSession.score, 15);
    });
    
    test('advanceLevel increases level correctly', () {
      gameSession.advanceLevel();
      expect(gameSession.level, 2);
      
      gameSession.advanceLevel();
      expect(gameSession.level, 3);
    });
    
    test('saveGame returns true', () async {
      final result = await gameSession.saveGame();
      expect(result, true);
    });
  });
}
