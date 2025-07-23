import 'package:puzzgame_flutter/core/domain/game_module_interface.dart';
import 'package:puzzgame_flutter/core/domain/entities/user.dart';

/// Service interface for tracking game sessions and statistics in the database
abstract class GameSessionTrackingService {
  /// Start tracking a new game session
  /// Records the session start in the database
  Future<void> startGameSession({
    required GameSession gameSession,
    AppUser? user,
    String? gameType,
    Map<String, dynamic>? initialSessionData,
  });
  
  /// Update an existing game session with new data
  /// Updates progress, score, pieces placed, etc.
  Future<void> updateGameSession({
    required String sessionId,
    Map<String, dynamic>? sessionData,
    int? score,
    int? level,
    bool? isCompleted,
  });
  
  /// End a game session
  /// Records final statistics and updates user stats
  Future<void> endGameSession({
    required String sessionId,
    required GameResult gameResult,
    AppUser? user,
    Map<String, dynamic>? finalSessionData,
  });
  
  /// Pause a game session
  Future<void> pauseGameSession({
    required String sessionId,
    Map<String, dynamic>? sessionData,
  });
  
  /// Resume a game session
  Future<void> resumeGameSession({
    required String sessionId,
    Map<String, dynamic>? sessionData,
  });
  
  /// Get game sessions for a user
  Future<List<Map<String, dynamic>>> getUserGameSessions({
    required String userId,
    String? gameType,
    int? limit,
    bool? completedOnly,
  });
  
  /// Get aggregated game statistics for a user
  Future<Map<String, dynamic>?> getUserGameStats({
    required String userId,
    String? gameType,
  });
  
  /// Update user's aggregated game statistics
  Future<void> updateUserGameStats({
    required String userId,
    required String gameType,
    required Duration additionalPlaytime,
    bool? puzzleCompleted,
  });
  
  /// Record app launch/usage for anonymous tracking
  /// This is useful even for users who haven't signed in
  Future<void> recordAppUsage({
    AppUser? user,
    String? deviceId,
    String? appVersion,
    Map<String, dynamic>? usageData,
  });
}

/// Data class for tracking game session information
class GameSessionInfo {
  final String sessionId;
  final String? userId;
  final String gameType;
  final DateTime startedAt;
  final DateTime? endedAt;
  final Map<String, dynamic> sessionData;
  final bool isCompleted;
  final int finalScore;
  final Duration playTime;

  const GameSessionInfo({
    required this.sessionId,
    this.userId,
    required this.gameType,
    required this.startedAt,
    this.endedAt,
    this.sessionData = const {},
    this.isCompleted = false,
    this.finalScore = 0,
    required this.playTime,
  });

  factory GameSessionInfo.fromJson(Map<String, dynamic> json) {
    return GameSessionInfo(
      sessionId: json['id'] as String,
      userId: json['user_id'] as String?,
      gameType: json['game'] as String,
      startedAt: DateTime.parse(json['started_at'] as String),
      endedAt: json['ended_at'] != null 
        ? DateTime.parse(json['ended_at'] as String) 
        : null,
      sessionData: (json['session_data'] as Map<String, dynamic>?) ?? {},
      isCompleted: (json['session_data'] as Map<String, dynamic>?)?['completed'] == true,
      finalScore: ((json['session_data'] as Map<String, dynamic>?)?['final_score'] as num?)?.toInt() ?? 0,
      playTime: Duration(seconds: ((json['session_data'] as Map<String, dynamic>?)?['play_time_seconds'] as num?)?.toInt() ?? 0),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': sessionId,
      'user_id': userId,
      'game': gameType,
      'started_at': startedAt.toIso8601String(),
      'ended_at': endedAt?.toIso8601String(),
      'session_data': {
        ...sessionData,
        'completed': isCompleted,
        'final_score': finalScore,
        'play_time_seconds': playTime.inSeconds,
      },
    };
  }
}

/// Data class for tracking aggregated game statistics
class GameStats {
  final String userId;
  final String gameType;
  final int totalPlaytimeSeconds;
  final int completedPuzzles;
  final DateTime? lastPlayed;
  final int totalSessions;
  final int highScore;
  final double completionRate;

  const GameStats({
    required this.userId,
    required this.gameType,
    required this.totalPlaytimeSeconds,
    required this.completedPuzzles,
    this.lastPlayed,
    this.totalSessions = 0,
    this.highScore = 0,
    this.completionRate = 0.0,
  });

  Duration get totalPlaytime => Duration(seconds: totalPlaytimeSeconds);

  factory GameStats.fromJson(Map<String, dynamic> json) {
    return GameStats(
      userId: json['user_id'] as String,
      gameType: json['game'] as String,
      totalPlaytimeSeconds: (json['total_playtime'] as num?)?.toInt() ?? 0,
      completedPuzzles: (json['completed_puzzles'] as num?)?.toInt() ?? 0,
      lastPlayed: json['last_played'] != null 
        ? DateTime.parse(json['last_played'] as String)
        : null,
      totalSessions: (json['total_sessions'] as num?)?.toInt() ?? 0,
      highScore: (json['high_score'] as num?)?.toInt() ?? 0,
      completionRate: (json['completion_rate'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'game': gameType,
      'total_playtime': totalPlaytimeSeconds,
      'completed_puzzles': completedPuzzles,
      'last_played': lastPlayed?.toIso8601String(),
      'total_sessions': totalSessions,
      'high_score': highScore,
      'completion_rate': completionRate,
    };
  }
}
