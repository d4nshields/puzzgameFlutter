import 'package:flutter_test/flutter_test.dart';
import 'package:puzzgame_flutter/core/domain/services/game_session_tracking_service.dart';
import 'package:puzzgame_flutter/core/domain/entities/user.dart';
import 'package:puzzgame_flutter/core/domain/game_module_interface.dart';

/// Mock implementation for testing
class MockGameSessionTrackingService implements GameSessionTrackingService {
  final List<Map<String, dynamic>> recordedSessions = [];
  final List<Map<String, dynamic>> recordedUsage = [];
  final Map<String, Map<String, dynamic>> userStats = {};

  @override
  Future<void> startGameSession({
    required GameSession gameSession,
    AppUser? user,
    String? gameType,
    Map<String, dynamic>? initialSessionData,
  }) async {
    recordedSessions.add({
      'action': 'start',
      'sessionId': gameSession.sessionId,
      'userId': user?.id,
      'gameType': gameType,
      'data': initialSessionData,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<void> updateGameSession({
    required String sessionId,
    Map<String, dynamic>? sessionData,
    int? score,
    int? level,
    bool? isCompleted,
  }) async {
    recordedSessions.add({
      'action': 'update',
      'sessionId': sessionId,
      'sessionData': sessionData,
      'score': score,
      'level': level,
      'isCompleted': isCompleted,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<void> endGameSession({
    required String sessionId,
    required GameResult gameResult,
    AppUser? user,
    Map<String, dynamic>? finalSessionData,
  }) async {
    recordedSessions.add({
      'action': 'end',
      'sessionId': sessionId,
      'userId': user?.id,
      'gameResult': {
        'completed': gameResult.completed,
        'finalScore': gameResult.finalScore,
        'playTime': gameResult.playTime.inSeconds,
      },
      'data': finalSessionData,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<void> pauseGameSession({
    required String sessionId,
    Map<String, dynamic>? sessionData,
  }) async {
    recordedSessions.add({
      'action': 'pause',
      'sessionId': sessionId,
      'sessionData': sessionData,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<void> resumeGameSession({
    required String sessionId,
    Map<String, dynamic>? sessionData,
  }) async {
    recordedSessions.add({
      'action': 'resume',
      'sessionId': sessionId,
      'sessionData': sessionData,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<List<Map<String, dynamic>>> getUserGameSessions({
    required String userId,
    String? gameType,
    int? limit,
    bool? completedOnly,
  }) async {
    return recordedSessions
        .where((session) => session['userId'] == userId)
        .take(limit ?? recordedSessions.length)
        .toList();
  }

  @override
  Future<Map<String, dynamic>?> getUserGameStats({
    required String userId,
    String? gameType,
  }) async {
    final key = '${userId}_${gameType ?? 'all'}';
    return userStats[key];
  }

  @override
  Future<void> updateUserGameStats({
    required String userId,
    required String gameType,
    required Duration additionalPlaytime,
    bool? puzzleCompleted,
  }) async {
    final key = '${userId}_$gameType';
    final current = userStats[key] ?? {
      'total_playtime': 0,
      'completed_puzzles': 0,
      'total_sessions': 0,
    };

    userStats[key] = {
      'user_id': userId,
      'game': gameType,
      'total_playtime': (current['total_playtime'] as int) + additionalPlaytime.inSeconds,
      'completed_puzzles': (current['completed_puzzles'] as int) + (puzzleCompleted == true ? 1 : 0),
      'total_sessions': (current['total_sessions'] as int) + 1,
      'last_played': DateTime.now().toIso8601String(),
    };
  }

  @override
  Future<void> recordAppUsage({
    AppUser? user,
    String? deviceId,
    String? appVersion,
    Map<String, dynamic>? usageData,
  }) async {
    recordedUsage.add({
      'userId': user?.id,
      'deviceId': deviceId,
      'appVersion': appVersion,
      'usageData': usageData,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }
}

/// Mock game session for testing
class MockGameSession implements GameSession {
  @override
  final String sessionId;
  
  @override
  int score = 0;
  
  @override
  int level = 1;
  
  @override
  bool isActive = true;

  MockGameSession(this.sessionId);

  @override
  Future<void> pauseGame() async {
    isActive = false;
  }

  @override
  Future<void> resumeSession() async {
    isActive = true;
  }

  @override
  Future<GameResult> endGame() async {
    isActive = false;
    return GameResult(
      sessionId: sessionId,
      finalScore: score,
      maxLevel: level,
      playTime: const Duration(minutes: 10),
      completed: true,
    );
  }

  @override
  Future<bool> saveGame() async {
    return true;
  }
}

// Helper constant for test data
final testCreatedAt = DateTime(2025, 1, 1);

void main() {
  group('Game Session Tracking Service Tests', () {
    late MockGameSessionTrackingService trackingService;
    late MockGameSession gameSession;
    late AppUser testUser;

    setUp(() {
      trackingService = MockGameSessionTrackingService();
      gameSession = MockGameSession('test-session-123');
      testUser = AppUser(
        id: 'user-123',
        email: 'test@example.com',
        createdAt: testCreatedAt,
        profileData: const {'name': 'Test User'},
      );
    });

    test('should track game session start', () async {
      await trackingService.startGameSession(
        gameSession: gameSession,
        user: testUser,
        gameType: 'puzzle_nook',
        initialSessionData: {'difficulty': 2},
      );

      expect(trackingService.recordedSessions.length, 1);
      final recorded = trackingService.recordedSessions.first;
      expect(recorded['action'], 'start');
      expect(recorded['sessionId'], 'test-session-123');
      expect(recorded['userId'], 'user-123');
      expect(recorded['gameType'], 'puzzle_nook');
      expect(recorded['data']['difficulty'], 2);
    });

    test('should track game session updates', () async {
      await trackingService.updateGameSession(
        sessionId: 'test-session-123',
        score: 100,
        sessionData: {'pieces_placed': 5},
      );

      expect(trackingService.recordedSessions.length, 1);
      final recorded = trackingService.recordedSessions.first;
      expect(recorded['action'], 'update');
      expect(recorded['sessionId'], 'test-session-123');
      expect(recorded['score'], 100);
      expect(recorded['sessionData']['pieces_placed'], 5);
    });

    test('should track game session end and update user stats', () async {
      final gameResult = await gameSession.endGame();
      
      await trackingService.endGameSession(
        sessionId: gameSession.sessionId,
        gameResult: gameResult,
        user: testUser,
      );

      await trackingService.updateUserGameStats(
        userId: testUser.id,
        gameType: 'puzzle_nook',
        additionalPlaytime: gameResult.playTime,
        puzzleCompleted: gameResult.completed,
      );

      // Check session end tracking
      expect(trackingService.recordedSessions.length, 1);
      final recorded = trackingService.recordedSessions.first;
      expect(recorded['action'], 'end');
      expect(recorded['gameResult']['completed'], true);
      expect(recorded['gameResult']['finalScore'], 0);

      // Check user stats update
      final stats = await trackingService.getUserGameStats(
        userId: testUser.id,
        gameType: 'puzzle_nook',
      );
      expect(stats, isNotNull);
      expect(stats!['completed_puzzles'], 1);
      expect(stats['total_playtime'], 600); // 10 minutes in seconds
    });

    test('should record app usage', () async {
      await trackingService.recordAppUsage(
        user: testUser,
        deviceId: 'device-123',
        appVersion: '1.0.0',
        usageData: {'action': 'app_launch'},
      );

      expect(trackingService.recordedUsage.length, 1);
      final recorded = trackingService.recordedUsage.first;
      expect(recorded['userId'], 'user-123');
      expect(recorded['deviceId'], 'device-123');
      expect(recorded['appVersion'], '1.0.0');
      expect(recorded['usageData']['action'], 'app_launch');
    });

    test('should work with anonymous users', () async {
      await trackingService.startGameSession(
        gameSession: gameSession,
        user: null, // Anonymous user
        gameType: 'puzzle_nook',
      );

      expect(trackingService.recordedSessions.length, 1);
      final recorded = trackingService.recordedSessions.first;
      expect(recorded['userId'], isNull);
      expect(recorded['gameType'], 'puzzle_nook');
    });
  });
}
